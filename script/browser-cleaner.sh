#!/usr/bin/env bash
#
# Copyright (C) 2026 Filonux
#
# Licencia:
#   Browser-Cleaner es software libre distribuido bajo los términos de la
#   GNU General Public License versión 3 (GPLv3).
#   Consulte el archivo LICENSE para obtener el texto completo de la
#   licencia.
#
# browser-cleaner.sh — Limpiador interactivo de navegadores
# Linux Mint 22.3 (Cinnamon)
#
# Programado por Filonux
#
# Filosofía: se conserva todo lo que define al navegador y al usuario
# (perfiles, configuración, marcadores, contraseñas, extensiones, temas,
# certificados, motores de búsqueda, ajustes de sincronización) y se
# elimina todo lo que el navegador puede regenerar solo, o lo que es
# simplemente residuo de la navegación (caché, historial, cookies,
# almacenamiento web, formularios, sesiones, favicons, logs, volcados
# de fallos, telemetría, temporales, archivos de bloqueo obsoletos y
# archivos WAL/SHM huérfanos).
#
# Navegadores soportados, detectando automáticamente si están instalados
# como paquete .deb nativo, Flatpak o Snap (Mint no trae Snap por defecto,
# pero se detecta igualmente por si el usuario lo instaló manualmente):
#
#   Motor Firefox    : Firefox, LibreWolf, Tor Browser, Waterfox, Floorp,
#                      Zen Browser
#   Motor Chromium   : Chromium, Google Chrome, Brave, Vivaldi, Opera, Edge
#   Motor QtWebEngine: Falkon
#   Motor WebKitGTK  : GNOME Web (Epiphany)
#
# Uso:   ./browser-cleaner.sh             (modo interactivo, con menús)
#        ./browser-cleaner.sh --help      (muestra la ayuda y termina)
#        ./browser-cleaner.sh --version   (muestra la versión instalada y termina)
#
# Changelog:
#   3.8.0 - La caché externa (fuera del perfil, bajo ~/.cache/...) ahora
#            se borra de verdad: en Firefox/LibreWolf estaba registrada
#            pero nunca se usaba, y en toda la familia Chromium (Chrome,
#            Chromium, Brave, Vivaldi, Opera, Edge) no estaba ni
#            registrada. "Solo caché" y las limpiezas rápida/completa/
#            profunda ya recuperan ese espacio en los tres formatos
#            (paquete, Flatpak, Snap).
#   3.7.1 - resolve_librewolf_fallback ya no se queda solo en el primer
#            nivel de cada carpeta candidata: ahora busca profiles.ini o
#            un perfil ya usado (prefs.js) hasta 4 niveles más abajo, así
#            que un AppImage portable (carpeta ".home") con el perfil
#            anidado varias capas por debajo ya se detecta.
#   3.7.0 - LibreWolf: nueva búsqueda de respaldo, acotada a $HOME con
#            profundidad 4, para cuando ninguna ruta fija coincide
#            (AppImage integrado, XDG_CONFIG_HOME distinto al usado por
#            el navegador, empaquetados atípicos): acepta la primera
#            carpeta "*librewolf*" que tenga un perfil real
#            (resolve_librewolf_fallback). Las rutas nativas ya
#            registradas se contrastaron contra la documentación oficial
#            de LibreWolf: eran correctas, el hueco era no tener una
#            última red de seguridad cuando ninguna aplica.
#   3.6.0 - Detección de Firefox y LibreWolf nativos ampliada a sus rutas
#            XDG (~/.config/mozilla/firefox desde Firefox 147, nov. 2025;
#            ~/.config/librewolf/librewolf, documentado por el propio
#            LibreWolf) y, en LibreWolf, también ~/.mozilla/librewolf,
#            visto en paquetes recientes. Cuando hay más de una candidata
#            instalada gana la que ya tenga un perfil real, no la primera
#            que exista (resolve_firefox_base). El descubrimiento de
#            perfiles ahora lee profiles.ini en vez de solo listar
#            subcarpetas, así que también encuentra perfiles reubicados
#            con el gestor de perfiles (Path absoluto).
#   3.5.2 - Cada sentencia de las funciones que tocan sqlite (historial,
#            permisos temporales, formularios/tarjetas) se ejecuta ahora en
#            su propia conexión: una tabla ausente en cierta versión ya no
#            impide que el VACUUM final libere el espacio. "Solo cachés" en
#            navegadores Chromium limpia también el caché de componentes/
#            extensiones, igual que Limpieza rápida. La vista previa ya no
#            sobrestima símlinks a archivos sueltos (solo se sigue el
#            destino real cuando es un directorio, igual que al borrar).
#            Reemplazo de Preferences en la misma carpeta que el original
#            (mv atómico, sin cruzar de sistema de archivos) y con sus
#            mismos permisos.
#   3.5.1 - Se retira la cabecera de metadatos de Scriptya (MENU/
#            DESCRIPTION/CONFIRM/TERMINAL/SUDO, añadida en 3.5.0): con
#            TERMINAL: true se abría una segunda terminal vacía al
#            lanzar el script desde ese menú.
#   3.5.0 - Versión en formato semver (X.Y.Z) y flag --version/-v; los
#            argumentos no reconocidos ahora terminan con error en vez de
#            abrir igualmente el menú. Copia de seguridad (.bak) también
#            antes de depurar los permisos temporales de Firefox, como ya se
#            hacía con places.sqlite/Web Data/Preferences. Metadatos de
#            Scriptya (MENU/DESCRIPTION/CONFIRM/TERMINAL/SUDO) justo después
#            del shebang, para integrarse en su menú sin edición manual.
#            SUDO: false a propósito (nunca como root).
#   3.4 - Nombre del proyecto unificado a "Browser-Cleaner" (con guion, sin
#         espacio) en el título mostrado y en la cabecera de licencia.
#   3.3 - Copia de seguridad (.bak, se sobrescribe, sin acumular) justo
#         antes de tocar places.sqlite, Web Data o Preferences. Trap que
#         detiene el spinner de progreso si el script se interrumpe
#         (Ctrl+C) a media operación sqlite. El aviso de "no ejecutar como
#         root" se muestra una sola vez por ejecución en vez de en cada
#         vuelta del menú.
#   3.2 - Instalación automática de sqlite3/jq vía apt si faltan (con
#         confirmación del usuario). El flujo interactivo vive dentro de
#         un bucle en main() y vuelve al selector de navegadores al
#         terminar cada limpieza; solo se sale con "0) Salir" o "q".
#   3.1 - Detección de LibreWolf instalado vía Flatpak (perfil en
#         ~/.var/app/io.gitlab.librewolf-community/.librewolf, no en
#         ~/.librewolf).
#
set -uo pipefail
IFS=$'\n\t'

# ---------------------------------------------------------------------------
# Presentación
# ---------------------------------------------------------------------------
SCRIPT_NAME="Browser-Cleaner"
SCRIPT_VERSION="3.8.0"  # semver (MAJOR.MINOR.PATCH); ver también flag --version
SCRIPT_AUTHOR="Filonux"
OS_LABEL="Linux Mint 22.3 (Cinnamon)"

C_RESET=$'\033[0m'
C_BOLD=$'\033[1m'
C_GREEN=$'\033[0;32m'
C_RED=$'\033[0;31m'
C_YELLOW=$'\033[0;33m'
C_CYAN=$'\033[0;36m'
C_GRAY=$'\033[0;90m'
OK="${C_GREEN}✓${C_RESET}"
BAD="${C_RED}✗${C_RESET}"

SQLITE_BIN="$(command -v sqlite3 || true)"
JQ_BIN="$(command -v jq || true)"

# Modo vista previa: las funciones de limpieza miden lo que borrarían sin
# tocar archivos. Se usa antes de operaciones irreversibles para mostrar
# un resumen y pedir confirmación explícita antes del borrado real.
DRY_RUN=0

# Reservado para un futuro modo no interactivo (cron, flags --yes/--force-close).
# Aún no implementado; de momento solo decide si se dibuja el spinner.
NONINTERACTIVE=0

# PID del spinner de progreso activo (ver spinner_start/spinner_stop).
SPINNER_PID=""

# Total acumulado (bytes) liberados en la ejecución actual.
GRAND_TOTAL=0

# Evita repetir la pregunta de instalación de sqlite3/jq si el usuario ya
# la rechazó en esta misma ejecución (ver ensure_tool).
SQLITE_INSTALL_DECLINED=0
JQ_INSTALL_DECLINED=0

# Registro de la sesión, para poder auditar el espacio liberado.
LOG_DIR="$HOME/.cache/browser-cleaner"
LOG_FILE="$LOG_DIR/browser-cleaner.log"
log_line() {
    mkdir -p "$LOG_DIR" 2>/dev/null || return 0
    printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG_FILE" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Utilidades genéricas
# ---------------------------------------------------------------------------

# Recorta espacios/tabs al principio y al final de "$1". Necesario porque
# IFS=$'\n\t' (ver más abajo) hace que "read" ya no los descarte por
# defecto; todas las lecturas de los menús pasan por aquí antes de comparar.
trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

# Envoltorio de "read -rp": si la entrada no está disponible (EOF, stdin
# cerrado o redirigida desde /dev/null) termina el script con un aviso en
# vez de dejar el menú reintentando sin parar. Uso: ask_input VAR "prompt"
ask_input() {
    if ! read -rp "$2" "$1"; then
        echo
        echo -e "${C_RED}Entrada no disponible; terminando.${C_RESET}" >&2
        exit 1
    fi
}

human_size() {
    local bytes="${1:-0}"
    awk -v b="$bytes" 'BEGIN{
        if (b < 0) b = 0
        split("B KB MB GB TB PB", u, " ")
        i = 1
        while (b >= 1024 && i < 6) { b /= 1024; i++ }
        printf "%.2f %s", b, u[i]
    }'
}

# Tamaño en bytes de un archivo o directorio (0 si no existe o "du" no
# puede leerlo). Siempre devuelve un entero válido para no romper las
# sumas aritméticas posteriores. Si la ruta es un symlink a un directorio,
# mide el destino real (du no sigue symlinks por defecto).
path_size() {
    local p="$1"
    [[ -e "$p" || -L "$p" ]] || { echo 0; return; }
    local target="$p"
    if [[ -L "$p" ]]; then
        local real
        real="$(readlink -f -- "$p" 2>/dev/null || true)"
        [[ -n "$real" && -d "$real" ]] && target="$real"
    fi
    local out
    out="$(du -sb -- "$target" 2>/dev/null | cut -f1)"
    [[ "$out" =~ ^[0-9]+$ ]] && echo "$out" || echo 0
}

# Elimina archivo/directorio de forma segura. Devuelve bytes liberados.
# Si es un symlink a un directorio (algunos empaquetados redirigen la
# caché fuera del perfil así), borra también el destino real, no solo el enlace.
remove_path() {
    local p="$1"
    local size=0
    [[ -e "$p" || -L "$p" ]] || { echo 0; return; }
    size=$(path_size "$p")
    # Vista previa: se informa el tamaño que se liberaría sin borrar nada.
    # Reutilizar esta misma función garantiza que coincide con el borrado real.
    if (( DRY_RUN )); then
        echo "$size"
        return
    fi
    if [[ -L "$p" ]]; then
        local real
        real="$(readlink -f -- "$p" 2>/dev/null || true)"
        if [[ -n "$real" && -d "$real" ]]; then
            rm -rf -- "$real" 2>/dev/null || true
        fi
        rm -f -- "$p" 2>/dev/null || true
    else
        rm -rf -- "$p" 2>/dev/null || true
    fi
    echo "$size"
}

# Elimina una lista de rutas (puede incluir inexistentes). Devuelve bytes liberados.
remove_paths() {
    local total=0
    local p
    for p in "$@"; do
        total=$(( total + $(remove_path "$p") ))
    done
    echo "$total"
}

