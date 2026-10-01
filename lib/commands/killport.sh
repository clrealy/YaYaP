# about: Kill whatever process is listening on a port
cmd_killport_help() { echo "Usage: yayap killport PORT [SIGNAL]   (default signal: TERM)"; }
cmd_killport() {
    local port="${1:-}" sig="${2:-TERM}" pids
    [[ "$port" =~ ^[0-9]+$ ]] || { cmd_killport_help; return 1; }
    if has fuser; then
        pids="$(fuser "$port"/tcp 2>/dev/null; fuser "$port"/udp 2>/dev/null)"
    elif has ss; then
        pids="$(ss -tulpnH "sport = :$port" 2>/dev/null | grep -o 'pid=[0-9]*' | cut -d= -f2)"
    else
        die "need 'fuser' (psmisc) or 'ss' (iproute2)"
    fi
    pids="$(tr -s ' \n' '\n' <<<"$pids" | grep -E '^[0-9]+$' | sort -u)"
    [[ -n "$pids" ]] || { warn "nothing listening on port $port"; return 1; }
    local pid
    for pid in $pids; do
        info "port $port -> pid $pid ($(ps -o comm= -p "$pid" 2>/dev/null))"
    done
    confirm "send SIG$sig to these processes?" || return 1
    # shellcheck disable=SC2086
    kill -s "$sig" $pids && ok "sent SIG$sig"
}
