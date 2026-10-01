# about: Services Manager: start, stop, enable and inspect services
# category: System
cmd_services_help() {
    cat <<'H'
Usage: yayap services <list|failed|status|start|stop|restart|enable|disable|logs> [SERVICE]
  Works with systemd and OpenRC.
H
}

_svc_init() {
    if has systemctl && [[ -d /run/systemd/system ]]; then echo systemd
    elif has rc-service; then echo openrc
    else return 1
    fi
}

cmd_services() {
    local action="${1:-list}" svc="${2:-}" init
    init="$(_svc_init)" || die "no supported init system found (need systemd or OpenRC)"
    case "$action" in
        status|start|stop|restart|enable|disable|logs)
            [[ -n "$svc" ]] || die "which service? (yayap services $action NAME)"
            [[ "$svc" =~ ^[A-Za-z0-9@._:-]+$ ]] || die "invalid service name: $svc" ;;
    esac

    case "$init:$action" in
        systemd:list)    systemctl list-units --type=service --all --no-pager --plain --no-legend \
                            | awk '{printf "%-45s %-10s %s\n", $1, $3, $4}' ;;
        systemd:failed)  systemctl --failed --no-pager ;;
        systemd:status)  systemctl status --no-pager "$svc" ;;
        systemd:start|systemd:stop|systemd:restart)
                         as_root systemctl "$action" "$svc" && ok "$svc: $action done" ;;
        systemd:enable|systemd:disable)
                         as_root systemctl "$action" --now "$svc" && ok "$svc ${action}d" ;;
        systemd:logs)    journalctl -u "$svc" -n 50 --no-pager ;;

        openrc:list)     rc-status --all ;;
        openrc:failed)   rc-status --crashed ;;
        openrc:status)   rc-service "$svc" status ;;
        openrc:start|openrc:stop|openrc:restart)
                         as_root rc-service "$svc" "$action" ;;
        openrc:enable)   as_root rc-update add "$svc" default && as_root rc-service "$svc" start ;;
        openrc:disable)  as_root rc-service "$svc" stop; as_root rc-update del "$svc" default ;;
        openrc:logs)     tail -n 50 /var/log/messages 2>/dev/null | grep -i -- "$svc" || warn "no logs found" ;;

        *) cmd_services_help; return 1 ;;
    esac
}

cmd_services_actions() {
    cat <<'A'
List all services|list
Show failed services|failed
Service status|status {Service_name}
Start a service|start {Service_name}
Stop a service|stop {Service_name}
Restart a service|restart {Service_name}
Enable at boot (and start)|enable {Service_name}
Disable at boot (and stop)|disable {Service_name}
Service logs|logs {Service_name}
A
}
