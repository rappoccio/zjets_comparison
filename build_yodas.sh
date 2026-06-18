#!/usr/bin/env bash
# Combine YODA files from all MC generators into out/ with per-process histogram paths.
# Auto-discovers generators from yodas/ subdirectories.
set -euo pipefail
cd "$(dirname "$0")"
source ./config.sh
set +eu; source "$LCG_VIEW/setup.sh"; set -eu

echo ">>> Scanning for MC generators in $PKG/yodas/..."
specs=()
for d in "$PKG"/yodas/*/; do
  [ -d "$d" ] || continue
  name=$(basename "$d")
  files=$(ls "$d"*.yoda 2>/dev/null | paste -sd, -) || true
  [ -n "$files" ] || continue
  echo "    ✓ $name: $(ls "$d"*.yoda 2>/dev/null | wc -l) file(s)"
  specs+=( "${name}=${files}" )
done

if [ ${#specs[@]} -eq 0 ]; then
  echo "ERROR: no YODAs found under $PKG/yodas/*/" >&2
  exit 1
fi

echo ""
echo ">>> Building combined YODA files in out/..."
python3 build_comparison.py "$PKG" out "${specs[@]}"
echo "✓ Done"
