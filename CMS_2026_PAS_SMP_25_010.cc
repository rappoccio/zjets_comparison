// -*- C++ -*-
// Rivet analysis: Differential jet normalized mass (m/pT*R) and pT cross sections in dijet,
// Z+jets, and trijet events at 13 TeV (Run II).
//
// Measures normalized (1/sigma)(d^2 sigma / d pT d log10(rho^2)) for the
// leading AK8 anti-kT jet (R=0.8) as a 2D histogram binned in ungroomed jet
// pT (x) and log10(rho^2) where rho = m / (pT * R), R = 0.8 (y), separately
// for groomed and ungroomed mass.
//
// Channels:
//   Z+jets:  Z->ll + >= 1 AK8 jet, leading jet filled
//   Dijet:   >= 2 AK8 jets, leading jet filled [quark-enriched]
//   Trijet:  >= 3 AK8 jets, 3rd (softest) jet filled [gluon-enriched]
//
// Closely follows CMS_2018_I1682495 (dijet jet mass at 13 TeV).
// Requires FastJet contrib (SoftDrop).

#include "Rivet/Analysis.hh"
#include <cmath>
#include "Rivet/Projections/FinalState.hh"
#include "Rivet/Projections/FastJets.hh"
#include "Rivet/Projections/DileptonFinder.hh"
#include "Rivet/Projections/VetoedFinalState.hh"
#include "fastjet/contrib/SoftDrop.hh"

namespace Rivet {

class CMS_2026_PAS_SMP_25_010 : public Analysis {
public:

  RIVET_DEFAULT_ANALYSIS_CTOR(CMS_2026_PAS_SMP_25_010);

  // Adjust these constants to match your analysis note.
  static constexpr double SD_BETA = 0.0;
  static constexpr double SD_ZCUT = 0.1;
  static constexpr double JET_R   = 0.8;

  // 2D binning matched to the HepData export (hepdata_export_*.npz):
  //   x = leading-jet pT, 3 slices: [200,290], [290,400], [400,inf) (last edge = catch-all)
  //   y = log10(rho^2), rho = m/(pT*R); 10 bins, first one a wide [-10,-4.5] catch-all
  static const std::vector<double>& ptEdges() {
    static const std::vector<double> e = {200., 290., 400., 13000.};
    return e;
  }
  static const std::vector<double>& massEdges() {
    static const std::vector<double> e =
      {-10., -4.5, -4., -3.5, -3., -2.5, -2., -1.5, -1., -0.5, 0.};
    return e;
  }


  // -----------------------------------------------------------------------
  void init() {

    // Full final state (tracker + calorimeter acceptance)
    const FinalState fs(Cuts::abseta < 5.0);

    // --- Z finder (muon channel) ---
    // Rivet 4: DileptonFinder(masstarget, dRmax_dressing, leptonCuts+PID, pairCuts)
    const Cut lep_cuts = Cuts::pT > 20*GeV && Cuts::abseta < 2.4;
    DileptonFinder zfinder_mu(91.2*GeV, 0.1, lep_cuts && Cuts::abspid == PID::MUON, Cuts::massIn(71*GeV, 111*GeV));
    declare(zfinder_mu, "ZFinderMu");

    // --- Z finder (electron channel) ---
    DileptonFinder zfinder_el(91.2*GeV, 0.1, lep_cuts && Cuts::abspid == PID::ELECTRON, Cuts::massIn(71*GeV, 111*GeV));
    declare(zfinder_el, "ZFinderEl");

    // --- Jets for Z+jets: veto Z decay products to avoid double-counting ---
    VetoedFinalState fs_zjets(fs);
    fs_zjets.addVetoOnThisFinalState(zfinder_mu);
    fs_zjets.addVetoOnThisFinalState(zfinder_el);
    FastJets jets_zjets(fs_zjets, JetAlg::ANTIKT, 0.8);
    declare(jets_zjets, "JetsZJets");

    // --- Jets for dijet and trijet (inclusive, full FS) ---
    FastJets jets_incl(fs, JetAlg::ANTIKT, 0.8);
    declare(jets_incl, "JetsIncl");

    // -----------------------------------------------------------------------
    // Book 2D histograms (x = leading-jet pT, y = log10(rho^2)) for each
    // channel x grooming, with the HepData binning.
    for (const string& chan : {"zjets", "dijet", "trijet"})
      for (const string& groom : {"ungroomed", "groomed"}) {
        const string name = chan + "_" + groom;
        book(_h2[name], name, ptEdges(), massEdges());
      }
  }