# Elimina archivos que coincidan con un patrón glob. Devuelve bytes liberados.
remove_glob() {
    local pattern="$1"
    local total=0
    local f
    shopt -s nullglob dotglob
    for f in $pattern; do
        total=$(( total + $(remove_path "$f") ))
    done
    shopt -u nullglob dotglob
    echo "$total"
}

# Elimina archivos -wal/-shm cuya base de datos principal ya no existe.
clean_orphan_wal_shm() {
    local dir="$1"
    local total=0
    [[ -d "$dir" ]] || { echo 0; return; }
    local f base
    while IFS= read -r f; do
        base="${f%-wal}"
        base="${base%-shm}"
        if [[ ! -f "$base" ]]; then
            total=$(( total + $(remove_path "$f") ))
        fi
    done < <(find "$dir" -maxdepth 1 -type f \( -name "*-wal" -o -name "*-shm" \) 2>/dev/null)
    echo "$total"
}

# Ejecuta una o más sentencias sqlite contra una base de datos, cada una en
# su propia conexión: si una falla (p. ej. tabla ausente según la versión
# del navegador), sqlite3 detiene ahí el resto de UN MISMO lote, así que
# separarlas garantiza que las demás —y el VACUUM final— se ejecuten igual.
sqlite_exec() {
    local db="$1"; shift
    [[ -n "$SQLITE_BIN" ]] || return 1
    [[ -f "$db" ]] || return 0
    local stmt
    for stmt in "$@"; do
        "$SQLITE_BIN" "$db" "$stmt" >/dev/null 2>&1
    done
    return 0
}

# Copia de seguridad silenciosa (.bak, se sobrescribe) antes de una
# modificación irreversible. Es best-effort: un fallo al copiar no aborta
# la limpieza.
backup_before_write() {
    local f="$1"
    [[ -f "$f" ]] || return 0
    cp -f -- "$f" "${f}.bak" 2>/dev/null || true
}

log_warn() { echo -e "  ${C_YELLOW}⚠ $*${C_RESET}" >&2; }
log_skip() { echo -e "  ${C_GRAY}– $*${C_RESET}"; }

# ---------------------------------------------------------------------------
# Instalación automática de herramientas opcionales (sqlite3, jq)
# ---------------------------------------------------------------------------
# sqlite3 y jq no son dependencias estrictas: sin ellas, cada función de
# limpieza que las necesita omite esa categoría concreta para no arriesgar
# marcadores, motores de búsqueda ni el resto de la configuración. Se
# ofrece instalarlas vía apt (una vez por herramienta y por vuelta de
# menú, ver main()); si el usuario rechaza o la instalación falla, el
# script no aborta, simplemente omite esa categoría de limpieza.
ensure_tool() {
    local bin_name="$1" pkg_name="$2" var_name="$3" reason="$4"
    local current
    current="$(command -v "$bin_name" || true)"
    if [[ -n "$current" ]]; then
        printf -v "$var_name" '%s' "$current"
        return 0
    fi

    echo
    echo -e "${C_YELLOW}⚠ '${bin_name}' no está instalado${C_RESET} (se necesita ${reason})."

    if ! [[ -t 0 ]]; then
        log_warn "No hay una terminal interactiva para confirmar la instalación: se omite '${bin_name}' (esa categoría se saltará)."
        return 1
    fi
    if ! command -v apt-get >/dev/null 2>&1; then
        log_warn "No se encontró 'apt-get' en este sistema: instala '${pkg_name}' manualmente para una limpieza completa."
        return 1
    fi

    local confirm
    ask_input confirm "¿Instalar '${pkg_name}' automáticamente ahora (apt-get install ${pkg_name})? [S/n]: "
    confirm="$(trim "$confirm")"
    case "$confirm" in
        n|N|no|No|NO)
            log_warn "Instalación de '${bin_name}' omitida: esa categoría de limpieza se saltará."
            case "$bin_name" in
                sqlite3) SQLITE_INSTALL_DECLINED=1 ;;
                jq)      JQ_INSTALL_DECLINED=1 ;;
            esac
            return 1
            ;;
    esac

    local sudo_cmd=""
    if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
        if command -v sudo >/dev/null 2>&1; then
            sudo_cmd="sudo"
        else
            log_warn "No se encontró 'sudo' y el script no corre como root: no se puede instalar '${bin_name}' automáticamente."
            return 1
        fi
    fi

    echo -e "${C_CYAN}Instalando '${pkg_name}'... (puede pedir tu contraseña de sudo)${C_RESET}"
    if ! $sudo_cmd apt-get install -y "$pkg_name"; then
        echo -e "${C_GRAY}Falló; actualizando el índice de paquetes (apt-get update) y reintentando...${C_RESET}"
        $sudo_cmd apt-get update || true
        $sudo_cmd apt-get install -y "$pkg_name" || true
    fi

    current="$(command -v "$bin_name" || true)"
    if [[ -n "$current" ]]; then
        printf -v "$var_name" '%s' "$current"
        echo -e "${OK} '${bin_name}' instalado correctamente."
        return 0
    fi

    log_warn "No se ha podido instalar '${bin_name}'. Esa categoría de limpieza se saltará para no arriesgar datos."
    return 1
}

# ---------------------------------------------------------------------------
# Indicador de progreso (spinner)
# ---------------------------------------------------------------------------
# Algunas operaciones sqlite (VACUUM sobre historiales grandes) pueden
# tardar sin dar señal de que el script sigue vivo. Se dibuja en stderr
# para no contaminar el stdout que usan otras funciones como canal de
# datos (protocolo "categoria:bytes" leído por clean_browser).
spinner_start() {
    local msg="$1"
    [[ -t 2 && "$NONINTERACTIVE" -eq 0 ]] || return 0
    (
        local chars='-\|/'
        local i=0
        while true; do
            i=$(( (i + 1) % 4 ))
            printf '\r  %s %s ' "${chars:$i:1}" "$msg" >&2
            sleep 0.12
        done
    ) &
    SPINNER_PID=$!
    disown "$SPINNER_PID" 2>/dev/null || true
}

spinner_stop() {
    [[ -n "$SPINNER_PID" ]] || return 0
    kill "$SPINNER_PID" 2>/dev/null || true
    wait "$SPINNER_PID" 2>/dev/null || true
    SPINNER_PID=""
    printf '\r%*s\r' 70 "" >&2
}

# Sin esta trap, un Ctrl+C a media operación sqlite dejaría el spinner
# huérfano imprimiendo sin fin (ignora SIGINT por defecto como job en
# segundo plano). Se dispara también al salir por esa vía y lo detiene.
trap spinner_stop EXIT
trap 'echo -e "\n${C_YELLOW}Interrumpido por el usuario.${C_RESET}"; exit 130' INT

# Ejecuta una operación sqlite potencialmente lenta (VACUUM) mostrando un
# spinner mientras dura. En modo vista previa (DRY_RUN) no ejecuta nada:
# el valor a devolver lo decide quien llama, antes/después de esta función.
sqlite_exec_slow() {
    local db="$1" msg="$2"; shift 2
    (( DRY_RUN )) && return 0
    spinner_start "$msg"
    sqlite_exec "$db" "$@"
    spinner_stop
    return 0
}

# ---------------------------------------------------------------------------
# Caché real, separada del perfil
# ---------------------------------------------------------------------------
# En Linux, Firefox y Chromium (y casi todos sus derivados) NO guardan la
# caché dentro del perfil: usan una ruta aparte basada en XDG_CACHE_HOME
# (p. ej. ~/.cache/mozilla/firefox/<perfil>, ~/.cache/chromium/<perfil>),
# con su equivalente dentro de Flatpak/Snap. Falkon/GNOME Web ya usaban
# V_CACHE_CANDIDATES (una única ruta fija); Firefox/Chromium necesitan
# además el nombre del perfil, así que usan su propio mapa (V_CACHE_BASE).
#
# NOTA: debe ir definido ANTES del registro de navegadores de más abajo, ya
# que esas secciones llaman a register_cache_dir()/register_cache_base() al
# leerse el script; si se definiera después, esas llamadas fallarían.
declare -A V_CACHE_CANDIDATES=()
declare -A V_CACHE_DIR_CACHE=()
declare -A V_CACHE_BASE=()

register_cache_dir() {
    local id="$1" candidates="$2"
    V_CACHE_CANDIDATES[$id]="$candidates"
}

register_cache_base() {
    local id="$1" candidates="$2"
    V_CACHE_BASE[$id]="$candidates"
}

resolve_cache_dir() {
    local id="$1"
    if [[ -n "${V_CACHE_DIR_CACHE[$id]+x}" ]]; then
        echo "${V_CACHE_DIR_CACHE[$id]}"
        return
    fi
    local resolved="" c
    while IFS= read -r c; do
        [[ -n "$c" && -d "$c" ]] && { resolved="$c"; break; }
    done <<< "${V_CACHE_CANDIDATES[$id]:-}"
    V_CACHE_DIR_CACHE[$id]="$resolved"
    echo "$resolved"
}

# Rutas candidatas (una por línea) donde puede vivir la caché real de un
# perfil de Firefox o Chromium: cada base de V_CACHE_BASE + el mismo nombre
# de carpeta que tiene el perfil "$p". No hace falta resolver de antemano
# cuál existe: remove_path ya ignora en silencio las que no.
profile_cache_dirs() {
    local id="$1" p="$2"
    local name; name="$(basename -- "$p")"
    local base
    while IFS= read -r base; do
        [[ -n "$base" ]] && echo "$base/$name"
    done <<< "${V_CACHE_BASE[$id]:-}"
}

# ---------------------------------------------------------------------------
# Registro de navegadores y sus variantes de instalación
# ---------------------------------------------------------------------------
# Cada navegador puede existir como paquete .deb nativo, Flatpak o Snap, y
# cada formato guarda el perfil en una ruta distinta; en tiempo de
# ejecución solo se muestran al usuario las variantes que de verdad
# existen en el equipo.
#
# V_LABEL[id]       Nombre mostrado al usuario
# V_FAMILY[id]      "firefox" o "chromium" (motor de perfiles / limpieza)
# V_KIND[id]        "native" | "flatpak" | "snap" | "any" — distingue
#                    procesos en ejecución cuando dos variantes comparten
#                    nombre de proceso (p. ej. Brave nativo y Flatpak a la vez)
# V_PROC[id]        Patrón amplio (pgrep -f); se afina por V_KIND mirando
#                    /proc/<pid>/cmdline
# V_CANDIDATES[id]  Rutas candidatas (una por línea); se usa la primera que
#                    exista, salvo en el motor Firefox, donde se prefiere la
#                    primera que ya tenga perfiles (ver resolve_firefox_base)
V_ORDER=()
declare -A V_LABEL=()
declare -A V_FAMILY=()
declare -A V_KIND=()
declare -A V_PROC=()
declare -A V_CANDIDATES=()

register_variant() {
    local id="$1" label="$2" family="$3" kind="$4" proc="$5" candidates="$6"
    V_ORDER+=("$id")
    V_LABEL[$id]="$label"
    V_FAMILY[$id]="$family"
    V_KIND[$id]="$kind"
    V_PROC[$id]="$proc"
    V_CANDIDATES[$id]="$candidates"
}

# --- Motor Firefox ----------------------------------------------------------
# Firefox 147 (nov. 2025) añadió soporte XDG: los perfiles NUEVOS se crean
# en ~/.config/mozilla/firefox, y ~/.mozilla/firefox solo se sigue usando
# si ya existía de antes. Un Mint recién instalado puede tener el perfil
# real únicamente en la ruta XDG, así que se listan ambas candidatas
# (resolve_firefox_base(), más abajo, elige la que de verdad tenga
# perfiles, no solo la primera que exista).
register_variant firefox_deb "Firefox" firefox native "firefox" \
"$HOME/.mozilla/firefox
${XDG_CONFIG_HOME:-$HOME/.config}/mozilla/firefox"
register_cache_base firefox_deb "${XDG_CACHE_HOME:-$HOME/.cache}/mozilla/firefox"

