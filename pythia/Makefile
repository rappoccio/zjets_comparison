# Build the PYTHIA8 -> Rivet driver. Intended to run *inside* the
# hepstore/rivet-pythia image (run.sh does this for you), where pythia8-config,
# rivet-config and HepMC3-config are all on PATH.

CXX      ?= g++
CXXSTD   ?= -std=c++17

# Strip pythia8-config's own -std (it ships -std=c++11, which would otherwise win
# over CXXSTD below and break Rivet's C++17 headers). CXXSTD is placed LAST so it
# is the effective standard regardless of what the *-config scripts inject.
PYTHIA_CF := $(filter-out -std=%,$(shell pythia8-config --cxxflags))
PYTHIA_LD := $(shell pythia8-config --ldflags)
RIVET_CF  := $(shell rivet-config --cppflags)
RIVET_LD  := $(shell rivet-config --ldflags --libs)
HEPMC_CF  := $(shell HepMC3-config --cflags 2>/dev/null)
HEPMC_LD  := $(shell HepMC3-config --ldflags 2>/dev/null) -lHepMC3

CXXFLAGS := -O2 $(PYTHIA_CF) $(RIVET_CF) $(HEPMC_CF) $(CXXSTD)
LDLIBS   := $(PYTHIA_LD) $(RIVET_LD) $(HEPMC_LD)

pythia8-rivet: main_rivet.cc
	$(CXX) $(CXXFLAGS) $< -o $@ $(LDLIBS)

# POWHEG variant: same driver + the PowhegHooks pT-veto (Pythia8Plugins).
powheg8-rivet: main_rivet_powheg.cc
	$(CXX) $(CXXFLAGS) $< -o $@ $(LDLIBS)

all: pythia8-rivet powheg8-rivet

clean:
	rm -f pythia8-rivet powheg8-rivet
.PHONY: all clean
