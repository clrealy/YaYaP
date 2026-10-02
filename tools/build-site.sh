#!/usr/bin/env bash
# Build the website into _site/ (or $1). Data comes straight from the code:
# the module list and the version.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:-$ROOT/_site}"
Y="$ROOT/bin/yayap"
export NO_COLOR=1

rm -rf -- "$OUT"
mkdir -p "$OUT"
cp -r "$ROOT/site/." "$OUT/"
cp "$ROOT/lib/gui/yayap.svg" "$OUT/yayap.svg"
cp "$ROOT/share/banner.svg" "$OUT/banner.svg"

"$Y" center --tsv > "$OUT/modules.tsv"
"$Y" --version | awk '{print $2}' > "$OUT/version.txt"

python3 - "$OUT" <<'PY'
import json, sys, os
out = sys.argv[1]
cats, mods = [], {}
for line in open(os.path.join(out, "modules.tsv"), encoding="utf-8"):
    f = line.rstrip("\n").split("\t")
    if f[0] == "M":
        _, cat, name, icon, about = f
        if not cats or cats[-1]["name"] != cat:
            cats.append({"name": cat, "modules": []})
        mods[name] = {"name": name, "icon": icon, "about": about, "actions": []}
        cats[-1]["modules"].append(mods[name])
    elif f[0] == "A":
        mods[f[1]]["actions"].append(f[2])
data = {
    "version": open(os.path.join(out, "version.txt")).read().strip(),
    "categories": cats,
}
# a .js file (not .json) so the page also works opened straight from disk
with open(os.path.join(out, "data.js"), "w", encoding="utf-8") as f:
    f.write("window.YAYAP = " + json.dumps(data, ensure_ascii=False) + ";\n")
for tmp in ("modules.tsv", "version.txt"):
    os.remove(os.path.join(out, tmp))
PY
echo "site built -> $OUT"
