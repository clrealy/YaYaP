# about: List listening TCP/UDP ports and the processes behind them
cmd_ports() {
    if has ss; then
        ss -tulpnH 2>/dev/null | awk '{
            proc = $7; sub(/^users:\(\("/, "", proc); sub(/".*/, "", proc)
            printf "%-5s %-28s %s\n", $1, $5, (proc == "" ? "-" : proc)
        }' | sort -u | { printf '%-5s %-28s %s\n' PROTO ADDRESS PROCESS; cat; }
    elif has netstat; then
        netstat -tulpn 2>/dev/null
    else
        die "need 'ss' (iproute2) or 'netstat' (net-tools)"
    fi
    [[ $EUID -ne 0 ]] && warn "run as root to see processes owned by other users"
    return 0
}
