# about: Generate strong random passwords
# category: Security and Users
cmd_passgen_help() {
    cat <<'H'
Usage: yayap passgen [-l LENGTH] [-c COUNT] [-s]
  -l  length (default 20)   -c  how many (default 1)
  -s  simple: letters and digits only (no symbols)
H
}
cmd_passgen() {
    local len=20 count=1 charset='A-Za-z0-9!@#$%^&*()_+=.,:;?-'
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -l) len="${2:?}"; shift 2 ;;
            -c) count="${2:?}"; shift 2 ;;
            -s) charset='A-Za-z0-9'; shift ;;
            *) cmd_passgen_help; return 1 ;;
        esac
    done
    [[ "$len" =~ ^[0-9]+$ && "$len" -gt 0 && "$count" =~ ^[0-9]+$ ]] || die "length/count must be positive integers"
    local i
    for ((i = 0; i < count; i++)); do
        LC_ALL=C tr -dc "$charset" </dev/urandom | head -c "$len"
        echo
    done
}

cmd_passgen_actions() {
    cat <<'A'
One strong password|
Five strong passwords|-c 5
Letters+digits only|-s
Custom length|-l {Length}
A
}
