#!/usr/bin/env bash
#
# Copyright (C) 2026 Filonux
#
# License:
#   Browser-Cleaner is free software distributed under the terms of the GNU
#   General Public License version 3 (GPLv3). See LICENSE.txt for the full text.
#
# browser-cleaner.sh — Interactive browser cleaner
# Linux Mint 22.3 (Cinnamon)
#
# Programmed by Filonux
#
# Design: preserve browser/user state (profiles, settings, bookmarks, passwords,
# extensions, themes, certificates, search engines and sync settings); remove
# regenerable browsing residue such as cache, history, cookies, web storage,
# sessions, favicons, logs, crash data, telemetry, temporary files, stale locks
# and orphaned WAL/SHM files.
#
# Supported browsers are detected from native, Flatpak or Snap profile layouts.
#   Firefox engine    : Firefox, LibreWolf, Tor Browser, Waterfox, Floorp, Zen
#   Chromium engine   : Chromium, Google Chrome, Brave, Vivaldi, Opera, Edge
#   QtWebEngine       : Falkon
#   WebKitGTK         : GNOME Web (Epiphany)
#
# Usage: ./browser-cleaner.sh, --help, --version
#
# Changelog:
#   3.8.2 - Refuse to rewrite symlinked SQLite/Preferences files.
#   3.8.1 - Do not follow symlinks during cleanup and preserve shared Chromium
#           storage that may contain extension state.
#   3.8.0 - External per-profile cache is now removed for Firefox/LibreWolf and
#           Chromium-family browsers across native, Flatpak and Snap installs.
#   3.7.1 - LibreWolf fallback profile discovery searches four levels deep.
#   3.7.0 - Added bounded LibreWolf fallback discovery for atypical layouts.
#   3.6.0 - Expanded Firefox/LibreWolf XDG paths and profile.ini discovery.
#   3.5.2 - Isolated SQLite statements, expanded Chromium cache cleanup and
#           preserved Preferences metadata during atomic replacements.
#   3.5.1 - Removed Scriptya terminal metadata that opened an empty terminal.
#   3.5.0 - Added semver, --version/-v, safer unknown-argument handling and
#           optional dependency installation with explicit confirmation.
#   3.4   - Unified the project name as "Browser-Cleaner".
#   3.3   - Added pre-write backups, spinner cleanup on Ctrl+C and a single
#           per-run root warning.
#   3.2   - Added optional sqlite3/jq installation and a persistent menu loop.
#   3.1   - Added LibreWolf Flatpak profile detection.
#
set -uo pipefail
IFS=$'\n\t'

# ---------------------------------------------------------------------------
# Presentation
# ---------------------------------------------------------------------------
SCRIPT_NAME="Browser-Cleaner"
SCRIPT_VERSION="3.8.2"  # semver (MAJOR.MINOR.PATCH); see also --version
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

# ---------------------------------------------------------------------------
# Interface language
# ---------------------------------------------------------------------------
declare -A UI_EN=(
    [input_unavailable]="Input unavailable; exiting.\n"
    [interrupt]="Interrupted by user.\n"
    [tools]="Tools:"
    [sqlite_limited]="history/form-data cleaning is limited"
    [jq_limited]="website permissions are limited"
    [tool_missing]="'%s' is not installed (needed for this cleaning category).\n"
    [tool_missing_reason]="⚠ '%s' is not installed; %s.\n"
    [tool_noninteractive]="No interactive terminal is available to confirm installation; skipping '%s' and that cleaning category."
    [no_apt]="No 'apt-get' found on this system: install '%s' manually for full cleaning."
    [install_prompt]="Install '%s' automatically now (apt-get install %s)? [Y/n]: "
    [install_skipped]="Installation of '%s' skipped: that cleaning category will be skipped."
    [no_sudo]="No 'sudo' found and the script is not running as root: cannot install '%s' automatically."
    [installing]="Installing '%s'... (your sudo password may be requested)"
    [retry_install]="Failed; updating the package index (apt-get update) and retrying..."
    [installed]="✓ '%s' installed successfully."
    [install_failed]="Could not install '%s'. That cleaning category will be skipped to avoid risking data."
    [tmp_create_failed]="⚠ Could not create a temporary file to safely update '%s'; this step is skipped.\n"
    [browser_open]="%s is open."
    [close_auto]="[1] Close it automatically"
    [cancel]="[2] Cancel"
    [cancelled_for]="Cancelled for %s."
    [close_failed]="Could not close %s (still running). Cleaning is skipped."
    [closed]="✓ %s closed."
    [not_installed_skip]="%s is not installed; skipping."
    [no_profiles]="No profiles found for %s."
    [preview_title]="Preview — %s (%s)"
    [cleaning_title]="Cleaning %s... (%s)"
    [profile_one]="1 profile"
    [profiles_many]="%d profiles"
    [nothing_to_clean]="(nothing to clean at this level)"
    [estimated_recover]="Estimated space to recover"
    [recovered]="Space recovered"
    [unrecognized_option]="Unrecognized option: %s"
    [try_help]="Try: %s --help"
    [help_title]="Interactive browser cleaner"
    [usage]="Usage:"
    [interactive_mode]="Interactive mode (step-by-step menus)."
    [help_show]="Show this help and exit."
    [version_show]="Show the installed version and exit."
    [help_desc]="The script detects installed browsers and lets you choose which ones to clean.
The cleaning types are quick, complete, cache, cookies, history and deep.
For irreversible types (history, cookies, complete and deep), it first shows a
preview of the space to be freed and asks for confirmation before deletion."
    [supported]="Supported browser profile layouts (native, Flatpak or Snap):"
    [supported_firefox]="Firefox engine    : Firefox, LibreWolf, Tor Browser, Waterfox, Floorp,"
    [supported_firefox2]="                    Zen Browser"
    [supported_chromium]="Chromium engine   : Chromium, Google Chrome, Brave, Vivaldi, Opera, Edge"
    [supported_qt]="QtWebEngine       : Falkon"
    [supported_webkit]="WebKitGTK         : GNOME Web (Epiphany)"
    [session_log]="Each session is logged to: %s"
    [root_warning]="Warning: this script is intended to run as your normal user,"
    [root_warning2]="not as root, because it cleans your own user's \$HOME directory."
    [searching]="Looking for browser profiles (native, Flatpak and Snap)..."
    [none_found]="No compatible browsers or user profiles were detected."
    [found_browsers]="Browsers found:"
    [select]="Select:"
    [clean_one]="Clean %s"
    [clean_all]="Clean ALL"
    [exit]="Exit"
    [goodbye]="See you next time."
    [invalid]="Invalid option."
    [press_enter]="Press Enter to return to the main menu..."
    [deep_warning1]="⚠ Deep cleaning also removes website permissions and"
    [deep_warning2]="  security state (HSTS/NEL). Bookmarks, passwords, extensions,"
    [deep_warning3]="  themes, certificates, search engines and configuration are NOT touched."
    [preview_calc]="Preview: calculating what would be removed (nothing is deleted yet)..."
    [irreversible]="This operation is irreversible."
    [confirm]="Confirm deletion? [y/N]: "
    [cancelled]="Operation cancelled. Nothing has been deleted."
    [total]="Total space recovered:"
    [session_log_label]="This session's log: %s"
    [log_recovered]="%s: freed %s (type: %s)"
    [again]="Press Enter to return to the main menu, or type 'q' to exit: "
    [switch_language]="Switch language"
    [current_language]="current: %s"
    [lang_english]="English"
    [lang_spanish]="Spanish"
    [language_changed]="Language changed to %s."
    [by_author]="by %s"
    [language_auto]="Language: the system message locale is detected automatically; press L in the
menu to switch between Spanish and English."
    [type_prompt]="What do you want to clean?"
    [type_quick]="[1] Quick cleaning    (cache, thumbnails, crash reports)"
    [type_complete]="[2] Complete cleaning (quick + history, cookies, sessions, form data...)"
    [type_cache]="[3] Cache only"
    [type_cookies]="[4] Cookies only"
    [type_history]="[5] History only"
    [type_deep]="[6] Deep cleaning     (complete + site permissions and security state)"
    [type_name_quick]="quick"
    [type_name_complete]="complete"
    [type_name_cache]="cache"
    [type_name_cookies]="cookies"
    [type_name_history]="history"
    [type_name_deep]="deep"
    [option]="Option: "
    [category_cache]="Cache, thumbnails and temporary files"
    [category_crash]="Crash reports, telemetry and diagnostics"
    [category_bloqueos]="Obsolete lock files"
    [category_history]="Browsing history"
    [category_cookies]="Cookies"
    [category_storage]="Web storage (IndexedDB, Local Storage, Workers)"
    [category_sessions]="Saved sessions and tabs"
    [category_favicons]="Favicons"
    [category_formdata]="Form data and saved payment cards"
    [category_permisos]="Website permissions"
    [category_seguridad]="Security state (HSTS/NEL)"
    [category_walshm]="Orphan WAL/SHM files"
    [sqlite_vacuum]="Optimizing browsing history (VACUUM)..."
    [sqlite_temp_permissions]="Cleaning temporary site permissions..."
    [sqlite_formdata]="Cleaning form data and saved payment cards..."
    [reason_history]="to clean browsing history (and, in complete/deep cleaning, form data and permissions) without risking bookmarks or search engines"
    [reason_jq]="to clean website permissions without touching the rest of your configuration"
)

