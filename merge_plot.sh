#!/usr/bin/env bash
# Sum every generator's per-seed YODAs and render the data/MC plots.
# Auto-discovers each non-empty subdirectory of yodas/ as one generator line,
# so it just picks up whatever batches have finished. No arguments needed.
set -euo pipefail
cd "$(dirname "$0")"
source ./config.sh
# LCG setup.sh is not strict-mode clean (uses unset $COMPILER etc.), so relax -eu.
set +eu; source "$LCG_VIEW/setup.sh"; set -eu

specs=()
for d in "$PKG"/yodas/*/; do
  [ -d "$d" ] || continue
  name=$(basename "$d")
  files=$(ls "$d"*.yoda 2>/dev/null | paste -sd, -) || true
  [ -n "$files" ] || continue
  echo "  $name: $(ls "$d"*.yoda 2>/dev/null | wc -l) file(s)"
  specs+=( "${name}=${files}" )
done
[ ${#specs[@]} -gt 0 ] || { echo "no YODAs under $PKG/yodas/*/ yet" >&2; exit 1; }

cd "$PKG"
echo ">>> build_comparison.py: ${specs[*]%%=*}"
python3 build_comparison.py "$PKG" out "${specs[@]}"

cd out
rivet-mkhtml -o ../html *.yoda
echo ">>> plots: $PKG/html/index.html"
