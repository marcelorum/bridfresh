#!/usr/bin/env bash
# ============================================================
#  Session Keep-Alive — macOS nativo
#  Evita los plugins detectables. Mantiene viva la sesion
#  real de tu navegador rotando entre URLs.
#
#  Uso:
#    ./keepalive.sh                       -> usa config.conf
#    ./keepalive.sh -c -f -t 300 urls.txt -> Chrome+Firefox, 5 min, URLs desde archivo
#    ./keepalive.sh -s https://miweb.com/a -> solo Safari, cicla esa URL
#    ./keepalive.sh -c -u urls.txt -t 120 -> Chrome, archivo de URLs, 2 min
#    ./keepalive.sh --list                -> muestra estado, no cicla
#    ./keepalive.sh --once 2              -> prueba manual: usa el index 2 de URLS
#
#  Flags:
#    -c        usa Google Chrome
#    -f        usa Firefox
#    -s        usa Safari
#    -t <seg>  intervalo entre rotaciones (default: config.conf)
#    -u <file> archivo .txt con una URL por linea
#    -h        ayuda
# ============================================================

set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="$SCRIPT_DIR/config.conf"

# --- Defaults seguros ---
URLS=()
INTERVAL=120
CHROME=false
SAFARI=false
FIREFOX=false
RELOAD_MODE="navigate"

# --- Cargar config.conf si existe (solo como default) ---
if [[ -f "$CONFIG" ]]; then
  source "$CONFIG"
fi

usage() {
  sed -n '3,24p' "$0"
  exit 0
}

# ============================================================
#  Helpers por navegador (pestana activa, sesion EXISTENTE)
# ============================================================

chrome_navigate() {
  osascript -e "tell application \"Google Chrome\"
    if (count of windows) > 0 then
      set URL of active tab of front window to \"$1\"
      if \"$RELOAD_MODE\" = \"force\" then
        reload active tab of front window
      end if
    end if
  end tell" >/dev/null 2>&1
}

safari_navigate() {
  osascript -e "tell application \"Safari\"
    if (count of windows) > 0 then
      set URL of current tab of front window to \"$1\"
      if \"$RELOAD_MODE\" = \"force\" then
        do JavaScript \"location.reload()\" in current tab of front window
      end if
    end if
  end tell" >/dev/null 2>&1
}

# Firefox NO expone la URL por AppleScript.
# Usamos keystroke: activa la app, enfoca la barra de direcciones y pega la URL.
firefox_navigate() {
  osascript -e "tell application \"Firefox\" to activate" \
            -e "delay 0.4" \
            -e "tell application \"System Events\"
                 keystroke \"l\" using command down
                 delay 0.2
                 keystroke \"$1\"
                 key code 36
               end tell" >/dev/null 2>&1
}

navigate_all() {
  local url="$1"
  [[ "$CHROME" == true ]]  && chrome_navigate "$url"
  [[ "$SAFARI" == true ]]  && safari_navigate "$url"
  [[ "$FIREFOX" == true ]] && firefox_navigate "$url"
}

# ============================================================
#  Parseo de flags
# ============================================================

# Extraemos --list y --once del argumento (estan antes o despues de los flags).
# --once consume el token que le sigue como <index>.
ONCE_MODE=false
LIST_MODE=false
ONCE_INDEX=""

