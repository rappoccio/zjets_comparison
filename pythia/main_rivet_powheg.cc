// main_rivet_powheg.cc — shower a POWHEG-BOX LHE with PYTHIA 8.3 and the official
// PowhegHooks pT-veto, piped natively into Rivet.
//
// This is main_rivet.cc + the POWHEG matching UserHook (Pythia8Plugins/PowhegHooks.h,
// the analog of PYTHIA's main31.cc). The plain pythia8-rivet driver does NOT install
// PowhegHooks, so POWHEG NLO matching would be wrong with it — hence this variant.
//
// Usage:  powheg8-rivet  <config.cmnd>  <output.yoda>  [nEvents]
//
// The .cmnd must set Beams:frameType=4 + Beams:LHEF, and the POWHEG:* keys the hook
// reads (POWHEG:nFinal, POWHEG:veto=1, SpaceShower/TimeShower:pTmaxMatch=2, ...).

#include "Pythia8/Pythia.h"
#include "Pythia8Plugins/Pythia8Rivet.h"
#include "Pythia8Plugins/PowhegHooks.h"

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

  int nEvents = pythia.mode("Main:numberOfEvents");
  if (argc > 3) nEvents = std::atoi(argv[3]);

  // Install the POWHEG pT-veto hook (reads its POWHEG:* settings from the cmnd).
  std::shared_ptr<PowhegHooks> powhegHooks = std::make_shared<PowhegHooks>();
  pythia.setUserHooksPtr(powhegHooks);

  pythia.init();

  Pythia8Rivet rivet(pythia, yoda);
  rivet.addAnalysis("CMS_2026_PAS_SMP_25_010");

  const int nAbort = 10;
  int iAbort = 0;
  for (int iEvent = 0; nEvents < 0 || iEvent < nEvents; ++iEvent) {
    if (!pythia.next()) {
      if (pythia.info.atEndOfFile()) break;
      if (++iAbort > nAbort) { std::cerr << "Too many errors, aborting.\n"; break; }
      continue;
    }
    rivet();
  }

  pythia.stat();
  rivet.done();
  return 0;
}