register_variant firefox_flatpak "Firefox (Flatpak)" firefox flatpak "firefox" \
"$HOME/.var/app/org.mozilla.firefox/.mozilla/firefox
$HOME/.var/app/org.mozilla.firefox/.config/mozilla/firefox"
register_cache_base firefox_flatpak "$HOME/.var/app/org.mozilla.firefox/cache/mozilla/firefox"

register_variant firefox_snap "Firefox (Snap)" firefox snap "firefox" \
"$HOME/snap/firefox/common/.mozilla/firefox"
register_cache_base firefox_snap "$HOME/snap/firefox/common/.cache/mozilla/firefox"

# LibreWolf: aún más variable que Firefox. El Flatpak (Flathub,
# "io.gitlab.librewolf-community") usa
# ~/.var/app/io.gitlab.librewolf-community/.librewolf, NO ~/.librewolf. El
# nativo históricamente usaba ~/.librewolf directamente; la documentación
# oficial de LibreWolf ya recoge además ~/.config/librewolf/librewolf como
# ruta XDG en distros que la soportan, y algunos paquetes recientes han
# usado por error ~/.mozilla/librewolf: se comprueban las tres (las tres
# contrastadas contra la documentación oficial). Si ninguna coincide,
# resolve_librewolf_fallback() hace una última búsqueda por nombre.
register_variant librewolf_deb "LibreWolf" firefox native "librewolf" \
"$HOME/.librewolf
${XDG_CONFIG_HOME:-$HOME/.config}/librewolf/librewolf
$HOME/.mozilla/librewolf"
# No hay una única convención documentada para el nombre de producto que
# usa LibreWolf bajo XDG_CACHE_HOME: se prueban las variantes plausibles.
register_cache_base librewolf_deb \
"${XDG_CACHE_HOME:-$HOME/.cache}/librewolf/librewolf
${XDG_CACHE_HOME:-$HOME/.cache}/librewolf
${XDG_CACHE_HOME:-$HOME/.cache}/mozilla/librewolf"

register_variant librewolf_flatpak "LibreWolf (Flatpak)" firefox flatpak "librewolf" \
"$HOME/.var/app/io.gitlab.librewolf-community/.librewolf"
register_cache_base librewolf_flatpak "$HOME/.var/app/io.gitlab.librewolf-community/cache/librewolf"

# Tor Browser (vía torbrowser-launcher, el método oficial en los repos de
# Debian/Ubuntu/Mint): la ruta exacta del perfil depende de la versión
# instalada, así que se resuelve de forma especial en resolve_config_dir()
# en lugar de listar candidatas fijas aquí. Sin caché XDG separada: por
# diseño mantiene todo autocontenido dentro de su propia carpeta.
register_variant torbrowser "Tor Browser" firefox any "tor-browser/Browser/firefox" \
""

# Waterfox (fork de Firefox): misma convención de perfil en ~/.waterfox.
# Se registran nativo y Flatpak por separado, igual que LibreWolf.
register_variant waterfox_deb "Waterfox" firefox native "waterfox" \
"$HOME/.waterfox"

register_variant waterfox_flatpak "Waterfox (Flatpak)" firefox flatpak "waterfox" \
"$HOME/.var/app/net.waterfox.waterfox/.waterfox"

# Floorp (fork de Firefox, popular en Japón, disponible también para Mint
# vía Flatpak o .deb de terceros). Misma convención de perfil que Firefox.
register_variant floorp_deb "Floorp" firefox native "floorp" \
"$HOME/.floorp"

register_variant floorp_flatpak "Floorp (Flatpak)" firefox flatpak "floorp" \
"$HOME/.var/app/one.ablaze.floorp/.floorp"

# Zen Browser (fork de Firefox): tanto el instalador oficial como el
# Flatpak usan ~/.zen como raíz de perfiles. El patrón de proceso se ancla
# a ".zen/" en vez de "zen" a secas, que es demasiado genérico para
# "pgrep -f" y daría falsos positivos con cualquier otro proceso.
register_variant zen_native "Zen Browser" firefox native ".zen/zen" \
"$HOME/.zen"

register_variant zen_flatpak "Zen Browser (Flatpak)" firefox flatpak ".zen/zen" \
"$HOME/.var/app/app.zen_browser.zen/.zen"

# --- Motor Chromium ----------------------------------------------------------
register_variant chromium_deb "Chromium" chromium native "chromium" \
"$HOME/.config/chromium"
register_cache_base chromium_deb "$HOME/.cache/chromium"

register_variant chromium_flatpak "Chromium (Flatpak)" chromium flatpak "chromium" \
"$HOME/.var/app/org.chromium.Chromium/config/chromium"
register_cache_base chromium_flatpak "$HOME/.var/app/org.chromium.Chromium/cache/chromium"

register_variant chromium_snap "Chromium (Snap)" chromium snap "chromium" \
"$HOME/snap/chromium/common/chromium
$HOME/snap/chromium/current/.config/chromium"
register_cache_base chromium_snap \
"$HOME/snap/chromium/common/.cache/chromium
$HOME/snap/chromium/current/.cache/chromium"

register_variant chrome_deb "Google Chrome" chromium native "chrome" \
"$HOME/.config/google-chrome"
register_cache_base chrome_deb "$HOME/.cache/google-chrome"

register_variant chrome_flatpak "Google Chrome (Flatpak)" chromium flatpak "chrome" \
"$HOME/.var/app/com.google.Chrome/config/google-chrome"
register_cache_base chrome_flatpak "$HOME/.var/app/com.google.Chrome/cache/google-chrome"

register_variant brave_deb "Brave" chromium native "brave" \
"$HOME/.config/BraveSoftware/Brave-Browser"
register_cache_base brave_deb "$HOME/.cache/BraveSoftware/Brave-Browser"

register_variant brave_flatpak "Brave (Flatpak)" chromium flatpak "brave" \
"$HOME/.var/app/com.brave.Browser/config/BraveSoftware/Brave-Browser"
register_cache_base brave_flatpak "$HOME/.var/app/com.brave.Browser/cache/BraveSoftware/Brave-Browser"

register_variant brave_snap "Brave (Snap)" chromium snap "brave" \
"$HOME/snap/brave/common/.config/BraveSoftware/Brave-Browser
$HOME/snap/brave/current/.config/BraveSoftware/Brave-Browser"
register_cache_base brave_snap \
"$HOME/snap/brave/common/.cache/BraveSoftware/Brave-Browser
$HOME/snap/brave/current/.cache/BraveSoftware/Brave-Browser"

register_variant vivaldi_deb "Vivaldi" chromium native "vivaldi" \
"$HOME/.config/vivaldi"
register_cache_base vivaldi_deb "$HOME/.cache/vivaldi"

register_variant vivaldi_snap "Vivaldi (Snap)" chromium snap "vivaldi" \
"$HOME/snap/vivaldi/current/.config/vivaldi
$HOME/snap/vivaldi/common/.config/vivaldi"
register_cache_base vivaldi_snap \
"$HOME/snap/vivaldi/current/.cache/vivaldi
$HOME/snap/vivaldi/common/.cache/vivaldi"

register_variant opera_deb "Opera" chromium native "opera" \
"$HOME/.config/opera"
register_cache_base opera_deb "$HOME/.cache/opera"

register_variant opera_flatpak "Opera (Flatpak)" chromium flatpak "opera" \
"$HOME/.var/app/com.opera.Opera/config/opera-stable
$HOME/.var/app/com.opera.Opera/config/opera"
register_cache_base opera_flatpak \
"$HOME/.var/app/com.opera.Opera/cache/opera-stable
$HOME/.var/app/com.opera.Opera/cache/opera"

register_variant opera_snap "Opera (Snap)" chromium snap "opera" \
"$HOME/snap/opera/current/.config/opera-stable
$HOME/snap/opera/common/.config/opera-stable
$HOME/snap/opera/current/.config/opera
$HOME/snap/opera/common/.config/opera"
register_cache_base opera_snap \
"$HOME/snap/opera/current/.cache/opera-stable
$HOME/snap/opera/common/.cache/opera-stable
$HOME/snap/opera/current/.cache/opera
$HOME/snap/opera/common/.cache/opera"

register_variant edge_deb "Microsoft Edge" chromium native "microsoft-edge" \
"$HOME/.config/microsoft-edge"
register_cache_base edge_deb "$HOME/.cache/microsoft-edge"

register_variant edge_flatpak "Microsoft Edge (Flatpak)" chromium flatpak "microsoft-edge" \
"$HOME/.var/app/com.microsoft.Edge/config/microsoft-edge"
register_cache_base edge_flatpak "$HOME/.var/app/com.microsoft.Edge/cache/microsoft-edge"

# --- Motor QtWebEngine -------------------------------------------------------
# Falkon (KDE): estructura de perfil distinta a Firefox/Chromium, tratada
# como familia propia ("falkon"). Los perfiles viven en subcarpetas de
# ".../profiles/", no directamente en la carpeta de configuración.
register_variant falkon_deb "Falkon" falkon native "falkon" \
"$HOME/.config/falkon"

register_variant falkon_flatpak "Falkon (Flatpak)" falkon flatpak "falkon" \
"$HOME/.var/app/org.kde.falkon/config/falkon"

register_cache_dir falkon_deb "$HOME/.cache/falkon"
register_cache_dir falkon_flatpak "$HOME/.var/app/org.kde.falkon/cache/falkon"

# --- Motor WebKitGTK ----------------------------------------------------------
# GNOME Web / Epiphany (WebKitGTK): un único perfil por instalación, sin
# el concepto de perfiles múltiples de Firefox/Chromium, tratado como
# familia propia ("epiphany"). Se comprueban dos rutas candidatas porque
# el lugar donde guarda sus datos ha variado entre versiones.
register_variant epiphany_deb "GNOME Web (Epiphany)" epiphany native "epiphany" \
"$HOME/.local/share/epiphany
$HOME/.config/epiphany"

register_variant epiphany_flatpak "GNOME Web (Epiphany, Flatpak)" epiphany flatpak "epiphany" \
"$HOME/.var/app/org.gnome.Epiphany/data/epiphany
$HOME/.var/app/org.gnome.Epiphany/config/epiphany"

register_cache_dir epiphany_deb "$HOME/.cache/epiphany"
register_cache_dir epiphany_flatpak "$HOME/.var/app/org.gnome.Epiphany/cache/epiphany"

# ---------------------------------------------------------------------------
# Resolución de la ruta de configuración real de cada variante
# ---------------------------------------------------------------------------

declare -A V_CONFIG_DIR_CACHE=()

# El nombre de las subcarpetas de Tor Browser Launcher ha cambiado entre
# versiones, así que se busca el destino ".../TorBrowser/Data/Browser"
# en vez de asumir una ruta fija.
resolve_torbrowser_dir() {
    local base="$HOME/.local/share/torbrowser"
    [[ -d "$base" ]] || { echo ""; return; }
    find "$base" -maxdepth 8 -type d -path "*/TorBrowser/Data/Browser" 2>/dev/null | head -n1
}

