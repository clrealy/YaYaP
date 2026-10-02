# about: System Log viewer (journald or /var/log)
# category: System
# icon: 📜
cmd_logs_help() {
    cat <<'H'
Usage: yayap logs [-n LINES] [-e] [-b] [-f] [-u UNIT]
  -e errors only   -b this boot   -f follow   -u one systemd unit
H
}
cmd_logs() {
    local n=50 errors=0 boot=0 follow=0 unit=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n) n="${2:?}"; shift 2 ;;
            -e) errors=1; shift ;;
            -b) boot=1; shift ;;
            -f) follow=1; shift ;;
            -u) unit="${2:?}"; shift 2 ;;
            *) cmd_logs_help; return 1 ;;
        esac
    done
    [[ "$n" =~ ^[0-9]+$ ]] || die "-n needs a number"

    if has journalctl && journalctl -n 0 >/dev/null 2>&1; then
        local -a args=(--no-pager -n "$n")
        [[ $errors -eq 1 ]] && args+=(-p err)
        [[ $boot -eq 1 ]] && args+=(-b)
        [[ $follow -eq 1 ]] && args+=(-f)
        [[ -n "$unit" ]] && args+=(-u "$unit")
        journalctl "${args[@]}"
        return
    fi

    local f
    for f in /var/log/syslog /var/log/messages; do
        [[ -r "$f" ]] || continue
        if [[ $follow -eq 1 ]]; then tail -n "$n" -f "$f"
        elif [[ $errors -eq 1 ]]; then grep -iE 'err|fail|crit|panic' "$f" | tail -n "$n"
        else tail -n "$n" "$f"
        fi
        return
    done
    die "no journald and no readable /var/log/syslog or /var/log/messages (try as root)"
}
cmd_logs_actions() {
    cat <<'A'
Recent messages|
Errors only|-e
This boot|-b
Follow live (Ctrl-C to stop)|-f
Logs for one service|-u {Unit_name}
A
}
