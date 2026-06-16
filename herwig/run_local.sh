#!/usr/bin/env bash
# Local interactive test of the HERWIG7 (internal ME + angular-ordered shower)
# Z+jets chain — same as gen_herwig_job.sh but local, verbose, keeps the run dir.
#   ./herwig/run_local.sh [NEV] [SEED]      # defaults: 1000 events, seed 1
set -euo pipefail
cd "$(dirname "$0")/.."                          # package root
source ./config.sh
set +eu; source "$LCG_VIEW/setup.sh"; set -eu
export RIVET_ANALYSIS_PATH="$PKG"

NEV="${1:-1000}"; SEED="${2:-1}"

echo "=== environment ==="
echo "Herwig : $(command -v Herwig || echo MISSING)   $(Herwig --version 2>&1 | head -1)"
echo "rivet  : $(rivet --version 2>/dev/null)"
command -v Herwig >/dev/null || { echo "no Herwig in this LCG view"; exit 1; }
[ -f "$PKG/RivetCMS_2026_PAS_SMP_25_010.so" ] || { echo ">>> building plugin"; ( cd "$PKG" && ./prepare.sh ); }

WORK="$PKG/herwig/local_run"; rm -rf "$WORK"; mkdir -p "$WORK"; cd "$WORK"
cp "$PKG/herwig/zjets.in" .

# Same relocated-LCG fixes as the batch payload: find the real read root + repo.
HWROOT=$(readlink -f "$(dirname "$(command -v Herwig)")/.." 2>/dev/null || true)
READROOT=""
if [ -f "$HWROOT/share/Herwig/snippets/PPCollider.in" ]; then
  READROOT="$HWROOT/share/Herwig"
else
  PP=$(find "$HWROOT" -name PPCollider.in -print -quit 2>/dev/null || true)
  [ -n "$PP" ] && READROOT=$(dirname "$(dirname "$PP")")
fi
[ -n "$READROOT" ] && [ -f "$READROOT/snippets/PPCollider.in" ] \
  || { echo "ERROR: snippets/PPCollider.in not found under $HWROOT"; exit 1; }
RPO="$READROOT/HerwigDefaults.rpo"
[ -f "$RPO" ] || { echo "ERROR: HerwigDefaults.rpo not at $RPO"; exit 1; }
HELP=$(Herwig read --help 2>&1 || true); INC=""
for opt in --prepend-read --append-read -I -i; do
  printf '%s\n' "$HELP" | grep -q -- "$opt" && { INC="$opt"; break; }
done
ln -sf "$READROOT/snippets" snippets
[ -d "$READROOT/defaults" ] && ln -sf "$READROOT/defaults" defaults

echo "=== read root: $READROOT  (repo $RPO ; include ${INC:-cwd}) ==="
echo ">>> Herwig read zjets.in — watch for ME/decay errors"
Herwig read --repo "$RPO" ${INC:+$INC "$READROOT"} zjets.in
echo ">>> Herwig run ($NEV events, seed $SEED)"
Herwig run zjets.run -N "$NEV" -s "$SEED" -d 1

YODA=$(ls -t *.yoda 2>/dev/null | head -1)
echo ">>> wrote ${YODA:-<none>}   (run dir kept: $WORK)"