# Para el motor Firefox puede haber más de una candidata "instalada" a la
# vez (p. ej. ~/.mozilla/firefox vacía y el perfil real en la ruta XDG, o
# al revés): gana la primera candidata que ya tenga un perfil real; si
# ninguna lo tiene todavía, se cae en la primera que exista como carpeta,
# para no marcar como "no instalado" algo recién instalado sin usar aún.
# (firefox_profiles se define más abajo; en bash el orden de definición no
# importa mientras exista ya cuando de verdad se invoque, y aquí solo se
# llama desde dentro de main).
resolve_firefox_base() {
    local id="$1" c first_existing=""
    while IFS= read -r c; do
        [[ -n "$c" && -d "$c" ]] || continue
        [[ -z "$first_existing" ]] && first_existing="$c"
        [[ -n "$(firefox_profiles "$c")" ]] && { echo "$c"; return; }
    done <<< "${V_CANDIDATES[$id]}"
    echo "$first_existing"
}

# Último recurso para LibreWolf: entra en juego cuando ninguna ruta fija
# tiene perfil real (AppImage portable, XDG_CONFIG_HOME distinto al que
# tenía LibreWolf al crear el perfil, empaquetados atípicos, carpeta
# presente pero vacía). Busca, acotado a profundidad 4 en $HOME,
# cualquier carpeta con "librewolf" en el nombre y, dentro de cada una,
# hasta 4 niveles más, profiles.ini o un perfil ya usado (prefs.js): un
# AppImage portable (carpeta ".home" junto al ejecutable) anida el
# perfil real varias capas por debajo de esa carpeta, así que mirar solo
# su primer nivel no basta. Excluye el árbol .var/app salvo para la
# variante Flatpak, para no mezclar el perfil de una variante con otra.
resolve_librewolf_fallback() {
    local id="$1" want_flatpak=0 d f base
    [[ "$id" == librewolf_flatpak ]] && want_flatpak=1
    while IFS= read -r d; do
        if (( want_flatpak )); then
            [[ "$d" == "$HOME/.var/app/"* ]] || continue
        else
            [[ "$d" == "$HOME/.var/app/"* ]] && continue
        fi
        f="$(find "$d" -maxdepth 4 -iname 'profiles.ini' -type f 2>/dev/null | sort | head -n1)"
        if [[ -n "$f" ]]; then
            base="$(dirname "$f")"
            [[ -n "$(firefox_profiles "$base")" ]] && { echo "$base"; return; }
        fi
        f="$(find "$d" -maxdepth 4 -iname 'prefs.js' -type f 2>/dev/null | sort | head -n1)"
        [[ -n "$f" ]] && { dirname "$(dirname "$f")"; return; }
    done < <(find "$HOME" -maxdepth 4 -iname '*librewolf*' -type d 2>/dev/null | sort)
}

resolve_config_dir() {
    local id="$1"
    if [[ -n "${V_CONFIG_DIR_CACHE[$id]+x}" ]]; then
        echo "${V_CONFIG_DIR_CACHE[$id]}"
        return
    fi
    local resolved=""
    if [[ "$id" == "torbrowser" ]]; then
        resolved="$(resolve_torbrowser_dir)"
    elif [[ "${V_FAMILY[$id]}" == "firefox" ]]; then
        resolved="$(resolve_firefox_base "$id")"
        if [[ "$id" == librewolf_* ]] && [[ -z "$(firefox_profiles "$resolved")" ]]; then
            local fb; fb="$(resolve_librewolf_fallback "$id")"
            [[ -n "$fb" ]] && resolved="$fb"
        fi
    else
        local c
        while IFS= read -r c; do
            [[ -n "$c" && -d "$c" ]] && { resolved="$c"; break; }
        done <<< "${V_CANDIDATES[$id]}"
    fi
    V_CONFIG_DIR_CACHE[$id]="$resolved"
    echo "$resolved"
}

browser_installed() {
    local id="$1"
    [[ -n "$(resolve_config_dir "$id")" ]]
}

# ---------------------------------------------------------------------------
# Detección de procesos en ejecución
# ---------------------------------------------------------------------------
# Varias variantes del mismo navegador pueden compartir nombre de proceso,
# así que se busca con un patrón amplio y se afina mirando
# /proc/<pid>/cmdline: "/snap/" es la variante Snap, ".var/app/" Flatpak,
# y si no contiene ninguna se considera nativa (V_KIND=any no distingue).
pids_for_variant() {
    local id="$1"
    local kind="${V_KIND[$id]}" broad="${V_PROC[$id]}"
    local pid cmdline
    while IFS= read -r pid; do
        # Excluye el propio script y su proceso padre: si se ejecuta desde
        # una ruta con el nombre de un navegador, su cmdline coincidiría
        # con el patrón y daría un falso positivo.
        [[ "$pid" == "$$" || "$pid" == "${PPID:-}" ]] && continue
        [[ -r "/proc/$pid/cmdline" ]] || continue
        cmdline="$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null)"
        case "$kind" in
            flatpak) [[ "$cmdline" == *"/.var/app/"* ]] && echo "$pid" ;;
            snap)    [[ "$cmdline" == *"/snap/"* ]] && echo "$pid" ;;
            native)  [[ "$cmdline" != *"/.var/app/"* && "$cmdline" != *"/snap/"* ]] && echo "$pid" ;;
            any)     echo "$pid" ;;
        esac
    done < <(pgrep -f -- "$broad" 2>/dev/null)
}

browser_running() {
    local id="$1"
    [[ -n "$(pids_for_variant "$id")" ]]
}

