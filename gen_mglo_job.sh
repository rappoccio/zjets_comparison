#!/usr/bin/env bash
# HTCondor payload: ONE LO-MadGraph Z+jet sample showered by PYTHIA8 *or* VINCIA,
# distinct seed. LO `p p > z j` has no MC@NLO counterterms, so any shower is valid;
# the shower is chosen by MODEL (1=simple/CP5, 2=VINCIA) exactly like gen_job.sh.
#
# MadGraph writes the LO LHE (its internal shower is a no-op on the LCG build), then
# pythia8-rivet showers it (Beams:frameType=4).
#
# Args:  SEED  NEV  PKG  LCG_VIEW  OUTDIR  TAG  MODEL  [EOS_XROOTD]
set -euo pipefail
SEED="$1"; NEV="$2"; PKG="$3"; LCG_VIEW="$4"; OUTDIR="$5"; TAG="$6"; MODEL="$7"; EOS_XROOTD="${8:-}"

set +eu; source "$LCG_VIEW/setup.sh"; set -eu
export RIVET_ANALYSIS_PATH="$PKG"
export PATH="$PKG/madgraph/bin:$PATH"          # bundled bc (used by MG generation steps)
lhapdf ls --installed 2>/dev/null | grep -q NNPDF31_nnlo_as_0118 \
  || export LHAPDF_DATA_PATH="$PKG/lhapdf-cache:${LHAPDF_DATA_PATH:-}"
command -v mg5_aMC >/dev/null || { echo "mg5_aMC not in this LCG view" >&2; exit 1; }
[ -x "$PKG/pythia/pythia8-rivet" ] || { echo "pythia8-rivet missing — run prepare.sh first" >&2; exit 1; }

SCRATCH="${_CONDOR_SCRATCH_DIR:-${TMPDIR:-/tmp}}/mglo_${TAG}_${SEED}"
mkdir -p "$SCRATCH" && cd "$SCRATCH"

# 1. MadGraph: LO generation -> parton-level LHE.
sed -e "s/@SEED@/$SEED/g" -e "s/@NEV@/$NEV/g" "$PKG/madgraph/zjets_lo_batch.mg5" > card.mg5
echo ">>> mg5_aMC LO (seed $SEED, $NEV events) — writes the LO LHE"
mg5_aMC card.mg5 || echo ">>> mg5_aMC returned $? (checking for the LHE anyway)"

LHE=$(ls -t zjets_lo*/Events/run_01*/unweighted_events.lhe.gz 2>/dev/null | head -1 || true)
[ -n "$LHE" ] || LHE=$(ls -t zjets_lo*/Events/run_01*/events.lhe.gz 2>/dev/null | head -1 || true)
[ -n "$LHE" ] || { echo "no LHE produced by MadGraph" >&2; exit 1; }
gunzip -kf "$LHE"; LHE="${LHE%.gz}"
NIN=$(grep -c '<event>' "$LHE" 2>/dev/null || echo 0)
echo ">>> showering $NIN-event LO LHE with pythia8-rivet (model $MODEL): $LHE"

# 2. Shower the LHE. VINCIA (model 2) needs its own tune — the CP5 simple-shower
#    settings break it (see pythia/vincia.cmnd).
CARD="$SCRATCH/shower.cmnd"
TUNE="$PKG/pythia/cp5.cmnd"; [ "$MODEL" = "2" ] && TUNE="$PKG/pythia/vincia.cmnd"
cat "$TUNE" > "$CARD"
{ echo "PartonShowers:model = $MODEL"
  echo "Beams:frameType = 4"
  echo "Beams:LHEF = $LHE"; } >> "$CARD"
OUT="$SCRATCH/${TAG}_zjets_seed${SEED}.yoda"
"$PKG/pythia/pythia8-rivet" "$CARD" "$OUT" "$(( NIN > 0 ? NIN : 1000000 ))"
[ -s "$OUT" ] || { echo "pythia8-rivet produced no YODA" >&2; exit 1; }

# 3. Copy out.
DEST="${TAG}_zjets_seed${SEED}.yoda"
if [ -n "$EOS_XROOTD" ]; then
  EOSDEST=$(printf '%s' "$OUTDIR" | sed -E 's#^/eos/home-([^/]+)/#/eos/user/\1/#')
  echo ">>> xrdcp -> ${EOS_XROOTD}${EOSDEST}/${DEST}"
  xrdcp -f "$OUT" "${EOS_XROOTD}${EOSDEST}/${DEST}" \
    || { echo "xrdcp failed; fuse fallback" >&2; mkdir -p "$OUTDIR"; cp -f "$OUT" "$OUTDIR/${DEST}"; }
else
  mkdir -p "$OUTDIR"; cp -f "$OUT" "$OUTDIR/${DEST}"
fi
cd /; rm -rf "$SCRATCH"
