#!/usr/bin/env bash
# Local interactive test of the LO-MadGraph + HERWIG7 chain — same as
# gen_mglo_herwig_job.sh but local, verbose, keeps the run dir.
#   ./madgraph/run_local_lo_herwig.sh [NEV] [SEED]      # defaults: 1000 events, seed 1
set -euo pipefail
cd "$(dirname "$0")/.."                          # package root
source ./config.sh
set +eu; source "$LCG_VIEW/setup.sh"; set -eu
export RIVET_ANALYSIS_PATH="$PKG"
export PATH="$PKG/madgraph/bin:$PATH"
lhapdf ls --installed 2>/dev/null | grep -q NNPDF31_nnlo_as_0118 \
  || export LHAPDF_DATA_PATH="$PKG/lhapdf-cache:${LHAPDF_DATA_PATH:-}"

NEV="${1:-1000}"; SEED="${2:-1}"

echo "=== environment ==="
echo "mg5_aMC : $(command -v mg5_aMC || echo MISSING)"
echo "Herwig  : $(command -v Herwig || echo MISSING)   $(Herwig --version 2>&1 | head -1)"
echo "rivet   : $(rivet --version 2>/dev/null)"
command -v mg5_aMC >/dev/null || { echo "no mg5_aMC in this LCG view"; exit 1; }
command -v Herwig  >/dev/null || { echo "no Herwig in this LCG view";  exit 1; }
[ -f "$PKG/RivetCMS_2026_PAS_SMP_25_010.so" ] || { echo ">>> building plugin"; ( cd "$PKG" && ./prepare.sh ); }

WORK="$PKG/madgraph/local_run_mglo_herwig"; rm -rf "$WORK"; mkdir -p "$WORK"; cd "$WORK"
sed -e "s/@SEED@/$SEED/g" -e "s/@NEV@/$NEV/g" "$PKG/madgraph/zjets_lo_batch.mg5" > card.mg5
echo "=== card.mg5 ==="; cat card.mg5; echo "================"

echo ">>> mg5_aMC card.mg5 (LO) — writes the LO LHE"
mg5_aMC card.mg5 || echo ">>> mg5_aMC exit $? (continuing to the LHE)"
LHE=$(ls -t zjets_lo*/Events/run_01*/unweighted_events.lhe.gz 2>/dev/null | head -1 || true)
[ -n "$LHE" ] || LHE=$(ls -t zjets_lo*/Events/run_01*/events.lhe.gz 2>/dev/null | head -1 || true)
[ -n "$LHE" ] || { echo ">>> NO LHE produced — see output above. Run dir kept: $WORK"; exit 1; }
gunzip -kf "$LHE"; LHE=$(readlink -f "${LHE%.gz}")
echo ">>> showering LO LHE with Herwig7: $LHE"

# Herwig LHE reader + relocated-LCG fixes (same as the batch payload).
cp "$PKG/herwig/lhe_shower.in" .; sed -i "s#@LHE@#$LHE#g" lhe_shower.in
HWROOT=$(readlink -f "$(dirname "$(command -v Herwig)")/.." 2>/dev/null || true)
READROOT=""
if [ -f "$HWROOT/share/Herwig/snippets/PPCollider.in" ]; then READROOT="$HWROOT/share/Herwig"
else PP=$(find "$HWROOT" -name PPCollider.in -print -quit 2>/dev/null || true); [ -n "$PP" ] && READROOT=$(dirname "$(dirname "$PP")"); fi
[ -n "$READROOT" ] && [ -f "$READROOT/snippets/PPCollider.in" ] || { echo "ERROR: PPCollider.in not found under $HWROOT"; exit 1; }
RPO="$READROOT/HerwigDefaults.rpo"; [ -f "$RPO" ] || { echo "ERROR: HerwigDefaults.rpo not at $RPO"; exit 1; }
HELP=$(Herwig read --help 2>&1 || true); INC=""
for opt in --prepend-read --append-read -I -i; do printf '%s\n' "$HELP" | grep -q -- "$opt" && { INC="$opt"; break; }; done
ln -sf "$READROOT/snippets" snippets; [ -d "$READROOT/defaults" ] && ln -sf "$READROOT/defaults" defaults

echo ">>> Herwig read lhe_shower.in (repo $RPO ; include ${INC:-cwd})"
Herwig read --repo "$RPO" ${INC:+$INC "$READROOT"} lhe_shower.in
echo ">>> Herwig run (seed $SEED)"
Herwig run zjets_hw.run -s "$SEED" -d 1

YODA=$(ls -t *.yoda 2>/dev/null | head -1)
echo ">>> wrote ${YODA:-<none>}   (run dir kept: $WORK)"
