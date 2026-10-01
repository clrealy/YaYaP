#!/usr/bin/env bash
# Install YaYaP. Default prefix: ~/.local (no root needed).
#   ./install.sh                 install to ~/.local
#   PREFIX=/usr/local ./install.sh
#   ./install.sh --uninstall
set -euo pipefail

PREFIX="${PREFIX:-$HOME/.local}"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARE="$PREFIX/share/yayap"
BIN="$PREFIX/bin/yayap"
COMP="$PREFIX/share/bash-completion/completions/yayap"

if [[ "${1:-}" == --uninstall ]]; then
    rm -rf -- "$SHARE" "$BIN" "$COMP"
    echo "yayap uninstalled from $PREFIX"
    exit 0
fi

mkdir -p "$SHARE" "$PREFIX/bin" "$(dirname "$COMP")"
rm -rf -- "${SHARE:?}/bin" "${SHARE:?}/lib"
cp -r "$SRC/bin" "$SRC/lib" "$SHARE/"
ln -sf "$SHARE/bin/yayap" "$BIN"
cp "$SRC/completions/yayap.bash" "$COMP"

echo "yayap installed -> $BIN"
case ":$PATH:" in
    *":$PREFIX/bin:"*) ;;
    *) echo "note: add $PREFIX/bin to your PATH" ;;
esac
