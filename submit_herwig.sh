#!/usr/bin/env bash
# Submit the HERWIG7 (angular-ordered shower) Z+jets batch.  -> yodas/herwig/
# NSEEDS parallel jobs (same stats knobs as the Pythia/Vincia showers).
set -euo pipefail
cd "$(dirname "$0")"
source ./config.sh
source ./submit_lib.sh

[ -f "$PKG/RivetCMS_2026_PAS_SMP_25_010.so" ] || { echo "Run ./prepare.sh first (need the plugin .so)." >&2; exit 1; }

TAG=herwig
OUTDIR="$PKG/yodas/$TAG"
ARGS="\$(Process) $NEV $PKG $LCG_VIEW $OUTDIR $EOS_XROOTD"
condor_launch "$TAG" gen_herwig_job.sh "$NSEEDS" "$JOBFLAVOUR" "$ARGS"
echo "Watch: condor_q   |   when done: ./merge_plot.sh"
