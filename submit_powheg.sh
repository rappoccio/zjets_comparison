#!/usr/bin/env bash
# Submit the POWHEG-BOX Zj (NLO) + PYTHIA8 Z+jets batch.  -> yodas/powheg/
# Heavy jobs (POWHEG integration + showering), so use the MG-style job knobs.
set -euo pipefail
cd "$(dirname "$0")"
source ./config.sh
source ./submit_lib.sh

[ -f "$PKG/RivetCMS_2026_PAS_SMP_25_010.so" ] || { echo "Run ./prepare.sh first (need the plugin .so)." >&2; exit 1; }
[ -x "$PKG/pythia/powheg8-rivet" ] || { echo "powheg8-rivet missing — run ./prepare.sh first." >&2; exit 1; }
[ -x "$PKG/powheg/pwhg_main" ]     || echo "WARN: $PKG/powheg/pwhg_main not bundled — jobs will look for pwhg_main on PATH." >&2

TAG=powheg
OUTDIR="$PKG/yodas/$TAG"
ARGS="\$(Process) $NEV_MG $PKG $LCG_VIEW $OUTDIR $EOS_XROOTD"
condor_launch "$TAG" gen_powheg_job.sh "$NSEEDS_MG" "$JOBFLAVOUR_MG" "$ARGS"
echo "Watch: condor_q   |   when done: ./merge_plot.sh"
