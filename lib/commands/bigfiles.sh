# about: Find the largest files under a path
cmd_bigfiles_help() {
    cat <<'H'
Usage: yayap bigfiles [PATH] [-n N] [-m MIN_SIZE]
  Lists the N (default 15) biggest files under PATH (default: .),
  ignoring files smaller than MIN_SIZE (find -size syntax, default 1M).
H
}
cmd_bigfiles() {
    local path="." n=15 min="1M"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n) n="${2:?}"; shift 2 ;;
            -m) min="${2:?}"; shift 2 ;;
            *) path="$1"; shift ;;
        esac
    done
    [[ -d "$path" ]] || die "not a directory: $path"
    find "$path" -xdev -type f -size +"$min" -printf '%s\t%p\n' 2>/dev/null \
        | sort -rn | head -n "$n" \
        | while IFS=$'\t' read -r size file; do
            printf '%10s  %s\n' "$(human_size "$size")" "$file"
        done
}
