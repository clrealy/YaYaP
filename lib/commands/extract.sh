# about: Extract any archive (tar, zip, 7z, rar, gz, xz, zst, ...)
cmd_extract_help() { echo "Usage: yayap extract ARCHIVE... [-d DEST]"; }
cmd_extract() {
    local dest="" files=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d) dest="${2:?}"; shift 2 ;;
            *) files+=("$1"); shift ;;
        esac
    done
    [[ ${#files[@]} -gt 0 ]] || { cmd_extract_help; return 1; }
    if [[ -n "$dest" ]]; then mkdir -p -- "$dest" || return 1; fi

    local f out rc=0
    for f in "${files[@]}"; do
        [[ -f "$f" ]] || { err "no such file: $f"; rc=1; continue; }
        f="$(realpath -- "$f")"
        out="${dest:-.}"
        info "extracting $(basename "$f")"
        (
            cd -- "$out" || exit 1
            case "${f,,}" in
                *.tar|*.tar.*|*.tgz|*.tbz|*.tbz2|*.txz|*.tzst) tar -xf "$f" ;;
                *.zip|*.jar|*.apk|*.whl) need unzip; unzip -q "$f" ;;
                *.7z)  need 7z; 7z x -y "$f" >/dev/null ;;
                *.rar) if has unrar; then unrar x -y "$f" >/dev/null; else need 7z; 7z x -y "$f" >/dev/null; fi ;;
                *.gz)  gunzip -kc "$f" > "$(basename "${f%.*}")" ;;
                *.bz2) bunzip2 -kc "$f" > "$(basename "${f%.*}")" ;;
                *.xz)  unxz -kc "$f" > "$(basename "${f%.*}")" ;;
                *.zst) need zstd; zstd -dqc "$f" > "$(basename "${f%.*}")" ;;
                *.deb) need ar; ar x "$f" ;;
                *.rpm) need rpm2cpio cpio; rpm2cpio "$f" | cpio -idm --quiet ;;
                *) err "don't know how to extract: $f"; exit 1 ;;
            esac
        ) && ok "done -> $out" || rc=1
    done
    return $rc
}
