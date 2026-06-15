#!/usr/bin/env bash
# Submit NSEEDS parallel generation jobs to HTCondor using settings from config.sh.
set -euo pipefail
cd "$(dirname "$0")"
source ./config.sh

[ -x "$PKG/pythia/pythia8-rivet" ] || { echo "Run ./prepare.sh first." >&2; exit 1; }

# Standard schedds reject /eos paths in the submit file, so stage Condor's control
# files (executable + logs) onto AFS and submit from there. Data stays on EOS.
mkdir -p "$SUBMIT_DIR/log" "$OUTDIR"
cp -f gen.sub gen_job.sh "$SUBMIT_DIR/"

echo ">>> submitting $NSEEDS jobs x $NEV events  ($TAG, model $MODEL)"
echo "    control files: $SUBMIT_DIR   ->   output: $OUTDIR"
( cd "$SUBMIT_DIR" && condor_submit \
    -append "arguments = \$(Process) $NEV $PKG $LCG_VIEW $OUTDIR $TAG $MODEL $EOS_XROOTD" \
    -append "+JobFlavour = \"$JOBFLAVOUR\"" \
    -append "queue $NSEEDS" \
    gen.sub )

echo
echo "Watch:          condor_q        (logs in $SUBMIT_DIR/log)"
echo "When finished:  ./merge_plot.sh"
