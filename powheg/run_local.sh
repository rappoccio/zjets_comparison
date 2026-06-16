#!/usr/bin/env bash
# Local interactive test of the POWHEG-BOX Zj (NLO) + PYTHIA8 chain — same as
# gen_powheg_job.sh but local, verbose, keeps the run dir.
#   ./powheg/run_local.sh [NEV] [SEED]      # defaults: 2000 events, seed 1
#
# A cold pwhg_main builds its integration grids first (slow); the run dir is kept
# so a re-run reuses them. Needs powheg/pwhg_main (CVMFS or built — see prepare.sh).
set -euo pipefail
cd "$(dirname "$0")/.."                          # package root
source ./config.sh
set +eu; source "$LCG_VIEW/setup.sh"; set -eu
export RIVET_ANALYSIS_PATH="$PKG"
lhapdf ls --installed 2>/dev/null | grep -q NNPDF31_nnlo_as_0118 \
  || export LHAPDF_DATA_PATH="$PKG/lhapdf-cache:${LHAPDF_DATA_PATH:-}"

NEV="${1:-2000}"; SEED="${2:-1}"
PWHG="$PKG/powheg/pwhg_main"
[ -x "$PWHG" ] || PWHG="$(command -v pwhg_main_Zj || command -v pwhg_main || true)"

echo "=== environment ==="
echo "pwhg_main    : ${PWHG:-MISSING}"
echo "powheg8-rivet: $([ -x "$PKG/pythia/powheg8-rivet" ] && echo OK || echo MISSING)"
echo "rivet        : $(rivet --version 2>/dev/null)"
[ -x "$PWHG" ] || { echo "no pwhg_main (Zj) — build it / fetch from CVMFS (see prepare.sh)"; exit 1; }
[ -x "$PKG/pythia/powheg8-rivet" ] || { echo ">>> building powheg8-rivet"; ( cd "$PKG/pythia" && make powheg8-rivet ); }

WORK="$PKG/powheg/local_run"; mkdir -p "$WORK"; cd "$WORK"
sed -e "s/@SEED@/$SEED/g" -e "s/@NEV@/$NEV/g" "$PKG/powheg/Zj.input" > powheg.input
echo "=== powheg.input ==="; cat powheg.input; echo "===================="

echo ">>> pwhg_main (Zj, $NEV events, seed $SEED) — cold start builds grids (slow)"
"$PWHG" || echo ">>> pwhg_main exit $? (continuing to the LHE)"
LHE=$(ls -t pwgevents*.lhe 2>/dev/null | head -1 || true)
[ -n "$LHE" ] || { echo ">>> NO LHE produced — see output above. Run dir kept: $WORK"; exit 1; }
LHE=$(readlink -f "$LHE"); NIN=$(grep -c '<event>' "$LHE" 2>/dev/null || echo 0)

echo ">>> showering $NIN-event LHE with powheg8-rivet: $LHE"
CARD="$WORK/shower.cmnd"; cat "$PKG/pythia/cp5.cmnd" "$PKG/pythia/powheg.cmnd" > "$CARD"
echo "Beams:LHEF = $LHE" >> "$CARD"
"$PKG/pythia/powheg8-rivet" "$CARD" "$WORK/powheg_zjets_local.yoda" "$(( NIN > 0 ? NIN : 1000000 ))"
echo ">>> wrote $WORK/powheg_zjets_local.yoda   (run dir kept: $WORK)"
