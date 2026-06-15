#!/usr/bin/env bash
# Submit the aMC@NLO (p p > z j [QCD]) Z+jets batch.  -> yodas/amcnlo/
# NSEEDS_MG independent jobs, each compiling + generating NEV_MG events with a
# distinct seed (NLO is slow, hence fewer/longer jobs than the showers).
set -euo pipefail
cd "$(dirname "$0")"
source ./config.sh
source ./submit_lib.sh

TAG=amcnlo
OUTDIR="$PKG/yodas/$TAG"
ARGS="\$(Process) $NEV_MG $PKG $LCG_VIEW $OUTDIR $EOS_XROOTD"
condor_launch "$TAG" gen_amcnlo_job.sh "$NSEEDS_MG" "$JOBFLAVOUR_MG" "$ARGS"
echo "Watch: condor_q   |   when done: ./merge_plot.sh"
