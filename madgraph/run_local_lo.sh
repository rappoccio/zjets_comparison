#!/usr/bin/env bash
# Local interactive test of the LO-MadGraph + PYTHIA8/VINCIA chains — same as
# gen_mglo_job.sh but local, verbose, keeps the run dir.
#   ./madgraph/run_local_lo.sh [MODEL] [NEV] [SEED]
#     MODEL 1 = PYTHIA8 (CP5), 2 = VINCIA      (default 1)
#     NEV defaults 2000, SEED defaults 1
set -euo pipefail
cd "$(dirname "$0")/.."                          # package root
source ./config.sh
set +eu; source "$LCG_VIEW/setup.sh"; set -eu
export RIVET_ANALYSIS_PATH="$PKG"
export PATH="$PKG/madgraph/bin:$PATH"
lhapdf ls --installed 2>/dev/null | grep -q NNPDF31_nnlo_as_0118 \
  || export LHAPDF_DATA_PATH="$PKG/lhapdf-cache:${LHAPDF_DATA_PATH:-}"

MODEL="${1:-1}"; NEV="${2:-2000}"; SEED="${3:-1}"
case "$MODEL" in 1) TAG=mglo_pythia ;; 2) TAG=mglo_vincia ;; *) echo "MODEL must be 1 or 2"; exit 1 ;; esac

echo "=== environment ==="
echo "mg5_aMC : $(command -v mg5_aMC || echo MISSING)"
echo "pythia8 : $(command -v pythia8-config || echo MISSING)"
echo "rivet   : $(rivet --version 2>/dev/null)"
command -v mg5_aMC >/dev/null || { echo "no mg5_aMC in this LCG view"; exit 1; }
[ -x "$PKG/pythia/pythia8-rivet" ] || { echo ">>> building pythia8-rivet"; ( cd "$PKG/pythia" && make ); }

WORK="$PKG/madgraph/local_run_${TAG}"; rm -rf "$WORK"; mkdir -p "$WORK"; cd "$WORK"
sed -e "s/@SEED@/$SEED/g" -e "s/@NEV@/$NEV/g" "$PKG/madgraph/zjets_lo_batch.mg5" > card.mg5
echo "=== card.mg5 ==="; cat card.mg5; echo "================"

echo ">>> mg5_aMC card.mg5 (LO) — writes the LO LHE"
mg5_aMC card.mg5 || echo ">>> mg5_aMC exit $? (continuing to the LHE)"
LHE=$(ls -t zjets_lo*/Events/run_01*/unweighted_events.lhe.gz 2>/dev/null | head -1 || true)
[ -n "$LHE" ] || LHE=$(ls -t zjets_lo*/Events/run_01*/events.lhe.gz 2>/dev/null | head -1 || true)
[ -n "$LHE" ] || { echo ">>> NO LHE produced — see output above. Run dir kept: $WORK"; exit 1; }
gunzip -kf "$LHE"; LHE="${LHE%.gz}"; NIN=$(grep -c '<event>' "$LHE" 2>/dev/null || echo 0)
echo ">>> showering $NIN-event LO LHE with pythia8-rivet (model $MODEL): $LHE"

CARD="$WORK/shower.cmnd"
TUNE="$PKG/pythia/cp5.cmnd"; [ "$MODEL" = "2" ] && TUNE="$PKG/pythia/vincia.cmnd"
cat "$TUNE" > "$CARD"
{ echo "PartonShowers:model = $MODEL"; echo "Beams:frameType = 4"; echo "Beams:LHEF = $LHE"; } >> "$CARD"
"$PKG/pythia/pythia8-rivet" "$CARD" "$WORK/${TAG}_zjets_local.yoda" "$(( NIN > 0 ? NIN : 1000000 ))"
echo ">>> wrote $WORK/${TAG}_zjets_local.yoda   (run dir kept: $WORK)"
