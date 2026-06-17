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
mkargs=()
for f in mc_*.yoda; do t="${f#mc_}"; t="${t%.yoda}"; mkargs+=("$f:$t"); done
mkargs+=("ref.yoda:CMS data")
# Isolate matplotlib caches and disable problematic font config caching
export MPLCONFIGDIR="${TMPDIR:-/tmp}/mpl-$$"
export FONTCONFIG_PATH="/tmp/fc-$$"
export MPLBACKEND=Agg
mkdir -p "$MPLCONFIGDIR" "$FONTCONFIG_PATH"
rivet-mkhtml -o ../html "${mkargs[@]}"

# Post-process generated plot scripts to disable LaTeX rendering
for py in ../html/CMS_2026_PAS_SMP_25_010/*.py; do
  sed -i "s/^import matplotlib/import matplotlib\nmpl.rcParams['text.usetex'] = False/" "$py"
done
echo ">>> plots: $PKG/html/index.html"
