#!/usr/bin/env bash
# HTCondor payload: ONE aMC@NLO Z+jet sample showered by HERWIG7.
#
# aMC@NLO computes shower-specific MC@NLO counterterms, so the shower MUST match
# the one the LHE was generated for. Here madgraph/zjets_herwig.mg5 sets
# parton_shower=HERWIGPP, and we shower the resulting LHE with Herwig7's
# LesHouchesFileReader (herwig/lhe_shower_nlo.in) — configured for NLO MC@NLO
# events with IDWTUP=-4 and negative weights.
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
command -v mg5_aMC >/dev/null || { echo "mg5_aMC not in this LCG view" >&2; exit 1; }
command -v Herwig  >/dev/null || { echo "Herwig not in this LCG view"  >&2; exit 1; }

SCRATCH="${_CONDOR_SCRATCH_DIR:-${TMPDIR:-/tmp}}/mghw_${SEED}"
mkdir -p "$SCRATCH" && cd "$SCRATCH"

# 1. MadGraph: NLO generation + MadSpin -> parton-level LHE with HERWIG counterterms.
sed -e "s/@SEED@/$SEED/g" -e "s/@NEV@/$NEV/g" "$PKG/madgraph/zjets_herwig.mg5" > card.mg5
echo ">>> mg5_aMC (seed $SEED, $NEV events) — writes the HERWIG-counterterm LHE"
mg5_aMC card.mg5 || echo ">>> mg5_aMC returned $? (checking for the LHE anyway)"

LHE=$(ls -t zjets_nlo_hw*/Events/run_01_decayed_*/events.lhe.gz 2>/dev/null | head -1 || true)
[ -n "$LHE" ] || LHE=$(ls -t zjets_nlo_hw*/Events/run_01*/events.lhe.gz 2>/dev/null | head -1 || true)
[ -n "$LHE" ] || { echo "no LHE produced by MadGraph" >&2; exit 1; }
gunzip -kf "$LHE"; LHE="${LHE%.gz}"
LHE=$(readlink -f "$LHE")
echo ">>> showering LHE with Herwig7: $LHE"

# 2. Herwig setup. Same relocated-LCG fixes as gen_herwig_job.sh: find the real
#    read root (snippets/PPCollider.in) + the compiled-in HerwigDefaults.rpo.
cp "$PKG/herwig/lhe_shower_nlo.in" lhe_shower.in
sed -i "s#@LHE@#$LHE#g" lhe_shower.in

HWROOT=$(readlink -f "$(dirname "$(command -v Herwig)")/.." 2>/dev/null || true)
READROOT=""
if [ -f "$HWROOT/share/Herwig/snippets/PPCollider.in" ]; then
  READROOT="$HWROOT/share/Herwig"
else
  PP=$(find "$HWROOT" -name PPCollider.in -print -quit 2>/dev/null || true)
  [ -n "$PP" ] && READROOT=$(dirname "$(dirname "$PP")")
fi
[ -n "$READROOT" ] && [ -f "$READROOT/snippets/PPCollider.in" ] \
  || { echo "ERROR: snippets/PPCollider.in not found under $HWROOT" >&2; exit 1; }

RPO="$READROOT/HerwigDefaults.rpo"
[ -f "$RPO" ] || { echo "ERROR: HerwigDefaults.rpo not at $RPO" >&2; exit 1; }

HELP=$(Herwig read --help 2>&1 || true)
INC=""
for opt in --prepend-read --append-read -I -i; do
  printf '%s\n' "$HELP" | grep -q -- "$opt" && { INC="$opt"; break; }
done
ln -sf "$READROOT/snippets" snippets
[ -d "$READROOT/defaults" ] && ln -sf "$READROOT/defaults" defaults

echo ">>> Herwig read (repo: $RPO ; include: ${INC:-cwd})"
Herwig read --repo "$RPO" ${INC:+$INC "$READROOT"} lhe_shower.in
echo ">>> Herwig run (seed $SEED)"
Herwig run zjets_hw.run -s "$SEED" -d 0

YODA=$(ls -t *.yoda 2>/dev/null | head -1)
[ -n "$YODA" ] || { echo "no YODA produced by Herwig" >&2; exit 1; }

DEST="amcnlo_herwig_zjets_seed${SEED}.yoda"
if [ -n "$EOS_XROOTD" ]; then
  EOSDEST=$(printf '%s' "$OUTDIR" | sed -E 's#^/eos/home-([^/]+)/#/eos/user/\1/#')
  echo ">>> xrdcp -> ${EOS_XROOTD}${EOSDEST}/${DEST}"
  xrdcp -f "$YODA" "${EOS_XROOTD}${EOSDEST}/${DEST}" \
    || { echo "xrdcp failed; fuse fallback" >&2; mkdir -p "$OUTDIR"; cp -f "$YODA" "$OUTDIR/${DEST}"; }
else
  mkdir -p "$OUTDIR"; cp -f "$YODA" "$OUTDIR/${DEST}"
fi
cd /; rm -rf "$SCRATCH"
