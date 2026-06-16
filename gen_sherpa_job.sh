#!/usr/bin/env bash
# HTCondor payload: ONE Sherpa MEPS@LO Z+jets sample (complete generator: ME+PS+
# hadronization) with the native Rivet hook, distinct seed. Runs in node scratch.
#
# The process libraries are built ONCE by prepare.sh (Sherpa ... INIT_ONLY) and
# cached under $PKG/sherpa/{Process,Results}; we copy them in so jobs skip the
# (slow) Comix/Amegic compilation and just generate events.
#
# Args:  SEED  NEV  PKG  LCG_VIEW  OUTDIR  [EOS_XROOTD]
set -euo pipefail
SEED="$1"; NEV="$2"; PKG="$3"; LCG_VIEW="$4"; OUTDIR="$5"; EOS_XROOTD="${6:-}"

set +eu; source "$LCG_VIEW/setup.sh"; set -eu
export RIVET_ANALYSIS_PATH="$PKG"
lhapdf ls --installed 2>/dev/null | grep -q NNPDF31_nnlo_as_0118 \
  || export LHAPDF_DATA_PATH="$PKG/lhapdf-cache:${LHAPDF_DATA_PATH:-}"
command -v Sherpa >/dev/null || { echo "Sherpa not in this LCG view" >&2; exit 1; }

SCRATCH="${_CONDOR_SCRATCH_DIR:-${TMPDIR:-/tmp}}/sherpa_${SEED}"
mkdir -p "$SCRATCH" && cd "$SCRATCH"
cp "$PKG/sherpa/Sherpa.yaml" .
# Reuse the pre-built process libraries (built once by prepare.sh).
[ -d "$PKG/sherpa/Process" ] && cp -a "$PKG/sherpa/Process" . || \
  echo "WARN: no cached Process/ — this job will build process libs (slow)." >&2
[ -d "$PKG/sherpa/Results" ] && cp -a "$PKG/sherpa/Results" . || true

echo ">>> Sherpa ($NEV events, seed $SEED)"
Sherpa -f Sherpa.yaml -e "$NEV" -R "$SEED" -A "sherpa_seed${SEED}"

# Sherpa's Rivet hook writes <-A name>.yoda.
YODA=$(ls -t sherpa_seed${SEED}*.yoda *.yoda 2>/dev/null | head -1 || true)
[ -n "$YODA" ] || { echo "no YODA produced by Sherpa" >&2; exit 1; }

DEST="sherpa_zjets_seed${SEED}.yoda"
if [ -n "$EOS_XROOTD" ]; then
  EOSDEST=$(printf '%s' "$OUTDIR" | sed -E 's#^/eos/home-([^/]+)/#/eos/user/\1/#')
  echo ">>> xrdcp -> ${EOS_XROOTD}${EOSDEST}/${DEST}"
  xrdcp -f "$YODA" "${EOS_XROOTD}${EOSDEST}/${DEST}" \
    || { echo "xrdcp failed; fuse fallback" >&2; mkdir -p "$OUTDIR"; cp -f "$YODA" "$OUTDIR/${DEST}"; }
else
  mkdir -p "$OUTDIR"; cp -f "$YODA" "$OUTDIR/${DEST}"
fi
cd /; rm -rf "$SCRATCH"
