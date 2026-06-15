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

# aMC@NLO's NLO shower step calls `bc`, which batch worker nodes often lack (and
# you can't apt-get there). Stash a copy from this login node so the jobs find it
# on PATH. Its only runtime deps are base libs (libc, libtinfo) present on workers.
echo ">>> bundling bc for aMC@NLO showering"
mkdir -p "$PKG/madgraph/bin"
if command -v bc >/dev/null; then
  cp -f "$(command -v bc)" "$PKG/madgraph/bin/bc"
  echo "    bundled $(command -v bc) -> madgraph/bin/bc"
  echo "    deps: $(ldd "$(command -v bc)" 2>/dev/null | awk '{print $1}' | tr '\n' ' ')"
else
  echo "    WARN: bc not found on this node — aMC@NLO showering will be skipped on workers" >&2
fi

echo ">>> OK: plugin + pythia8-rivet (+ bundled bc) are ready"
