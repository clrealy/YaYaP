# about: Yet another yap. Wisdom from the toolbox.
# category: Misc
cmd_yap() {
    local -a yaps=(
        "There are only two hard things in CS: cache invalidation, naming things, and off-by-one errors."
        "It's not a bug, it's an undocumented feature."
        "rm -rf / is just aggressive spring cleaning."
        "Yet Another Yet Another Program: because 'Yet Another Program' was taken."
        "Have you tried turning it off and on again? (systemctl restart life.service)"
        "sudo make me a sandwich."
        "The year of the Linux desktop is always next year."
        "Works on my machine. Ship the machine."
        "Real programmers count from 0."
        "vim users don't quit, they just :q! out of situations."
    )
    local msg="${*:-${yaps[RANDOM % ${#yaps[@]}]}}"
    local line
    line="$(printf '%*s' "$(( ${#msg} + 2 ))" '' | tr ' ' '-')"
    printf ' %s\n< %s >\n %s\n' "$line" "$msg" "$line"
    cat <<'YAK'
        \   ^__^
         \  (oo)\_______
            (__)\  yap  )\/\
                ||----w |
                ||     ||
YAK
}