# Pide cerrar el navegador si está abierto. Devuelve 0 si se puede
# continuar, 1 si el usuario cancela. Solo señaliza los PID que
# pertenecen a esta variante (ver pids_for_variant).
ensure_browser_closed() {
    local id="$1"
    local label="${V_LABEL[$id]}"

    browser_running "$id" || return 0

    echo
    echo -e "${C_YELLOW}${label} está abierto.${C_RESET}"
    echo "  [1] Cerrarlo automáticamente"
    echo "  [2] Cancelar"
    local opt
    ask_input opt "Opción: "
    opt="$(trim "$opt")"
    if [[ "$opt" != "1" ]]; then
        echo -e "${C_RED}Cancelado para ${label}.${C_RESET}"
        return 1
    fi

    local pids=() pid
    while IFS= read -r pid; do
        [[ -n "$pid" ]] && pids+=("$pid")
    done < <(pids_for_variant "$id")
    (( ${#pids[@]} > 0 )) && kill "${pids[@]}" 2>/dev/null || true

    local waited=0
    while browser_running "$id" && (( waited < 10 )); do
        sleep 1
        waited=$(( waited + 1 ))
    done
    if browser_running "$id"; then
        pids=()
        while IFS= read -r pid; do
            [[ -n "$pid" ]] && pids+=("$pid")
        done < <(pids_for_variant "$id")
        (( ${#pids[@]} > 0 )) && kill -9 "${pids[@]}" 2>/dev/null || true
        sleep 1
    fi

    # Si sigue en ejecución (p. ej. estado D, poco frecuente pero posible)
    # se omite la limpieza de ESE navegador en vez de tocar archivos en uso.
    if browser_running "$id"; then
        echo -e "${C_RED}No se ha podido cerrar ${label} (sigue en ejecución). Se omite su limpieza.${C_RESET}"
        return 1
    fi

    echo -e "${OK} ${label} cerrado."
    return 0
}

# ---------------------------------------------------------------------------
# Descubrimiento de perfiles
# ---------------------------------------------------------------------------

# Los perfiles "oficiales" son los que lista profiles.ini (el mismo
# fichero que usa el propio Firefox/LibreWolf), incluyendo los que el
# usuario haya reubicado fuera de "$base" con el gestor de perfiles
# (Path absoluto, IsRelative=0). Si no hay profiles.ini o no aporta
# ninguna ruta válida, se recurre al escaneo de subcarpetas de siempre.
firefox_profiles() {
    local base="$1"
    [[ -d "$base" ]] || return 0
    local ini="$base/profiles.ini" relative path abs found=0
    if [[ -f "$ini" ]]; then
        while IFS=$'\t' read -r relative path; do
            [[ -n "$path" ]] || continue
            if [[ "$relative" == "0" ]]; then abs="$path"; else abs="$base/$path"; fi
            [[ -f "$abs/prefs.js" ]] && { echo "$abs"; found=1; }
        done < <(awk -F= '
            /^\[/ { if (p != "") print r "\t" p; p=""; r="1"; next }
            /^IsRelative/ { r=$2 }
            /^Path/ { p=$2 }
            END { if (p != "") print r "\t" p }
        ' "$ini" 2>/dev/null)
    fi
    (( found )) && return 0
    find "$base" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | while IFS= read -r d; do
        [[ -f "$d/prefs.js" ]] && echo "$d"
    done
}

chromium_profiles() {
    local base="$1"
    [[ -d "$base" ]] || return 0
    find "$base" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | while IFS= read -r d; do
        [[ -f "$d/Preferences" ]] && echo "$d"
    done
}

# Falkon guarda cada perfil como una subcarpeta de ".../profiles/"
# (por defecto suele existir un único perfil llamado "default").
falkon_profiles() {
    local base="$1"
    [[ -d "$base/profiles" ]] || return 0
    find "$base/profiles" -mindepth 1 -maxdepth 1 -type d 2>/dev/null
}

# GNOME Web / Epiphany no tiene el concepto de "varios perfiles" del mismo
# modo que Firefox/Chromium: toda la carpeta de datos ES el perfil.
epiphany_profiles() {
    local base="$1"
    [[ -d "$base" ]] && echo "$base"
}

browser_profiles() {
    local id="$1"
    local dir; dir="$(resolve_config_dir "$id")"
    [[ -n "$dir" ]] || return 0
    case "${V_FAMILY[$id]}" in
        firefox)  firefox_profiles "$dir" ;;
        chromium) chromium_profiles "$dir" ;;
        falkon)   falkon_profiles "$dir" ;;
        epiphany) epiphany_profiles "$dir" ;;
    esac
}

# ===========================================================================
# FIREFOX / LIBREWOLF / TOR BROWSER — funciones de limpieza por categoría
# (reciben la ruta del perfil; algunas también la ruta base del navegador)
# ===========================================================================

clean_firefox_cache() {
    local p="$1" id="$2"
    local total
    total=$(remove_paths \
        "$p/cache2" "$p/startupCache" "$p/shader-cache" \
        "$p/thumbnails" "$p/OfflineCache" "$p/offlineCache")
    # Caché real fuera del perfil (ver V_CACHE_BASE/profile_cache_dirs):
    # se borra la carpeta completa, no solo nombres concretos.
    local extra
    while IFS= read -r extra; do
        [[ -n "$extra" ]] && total=$(( total + $(remove_path "$extra") ))
    done < <(profile_cache_dirs "$id" "$p")
    echo "$total"
}

# Los informes de fallos y pings de telemetría pendientes viven a nivel
# de navegador (de ahí la ruta base "$base" además del perfil "$p").
# "datareporting/" sí vive dentro del perfil y guarda el estado de
# telemetría: es puramente diagnóstico y regenerable, no afecta a
# marcadores ni configuración.
clean_firefox_crash_logs() {
    local p="$1" base="$2"
    local total=0
    total=$(( total + $(remove_path "$base/Crash Reports") ))
    total=$(( total + $(remove_path "$base/Pending Pings") ))
    total=$(( total + $(remove_path "$p/datareporting") ))
    total=$(( total + $(remove_glob "$p/*.log") ))
    echo "$total"
}

# Historial: places.sqlite mezcla historial Y marcadores.
# Se borran únicamente las visitas / páginas no vinculadas a marcadores.
clean_firefox_history() {
    local p="$1"
    local db="$p/places.sqlite"
    [[ -f "$db" ]] || { echo 0; return; }
    if [[ -z "$SQLITE_BIN" ]]; then
        log_warn "sqlite3 no está instalado: no se pudo depurar el historial sin arriesgar los marcadores (se omite)."
        echo 0
        return
    fi
    local before after
    before=$(path_size "$db")
    # Vista previa: se informa el tamaño actual de places.sqlite como cota
    # máxima de lo recuperable (VACUUM nunca libera más que eso).
    if (( DRY_RUN )); then
        echo "$before"
        return
    fi
    backup_before_write "$db"
    sqlite_exec_slow "$db" "Optimizando historial de navegación (VACUUM)..." \
        "PRAGMA foreign_keys=OFF" \
        "DELETE FROM moz_historyvisits" \
        "DELETE FROM moz_places WHERE id NOT IN (SELECT fk FROM moz_bookmarks WHERE fk IS NOT NULL)" \
        "DELETE FROM moz_annos WHERE place_id NOT IN (SELECT id FROM moz_places)" \
        "DELETE FROM moz_inputhistory" \
        "VACUUM"
    after=$(path_size "$db")
    echo $(( before > after ? before - after : 0 ))
}

clean_firefox_cookies() {
    local p="$1"
    remove_paths "$p/cookies.sqlite" "$p/cookies.sqlite-wal" "$p/cookies.sqlite-shm"
}

# IndexedDB, Cache API, LocalStorage (LSNG) viven bajo storage/*.
# Se preservan los orígenes moz-extension+++ (datos de extensiones)
# y los internos (about+, chrome, indexeddb+++chrome); se borra el resto.
clean_firefox_storage() {
    local p="$1"
    local total=0
    local storage_base origin name
    for storage_base in "$p/storage/default" "$p/storage/permanent" "$p/storage/temporary"; do
        [[ -d "$storage_base" ]] || continue
        while IFS= read -r origin; do
            name="$(basename "$origin")"
            case "$name" in
                moz-extension+++*|about+*|chrome*|indexeddb+++chrome*|resource+++*)
                    continue
                    ;;
            esac
            total=$(( total + $(remove_path "$origin") ))
        done < <(find "$storage_base" -mindepth 1 -maxdepth 1 -type d 2>/dev/null)
    done
    total=$(( total + $(remove_paths \
        "$p/webappsstore.sqlite" "$p/webappsstore.sqlite-wal" "$p/webappsstore.sqlite-shm" \
        "$p/storage.sqlite" "$p/serviceworker.txt") ))
    echo "$total"
}

clean_firefox_sessions() {
    local p="$1"
    local total=0
    total=$(( total + $(remove_paths "$p/sessionstore.jsonlz4" "$p/sessionCheckpoints.json") ))
    total=$(( total + $(remove_path "$p/sessionstore-backups") ))
    echo "$total"
}

# En Firefox moderno los favicons viven en favicons.sqlite, separado
# de places.sqlite: se puede borrar entero sin tocar marcadores.
clean_firefox_favicons() {
    local p="$1"
    remove_paths "$p/favicons.sqlite" "$p/favicons.sqlite-wal" "$p/favicons.sqlite-shm"
}

clean_firefox_formdata() {
    local p="$1"
    remove_paths "$p/formhistory.sqlite" "$p/formhistory.sqlite-wal" "$p/formhistory.sqlite-shm"
}

# "Permisos temporales" (limpieza completa): solo permisos con expiración
# (sesión / temporales), se conservan los permanentes fijados por el usuario.
clean_firefox_permissions_temp() {
    local p="$1"
    local db="$p/permissions.sqlite"
    [[ -f "$db" && -n "$SQLITE_BIN" ]] || { echo 0; return; }
    local before after
    before=$(path_size "$db")
    if (( DRY_RUN )); then
        echo "$before"
        return
    fi
    backup_before_write "$db"
    sqlite_exec_slow "$db" "Depurando permisos temporales de sitios..." \
        "DELETE FROM moz_perms WHERE expireType != 0" \
        "VACUUM"
    after=$(path_size "$db")
    echo $(( before > after ? before - after : 0 ))
}

# Limpieza profunda: TODOS los permisos de sitios (incluidos los permanentes).
clean_firefox_permissions_all() {
    local p="$1"
    remove_paths "$p/permissions.sqlite" "$p/permissions.sqlite-wal" "$p/permissions.sqlite-shm" \
                 "$p/content-prefs.sqlite" "$p/content-prefs.sqlite-wal" "$p/content-prefs.sqlite-shm"
}

clean_firefox_security_state() {
    local p="$1"
    remove_path "$p/SiteSecurityServiceState.txt"
}

# "lock" y ".parentlock" son los archivos con los que Firefox detecta si
# un perfil ya está en uso; tras un cierre en frío pueden quedar huérfanos
# y provocar un aviso falso de "ya hay una ventana abierta". Solo se llama
# aquí tras confirmar que el navegador no está en ejecución (ver
# ensure_browser_closed), así que borrarlos es seguro.
clean_firefox_stale_locks() {
    local p="$1"
    remove_paths "$p/lock" "$p/.parentlock"
}

# ===========================================================================
# CHROMIUM / CHROME / BRAVE / VIVALDI / OPERA / EDGE — funciones genéricas
# (misma estructura interna de perfil en todos ellos)
# ===========================================================================

clean_chromium_cache() {
    local p="$1" id="$2"
    local total
    total=$(remove_paths \
        "$p/Cache" "$p/Cache/Cache_Data" "$p/Code Cache" "$p/GPUCache" \
        "$p/GrShaderCache" "$p/ShaderCache" "$p/DawnCache" \
        "$p/DawnGraphiteCache" "$p/DawnWebGPUCache" "$p/Media Cache")
    # Caché real fuera del perfil (ver V_CACHE_BASE/profile_cache_dirs):
    # se borra la carpeta completa, no solo nombres concretos.
    local extra
    while IFS= read -r extra; do
        [[ -n "$extra" ]] && total=$(( total + $(remove_path "$extra") ))
    done < <(profile_cache_dirs "$id" "$p")
    echo "$total"
}

# Volcados de fallos (Crashpad), logs de depuración y métricas de uso
# (BrowserMetrics, puramente diagnóstico) se guardan a nivel de navegador,
# no dentro de cada perfil.
clean_chromium_crash_logs() {
    local base="$1"
    local total=0
    total=$(( total + $(remove_path "$base/Crashpad") ))
    total=$(( total + $(remove_path "$base/BrowserMetrics") ))
    total=$(( total + $(remove_path "$base/chrome_debug.log") ))
    total=$(( total + $(remove_glob "$base/*.log") ))
    echo "$total"
}

# component_crx_cache / extensions_crx_cache guardan copias .crx del
# actualizador de componentes (Widevine, certificados raíz, listas
# adblock...) y de extensiones. Son caché pura: Chromium las regenera.
clean_chromium_component_cache() {
    local base="$1"
    remove_paths "$base/component_crx_cache" "$base/extensions_crx_cache"
}

# SingletonLock / SingletonCookie / SingletonSocket son el equivalente
# Chromium a "lock"/".parentlock" en Firefox. Tras un cierre en frío
# pueden quedar huérfanos e impedir abrir una ventana nueva; igual que en
# Firefox, solo se llama aquí tras confirmar que el proceso no corre.
clean_chromium_stale_locks() {
    local base="$1"
    remove_paths "$base/SingletonLock" "$base/SingletonCookie" "$base/SingletonSocket"
}

# El historial vive en "History" (sqlite), independiente de "Bookmarks"
# (JSON aparte): se borra sin tocar marcadores.
clean_chromium_history() {
    local p="$1"
    remove_paths \
        "$p/History" "$p/History-journal" \
        "$p/Visited Links" "$p/Top Sites" "$p/Top Sites-journal"
}

clean_chromium_cookies() {
    local p="$1"
    remove_paths \
        "$p/Cookies" "$p/Cookies-journal" \
        "$p/Network/Cookies" "$p/Network/Cookies-journal"
}

clean_chromium_storage() {
    local p="$1"
    local total=0
    # IndexedDB y "databases" (WebSQL, obsoleto) organizan sus datos en
    # una carpeta por origen: se depuran por origen, excluyendo extensiones.
    total=$(( total + $(clean_chromium_origin_dir "$p/IndexedDB") ))
    total=$(( total + $(clean_chromium_origin_dir "$p/databases") ))
    # "Local Storage"/"Session Storage" usan una única base LevelDB
    # compartida por todos los orígenes (desde Chromium 59), así que se
    # borran enteras como residuo regenerable. Los datos de extensiones
    # viven aparte ("Local/Sync Extension Settings"), nunca se tocan.
    total=$(( total + $(remove_paths \
        "$p/Local Storage" "$p/Session Storage" \
        "$p/Service Worker" "$p/File System" "$p/blob_storage" \
        "$p/shared_proto_db" "$p/Application Cache" "$p/GCM Store") ))
    echo "$total"
}

# Limpia un directorio "por origen" (IndexedDB, databases) excluyendo
# chrome-extension_* (almacenamiento propio de extensiones). Equivalente
# chromium de la exclusión moz-extension+++ de Firefox.
clean_chromium_origin_dir() {
    local dir="$1"
    local total=0
    [[ -d "$dir" ]] || { echo 0; return; }
    local entry name
    while IFS= read -r entry; do
        name="$(basename "$entry")"
        case "$name" in
            chrome-extension_*|extension_*)
                continue
                ;;
        esac
        total=$(( total + $(remove_path "$entry") ))
    done < <(find "$dir" -mindepth 1 -maxdepth 1 2>/dev/null)
    echo "$total"
}

clean_chromium_sessions() {
    local p="$1"
    remove_paths \
        "$p/Sessions" "$p/Current Session" "$p/Current Tabs" \
        "$p/Last Session" "$p/Last Tabs"
}

clean_chromium_favicons() {
    local p="$1"
    remove_paths "$p/Favicons" "$p/Favicons-journal"
}

# "Web Data" mezcla autofill (formularios) con "keywords" (motores de
# búsqueda). Se depuran solo las tablas de autofill/tarjetas, se
# conserva "keywords" intacta.
clean_chromium_formdata() {
    local p="$1"
    local db="$p/Web Data"
    [[ -f "$db" ]] || { echo 0; return; }
    if [[ -z "$SQLITE_BIN" ]]; then
        log_warn "sqlite3 no está instalado: se omite la limpieza de formularios (Web Data) para no arriesgar los motores de búsqueda."
        echo 0
        return
    fi
    local before after
    before=$(path_size "$db")
    if (( DRY_RUN )); then
        echo "$before"
        return
    fi
    backup_before_write "$db"
    sqlite_exec_slow "$db" "Depurando formularios y tarjetas guardadas..." \
        "DELETE FROM autofill" \
        "DELETE FROM autofill_profiles" \
        "DELETE FROM autofill_profile_names" \
        "DELETE FROM autofill_profile_emails" \
        "DELETE FROM autofill_profile_phones" \
        "DELETE FROM credit_cards" \
        "VACUUM"
    after=$(path_size "$db")
    echo $(( before > after ? before - after : 0 ))
}

# Limpieza completa: elimina solo las excepciones de permisos no
# permanentes (session_model distinto de "Durable", o con expiración
# explícita); si esos campos no existen se conserva el permiso, igual
# criterio conservador que clean_firefox_permissions_temp. Requiere jq.
clean_chromium_permissions_temp() {
    local p="$1"
    local prefs="$p/Preferences"
    [[ -f "$prefs" ]] || { echo 0; return; }
    if [[ -z "$JQ_BIN" ]]; then
        log_warn "jq no está instalado: se omite la limpieza de permisos temporales (Preferences)."
        echo 0
        return
    fi
    local before after tmp
    before=$(path_size "$prefs")
    # Vista previa: Preferences mezcla muchos ajustes además de los
    # permisos, así que se genera el JSON filtrado con jq (sin escribir a
    # disco) para estimar el tamaño real en vez de devolver solo "0".
    if (( DRY_RUN )); then
        local filtered_size
        filtered_size="$("$JQ_BIN" -c '
            if .profile.content_settings.exceptions then
                .profile.content_settings.exceptions |= with_entries(
                    .value |= with_entries(
                        select(
                            ((.value.session_model // "Durable") == "Durable")
                            and ((.value.expiration // "0") == "0")
                        )
                    )
                )
            else . end
        ' "$prefs" 2>/dev/null | wc -c)"
        [[ "$filtered_size" =~ ^[0-9]+$ ]] || filtered_size=0
        echo $(( before > filtered_size ? before - filtered_size : 0 ))
        return
    fi
    tmp="$(mktemp "${prefs}.XXXXXX")"
    chmod --reference="$prefs" "$tmp" 2>/dev/null || true
    backup_before_write "$prefs"
    # "-c" (compacto): Chromium escribe Preferences en una sola línea;
    # reformatear con sangría podría dejarlo más grande pese al borrado.
    if "$JQ_BIN" -c '
        if .profile.content_settings.exceptions then
            .profile.content_settings.exceptions |= with_entries(
                .value |= with_entries(
                    select(
                        ((.value.session_model // "Durable") == "Durable")
                        and ((.value.expiration // "0") == "0")
                    )
                )
            )
        else . end
    ' "$prefs" > "$tmp" 2>/dev/null && [[ -s "$tmp" ]]; then
        mv "$tmp" "$prefs"
    else
        rm -f "$tmp"
    fi
    after=$(path_size "$prefs")
    echo $(( before > after ? before - after : 0 ))
}

# Limpieza profunda: vacía las excepciones de permisos guardadas en
# Preferences (requiere jq). Mide el archivo antes/después para reflejar
# los bytes liberados, igual que clean_firefox_permissions_all.
clean_chromium_permissions_all() {
    local p="$1"
    local prefs="$p/Preferences"
    [[ -f "$prefs" ]] || { echo 0; return; }
    if [[ -z "$JQ_BIN" ]]; then
        log_warn "jq no está instalado: se omite el borrado de permisos de sitios en Preferences."
        echo 0
        return
    fi
    local before after
    before=$(path_size "$prefs")
    # Vista previa: igual que en clean_chromium_permissions_temp, se genera
    # el JSON filtrado en memoria solo para estimar el tamaño a liberar.
    if (( DRY_RUN )); then
        local filtered_size
        filtered_size="$("$JQ_BIN" -c '
            if .profile.content_settings.exceptions then
                .profile.content_settings.exceptions = {}
            else . end
        ' "$prefs" 2>/dev/null | wc -c)"
        [[ "$filtered_size" =~ ^[0-9]+$ ]] || filtered_size=0
        echo $(( before > filtered_size ? before - filtered_size : 0 ))
        return
    fi
    local tmp
    tmp="$(mktemp "${prefs}.XXXXXX")"
    chmod --reference="$prefs" "$tmp" 2>/dev/null || true
    backup_before_write "$prefs"
    # Igual que en clean_chromium_permissions_temp, "-c" evita reformatear
    # Preferences con sangría, lo que podría hacerlo crecer en vez de encoger.
    if "$JQ_BIN" -c '
        if .profile.content_settings.exceptions then
            .profile.content_settings.exceptions = {}
        else . end
    ' "$prefs" > "$tmp" 2>/dev/null && [[ -s "$tmp" ]]; then
        mv "$tmp" "$prefs"
    else
        rm -f "$tmp"
    fi
    after=$(path_size "$prefs")
    echo $(( before > after ? before - after : 0 ))
}

clean_chromium_security_state() {
    local p="$1"
    remove_paths \
        "$p/Network Persistent State" "$p/TransportSecurity" "$p/Reporting and NEL" \
        "$p/Network/Network Persistent State" "$p/Network/TransportSecurity" \
        "$p/Network/Reporting and NEL"
}

# ===========================================================================
# FALKON (QtWebEngine) — funciones de limpieza
# ===========================================================================
# AVISO DE PRECISIÓN: Falkon está mucho menos documentado que Firefox o
# Chromium y su formato interno cambia entre versiones. Por eso estas
# funciones borran ficheros completos por nombre (caché QtWebEngine,
# "browsedata.db", que no afecta a "bookmarks.json") en vez de depurar
# filas por SQL, y no tocan permisos de sitios ni estado de seguridad por
# falta de certeza sobre dónde los guarda cada versión.

clean_falkon_cache() {
    local cache_dir="$1"
    remove_path "$cache_dir"
}

clean_falkon_history() {
    local p="$1"
    remove_paths "$p/browsedata.db" "$p/browsedata.db-wal" "$p/browsedata.db-shm"
}

clean_falkon_cookies() {
    local p="$1"
    remove_path "$p/cookies.db"
}

# El nombre del fichero de favicons ha variado entre versiones de Falkon
# ("favicons.db" en las más recientes); se comprueban ambos por seguridad.
clean_falkon_favicons() {
    local p="$1"
    remove_paths "$p/favicons.db" "$p/icons.db"
}

clean_falkon_sessions() {
    local p="$1"
    remove_path "$p/session.dat"
}

# El autofill de formularios ha usado tanto ".dat" (versiones antiguas)
# como ".json" (versiones recientes); se comprueban ambos.
clean_falkon_formdata() {
    local p="$1"
    remove_paths "$p/autofill.dat" "$p/autofill.json"
}

# ===========================================================================
# GNOME WEB / EPIPHANY (WebKitGTK) — funciones de limpieza
# ===========================================================================
# AVISO DE PRECISIÓN: la disposición de archivos de Epiphany es la menos
# documentada de las cubiertas aquí (bastantes ajustes viven en
# dconf/GSettings y quedan fuera de alcance). Se prueban varios nombres
# de archivo plausibles para historial/cookies; si alguno no existe, esa
# ruta simplemente no hace nada. Los marcadores ("bookmarks.gvdb") nunca
# se tocan.

clean_epiphany_cache() {
    local cache_dir="$1"
    remove_path "$cache_dir"
}

clean_epiphany_history() {
    local p="$1"
    remove_paths "$p/ephy-history.db" "$p/ephy-history.db-wal" "$p/ephy-history.db-shm" "$p/history.db"
}

clean_epiphany_cookies() {
    local p="$1"
    remove_paths "$p/cookies.sqlite" "$p/Cookies"
}

# WebKitGTK guarda tradicionalmente la base de favicons dentro de la
# carpeta de caché, no en la de datos.
clean_epiphany_favicons() {
    local cache_dir="$1"
    remove_paths "$cache_dir/favicons" "$cache_dir/icondatabase"
}

clean_epiphany_sessions() {
    local p="$1"
    remove_paths "$p/session_state.xml" "$p/ephy-session.xml"
}

# ===========================================================================
# Orquestación de la limpieza
# ===========================================================================

# Orden y etiquetas de las categorías para el resumen final. Solo se
# muestran las categorías realmente ejecutadas para el tipo de limpieza
# elegido (ver clean_browser), con el tamaño real liberado en cada una.
CATEGORY_ORDER=(cache crash bloqueos history cookies storage sessions favicons formdata permisos seguridad walshm)
declare -A CATEGORY_LABEL=(
    [cache]="Caché, miniaturas y archivos temporales"
    [crash]="Informes de fallos, telemetría y diagnóstico"
    [bloqueos]="Archivos de bloqueo obsoletos"
    [history]="Historial de navegación"
    [cookies]="Cookies"
    [storage]="Almacenamiento web (IndexedDB, LocalStorage, Workers)"
    [sessions]="Sesiones y pestañas guardadas"
    [favicons]="Favicons"
    [formdata]="Datos de formularios y tarjetas guardadas"
    [permisos]="Permisos de sitios web"
    [seguridad]="Estado de seguridad (HSTS/NEL)"
    [walshm]="Archivos WAL/SHM huérfanos"
)

# Ejecuta la limpieza de un único perfil de Firefox/LibreWolf/Tor
# Browser/Waterfox/Floorp/Zen Browser (todos comparten el mismo motor y
# estructura de perfil). Imprime una línea "categoria:bytes" por cada
# categoría tratada.
#
# Los archivos de bloqueo obsoletos (lock/.parentlock) se limpian SIEMPRE,
# independientemente del tipo de limpieza elegido: no es una cuestión de
# "profundidad" de limpieza sino una corrección de un estado inconsistente
# (y en este punto ya se ha confirmado que el navegador no está corriendo).
run_firefox_profile() {
    local p="$1" type="$2" base="$3" id="$4"
    echo "bloqueos:$(clean_firefox_stale_locks "$p")"
    case "$type" in
        rapida)
            echo "cache:$(clean_firefox_cache "$p" "$id")"
            echo "crash:$(clean_firefox_crash_logs "$p" "$base")"
            ;;
        completa|profunda)
            echo "cache:$(clean_firefox_cache "$p" "$id")"
            echo "crash:$(clean_firefox_crash_logs "$p" "$base")"
            echo "history:$(clean_firefox_history "$p")"
            echo "cookies:$(clean_firefox_cookies "$p")"
            echo "storage:$(clean_firefox_storage "$p")"
            echo "sessions:$(clean_firefox_sessions "$p")"
            echo "favicons:$(clean_firefox_favicons "$p")"
            echo "formdata:$(clean_firefox_formdata "$p")"
            echo "permisos:$(clean_firefox_permissions_temp "$p")"
            if [[ "$type" == "profunda" ]]; then
                echo "permisos:$(clean_firefox_permissions_all "$p")"
                echo "seguridad:$(clean_firefox_security_state "$p")"
            fi
            echo "walshm:$(clean_orphan_wal_shm "$p")"
            ;;
        cache)     echo "cache:$(clean_firefox_cache "$p" "$id")" ;;
        cookies)   echo "cookies:$(clean_firefox_cookies "$p")" ;;
        historial) echo "history:$(clean_firefox_history "$p")" ;;
    esac
}

# Igual que run_firefox_profile pero para el motor Chromium (Chromium,
# Chrome, Brave, Vivaldi, Opera, Edge). "component_crx_cache" y
# "extensions_crx_cache" se cuentan dentro de "cache" (son caché pura del
# actualizador), y los bloqueos "Singleton*" se limpian siempre, igual
# criterio que en Firefox.
run_chromium_profile() {
    local p="$1" type="$2" base="$3" id="$4"
    echo "bloqueos:$(clean_chromium_stale_locks "$base")"
    case "$type" in
        rapida)
            echo "cache:$(clean_chromium_cache "$p" "$id")"
            echo "cache:$(clean_chromium_component_cache "$base")"
            echo "crash:$(clean_chromium_crash_logs "$base")"
            ;;
        completa|profunda)
            echo "cache:$(clean_chromium_cache "$p" "$id")"
            echo "cache:$(clean_chromium_component_cache "$base")"
            echo "crash:$(clean_chromium_crash_logs "$base")"
            echo "history:$(clean_chromium_history "$p")"
            echo "cookies:$(clean_chromium_cookies "$p")"
            echo "storage:$(clean_chromium_storage "$p")"
            echo "sessions:$(clean_chromium_sessions "$p")"
            echo "favicons:$(clean_chromium_favicons "$p")"
            echo "formdata:$(clean_chromium_formdata "$p")"
            echo "permisos:$(clean_chromium_permissions_temp "$p")"
            if [[ "$type" == "profunda" ]]; then
                echo "permisos:$(clean_chromium_permissions_all "$p")"
                echo "seguridad:$(clean_chromium_security_state "$p")"
            fi
            echo "walshm:$(clean_orphan_wal_shm "$p")"
            ;;
        cache)
            echo "cache:$(clean_chromium_cache "$p" "$id")"
            echo "cache:$(clean_chromium_component_cache "$base")"
            ;;
        cookies)   echo "cookies:$(clean_chromium_cookies "$p")" ;;
        historial) echo "history:$(clean_chromium_history "$p")" ;;
    esac
}

