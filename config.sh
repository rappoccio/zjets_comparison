# Shared configuration. Sourced by every script. Per-generator values (TAG, MODEL,
# OUTDIR) are NOT here — they are set by the individual submit_<gen>.sh scripts.
# PKG is auto-detected as this directory — do not edit it.
export PKG="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================ EDIT THESE ============================
# CVMFS LCG view providing Rivet >= 4.0 (see README "Pick an LCG view").
export LCG_VIEW="/cvmfs/sft.cern.ch/lcg/views/LCG_107/x86_64-el9-gcc13-opt"

# Shower generators (pythia8, vincia): NSEEDS parallel jobs x NEV events each.
export NEV=100000
export NSEEDS=200

# aMC@NLO (madgraph): fewer, heavier jobs (NLO compiles per job) x NEV_MG events.
export NEV_MG=20000
export NSEEDS_MG=20

# HTCondor walltime per job: espresso 20m, microcentury 1h, longlunch 2h,
# workday 8h, tomorrow 1d, testmatch 3d.
export JOBFLAVOUR=workday        # showers
export JOBFLAVOUR_MG=tomorrow    # aMC@NLO (slower)
# ===================================================================

# HTCondor control files (executable + logs) must live on AFS for the standard
# lxplus schedds; data (this package, the YODAs) stays on EOS and jobs copy their
# output back with xrdcp. SUBMIT_ROOT must be on AFS (small).
#   Alternative: the EosSubmit schedds keep everything on EOS —
#   https://batchdocs.web.cern.ch/local/eossubmit.html
export SUBMIT_ROOT="${SUBMIT_ROOT:-$HOME/zjets_submit}"
export EOS_XROOTD="${EOS_XROOTD:-root://eosuser.cern.ch/}"
