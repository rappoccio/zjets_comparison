#!/usr/bin/env bash
# Submit the Sherpa (MEPS@LO Z+jets) batch.  -> yodas/sherpa/
# Sherpa is a full generator; once the process libs are built (prepare.sh), the
# per-event cost is shower-like, so use the shower job knobs (NSEEDS x NEV).
set -euo pipefail
cd "$(dirname "$0")"
source ./config.sh
source ./submit_lib.sh

[ -f "$PKG/RivetCMS_2026_PAS_SMP_25_010.so" ] || { echo "Run ./prepare.sh first (need the plugin .so)." >&2; exit 1; }
[ -d "$PKG/sherpa/Process" ] || echo "WARN: sherpa/Process not built — run ./prepare.sh (Sherpa INIT) first, else every job rebuilds it." >&2

TAG=sherpa
OUTDIR="$PKG/yodas/$TAG"
ARGS="\$(Process) $NEV $PKG $LCG_VIEW $OUTDIR $EOS_XROOTD"
condor_launch "$TAG" gen_sherpa_job.sh "$NSEEDS" "$JOBFLAVOUR" "$ARGS"
echo "Watch: condor_q   |   when done: ./merge_plot.sh"