# Falkon y GNOME Web no usan archivos de bloqueo con nombre fijo del mismo
# modo que Firefox/Chromium (Falkon se apoya en D-Bus/QLocalServer para
# detectar otra instancia, y GNOME Web en el propio arranque de la sesión
# GNOME), así que la categoría "bloqueos" no aplica aquí y no aparece en
# su resumen — es una diferencia real entre motores, no un descuido.
run_falkon_profile() {
    local p="$1" type="$2" cache_dir="$3"
    case "$type" in
        rapida)
            echo "cache:$(clean_falkon_cache "$cache_dir")"
            ;;
        completa|profunda)
            echo "cache:$(clean_falkon_cache "$cache_dir")"
            echo "history:$(clean_falkon_history "$p")"
            echo "cookies:$(clean_falkon_cookies "$p")"
            echo "sessions:$(clean_falkon_sessions "$p")"
            echo "favicons:$(clean_falkon_favicons "$p")"
            echo "formdata:$(clean_falkon_formdata "$p")"
            ;;
        cache)     echo "cache:$(clean_falkon_cache "$cache_dir")" ;;
        cookies)   echo "cookies:$(clean_falkon_cookies "$p")" ;;
        historial) echo "history:$(clean_falkon_history "$p")" ;;
    esac
}