  // -----------------------------------------------------------------------
  void analyze(const Event& event) {

    // Soft drop groomer: beta=0 (mMDT), z_cut=0.1
    fastjet::contrib::SoftDrop sd(SD_BETA, SD_ZCUT);

    // -----------------------------------------------------------------------
    // Z+JETS CHANNEL
    // Require a Z->mumu or Z->ee candidate (71 < m_ll < 111 GeV).
    // Require >= 1 AK8 jet with pT > 200 GeV, |eta| < 2.5,
    // separated from the Z by deltaR > 1.0.
    // Fill leading jet: x = ungroomed pT, y = ungroomed or groomed log10(rho**2)
    {
      const ZFinder& zf_mu = apply<DileptonFinder>(event, "ZFinderMu");
      const ZFinder& zf_el = apply<DileptonFinder>(event, "ZFinderEl");

      const bool has_z_mu = !zf_mu.bosons().empty();
      const bool has_z_el = !zf_el.bosons().empty();

      if (has_z_mu || has_z_el) {
        // Prefer muons; could also take highest-pT Z candidate
        const FourMomentum z_mom = has_z_mu
          ? zf_mu.bosons()[0].momentum()
          : zf_el.bosons()[0].momentum();

        const Jets jets = apply<FastJets>(event, "JetsZJets")
                            .jetsByPt(Cuts::pT > 200*GeV && Cuts::abseta < 2.5);

        for (const Jet& jet : jets) {
          if (deltaR(jet.momentum(), z_mom) > 1.0) {
            const double pt_ungroomed  = jet.pT()/GeV;
            const double rho_ungroomed = jet.mass()/GeV / (pt_ungroomed * JET_R);
            if (rho_ungroomed > 0.)
              _h2["zjets_ungroomed"]->fill(pt_ungroomed, std::log10(rho_ungroomed*rho_ungroomed));

            const fastjet::PseudoJet groomed = sd(jet.pseudojet());
            if (groomed.m() > 0.) {
              const double rho_groomed = groomed.m()/GeV / (pt_ungroomed * JET_R);
              _h2["zjets_groomed"]->fill(pt_ungroomed, std::log10(rho_groomed*rho_groomed));
            }

            break; // leading jet only
          }
        }
      }
    }
    

    // -----------------------------------------------------------------------
    // DIJET CHANNEL
    // Select events with >= 2 AK8 jets, pT > 200 GeV, |eta| < 2.5.
    // Require the two leading jets to be back-to-back (delta_phi > 2.0 rad)
    // and not too asymmetric in pT (pT2/pT1 > 0.3).
    // Fill leading jet: x = ungroomed pT, y = ungroomed or groomed mass.
    {
      const Jets jets = apply<FastJets>(event, "JetsIncl")
                          .jetsByPt(Cuts::pT > 200*GeV && Cuts::abseta < 2.5);

      if (jets.size() >= 2) {
        const Jet& j1 = jets[0];
        const Jet& j2 = jets[1];

        const double dphi    = deltaPhi(j1.phi(), j2.phi());
        const double pt_asym = j2.pT() / j1.pT();

        if (dphi > 2.0 && pt_asym > 0.3) {
          for (const Jet* jj : {&j1, &j2}) {
            const double pt_ungroomed  = jj->pT()/GeV;
            const double rho_ungroomed = jj->mass()/GeV / (pt_ungroomed * JET_R);
            if (rho_ungroomed > 0.)
              _h2["dijet_ungroomed"]->fill(pt_ungroomed, std::log10(rho_ungroomed*rho_ungroomed));

            const fastjet::PseudoJet groomed = sd(jj->pseudojet());
            if (groomed.m() > 0.) {
              const double rho_groomed = groomed.m()/GeV / (pt_ungroomed * JET_R);
              _h2["dijet_groomed"]->fill(pt_ungroomed, std::log10(rho_groomed*rho_groomed));
            }
          }
        }
      }
    }


    // -----------------------------------------------------------------------
    // TRIJET CHANNEL
    // Select events with >= 3 AK8 jets, all with pT > 200 GeV, |eta| < 2.5.
    // Fill the 3rd (softest) jet: this sample is enriched in gluon jets
    // because soft color-coherent radiation preferentially produces
    // gluon-initiated jets at lower pT in three-body final states.
    // x = ungroomed pT of the 3rd jet, y = ungroomed or groomed mass.
    //
    // NOTE: No explicit Z veto is applied here. Add one if you need
    // the trijet channel to be orthogonal to Z+jets.
    {
      const Jets jets = apply<FastJets>(event, "JetsIncl")
                          .jetsByPt(Cuts::pT > 200*GeV && Cuts::abseta < 2.5);

      if (jets.size() >= 3) {
        const Jet& j3 = jets[2]; // softest of the three leading jets
        const double pt_ungroomed  = j3.pT()/GeV;
        const double rho_ungroomed = j3.mass()/GeV / (pt_ungroomed * JET_R);
        if (rho_ungroomed > 0.)
          _h2["trijet_ungroomed"]->fill(pt_ungroomed, std::log10(rho_ungroomed*rho_ungroomed));

        const fastjet::PseudoJet groomed = sd(j3.pseudojet());
        if (groomed.m() > 0.) {
          const double rho_groomed = groomed.m()/GeV / (pt_ungroomed * JET_R);
          _h2["trijet_groomed"]->fill(pt_ungroomed, std::log10(rho_groomed*rho_groomed));
        }
      }
    }
  }

  // -----------------------------------------------------------------------
  void finalize() {
    for (auto& kv : _h2) normalize(kv.second);
  }

private:
  map<string, Histo2DPtr> _h2;
};

// Register analysis
RIVET_DECLARE_PLUGIN(CMS_2026_PAS_SMP_25_010);

} // namespace Rivet
