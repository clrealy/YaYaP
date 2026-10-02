# about: Disk usage overview and biggest directories under a path
# category: Hardware
# icon: 💽
cmd_disk_help() {
    cat <<'H'
Usage: yayap disk [PATH] [-n N]
  Shows mounted filesystem usage, then the N (default 10) biggest
  directories directly under PATH (default: current directory).
H
}
cmd_disk() {
    local path="." n=10
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n) n="${2:?-n needs a number}"; shift 2 ;;
            *) path="$1"; shift ;;
        esac
    done
    [[ -d "$path" ]] || die "not a directory: $path"

    header "Filesystems"
    df -h -x tmpfs -x devtmpfs -x squashfs -x overlay 2>/dev/null || df -h

    header "Biggest under $(cd "$path" && pwd)"
    du -xsh -- "$path"/* "$path"/.[!.]* 2>/dev/null | sort -rh | head -n "$n"
}

cmd_disk_actions() {
    cat <<'A'
Overview of current directory|
Overview of a directory|{Directory}
A
}
