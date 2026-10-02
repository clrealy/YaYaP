# about: Ouroboros: YaYaP eats itself, hatches from the copy and checks it's still itself
# category: Misc
# icon: 🐍
cmd_ouroboros_help() {
    cat <<'H'
Usage: yayap ouroboros [-n GENERATIONS] [--fingerprint]

  The snake eats its own tail. YaYaP packs itself up with its own `backup`
  module, unpacks the copy with its own `extract` module, and hands over to
  the copy, which does the same, GENERATIONS times (default 3, max 20).
  The last generation compares its fingerprint with the first one's: if
  they match, the snake caught its tail and the install can rebuild itself.

  --fingerprint   just print this install's fingerprint (sha256 of bin/ + lib/)
H
}

# sha256 over every file in bin/ and lib/ (names + contents), stable across copies.
_ouro_fingerprint() {
    need sha256sum
    (
        cd -- "$1" || exit 1
        find bin lib -type f ! -path '*/__pycache__/*' ! -name '*.pyc' | LC_ALL=C sort \
            | while IFS= read -r f; do printf '%s  %s\n' "$(sha256sum < "$f" | cut -d' ' -f1)" "$f"; done
    ) | sha256sum | cut -d' ' -f1
}

cmd_ouroboros() {
    local total=3
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -n) total="${2:-}"; shift 2 || shift ;;
            --fingerprint) _ouro_fingerprint "$YAYAP_ROOT"; return ;;
            *) cmd_ouroboros_help; return 1 ;;
        esac
    done
    [[ "$total" =~ ^[0-9]+$ && "$total" -ge 1 && "$total" -le 20 ]] || die "generations must be 1-20"

    local gen="${YAYAP_OUROBOROS_GEN:-0}" origin="${YAYAP_OUROBOROS_ORIGIN:-}" nest="${YAYAP_OUROBOROS_TMP:-}" me
    me="$(_ouro_fingerprint "$YAYAP_ROOT")" || die "couldn't fingerprint $YAYAP_ROOT"

    if [[ $gen -eq 0 ]]; then
        origin="$me"
        nest="$(mktemp -d "${TMPDIR:-/tmp}/yayap-ouroboros.XXXXXX")" || die "no temp dir"
        # shellcheck disable=SC2064 # expand now: $nest is local and gone by EXIT time
        trap "rm -rf -- $(printf '%q' "$nest")" EXIT
        header "🐍 Ouroboros: YaYaP is about to eat itself ($total generations)"
        printf '  gen 0  %s  %s\n' "${me:0:12}" "$YAYAP_ROOT"
    fi

    if [[ $gen -ge $total ]]; then
        # the head reaches the tail
        if [[ "$me" == "$origin" ]]; then
            printf '\n'
            cat <<'SNAKE'
       .-~~~~~-.
     .'         '.
    /             \
   |               |    the snake caught its tail
    \             /
     '.         .'
       '-~~~~~-🐍
SNAKE
            ok "generation $gen is byte-for-byte the same YaYaP as generation 0 (${me:0:12})"
            return 0
        fi
        die "generation $gen mutated: ${me:0:12} != ${origin:0:12}"
    fi

    # eat: pack ourselves up with our own backup module...
    local next=$((gen + 1)) den="$nest/gen$((gen + 1))" archive child
    mkdir -p -- "$den" || die "couldn't make $den"
    "$YAYAP_ROOT/bin/yayap" --no-color backup "$YAYAP_ROOT/bin" "$YAYAP_ROOT/lib" -o "$den" >/dev/null \
        || die "gen $gen couldn't swallow itself"
    archive="$(find "$den" -maxdepth 1 -name '*.tar.gz' | head -n1)"
    [[ -n "$archive" ]] || die "gen $gen: no archive came out"

    # ...and hatch with our own extract module
    "$YAYAP_ROOT/bin/yayap" --no-color extract "$archive" -d "$den/body" >/dev/null \
        || die "gen $gen couldn't hatch the copy"
    child="$den/body/bin/yayap"
    [[ -x "$child" ]] || die "gen $next hatched without a body"
    printf '  gen %d  %s  ate itself (%s) and hatched\n' "$next" "$(_ouro_fingerprint "$den/body" | cut -c1-12)" \
        "$(human_size "$(stat -c %s "$archive")")"

    # hand over to the copy; it's the copy that keeps going from here
    env -u YAYAP_LIB YAYAP_OUROBOROS_GEN="$next" YAYAP_OUROBOROS_ORIGIN="$origin" YAYAP_OUROBOROS_TMP="$nest" \
        "$child" ouroboros -n "$total"
}

cmd_ouroboros_actions() {
    cat <<'A'
Eat itself 3 times|
Eat itself N times|-n {Generations_(1-20)}
Show this install's fingerprint|--fingerprint
A
}
