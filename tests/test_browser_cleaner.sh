#!/usr/bin/env bash
# '$1'/'$2'/'$var' inside single-quoted `bash -c '...' _ "$SCRIPT" ...` blocks
# below are the spawned shell's positional params, not this shell's variables.
set -euo pipefail
IFS=$'\n\t'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../script" && pwd)"
SCRIPT="$SCRIPT_DIR/browser-cleaner.sh"

pass=0
fail=0

ok() {
    printf 'ok - %s\n' "$1"
    pass=$((pass + 1))
}

fail_test() {
    printf 'not ok - %s\n' "$1" >&2
    fail=$((fail + 1))
}

assert_eq() {
    local expected="$1" actual="$2" name="$3"
    if [[ "$actual" == "$expected" ]]; then
        ok "$name"
    else
        printf '  expected: %q\n  actual:   %q\n' "$expected" "$actual" >&2
        fail_test "$name"
    fi
}

assert_contains() {
    local haystack="$1" needle="$2" name="$3"
    if [[ "$haystack" == *"$needle"* ]]; then
        ok "$name"
    else
        printf '  missing: %q\n' "$needle" >&2
        fail_test "$name"
    fi
}

assert_not_contains() {
    local haystack="$1" needle="$2" name="$3"
    if [[ "$haystack" != *"$needle"* ]]; then
        ok "$name"
    else
        printf '  unexpected: %q\n' "$needle" >&2
        fail_test "$name"
    fi
}

assert_file_exists() {
    local path="$1" name="$2"
    if [[ -e "$path" ]]; then ok "$name"; else fail_test "$name"; fi
}

assert_file_missing() {
    local path="$1" name="$2"
    if [[ ! -e "$path" ]]; then ok "$name"; else fail_test "$name"; fi
}

strip_ansi() {
    sed -E $'s/\033\[[0-9;?]*[ -\/]*[@-~]//g; s/\r//g'
}

visible_max_width() {
    if command -v python3 >/dev/null 2>&1; then
        python3 -c 'import re, sys, unicodedata
ansi = re.compile(r"\x1b\[[0-9;?]*[ -/]*[@-~]")
def width(s):
    s = ansi.sub("", s).rstrip("\r\n")
    return sum(2 if unicodedata.east_asian_width(ch) in "WF" else 1 for ch in s)
print(max((width(line) for line in sys.stdin), default=0))'
    else
        strip_ansi | LC_ALL=C.UTF-8 wc -L
    fi
}

assert_max_visible_width() {
    local text="$1" max_width="$2" name="$3"
    local width
    width="$(printf '%s\n' "$text" | visible_max_width)"
    if (( width <= max_width )); then
        ok "$name (max $width columns)"
    else
        printf '  max allowed: %d\n  longest line: %d\n' "$max_width" "$width" >&2
        fail_test "$name"
    fi
}

tmp_root="$(mktemp -d)"
trap 'rm -rf -- "$tmp_root"' EXIT

run_source() {
    local lang="$1" extra="$2" command="$3"
    env -i \
        HOME="$tmp_root/home" PATH="$PATH" TERM=xterm \
        LC_ALL=C LC_MESSAGES=C LANG=C \
        BROWSER_CLEANER_LANG="$lang" \
        bash -c "set -e; $extra source \"$SCRIPT\" && $command"
}

mkdir -p "$tmp_root/home"

hide_tools_path() {
    # Mirrors $PATH into one directory, skipping the given command names, so
    # missing-tool tests are deterministic regardless of what the host has.
    local dir; dir="$(mktemp -d "$tmp_root/hide-XXXXXX")"
    local -A skip=()
    local name; for name in "$@"; do skip["$name"]=1; done
    local IFS=':' d f base
    for d in $PATH; do
        [[ -d "$d" ]] || continue
        for f in "$d"/*; do
            [[ -f "$f" && -x "$f" ]] || continue
            base="${f##*/}"
            [[ -n "${skip[$base]:-}" || -e "$dir/$base" ]] && continue
            ln -s -- "$f" "$dir/$base" 2>/dev/null || true
        done
    done
    printf '%s' "$dir"
}


if bash -n "$SCRIPT"; then
    ok "Bash syntax"
else
    fail_test "Bash syntax"
fi

version_output="$(env -i HOME="$tmp_root/home" PATH="$PATH" TERM=xterm LC_ALL=C LC_MESSAGES=C LANG=C BROWSER_CLEANER_LANG=en bash "$SCRIPT" --version)"
assert_eq "Browser-Cleaner 3.8.2" "$version_output" "Version command prints the installed version"

if bash -c 'source "$1"; for k in "${!UI_EN[@]}"; do [[ -v "UI_ES[$k]" ]] || { printf "missing ES key: %s\n" "$k" >&2; exit 1; }; [[ -n "${UI_EN[$k]}" ]] || { printf "empty EN key: %s\n" "$k" >&2; exit 1; }; [[ -n "${UI_ES[$k]}" ]] || { printf "empty ES key: %s\n" "$k" >&2; exit 1; }; done; for k in "${!UI_ES[@]}"; do [[ -v "UI_EN[$k]" ]] || { printf "missing EN key: %s\n" "$k" >&2; exit 1; }; done' _ "$SCRIPT"; then
    ok "English/Spanish catalog parity and non-empty values"
