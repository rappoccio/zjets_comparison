#!/usr/bin/env bash
# After the jobs finish: sum the per-seed YODAs and render the data/MC plots.
# Extra generators can be overlaid by passing "NAME=dir" (a dir of .yoda files):
#   ./merge_plot.sh VINCIA=$PKG/yodas/vincia  aMCNLO=$PKG/yodas/amcnlo
set -euo pipefail
cd "$(dirname "$0")"
source ./config.sh
# LCG setup.sh is not strict-mode clean (uses unset $COMPILER etc.), so relax -eu.
set +eu; source "$LCG_VIEW/setup.sh"; set -eu

collect() {                      # collect <name> <dir>  ->  NAME=f1,f2,...
  local name="$1" dir="$2" files
  files=$(ls "$dir"/*.yoda 2>/dev/null | paste -sd, -)
  [ -n "$files" ] || { echo "no .yoda files in $dir" >&2; return 1; }
  echo "${name}=${files}"
}

specs=( "$(collect "${TAG^^}" "$OUTDIR")" )
for extra in "$@"; do specs+=( "$(collect "${extra%%=*}" "${extra#*=}")" ); done

cd "$PKG"
echo ">>> build_comparison.py: ${specs[*]%%=*}"
python3 build_comparison.py "$PKG" out "${specs[@]}"

cd out
mkargs=()
for f in mc_*.yoda; do t="${f#mc_}"; t="${t%.yoda}"; mkargs+=("$f:$t"); done
mkargs+=("ref.yoda:CMS data")
rivet-mkhtml -o ../html "${mkargs[@]}"
echo ">>> plots: $PKG/html/index.html"
