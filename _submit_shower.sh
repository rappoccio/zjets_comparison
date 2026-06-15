#!/usr/bin/env bash
# Shared core for the PYTHIA-family submit scripts. Not called directly —
# use submit_pythia8.sh / submit_vincia.sh.
#   _submit_shower.sh <tag> <PartonShowers:model>
set -euo pipefail
cd "$(dirname "$0")"
source ./config.sh
source ./submit_lib.sh

TAG="${1:?usage: _submit_shower.sh <tag> <model>}"
MODEL="${2:?model}"
[ -x "$PKG/pythia/pythia8-rivet" ] || { echo "Run ./prepare.sh first." >&2; exit 1; }

OUTDIR="$PKG/yodas/$TAG"
# Keep $(Process) literal for HTCondor (it becomes the per-job seed).
ARGS="\$(Process) $NEV $PKG $LCG_VIEW $OUTDIR $TAG $MODEL $EOS_XROOTD"
condor_launch "$TAG" gen_job.sh "$NSEEDS" "$JOBFLAVOUR" "$ARGS"
echo "Watch: condor_q   |   when done: ./merge_plot.sh"
