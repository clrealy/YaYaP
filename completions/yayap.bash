# bash completion for yayap
_yayap() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    if [[ $COMP_CWORD -eq 1 || ( $COMP_CWORD -eq 2 && "${COMP_WORDS[1]}" == help ) ]]; then
        local lib
        lib="$(dirname "$(readlink -f "$(command -v yayap)")")/../lib/commands"
        local f cmds="help center gui"
        for f in "$lib"/*.sh; do
            [[ -e "$f" ]] || continue
            f="${f##*/}"
            cmds+=" ${f%.sh}"
        done
        mapfile -t COMPREPLY < <(compgen -W "$cmds" -- "$cur")
    elif [[ "${COMP_WORDS[1]}" == pkg && $COMP_CWORD -eq 2 ]]; then
        mapfile -t COMPREPLY < <(compgen -W "install remove update search info list" -- "$cur")
    else
        mapfile -t COMPREPLY < <(compgen -f -- "$cur")
    fi
}
complete -F _yayap yayap
