#!/usr/bin/env bash
# Submit the LO-MadGraph + PYTHIA8 (simple shower) Z+jets batch.  -> yodas/mglo_pythia/
# Each job runs LO MadGraph (cheap) + the shower, so use the MG event knobs but the
# regular (shorter) shower JobFlavour — LO generation is fast.
set -euo pipefail
cd "$(dirname "$0")"
source ./config.sh
source ./submit_lib.sh

[ -f "$PKG/RivetCMS_2026_PAS_SMP_25_010.so" ] || { echo "Run ./prepare.sh first (need the plugin .so)." >&2; exit 1; }

TAG=mglo_pythia
OUTDIR="$PKG/yodas/$TAG"
ARGS="\$(Process) $NEV_MG $PKG $LCG_VIEW $OUTDIR $TAG 1 $EOS_XROOTD"
condor_launch "$TAG" gen_mglo_job.sh "$NSEEDS_MG" "$JOBFLAVOUR" "$ARGS"
echo "Watch: condor_q   |   when done: ./merge_plot.sh"
