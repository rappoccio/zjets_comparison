#!/usr/bin/env bash
# Generate rivet-mkhtml plots from YODA files in out/ with per-process styling.
set -euo pipefail
cd "$(dirname "$0")"
source ./config.sh
set +eu; source "$LCG_VIEW/setup.sh"; set -eu

if [ ! -d out ]; then
  echo "ERROR: out/ directory not found. Run build_yodas.sh first." >&2
  exit 1
fi

if [ ! -f out/axis.plot ]; then
  echo "ERROR: out/axis.plot not found. Run build_yodas.sh first." >&2
  exit 1
fi

echo ">>> Generating rivet-mkhtml plots from out/*.yoda..."
rivet-mkhtml -o html -c out/axis.plot out/*.yoda

echo ""
echo "✓ Done! Open html/index.html in a browser"