else
    fail_test "English/Spanish catalog parity and non-empty values"
fi

if bash -c 'source "$1"; for k in "${!UI_EN[@]}"; do a=$(printf "%s" "${UI_EN[$k]}" | grep -oE "%([0-9]+\$)?[-+0 #]*[0-9]*(\.[0-9]+)?[sd]" | sort); b=$(printf "%s" "${UI_ES[$k]}" | grep -oE "%([0-9]+\$)?[-+0 #]*[0-9]*(\.[0-9]+)?[sd]" | sort); [[ "$a" == "$b" ]] || { printf "placeholder mismatch: %s\nEN=%q\nES=%q\n" "$k" "$a" "$b" >&2; exit 1; }; done' _ "$SCRIPT"; then
    ok "English/Spanish placeholder parity"
else
    fail_test "English/Spanish placeholder parity"
fi

if bash -c 'source "$1"; for lang in en es; do UI_LANG="$lang"; for k in "${!UI_EN[@]}"; do fmt="${UI_EN[$k]}"; [[ "$lang" == es ]] && fmt="${UI_ES[$k]}"; bad=$(printf "%s" "$fmt" | grep -oE "%([0-9]+\$)?[-+0 #]*[0-9]*(\.[0-9]+)?[bceEfgGioxXnqQT]" | head -n1 || true); [[ -z "$bad" ]] || { printf "unsupported printf directive: lang=%s key=%s directive=%q\n" "$lang" "$k" "$bad" >&2; exit 1; }; done; done' _ "$SCRIPT"; then
    ok "UI catalog contains only supported printf directives"
else
    fail_test "UI catalog contains only supported printf directives"
fi

if bash -c 'source "$1"; bt=$(printf "\140"); cp=$(printf "\044\050"); declare -p UI_EN UI_ES | grep -Fq "$bt" && exit 1; declare -p UI_EN UI_ES | grep -Fq "$cp" && exit 1; exit 0' _ "$SCRIPT"; then
    ok "Catalog strings are shell-safe"
else
    fail_test "Catalog strings are shell-safe"
fi

if ! bash -c '
    source "$1"
    bad=$(printf "%s\n" "${UI_EN[@]}" | grep -E -i "Limpiador|Navegadores|Limpieza|Caché|Historial|Idioma|Inglés|Español|Opción|Registro|Herramientas|Operación|borrado|liberado|Pulse|Pruebe|No se |se ha |¿|Hasta la próxima" || true)
    [[ -z "$bad" ]]
' _ "$SCRIPT"; then
    fail_test "English catalog has no Spanish UI text"
else
    ok "English catalog has no Spanish UI text"
fi

if ! grep -nE '^\s*#.*(Licencia|Presentación|Idioma|Limpieza|Navegador|perfil|archivo|caché|usuario|Opción|Vista previa|Borrado|Instalación)' "$SCRIPT" >/dev/null; then
    ok "Shell comments are translated to English"
else
    fail_test "Shell comments are translated to English"
fi

# shellcheck disable=SC2016 # literal $(...) is the spawned shell's, not this one's
assert_eq "⚠ 'sqlite3' is not installed; to clean browsing history (and, in complete/deep cleaning, form data and permissions) without risking bookmarks or search engines." "$(run_source en '' 'printf "%s" "$(ui tool_missing_reason sqlite3 "$(ui reason_history)")" | sed "s/\\n$//"')" "English missing-tool reason is preserved"
# shellcheck disable=SC2016 # literal $(...) is the spawned shell's, not this one's
assert_eq "⚠ 'sqlite3' no está instalado; para limpiar el historial (y, en limpieza completa/profunda, formularios y permisos) sin arriesgar marcadores ni motores de búsqueda." "$(run_source es '' 'printf "%s" "$(ui tool_missing_reason sqlite3 "$(ui reason_history)")" | sed "s/\\n$//"')" "Spanish missing-tool reason is preserved"

detect() {
    local lc_all="${1-}" lc_messages="${2-}" lang="${3-}"
    # shellcheck disable=SC2016 # $1..$4 below are the spawned shell's, not this one's
    env -i HOME="$tmp_root/home" PATH="$PATH" LC_ALL=C LC_MESSAGES=C LANG=C         bash -c 'source "$1"; LC_ALL="$2"; LC_MESSAGES="$3"; LANG="$4"; detect_ui_language' _ "$SCRIPT" "$lc_all" "$lc_messages" "$lang" 2>/dev/null
}
assert_eq "es" "$(detect es_ES.UTF-8 en_US.UTF-8 en_US.UTF-8)" "Spanish LC_ALL is detected"
assert_eq "es" "$(detect "" es_ES.UTF-8 en_US.UTF-8)" "Spanish LC_MESSAGES is detected"
assert_eq "es" "$(detect "" "" es_ES.UTF-8)" "Spanish LANG is detected"
assert_eq "en" "$(detect C es_ES.UTF-8 es_ES.UTF-8)" "LC_ALL overrides Spanish lower-priority locales"
assert_eq "en" "$(detect "" "" en_US.UTF-8)" "English locale defaults to English"
assert_eq "en" "$(detect "" "" ca_ES.UTF-8)" "Non-Spanish locale defaults to English"
assert_eq "es" "$(detect "" "" es.UTF-8)" "Bare Spanish locale is detected"
assert_eq "es" "$(detect "" "" es_ES@euro)" "Spanish locale variant is detected"

