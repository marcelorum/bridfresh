#!/usr/bin/env bash
# ============================================================
#  keepdash.sh — Navegador-Dashboard dedicado e invisible
#
#  SCRIPT OFICIAL. El anterior keepalive.sh (over la pestana real,
#  AppleScript) quedo en ./legacy/ como referencia historica.
#
#  Usa una instancia de Chrome aparte (perfil propio, no toca tus
#  perfiles personal/trabajo) y la controla por HTTP (DevTools
#  Protocol). El ciclo corre en modo HEADLESS (sin ventana): es
#  IMPOSIBLE que Chrome aparezca, robe el foco o te corte el flujo.
#
#  PRIMERA VEZ (autenticacion SSO + 2FA):
#    ./keepdash.sh            -> si no estas logueado, abre SOLA la ventana
#                                para login, espera y DETECTA SOLO cuando
#                                terminas de loguearte, y reanuda el ciclo
#                                invisible. Sin preguntas, sin --login previo.
#                                La segunda vez entra directo al ciclo.
#    ./keepdash.sh --login    -> abre la VENTANA dedicada manualmente.
#
#  Uso:
#    ./keepdash.sh               -> ciclo en headless, invisible (240s default; URLs en config.conf).
#    ./keepdash.sh --login       -> abre ventana headed para login (o para ver).
#    ./keepdash.sh -t 240        -> intervalo 4 min (default).
#    ./keepdash.sh -d 1h         -> corre 1 hora y sale solo.
#    ./keepdash.sh -u <archivo>  -> URLs desde un archivo (pisa las de config.conf).
#    ./keepdash.sh --once        -> un solo refresco (prueba).
#    ./keepdash.sh --stop        -> apaga la instancia dedicada.
#
#  Flags:
#    -d <dur>   duracion total: 30m, 1h, 2h o minutos sueltos (default: sin limite)
#    -t <seg>   intervalo entre refrescos (default: config.conf)
#    -u <file>  archivo con una URL por linea (pisa las de config.conf)
#    -h         ayuda
#
#  Si arrancas sin sesion, abre SOLA la ventana de login y reanuda el
#  ciclo invisible al detectar el login. Si la sesion expira a mitad del
#  ciclo, imprime un resumen y cierra solo (sin preguntar).
# ============================================================

set -u
# Resuelve symlinks (ej. ~/bin/keepdash -> bridfresh/keepdash.sh) para que
# SCRIPT_DIR siempre apunte al repo real, sin importar desde donde se invoque.
_SRC="${BASH_SOURCE[0]}"
while [[ -L "$_SRC" ]]; do
  _d="$(cd -P "$(dirname "$_SRC")" >/dev/null 2>&1 && pwd)"
  _t="$(readlink "$_SRC")"
  [[ "$_t" != /* ]] && _t="$_d/$_t"
  _SRC="$_t"
done
SCRIPT_DIR="$(cd -P "$(dirname "$_SRC")" && pwd)"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
PROFILE_DIR="$SCRIPT_DIR/.dash-profile"      # perfil dedicado (privado, gitignored)
PORT=9222                                     # puerto local de control (CDP)
INTERVAL=240                                  # default: refresco cada 4 min
DURATION_MINS=0                               # 0 = sin limite (corre hasta --stop / Ctrl+C)

# URL por default si no hay URLS en config.conf ni -u <archivo>.
DEFAULT_URLS=(
  "https://example.com/dashboard"
)

# --- CONFIG (si existe): tomamos INTERVAL y URLS=( ... ) como default ---
CONFIG="$SCRIPT_DIR/config.conf"
URLS_CFG=()
if [[ -f "$CONFIG" ]]; then
  _iv="$(sed -n 's/^INTERVAL=\([0-9]*\).*/\1/p' "$CONFIG" | head -1)"
  [[ -n "$_iv" ]] && INTERVAL="$_iv"
  # URLS=( ... ): cada linea dentro del bloque es una URL a ciclar.
  while IFS= read -r _u; do
    [[ -n "$_u" ]] && URLS_CFG+=("$_u")
  done < <(sed -n '/^[[:space:]]*URLS=(/,/^[[:space:]]*)/p' "$CONFIG" \
      | sed '1d;$d' \
      | sed -E 's/#.*$//; s/^[[:space:]]+//; s/[[:space:]]+$//; s/^"(.*)"$/\1/; s/^'"'"'(.*)'"'"'$/\1/')
fi

# --- Duracion: convierte 30m / 1h / 2h (o minutos sueltos) a minutos ----
parse_duration() {
  local v="$1"
  case "$v" in
    *h) DURATION_MINS="${v%h}"; DURATION_MINS=$((DURATION_MINS * 60)) ;;
    *m) DURATION_MINS="${v%m}" ;;
    *)  DURATION_MINS="$v" ;;
  esac
  if ! [[ "$DURATION_MINS" =~ ^[0-9]+$ ]] || [[ "$DURATION_MINS" -eq 0 ]]; then
    echo "ERROR: duracion invalida '$1' (usa 30m, 1h, 2h o minutos sueltos)." >&2
    exit 1
  fi
}

