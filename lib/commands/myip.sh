# about: Show local interface addresses and your public IP
cmd_myip() {
    header "Local"
    if has ip; then
        ip -brief address 2>/dev/null | awk '$1 != "lo" {printf "  %-12s %-8s %s\n", $1, $2, $3}'
    else
        hostname -I 2>/dev/null | tr ' ' '\n' | sed '/^$/d; s/^/  /'
    fi
    header "Public"
    local pub=""
    if has curl; then pub="$(curl -fsS --max-time 5 https://ifconfig.me 2>/dev/null)"
    elif has wget; then pub="$(wget -qO- --timeout=5 https://ifconfig.me 2>/dev/null)"
    fi
    printf '  %s\n' "${pub:-unavailable (offline or no curl/wget)}"
}
