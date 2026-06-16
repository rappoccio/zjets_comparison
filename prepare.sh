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

echo ">>> building pythia8-rivet driver (+ powheg8-rivet for the POWHEG chain)"
cd "$PKG/pythia" && make all

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

# --- POWHEG-BOX Zj binary (optional; only needed for submit_powheg.sh) ---
# If POWHEG-BOX is in CVMFS, copy/symlink the Zj `pwhg_main` to powheg/pwhg_main;
# otherwise build the Zj process once from source. CHECK first:
#   ls /cvmfs/sft.cern.ch/lcg/releases/MCGenerators/powheg-box*/ 2>/dev/null
if [ ! -x "$PKG/powheg/pwhg_main" ]; then
  PWHG_CVMFS=$(ls -d /cvmfs/sft.cern.ch/lcg/releases/MCGenerators/powheg-box*/*/*/Zj/pwhg_main 2>/dev/null | head -1 || true)
  if [ -n "$PWHG_CVMFS" ]; then
    cp -f "$PWHG_CVMFS" "$PKG/powheg/pwhg_main"
    echo ">>> POWHEG: copied Zj pwhg_main from $PWHG_CVMFS"
  else
    echo ">>> POWHEG: Zj pwhg_main not found in CVMFS — build it once and drop the" >&2
    echo "           binary at $PKG/powheg/pwhg_main (see HANDOFF.md §3). Skipping." >&2
  fi
fi

# --- Sherpa process libraries (optional; only needed for submit_sherpa.sh) ---
# Build the process libs ONCE so batch jobs skip the slow Comix/Amegic compile.
if command -v Sherpa >/dev/null && [ ! -d "$PKG/sherpa/Process" ]; then
  # LCG_107: Sherpa's HepMC3 output plugin (libSherpaHepMC3Output.so) is not exposed
  # on LD_LIBRARY_PATH by the view → locate it and prepend its dir (no-op if resolved).
  _shp=$(find "$(readlink -f "$(command -v Sherpa)" | sed 's#/bin/Sherpa$##')" \
    -name 'libSherpaHepMC3Output.so*' 2>/dev/null | head -1 || true)
  if [ -n "${_shp:-}" ]; then export LD_LIBRARY_PATH="$(dirname "$_shp"):${LD_LIBRARY_PATH:-}"; fi
  echo ">>> Sherpa: building process libraries (INIT_ONLY; slow, one-off)"
  ( cd "$PKG/sherpa" && RIVET_ANALYSIS_PATH="$PKG" Sherpa -f Sherpa.yaml INIT_ONLY=1 \
      && [ -f makelibs ] && ./makelibs ) \
    || echo "    WARN: Sherpa INIT failed (check Sherpa --version: YAML needs 3.x)." >&2
fi

echo ">>> OK: plugin + pythia8-rivet + powheg8-rivet (+ bundled bc) ready"
echo "    (POWHEG pwhg_main and Sherpa Process/ built above only if available.)"
