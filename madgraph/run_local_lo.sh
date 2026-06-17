#!/usr/bin/env bash
# Local interactive test of the LO-MadGraph + PYTHIA8/VINCIA/HERWIG chains — same as
# gen_mglo_job.sh but local, verbose, keeps the run dir.
#   ./madgraph/run_local_lo.sh [MODEL] [NEV] [SEED]
#     MODEL 1 = PYTHIA8 (CP5), 2 = VINCIA, 3 = HERWIG7  (default 1)
#     NEV defaults 2000, SEED defaults 1
set -euo pipefail
cd "$(dirname "$0")/.."                          # package root
source ./config.sh
set +eu; source "$LCG_VIEW/setup.sh"; set -eu
export RIVET_ANALYSIS_PATH="$PKG"
export PATH="$PKG/madgraph/bin:$PATH"
lhapdf ls --installed 2>/dev/null | grep -q NNPDF31_nnlo_as_0118 \
  || export LHAPDF_DATA_PATH="$PKG/lhapdf-cache:${LHAPDF_DATA_PATH:-}"

MODEL="${1:-1}"; NEV="${2:-2000}"; SEED="${3:-1}"
case "$MODEL" in 1) TAG=mglo_pythia ;; 2) TAG=mglo_vincia ;; 3) TAG=mglo_herwig ;; *) echo "MODEL must be 1, 2, or 3"; exit 1 ;; esac

echo "=== environment ==="
echo "mg5_aMC : $(command -v mg5_aMC || echo MISSING)"
echo "pythia8 : $(command -v pythia8-config || echo MISSING)"
echo "herwig  : $(command -v Herwig || echo MISSING)"
echo "rivet   : $(rivet --version 2>/dev/null)"
command -v mg5_aMC >/dev/null || { echo "no mg5_aMC in this LCG view"; exit 1; }
if [ "$MODEL" != "3" ]; then
  [ -x "$PKG/pythia/pythia8-rivet" ] || { echo ">>> building pythia8-rivet"; ( cd "$PKG/pythia" && make ); }
else
  command -v Herwig >/dev/null || { echo "no Herwig in this LCG view"; exit 1; }
fi

WORK="$PKG/madgraph/local_run_${TAG}"; rm -rf "$WORK"; mkdir -p "$WORK"; cd "$WORK"
sed -e "s/@SEED@/$SEED/g" -e "s/@NEV@/$NEV/g" "$PKG/madgraph/zjets_lo_batch.mg5" > card.mg5
echo "=== card.mg5 ==="; cat card.mg5; echo "================"

echo ">>> mg5_aMC card.mg5 (LO) — writes the LO LHE"
mg5_aMC card.mg5 || echo ">>> mg5_aMC exit $? (continuing to the LHE)"
LHE=$(ls -t zjets_lo*/Events/run_01*/unweighted_events.lhe.gz 2>/dev/null | head -1 || true)
[ -n "$LHE" ] || LHE=$(ls -t zjets_lo*/Events/run_01*/events.lhe.gz 2>/dev/null | head -1 || true)
[ -n "$LHE" ] || { echo ">>> NO LHE produced — see output above. Run dir kept: $WORK"; exit 1; }
gunzip -kf "$LHE"; LHE="${LHE%.gz}"; NIN=$(grep -c '<event>' "$LHE" 2>/dev/null || echo 0)
LHE=$(readlink -f "$LHE")

if [ "$MODEL" = "3" ]; then
  echo ">>> showering $NIN-event LO LHE with Herwig7: $LHE"

  # Set up Herwig
  cp "$PKG/herwig/lhe_shower.in" "$WORK/shower.in"
  sed -i "s#@LHE@#$LHE#g" "$WORK/shower.in"

  HWROOT=$(readlink -f "$(dirname "$(command -v Herwig)")/.." 2>/dev/null || true)
  READROOT=""
  if [ -f "$HWROOT/share/Herwig/snippets/PPCollider.in" ]; then
    READROOT="$HWROOT/share/Herwig"
  else
    PP=$(find "$HWROOT" -name PPCollider.in -print -quit 2>/dev/null || true)
    [ -n "$PP" ] && READROOT=$(dirname "$(dirname "$PP")")
  fi
  [ -n "$READROOT" ] && [ -f "$READROOT/snippets/PPCollider.in" ] \
    || { echo "ERROR: snippets/PPCollider.in not found"; exit 1; }

  RPO="$READROOT/HerwigDefaults.rpo"
  [ -f "$RPO" ] || { echo "ERROR: HerwigDefaults.rpo not at $RPO"; exit 1; }

  ln -sf "$READROOT/snippets" "$WORK/snippets"
  [ -d "$READROOT/defaults" ] && ln -sf "$READROOT/defaults" "$WORK/defaults"

  echo ">>> Herwig read (repo: $RPO)"
  Herwig read --repo "$RPO" --prepend-read "$READROOT" "$WORK/shower.in"
  echo ">>> Herwig run (seed $SEED)"
  Herwig run "$WORK/zjets_hw.run" -s "$SEED" -d 0

  YODA=$(ls -t "$WORK"/*.yoda 2>/dev/null | head -1)
  [ -n "$YODA" ] || { echo ">>> NO YODA produced by Herwig — run dir kept: $WORK"; exit 1; }
  cp "$YODA" "$WORK/${TAG}_zjets_local.yoda"
else
  echo ">>> showering $NIN-event LO LHE with pythia8-rivet (model $MODEL): $LHE"

  CARD="$WORK/shower.cmnd"
  TUNE="$PKG/pythia/cp5.cmnd"; [ "$MODEL" = "2" ] && TUNE="$PKG/pythia/vincia.cmnd"
  cat "$TUNE" > "$CARD"
  { echo "PartonShowers:model = $MODEL"; echo "Beams:frameType = 4"; echo "Beams:LHEF = $LHE"; } >> "$CARD"
  "$PKG/pythia/pythia8-rivet" "$CARD" "$WORK/${TAG}_zjets_local.yoda" "$(( NIN > 0 ? NIN : 1000000 ))"
fi
echo ">>> wrote $WORK/${TAG}_zjets_local.yoda   (run dir kept: $WORK)"
