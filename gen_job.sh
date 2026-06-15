#!/usr/bin/env bash
# HTCondor payload: generate ONE seed of Z+jets natively under the LCG view.
# Args:  SEED  NEV  PKG  LCG_VIEW  OUTDIR  TAG  MODEL  [EOS_XROOTD]
set -euo pipefail
SEED="$1"; NEV="$2"; PKG="$3"; LCG_VIEW="$4"; OUTDIR="$5"; TAG="${6:-pythia8}"; MODEL="${7:-1}"; EOS_XROOTD="${8:-}"

# LCG setup.sh is not strict-mode clean (uses unset $COMPILER etc.), so relax -eu.
set +eu; source "$LCG_VIEW/setup.sh"; set -eu
export RIVET_ANALYSIS_PATH="$PKG"
# CP5 PDF: CVMFS if present, else the copy bundled in this package.
lhapdf ls --installed 2>/dev/null | grep -q NNPDF31_nnlo_as_0118 \
  || export LHAPDF_DATA_PATH="$PKG/lhapdf-cache:${LHAPDF_DATA_PATH:-}"

cd "$PKG/pythia"
[ -x ./pythia8-rivet ] || { echo "pythia8-rivet missing — run prepare.sh first" >&2; exit 1; }

SCRATCH="${_CONDOR_SCRATCH_DIR:-${TMPDIR:-/tmp}}/jm_${TAG}_${SEED}"
mkdir -p "$SCRATCH"
CARD="$SCRATCH/run.cmnd"
cat cp5.cmnd zjets.cmnd > "$CARD"
echo "PartonShowers:model = $MODEL"                     >> "$CARD"
printf 'Random:setSeed = on\nRandom:seed = %s\n' "$SEED" >> "$CARD"

OUT="$SCRATCH/${TAG}_zjets_seed${SEED}.yoda"
echo ">>> generating $NEV events (seed $SEED, model $MODEL)"
./pythia8-rivet "$CARD" "$OUT" "$NEV"

DEST="${TAG}_zjets_seed${SEED}.yoda"
if [ -n "$EOS_XROOTD" ]; then
  # Write to EOS over xrootd (avoids deprecated /eos fuse writes from workers).
  echo ">>> xrdcp -> ${EOS_XROOTD}${OUTDIR}/${DEST}"
  xrdcp -f "$OUT" "${EOS_XROOTD}${OUTDIR}/${DEST}"
else
  mkdir -p "$OUTDIR"; cp -f "$OUT" "$OUTDIR/${DEST}"
  echo ">>> wrote $OUTDIR/${DEST}"
fi
rm -rf "$SCRATCH"
