# about: Serve a directory over HTTP in one command
# category: Network
# icon: 🛰️
cmd_serve_help() { echo "Usage: yayap serve [DIR] [-p PORT]   (default: . on port 8000)"; }
cmd_serve() {
    local dir="." port=8000
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -p) port="${2:?}"; shift 2 ;;
            *) dir="$1"; shift ;;
        esac
    done
    [[ -d "$dir" ]] || die "not a directory: $dir"
    info "serving $(cd "$dir" && pwd) on http://0.0.0.0:$port  (Ctrl-C to stop)"
    if has python3; then
        python3 -m http.server "$port" --directory "$dir"
    elif has busybox; then
        busybox httpd -f -p "$port" -h "$dir"
    else
        die "need python3 or busybox"
    fi
}

cmd_serve_actions() {
    cat <<'A'
Serve current directory on :8000|
Serve a directory|{Directory} -p {Port}
A
}
