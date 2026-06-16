#!/usr/bin/env bash
# Submit the LO-MadGraph + VINCIA shower Z+jets batch.  -> yodas/mglo_vincia/
# This is the VALID way to combine MadGraph with VINCIA: at LO there are no MC@NLO
# counterterms, so VINCIA (not an aMC@NLO shower_mc) can shower the LHE freely.
# MODEL=2 selects VINCIA; gen_mglo_job.sh then uses pythia/vincia.cmnd (not CP5).
set -euo pipefail
cd "$(dirname "$0")"
source ./config.sh
source ./submit_lib.sh

[ -f "$PKG/RivetCMS_2026_PAS_SMP_25_010.so" ] || { echo "Run ./prepare.sh first (need the plugin .so)." >&2; exit 1; }

TAG=mglo_vincia
OUTDIR="$PKG/yodas/$TAG"
ARGS="\$(Process) $NEV_MG $PKG $LCG_VIEW $OUTDIR $TAG 2 $EOS_XROOTD"
condor_launch "$TAG" gen_mglo_job.sh "$NSEEDS_MG" "$JOBFLAVOUR" "$ARGS"
echo "Watch: condor_q   |   when done: ./merge_plot.sh"
