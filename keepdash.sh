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
#    ./keepdash.sh --login   -> abre la VENTANA dedicada; te logueas UNA vez.
#    ./keepdash.sh            -> de ahi en mas: cicla en headless (invisible).
#
#  Uso:
#    ./keepdash.sh               -> ciclo en headless, invisible (120s default).
#    ./keepdash.sh --login       -> abre ventana headed para login (o para ver).
#    ./keepdash.sh -t 300        -> intervalo 5 min.
#    ./keepdash.sh -u urls.txt   -> URLs desde archivo.
#    ./keepdash.sh --once        -> un solo refresco (prueba).
#    ./keepdash.sh --stop        -> apaga la instancia dedicada.
#
#  Flags:
#    -t <seg>   intervalo entre refrescos (default: config.conf)
#    -u <file>  archivo con una URL por linea
#    -h         ayuda
# ============================================================

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
PROFILE_DIR="$SCRIPT_DIR/.dash-profile"      # perfil dedicado (privado, gitignored)
PORT=9222                                     # puerto local de control (CDP)
INTERVAL=120

# URL por default si no hay urls.txt ni -u <archivo>.
DEFAULT_URLS=(
  "https://www.kyndryl.com/bridge/aiops/home"
)

# --- CONFIG (si existe): tomamos solo INTERVAL como default ---
CONFIG="$SCRIPT_DIR/config.conf"
if [[ -f "$CONFIG" ]]; then
  _iv="$(sed -n 's/^INTERVAL=\([0-9]*\).*/\1/p' "$CONFIG" | head -1)"
  [[ -n "$_iv" ]] && INTERVAL="$_iv"
fi

usage() { sed -n '10,32p' "$0"; exit 0; }

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
while getopts "t:u:h" opt; do
  case "$opt" in
    t) INTERVAL="$OPTARG" ;;
    u) URL_FILE="$OPTARG" ;;
    h) usage ;;
    *) usage ;;
  esac
done
shift $((OPTIND - 1))

if [[ -n "${URL_FILE:-}" ]]; then
  if [[ ! -f "$URL_FILE" ]]; then
    echo "ERROR: archivo '$URL_FILE' no existe" >&2; exit 1
  fi
else
  # Por defecto: si existe urls.txt en el directorio del script, úsalo.
  # Así el ciclo corre tus dashboards reales sin pasar -u cada vez.
  if [[ -f "$SCRIPT_DIR/urls.txt" ]]; then
    URL_FILE="$SCRIPT_DIR/urls.txt"
  fi
fi

if [[ -n "${URL_FILE:-}" ]]; then
  URLS=()
  while IFS= read -r line; do
    line="${line%%#*}"
    line="$(printf '%s' "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ -n "$line" ]] && URLS+=("$line")
  done < "$URL_FILE"
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
  # ¿Alguna pestana quedo en la pagina de login (login.kyndryl.com / okta)?
  curl -s --max-time 5 "http://localhost:$PORT/json/list" 2>/dev/null \
    | grep -qE 'login\.|okta'
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

# Espera de login en headless: si pide sesion, NO hay ventana que mostrar.
sleep 3
if dash_needs_auth; then
  echo ""
  echo "El dashboard pide autenticacion (SSO + 2FA) pero el modo es invisible."
  echo "Corre para autenticarte:  ./keepdash.sh --login"
  echo "Luego volve a correr:     ./keepdash.sh"
  dash_stop
  exit 1
fi

echo "Alternando invisible. Ciclo: ${INTERVAL}s, ${#URLS[@]} URL(s)."
echo "Para detener:      ./keepdash.sh --stop"
echo "Para ver/login:    ./keepdash.sh --login"
echo "---"

trap 'echo; echo "Detenido."; dash_stop; echo "Adios."; exit 0' INT
idx=0
while true; do
  if dash_needs_auth; then
    echo ""
    echo "La sesion expiro. Corre  ./keepdash.sh --login  para autenticar de nuevo."
    dash_stop
    exit 1
  fi
  url="${URLS[$((idx % ${#URLS[@]}))]}"
  ts="$(date '+%H:%M:%S')"
  echo "[$ts]"
  dash_refresh "$url"
  # Chequeo IMMEDIATO: si el refresh aterrizó en login, abortá ahora.
  # (el chequeo de arriba solo tapa la expiración previa al loop)
  if dash_needs_auth; then
    echo ""
    echo "La sesion expiro justo al refrescar. Corre  ./keepdash.sh --login."
    dash_stop
    exit 1
  fi
  idx=$((idx + 1))
  sleep "$INTERVAL"
done