#!/usr/bin/env bash
# HTCondor payload: ONE Herwig7 Z+jets sample (internal ME + angular-ordered
# shower) with Rivet, distinct seed. Runs in node-local scratch.
# Args:  SEED  NEV  PKG  LCG_VIEW  OUTDIR  [EOS_XROOTD]
set -euo pipefail
SEED="$1"; NEV="$2"; PKG="$3"; LCG_VIEW="$4"; OUTDIR="$5"; EOS_XROOTD="${6:-}"

# LCG setup.sh is not strict-mode clean (uses unset $COMPILER etc.), so relax -eu.
set +eu; source "$LCG_VIEW/setup.sh"; set -eu
export RIVET_ANALYSIS_PATH="$PKG"
command -v Herwig >/dev/null || { echo "Herwig not in this LCG view; pick one with Herwig7" >&2; exit 1; }

SCRATCH="${_CONDOR_SCRATCH_DIR:-${TMPDIR:-/tmp}}/hw_${SEED}"
mkdir -p "$SCRATCH" && cd "$SCRATCH"
cp "$PKG/herwig/zjets.in" .

echo ">>> Herwig read"
Herwig read zjets.in
echo ">>> Herwig run ($NEV events, seed $SEED)"
Herwig run zjets.run -N "$NEV" -s "$SEED" -d 0

# Herwig's RivetAnalysis writes <runname>.yoda (here zjets.yoda).
YODA=$(ls -t *.yoda 2>/dev/null | head -1)
[ -n "$YODA" ] || { echo "no YODA produced by Herwig" >&2; exit 1; }

DEST="herwig_zjets_seed${SEED}.yoda"
if [ -n "$EOS_XROOTD" ]; then
  EOSDEST=$(printf '%s' "$OUTDIR" | sed -E 's#^/eos/home-([^/]+)/#/eos/user/\1/#')
  echo ">>> xrdcp -> ${EOS_XROOTD}${EOSDEST}/${DEST}"
  xrdcp -f "$YODA" "${EOS_XROOTD}${EOSDEST}/${DEST}" \
    || { echo "xrdcp failed; fuse fallback" >&2; mkdir -p "$OUTDIR"; cp -f "$YODA" "$OUTDIR/${DEST}"; }
else
  mkdir -p "$OUTDIR"; cp -f "$YODA" "$OUTDIR/${DEST}"
fi
cd /; rm -rf "$SCRATCH"