language_only() {
    # shellcheck disable=SC2016 # $1..$3 below are the spawned shell's, not this one's
    env -i HOME="$tmp_root/home" PATH="$PATH" LC_ALL=C LC_MESSAGES=C LANG=C LANGUAGE="$1" \
        bash -c 'source "$1"; unset LC_ALL LC_MESSAGES; LANG=C; detect_ui_language' _ "$SCRIPT" 2>/dev/null
}
assert_eq "es" "$(language_only 'es:en')" "LANGUAGE Spanish preference is detected when no LC locale is set"
assert_eq "en" "$(language_only 'en:es')" "LANGUAGE English preference remains English"

# shellcheck disable=SC2016 # $UI_LANG below belongs to the spawned shell, not this one
assert_eq "es" "$(run_source es '' 'printf "%s" "$UI_LANG"')" "Forced Spanish override"
# shellcheck disable=SC2016 # $UI_LANG below belongs to the spawned shell, not this one
assert_eq "en" "$(run_source en '' 'printf "%s" "$UI_LANG"')" "Forced English override"

missing_tools_path="$(hide_tools_path sqlite3 jq)"
for lang in en es; do
    missing_home="$tmp_root/missing-tools-$lang"
    mkdir -p "$missing_home/.mozilla/firefox/p1"
    printf 'pref\n' > "$missing_home/.mozilla/firefox/p1/prefs.js"
    printf '[Profile0]\nName=Default\nIsRelative=1\nPath=p1\n' > "$missing_home/.mozilla/firefox/profiles.ini"
    missing_output="$(env -i HOME="$missing_home" PATH="$missing_tools_path" TERM=xterm LC_ALL=C LC_MESSAGES=C LANG=C BROWSER_CLEANER_LANG="$lang" bash "$SCRIPT" <<'EOF' 2>&1
1
2
n

0
EOF
)"
    if [[ "$lang" == en ]]; then
        assert_contains "$missing_output" "'sqlite3' is not installed" "English sqlite3 missing-tool warning"
        assert_contains "$missing_output" "No interactive terminal is available" "English noninteractive dependency warning"
        assert_not_contains "$missing_output" "no está instalado" "English missing-tool warning has no Spanish text"
    else
        assert_contains "$missing_output" "'sqlite3' no está instalado" "Spanish sqlite3 missing-tool warning"
        assert_contains "$missing_output" "No hay una terminal interactiva para confirmar la instalación" "Spanish noninteractive dependency warning"
        assert_not_contains "$missing_output" "is not installed" "Spanish missing-tool warning has no English text"
    fi
done

# Deterministic (host-independent) coverage of the sqlite3-missing branch
# inside the cleaning functions themselves: file untouched, 0 reported, warned.
sqlite_fixture='db content untouched'
sqlite_hidden_path="$(hide_tools_path sqlite3)"
for func in clean_firefox_history clean_chromium_formdata; do
    case "$func" in
        clean_firefox_history)   db_name="places.sqlite" ;;
        clean_chromium_formdata) db_name="Web Data" ;;
    esac
    prof="$tmp_root/nosqlite-$func"
    mkdir -p "$prof"
    printf '%s' "$sqlite_fixture" > "$prof/$db_name"
    warn_log="$tmp_root/nosqlite-$func.warn"
    # shellcheck disable=SC2016 # $1/$2/$3 below belong to the spawned shell, not this one
    freed="$(env -i HOME="$prof" PATH="$sqlite_hidden_path" TERM=xterm LC_ALL=C LC_MESSAGES=C LANG=C BROWSER_CLEANER_LANG=en bash -c 'source "$1"; "$2" "$3"' _ "$SCRIPT" "$func" "$prof" 2>"$warn_log")"
    assert_eq "0" "$freed" "$func reports 0 recovered when sqlite3 is hidden"
    assert_eq "$sqlite_fixture" "$(cat "$prof/$db_name")" "$func leaves its file untouched when sqlite3 is hidden"
    assert_contains "$(cat "$warn_log")" "'sqlite3' is not installed (needed for this cleaning category)." "$func warns that sqlite3 is missing"
done

# shellcheck disable=SC2016 # $1/$UI_LANG below belong to the spawned shell, not this one
assert_eq "es" "$(env -i HOME="$tmp_root/home" PATH="$PATH" LANG=es_ES.UTF-8 BROWSER_CLEANER_LANG=xx bash -c 'source "$1"; printf "%s" "$UI_LANG"' _ "$SCRIPT")" "Invalid language override falls back to detected language"
assert_eq "1 profile" "$(run_source en '' 'ui_profiles 1')" "English singular profile label"
assert_eq "2 profiles" "$(run_source en '' 'ui_profiles 2')" "English plural profile label"
assert_eq "1 perfil" "$(run_source es '' 'ui_profiles 1')" "Spanish singular profile label"
assert_eq "2 perfiles" "$(run_source es '' 'ui_profiles 2')" "Spanish plural profile label"
assert_eq "rápida" "$(run_source es '' 'ui_type_name rapida')" "Spanish clean type label"
assert_eq "quick" "$(run_source en '' 'ui_type_name rapida')" "English clean type label"
assert_eq "Limpiar TODOS" "$(run_source es '' 'ui clean_all')" "Spanish translation lookup"
assert_eq "Clean ALL" "$(run_source en '' 'ui clean_all')" "English translation lookup"

