# about: Firewall: status, open and close ports (ufw or firewalld)
# category: Security and Users
# icon: 🧱
cmd_firewall_help() {
    cat <<'H'
Usage: yayap firewall <status|allow|deny|on|off> [PORT[/tcp|/udp]]
  Uses ufw or firewalld, whichever is installed.
H
}

_fw_backend() {
    if has ufw; then echo ufw
    elif has firewall-cmd; then echo firewalld
    else return 1
    fi
}

cmd_firewall() {
    local action="${1:-status}" port="${2:-}" fw
    if [[ "$action" == allow || "$action" == deny ]]; then
        [[ "$port" =~ ^[0-9]{1,5}(/(tcp|udp))?$ ]] || die "port must look like 22, 8080/tcp or 53/udp"
    fi
    if ! fw="$(_fw_backend)"; then
        warn "no ufw or firewalld found — install one with: yayap pkg install ufw"
        if [[ "$action" == status ]] && has nft; then
            info "raw nftables ruleset:"; as_root nft list ruleset
        fi
        return 1
    fi
    # firewalld needs an explicit protocol
    [[ "$fw" == firewalld && -n "$port" && "$port" != */* ]] && port="$port/tcp"
    case "$fw:$action" in
        ufw:status)    as_root ufw status verbose ;;
        ufw:allow)     as_root ufw allow "$port" ;;
        ufw:deny)      as_root ufw deny "$port" ;;
        ufw:on)        as_root ufw enable ;;
        ufw:off)       as_root ufw disable ;;
        firewalld:status) as_root firewall-cmd --state && as_root firewall-cmd --list-all ;;
        firewalld:allow)  as_root firewall-cmd --permanent --add-port="$port" && as_root firewall-cmd --reload ;;
        firewalld:deny)   as_root firewall-cmd --permanent --remove-port="$port" && as_root firewall-cmd --reload ;;
        firewalld:on)     as_root systemctl enable --now firewalld ;;
        firewalld:off)    as_root systemctl disable --now firewalld ;;
        *) cmd_firewall_help; return 1 ;;
    esac
}

cmd_firewall_actions() {
    cat <<'A'
Firewall status|status
Open a port|allow {Port_(e.g._22_or_8080/tcp)}
Close a port|deny {Port_(e.g._22_or_8080/tcp)}
Turn the firewall on|on
Turn the firewall off|off
A
}
