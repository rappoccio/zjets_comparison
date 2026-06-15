// main_rivet.cc — PYTHIA 8.3 event generation piped natively into Rivet.
//
// One binary serves PYTHIA's simple shower, VINCIA and DIRE: the shower model
// is chosen entirely in the .cmnd file (PartonShowers:model = 1 / 2 / 3), so
// vincia/ and dire/ reuse this same program.
//
// Usage:  pythia8-rivet  <config.cmnd>  <output.yoda>  [nEvents]
//
// Reads LHE files too (Beams:frameType = 4), which is how the madgraph/ chain
// showers aMC@NLO events with MC@NLO matching handled by PYTHIA.

#include "Pythia8/Pythia.h"
#include "Pythia8Plugins/Pythia8Rivet.h"   // native Rivet interface, ships with PYTHIA 8.3

using namespace Pythia8;

int main(int argc, char* argv[]) {
  if (argc < 3) {
    std::cerr << "Usage: " << argv[0]
              << " <config.cmnd> <output.yoda> [nEvents]\n";
    return 1;
  }
  const std::string cmnd = argv[1];
  const std::string yoda = argv[2];

  Pythia pythia;
  pythia.readFile(cmnd);

  // Command-line nEvents overrides Main:numberOfEvents (handy for LHE files).
  int nEvents = pythia.mode("Main:numberOfEvents");
  if (argc > 3) nEvents = std::atoi(argv[3]);

  pythia.init();

  // Hook Rivet onto the generated events.
  Pythia8Rivet rivet(pythia, yoda);
  rivet.addAnalysis("CMS_2026_PAS_SMP_25_010");

  const int nAbort = 10;
  int iAbort = 0;
  for (int iEvent = 0; nEvents < 0 || iEvent < nEvents; ++iEvent) {
    if (!pythia.next()) {
      // End of an LHE file (frameType 4) is a clean stop, not an error.
      if (pythia.info.atEndOfFile()) break;
      if (++iAbort > nAbort) { std::cerr << "Too many errors, aborting.\n"; break; }
      continue;
    }
    rivet();   // analyze this event (uses the Pythia instance bound at construction)
  }

  pythia.stat();
  rivet.done();      // normalize + write the .yoda
  return 0;
}