# shellcheck disable=SC2016 # $UI_LANG below belongs to the spawned shell, not this one
if run_source en '' 'toggle_language; [[ "$UI_LANG" == es ]]; toggle_language; [[ "$UI_LANG" == en ]]' >/dev/null; then
    ok "Language toggle es/en state change"
else
    fail_test "Language toggle es/en state change"
fi
assert_eq "rapida" "$(run_source en '' 'printf "1\n" | ask_clean_type 2>/dev/null')" "Quick cleaning internal token remains stable"
assert_eq "completa" "$(run_source en '' 'printf "2\n" | ask_clean_type 2>/dev/null')" "Complete cleaning internal token remains stable"
assert_eq "cache" "$(run_source en '' 'printf "3\n" | ask_clean_type 2>/dev/null')" "Cache cleaning internal token remains stable"
assert_eq "cookies" "$(run_source en '' 'printf "4\n" | ask_clean_type 2>/dev/null')" "Cookies internal token remains stable"
assert_eq "historial" "$(run_source en '' 'printf "5\n" | ask_clean_type 2>/dev/null')" "History internal token remains stable"
assert_eq "profunda" "$(run_source en '' 'printf "6\n" | ask_clean_type 2>/dev/null')" "Deep cleaning internal token remains stable"

help_en="$(env -i HOME="$tmp_root/home" PATH="$PATH" TERM=xterm LC_ALL=C LC_MESSAGES=C LANG=C BROWSER_CLEANER_LANG=en bash "$SCRIPT" --help)"
assert_max_visible_width "$help_en" 80 "English help fits an 80-column terminal"
assert_contains "$help_en" "Interactive browser cleaner" "English help header"
assert_contains "$help_en" "Language: the system message locale is detected automatically" "English language help"
assert_not_contains "$help_en" "Limpiador interactivo" "English help has no Spanish title"

help_es="$(env -i HOME="$tmp_root/home" PATH="$PATH" TERM=xterm LC_ALL=C LC_MESSAGES=C LANG=C BROWSER_CLEANER_LANG=es bash "$SCRIPT" --help)"
assert_max_visible_width "$help_es" 80 "Spanish help fits an 80-column terminal"
assert_contains "$help_es" "Limpiador interactivo de navegadores" "Spanish help header"
assert_contains "$help_es" "Idioma: el idioma del sistema se detecta automáticamente" "Spanish language help"
assert_not_contains "$help_es" "Interactive browser cleaner" "Spanish help has no English title"
assert_not_contains "$help_en" "Motor Firefox" "English help has no Spanish engine label"
assert_not_contains "$help_en" "Navegadores" "English help has no Spanish browser heading"
assert_not_contains "$help_es" "Firefox engine" "Spanish help has no English engine label"

invalid_en="$(env -i HOME="$tmp_root/home" PATH="$PATH" TERM=xterm LC_ALL=C LC_MESSAGES=C LANG=C BROWSER_CLEANER_LANG=en bash "$SCRIPT" --unknown 2>&1 || true)"
assert_contains "$invalid_en" "Unrecognized option: --unknown" "Invalid option is translated to English"

for lang in en es; do
    empty_home="$tmp_root/empty-$lang"
    mkdir -p "$empty_home"
    none_output="$(env -i HOME="$empty_home" PATH="$PATH" TERM=xterm LC_ALL=C LC_MESSAGES=C LANG=C BROWSER_CLEANER_LANG="$lang" bash "$SCRIPT")"
    if [[ "$lang" == en ]]; then
        assert_contains "$none_output" "No compatible browsers or user profiles were detected." "English no-browser message"
        assert_contains "$none_output" "Firefox engine" "English no-browser engine list"
        assert_not_contains "$none_output" "Motor Firefox" "English no-browser list has no Spanish label"
    else
        assert_contains "$none_output" "No se detectaron navegadores compatibles ni perfiles de usuario." "Spanish no-browser message"
        assert_contains "$none_output" "Motor Firefox" "Spanish no-browser engine list"
        assert_not_contains "$none_output" "Firefox engine" "Spanish no-browser list has no English label"
    fi
done

readme_en="$(cat "$(dirname "$SCRIPT_DIR")/README.md")"
readme_es="$(cat "$(dirname "$SCRIPT_DIR")/README.es.md")"
assert_contains "$readme_en" "[Español](README.es.md)" "English README links Spanish README"
assert_contains "$readme_es" "[English](README.md)" "Spanish README links English README"
assert_not_contains "$readme_en" "## Sobre el idioma" "English README has no Spanish language heading"
assert_not_contains "$readme_es" "## Language" "Spanish README has no English language heading"

