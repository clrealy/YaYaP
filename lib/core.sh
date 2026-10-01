# shellcheck shell=bash
# Core helpers shared by every YaYaP command.
# shellcheck disable=SC2034 # color vars are used by command files

# ---------- output ----------
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    C_RESET=$'\e[0m' C_BOLD=$'\e[1m' C_DIM=$'\e[2m'
    C_RED=$'\e[31m' C_GREEN=$'\e[32m' C_YELLOW=$'\e[33m' C_BLUE=$'\e[34m' C_MAGENTA=$'\e[35m' C_CYAN=$'\e[36m'
else
    C_RESET='' C_BOLD='' C_DIM='' C_RED='' C_GREEN='' C_YELLOW='' C_BLUE='' C_MAGENTA='' C_CYAN=''
fi

info()  { printf '%s==>%s %s\n' "$C_BLUE$C_BOLD" "$C_RESET" "$*"; }
ok()    { printf '%s✔%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn()  { printf '%s!%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
err()   { printf '%s✘%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
die()   { err "$*"; exit 1; }
kv()    { printf '  %s%-12s%s %s\n' "$C_CYAN" "$1" "$C_RESET" "$2"; }
header(){ printf '\n%s%s%s\n' "$C_BOLD$C_MAGENTA" "$*" "$C_RESET"; }

# ---------- utils ----------
has() { command -v "$1" >/dev/null 2>&1; }
need() { local c; for c in "$@"; do has "$c" || die "required command not found: $c"; done; }

# Run a command as root, using sudo/doas only when necessary.
as_root() {
    if [[ $EUID -eq 0 ]]; then "$@"
    elif has sudo; then sudo "$@"
    elif has doas; then doas "$@"
    else die "need root privileges but neither sudo nor doas is available"
    fi
}

# Ask a yes/no question; default no. YAYAP_YES=1 auto-confirms.
confirm() {
    [[ "${YAYAP_YES:-0}" == 1 ]] && return 0
    local reply
    read -r -p "$* [y/N] " reply
    [[ "$reply" =~ ^[Yy]([Ee][Ss])?$ ]]
}

# Bytes -> human readable (1024 base).
human_size() {
    awk -v b="${1:-0}" 'BEGIN {
        split("B KiB MiB GiB TiB PiB", u, " "); i = 1
        while (b >= 1024 && i < 6) { b /= 1024; i++ }
        printf (i == 1 ? "%d %s\n" : "%.1f %s\n"), b, u[i]
    }'
}

# ---------- command registry ----------
_cmd_file() { printf '%s/commands/%s.sh' "$YAYAP_LIB" "$1"; }

# Each command file starts with a line: "# about: <one-line description>"
_cmd_about() { sed -n 's/^# about: //p' "$1" | head -n1; }

yayap_commands() {
    local f
    for f in "$YAYAP_LIB"/commands/*.sh; do
        [[ -e "$f" ]] || continue
        basename "$f" .sh
    done
}

yayap_banner() {
    printf '%s' "$C_MAGENTA$C_BOLD"
    cat <<'BANNER'
 __   __    __   __     ____
 \ \ / /_ _ \ \ / /_ _ |  _ \
  \ V / _` | \ V / _` || |_) |
   | | (_| |  | | (_| ||  __/
   |_|\__,_|  |_|\__,_||_|
BANNER
    printf '%s' "$C_RESET"
    printf '  %sYet Another "Yet Another" Program%s  v%s\n' "$C_BOLD" "$C_RESET" "$YAYAP_VERSION"
}

yayap_help() {
    yayap_banner
    printf '\n%sUsage:%s yayap <command> [args...]\n' "$C_BOLD" "$C_RESET"
    printf '       yayap help <command>\n\n%sCommands:%s\n' "$C_BOLD" "$C_RESET"
    local name
    while read -r name; do
        printf '  %s%-12s%s %s\n' "$C_GREEN" "$name" "$C_RESET" "$(_cmd_about "$(_cmd_file "$name")")"
    done < <(yayap_commands)
    printf '\n%sGlobal flags:%s -y/--yes (auto-confirm), --no-color, -V/--version, -h/--help\n' "$C_BOLD" "$C_RESET"
}

# Commands may define cmd_<name>_help; otherwise we print the about line.
yayap_cmd_help() {
    local name="$1" file fn
    file="$(_cmd_file "$name")"
    [[ -f "$file" ]] || die "unknown command: $name (try 'yayap help')"
    # shellcheck source=/dev/null
    source "$file"
    fn="cmd_${name//-/_}_help"
    if declare -F "$fn" >/dev/null; then "$fn"
    else printf 'yayap %s — %s\n' "$name" "$(_cmd_about "$file")"
    fi
}

yayap_main() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -y|--yes) export YAYAP_YES=1; shift ;;
            --no-color) C_RESET='' C_BOLD='' C_DIM='' C_RED='' C_GREEN='' C_YELLOW='' C_BLUE='' C_MAGENTA='' C_CYAN=''; shift ;;
            -V|--version) echo "yayap $YAYAP_VERSION"; return 0 ;;
            -h|--help) yayap_help; return 0 ;;
            *) break ;;
        esac
    done

    local name="${1:-}"
    [[ -z "$name" ]] && { yayap_help; return 0; }
    shift

    if [[ "$name" == help ]]; then
        if [[ $# -gt 0 ]]; then yayap_cmd_help "$1"; else yayap_help; fi
        return
    fi
    [[ "$name" =~ ^[a-z0-9-]+$ ]] || die "invalid command name: $name"

    local file fn
    file="$(_cmd_file "$name")"
    [[ -f "$file" ]] || die "unknown command: $name (try 'yayap help')"
    # shellcheck source=/dev/null
    source "$file"

    if [[ "${1:-}" == -h || "${1:-}" == --help ]]; then
        yayap_cmd_help "$name"; return
    fi
    fn="cmd_${name//-/_}"
    declare -F "$fn" >/dev/null || die "command '$name' does not define $fn"
    "$fn" "$@"
}
