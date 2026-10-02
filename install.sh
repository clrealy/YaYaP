#!/usr/bin/env bash
# Install YaYaP. Default prefix: ~/.local (no root needed).
#   ./install.sh                 install to ~/.local
#   PREFIX=/usr/local ./install.sh
#   ./install.sh --uninstall
#   DESTDIR=/tmp/pkg PREFIX=/usr/local ./install.sh   (staged install, for packagers like gurt)
set -euo pipefail

PREFIX="${PREFIX:-$HOME/.local}"
DESTDIR="${DESTDIR:-}"
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SHARE="$DESTDIR$PREFIX/share/yayap"
BIN="$DESTDIR$PREFIX/bin/yayap"
COMP="$DESTDIR$PREFIX/share/bash-completion/completions/yayap"
APPS="$DESTDIR$PREFIX/share/applications"
ICON="$DESTDIR$PREFIX/share/icons/hicolor/scalable/apps/yayap.svg"

if [[ "${1:-}" == --uninstall ]]; then
    rm -rf -- "$SHARE" "$BIN" "$COMP" "$APPS/yayap.desktop" "$APPS/yayap-tui.desktop" "$ICON"
    echo "yayap uninstalled from $PREFIX"
    exit 0
fi

mkdir -p "$SHARE" "$(dirname "$BIN")" "$(dirname "$COMP")" "$APPS" "$(dirname "$ICON")"
rm -rf -- "${SHARE:?}/bin" "${SHARE:?}/lib"
cp -r "$SRC/bin" "$SRC/lib" "$SHARE/"
ln -sf ../share/yayap/bin/yayap "$BIN"   # relative, so it survives DESTDIR staging
cp "$SRC/completions/yayap.bash" "$COMP"
cp "$SRC/share/yayap.desktop" "$SRC/share/yayap-tui.desktop" "$APPS/"   # app menu: GUI + terminal
cp "$SRC/lib/gui/yayap.svg" "$ICON"                                      # the parrot 🦜

echo "yayap installed -> $BIN"
[[ -n "$DESTDIR" ]] && exit 0
case ":$PATH:" in
    *":$PREFIX/bin:"*) ;;
    *) echo "note: add $PREFIX/bin to your PATH" ;;
esac