make_firefox_fixture() {
    local home="$1"
    local p="$home/.mozilla/firefox/p1"
    mkdir -p "$p/cache2" "$home/.cache/mozilla/firefox/p1" "$p/Crash Reports"
    printf 'pref\n' > "$p/prefs.js"
    printf 'bookmark\n' > "$p/bookmarks.sqlite"
    printf 'password\n' > "$p/logins.json"
    printf 'cache\n' > "$p/cache2/entry"
    printf 'external\n' > "$home/.cache/mozilla/firefox/p1/entry"
    printf 'log\n' > "$p/browser.log"
    printf '[Profile0]\nName=Default\nIsRelative=1\nPath=p1\n' > "$home/.mozilla/firefox/profiles.ini"
}

run_quick_clean() {
    local lang="$1" out_home="$2"
    make_firefox_fixture "$out_home"
    env -i HOME="$out_home" PATH="$PATH" TERM=xterm \
        LC_ALL=C LC_MESSAGES=C LANG=C BROWSER_CLEANER_LANG="$lang" \
        bash "$SCRIPT" <<'EOF'
1
1
q
EOF
}

run_cookie_preview_cancel() {
    local lang="$1" out_home="$2"
    local p="$out_home/.mozilla/firefox/p1"
    mkdir -p "$p"
    printf 'pref\n' > "$p/prefs.js"
    printf 'cookie\n' > "$p/cookies.sqlite"
    printf '[Profile0]\nName=Default\nIsRelative=1\nPath=p1\n' > "$out_home/.mozilla/firefox/profiles.ini"
    env -i HOME="$out_home" PATH="$PATH" TERM=xterm         LC_ALL=C LC_MESSAGES=C LANG=C BROWSER_CLEANER_LANG="$lang"         bash "$SCRIPT" <<'EOF'
1
4
n

0
EOF
}

for lang in en es; do
    fixture="$tmp_root/$lang"
    mkdir -p "$fixture"
    output="$(run_quick_clean "$lang" "$fixture")"
    assert_eq "0" "$?" "Interactive quick clean exits cleanly ($lang)"
    assert_max_visible_width "$output" 80 "${lang} interactive output fits an 80-column terminal"
    if [[ "$lang" == en ]]; then
        assert_contains "$output" "Browsers found:" "English main menu"
        assert_contains "$output" "Cleaning Firefox..." "English cleaning output"
        assert_contains "$output" "Space recovered" "English summary"
    else
        assert_contains "$output" "Navegadores encontrados:" "Spanish main menu"
        assert_contains "$output" "Limpiando Firefox..." "Spanish cleaning output"
        assert_contains "$output" "Espacio recuperado" "Spanish summary"
    fi
    log_text="$(cat "$fixture/.cache/browser-cleaner/browser-cleaner.log")"
    if [[ "$lang" == en ]]; then
        assert_contains "$log_text" "type: quick" "English log uses localized clean type"
        assert_not_contains "$log_text" "type: rapida" "English log does not leak internal token"
    else
        assert_contains "$log_text" "tipo: rápida" "Spanish log uses localized clean type"
        assert_not_contains "$log_text" "tipo: rapida" "Spanish log does not leak internal token"
    fi
    assert_file_missing "$fixture/.mozilla/firefox/p1/cache2" "Cache directory removed ($lang)"
    assert_file_missing "$fixture/.cache/mozilla/firefox/p1" "External cache removed ($lang)"
    assert_file_missing "$fixture/.mozilla/firefox/p1/browser.log" "Crash/log residue removed ($lang)"
    assert_file_exists "$fixture/.mozilla/firefox/p1/prefs.js" "Preferences preserved ($lang)"
    assert_file_exists "$fixture/.mozilla/firefox/p1/bookmarks.sqlite" "Bookmarks preserved ($lang)"
    assert_file_exists "$fixture/.mozilla/firefox/p1/logins.json" "Passwords preserved ($lang)"
done

for lang in en es; do
    preview_home="$tmp_root/preview-$lang"
    mkdir -p "$preview_home"
    preview_output="$(run_cookie_preview_cancel "$lang" "$preview_home")"
    if [[ "$lang" == en ]]; then
        assert_contains "$preview_output" "Preview: calculating what would be removed" "English irreversible preview"
        assert_contains "$preview_output" "This operation is irreversible." "English irreversible warning"
        assert_contains "$preview_output" "Operation cancelled. Nothing has been deleted." "English cancellation"
    else
        assert_contains "$preview_output" "Vista previa: calculando qué se eliminaría" "Spanish irreversible preview"
        assert_contains "$preview_output" "Esta operación es irreversible." "Spanish irreversible warning"
        assert_contains "$preview_output" "Operación cancelada. No se ha borrado nada." "Spanish cancellation"
    fi
    assert_file_exists "$preview_home/.mozilla/firefox/p1/cookies.sqlite" "Preview cancellation preserves cookies ($lang)"
done

