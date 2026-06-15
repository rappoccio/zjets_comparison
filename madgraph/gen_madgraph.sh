#!/usr/bin/env bash
# OPTIONAL: aMC@NLO p p > z j [QCD] + Pythia8 shower, run natively under the LCG
# view (one job, not a seed scan). Produces a YODA that merge_plot.sh can overlay.
set -euo pipefail
cd "$(dirname "$0")/.."          # package root
source ./config.sh
# LCG setup.sh is not strict-mode clean (uses unset $COMPILER etc.), so relax -eu.
set +eu; source "$LCG_VIEW/setup.sh"; set -eu
export RIVET_ANALYSIS_PATH="$PKG"
lhapdf ls --installed 2>/dev/null | grep -q NNPDF31_nnlo_as_0118 \
  || export LHAPDF_DATA_PATH="$PKG/lhapdf-cache:${LHAPDF_DATA_PATH:-}"

command -v mg5_aMC >/dev/null || { echo "mg5_aMC not in this LCG view; pick one with MadGraph" >&2; exit 1; }

cd "$PKG/madgraph"
mg5_aMC zjets.mg5
HEPMC=$(ls -t zjets_nlo*/Events/run_*/*.hepmc.gz 2>/dev/null | head -1)
[ -n "$HEPMC" ] || { echo "no HepMC produced" >&2; exit 1; }

mkdir -p "$PKG/yodas/amcnlo"
rivet -a CMS_2026_PAS_SMP_25_010 -o "$PKG/yodas/amcnlo/aMCNLO_zjets.yoda" "$HEPMC"
echo ">>> wrote $PKG/yodas/amcnlo/aMCNLO_zjets.yoda"
echo ">>> overlay it with:  ./merge_plot.sh aMCNLO=$PKG/yodas/amcnlo"
