#!/usr/bin/env bash
# HTCondor payload: ONE aMC@NLO Z+jet sample (p p > z j [QCD]), distinct seed.
#
# The LCG MadGraph build has NO runnable Pythia8 shower interface
# (MG5aMC_PY8_interface), so `shower=Pythia8` can't run there — MadGraph only
# writes the (MadSpin-decayed) parton-level LHE, with parton_shower=PYTHIA8
# counterterms. We then shower that LHE with our own pythia8-rivet driver
# (Beams:frameType=4). Because the LHE's MC@NLO counterterms are computed *for
# Pythia8*, showering with Pythia8 is the correct MC@NLO matching.
#
# Args:  SEED  NEV  PKG  LCG_VIEW  OUTDIR  [EOS_XROOTD]
set -euo pipefail
SEED="$1"; NEV="$2"; PKG="$3"; LCG_VIEW="$4"; OUTDIR="$5"; EOS_XROOTD="${6:-}"

# LCG setup.sh is not strict-mode clean (uses unset $COMPILER etc.), so relax -eu.
set +eu; source "$LCG_VIEW/setup.sh"; set -eu
export RIVET_ANALYSIS_PATH="$PKG"
export PATH="$PKG/madgraph/bin:$PATH"          # bundled bc (used by MG generation steps)
lhapdf ls --installed 2>/dev/null | grep -q NNPDF31_nnlo_as_0118 \
  || export LHAPDF_DATA_PATH="$PKG/lhapdf-cache:${LHAPDF_DATA_PATH:-}"
command -v mg5_aMC >/dev/null || { echo "mg5_aMC not in this LCG view; pick one with MadGraph" >&2; exit 1; }
[ -x "$PKG/pythia/pythia8-rivet" ] || { echo "pythia8-rivet missing — run prepare.sh first" >&2; exit 1; }

SCRATCH="${_CONDOR_SCRATCH_DIR:-${TMPDIR:-/tmp}}/mg_${SEED}"
mkdir -p "$SCRATCH" && cd "$SCRATCH"

# 1. MadGraph: NLO generation + MadSpin decay -> LHE. (Its internal shower is a
#    no-op on this build — expected; we shower externally below.)
sed -e "s/@SEED@/$SEED/g" -e "s/@NEV@/$NEV/g" "$PKG/madgraph/zjets_batch.mg5" > card.mg5
echo ">>> mg5_aMC (seed $SEED, $NEV events) — writes the parton-level LHE"
mg5_aMC card.mg5 || echo ">>> mg5_aMC returned $? (checking for the LHE anyway)"

# 2. Find the parton-level LHE (MadSpin-decayed if present, else the raw one).
LHE=$(ls -t zjets_nlo*/Events/run_01_decayed_*/events.lhe.gz 2>/dev/null | head -1 || true)
[ -n "$LHE" ] || LHE=$(ls -t zjets_nlo*/Events/run_01*/events.lhe.gz 2>/dev/null | head -1 || true)
[ -n "$LHE" ] || { echo "no LHE produced by MadGraph" >&2; exit 1; }
gunzip -kf "$LHE"; LHE="${LHE%.gz}"
NIN=$(grep -c '<event>' "$LHE" 2>/dev/null || echo 0)
echo ">>> showering $NIN-event LHE with pythia8-rivet: $LHE"

# 3. Shower the LHE with the CP5 tune + our Rivet driver.
CARD="$SCRATCH/shower.cmnd"
cat "$PKG/pythia/cp5.cmnd" > "$CARD"
{ echo "Beams:frameType = 4"; echo "Beams:LHEF = $LHE"; } >> "$CARD"
OUT="$SCRATCH/amcnlo_zjets_seed${SEED}.yoda"
"$PKG/pythia/pythia8-rivet" "$CARD" "$OUT" "$(( NIN > 0 ? NIN : 1000000 ))"
[ -s "$OUT" ] || { echo "pythia8-rivet produced no YODA" >&2; exit 1; }

# 4. Copy the result out.
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