for lang in en es; do
    type_home="$tmp_root/type-$lang"
    mkdir -p "$type_home"
    # shellcheck disable=SC2016 # $1 below belongs to the spawned shell, not this one
    type_output="$(env -i HOME="$type_home" PATH="$PATH" TERM=xterm LC_ALL=C LC_MESSAGES=C LANG=C BROWSER_CLEANER_LANG="$lang" bash -c 'source "$1"; printf "1\n" | ask_clean_type' _ "$SCRIPT" 2>&1)"
    assert_max_visible_width "$type_output" 80 "${lang} cleaning-type menu fits an 80-column terminal"
    if [[ "$lang" == en ]]; then
        assert_contains "$type_output" "Quick cleaning" "English cleaning-type menu"
        assert_contains "$type_output" "Deep cleaning" "English deep-cleaning label"
        assert_not_contains "$type_output" "Limpieza rápida" "English type menu has no Spanish label"
    else
        assert_contains "$type_output" "Limpieza rápida" "Spanish cleaning-type menu"
        assert_contains "$type_output" "Limpieza profunda" "Spanish deep-cleaning label"
        assert_not_contains "$type_output" "Quick cleaning" "Spanish type menu has no English label"
    fi
done

for lang in en es; do
    for input_token in 1 2 3 4 5 6; do
        type_home="$tmp_root/all-types-${lang}-${input_token}"
        mkdir -p "$type_home"
        # shellcheck disable=SC2016 # $1/$2 below belong to the spawned shell, not this one
        type_token="$(env -i HOME="$type_home" PATH="$PATH" TERM=xterm LC_ALL=C LC_MESSAGES=C LANG=C BROWSER_CLEANER_LANG="$lang" bash -c 'source "$1"; printf "%s\n" "$2" | ask_clean_type 2>/dev/null' _ "$SCRIPT" "$input_token")"
        case "$input_token" in
            1) expected_type=rapida ;;
            2) expected_type=completa ;;
            3) expected_type=cache ;;
            4) expected_type=cookies ;;
            5) expected_type=historial ;;
            6) expected_type=profunda ;;
        esac
        assert_eq "$expected_type" "$type_token" "All clean-type choices preserve internal token ($lang, $input_token)"
    done
done

make_locale_parity_fixture() {
    local home="$1"
    local p="$home/.mozilla/firefox/p1"
    mkdir -p "$p/cache2" "$p/storage/default" "$p/crash-reports"
    printf 'cache' > "$p/cache2/cache.dat"
    printf 'storage' > "$p/storage/default/x"
    printf 'crash' > "$p/crash-reports/1.dmp"
    printf 'cookies' > "$p/cookies.sqlite"
    printf 'history' > "$p/places.sqlite"
    printf 'form' > "$p/formhistory.sqlite"
    printf 'perm' > "$p/permissions.sqlite"
    printf 'session' > "$p/sessionstore.jsonlz4"
    printf 'prefs' > "$p/prefs.js"
}

for type in rapida completa cache cookies historial profunda; do
    parity_en="$tmp_root/parity-en-${type}"
    parity_es="$tmp_root/parity-es-${type}"
    make_locale_parity_fixture "$parity_en"
    make_locale_parity_fixture "$parity_es"
    # shellcheck disable=SC2016 # $1..$5 below belong to the spawned shell, not this one
    out_en="$(env -i HOME="$parity_en" PATH="$PATH" TERM=xterm LC_ALL=C LC_MESSAGES=C LANG=C BROWSER_CLEANER_LANG=en bash -c 'source "$1"; BROWSER_CLEANER_NO_COLOR=1; DRY_RUN=1; run_firefox_profile "$2" "$3" "$4" "$5"' _ "$SCRIPT" "$parity_en/.mozilla/firefox/p1" "$type" "$parity_en/.mozilla/firefox" firefox)"
    # shellcheck disable=SC2016 # $1..$5 below belong to the spawned shell, not this one
    out_es="$(env -i HOME="$parity_es" PATH="$PATH" TERM=xterm LC_ALL=C LC_MESSAGES=C LANG=C BROWSER_CLEANER_LANG=es bash -c 'source "$1"; BROWSER_CLEANER_NO_COLOR=1; DRY_RUN=1; run_firefox_profile "$2" "$3" "$4" "$5"' _ "$SCRIPT" "$parity_es/.mozilla/firefox/p1" "$type" "$parity_es/.mozilla/firefox" firefox)"
    assert_eq "$out_en" "$out_es" "EN/ES functional parity for $type"
done

make_preview_fixture() {
    local home="$1"
    local p="$home/.mozilla/firefox/p1"
    mkdir -p "$p/cache2" "$home/.cache/mozilla/firefox/p1"
    printf 'pref\n' > "$p/prefs.js"
    printf 'cache\n' > "$p/cache2/entry"
    printf 'external\n' > "$home/.cache/mozilla/firefox/p1/entry"
    printf '[Profile0]\nName=Default\nIsRelative=1\nPath=p1\n' > "$home/.mozilla/firefox/profiles.ini"
}

