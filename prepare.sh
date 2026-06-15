#!/usr/bin/env bash
# Run ONCE on the lxplus login node: build the Rivet plugin and the pythia8-rivet
# driver under the LCG view. The binaries link against CVMFS (which the batch
# workers also mount), so what builds here runs unchanged there.
set -euo pipefail
cd "$(dirname "$0")"
source ./config.sh

# LCG setup.sh is not strict-mode clean (uses unset $COMPILER etc.), so relax -eu.
set +eu; source "$LCG_VIEW/setup.sh"; set -eu
echo "Rivet: $(rivet --version)   (must be >= 4.0)"

echo ">>> building Rivet plugin"
cd "$PKG"
rivet-build RivetCMS_2026_PAS_SMP_25_010.so CMS_2026_PAS_SMP_25_010.cc \
    $(fastjet-config --cxxflags --libs) -lfastjetcontribfragile

echo ">>> building pythia8-rivet driver"
cd "$PKG/pythia" && make

echo ">>> OK: RivetCMS_2026_PAS_SMP_25_010.so and pythia/pythia8-rivet are ready"
