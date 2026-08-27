//+------------------------------------------------------------------+
//| RBT_Hybrid_MotifRisk.mqh                                         |
//| Hourly frozen Motif V5.8 assessment used only as XGBoost risk.   |
//+------------------------------------------------------------------+
#ifndef __RBT_HYBRID_MOTIF_RISK_MQH__
#define __RBT_HYBRID_MOTIF_RISK_MQH__

#include "RBT_V58_ModelEngine.mqh"
#include "RBT_V58_FeatureEngine.mqh"

enum ENUM_RBT_HYBRID_MOTIF_STATE
{
   RBT_HYBRID_MOTIF_UNAVAILABLE = 0,
   RBT_HYBRID_MOTIF_NEUTRAL     = 1,
   RBT_HYBRID_MOTIF_CONFIRM     = 2,
   RBT_HYBRID_MOTIF_OPPOSE      = 3
};

struct SRBTHybridMotifSnapshot
{
   bool valid;
   datetime anchorTime;
   int motifId;
   int direction; // -1=SELL, +1=BUY
   double pDown;
   double pNone;
   double pUp;
   double confidence;
   double predictedReturnATR;
   double costATR;
   double expectedNetATR;
   double grossToCostRatio;
   double atrPips;
   double spreadPips;
   bool strong;
};

CRBTV58Model g_hybridMotifModel;
CRBTV58FeatureEngine g_hybridMotifFeatures;
SRBTHybridMotifSnapshot g_hybridMotifLast;
bool g_hybridMotifReady = false;
long g_hybridMotifCandidates = 0;
long g_hybridMotifFailures = 0;

double g_RBTHybridHourSin[24] = {
   0.0,0.25881904510252074,0.49999999999999994,0.70710678118654746,
   0.8660254037844386,0.96592582628906831,1.0,0.96592582628906831,
   0.86602540378443871,0.70710678118654757,0.49999999999999994,
   0.25881904510252102,1.2246467991473532e-16,-0.25881904510252079,
   -0.49999999999999972,-0.70710678118654713,-0.86602540378443837,
   -0.96592582628906831,-1.0,-0.96592582628906842,-0.8660254037844386,
   -0.70710678118654768,-0.50000000000000044,-0.25881904510252157
};
double g_RBTHybridHourCos[24] = {
   1.0,0.96592582628906831,0.86602540378443871,0.70710678118654757,
   0.50000000000000011,0.25881904510252074,6.123233995736766e-17,
   -0.25881904510252063,-0.49999999999999978,-0.70710678118654746,
   -0.86602540378443871,-0.9659258262890682,-1.0,-0.96592582628906831,
   -0.86602540378443882,-0.70710678118654791,-0.50000000000000044,
   -0.25881904510252063,-1.8369701987210297e-16,0.2588190451025203,
   0.50000000000000011,0.70710678118654735,0.86602540378443837,
   0.96592582628906809
};
double g_RBTHybridWeekdaySin[5] = {
   0.0,0.95105651629515353,0.58778525229247325,-0.58778525229247303,
   -0.95105651629515364
};
double g_RBTHybridWeekdayCos[5] = {
   1.0,0.30901699437494745,-0.80901699437494734,-0.80901699437494756,
   0.30901699437494723
};

void RBTHybridMotifResetSnapshot()
{
   g_hybridMotifLast.valid = false;
   g_hybridMotifLast.anchorTime = 0;
   g_hybridMotifLast.motifId = -1;
   g_hybridMotifLast.direction = 0;
   g_hybridMotifLast.pDown = 0.0;
   g_hybridMotifLast.pNone = 0.0;
   g_hybridMotifLast.pUp = 0.0;
   g_hybridMotifLast.confidence = 0.0;
   g_hybridMotifLast.predictedReturnATR = 0.0;
   g_hybridMotifLast.costATR = 0.0;
   g_hybridMotifLast.expectedNetATR = 0.0;
   g_hybridMotifLast.grossToCostRatio = 0.0;
   g_hybridMotifLast.atrPips = 0.0;
   g_hybridMotifLast.spreadPips = 0.0;
   g_hybridMotifLast.strong = false;
}

bool RBTHybridMotifValidateInputs(string &reason)
{
   reason = "OK";
   if(InpHybridMotifMaximumAgeMinutes < 1 || InpHybridMotifMaximumAgeMinutes > 1440)
      reason = "Motif maximum age must be in [1,1440] minutes";
   else if(InpMotifDirectionConfidence < 0.5 || InpMotifDirectionConfidence > 1.0)
      reason = "Motif confidence must be in [0.5,1.0]";
   else if(InpMotifMinimumPredictedNetATR < 0.0 ||
           InpMotifMinimumGrossToCostRatio < 0.0 ||
           InpMotifMaximumSelectionCostATR < 0.0 ||
           InpMotifMaximumSpreadPips < 0.0)
      reason = "Motif gates cannot be negative";
   else if(InpHybridConfirmLotMultiplier < 0.0 ||
           InpHybridNeutralLotMultiplier < 0.0 ||
           InpHybridOpposeLotMultiplier < 0.0)
      reason = "Hybrid multipliers cannot be negative";
   else if(InpMotifLatestFridayEntryHour < 0 || InpMotifLatestFridayEntryHour > 24)
      reason = "Friday hour must be in [0,24]";
   return (reason == "OK");
}

