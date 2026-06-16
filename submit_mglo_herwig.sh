#!/usr/bin/env bash
# Submit the LO-MadGraph + HERWIG7 shower Z+jets batch.  -> yodas/mglo_herwig/
# LO LHE (no counterterms) showered by Herwig7's LesHouchesFileReader. Uses the MG
# event knobs but the regular shower JobFlavour (LO generation is fast).
set -euo pipefail
cd "$(dirname "$0")"
source ./config.sh
source ./submit_lib.sh

[ -f "$PKG/RivetCMS_2026_PAS_SMP_25_010.so" ] || { echo "Run ./prepare.sh first (need the plugin .so)." >&2; exit 1; }

TAG=mglo_herwig
OUTDIR="$PKG/yodas/$TAG"
ARGS="\$(Process) $NEV_MG $PKG $LCG_VIEW $OUTDIR $EOS_XROOTD"
condor_launch "$TAG" gen_mglo_herwig_job.sh "$NSEEDS_MG" "$JOBFLAVOUR" "$ARGS"
echo "Watch: condor_q   |   when done: ./merge_plot.sh"
