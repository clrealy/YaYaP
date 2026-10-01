#!/usr/bin/env bash
# Minimal test runner for YaYaP. Usage: tests/run.sh
set -u
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
Y="$ROOT/bin/yayap"
export NO_COLOR=1
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass=0 fail=0

t() {  # t "name" command...
    local name="$1"; shift
    if "$@" >"$TMP/out" 2>&1; then pass=$((pass+1)); printf 'ok   %s\n' "$name"
    else fail=$((fail+1)); printf 'FAIL %s\n' "$name"; sed 's/^/     /' "$TMP/out"; fi
}
out_has() { "$Y" "${@:2}" 2>&1 | grep -q -- "$1"; }

t "version"            out_has "yayap 0." --version
t "help lists cmds"    out_has "sysinfo" help
t "help per command"   out_has "Usage: yayap backup" help backup
t "-h on command"      out_has "Usage: yayap pkg" pkg -h
t "unknown cmd fails"  bash -c "! '$Y' nope"
t "bad cmd name fails" bash -c "! '$Y' '../etc'"
t "sysinfo"            out_has "Kernel" sysinfo
t "yap"                out_has "hello" yap hello
t "passgen length"     bash -c "[[ \$('$Y' passgen -l 33 | head -1 | tr -d '\n' | wc -c) -eq 33 ]]"
t "passgen count"      bash -c "[[ \$('$Y' passgen -c 4 | wc -l) -eq 4 ]]"
t "passgen simple"     bash -c "'$Y' passgen -s -l 200 | grep -qx '[A-Za-z0-9]*'"
t "passgen bad arg"    bash -c "! '$Y' passgen -l abc"
t "clean dry run"      out_has "dry run" clean
t "disk"               out_has "Filesystems" disk "$ROOT"

mkdir -p "$TMP/src/sub"; echo hi >"$TMP/src/sub/a.txt"
dd if=/dev/zero of="$TMP/src/big.bin" bs=1M count=2 status=none
t "bigfiles"           out_has "big.bin" bigfiles "$TMP/src"
t "bigfiles min size"  bash -c "! '$Y' bigfiles '$TMP/src' -m 3M | grep -q big.bin"
t "bigfiles bad size"  bash -c "! '$Y' bigfiles '$TMP/src' -m huge"
t "backup"             "$Y" backup "$TMP/src" -o "$TMP/bk"
t "extract tar.gz"     bash -c "'$Y' extract \"\$(ls '$TMP'/bk/*.tar.gz)\" -d '$TMP/x' && [[ -f '$TMP/x/src/sub/a.txt' ]]"
t "extract .gz"        bash -c "gzip -k '$TMP/src/sub/a.txt' && '$Y' extract '$TMP/src/sub/a.txt.gz' -d '$TMP/g' && grep -q hi '$TMP/g/a.txt'"
command -v bzip2 >/dev/null && \
t "extract tar.bz2"    bash -c "tar -cjf '$TMP/s.tbz2' -C '$TMP' src && '$Y' extract '$TMP/s.tbz2' -d '$TMP/b' && [[ -f '$TMP/b/src/sub/a.txt' ]]"
t "backup rel path"    bash -c "cd '$TMP/src' && '$Y' backup sub -o '$TMP/bk2' && tar -tzf '$TMP'/bk2/sub-*.tar.gz | grep -q '^sub/a.txt'"
t "extract missing"    bash -c "! '$Y' extract '$TMP/nope.zip'"
t "killport bad port"  bash -c "! '$Y' killport abc"

for f in "$ROOT"/bin/yayap "$ROOT"/lib/*.sh "$ROOT"/lib/commands/*.sh "$ROOT"/install.sh; do
    t "syntax $(basename "$f")" bash -n "$f"
done

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