for lang in en es; do
    visual_home="$tmp_root/visual-$lang"
    mkdir -p "$visual_home"
    make_preview_fixture "$visual_home"
    # shellcheck disable=SC2016 # $1 below belongs to the spawned shell, not this one
    visual_output="$(env -i HOME="$visual_home" PATH="$PATH" TERM=xterm LC_ALL=C LC_MESSAGES=C LANG=C BROWSER_CLEANER_LANG="$lang" bash -c 'source "$1"; DRY_RUN=1; clean_browser firefox_deb rapida 1' _ "$SCRIPT")"
    assert_max_visible_width "$visual_output" 80 "${lang} browser summary fits an 80-column terminal"
    plain_visual="$(printf '%s\n' "$visual_output" | strip_ansi)"
    border_count="$(printf '%s\n' "$plain_visual" | grep -c '^  ┌.*┐$')"
    assert_eq "1" "$border_count" "${lang} summary has one top border"
    top_border="$(printf '%s\n' "$plain_visual" | grep '^  ┌.*┐$' | head -n1)"
    assert_max_visible_width "$top_border" 80 "${lang} summary top border fits"
    if [[ "$(printf '%s' "$top_border" | sed 's/^  //; s/.$//' | tr -d '─┌┐')" == "" ]]; then
        ok "${lang} summary border has no stray text"
    else
        fail_test "${lang} summary border has no stray text"
    fi
    if [[ "$lang" == en ]]; then
        assert_contains "$plain_visual" "Firefox" "English summary shows browser name"
        assert_contains "$plain_visual" "Cache, thumbnails and temporary files" "English summary localizes cache category"
    else
        assert_contains "$plain_visual" "Firefox" "Spanish summary shows browser name"
        assert_contains "$plain_visual" "Caché, miniaturas y archivos temporales" "Spanish summary localizes cache category"
    fi
done

confirm_en="$(run_source en '' 'ui confirm')"
confirm_es="$(run_source es '' 'ui confirm')"
assert_contains "$confirm_en" "[y/N]" "English confirmation key"
assert_contains "$confirm_es" "[s/N]" "Spanish confirmation key"

toggle_home="$tmp_root/toggle"
mkdir -p "$toggle_home/.mozilla/firefox/p1"
printf 'pref\n' > "$toggle_home/.mozilla/firefox/p1/prefs.js"
toggle_output="$(env -i HOME="$toggle_home" PATH="$PATH" TERM=xterm \
    LC_ALL=C LC_MESSAGES=C LANG=C BROWSER_CLEANER_LANG=en \
    bash "$SCRIPT" <<'EOF'
L
0
EOF
)"
assert_contains "$toggle_output" "L) Switch language" "Language switch option uses L"
assert_contains "$toggle_output" "Clean ALL" "Toggle starts from English"
assert_contains "$toggle_output" "Limpiar TODOS" "Single-letter toggle switches to Spanish"
toggle_output_lower="$(env -i HOME="$toggle_home" PATH="$PATH" TERM=xterm LC_ALL=C LC_MESSAGES=C LANG=C BROWSER_CLEANER_LANG=en bash "$SCRIPT" <<'EOF'
l
0
EOF
)"
assert_contains "$toggle_output_lower" "Limpiar TODOS" "Lowercase l remains backward-compatible"
toggle_output_reverse="$(env -i HOME="$toggle_home" PATH="$PATH" TERM=xterm LC_ALL=C LC_MESSAGES=C LANG=C BROWSER_CLEANER_LANG=es bash "$SCRIPT" <<'EOF'
L
0
EOF
)"
assert_contains "$toggle_output_reverse" "Switch language (current: English)" "Toggle from Spanish shows English state"
assert_contains "$toggle_output_reverse" "Clean ALL" "Single-letter toggle switches from Spanish to English"

# pgrep -f can match the browser name inside the script's own command line.
# shellcheck disable=SC2016 # $1 below belongs to the spawned shell, not this one
process_probe="$(env -i HOME="$tmp_root/home" PATH="$PATH" TERM=xterm LC_ALL=C LC_MESSAGES=C LANG=C BROWSER_CLEANER_LANG=en bash -c '
    source "$1"
    pids_for_variant falkon_deb
' _ "$SCRIPT" 2>/dev/null)"
assert_eq "" "$process_probe" "Own command-line text is not mistaken for an open browser"

symlink_home="$tmp_root/symlink"
outside_dir="$tmp_root/outside"
mkdir -p "$symlink_home/.cache/test" "$outside_dir/keep"
printf 'must survive\n' > "$outside_dir/keep/important.txt"
ln -s "$outside_dir/keep" "$symlink_home/.cache/test/cache-link"
# shellcheck disable=SC2016 # $1/$2 below belong to the spawned shell, not this one
env -i HOME="$symlink_home" PATH="$PATH" LC_ALL=C LANG=C bash -c 'source "$1"; remove_path "$2"' _ "$SCRIPT" "$symlink_home/.cache/test/cache-link" >/dev/null
assert_file_exists "$outside_dir/keep/important.txt" "Symlink cleanup never deletes the link target"
assert_file_missing "$symlink_home/.cache/test/cache-link" "Symlink cleanup removes only the link"

# Deterministic (host-independent) coverage of the jq-missing branch inside
# the cleaning functions themselves: file untouched, 0 reported, warned.
jq_fixture='{"profile":{"content_settings":{"exceptions":{"https://example.test,*":{"session_model":"NonPersistent"}}}},"marker":"untouched"}'
jq_hidden_path="$(hide_tools_path jq)"
for func in clean_chromium_permissions_temp clean_chromium_permissions_all; do
    prof="$tmp_root/nojq-$func"
    mkdir -p "$prof"
    printf '%s' "$jq_fixture" > "$prof/Preferences"
    warn_log="$tmp_root/nojq-$func.warn"
    # shellcheck disable=SC2016 # $1/$2/$3 below belong to the spawned shell, not this one
    freed="$(env -i HOME="$prof" PATH="$jq_hidden_path" TERM=xterm LC_ALL=C LC_MESSAGES=C LANG=C BROWSER_CLEANER_LANG=en bash -c 'source "$1"; "$2" "$3"' _ "$SCRIPT" "$func" "$prof" 2>"$warn_log")"
    assert_eq "0" "$freed" "$func reports 0 recovered when jq is hidden"
    assert_eq "$jq_fixture" "$(cat "$prof/Preferences")" "$func leaves Preferences untouched when jq is hidden"
    assert_contains "$(cat "$warn_log")" "'jq' is not installed (needed for this cleaning category)." "$func warns that jq is missing"
