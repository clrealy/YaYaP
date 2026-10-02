# about: Hostname: show or change this machine's name
# category: Network
# icon: 🏷️
cmd_hostname_help() { echo "Usage: yayap hostname [show | set NAME]"; }
cmd_hostname() {
    case "${1:-show}" in
        show)
            kv "Hostname" "$(hostname 2>/dev/null || cat /etc/hostname)"
            if has hostnamectl; then hostnamectl 2>/dev/null | sed 's/^ */  /'; fi
            return 0 ;;
        set)
            local name="${2:-}"
            [[ "$name" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$ ]] || die "invalid hostname: '$name'"
            if has hostnamectl && [[ -d /run/systemd/system ]]; then
                as_root hostnamectl set-hostname "$name"
            else
                echo "$name" | as_root tee /etc/hostname >/dev/null && as_root hostname "$name"
            fi && ok "hostname is now $name" ;;
        *) cmd_hostname_help; return 1 ;;
    esac
}
cmd_hostname_actions() {
    cat <<'A'
Show hostname|show
Change hostname|set {New_hostname}
A
}
