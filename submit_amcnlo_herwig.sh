#!/usr/bin/env bash
# Submit the aMC@NLO (p p > z j [QCD]) Z+jets batch showered by HERWIG7.
#   -> yodas/amcnlo_herwig/
# Same heavy-job knobs as plain aMC@NLO (NLO generation dominates the time).
set -euo pipefail
cd "$(dirname "$0")"
source ./config.sh
source ./submit_lib.sh

[ -f "$PKG/RivetCMS_2026_PAS_SMP_25_010.so" ] || { echo "Run ./prepare.sh first (need the plugin .so)." >&2; exit 1; }

TAG=amcnlo_herwig
OUTDIR="$PKG/yodas/$TAG"
ARGS="\$(Process) $NEV_MG $PKG $LCG_VIEW $OUTDIR $EOS_XROOTD"
condor_launch "$TAG" gen_amcnlo_herwig_job.sh "$NSEEDS_MG" "$JOBFLAVOUR_MG" "$ARGS"
echo "Watch: condor_q   |   when done: ./merge_plot.sh"
