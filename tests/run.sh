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
# --- control center (YaST-style) ---
t "center --list"      out_has "Security and Users" center --list
t "center has actions" out_has "yayap services start {Service_name}" center --list
t "help by category"   out_has "Hardware" help
# plain UI: Misc (6) -> yap (3) -> Enter -> back -> quit
t "center plain nav"   bash -c "printf '6\\n3\\n\\nq\\nq\\n' | YAYAP_UI=plain '$Y' center 2>&1 | grep -q '(oo)'"
# action with a prompt: Security (5) -> passgen -> Custom length (4) -> 12 -> Enter -> back x3
t "center prompt"      bash -c "printf '5\\n2\\n4\\n12\\n\\nq\\nq\\nq\\n' | YAYAP_UI=plain '$Y' center 2>/dev/null | grep -qx '[[:graph:]]\\{12\\}'"
t "center cancel"      bash -c "printf 'q\\n' | YAYAP_UI=plain '$Y' center"
t "no args non-tty"    out_has "Usage:"

# --- YaST-style modules ---
t "users list"         out_has "root" users list
t "users bad name"     bash -c "! '$Y' users info 'x;y'"
t "users addgroup arg" bash -c "! '$Y' users addgroup root"
t "services bad name"  bash -c "! '$Y' services start 'a b;c'"
t "hostname show"      out_has "Hostname" hostname
t "hostname bad set"   bash -c "! '$Y' hostname set '-bad-'"
t "datetime show"      out_has "Time zone" datetime
t "datetime bad tz"    bash -c "! '$Y' datetime set-tz 'Nope/Nowhere'"
t "firewall bad port"  bash -c "! '$Y' firewall allow 'abc'"
t "hardware"           out_has "Memory" hardware
t "hardware bad arg"   bash -c "! '$Y' hardware gpu-go-brr"
t "logs bad arg"       bash -c "! '$Y' logs -n lots"

t "killport bad port"  bash -c "! '$Y' killport abc"

for f in "$ROOT"/bin/yayap "$ROOT"/lib/*.sh "$ROOT"/lib/commands/*.sh "$ROOT"/install.sh; do
    t "syntax $(basename "$f")" bash -n "$f"
done

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[[ $fail -eq 0 ]]