declare -A UI_ES=(
    [input_unavailable]="Entrada no disponible; terminando.\n"
    [interrupt]="Interrumpido por el usuario.\n"
    [tools]="Herramientas:"
    [sqlite_limited]="historial/formularios limitados"
    [jq_limited]="permisos de sitios limitados"
    [tool_missing]="'%s' no está instalado (se necesita para esta categoría de limpieza).\n"
    [tool_missing_reason]="⚠ '%s' no está instalado; %s.\n"
    [tool_noninteractive]="No hay una terminal interactiva para confirmar la instalación: se omite '%s' (esa categoría se saltará)."
    [no_apt]="No se encontró 'apt-get' en este sistema: instala '%s' manualmente para una limpieza completa."
    [install_prompt]="¿Instalar '%s' automáticamente ahora (apt-get install %s)? [S/n]: "
    [install_skipped]="Instalación de '%s' omitida: esa categoría de limpieza se saltará."
    [no_sudo]="No se encontró 'sudo' y el script no se está ejecutando como root: no se puede instalar '%s' automáticamente."
    [installing]="Instalando '%s'... (puede pedir tu contraseña de sudo)"
    [retry_install]="Falló; actualizando el índice de paquetes (apt-get update) y reintentando..."
    [installed]="✓ '%s' instalado correctamente."
    [install_failed]="No se ha podido instalar '%s'. Esa categoría de limpieza se saltará para no arriesgar datos."
    [tmp_create_failed]="⚠ No se ha podido crear un archivo temporal para actualizar '%s' de forma segura; se omite este paso.\n"
    [browser_open]="%s está abierto."
    [close_auto]="[1] Cerrarlo automáticamente"
    [cancel]="[2] Cancelar"
    [cancelled_for]="Cancelado para %s."
    [close_failed]="No se ha podido cerrar %s (sigue en ejecución). Se omite su limpieza."
    [closed]="✓ %s cerrado."
    [not_installed_skip]="%s no está instalado, se omite."
    [no_profiles]="No se encontraron perfiles de %s."
    [preview_title]="Vista previa — %s (%s)"
    [cleaning_title]="Limpiando %s... (%s)"
    [profile_one]="1 perfil"
    [profiles_many]="%d perfiles"
    [nothing_to_clean]="(nada que limpiar en este nivel)"
    [estimated_recover]="Espacio estimado a recuperar"
    [recovered]="Espacio recuperado"
    [unrecognized_option]="Opción no reconocida: %s"
    [try_help]="Pruebe: %s --help"
    [help_title]="Limpiador interactivo de navegadores"
    [usage]="Uso:"
    [interactive_mode]="Modo interactivo (menús paso a paso)."
    [help_show]="Muestra esta ayuda y termina."
    [version_show]="Muestra la versión instalada y termina."
    [help_desc]="El script es interactivo: detecta los navegadores instalados, permite elegir
cuáles limpiar y qué tipo de limpieza aplicar (rápida, completa, solo caché,
solo cookies, solo historial o profunda). Para los tipos de limpieza
irreversibles (historial, cookies, completa y profunda), primero muestra una
vista previa de lo que se liberaría y pide confirmación antes de borrar
nada."
    [supported]="Diseños de perfiles compatibles (nativo, Flatpak o Snap):"
    [supported_firefox]="Motor Firefox    : Firefox, LibreWolf, Tor Browser, Waterfox, Floorp,"
    [supported_firefox2]="                   Zen Browser"
    [supported_chromium]="Motor Chromium   : Chromium, Google Chrome, Brave, Vivaldi, Opera, Edge"
    [supported_qt]="Motor QtWebEngine: Falkon"
    [supported_webkit]="Motor WebKitGTK  : GNOME Web (Epiphany)"
    [session_log]="Registro de cada sesión: %s"
    [root_warning]="Aviso: este script está pensado para ejecutarse como tu usuario normal,"
    [root_warning2]="no como root, ya que limpia el directorio \$HOME de tu propio usuario."
    [searching]="Buscando perfiles de navegador (nativo, Flatpak y Snap)..."
    [none_found]="No se detectaron navegadores compatibles ni perfiles de usuario."
    [found_browsers]="Navegadores encontrados:"
    [select]="Seleccione:"
    [clean_one]="Limpiar %s"
    [clean_all]="Limpiar TODOS"
    [exit]="Salir"
    [goodbye]="Hasta la próxima."
    [invalid]="Opción no válida."
    [press_enter]="Pulse Enter para volver al menú principal..."
    [deep_warning1]="⚠ La limpieza profunda además borra los permisos de sitios web y el"
    [deep_warning2]="  estado de seguridad (HSTS/NEL). Marcadores, contraseñas, extensiones,"
    [deep_warning3]="  temas, certificados, motores de búsqueda y configuración NO se tocan."
    [preview_calc]="Vista previa: calculando qué se eliminaría (todavía no se borra nada)..."
    [irreversible]="Esta operación es irreversible."
    [confirm]="¿Confirma el borrado? [s/N]: "
    [cancelled]="Operación cancelada. No se ha borrado nada."
    [total]="Total general recuperado:"
    [session_log_label]="Registro de esta sesión: %s"
    [log_recovered]="%s: liberado %s (tipo: %s)"
    [again]="Pulse Enter para volver al menú principal, o escriba 'q' para salir: "
    [switch_language]="Cambiar idioma"
    [current_language]="actual: %s"
    [lang_english]="Inglés"
    [lang_spanish]="Español"
    [language_changed]="Idioma cambiado a %s."
    [by_author]="por %s"
    [language_auto]="Idioma: el idioma del sistema se detecta automáticamente; pulse la tecla L
en el menú para alternar entre español e inglés."
    [type_prompt]="¿Qué desea limpiar?"
    [type_quick]="[1] Limpieza rápida   (caché, miniaturas, informes de fallos)"
    [type_complete]="[2] Limpieza completa (rápida + historial, cookies, sesiones y formularios)"
    [type_cache]="[3] Solo cachés"
    [type_cookies]="[4] Solo cookies"
    [type_history]="[5] Solo historial"
    [type_deep]="[6] Limpieza profunda (completa + permisos de sitios y estado de seguridad)"
    [type_name_quick]="rápida"
    [type_name_complete]="completa"
    [type_name_cache]="caché"
    [type_name_cookies]="cookies"
    [type_name_history]="historial"
    [type_name_deep]="profunda"
    [option]="Opción: "
    [category_cache]="Caché, miniaturas y archivos temporales"
    [category_crash]="Informes de fallos, telemetría y diagnósticos"
    [category_bloqueos]="Archivos de bloqueo obsoletos"
    [category_history]="Historial de navegación"
    [category_cookies]="Cookies"
    [category_storage]="Almacenamiento web (IndexedDB, Local Storage, Workers)"
    [category_sessions]="Sesiones y pestañas guardadas"
    [category_favicons]="Favicons"
    [category_formdata]="Datos de formularios y tarjetas de pago guardadas"
    [category_permisos]="Permisos de sitios web"
    [category_seguridad]="Estado de seguridad (HSTS/NEL)"
    [category_walshm]="Archivos WAL/SHM huérfanos"
    [sqlite_vacuum]="Optimizando historial de navegación (VACUUM)..."
    [sqlite_temp_permissions]="Limpiando permisos temporales de sitios..."
    [sqlite_formdata]="Limpiando formularios y tarjetas de pago guardadas..."
    [reason_history]="para limpiar el historial (y, en limpieza completa/profunda, formularios y permisos) sin arriesgar marcadores ni motores de búsqueda"
    [reason_jq]="para limpiar permisos de sitios web sin tocar el resto de tu configuración"
)