bool RBTHybridMotifInitialize(const uchar &modelBytes[])
{
   RBTHybridMotifResetSnapshot();
   g_hybridMotifReady = false;
   if(!InpHybridMotifEnable)
      return true;
   string reason = "";
   if(!RBTHybridMotifValidateInputs(reason))
   {
      Print("HYBRID MOTIF input error: ", reason);
      return false;
   }
   if(_Symbol != "EURUSD" && StringFind(_Symbol, "EURUSD") < 0)
   {
      Print("HYBRID MOTIF requires an EURUSD symbol or broker suffix variant.");
      return false;
   }
   if(!g_hybridMotifModel.Load(modelBytes))
   {
      Print("HYBRID MOTIF failed to load frozen model.");
      return false;
   }
   if(!g_hybridMotifFeatures.Initialize(_Symbol))
   {
      Print("HYBRID MOTIF feature history is not ready.");
      return false;
   }
   g_hybridMotifReady = true;
   PrintFormat("HYBRID MOTIF ready | raw=%d decision=%d hourly_contract=1",
               g_hybridMotifModel.RawDimension(),
               g_hybridMotifModel.DecisionDimension());
   return true;
}

bool RBTHybridMotifEvaluate()
{
   g_hybridMotifCandidates++;
   double raw[], context[];
   int hour = 0, weekday = 0;
   double atrPips = 0.0, spreadPips = 0.0;
   string reason = "";
   if(!g_hybridMotifFeatures.Build(raw, context, hour, weekday,
                                   atrPips, spreadPips, reason))
   {
      g_hybridMotifFailures++;
      if(InpHybridMotifLog)
         PrintFormat("HYBRID MOTIF unavailable | anchor=%s reason=%s",
            TimeToString(g_hybridMotifFeatures.LastAnchorTime(), TIME_DATE|TIME_SECONDS), reason);
      return false;
   }

   int motifId = -1;
   double embedding[], motifDistance = 0.0, motifMargin = 0.0;
   if(!g_hybridMotifModel.Discover(raw, motifId, embedding, motifDistance, motifMargin))
   {
      g_hybridMotifFailures++;
      return false;
   }
   double decision[];
   ArrayResize(decision, 31);
   decision[0] = (double)motifId;
   for(int i = 0; i < 16; i++) decision[1+i] = context[i];
   decision[17] = g_RBTHybridHourSin[hour];
   decision[18] = g_RBTHybridHourCos[hour];
   decision[19] = g_RBTHybridWeekdaySin[weekday];
   decision[20] = g_RBTHybridWeekdayCos[weekday];
   for(int i = 0; i < 8; i++) decision[21+i] = embedding[i];
   decision[29] = motifDistance;
   decision[30] = motifMargin;

   double pDown = 0.0, pNone = 0.0, pUp = 0.0, predictedReturn = 0.0;
   if(!g_hybridMotifModel.Predict(decision, pDown, pNone, pUp, predictedReturn))
   {
      g_hybridMotifFailures++;
      return false;
   }
   const double directionalMass = MathMax(pUp + pDown, 1.0e-12);
   const double confidence = MathMax(pUp, pDown) / directionalMass;
   const double gross = MathAbs(predictedReturn);
   const double costPips = spreadPips * InpMotifSpreadMultiplier +
      InpMotifCommissionRoundTurnPips + InpMotifSlippageRoundTurnPips;
   const double costATR = (atrPips > 0.0 ? costPips / atrPips : 1.0e308);
   const double expectedNet = gross - costATR;
   const double ratio = (costATR > 0.0 ? gross / costATR : 1.0e308);
   const bool horizon = !(weekday == 4 && hour >= InpMotifLatestFridayEntryHour);
   const bool strong = (confidence >= InpMotifDirectionConfidence &&
      expectedNet >= InpMotifMinimumPredictedNetATR &&
      ratio >= InpMotifMinimumGrossToCostRatio &&
      costATR <= InpMotifMaximumSelectionCostATR &&
      spreadPips <= InpMotifMaximumSpreadPips && horizon && predictedReturn != 0.0);

   g_hybridMotifLast.valid = true;
   g_hybridMotifLast.anchorTime = g_hybridMotifFeatures.LastAnchorTime();
   g_hybridMotifLast.motifId = motifId;
   g_hybridMotifLast.direction = (predictedReturn > 0.0 ? 1 : (predictedReturn < 0.0 ? -1 : 0));
   g_hybridMotifLast.pDown = pDown;
   g_hybridMotifLast.pNone = pNone;
   g_hybridMotifLast.pUp = pUp;
   g_hybridMotifLast.confidence = confidence;
   g_hybridMotifLast.predictedReturnATR = predictedReturn;
   g_hybridMotifLast.costATR = costATR;
   g_hybridMotifLast.expectedNetATR = expectedNet;
   g_hybridMotifLast.grossToCostRatio = ratio;
   g_hybridMotifLast.atrPips = atrPips;
   g_hybridMotifLast.spreadPips = spreadPips;
   g_hybridMotifLast.strong = strong;
   if(InpHybridMotifLog)
      PrintFormat("HYBRID MOTIF hourly | %s motif=%d dir=%d conf=%.4f netATR=%.4f strong=%d",
         TimeToString(g_hybridMotifLast.anchorTime, TIME_DATE|TIME_SECONDS), motifId,
         g_hybridMotifLast.direction, confidence, expectedNet, (int)strong);
   return true;
}

