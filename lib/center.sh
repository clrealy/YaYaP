# shellcheck shell=bash
# The YaYaP Control Center: a YaST-style category -> module -> action browser.
#
# Command files opt in with header lines:
#   # about: one-line description
#   # category: Software | System | Hardware | Network | Security and Users | Misc
# and may define cmd_<name>_actions, printing one "Label|args" line per action.
# Args are split on spaces; a {Some_prompt} token asks the user for a value
# (underscores become spaces in the prompt); {Things...} splits the answer into
# several args. Without actions, the module just
# runs with no arguments.

# shellcheck disable=SC2153 # YAYAP_LIB comes from bin/yayap
# shellcheck source=lib/ui.sh
source "$YAYAP_LIB/ui.sh"

# Module names in a category, one per line.
_center_modules() {
    local name
    while read -r name; do
        [[ "$(_cmd_category "$(_cmd_file "$name")")" == "$1" ]] && echo "$name"
    done < <(yayap_commands)
}

# Run a module in a subshell so `die` only ends the action, not the center.
# A real INT handler (not an ignore) lets Ctrl-C stop e.g. `serve` and come back.
_center_run() {
    local name="$1"; shift
    ui_clear
    printf '%s▶ yayap %s %s%s\n' "$C_BOLD$C_BLUE" "$name" "$*" "$C_RESET"
    trap ':' INT
    ( "cmd_${name//-/_}" "$@" )
    local rc=$?
    trap - INT
    [[ $rc -ne 0 ]] && printf '\n%s(exited with status %d)%s' "$C_YELLOW" "$rc" "$C_RESET"
    ui_pause
}

# Expand a "args template" into ARGS, prompting for {Placeholders}. 1 = cancelled.
_center_fill_args() {
    local title="$1" template="$2" tok val
    local -a toks
    ARGS=()
    read -r -a toks <<<"$template"
    for tok in "${toks[@]}"; do
        if [[ "$tok" =~ ^\{(.+)\}$ ]]; then
            local prompt="${BASH_REMATCH[1]}" many=0
            [[ "$prompt" == *... ]] && { many=1; prompt="${prompt%...}"; }
            val="$(ui_input "$title" "${prompt//_/ }")" || return 1
            [[ -n "$val" ]] || return 1
            if [[ $many -eq 1 ]]; then
                local -a parts
                read -r -a parts <<<"$val"
                ARGS+=("${parts[@]}")
            else
                ARGS+=("$val")
            fi
        else
            ARGS+=("$tok")
        fi
    done
}

_center_module() {
    local name="$1" file fn
    file="$(_cmd_file "$name")"
    # shellcheck source=/dev/null
    source "$file"
    fn="cmd_${name//-/_}_actions"
    if ! declare -F "$fn" >/dev/null; then
        _center_run "$name"; return
    fi

    local -a labels=() templates=() items=()
    local i choice
    while IFS='|' read -r label template; do
        [[ -n "$label" ]] || continue
        labels+=("$label"); templates+=("$template")
    done < <("$fn")
    for i in "${!labels[@]}"; do items+=("$((i + 1))" "${labels[i]}"); done

    while choice="$(ui_menu "$name" "$(_cmd_about "$file")" "${items[@]}")"; do
        i=$((choice - 1))
        _center_fill_args "${labels[i]}" "${templates[i]}" || continue
        _center_run "$name" "${ARGS[@]}"
    done
}

_center_category() {
    local cat="$1" name choice
    local -a items=()
    while read -r name; do
        items+=("$name" "$(_cmd_about "$(_cmd_file "$name")")")
    done < <(_center_modules "$cat")
    while choice="$(ui_menu "$cat" "Pick a module" "${items[@]}")"; do
        _center_module "$choice"
    done
}

# Print the whole tree (non-interactive, handy for docs and tests).
yayap_center_list() {
    local cat name file fn label template
    for cat in "${YAYAP_CATEGORIES[@]}"; do
        printf '%s%s%s\n' "$C_BOLD$C_MAGENTA" "$cat" "$C_RESET"
        while read -r name; do
            file="$(_cmd_file "$name")"
            printf '  %s%-12s%s %s\n' "$C_GREEN" "$name" "$C_RESET" "$(_cmd_about "$file")"
            # shellcheck source=/dev/null
            source "$file"
            fn="cmd_${name//-/_}_actions"
            declare -F "$fn" >/dev/null || continue
            while IFS='|' read -r label template; do
                [[ -n "$label" ]] && printf '    %s• %-34s%s yayap %s %s\n' "$C_DIM" "$label" "$C_RESET" "$name" "$template"
            done < <("$fn")
        done < <(_center_modules "$cat")
    done
}

yayap_center() {
    if [[ "${1:-}" == --list ]]; then yayap_center_list; return; fi
    local cat choice n
    local -a items=()
    for cat in "${YAYAP_CATEGORIES[@]}"; do
        n="$(_center_modules "$cat" | wc -l)"
        [[ $n -gt 0 ]] && items+=("$cat" "$n module$([[ $n -gt 1 ]] && echo s)")
    done
    while choice="$(UI_CANCEL=Quit ui_menu "YaYaP Control Center" "Yet Another \"Yet Another\" Program — pick a category" "${items[@]}")"; do
        _center_category "$choice"
    done
    ui_clear
}