usage() { sed -n '10,/^# ====.*$/p' "$0"; exit 0; }

LOG=false
ONE=false
STOP=false
SHOW=false
URLS=("${DEFAULT_URLS[@]}")
URL_FILE=""

# --- Parseo: --flags primero, luego getopts ---------------------------
ARGS=()
args=("$@")
i=0
while [[ $i -lt ${#args[@]} ]]; do
  case "${args[$i]}" in
    --login) LOG=true ;;
    --once)  ONE=true ;;
    --stop)  STOP=true ;;
    --show)  SHOW=true ;;
    -h|--help) usage ;;
    *) ARGS+=("${args[$i]}") ;;
  esac
  i=$((i + 1))
done
set -- "${ARGS[@]+"${ARGS[@]}"}"
while getopts "t:u:d:h" opt; do
  case "$opt" in
    t) INTERVAL="$OPTARG" ;;
    u) URL_FILE="$OPTARG" ;;
    d) parse_duration "$OPTARG" ;;
    h) usage ;;
    *) usage ;;
  esac
done
shift $((OPTIND - 1))

if [[ -n "${URL_FILE:-}" ]]; then
  if [[ ! -f "$URL_FILE" ]]; then
    echo "ERROR: archivo '$URL_FILE' no existe" >&2; exit 1
  fi
  URLS=()
  while IFS= read -r line; do
    line="${line%%#*}"
    line="$(printf '%s' "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ -n "$line" ]] && URLS+=("$line")
  done < "$URL_FILE"