detect_ui_language() {
    local lc="${LC_ALL:-}"
    [[ -n "$lc" ]] || lc="${LC_MESSAGES:-}"
    if [[ -z "$lc" ]]; then
        lc="${LANGUAGE:-}"
        lc="${lc%%:*}"
    fi
    [[ -n "$lc" ]] || lc="${LANG:-}"
    lc="${lc,,}"
    [[ "$lc" =~ ^es([_.@-].*)?$ ]] && printf 'es' || printf 'en'
}

UI_LANG="${BROWSER_CLEANER_LANG:-$(detect_ui_language)}"
[[ "$UI_LANG" == "es" || "$UI_LANG" == "en" ]] || UI_LANG="$(detect_ui_language)"

ui() {
    local key="$1" fmt
    shift
    if [[ "$UI_LANG" == "es" ]]; then
        fmt="${UI_ES[$key]:-}"
    else
        fmt="${UI_EN[$key]:-}"
    fi
    # shellcheck disable=SC2059 # fmt is always a trusted literal from UI_EN/UI_ES
    # (never user input); the translation lookup needs it as the format string.
    printf "$fmt" "$@"
}

language_name() {
    if [[ "$1" == "es" ]]; then
        ui lang_spanish
    else
        ui lang_english
    fi
}

ui_profiles() {
    local n="$1"
    if (( n == 1 )); then
        ui profile_one
    else
        ui profiles_many "$n"
    fi
}

ui_type_name() {
    local type="$1"
    case "$type" in
        rapida)    ui type_name_quick ;;
        completa)  ui type_name_complete ;;
        cache)     ui type_name_cache ;;
        cookies)   ui type_name_cookies ;;
        historial) ui type_name_history ;;
        profunda)  ui type_name_deep ;;
        *)         printf '%s' "$type" ;;
    esac
}

toggle_language() {
    if [[ "$UI_LANG" == "es" ]]; then
        UI_LANG="en"
    else
        UI_LANG="es"
    fi
}

SQLITE_BIN="$(command -v sqlite3 || true)"
JQ_BIN="$(command -v jq || true)"

# Dry-run mode measures deletions without modifying files before irreversible operations.
DRY_RUN=0

# Reserved for a future non-interactive mode; currently controls spinner display only.
NONINTERACTIVE=0

# PID of the active progress spinner.
SPINNER_PID=""

# Record the script's ancestor PIDs to avoid false browser-process matches.
declare -A OWN_ANCESTORS=()
ancestor_pid="$$"
while [[ "$ancestor_pid" =~ ^[0-9]+$ ]] && (( ancestor_pid > 1 )); do
    OWN_ANCESTORS[$ancestor_pid]=1
    ancestor_pid="$(ps -o ppid= -p "$ancestor_pid" 2>/dev/null | tr -d ' ')"
    [[ "$ancestor_pid" =~ ^[0-9]+$ ]] || break
done
unset ancestor_pid

# Bytes freed during the current execution.
GRAND_TOTAL=0

# Prevent repeated sqlite3/jq installation prompts after a rejection.
SQLITE_INSTALL_DECLINED=0
JQ_INSTALL_DECLINED=0