ARGS=()
args=("$@")
i=0
while [[ $i -lt ${#args[@]} ]]; do
  case "${args[$i]}" in
    --list)
      LIST_MODE=true ;;
    --once)
      ONCE_MODE=true
      i=$((i + 1))
      if [[ $i -lt ${#args[@]} ]]; then
        ONCE_INDEX="${args[$i]}"
      fi
      ;;
    *)
      ARGS+=("${args[$i]}") ;;
  esac
  i=$((i + 1))
done

# getopts: -c -f -s -t -u -h
# Si vino algun flag de browser (-c/-f/-s), SOLO se usan esos; el config se ignora.
BROWSER_FLAG_SET=false
for arg in "${ARGS[@]}"; do
  case "$arg" in
    -c|-f|-s) BROWSER_FLAG_SET=true ;;
  esac
done
if [[ "$BROWSER_FLAG_SET" == true ]]; then
  CHROME=false
  SAFARI=false
  FIREFOX=false
fi

set -- "${ARGS[@]}"   # reparar positional desde el array filtrado
while getopts "cfsht:u:" opt; do
  case "$opt" in
    c) CHROME=true ;;
    f) FIREFOX=true ;;
    s) SAFARI=true ;;
    t) INTERVAL="$OPTARG" ;;
    u) URL_FILE="$OPTARG" ;;
    h) usage ;;
    *) usage ;;
  esac
done
shift $((OPTIND - 1))

# Quedan los posicionales tras flags: si hay una URL, se usa como fuente directa.

# --- Validaciones ---
if [[ "$(uname)" != "Darwin" ]]; then
  echo "ERROR: esto es para macOS" >&2; exit 1
fi

# Si no se paso ningun flag de browser, respetar config.conf tal cual
# (BROWSER_FLAG_SET false => se usan los valores que ya cargo el source).

# --- Fuente de URLs ---
# Prioridad: -u <archivo> > argumento posicional (URL) > config.conf
if [[ -n "$URL_FILE" ]]; then
  if [[ ! -f "$URL_FILE" ]]; then
    echo "ERROR: archivo '$URL_FILE' no existe" >&2; exit 1
  fi
  # Una URL por linea, ignorando vacias y comentarios (#)
  URLS=()
  while IFS= read -r line; do
    line="${line%%#*}"                                    # quitar comentario inline
    line="$(printf '%s' "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    [[ -n "$line" ]] && URLS+=("$line")
  done < "$URL_FILE"
elif [[ $# -gt 0 ]]; then
  # URL pasada como argumento final
  URLS=("$1")
fi

if [[ ${#URLS[@]} -eq 0 ]]; then
  echo "ERROR: no hay URLs. Usa config.conf, -u <archivo> o una URL al final." >&2
  exit 1
fi

# --- Modo listado ---
if [[ "$LIST_MODE" == true ]]; then
  echo "URLs en rotacion:"
  for i in "${!URLS[@]}"; do echo "  [$i] ${URLS[$i]}"; done
  echo "Intervalo: ${INTERVAL}s"
  echo "Browsers: Chrome=$CHROME Safari=$SAFARI Firefox=$FIREFOX"
  exit 0
fi

# --- Modo one-shot manual ---
if [[ "$ONCE_MODE" == true ]]; then
  [[ -z "$ONCE_INDEX" ]] && { echo "Uso: $0 --once <index>"; exit 1; }
  url="${URLS[$ONCE_INDEX]}"
  [[ -z "$url" ]] && { echo "ERROR: index $ONCE_INDEX no existe (max $(( ${#URLS[@]} - 1 )))" >&2; exit 1; }
  echo "Navegando [$ONCE_INDEX] -> $url"
  navigate_all "$url"
  exit 0
fi

# --- Muestra lo que va a hacer ---
echo "URLs en rotacion:"
for i in "${!URLS[@]}"; do echo "  [$i] ${URLS[$i]}"; done
echo "Intervalo: ${INTERVAL}s"
echo "Browsers: Chrome=$CHROME Safari=$SAFARI Firefox=$FIREFOX"
[[ "$#" -gt 0 && -z "$URL_FILE" ]] && echo "(URL directa: usa solo esa)"
echo "---"

# --- Loop principal ---
trap 'echo; echo "Detenido."; exit 0' INT
i=0
while true; do
  url="${URLS[$((i % ${#URLS[@]}))]}"
  ts="$(date '+%H:%M:%S')"
  echo "[$ts] -> ${url}"

  navigate_all "$url"

  i=$((i + 1))
  sleep "$INTERVAL"
done