done

if command -v jq >/dev/null 2>&1; then
    jq_home="$tmp_root/chromium-jq"
    jq_profile="$jq_home/.config/chromium/Default"
    mkdir -p "$jq_profile"
    cat > "$jq_profile/Preferences" <<'EOF'
{"profile":{"content_settings":{"exceptions":{"https://temporary.example,*":{"session_model":"NonPersistent"},"https://durable.example,*":{"session_model":"Durable","expiration":"0"}}}},"homepage":"KEEP"}
EOF
    # shellcheck disable=SC2016 # $1/$2 below belong to the spawned shell, not this one
    jq_result="$(env -i HOME="$jq_home" PATH="$PATH" TERM=xterm LC_ALL=C LC_MESSAGES=C LANG=C BROWSER_CLEANER_LANG=en bash -c '
        source "$1"
        JQ_BIN="$(command -v jq)"
        DRY_RUN=0
        clean_chromium_permissions_temp "$2"
        cat "$2/Preferences"
    ' _ "$SCRIPT" "$jq_profile")"
    assert_contains "$jq_result" '"https://durable.example,*"' "Chromium temporary permission cleanup preserves durable permissions"
    assert_not_contains "$jq_result" '"https://temporary.example,*"' "Chromium temporary permission cleanup removes temporary permissions"
    assert_contains "$jq_result" '"homepage":"KEEP"' "Chromium permission cleanup preserves unrelated Preferences"
    jq_mode_home="$tmp_root/chromium-jq-mode"
    jq_mode_profile="$jq_mode_home/.config/chromium/Default"
    mkdir -p "$jq_mode_profile"
    cat > "$jq_mode_profile/Preferences" <<'EOF'
{"profile":{"content_settings":{"exceptions":{"https://temporary.example,*":{"session_model":"NonPersistent"}}}},"homepage":"KEEP"}
EOF
    chmod 640 "$jq_mode_profile/Preferences"
    mkdir -p "$jq_mode_profile/Local Storage/leveldb" "$jq_mode_profile/IndexedDB"
    printf 'extension-local-state\n' > "$jq_mode_profile/Local Storage/leveldb/000003.log"
    mkdir -p "$jq_mode_profile/IndexedDB/https_example.test_0" "$jq_mode_profile/IndexedDB/chrome-extension_demo_0"
    printf 'web-state\n' > "$jq_mode_profile/IndexedDB/https_example.test_0/state"
    printf 'extension-state\n' > "$jq_mode_profile/IndexedDB/chrome-extension_demo_0/state"
    jq_mode_before="$(stat -c '%a' "$jq_mode_profile/Preferences")"
    # shellcheck disable=SC2016 # $1/$2 below belong to the spawned shell, not this one
    env -i HOME="$jq_mode_home" PATH="$PATH" TERM=xterm LC_ALL=C LC_MESSAGES=C LANG=C bash -c '
        source "$1"
        JQ_BIN="$(command -v jq)"
        clean_chromium_permissions_temp "$2"
    ' _ "$SCRIPT" "$jq_mode_profile" >/dev/null
    jq_mode_after="$(stat -c '%a' "$jq_mode_profile/Preferences")"
    assert_eq "$jq_mode_before" "$jq_mode_after" "Atomic Preferences replacement preserves file mode"
    assert_file_exists "$jq_mode_profile/Preferences.bak" "Preferences replacement creates a backup"
    if jq empty "$jq_mode_profile/Preferences" >/dev/null 2>&1; then
        ok "Atomic Preferences replacement keeps valid JSON"
    else
        fail_test "Atomic Preferences replacement keeps valid JSON"
    fi
    # shellcheck disable=SC2016 # $1/$2 below belong to the spawned shell, not this one
    env -i HOME="$jq_mode_home" PATH="$PATH" LC_ALL=C LANG=C bash -c '
        source "$1"
        JQ_BIN="$(command -v jq)"
        clean_chromium_storage "$2" >/dev/null
    ' _ "$SCRIPT" "$jq_mode_profile"
    assert_file_exists "$jq_mode_profile/Local Storage/leveldb/000003.log" "Chromium global Local Storage is preserved"
    assert_file_missing "$jq_mode_profile/IndexedDB/https_example.test_0" "Chromium origin storage is cleaned"
    assert_file_exists "$jq_mode_profile/IndexedDB/chrome-extension_demo_0/state" "Chromium extension storage is preserved"
else
    printf 'ok - Chromium jq permission cleanup test skipped (jq not installed)\n'
    pass=$((pass + 1))
fi


printf '\n%d passed, %d failed\n' "$pass" "$fail"
(( fail == 0 ))
