# about: Find the largest files under a path
# category: System
# icon: 🐘
cmd_bigfiles_help() {
    cat <<'H'
Usage: yayap bigfiles [PATH] [-n N] [-m MIN_SIZE]
  Lists the N (default 15) biggest files under PATH (default: .),
  ignoring files smaller than MIN_SIZE (e.g. 500K, 10M, 2G; default 1M).
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
    local min_bytes
    min_bytes="$(parse_size "$min")" || die "bad size: $min (try 500K, 10M, 2G)"
    # stat -c works with GNU coreutils and busybox (find -printf is GNU-only).
    find "$path" -xdev -type f -exec stat -c $'%s\t%n' {} + 2>/dev/null \
        | awk -F'\t' -v min="$min_bytes" '$1 >= min' \
        | sort -rn | head -n "$n" \
        | while IFS=$'\t' read -r size file; do
            printf '%10s  %s\n' "$(human_size "$size")" "$file"
        done
}

cmd_bigfiles_actions() {
    cat <<'A'
Biggest files in a directory|{Directory}
Biggest files over a size|{Directory} -m {Minimum_size_(e.g._100M)}
A
}
