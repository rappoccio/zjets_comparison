#!/usr/bin/env bash
# HTCondor payload: ONE independent aMC@NLO Z+jet sample (p p > z j [QCD]) +
# Pythia8 shower + Rivet, with a distinct seed. Runs entirely in node-local
# scratch so concurrent jobs never collide.
# Args:  SEED  NEV  PKG  LCG_VIEW  OUTDIR  [EOS_XROOTD]
set -euo pipefail
SEED="$1"; NEV="$2"; PKG="$3"; LCG_VIEW="$4"; OUTDIR="$5"; EOS_XROOTD="${6:-}"

# LCG setup.sh is not strict-mode clean (uses unset $COMPILER etc.), so relax -eu.
set +eu; source "$LCG_VIEW/setup.sh"; set -eu
export RIVET_ANALYSIS_PATH="$PKG"
lhapdf ls --installed 2>/dev/null | grep -q NNPDF31_nnlo_as_0118 \
  || export LHAPDF_DATA_PATH="$PKG/lhapdf-cache:${LHAPDF_DATA_PATH:-}"
command -v mg5_aMC >/dev/null || { echo "mg5_aMC not in this LCG view; pick one with MadGraph" >&2; exit 1; }

# aMC@NLO's NLO shower step needs `bc`; workers often lack it (-> it silently
# skips the shower and writes unphysical, unshowered LHE). Use the copy bundled by
# prepare.sh.
export PATH="$PKG/madgraph/bin:$PATH"
command -v bc >/dev/null || echo "WARNING: bc not found even after bundling — shower will be skipped; re-run prepare.sh on a node that has bc" >&2

SCRATCH="${_CONDOR_SCRATCH_DIR:-${TMPDIR:-/tmp}}/mg_${SEED}"
mkdir -p "$SCRATCH" && cd "$SCRATCH"

sed -e "s/@SEED@/$SEED/g" -e "s/@NEV@/$NEV/g" "$PKG/madgraph/zjets_batch.mg5" > card.mg5
echo ">>> aMC@NLO generate+shower (seed $SEED, $NEV events)"
mg5_aMC card.mg5 || echo ">>> mg5_aMC returned $? (verifying HepMC anyway)"

HEPMC=$(ls -t zjets_nlo*/Events/run_*/*.hepmc.gz 2>/dev/null | head -1)
[ -n "$HEPMC" ] || { echo "no HepMC produced" >&2; exit 1; }

OUT="$SCRATCH/amcnlo_zjets_seed${SEED}.yoda"
rivet -a CMS_2026_PAS_SMP_25_010 -o "$OUT" "$HEPMC"

DEST="amcnlo_zjets_seed${SEED}.yoda"
if [ -n "$EOS_XROOTD" ]; then
  EOSDEST=$(printf '%s' "$OUTDIR" | sed -E 's#^/eos/home-([^/]+)/#/eos/user/\1/#')
  echo ">>> xrdcp -> ${EOS_XROOTD}${EOSDEST}/${DEST}"
  xrdcp -f "$OUT" "${EOS_XROOTD}${EOSDEST}/${DEST}" \
    || { echo "xrdcp failed; fuse fallback" >&2; mkdir -p "$OUTDIR"; cp -f "$OUT" "$OUTDIR/${DEST}"; }
else
  mkdir -p "$OUTDIR"; cp -f "$OUT" "$OUTDIR/${DEST}"
fi
cd /; rm -rf "$SCRATCH"
