# about: Find (and optionally remove) junk: caches, trash, old logs
cmd_clean_help() {
    cat <<'H'
Usage: yayap clean [--force]
  Without --force it's a dry run that just reports reclaimable space.
  Targets: ~/.cache, the trash, thumbnails, and (as root) package caches
  and journald logs older than 2 weeks.
H
}
cmd_clean() {
    local force=0
    [[ "${1:-}" == --force ]] && force=1

    local -a targets=(
        "$HOME/.cache"
        "$HOME/.local/share/Trash"
        "$HOME/.thumbnails"
    )
    local t size total=0
    header "User junk"
    for t in "${targets[@]}"; do
        [[ -d "$t" ]] || continue
        size="$(du -sb -- "$t" 2>/dev/null | cut -f1)"
        total=$((total + ${size:-0}))
        kv "$(human_size "${size:-0}")" "$t"
    done
    printf '  %sTotal reclaimable: %s%s\n' "$C_BOLD" "$(human_size "$total")" "$C_RESET"

    if [[ $force -eq 0 ]]; then
        warn "dry run — re-run with --force to delete"
        return 0
    fi
    confirm "delete the contents of these directories?" || return 1
    for t in "${targets[@]}"; do
        [[ -d "$t" ]] && find "$t" -mindepth 1 -delete 2>/dev/null
    done
    ok "user junk removed"

    if [[ $EUID -eq 0 ]]; then
        header "System"
        if has apt-get; then apt-get clean && ok "apt cache cleaned"; fi
        if has dnf; then dnf clean all -q && ok "dnf cache cleaned"; fi
        if has pacman; then pacman -Sc --noconfirm >/dev/null && ok "pacman cache cleaned"; fi
        if has journalctl; then journalctl --vacuum-time=2weeks -q && ok "journal vacuumed"; fi
    else
        warn "run as root to also clean package caches and journald logs"
    fi
}
