# about: Show a quick overview of this machine
cmd_sysinfo() {
    local distro="unknown" cpu cores mem_total mem_avail up
    if [[ -r /etc/os-release ]]; then
        # shellcheck source=/dev/null
        distro="$(. /etc/os-release && echo "${PRETTY_NAME:-$NAME}")"
    fi
    cpu="$(sed -n 's/^model name[[:space:]]*: //p' /proc/cpuinfo 2>/dev/null | head -n1)"
    cores="$(nproc 2>/dev/null || echo '?')"
    mem_total="$(awk '/^MemTotal:/ {print $2 * 1024}' /proc/meminfo 2>/dev/null)"
    mem_avail="$(awk '/^MemAvailable:/ {print $2 * 1024}' /proc/meminfo 2>/dev/null)"
    up="$(awk '{s=int($1); d=int(s/86400); h=int(s%86400/3600); m=int(s%3600/60);
               printf "%dd %dh %dm", d, h, m}' /proc/uptime 2>/dev/null)"

    header "System"
    kv "Host"    "$(hostname 2>/dev/null || cat /etc/hostname 2>/dev/null)"
    kv "User"    "${USER:-$(id -un)}"
    kv "OS"      "$distro"
    kv "Kernel"  "$(uname -sr)"
    kv "Arch"    "$(uname -m)"
    kv "Uptime"  "${up:-?}"
    kv "Shell"   "${SHELL:-?}"

    header "Hardware"
    kv "CPU"     "${cpu:-unknown} ($cores threads)"
    kv "Load"    "$(cut -d' ' -f1-3 /proc/loadavg 2>/dev/null)"
    if [[ -n "$mem_total" ]]; then
        kv "Memory" "$(human_size $((mem_total - mem_avail))) / $(human_size "$mem_total") used"
    fi
    kv "Disk /"  "$(df -h / 2>/dev/null | awk 'NR==2 {print $3 " / " $2 " used (" $5 ")"}')"
    if [[ -d /sys/class/power_supply/BAT0 ]]; then
        kv "Battery" "$(cat /sys/class/power_supply/BAT0/capacity)% ($(cat /sys/class/power_supply/BAT0/status))"
    fi
}