# Session log for auditing recovered space.
LOG_DIR="$HOME/.cache/browser-cleaner"
LOG_FILE="$LOG_DIR/browser-cleaner.log"
LOG_DISPLAY="${LOG_FILE/#"$HOME"/\~}"
log_line() {
    mkdir -p "$LOG_DIR" 2>/dev/null || return 0
    printf '%s  %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" >> "$LOG_FILE" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# Generic utilities
# ---------------------------------------------------------------------------

# Trim leading/trailing whitespace because IFS excludes spaces from read's default trimming.
trim() {
    local s="$1"
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    printf '%s' "$s"
}

# Safe read wrapper: exit on EOF or unavailable stdin instead of looping forever.
ask_input() {
    if ! read -rp "$2" "$1"; then
        echo
        printf "${C_RED}%b${C_RESET}" "$(ui input_unavailable)" >&2
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

# Return the byte size of a path without following symlinks.
path_size() {
    local p="$1"
    [[ -e "$p" || -L "$p" ]] || { echo 0; return; }
    local out
    out="$(du -sb -- "$p" 2>/dev/null | cut -f1)"
    [[ "$out" =~ ^[0-9]+$ ]] && echo "$out" || echo 0
}

# Remove a file or directory safely and return its measured size.
remove_path() {
    local p="$1"
    local size=0
    [[ -e "$p" || -L "$p" ]] || { echo 0; return; }
    size=$(path_size "$p")
    # In dry-run mode, report the removable size without deleting anything.
    if (( DRY_RUN )); then
        echo "$size"
        return
    fi
    if [[ -L "$p" ]]; then
        rm -f -- "$p" 2>/dev/null || true
    else
        rm -rf -- "$p" 2>/dev/null || true
    fi
    echo "$size"
}

# Remove multiple paths and return the total size.
remove_paths() {
    local total=0
    local p
    for p in "$@"; do
        total=$(( total + $(remove_path "$p") ))
    done
    echo "$total"
}

# Remove files matched by a glob and return the total size.
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

# Remove orphaned -wal/-shm files whose main database is gone.
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

is_regular_file() {
    [[ -f "$1" && ! -L "$1" ]]
}

# Run SQLite statements in separate connections so one missing table cannot block later work.
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

# Create a best-effort atomic .bak before destructive database/config changes.
backup_before_write() {
    local f="$1" tmp
    [[ -f "$f" && ! -L "$f" ]] || return 0
    tmp="$(mktemp "${f}.bak.XXXXXX" 2>/dev/null || true)"
    [[ -n "$tmp" ]] || return 0
    if cp -p -- "$f" "$tmp" 2>/dev/null && mv -- "$tmp" "${f}.bak" 2>/dev/null; then
        return 0
    fi
    rm -f -- "$tmp" 2>/dev/null || true
}

# Create a temp file next to $1 (same filesystem, so atomic_replace's rename
# stays atomic) with matching permissions. Prints the temp path, or nothing
# if it could not be created (caller must check before writing to it).
make_sibling_tempfile() {
    local target="$1" tmp
    tmp="$(mktemp "${target}.XXXXXX" 2>/dev/null || true)"
    [[ -n "$tmp" && -f "$tmp" ]] || return 1
    chmod --reference="$target" "$tmp" 2>/dev/null || true
    printf '%s' "$tmp"
}

atomic_replace() {
    local tmp="$1" dest="$2"
    if [[ -f "$tmp" ]] && mv -- "$tmp" "$dest" 2>/dev/null; then
        return 0
    fi
    rm -f -- "$tmp" 2>/dev/null || true
    return 1
}

log_warn() { echo -e "  ${C_YELLOW}⚠ $*${C_RESET}" >&2; }
log_skip() { echo -e "  ${C_GRAY}– $*${C_RESET}"; }

# ---------------------------------------------------------------------------
# Optional dependency installation (sqlite3, jq)
# ---------------------------------------------------------------------------
# Missing tools only disable the categories that require them.
ensure_tool() {
    local bin_name="$1" pkg_name="$2" var_name="$3" reason="$4"
    local current
    current="$(command -v "$bin_name" || true)"
    if [[ -n "$current" ]]; then
        printf -v "$var_name" '%s' "$current"
        return 0
    fi

    echo
    printf "${C_YELLOW}%b${C_RESET}\n" "$(ui tool_missing_reason "$bin_name" "$reason")"

    if ! [[ -t 0 ]]; then
        log_warn "$(ui tool_noninteractive "$bin_name")"
        return 1
    fi
    if ! command -v apt-get >/dev/null 2>&1; then
        log_warn "$(ui no_apt "$pkg_name")"
        return 1
    fi

    local confirm
    ask_input confirm "$(ui install_prompt "$bin_name" "$pkg_name")"
    confirm="$(trim "$confirm")"
    case "$confirm" in
        n|N|no|No|NO)
            log_warn "$(ui install_skipped "$bin_name")"
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
            log_warn "$(ui no_sudo "$bin_name")"
            return 1
        fi
    fi

    printf "${C_CYAN}%b${C_RESET}\n" "$(ui installing "$pkg_name")"
    if ! $sudo_cmd apt-get install -y "$pkg_name"; then
        printf "${C_GRAY}%b${C_RESET}\n" "$(ui retry_install)"
        $sudo_cmd apt-get update || true
        $sudo_cmd apt-get install -y "$pkg_name" || true
    fi

    current="$(command -v "$bin_name" || true)"
    if [[ -n "$current" ]]; then
        printf -v "$var_name" '%s' "$current"
        printf "${C_GREEN}%b${C_RESET}\n" "$(ui installed "$bin_name")"
        return 0
    fi

    log_warn "$(ui install_failed "$bin_name")"
    return 1
}

# ---------------------------------------------------------------------------
# Progress spinner
# ---------------------------------------------------------------------------
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

# Stop the spinner on exit or Ctrl+C so no background process is left behind.
trap spinner_stop EXIT
trap 'printf "\n${C_YELLOW}%b${C_RESET}" "$(ui interrupt)"; exit 130' INT

# Run a potentially slow SQLite operation with a spinner.
sqlite_exec_slow() {
    local db="$1" msg="$2"; shift 2
    (( DRY_RUN )) && return 0
    spinner_start "$msg"
    sqlite_exec "$db" "$@"
    spinner_stop
    return 0
}

# ---------------------------------------------------------------------------
# External browser cache
# ---------------------------------------------------------------------------
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

# Firefox/Chromium profile cache directories are separate from profile data.
profile_cache_dirs() {
    local id="$1" p="$2"
    local name; name="$(basename -- "$p")"
    local base
    while IFS= read -r base; do
        [[ -n "$base" ]] && echo "$base/$name"
    done <<< "${V_CACHE_BASE[$id]:-}"
}

# ---------------------------------------------------------------------------
# Browser registry and installation variants
# ---------------------------------------------------------------------------
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

# --- Firefox engine ---------------------------------------------------------
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

# LibreWolf has several profile layouts; Flatpak uses its own sandbox path.
register_variant librewolf_deb "LibreWolf" firefox native "librewolf" \
"$HOME/.librewolf
${XDG_CONFIG_HOME:-$HOME/.config}/librewolf/librewolf
$HOME/.mozilla/librewolf"
# LibreWolf cache naming varies, so several plausible XDG bases are checked.
register_cache_base librewolf_deb \
"${XDG_CACHE_HOME:-$HOME/.cache}/librewolf/librewolf
${XDG_CACHE_HOME:-$HOME/.cache}/librewolf
${XDG_CACHE_HOME:-$HOME/.cache}/mozilla/librewolf"

register_variant librewolf_flatpak "LibreWolf (Flatpak)" firefox flatpak "librewolf" \
"$HOME/.var/app/io.gitlab.librewolf-community/.librewolf"
register_cache_base librewolf_flatpak "$HOME/.var/app/io.gitlab.librewolf-community/cache/librewolf"

# Tor Browser Launcher uses a version-dependent profile path resolved at runtime.
register_variant torbrowser "Tor Browser" firefox any "tor-browser/Browser/firefox" \
""

# Waterfox follows the Firefox-style profile layout.
register_variant waterfox_deb "Waterfox" firefox native "waterfox" \
"$HOME/.waterfox"

register_variant waterfox_flatpak "Waterfox (Flatpak)" firefox flatpak "waterfox" \
"$HOME/.var/app/net.waterfox.waterfox/.waterfox"

# Floorp follows the Firefox-style profile layout.
register_variant floorp_deb "Floorp" firefox native "floorp" \
"$HOME/.floorp"

register_variant floorp_flatpak "Floorp (Flatpak)" firefox flatpak "floorp" \
"$HOME/.var/app/one.ablaze.floorp/.floorp"

# Zen Browser follows the Firefox-style profile layout.
register_variant zen_native "Zen Browser" firefox native ".zen/zen" \
"$HOME/.zen"

register_variant zen_flatpak "Zen Browser (Flatpak)" firefox flatpak ".zen/zen" \
"$HOME/.var/app/app.zen_browser.zen/.zen"

# --- Chromium engine --------------------------------------------------------
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

# --- QtWebEngine ------------------------------------------------------------
register_variant falkon_deb "Falkon" falkon native "falkon" \
"$HOME/.config/falkon"

register_variant falkon_flatpak "Falkon (Flatpak)" falkon flatpak "falkon" \
"$HOME/.var/app/org.kde.falkon/config/falkon"

register_cache_dir falkon_deb "$HOME/.cache/falkon"
register_cache_dir falkon_flatpak "$HOME/.var/app/org.kde.falkon/cache/falkon"

# --- WebKitGTK --------------------------------------------------------------
register_variant epiphany_deb "GNOME Web (Epiphany)" epiphany native "epiphany" \
"$HOME/.local/share/epiphany
$HOME/.config/epiphany"

register_variant epiphany_flatpak "GNOME Web (Epiphany, Flatpak)" epiphany flatpak "epiphany" \
"$HOME/.var/app/org.gnome.Epiphany/data/epiphany
$HOME/.var/app/org.gnome.Epiphany/config/epiphany"

register_cache_dir epiphany_deb "$HOME/.cache/epiphany"
register_cache_dir epiphany_flatpak "$HOME/.var/app/org.gnome.Epiphany/cache/epiphany"

# ---------------------------------------------------------------------------
# Configuration-directory resolution
# ---------------------------------------------------------------------------

declare -A V_CONFIG_DIR_CACHE=()

# Tor Browser Launcher directory names vary between versions.
resolve_torbrowser_dir() {
    local base="$HOME/.local/share/torbrowser"
    [[ -d "$base" ]] || { echo ""; return; }
    find "$base" -maxdepth 8 -type d -path "*/TorBrowser/Data/Browser" 2>/dev/null | head -n1
}

# Prefer the Firefox candidate that already contains a real profile.
resolve_firefox_base() {
    local id="$1" c first_existing=""
    while IFS= read -r c; do
        [[ -n "$c" && -d "$c" ]] || continue
        [[ -z "$first_existing" ]] && first_existing="$c"
        [[ -n "$(firefox_profiles "$c")" ]] && { echo "$c"; return; }
    done <<< "${V_CANDIDATES[$id]}"
    echo "$first_existing"
}

# Last-resort LibreWolf discovery for portable or atypical installations.
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
# Running-process detection
# ---------------------------------------------------------------------------
is_own_process_tree() {
    local candidate="$1" parent
    [[ "$candidate" == "$$" ]] && return 0
    parent="$(ps -o ppid= -p "$candidate" 2>/dev/null | tr -d ' ')"
    while [[ "$parent" =~ ^[0-9]+$ ]] && (( parent > 1 )); do
        [[ "$parent" == "$$" ]] && return 0
        parent="$(ps -o ppid= -p "$parent" 2>/dev/null | tr -d ' ')"
    done
    return 1
}

pids_for_variant() {
    local id="$1"
    local kind="${V_KIND[$id]}" broad="${V_PROC[$id]}"
    local pid cmdline
    while IFS= read -r pid; do
        [[ -n "$pid" ]] || continue
        [[ -n "${OWN_ANCESTORS[$pid]+x}" ]] && continue
        is_own_process_tree "$pid" && continue
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

# Ask the user to close an open browser variant before modifying its files.
ensure_browser_closed() {
    local id="$1"
    local label="${V_LABEL[$id]}"

    browser_running "$id" || return 0

    echo
    printf "${C_YELLOW}%b${C_RESET}\n" "$(ui browser_open "$label")"
    echo "  $(ui close_auto)"
    echo "  $(ui cancel)"
    local opt
    ask_input opt "$(ui option)"
    opt="$(trim "$opt")"
    if [[ "$opt" != "1" ]]; then
        printf "${C_RED}%b${C_RESET}\n" "$(ui cancelled_for "$label")"
        return 1
    fi

    local pids=() pid
    while IFS= read -r pid; do
        [[ -n "$pid" ]] && pids+=("$pid")
    done < <(pids_for_variant "$id")
    if (( ${#pids[@]} > 0 )); then
        kill "${pids[@]}" 2>/dev/null || true
    fi

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
        if (( ${#pids[@]} > 0 )); then
            kill -9 "${pids[@]}" 2>/dev/null || true
        fi
        sleep 1
    fi

    # Do not clean a browser that remains running after forced termination.
    if browser_running "$id"; then
        printf "${C_RED}%b${C_RESET}\n" "$(ui close_failed "$label")"
        return 1
    fi

    printf "${C_GREEN}%b${C_RESET}\n" "$(ui closed "$label")"
    return 0
}

# ---------------------------------------------------------------------------
# Profile discovery
# ---------------------------------------------------------------------------

# Read profiles.ini first so relocated Firefox profiles are also discovered.
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

# Falkon stores profiles below a dedicated profiles/ directory.
falkon_profiles() {
    local base="$1"
    [[ -d "$base/profiles" ]] || return 0
    find "$base/profiles" -mindepth 1 -maxdepth 1 -type d 2>/dev/null
}

# GNOME Web treats its data directory as the profile.
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
# FIREFOX / LIBREWOLF / TOR BROWSER — cleaning functions
# ===========================================================================

clean_firefox_cache() {
    local p="$1" id="$2"
    local total
    total=$(remove_paths \
        "$p/cache2" "$p/startupCache" "$p/shader-cache" \
        "$p/thumbnails" "$p/OfflineCache" "$p/offlineCache")
    # Remove Firefox cache inside the profile and under XDG_CACHE_HOME.
    local extra
    while IFS= read -r extra; do
        [[ -n "$extra" ]] && total=$(( total + $(remove_path "$extra") ))
    done < <(profile_cache_dirs "$id" "$p")
    echo "$total"
}

# Crash reports, telemetry pings and diagnostic logs are regenerable residue.
clean_firefox_crash_logs() {
    local p="$1" base="$2"
    local total=0
    total=$(( total + $(remove_path "$base/Crash Reports") ))
    total=$(( total + $(remove_path "$base/Pending Pings") ))
    total=$(( total + $(remove_path "$p/datareporting") ))
    total=$(( total + $(remove_glob "$p/*.log") ))
    echo "$total"
}

# Remove Firefox history without touching bookmarks in places.sqlite.
clean_firefox_history() {
    local p="$1"
    local db="$p/places.sqlite"
    is_regular_file "$db" || { echo 0; return; }
    if [[ -z "$SQLITE_BIN" ]]; then
        log_warn "$(ui tool_missing "sqlite3")"
        echo 0
        return
    fi
    local before after
    before=$(path_size "$db")
    # Dry-run uses the current database size as the maximum recoverable bound.
    if (( DRY_RUN )); then
        echo "$before"
        return
    fi
    backup_before_write "$db"
    sqlite_exec_slow "$db" "$(ui sqlite_vacuum)" \
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

# Clean web storage while preserving extension and internal origins.
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

# Favicons are stored separately from bookmarks in modern Firefox.
clean_firefox_favicons() {
    local p="$1"
    remove_paths "$p/favicons.sqlite" "$p/favicons.sqlite-wal" "$p/favicons.sqlite-shm"
}

clean_firefox_formdata() {
    local p="$1"
    remove_paths "$p/formhistory.sqlite" "$p/formhistory.sqlite-wal" "$p/formhistory.sqlite-shm"
}

# Remove only temporary/expiring Firefox permissions during complete cleaning.
clean_firefox_permissions_temp() {
    local p="$1"
    local db="$p/permissions.sqlite"
    if ! is_regular_file "$db" || [[ -z "$SQLITE_BIN" ]]; then
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
    sqlite_exec_slow "$db" "$(ui sqlite_temp_permissions)" \
        "DELETE FROM moz_perms WHERE expireType != 0" \
        "VACUUM"
    after=$(path_size "$db")
    echo $(( before > after ? before - after : 0 ))
}

# Deep cleaning removes all stored Firefox site permissions.
clean_firefox_permissions_all() {
    local p="$1"
    remove_paths "$p/permissions.sqlite" "$p/permissions.sqlite-wal" "$p/permissions.sqlite-shm" \
                 "$p/content-prefs.sqlite" "$p/content-prefs.sqlite-wal" "$p/content-prefs.sqlite-shm"
}

clean_firefox_security_state() {
    local p="$1"
    remove_path "$p/SiteSecurityServiceState.txt"
}

# Remove stale Firefox lock files only after the browser is confirmed closed.
clean_firefox_stale_locks() {
    local p="$1"
    remove_paths "$p/lock" "$p/.parentlock"
}

# ===========================================================================
# CHROMIUM — cleaning functions
# ===========================================================================

clean_chromium_cache() {
    local p="$1" id="$2"
    local total
    total=$(remove_paths \
        "$p/Cache" "$p/Cache/Cache_Data" "$p/Code Cache" "$p/GPUCache" \
        "$p/GrShaderCache" "$p/ShaderCache" "$p/DawnCache" \
        "$p/DawnGraphiteCache" "$p/DawnWebGPUCache" "$p/Media Cache")
    # Remove Chromium cache both inside the profile and under XDG_CACHE_HOME.
    local extra
    while IFS= read -r extra; do
        [[ -n "$extra" ]] && total=$(( total + $(remove_path "$extra") ))
    done < <(profile_cache_dirs "$id" "$p")
    echo "$total"
}

# Crashpad, diagnostics and debug logs are regenerable.
clean_chromium_crash_logs() {
    local base="$1"
    local total=0
    total=$(( total + $(remove_path "$base/Crashpad") ))
    total=$(( total + $(remove_path "$base/BrowserMetrics") ))
    total=$(( total + $(remove_path "$base/chrome_debug.log") ))
    total=$(( total + $(remove_glob "$base/*.log") ))
    echo "$total"
}

# Component/extension CRX caches are pure regenerated cache data.
clean_chromium_component_cache() {
    local base="$1"
    remove_paths "$base/component_crx_cache" "$base/extensions_crx_cache"
}

# Remove stale Chromium Singleton* lock files after shutdown.
clean_chromium_stale_locks() {
    local base="$1"
    remove_paths "$base/SingletonLock" "$base/SingletonCookie" "$base/SingletonSocket"
}

# Chromium history is stored separately from Bookmarks.
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
    # IndexedDB and legacy WebSQL storage are grouped by origin.
    total=$(( total + $(clean_chromium_origin_dir "$p/IndexedDB") ))
    total=$(( total + $(clean_chromium_origin_dir "$p/databases") ))
    echo "$total"
}

# Clean origin directories while preserving extension-owned storage.
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

# Web Data contains both autofill and search-engine keywords; only autofill is removed.
clean_chromium_formdata() {
    local p="$1"
    local db="$p/Web Data"
    is_regular_file "$db" || { echo 0; return; }
    if [[ -z "$SQLITE_BIN" ]]; then
        log_warn "$(ui tool_missing "sqlite3")"
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
    sqlite_exec_slow "$db" "$(ui sqlite_formdata)" \
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

# Complete cleaning removes only non-durable Chromium permission exceptions.
clean_chromium_permissions_temp() {
    local p="$1"
    local prefs="$p/Preferences"
    is_regular_file "$prefs" || { echo 0; return; }
    if [[ -z "$JQ_BIN" ]]; then
        log_warn "$(ui tool_missing "jq")"
        echo 0
        return
    fi
    local before after tmp
    before=$(path_size "$prefs")
    # Dry-run filters Preferences in memory to estimate the actual size change.
    if (( DRY_RUN )); then
        local filtered_size
        filtered_size="$("$JQ_BIN" -c '
            if .profile.content_settings.exceptions then
                .profile.content_settings.exceptions |= with_entries(
                    select(
                        ((.value.session_model // "Durable") == "Durable")
                        and ((.value.expiration // "0") == "0")
                    )
                )
            else . end
        ' "$prefs" 2>/dev/null | wc -c)"
        [[ "$filtered_size" =~ ^[0-9]+$ ]] || filtered_size=0
        echo $(( before > filtered_size ? before - filtered_size : 0 ))
        return
    fi
    if ! tmp="$(make_sibling_tempfile "$prefs")"; then
        log_warn "$(ui tmp_create_failed "$prefs")"
        echo 0
        return
    fi
    backup_before_write "$prefs"
    # Compact JSON avoids inflating Chromium's single-line Preferences file.
    if "$JQ_BIN" -c '
        if .profile.content_settings.exceptions then
            .profile.content_settings.exceptions |= with_entries(
                select(
                    ((.value.session_model // "Durable") == "Durable")
                    and ((.value.expiration // "0") == "0")
                )
            )
        else . end
    ' "$prefs" > "$tmp" 2>/dev/null && [[ -s "$tmp" ]]; then
        atomic_replace "$tmp" "$prefs"
    else
        rm -f "$tmp"
    fi
    after=$(path_size "$prefs")
    echo $(( before > after ? before - after : 0 ))
}

# Deep cleaning clears Chromium site-permission exceptions from Preferences.
clean_chromium_permissions_all() {
    local p="$1"
    local prefs="$p/Preferences"
    is_regular_file "$prefs" || { echo 0; return; }
    if [[ -z "$JQ_BIN" ]]; then
        log_warn "$(ui tool_missing "jq")"
        echo 0
        return
    fi
    local before after
    before=$(path_size "$prefs")
    # Dry-run calculates the filtered Preferences size without writing to disk.
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
    if ! tmp="$(make_sibling_tempfile "$prefs")"; then
        log_warn "$(ui tmp_create_failed "$prefs")"
        echo 0
        return
    fi
    backup_before_write "$prefs"
    # Keep Preferences compact to avoid replacing deletion with formatting growth.
    if "$JQ_BIN" -c '
        if .profile.content_settings.exceptions then
            .profile.content_settings.exceptions = {}
        else . end
    ' "$prefs" > "$tmp" 2>/dev/null && [[ -s "$tmp" ]]; then
        atomic_replace "$tmp" "$prefs"
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
# FALKON (QtWebEngine) — cleaning functions
# ===========================================================================

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

# Falkon favicon filenames vary by version; check both known forms.
clean_falkon_favicons() {
    local p="$1"
    remove_paths "$p/favicons.db" "$p/icons.db"
}

clean_falkon_sessions() {
    local p="$1"
    remove_path "$p/session.dat"
}

# Falkon form autofill has used both .dat and .json files across versions.
clean_falkon_formdata() {
    local p="$1"
    remove_paths "$p/autofill.dat" "$p/autofill.json"
}

# ===========================================================================
# GNOME WEB / EPIPHANY (WebKitGTK) — cleaning functions
# ===========================================================================

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

# WebKitGTK traditionally stores its favicon database under the cache tree.
clean_epiphany_favicons() {
    local cache_dir="$1"
    remove_paths "$cache_dir/favicons" "$cache_dir/icondatabase"
}

clean_epiphany_sessions() {
    local p="$1"
    remove_paths "$p/session_state.xml" "$p/ephy-session.xml"
}

# ===========================================================================
# Cleaning orchestration
# ===========================================================================

# Category order and labels used in the final summary.
CATEGORY_ORDER=(cache crash bloqueos history cookies storage sessions favicons formdata permisos seguridad walshm)
ui_category() {
    ui "category_$1"
}

# Clean one Firefox-family profile; stale lock files are always removed after shutdown.
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

# Clean one Chromium-family profile; CRX caches count as cache and Singleton* locks are always removed.
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

# Falkon and GNOME Web use different instance-lock mechanisms, so no lock category is reported.
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
# Bordered summary tables
# ---------------------------------------------------------------------------
CONTENT_WIDTH=71
BORDER_WIDTH=$(( CONTENT_WIDTH + 2 ))

box_top()    { echo -e "  ${C_CYAN}┌$(printf '─%.0s' $(seq 1 $BORDER_WIDTH))┐${C_RESET}"; }
box_sep()    { echo -e "  ${C_CYAN}├$(printf '─%.0s' $(seq 1 $BORDER_WIDTH))┤${C_RESET}"; }
box_bottom() { echo -e "  ${C_CYAN}└$(printf '─%.0s' $(seq 1 $BORDER_WIDTH))┘${C_RESET}"; }

# Summary title row: bold browser label with the profile count on the right.
box_title_row() {
    local left="$1" right="$2"
    local pad=$(( CONTENT_WIDTH - ${#left} - ${#right} ))
    (( pad < 1 )) && pad=1
    printf "  ${C_CYAN}│${C_RESET} ${C_BOLD}%s${C_RESET}%*s${C_GRAY}%s${C_RESET} ${C_CYAN}│${C_RESET}\n" \
        "$left" "$pad" "" "$right"
}

# Category row: status icon, localized label and aligned recovered size.
box_category_row() {
    local icon="$1" icon_color="$2" label="$3" value="$4"
    local label_w=58
    # Truncate oversized category labels to keep the border aligned.
    if (( ${#label} > label_w )); then
        label="${label:0:$((label_w - 1))}…"
    fi
    printf "  ${C_CYAN}│${C_RESET} %b %-58s %10s ${C_CYAN}│${C_RESET}\n" \
        "${icon_color}${icon}${C_RESET}" "$label" "$value"
}

# Total row.
box_total_row() {
    local label="$1" value="$2"
    printf "  ${C_CYAN}│${C_RESET} ${C_BOLD}%-60s %10s${C_RESET} ${C_CYAN}│${C_RESET}\n" "$label" "$value"
}

# Free-form warning/info row.
box_text_row() {
    local text="$1" color="${2:-}"
    local pad=$(( CONTENT_WIDTH - ${#text} ))
    (( pad < 0 )) && pad=0
    printf "  ${C_CYAN}│${C_RESET} %s%s%*s${C_RESET} ${C_CYAN}│${C_RESET}\n" "$color" "$text" "$pad" ""
}

# Last total produced by clean_browser(), reused by preview orchestration.
LAST_BROWSER_TOTAL=0

# Clean or preview all profiles for one browser and render a bordered summary.
clean_browser() {
    local id="$1" type="$2" preview="${3:-0}"
    local label="${V_LABEL[$id]}"
    LAST_BROWSER_TOTAL=0

    if ! browser_installed "$id"; then
        (( preview )) || log_skip "$(ui not_installed_skip "$label")"
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
        (( preview )) || log_skip "$(ui no_profiles "$label")"
        return
    fi

    echo
    if (( preview )); then
        printf "${C_BOLD}%b${C_RESET}\n" "$(ui preview_title "$label" "$(ui_profiles "${#profiles[@]}")")"
    else
        printf "${C_BOLD}%b${C_RESET}\n" "$(ui cleaning_title "$label" "$(ui_profiles "${#profiles[@]}")")"
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
    box_title_row "$label" "$(ui_profiles "${#profiles[@]}")"
    box_sep
    local c any_row=0
    for c in "${CATEGORY_ORDER[@]}"; do
        [[ -n "${CAT_BYTES[$c]+x}" ]] || continue
        any_row=1
        box_category_row "✓" "$C_GREEN" "$(ui_category "$c")" "$(human_size "${CAT_BYTES[$c]}")"
    done
    (( any_row )) || box_text_row "$(ui nothing_to_clean)" "$C_GRAY"
    box_sep
    if (( preview )); then
        box_total_row "$(ui estimated_recover)" "$(human_size "$total")"
    else
        box_total_row "$(ui recovered)" "$(human_size "$total")"
    fi
    box_bottom

    LAST_BROWSER_TOTAL=$total

    if (( ! preview )); then
        log_line "$(ui log_recovered "$label" "$(human_size "$total")" "$(ui_type_name "$type")")"
        GRAND_TOTAL=$(( GRAND_TOTAL + total ))
    fi
}

# ---------------------------------------------------------------------------
# Interactive menus
# ---------------------------------------------------------------------------

# Center plain text within a fixed-width field before applying ANSI colors.
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
    echo -e "${C_CYAN}║${C_RESET}${C_GRAY}$(center_text "$(ui by_author "$SCRIPT_AUTHOR")" "$width")${C_RESET}${C_CYAN}║${C_RESET}"
    echo -e "${C_CYAN}╚${border}╝${C_RESET}"
    echo
    local tools=""
    [[ -n "$SQLITE_BIN" ]] && tools+="${OK} sqlite3  " || tools+="${BAD} sqlite3  "
    [[ -n "$JQ_BIN" ]] && tools+="${OK} jq" || tools+="${BAD} jq"
    echo -e "  ${C_GRAY}$(ui tools)${C_RESET} ${tools}"
    # Show each missing-tool reason on its own line so the header never wraps
    # past 80 columns, even when both tools are missing or the locale is verbose.
    [[ -n "$SQLITE_BIN" ]] || printf "  ${C_YELLOW}%b${C_RESET}\n" "$(ui tool_missing_reason "sqlite3" "$(ui sqlite_limited)")"
    [[ -n "$JQ_BIN" ]] || printf "  ${C_YELLOW}%b${C_RESET}\n" "$(ui tool_missing_reason "jq" "$(ui jq_limited)")"
}

ask_clean_type() {
    # Menu text must go to stderr because stdout carries only the internal type token.
    echo >&2
    printf '%s\n' "$(ui type_prompt)" >&2
    echo "  $(ui type_quick)" >&2
    echo "  $(ui type_complete)" >&2
    echo "  $(ui type_cache)" >&2
    echo "  $(ui type_cookies)" >&2
    echo "  $(ui type_history)" >&2
    echo "  $(ui type_deep)" >&2
    echo >&2
    local opt
    ask_input opt "$(ui option)"
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
    local prog
    prog="$(basename -- "$0")"
    cat <<EOF
${SCRIPT_NAME} ${SCRIPT_VERSION} — $(ui help_title)
${OS_LABEL} — $(ui by_author "$SCRIPT_AUTHOR")

$(ui usage)
  ${prog}              $(ui interactive_mode)
  ${prog} --help       $(ui help_show)
  ${prog} --version    $(ui version_show)

$(ui language_auto)

$(ui help_desc)

$(ui supported)
  $(ui supported_firefox)
  $(ui supported_firefox2)
  $(ui supported_chromium)
  $(ui supported_qt)
  $(ui supported_webkit)

$(ui session_log "$LOG_DISPLAY")
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
            printf "%b\n" "$(ui unrecognized_option "$1")" >&2
            printf "%b\n" "$(ui try_help "$(basename -- "$0")")" >&2
            exit 1
            ;;
    esac

    local is_root=0
    [[ "${EUID:-$(id -u)}" -eq 0 ]] && is_root=1
    local root_warning_shown=0

    # Keep the full interactive flow inside one loop so each action returns to the browser selector.
    while true; do
        print_header

                # Show the root warning after print_header(), which clears the screen.
        if (( is_root && ! root_warning_shown )); then
            printf "${C_YELLOW}%b${C_RESET}\n" "$(ui root_warning)"
            printf "%b\n" "$(ui root_warning2)"
            echo
            root_warning_shown=1
        fi

        echo
        printf "${C_GRAY}%b${C_RESET}\n" "$(ui searching)"

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
            printf '%s\n' "$(ui none_found)"
            printf '%s\n' "$(ui supported)"
            echo "  $(ui supported_firefox)"
            echo "  $(ui supported_firefox2)"
            echo "  $(ui supported_chromium)"
            echo "  $(ui supported_qt)"
            echo "  $(ui supported_webkit)"
            exit 0
        fi

        echo
        printf '%s\n' "$(ui found_browsers)"
        local i=1
        for id in "${found[@]}"; do
            printf "  [%d] %-30s ${C_GRAY}(%s)${C_RESET}\n" "$i" "${V_LABEL[$id]}" "$(ui_profiles "${PROFILE_COUNT[$id]}")"
            i=$(( i + 1 ))
        done
        echo
        printf '%s\n' "$(ui select)"
        i=1
        for id in "${found[@]}"; do
            echo "  $i) $(ui clean_one "${V_LABEL[$id]}")"
            i=$(( i + 1 ))
        done
        local all_option=$i
        echo "  $all_option) $(ui clean_all)"
        echo "  0) $(ui exit)"
        echo "  L) $(ui switch_language) ($(ui current_language "$(language_name "$UI_LANG")"))"
        echo
        local choice
        ask_input choice "$(ui option)"
        choice="$(trim "$choice")"

        if [[ "$choice" == "l" || "$choice" == "L" ]]; then
            toggle_language
            printf "${C_GREEN}%b${C_RESET}\n" "$(ui language_changed "$(language_name "$UI_LANG")")"
            sleep 0.2
            continue
        fi

        if [[ "$choice" == "0" ]]; then
            echo
            printf '%s\n' "$(ui goodbye)"
            exit 0
        fi

        local selected=()
        if [[ "$choice" == "$all_option" ]]; then
            selected=("${found[@]}")
        # Force decimal interpretation so inputs such as 08/09 cannot be treated as octal.
        elif [[ "$choice" =~ ^[0-9]+$ ]] && (( 10#$choice >= 1 && 10#$choice < all_option )); then
            selected=("${found[$((10#$choice - 1))]}")
        else
            printf "${C_RED}%b${C_RESET}\n" "$(ui invalid)"
            ask_input _ "$(ui press_enter)"
            continue
        fi

        local type
        type="$(ask_clean_type)"
        if [[ -z "$type" ]]; then
            printf "${C_RED}%b${C_RESET}\n" "$(ui invalid)"
            ask_input _ "$(ui press_enter)"
            continue
        fi

        # Offer optional dependency installation before preview/cleanup, at most once per tool per run.
        if [[ "$type" == "historial" || "$type" == "completa" || "$type" == "profunda" ]] \
            && [[ -z "$SQLITE_BIN" ]] && (( ! SQLITE_INSTALL_DECLINED )); then
            ensure_tool sqlite3 sqlite3 SQLITE_BIN \
                "$(ui reason_history)"
        fi
        if [[ "$type" == "completa" || "$type" == "profunda" ]] \
            && [[ -z "$JQ_BIN" ]] && (( ! JQ_INSTALL_DECLINED )); then
            ensure_tool jq jq JQ_BIN \
                "$(ui reason_jq)"
        fi

        if [[ "$type" == "profunda" ]]; then
            # Deep cleaning only differs from complete cleaning on Firefox/Chromium;
            # skip the warning when it would not actually apply to the selection.
            local show_deep_warning=0 sid
            for sid in "${selected[@]}"; do
                case "${V_FAMILY[$sid]}" in
                    firefox|chromium) show_deep_warning=1; break ;;
                esac
            done
            if (( show_deep_warning )); then
                echo
                printf "${C_YELLOW}%b${C_RESET}\n" "$(ui deep_warning1)"
                printf "${C_YELLOW}%b${C_RESET}\n" "$(ui deep_warning2)"
                printf "${C_YELLOW}%b${C_RESET}\n" "$(ui deep_warning3)"
            fi
        fi

        # Irreversible types are previewed first and only executed after explicit confirmation.
        if [[ "$type" == "historial" || "$type" == "cookies" || "$type" == "completa" || "$type" == "profunda" ]]; then
            echo
            printf "${C_CYAN}%b${C_RESET}\n" "$(ui preview_calc)"
            DRY_RUN=1
            local preview_total=0
            for id in "${selected[@]}"; do
                clean_browser "$id" "$type" 1
                preview_total=$(( preview_total + LAST_BROWSER_TOTAL ))
            done
            DRY_RUN=0

            echo
            printf "${C_BOLD}%s: %s${C_RESET}\n" "$(ui estimated_recover)" "$(human_size "$preview_total")"
            printf "${C_YELLOW}%b${C_RESET}\n" "$(ui irreversible)"
            echo
            local confirm
            ask_input confirm "$(ui confirm)"
            confirm="$(trim "$confirm")"
            case "$confirm" in
                s|S|si|Si|SI|sí|Sí|SÍ|y|Y|yes|YES) ;;
                *)
                    echo
                    printf '%s\n' "$(ui cancelled)"
                    ask_input _ "$(ui press_enter)"
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
            printf "${C_BOLD}%s: %s${C_RESET}\n" "$(ui total)" "$(human_size "$GRAND_TOTAL")"
            echo
        fi

        printf "${C_GRAY}%s${C_RESET}\n" "$(ui session_log_label "$LOG_DISPLAY")"

        echo
        local again
        ask_input again "$(ui again)"
        again="$(trim "$again")"
        case "$again" in
            q|Q|salir|Salir|exit|Exit)
                echo
                printf '%s\n' "$(ui goodbye)"
                exit 0
                ;;
        esac
    done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
