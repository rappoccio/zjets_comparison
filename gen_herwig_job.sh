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

# Herwig's `read snippets/PPCollider.in` is resolved against Herwig's *read search
# path*, NOT the cwd. Under a relocated LCG install the compiled-in path is wrong,
# so (1) find where PPCollider.in actually lives and (2) add its parent to the
# read path with whatever include flag this Herwig build supports.
HWROOT=$(readlink -f "$(dirname "$(command -v Herwig)")/.." 2>/dev/null || true)
READROOT=""
if [ -f "$HWROOT/share/Herwig/snippets/PPCollider.in" ]; then
  READROOT="$HWROOT/share/Herwig"
else
  PP=$(find "$HWROOT" -name PPCollider.in -print -quit 2>/dev/null || true)
  [ -n "$PP" ] && READROOT=$(dirname "$(dirname "$PP")")
fi
if [ -z "$READROOT" ] || [ ! -f "$READROOT/snippets/PPCollider.in" ]; then
  echo "ERROR: snippets/PPCollider.in not found under $HWROOT." >&2
  echo "       This Herwig ($(Herwig --version 2>&1 | head -1)) likely predates the snippets" >&2
  echo "       mechanism (7.2+). Send me that version and I'll provide a matching zjets.in." >&2
  exit 1
fi
echo ">>> Herwig read root: $READROOT"

# The LCG Herwig has its repository (HerwigDefaults.rpo) compiled to a
# non-existent /build/jenkins/... path, so point it at the real CVMFS copy.
RPO="$READROOT/HerwigDefaults.rpo"
[ -f "$RPO" ] || { echo "ERROR: HerwigDefaults.rpo not at $RPO" >&2; exit 1; }

# Pick the read-include option this build understands (for the snippet search path).
HELP=$(Herwig read --help 2>&1 || true)
INC=""
for opt in --prepend-read --append-read -I -i; do
  printf '%s\n' "$HELP" | grep -q -- "$opt" && { INC="$opt"; break; }
done
ln -sf "$READROOT/snippets" snippets        # cwd fallback for `read snippets/...`
[ -d "$READROOT/defaults" ] && ln -sf "$READROOT/defaults" defaults

echo ">>> Herwig read (repo: $RPO ; include: ${INC:-cwd})"
Herwig read --repo "$RPO" ${INC:+$INC "$READROOT"} zjets.in
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
