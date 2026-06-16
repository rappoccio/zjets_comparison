#!/usr/bin/env bash
# Local interactive test of a shower generator (no HTCondor, no xrdcp), so you can
# see the full PYTHIA/VINCIA output and any Abort.
#   ./pythia/run_local.sh [MODEL] [NEV] [SEED]
#     MODEL 1 = PYTHIA8 simple shower, 2 = VINCIA   (default 2)
#     NEV defaults 2000, SEED defaults 1
#
# It builds exactly the card the batch job uses: cp5.cmnd + zjets.cmnd + the
# PartonShowers:model + seed, then runs pythia8-rivet and keeps the run dir.
set -euo pipefail
cd "$(dirname "$0")/.."                         # package root
source ./config.sh
set +eu; source "$LCG_VIEW/setup.sh"; set -eu

export RIVET_ANALYSIS_PATH="$PKG"
lhapdf ls --installed 2>/dev/null | grep -q NNPDF31_nnlo_as_0118 \
  || export LHAPDF_DATA_PATH="$PKG/lhapdf-cache:${LHAPDF_DATA_PATH:-}"

MODEL="${1:-2}"; NEV="${2:-2000}"; SEED="${3:-1}"
case "$MODEL" in 1) TAG=pythia8 ;; 2) TAG=vincia ;; *) TAG="model${MODEL}" ;; esac

echo "=== environment ==="
echo "pythia8 : $(command -v pythia8-config || echo MISSING)   $(pythia8-config --version 2>/dev/null)"
echo "rivet   : $(rivet --version 2>/dev/null)"
echo "PartonShowers:model max in this build:"
grep -oE 'PartonShowers:model[^>]*max="[0-9]+"' \
     "$(pythia8-config --datadir)/xmldoc/PartonShowers.xml" 2>/dev/null || echo "  (xml not found)"

[ -x "$PKG/pythia/pythia8-rivet" ] || { echo ">>> building pythia8-rivet"; ( cd "$PKG/pythia" && make ); }

WORK="$PKG/pythia/local_${TAG}"; rm -rf "$WORK"; mkdir -p "$WORK"
CARD="$WORK/run.cmnd"
cat "$PKG/pythia/cp5.cmnd" "$PKG/pythia/zjets.cmnd" > "$CARD"
echo "PartonShowers:model = $MODEL"                     >> "$CARD"
printf 'Random:setSeed = on\nRandom:seed = %s\n' "$SEED" >> "$CARD"
echo "=== run card ($TAG, model $MODEL, $NEV events) ==="; cat "$CARD"; echo "==================="

OUT="$WORK/${TAG}_zjets_local.yoda"
echo ">>> pythia8-rivet — watch for 'PYTHIA Abort' / 'Error'"
"$PKG/pythia/pythia8-rivet" "$CARD" "$OUT" "$NEV"
echo ">>> wrote $OUT   (run dir kept: $WORK)"
