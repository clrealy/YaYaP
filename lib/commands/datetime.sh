# about: Date and Time: clock, time zone and network time (NTP)
# category: System
# icon: 🕒
cmd_datetime_help() {
    cat <<'H'
Usage: yayap datetime [show | zones [FILTER] | set-tz ZONE | ntp on|off]
H
}

_current_tz() {
    local tz=""
    has timedatectl && tz="$(timedatectl show -p Timezone --value 2>/dev/null)"
    [[ -z "$tz" && -L /etc/localtime ]] && tz="$(readlink /etc/localtime | sed 's|.*/zoneinfo/||')"
    [[ -z "$tz" && -r /etc/timezone ]] && tz="$(cat /etc/timezone)"
    echo "${tz:-unknown}"
}

cmd_datetime() {
    local action="${1:-show}"
    case "$action" in
        show)
            kv "Local" "$(date '+%A %Y-%m-%d %H:%M:%S %Z')"
            kv "UTC" "$(date -u '+%Y-%m-%d %H:%M:%S')"
            kv "Time zone" "$(_current_tz)"
            if has timedatectl; then
                kv "NTP sync" "$(timedatectl show -p NTPSynchronized --value 2>/dev/null || echo '?')"
            fi ;;
        zones)
            if has timedatectl && timedatectl list-timezones >/dev/null 2>&1; then
                timedatectl list-timezones
            else
                (cd /usr/share/zoneinfo 2>/dev/null && find . -type f -name '[A-Z]*' | sed 's|^\./||' | grep / | sort)
            fi | grep -i -- "${2:-}" ;;
        set-tz)
            local tz="${2:-}"
            [[ "$tz" =~ ^[A-Za-z0-9_+/-]+$ && -f "/usr/share/zoneinfo/$tz" ]] || die "unknown time zone: '$tz' (try: yayap datetime zones Europe)"
            if has timedatectl && [[ -d /run/systemd/system ]]; then
                as_root timedatectl set-timezone "$tz"
            else
                as_root ln -sf "/usr/share/zoneinfo/$tz" /etc/localtime && echo "$tz" | as_root tee /etc/timezone >/dev/null
            fi && ok "time zone set to $tz" ;;
        ntp)
            case "${2:-}" in
                on|off) need timedatectl; as_root timedatectl set-ntp "$([[ $2 == on ]] && echo true || echo false)" && ok "NTP $2" ;;
                *) die "usage: yayap datetime ntp on|off" ;;
            esac ;;
        *) cmd_datetime_help; return 1 ;;
    esac
}

cmd_datetime_actions() {
    cat <<'A'
Show date, time and zone|show
Find a time zone|zones {Search_(e.g._Europe)}
Change time zone|set-tz {Time_zone_(e.g._America/New_York)}
Turn network time on|ntp on
Turn network time off|ntp off
A
}
