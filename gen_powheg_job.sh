#!/usr/bin/env bash
# HTCondor payload: ONE POWHEG-BOX Zj (Z+jet, NLO) sample showered by PYTHIA8
# with the PowhegHooks pT-veto (powheg8-rivet), distinct seed.
#
# POWHEG writes pwgevents.lhe (NLO matching encoded in the LHE); Pythia8 showers
# it and PowhegHooks applies the matching veto. The binary `pwhg_main` for the Zj
# process is bundled at $PKG/powheg/pwhg_main by prepare.sh (built once / copied
# from CVMFS — see prepare.sh).
#
# NOTE: a cold pwhg_main builds its integration grids first (slow). For many jobs,
# generate the grids ONCE and stage pwggrid*/pwg*.dat into $PKG/powheg/grids so the
# jobs reuse them (huge speedup) — see HANDOFF.md.
#
# Args:  SEED  NEV  PKG  LCG_VIEW  OUTDIR  [EOS_XROOTD]
set -euo pipefail
SEED="$1"; NEV="$2"; PKG="$3"; LCG_VIEW="$4"; OUTDIR="$5"; EOS_XROOTD="${6:-}"

set +eu; source "$LCG_VIEW/setup.sh"; set -eu
export RIVET_ANALYSIS_PATH="$PKG"
lhapdf ls --installed 2>/dev/null | grep -q NNPDF31_nnlo_as_0118 \
  || export LHAPDF_DATA_PATH="$PKG/lhapdf-cache:${LHAPDF_DATA_PATH:-}"

PWHG="$PKG/powheg/pwhg_main"
[ -x "$PWHG" ] || PWHG="$(command -v pwhg_main_Zj || command -v pwhg_main || true)"
[ -x "$PWHG" ] || { echo "pwhg_main (Zj) not found — see prepare.sh" >&2; exit 1; }
[ -x "$PKG/pythia/powheg8-rivet" ] || { echo "powheg8-rivet missing — run prepare.sh first" >&2; exit 1; }

SCRATCH="${_CONDOR_SCRATCH_DIR:-${TMPDIR:-/tmp}}/pwhg_${SEED}"
mkdir -p "$SCRATCH" && cd "$SCRATCH"

# 1. POWHEG: write powheg.input (its fixed filename) and generate the NLO LHE.
sed -e "s/@SEED@/$SEED/g" -e "s/@NEV@/$NEV/g" "$PKG/powheg/Zj.input" > powheg.input
# Reuse pre-computed integration grids if staged (much faster); harmless if absent.
[ -d "$PKG/powheg/grids" ] && cp -f "$PKG/powheg/grids/"* . 2>/dev/null || true
echo ">>> pwhg_main (Zj, seed $SEED, $NEV events)"
"$PWHG" || echo ">>> pwhg_main returned $? (checking for the LHE anyway)"

LHE=$(ls -t pwgevents*.lhe 2>/dev/null | head -1 || true)
[ -n "$LHE" ] || { echo "no LHE produced by POWHEG" >&2; exit 1; }
LHE=$(readlink -f "$LHE")
NIN=$(grep -c '<event>' "$LHE" 2>/dev/null || echo 0)
echo ">>> showering $NIN-event LHE with powheg8-rivet: $LHE"

# 2. Shower with Pythia8 (CP5 tune + POWHEG matching keys + the LHE).
CARD="$SCRATCH/shower.cmnd"
cat "$PKG/pythia/cp5.cmnd" "$PKG/pythia/powheg.cmnd" > "$CARD"
echo "Beams:LHEF = $LHE" >> "$CARD"
OUT="$SCRATCH/powheg_zjets_seed${SEED}.yoda"
"$PKG/pythia/powheg8-rivet" "$CARD" "$OUT" "$(( NIN > 0 ? NIN : 1000000 ))"
[ -s "$OUT" ] || { echo "powheg8-rivet produced no YODA" >&2; exit 1; }

# 3. Copy out.
DEST="powheg_zjets_seed${SEED}.yoda"
if [ -n "$EOS_XROOTD" ]; then
  EOSDEST=$(printf '%s' "$OUTDIR" | sed -E 's#^/eos/home-([^/]+)/#/eos/user/\1/#')
  echo ">>> xrdcp -> ${EOS_XROOTD}${EOSDEST}/${DEST}"
  xrdcp -f "$OUT" "${EOS_XROOTD}${EOSDEST}/${DEST}" \
    || { echo "xrdcp failed; fuse fallback" >&2; mkdir -p "$OUTDIR"; cp -f "$OUT" "$OUTDIR/${DEST}"; }
else
  mkdir -p "$OUTDIR"; cp -f "$OUT" "$OUTDIR/${DEST}"
fi
cd /; rm -rf "$SCRATCH"