run_epiphany_profile() {
    local p="$1" type="$2" cache_dir="$3"
    case "$type" in
        rapida)
            echo "cache:$(clean_epiphany_cache "$cache_dir")"
            ;;
        completa|profunda)
            echo "cache:$(clean_epiphany_cache "$cache_dir")"
            echo "history:$(clean_epiphany_history "$p")"
            echo "cookies:$(clean_epiphany_cookies "$p")"
            echo "sessions:$(clean_epiphany_sessions "$p")"
            echo "favicons:$(clean_epiphany_favicons "$cache_dir")"
            ;;
        cache)     echo "cache:$(clean_epiphany_cache "$cache_dir")" ;;
        cookies)   echo "cookies:$(clean_epiphany_cookies "$p")" ;;
        historial) echo "history:$(clean_epiphany_history "$p")" ;;
    esac
}

# ---------------------------------------------------------------------------
# Tablas con bordes para los resúmenes
# ---------------------------------------------------------------------------
# CONTENT_WIDTH es el número de columnas visibles entre los bordes "│ " y
# " │" (sin contar los propios bordes). Los cálculos de padding siempre se
# hacen sobre longitudes de texto plano (sin códigos ANSI) y el color se
# aplica alrededor después, igual que ya hacía center_text() para la
# cabecera — de lo contrario los códigos de color, invisibles pero
# contados por bash, descuadrarían el padding.
CONTENT_WIDTH=71
BORDER_WIDTH=$(( CONTENT_WIDTH + 2 ))

box_top()    { echo -e "  ${C_CYAN}┌$(printf '─%.0s' $(seq 1 $BORDER_WIDTH))┐${C_RESET}"; }
box_sep()    { echo -e "  ${C_CYAN}├$(printf '─%.0s' $(seq 1 $BORDER_WIDTH))┤${C_RESET}"; }
box_bottom() { echo -e "  ${C_CYAN}└$(printf '─%.0s' $(seq 1 $BORDER_WIDTH))┘${C_RESET}"; }