void RBTHybridMotifProcessTick()
{
   if(!InpHybridMotifEnable || !g_hybridMotifReady)
      return;
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
      return;
   bool candidateDue = false;
   if(g_hybridMotifFeatures.ProcessTick(tick, candidateDue) && candidateDue)
      RBTHybridMotifEvaluate();
}

string RBTHybridMotifStateName(const ENUM_RBT_HYBRID_MOTIF_STATE state)
{
   if(state == RBT_HYBRID_MOTIF_CONFIRM) return "CONFIRM";
   if(state == RBT_HYBRID_MOTIF_OPPOSE) return "OPPOSE";
   if(state == RBT_HYBRID_MOTIF_NEUTRAL) return "NEUTRAL";
   return "UNAVAILABLE";
}

ENUM_RBT_HYBRID_MOTIF_STATE RBTHybridResolveRisk(
   const int xgbDecision, double &lotMultiplier, double &tpMultiplier,
   bool &allowTrade, string &reason)
{
   lotMultiplier = 1.0;
   tpMultiplier = 1.0;
   allowTrade = true;
   reason = "HYBRID_DISABLED";
   if(!InpHybridMotifEnable)
      return RBT_HYBRID_MOTIF_UNAVAILABLE;

   ENUM_RBT_HYBRID_MOTIF_STATE state = RBT_HYBRID_MOTIF_NEUTRAL;
   const datetime now = TimeCurrent();
   const long ageSeconds = (g_hybridMotifLast.valid ?
      (long)(now - g_hybridMotifLast.anchorTime) : 2147483647);
   const bool fresh = (g_hybridMotifLast.valid && ageSeconds >= 0 &&
      ageSeconds <= (long)InpHybridMotifMaximumAgeMinutes * 60);
   if(!fresh)
   {
      lotMultiplier = InpHybridNeutralLotMultiplier;
      reason = (g_hybridMotifLast.valid ? "MOTIF_STALE" : "MOTIF_NOT_READY");
   }
   else if(!g_hybridMotifLast.strong || g_hybridMotifLast.direction == 0)
   {
      lotMultiplier = InpHybridNeutralLotMultiplier;
      reason = "MOTIF_BELOW_STRONG_GATES";
   }
   else
   {
      const int xgbDirection = (xgbDecision == 2 ? 1 : -1);
      if(g_hybridMotifLast.direction == xgbDirection)
      {
         state = RBT_HYBRID_MOTIF_CONFIRM;
         lotMultiplier = InpHybridConfirmLotMultiplier;
         reason = "MOTIF_STRONG_CONFIRM";
      }
      else
      {
         state = RBT_HYBRID_MOTIF_OPPOSE;
         lotMultiplier = InpHybridOpposeLotMultiplier;
         allowTrade = !InpHybridSkipStrongOpposition;
         reason = (allowTrade ? "MOTIF_STRONG_OPPOSE_REDUCED" : "MOTIF_STRONG_OPPOSE_SKIP");
      }
   }
   lotMultiplier = MathMax(0.0, lotMultiplier);
   tpMultiplier = (InpHybridScaleTPWithLot ? lotMultiplier : 1.0);
   if(lotMultiplier <= 0.0)
      allowTrade = false;
   return state;
}

void RBTHybridMotifShutdown(const int reason)
{
   PrintFormat("HYBRID MOTIF finished | reason=%d candidates=%I64d failures=%I64d",
               reason, g_hybridMotifCandidates, g_hybridMotifFailures);
}

#endif
