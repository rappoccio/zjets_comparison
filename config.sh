# Shared configuration for the whole package. Sourced by every script.
# PKG is auto-detected as this directory — do not edit it.
export PKG="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================ EDIT THESE ============================
# CVMFS LCG view providing Rivet >= 4.0 (see README "Pick an LCG view").
export LCG_VIEW="/cvmfs/sft.cern.ch/lcg/views/LCG_107/x86_64-el9-gcc13-opt"

# Statistics for the batch run: total events = NEV * NSEEDS (one job per seed).
export NEV=100000          # events per job
export NSEEDS=200          # number of parallel jobs

# Shower: TAG is just a label; MODEL = 1 simple PYTHIA8, 2 = VINCIA.
export TAG=pythia8
export MODEL=1

# HTCondor walltime: espresso 20m, microcentury 1h, longlunch 2h, workday 8h,
# tomorrow 1d, testmatch 3d. 100k events ~ 1-2 h.
export JOBFLAVOUR=workday
# ===================================================================

# Per-seed YODAs land here (on EOS, alongside the package).
export OUTDIR="$PKG/yodas/$TAG"

# HTCondor on lxplus: the *standard* schedds forbid /eos paths inside the submit
# file, so Condor's control files (executable + logs) go on AFS, while the data
# (this package, OUTDIR) stays on EOS and each job copies its result back with
# xrdcp. SUBMIT_DIR must be on AFS (small: just scripts + logs).
#   Alternative: the EosSubmit schedds let you keep everything on EOS —
#   https://batchdocs.web.cern.ch/local/eossubmit.html
export SUBMIT_DIR="${SUBMIT_DIR:-$HOME/zjets_submit}"
export EOS_XROOTD="${EOS_XROOTD:-root://eosuser.cern.ch/}"