# Fila de título: texto en negrita a la izquierda, texto en gris a la
# derecha (p. ej. "3 perfil(es)").
box_title_row() {
    local left="$1" right="$2"
    local pad=$(( CONTENT_WIDTH - ${#left} - ${#right} ))
    (( pad < 1 )) && pad=1
    printf "  ${C_CYAN}│${C_RESET} ${C_BOLD}%s${C_RESET}%*s${C_GRAY}%s${C_RESET} ${C_CYAN}│${C_RESET}\n" \
        "$left" "$pad" "" "$right"
}

# Fila de categoría: icono de color variable + etiqueta + valor alineado
# a la derecha. label_w=58 y value_w=10 reproducen el mismo ancho que la
# versión anterior sin bordes (1 + 1 + 58 + 1 + 10 = 71 = CONTENT_WIDTH).
box_category_row() {
    local icon="$1" icon_color="$2" label="$3" value="$4"
    local label_w=58
    # Truncado defensivo: si una etiqueta de categoría (actual o futura,
    # p. ej. tras una traducción) supera el ancho reservado, se recorta con
    # "…" en vez de desbordar la caja y desalinear el borde derecho "│".
    if (( ${#label} > label_w )); then
        label="${label:0:$((label_w - 1))}…"
    fi
    printf "  ${C_CYAN}│${C_RESET} %b %-58s %10s ${C_CYAN}│${C_RESET}\n" \
        "${icon_color}${icon}${C_RESET}" "$label" "$value"
}

# Fila de total, en negrita (60 + 1 + 10 = 71 = CONTENT_WIDTH).
box_total_row() {
    local label="$1" value="$2"
    printf "  ${C_CYAN}│${C_RESET} ${C_BOLD}%-60s %10s${C_RESET} ${C_CYAN}│${C_RESET}\n" "$label" "$value"
}

# Fila de texto libre (para avisos dentro de la tabla, p. ej. "sin cambios").
box_text_row() {
    local text="$1" color="${2:-}"
    local pad=$(( CONTENT_WIDTH - ${#text} ))
    (( pad < 0 )) && pad=0
    printf "  ${C_CYAN}│${C_RESET} %s%s%*s${C_RESET} ${C_CYAN}│${C_RESET}\n" "$color" "$text" "$pad" ""
}

# Último total calculado por clean_browser(), en bytes. Lo usa el
# orquestador de vista previa para acumular el gran total a confirmar,
# sin necesitar que clean_browser "devuelva" nada por stdout (que ya usa
# para pintar la tabla en pantalla).
LAST_BROWSER_TOTAL=0

# Limpia (o, en modo vista previa, solo mide) un navegador completo con
# todos sus perfiles, y muestra el resultado en una tabla con bordes.
# Usa "< <(...)" (sustitución de procesos) en vez de una tubería para que
# el bucle que acumula CAT_BYTES y total corra en este mismo shell y no en
# un subshell — de lo contrario los totales se perderían al salir del bucle.
#
# preview=1 activa el modo vista previa: no se confirma cierre del
# navegador (no hace falta, solo se van a leer tamaños) y la cabecera dice
# "Vista previa" en vez de "Limpiando". Se asume que el llamador ya ha
# puesto DRY_RUN=1 antes de invocar esta función en ese modo.
clean_browser() {
    local id="$1" type="$2" preview="${3:-0}"
    local label="${V_LABEL[$id]}"
    LAST_BROWSER_TOTAL=0

    if ! browser_installed "$id"; then
        (( preview )) || log_skip "${label} no está instalado, se omite."
        return
    fi

    if (( ! preview )); then
        if ! ensure_browser_closed "$id"; then
            return
        fi
    fi

    local base; base="$(resolve_config_dir "$id")"
    local cache_dir; cache_dir="$(resolve_cache_dir "$id")"
    local profiles=()
    while IFS= read -r line; do
        [[ -n "$line" ]] && profiles+=("$line")
    done < <(browser_profiles "$id")

    if (( ${#profiles[@]} == 0 )); then
        (( preview )) || log_skip "No se encontraron perfiles de ${label}."
        return
    fi

    echo
    if (( preview )); then
        echo -e "${C_BOLD}Vista previa — ${label}${C_RESET} (${#profiles[@]} perfil(es))"
    else
        echo -e "${C_BOLD}Limpiando ${label}...${C_RESET} (${#profiles[@]} perfil(es))"
    fi

    local -A CAT_BYTES=()
    local total=0
    local p cat bytes
    for p in "${profiles[@]}"; do
        case "${V_FAMILY[$id]}" in
            firefox)
                while IFS=: read -r cat bytes; do
                    [[ -n "$cat" ]] || continue
                    CAT_BYTES[$cat]=$(( ${CAT_BYTES[$cat]:-0} + bytes ))
                    total=$(( total + bytes ))
                done < <(run_firefox_profile "$p" "$type" "$base" "$id")
                ;;
            chromium)
                while IFS=: read -r cat bytes; do
                    [[ -n "$cat" ]] || continue
                    CAT_BYTES[$cat]=$(( ${CAT_BYTES[$cat]:-0} + bytes ))
                    total=$(( total + bytes ))
                done < <(run_chromium_profile "$p" "$type" "$base" "$id")
                ;;
            falkon)
                while IFS=: read -r cat bytes; do
                    [[ -n "$cat" ]] || continue
                    CAT_BYTES[$cat]=$(( ${CAT_BYTES[$cat]:-0} + bytes ))
                    total=$(( total + bytes ))
                done < <(run_falkon_profile "$p" "$type" "$cache_dir")
                ;;
            epiphany)
                while IFS=: read -r cat bytes; do
                    [[ -n "$cat" ]] || continue
                    CAT_BYTES[$cat]=$(( ${CAT_BYTES[$cat]:-0} + bytes ))
                    total=$(( total + bytes ))
                done < <(run_epiphany_profile "$p" "$type" "$cache_dir")
                ;;
        esac
    done

    echo
    box_top
    box_title_row "$label" "${#profiles[@]} perfil(es)"
    box_sep
    local c any_row=0
    for c in "${CATEGORY_ORDER[@]}"; do
        [[ -v CAT_BYTES[$c] ]] || continue
        any_row=1
        box_category_row "✓" "$C_GREEN" "${CATEGORY_LABEL[$c]}" "$(human_size "${CAT_BYTES[$c]}")"
    done
    (( any_row )) || box_text_row "(nada que limpiar en este nivel)" "$C_GRAY"
    box_sep
    if (( preview )); then
        box_total_row "Espacio estimado a recuperar" "$(human_size "$total")"
    else
        box_total_row "Espacio recuperado" "$(human_size "$total")"
    fi
    box_bottom

    LAST_BROWSER_TOTAL=$total

    if (( ! preview )); then
        log_line "${label}: liberado $(human_size "$total") (tipo: ${type})"
        GRAND_TOTAL=$(( GRAND_TOTAL + total ))
    fi
}

# ---------------------------------------------------------------------------
# Menús interactivos
# ---------------------------------------------------------------------------

# Centra "$1" en un campo de "$2" columnas devolviendo texto SIN color:
# los códigos ANSI no ocupan columnas visibles, pero sí cuentan para
# printf/${#...}, así que el padding se calcula siempre sobre texto plano
# y el color se aplica después, alrededor del resultado ya centrado.
center_text() {
    local text="$1" width="$2"
    local len=${#text}
    (( len >= width )) && { printf '%s' "$text"; return; }
    local left=$(( (width - len) / 2 ))
    local right=$(( width - len - left ))
    printf '%*s%s%*s' "$left" "" "$text" "$right" ""
}

print_header() {
    clear
    local width=62
    local border; border="$(printf '═%.0s' $(seq 1 $width))"
    echo -e "${C_CYAN}╔${border}╗${C_RESET}"
    echo -e "${C_CYAN}║${C_RESET}${C_BOLD}$(center_text "${SCRIPT_NAME} ${SCRIPT_VERSION}" "$width")${C_RESET}${C_CYAN}║${C_RESET}"
    echo -e "${C_CYAN}║${C_RESET}${C_GRAY}$(center_text "${OS_LABEL}" "$width")${C_RESET}${C_CYAN}║${C_RESET}"
    echo -e "${C_CYAN}║${C_RESET}${C_GRAY}$(center_text "por ${SCRIPT_AUTHOR}" "$width")${C_RESET}${C_CYAN}║${C_RESET}"
    echo -e "${C_CYAN}╚${border}╝${C_RESET}"
    echo
    local tools=""
    [[ -n "$SQLITE_BIN" ]] && tools+="${OK} sqlite3  " || tools+="${BAD} sqlite3 (limpieza de historial/formularios limitada)  "
    [[ -n "$JQ_BIN" ]] && tools+="${OK} jq" || tools+="${BAD} jq (limpieza de permisos de sitios limitada)"
    echo -e "  ${C_GRAY}Herramientas:${C_RESET} ${tools}"
}

ask_clean_type() {
    # Importante: esta función se invoca como "type=$(ask_clean_type)", así que
    # TODO el texto de menú debe ir a stderr (>&2); solo el valor final
    # (rapida/completa/...) puede pasar por stdout, o quedaría mezclado con el menú.
    echo >&2
    echo "¿Qué desea limpiar?" >&2
    echo "  [1] Limpieza rápida     (caché, miniaturas, informes de fallos)" >&2
    echo "  [2] Limpieza completa   (rápida + historial, cookies, sesiones, formularios...)" >&2
    echo "  [3] Solo cachés" >&2
    echo "  [4] Solo cookies" >&2
    echo "  [5] Solo historial" >&2
    echo "  [6] Limpieza profunda   (completa + permisos de sitios y estado de seguridad)" >&2
    echo >&2
    local opt
    ask_input opt "Opción: "
    opt="$(trim "$opt")"
    case "$opt" in
        1) echo "rapida" ;;
        2) echo "completa" ;;
        3) echo "cache" ;;
        4) echo "cookies" ;;
        5) echo "historial" ;;
        6) echo "profunda" ;;
        *) echo "" ;;
    esac
}

print_help() {
    local prog; prog="$(basename -- "$0")"
    cat <<EOF
${SCRIPT_NAME} ${SCRIPT_VERSION} — Limpiador interactivo de navegadores
${OS_LABEL} — por ${SCRIPT_AUTHOR}

Uso:
  ${prog}              Modo interactivo (menús paso a paso).
  ${prog} --help       Muestra esta ayuda y termina.
  ${prog} --version    Muestra la versión instalada y termina.

El script es interactivo: detecta los navegadores instalados, deja
elegir cuáles limpiar y qué tipo de limpieza aplicar (rápida, completa,
solo caché, solo cookies, solo historial o profunda). Para las
limpiezas irreversibles (historial, cookies, completa, profunda)
primero muestra una vista previa de lo que se liberaría y pide
confirmación antes de borrar nada.

Navegadores soportados (paquete .deb, Flatpak o Snap):
  Motor Firefox    : Firefox, LibreWolf, Tor Browser, Waterfox, Floorp,
                     Zen Browser
  Motor Chromium   : Chromium, Google Chrome, Brave, Vivaldi, Opera, Edge
  Motor QtWebEngine: Falkon
  Motor WebKitGTK  : GNOME Web (Epiphany)

Registro de cada sesión: ${LOG_FILE}
EOF
}

main() {
    case "${1:-}" in
        -h|--help)
            print_help
            exit 0
            ;;
        -v|--version)
            echo "${SCRIPT_NAME} ${SCRIPT_VERSION}"
            exit 0
            ;;
        "") ;;
        *)
            echo "Opción no reconocida: ${1}" >&2
            echo "Pruebe: $(basename -- "$0") --help" >&2
            exit 1
            ;;
    esac

    local is_root=0
    [[ "${EUID:-$(id -u)}" -eq 0 ]] && is_root=1
    local root_warning_shown=0

    # Todo el flujo interactivo vive dentro de este bucle: al terminar una
    # limpieza, al cancelarla, o al teclear una opción no válida, el script
    # vuelve al selector de navegadores en vez de finalizar el proceso. Solo
    # se sale del bucle (y del script) con la opción "0) Salir" del menú
    # principal, o respondiendo "q" cuando se pregunta al terminar una
    # limpieza; cualquier otro caso hace "continue"/cae al final del bucle y
    # se vuelve a dibujar el menú desde el principio.
    while true; do
        print_header

        # Se muestra justo después de la cabecera (print_header empieza con
        # "clear", así que antes se borraría sin que el usuario llegara a
        # leerlo) y solo la primera vez, aunque el resto del flujo viva
        # dentro de este bucle.
        if (( is_root && ! root_warning_shown )); then
            echo -e "${C_YELLOW}Aviso:${C_RESET} este script está pensado para ejecutarse como tu usuario normal,"
            echo "no como root, ya que limpia el directorio \$HOME de tu propio usuario."
            echo
            root_warning_shown=1
        fi

        echo
        echo -e "${C_GRAY}Buscando navegadores instalados (paquete, Flatpak y Snap)...${C_RESET}"

        local found=()
        declare -A PROFILE_COUNT=()
        local id n
        for id in "${V_ORDER[@]}"; do
            if browser_installed "$id"; then
                n=0
                while IFS= read -r line; do
                    [[ -n "$line" ]] && n=$(( n + 1 ))
                done < <(browser_profiles "$id")
                if (( n > 0 )); then
                    found+=("$id")
                    PROFILE_COUNT[$id]=$n
                fi
            fi
        done

        if (( ${#found[@]} == 0 )); then
            echo
            echo "No se detectaron navegadores compatibles ni perfiles de usuario."
            echo "Navegadores soportados (paquete .deb, Flatpak o Snap):"
            echo "  Motor Firefox    : Firefox, LibreWolf, Tor Browser, Waterfox, Floorp,"
            echo "                     Zen Browser"
            echo "  Motor Chromium   : Chromium, Google Chrome, Brave, Vivaldi, Opera, Edge"
            echo "  Motor QtWebEngine: Falkon"
            echo "  Motor WebKitGTK  : GNOME Web (Epiphany)"
            exit 0
        fi

        echo
        echo "Navegadores encontrados:"
        local i=1
        for id in "${found[@]}"; do
            printf "  [%d] %-30s ${C_GRAY}(%d perfil(es))${C_RESET}\n" "$i" "${V_LABEL[$id]}" "${PROFILE_COUNT[$id]}"
            i=$(( i + 1 ))
        done
        echo
        echo "Seleccione:"
        i=1
        for id in "${found[@]}"; do
            echo "  $i) Limpiar ${V_LABEL[$id]}"
            i=$(( i + 1 ))
        done
        local all_option=$i
        echo "  $all_option) Limpiar TODOS"
        echo "  0) Salir"
        echo
        local choice
        ask_input choice "Opción: "
        choice="$(trim "$choice")"

        if [[ "$choice" == "0" ]]; then
            echo
            echo "Hasta la próxima."
            exit 0
        fi

        local selected=()
        if [[ "$choice" == "$all_option" ]]; then
            selected=("${found[@]}")
        # "10#$choice" fuerza la interpretación en base 10: sin ese prefijo,
        # la evaluación aritmética de bash trata cualquier número que
        # empiece por "0" como octal (igual que en C), y un "08" o "09"
        # tecleado sin querer (8/9 no son dígitos octales válidos) abortaría
        # la comparación con un error real en vez de mostrar "Opción no
        # válida".
        elif [[ "$choice" =~ ^[0-9]+$ ]] && (( 10#$choice >= 1 && 10#$choice < all_option )); then
            selected=("${found[$((10#$choice - 1))]}")
        else
            echo -e "${C_RED}Opción no válida.${C_RESET}"
            ask_input _ "Pulse Enter para volver al menú principal..."
            continue
        fi

        local type
        type="$(ask_clean_type)"
        if [[ -z "$type" ]]; then
            echo -e "${C_RED}Opción no válida.${C_RESET}"
            ask_input _ "Pulse Enter para volver al menú principal..."
            continue
        fi

        # Herramientas opcionales (sqlite3/jq): si el tipo de limpieza
        # elegido las necesita y no están instaladas, se ofrece instalarlas
        # automáticamente AQUÍ (una vez, antes de la vista previa) en vez de
        # interrumpir a medio borrado real de cada perfil. Si en una vuelta
        # anterior de este mismo menú el usuario ya rechazó instalar una de
        # ellas, no se le vuelve a preguntar (SQLITE_INSTALL_DECLINED /
        # JQ_INSTALL_DECLINED); si la instalación falla o se rechaza, el
        # script sigue funcionando con la limpieza de esa categoría omitida
        # (ver los avisos dentro de clean_firefox_history,
        # clean_chromium_formdata, clean_chromium_permissions_*).
        if [[ "$type" == "historial" || "$type" == "completa" || "$type" == "profunda" ]] \
            && [[ -z "$SQLITE_BIN" ]] && (( ! SQLITE_INSTALL_DECLINED )); then
            ensure_tool sqlite3 sqlite3 SQLITE_BIN \
                "para depurar el historial (y, en limpieza completa/profunda, formularios y permisos) sin arriesgar marcadores ni motores de búsqueda"
        fi
        if [[ "$type" == "completa" || "$type" == "profunda" ]] \
            && [[ -z "$JQ_BIN" ]] && (( ! JQ_INSTALL_DECLINED )); then
            ensure_tool jq jq JQ_BIN \
                "para depurar permisos de sitios web sin tocar el resto de tu configuración"
        fi

        if [[ "$type" == "profunda" ]]; then
            echo
            echo -e "${C_YELLOW}⚠ La limpieza profunda además borra los permisos de sitios web y el${C_RESET}"
            echo -e "${C_YELLOW}  estado de seguridad (HSTS/NEL). Marcadores, contraseñas, extensiones,${C_RESET}"
            echo -e "${C_YELLOW}  temas, certificados, motores de búsqueda y configuración NO se tocan.${C_RESET}"
        fi

        # historial/cookies/completa/profunda son operaciones irreversibles
        # (una vez borrado el historial o las cookies no hay forma de
        # deshacerlo), así que primero se hace una pasada en modo vista previa
        # (DRY_RUN=1): mide exactamente lo que se borraría en cada navegador
        # seleccionado sin tocar ningún archivo, se muestra el resumen y solo
        # se continúa con el borrado real si el usuario lo confirma explícitamente.
        if [[ "$type" == "historial" || "$type" == "cookies" || "$type" == "completa" || "$type" == "profunda" ]]; then
            echo
            echo -e "${C_CYAN}Vista previa: calculando qué se eliminaría (todavía no se borra nada)...${C_RESET}"
            DRY_RUN=1
            local preview_total=0
            for id in "${selected[@]}"; do
                clean_browser "$id" "$type" 1
                preview_total=$(( preview_total + LAST_BROWSER_TOTAL ))
            done
            DRY_RUN=0

            echo
            echo -e "${C_BOLD}Espacio total estimado a recuperar: $(human_size "$preview_total")${C_RESET}"
            echo -e "${C_YELLOW}Esta operación es irreversible.${C_RESET}"
            echo
            local confirm
            ask_input confirm "¿Confirma el borrado real? [s/N]: "
            confirm="$(trim "$confirm")"
            case "$confirm" in
                s|S|si|Si|SI|sí|Sí|SÍ|y|Y|yes|YES) ;;
                *)
                    echo
                    echo "Operación cancelada. No se ha borrado nada."
                    ask_input _ "Pulse Enter para volver al menú principal..."
                    continue
                    ;;
            esac
        fi

        GRAND_TOTAL=0
        for id in "${selected[@]}"; do
            clean_browser "$id" "$type"
        done

        if (( ${#selected[@]} > 1 )); then
            echo
            echo -e "${C_BOLD}Total general recuperado:${C_RESET} $(human_size "$GRAND_TOTAL")"
            echo
        fi

        echo -e "${C_GRAY}Registro de esta sesión: ${LOG_FILE}${C_RESET}"

        echo
        local again
        ask_input again "Pulse Enter para volver al menú principal, o escriba 'q' para salir: "
        again="$(trim "$again")"
        case "$again" in
            q|Q|salir|Salir|exit|Exit)
                echo
                echo "Hasta la próxima."
                exit 0
                ;;
        esac
    done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
