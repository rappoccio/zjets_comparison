#!/usr/bin/env bash
# Run ONE aMC@NLO Z+jet sample INTERACTIVELY (no HTCondor, no xrdcp) for
# debugging the shower step. Same chain as gen_amcnlo_job.sh, but local + verbose,
# and it KEEPS the run directory so you can inspect it.
#
#   ./madgraph/run_local.sh [NEV] [SEED]      # defaults: 2000 events, seed 1
#
# NB: the NLO process (p p > z j [QCD]) compiles Fortran first — a few minutes and
# CPU-heavy; on lxplus prefer an interactive batch slot (condor_submit -i) over a
# busy login node.
set -euo pipefail
cd "$(dirname "$0")/.."                       # package root
source ./config.sh
set +eu; source "$LCG_VIEW/setup.sh"; set -eu

export RIVET_ANALYSIS_PATH="$PKG"
lhapdf ls --installed 2>/dev/null | grep -q NNPDF31_nnlo_as_0118 \
  || export LHAPDF_DATA_PATH="$PKG/lhapdf-cache:${LHAPDF_DATA_PATH:-}"
export PATH="$PKG/madgraph/bin:$PATH"          # bundled bc (NLO shower needs it)

NEV="${1:-2000}"; SEED="${2:-1}"
WORK="$PKG/madgraph/local_run"

echo "=== environment check ==="
echo "mg5_aMC : $(command -v mg5_aMC || echo MISSING)"
echo "bc      : $(command -v bc || echo MISSING)   $(bc --version 2>/dev/null | head -1)"
echo "pythia8 : $(command -v pythia8-config || echo MISSING)"
echo "rivet   : $(rivet --version 2>/dev/null)"
command -v mg5_aMC >/dev/null || { echo "no mg5_aMC in this LCG view"; exit 1; }
command -v bc      >/dev/null || echo ">>> WARNING: bc missing -> aMC@NLO will SKIP the shower"

rm -rf "$WORK"; mkdir -p "$WORK"; cd "$WORK"
sed -e "s/@SEED@/$SEED/g" -e "s/@NEV@/$NEV/g" "$PKG/madgraph/zjets_batch.mg5" > card.mg5
echo "=== card.mg5 ==="; cat card.mg5; echo "================"

echo ">>> mg5_aMC card.mg5   (the LCG build can't run its Pythia8 shower; it writes the LHE)"
mg5_aMC card.mg5 || echo ">>> mg5_aMC exit $? (continuing to the LHE)"

# Shower the parton-level LHE ourselves (correct: its counterterms are for Pythia8).
LHE=$(ls -t zjets_nlo*/Events/run_01_decayed_*/events.lhe.gz 2>/dev/null | head -1 || true)
[ -n "$LHE" ] || LHE=$(ls -t zjets_nlo*/Events/run_01*/events.lhe.gz 2>/dev/null | head -1 || true)
if [ -z "$LHE" ]; then
  echo ">>> NO LHE produced — see the mg5 output above. Run dir kept: $WORK"; exit 1
fi
gunzip -kf "$LHE"; LHE="${LHE%.gz}"
NIN=$(grep -c '<event>' "$LHE" 2>/dev/null || echo 0)
echo ">>> showering $NIN-event LHE with pythia8-rivet: $LHE"
CARD="$WORK/shower.cmnd"; cat "$PKG/pythia/cp5.cmnd" > "$CARD"
{ echo "Beams:frameType = 4"; echo "Beams:LHEF = $LHE"; } >> "$CARD"
"$PKG/pythia/pythia8-rivet" "$CARD" "$WORK/amcnlo_zjets_local.yoda" "$(( NIN > 0 ? NIN : 1000000 ))"
echo ">>> wrote $WORK/amcnlo_zjets_local.yoda   (run dir kept: $WORK)"
