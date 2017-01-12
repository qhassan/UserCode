#ifndef _common_tools_h_
#define _common_tools_h_

#include "CondFormats/JetMETObjects/interface/FactorizedJetCorrector.h"
#include "CondFormats/JetMETObjects/interface/JetCorrectionUncertainty.h"
#include "CondFormats/JetMETObjects/interface/JetCorrectorParameters.h"
#include "TopLJets2015/TopAnalysis/interface/MiniEvent.h"

#include "TVector2.h"
#include "TGraph.h"
#include "TSystem.h"
#include "TFile.h"
#include "TH1.h"
#include "TString.h"

#include <vector>

std::map<Int_t,Float_t> lumiPerRun(TString era="era2015");
Float_t computeMT(TLorentzVector &a, TLorentzVector &b);
std::vector<TGraph *> getPileupWeights(TString era,TH1 *puTrue);
FactorizedJetCorrector *getFactorizedJetEnergyCorrector(TString,bool);
std::vector<float> getJetResolutionScales(float pt, float eta, float genjpt);
float getLeptonEnergyScaleUncertainty(int l_id,float l_pt,float l_eta);

struct JetPullInfo_t
{
  Int_t n,nch;
  TVector2 pull,chPull;
};
JetPullInfo_t getPullVector( MiniEvent_t &ev, int ijet);

#endif
