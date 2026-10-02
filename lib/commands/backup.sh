# about: Make a timestamped .tar.gz backup of files or directories
# category: System
# icon: 💾
cmd_backup_help() {
    cat <<'H'
Usage: yayap backup PATH... [-o OUTDIR]
  Creates OUTDIR/<name>-YYYYmmdd-HHMMSS.tar.gz (default OUTDIR: ~/yayap-backups).
H
}
cmd_backup() {
    local outdir="${YAYAP_BACKUP_DIR:-$HOME/yayap-backups}" paths=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -o) outdir="${2:?}"; shift 2 ;;
            *) paths+=("$1"); shift ;;
        esac
    done
    [[ ${#paths[@]} -gt 0 ]] || { cmd_backup_help; return 1; }
    local p
    for p in "${paths[@]}"; do [[ -e "$p" ]] || die "no such path: $p"; done

    mkdir -p -- "$outdir" || return 1
    local name archive
    name="$(basename "$(abs_path "${paths[0]}")")"
    [[ ${#paths[@]} -gt 1 ]] && name="backup"
    archive="$outdir/$name-$(date +%Y%m%d-%H%M%S).tar.gz"

    info "archiving ${#paths[@]} path(s) -> $archive"
    # Store each path relative to its parent so the archive has no absolute paths.
    local -a args=()
    for p in "${paths[@]}"; do
        p="$(abs_path "$p")"
        args+=(-C "$(dirname "$p")" "$(basename "$p")")
    done
    tar -czf "$archive" "${args[@]}" || die "tar failed"
    ok "backup created ($(human_size "$(stat -c %s "$archive")"))"
}

cmd_backup_actions() {
    cat <<'A'
Back up a path|{Path_to_back_up}
Back up a path to a folder|{Path_to_back_up} -o {Output_folder}
A
}
