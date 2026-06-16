#!/usr/bin/env bash
# Local interactive test of the Sherpa (MEPS@LO Z+jets) chain — same as
# gen_sherpa_job.sh but local, verbose, keeps the run dir.
#   ./sherpa/run_local.sh [NEV] [SEED]      # defaults: 500 events, seed 1
#
# The FIRST run builds the process libraries (Comix/Amegic compile — slow); it is
# cached under the run dir, so re-runs are fast. Confirm `Sherpa --version` is 3.x
# (the YAML is 3.x syntax; 2.2.x needs Run.dat).
set -euo pipefail
cd "$(dirname "$0")/.."                          # package root
source ./config.sh
set +eu; source "$LCG_VIEW/setup.sh"; set -eu
export RIVET_ANALYSIS_PATH="$PKG"
lhapdf ls --installed 2>/dev/null | grep -q NNPDF31_nnlo_as_0118 \
  || export LHAPDF_DATA_PATH="$PKG/lhapdf-cache:${LHAPDF_DATA_PATH:-}"

NEV="${1:-500}"; SEED="${2:-1}"

echo "=== environment ==="
echo "Sherpa : $(command -v Sherpa || echo MISSING)   $(Sherpa --version 2>&1 | head -1)"
echo "rivet  : $(rivet --version 2>/dev/null)"
command -v Sherpa >/dev/null || { echo "no Sherpa in this LCG view"; exit 1; }
[ -f "$PKG/RivetCMS_2026_PAS_SMP_25_010.so" ] || { echo ">>> building plugin"; ( cd "$PKG" && ./prepare.sh ); }

WORK="$PKG/sherpa/local_run"; mkdir -p "$WORK"; cd "$WORK"
cp "$PKG/sherpa/Sherpa.yaml" .
echo "=== Sherpa.yaml ==="; cat Sherpa.yaml; echo "==================="

echo ">>> Sherpa -f Sherpa.yaml ($NEV events, seed $SEED) — first run builds process libs"
Sherpa -f Sherpa.yaml -e "$NEV" -R "$SEED" -A "sherpa_local"

YODA=$(ls -t sherpa_local*.yoda *.yoda 2>/dev/null | head -1 || true)
echo ">>> wrote ${YODA:-<none>}   (run dir kept: $WORK)"
