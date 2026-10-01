# shellcheck shell=bash
# UI layer for the control center, YaST-style.
# Backends: whiptail or dialog (ncurses TUI), falling back to a plain numbered
# menu. Force one with YAYAP_UI=whiptail|dialog|plain.

ui_backend() {
    if [[ -n "${YAYAP_UI:-}" ]]; then echo "$YAYAP_UI"; return; fi
    if has whiptail; then echo whiptail
    elif has dialog; then echo dialog
    else echo plain
    fi
}

# Dialog geometry that fits the terminal and the number of menu items (arg 1).
# Sets UI_H, UI_W, UI_LIST.
_ui_geometry() {
    local items="${1:-0}" lines cols max
    lines="$(tput lines 2>/dev/null || echo 24)"
    cols="$(tput cols 2>/dev/null || echo 80)"
    max=$(( lines - 12 < 3 ? 3 : lines - 12 ))
    UI_LIST=$(( items < 1 ? 1 : (items > max ? max : items) ))
    UI_H=$(( UI_LIST + 8 ))
    UI_W=$(( cols - 6 > 90 ? 90 : cols - 6 ))
    UI_W=$(( UI_W < 40 ? 40 : UI_W ))
}

# Runs whiptail/dialog and prints the selection; swaps fds so the UI draws on
# the terminal while the answer comes back on stdout.
_ui_box() {
    local b="$1"; shift
    "$b" --backtitle "YaYaP Control Center" "$@" 3>&1 1>&2 2>&3
}

# ui_menu TITLE TEXT TAG ITEM [TAG ITEM...] -> prints chosen TAG; 1 on cancel.
# The cancel button says $UI_CANCEL (default "Back").
ui_menu() {
    local title="$1" text="$2"; shift 2
    local b; b="$(ui_backend)"
    case "$b" in
        whiptail|dialog)
            _ui_geometry $(( $# / 2 ))
            local back=--cancel-button; [[ "$b" == dialog ]] && back=--cancel-label
            _ui_box "$b" --title " $title " "$back" "${UI_CANCEL:-Back}" --menu "$text" \
                "$UI_H" "$UI_W" "$UI_LIST" "$@" ;;
        *)
            local -a tags=()
            local i=0 choice
            printf '\n%s== %s ==%s\n' "$C_BOLD$C_GREEN" "$title" "$C_RESET" >&2
            [[ -n "$text" ]] && printf '%s%s%s\n' "$C_DIM" "$text" "$C_RESET" >&2
            while [[ $# -ge 2 ]]; do
                tags+=("$1"); i=$((i + 1))
                printf '  %s%2d)%s %-14s %s\n' "$C_CYAN" "$i" "$C_RESET" "$1" "$2" >&2
                shift 2
            done
            read -r -p "Choose 1-$i (q = ${UI_CANCEL:-back}): " choice || return 1
            [[ "$choice" =~ ^[0-9]+$ && "$choice" -ge 1 && "$choice" -le $i ]] || return 1
            echo "${tags[choice - 1]}" ;;
    esac
}

# ui_input TITLE PROMPT [DEFAULT] -> prints the answer; 1 on cancel.
ui_input() {
    local title="$1" prompt="$2" def="${3:-}" b
    b="$(ui_backend)"
    case "$b" in
        whiptail|dialog) _ui_geometry; _ui_box "$b" --title " $title " --inputbox "$prompt" 10 "$UI_W" "$def" ;;
        *)
            local ans
            read -r -p "$prompt${def:+ [$def]}: " ans || return 1
            echo "${ans:-$def}" ;;
    esac
}

# ui_pause: wait for Enter before going back to the menu.
ui_pause() {
    local _
    printf '\n%s' "${C_DIM}Press Enter to go back…${C_RESET}"
    read -r _ || true
}

ui_clear() {
    [[ "$(ui_backend)" != plain ]] && clear 2>/dev/null
    return 0
}