elif [[ ${#URLS_CFG[@]} -gt 0 ]]; then
  # Sin -u: si config.conf define URLS=( ... ), esas son las que ciclan.
  URLS=("${URLS_CFG[@]}")
fi

if [[ ${#URLS[@]} -eq 0 ]]; then
  echo "ERROR: no hay URLs." >&2; exit 1
fi

# --- Utilidades --------------------------------------------------------
# Percent-encode TODO (:, /, ?, =, &, +, %) para que /json/new reciba la
# URL completa sin cortarse en el primer &.
urlencode() {
  local s="$1" c out=""
  for ((i=0; i<${#s}; i++)); do
    c="${s:$i:1}"
    case "$c" in
      [a-zA-Z0-9_.-]) out+="$c" ;;
      *) printf -v h '%%%02X' "'$c"; out+="$h" ;;
    esac
  done
  printf '%s' "$out"
}

# --- Instancia dedicada ------------------------------------------------
dash_is_up() { curl -sf --max-time 3 "http://localhost:$PORT/json/version" >/dev/null 2>&1; }

dash_boot() {
  # headed=true  -> abre ventana visible (login / ver)
  # headed=false -> headless (invisible, el ciclo normal)
  # Antes, asegura que no quede otra instancia con el mismo perfil (evita conflicts).
  pkill -f "user-data-dir=$PROFILE_DIR" 2>/dev/null
  sleep 1
  local headed="$1"
  local extra="--headless=new"
  [[ "$headed" == true ]] && extra=""
  echo "Levantando navegador-dashboard dedicado ($([[ "$headed" == true ]] && echo VENTANA || echo invisible))..."
  "$CHROME" $extra \
            --user-data-dir="$PROFILE_DIR" \
            --remote-debugging-port="$PORT" \
            --no-first-run --no-default-browser-check \
            "${URLS[0]}" >/tmp/keepdash-chrome.log 2>&1 &
  local k=0
  while ! dash_is_up; do
    k=$((k+1)); [[ $k -gt 40 ]] && break
    sleep 0.5
  done
  if ! dash_is_up; then
    echo "ERROR: no arranco el navegador-dashboard ($CHROME)." >&2
    return 1
  fi
  sleep 3
  return 0
}

dash_stop() {
  pkill -f "user-data-dir=$PROFILE_DIR" 2>/dev/null
  echo "Navegador-dashboard apagado."
}

dash_needs_auth() {
  # ¿Alguna pestana quedo en la pagina de login (login. / okta)?
  curl -s --max-time 5 "http://localhost:$PORT/json/list" 2>/dev/null \
    | grep -qE 'login\.|okta'
}

# Espera activa en DOS FASES: (1) primero espera a VER la pagina de login
# (el redirect tarda; si nunca la vio, no puede estar logueado); (2) recien
# cuando la vio, exige 3 polls limpios consecutivos (15s sin login/okta)
# para declarar el login completo. Si la ventana se cerro, avisa una vez.
# Ctrl+C aborta. Sin timeout: espera hasta que loguees.
wait_for_login() {
  local waited=0 warned=0 saw_auth=0 clean=0
  echo ""
  echo "Esperando que termines de loguearte (se detecta solo)..."
  while true; do
    if dash_is_up; then
      if dash_needs_auth; then
        saw_auth=1
        clean=0
      elif [[ "$saw_auth" -eq 1 ]]; then
        clean=$((clean + 1))
        if [[ "$clean" -ge 3 ]]; then
          echo "Login detectado."
          return 0
        fi
      fi
    else
      if [[ "$warned" -eq 0 ]]; then
        warned=1
        echo "   Ojo: la ventana no esta arriba (¿la cerraste?)."
        echo "   Reabre con  ./keepdash.sh --login  o aborta con Ctrl+C."
      fi
      clean=0
    fi
    sleep 5
    waited=$((waited + 5))
    if (( waited % 30 == 0 )); then
      if [[ "$saw_auth" -eq 0 ]]; then
        echo "   Todavia no veo la pagina de login (el redirect tarda)."
        echo "   Si ya estabas logueado y no deberia esperar: Ctrl+C."
      else
        echo "   ...sigo esperando (${waited}s). Ctrl+C para cancelar."
      fi
    fi
  done
}

# Resumen de cierre: motivo, inicio, fin, duracion y refrescos. Se usa
# en todos los cierres (tiempo cumplido, sesion expirada, Ctrl+C).
print_summary() {
  local reason="$1"
  local end_ts now_str elapsed mins secs
  end_ts="$(date +%s)"
  now_str="$(date '+%H:%M:%S')"
  elapsed=$((end_ts - ${START_TS:-$end_ts}))
  mins=$((elapsed / 60)); secs=$((elapsed % 60))
  echo ""
  echo "--- Resumen ---"
  echo "  Motivo:     $reason"
  echo "  Inicio:     ${START_STR:-$now_str}"
  echo "  Fin:        $now_str"
  echo "  Duracion:   ${mins}m ${secs}s"
  echo "  Refrescos:  ${idx:-0} (${#URLS[@]} URL(s) cada ${INTERVAL}s)"
}

# Arranque sin sesion: abre SOLA la ventana de login (sin preguntar),
# espera a que se detecte el login y reanuda el ciclo invisible.
auto_login_from_startup() {
  echo ""
  echo "El dashboard no esta autenticado (primera vez o sesion nueva)."
  echo "Abriendo la ventana para login..."
  dash_stop
  sleep 2
  dash_boot true || { echo "ERROR: no se pudo abrir la ventana." >&2; exit 1; }
  echo ""
  echo "Logueate en el dashboard (SSO + 2FA)."
  echo "No necesitas avisarme: apenas termine el login, sigo solo."
  wait_for_login
  echo "Reanudando ciclo invisible..."
  dash_stop
  sleep 2
  dash_boot false || { echo "ERROR: no se pudo reanudar el navegador." >&2; exit 1; }
  echo "Ciclo invisible reanudado."
}

# Sesion expirada a mitad de ciclo: resumen y cierre directo (sin preguntar).
expiry_close() {
  echo ""
  echo "La sesion expiro."
  print_summary "sesion expirada"
  dash_stop
  echo "Adios."
  exit 0
}

dash_refresh() {
  # Refresco por HTTP: cierra todas las pestanas y abre la siguiente URL.
  # En etapa: Chrome ni se entera (no activa ventanas, no roba foco).
  local next="$1"
  local ids
  ids="$(curl -s --max-time 5 "http://localhost:$PORT/json/list" \
        | grep -o '"id": *"[^"]*"' \
        | sed -E 's/.*"id": *"([^"]*)"/\1/')"
  while IFS= read -r id; do
    [[ -z "$id" ]] && continue
    curl -s -X PUT --max-time 5 "http://localhost:$PORT/json/close/${id}" >/dev/null 2>&1
  done <<< "$ids"
  local enc
  enc="$(urlencode "$next")"
  curl -s -X PUT --max-time 10 "http://localhost:$PORT/json/new?${enc}" >/dev/null 2>&1
  # Mostramos índex + ruta base (cortamos antes del filtro base64, son
  # decenas de caracteres ilegibles). La URL COMPLETA sí se navega.
  local base="${next%%\?*}"
  echo "   refresca > ${base}"
  if [[ "${next}" == *"?ou="* ]]; then
    local dom="${next#*ou=}"
    dom="${dom%%&*}"
    echo "               dashboard $dom"
  fi
}

# --- Acciones -----------------------------------------------------------
[[ "$STOP" == true ]] && { dash_stop; exit 0; }

# Modo WINDOW (login / ver): detiene el invisible y abre ventana headed.
if [[ "$LOG" == true || "$SHOW" == true ]]; then
  dash_boot true || exit 1
  echo ""
  echo "Ventana del navegador-dashboard abierta."
  if [[ "$LOG" == true ]]; then
    echo "Logueate en el dashboard (SSO + 2FA, una sola vez)."
    echo "Cuando termines, cierra o deja la ventana y corre:"
  else
    echo "Para ver el dashboard. Cuando termines, corre:"
  fi
  echo "   ./keepdash.sh   -> vuelve al ciclo invisible (headless)."
  exit 0
fi

# Once: un solo refresco, invisible.
if [[ "$ONE" == true ]]; then
  dash_boot false || exit 1
  dash_refresh "${URLS[0]}"
  exit 0
fi

# --- Modo normal: ciclo invisible (headless) ---------------------------
dash_boot false || exit 1
echo "Navegador-dashboard invisible arriba."

# Espera de login en headless: primera vez, si pide sesion, abre SOLA
# la ventana de login y reanuda el ciclo al detectarlo. La segunda vez
# (sesion guardada en .dash-profile/) entra directo al ciclo.
sleep 3
if dash_needs_auth; then
  auto_login_from_startup
fi

echo "Alternando invisible. Ciclo: ${INTERVAL}s, ${#URLS[@]} URL(s)."
[[ "$DURATION_MINS" -gt 0 ]] && echo "Duracion: ${DURATION_MINS} min (sale solo al cumplirse)."
echo "Para detener:      ./keepdash.sh --stop"
echo "Para ver/login:    ./keepdash.sh --login"
echo "---"

trap 'print_summary "interrumpido (Ctrl+C)"; dash_stop; echo "Adios."; exit 0' INT
START_TS="$(date +%s)"
START_STR="$(date '+%H:%M:%S')"
idx=0
while true; do
  # Chequeo de duracion: si se cumplio el tiempo, resumen y cierre directo.
  if [[ "$DURATION_MINS" -gt 0 ]] && (( $(date +%s) - START_TS >= DURATION_MINS * 60 )); then
    print_summary "tiempo cumplido (${DURATION_MINS} min)"
    dash_stop
    echo "Adios."
    exit 0
  fi
  # Chequeo de sesion expirada: redirect a login → resumen y cierre directo.
  if dash_needs_auth; then
    expiry_close
  fi
  url="${URLS[$((idx % ${#URLS[@]}))]}"
  ts="$(date '+%H:%M:%S')"
  echo "[$ts]"
  dash_refresh "$url"
  idx=$((idx + 1))
  sleep "$INTERVAL"
done