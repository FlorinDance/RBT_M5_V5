//+------------------------------------------------------------------+
//| RBT_M5_Hybrid_v5.10.20.mq5                                      |
//| Normal RBT + live recovery and trailing management.            |
//+------------------------------------------------------------------+
#property strict
#property version   "5.120"
#property description "RBT M5 v5.10.20 - combined global lock + Recovery Only + configurable time stop filters"

#include <Trade/Trade.mqh>
#include "XGB_M5_Wrapper.mqh"
#resource "Files\\RBT_V58_Model.bin" as uchar g_RBTHybridMotifModelBytes[]
#resource "Files\\RBT_RiskManager_V5113.bin" as uchar g_RBTRiskManagerModelBytes[]

CTrade trade;

#include "EA_ML_M5_Inputs.mqh"
#include "RBT_Hybrid_MotifRisk.mqh"

datetime g_lastBarTime = 0;
int hRSI = INVALID_HANDLE;
int hMACD = INVALID_HANDLE;
int hEMA = INVALID_HANDLE;
int hATR = INVALID_HANDLE;
int hADX = INVALID_HANDLE;
int hCCI = INVALID_HANDLE;
int hStoch = INVALID_HANDLE;
int hMomentum = INVALID_HANDLE;
int hWPR = INVALID_HANDLE;
int hBands = INVALID_HANDLE;

#include "EA_ML_M5_Helpers.mqh"
#include "EA_ML_M5_Filters.mqh"
#include "EA_ML_M5_PropRisk.mqh"
#include "EA_ML_M5_Panel.mqh"
#include "EA_ML_M5_ML.mqh"
#include "RBT_Hybrid_CSVLogger.mqh"
#include "RBT_Hybrid_TrajectoryLogger.mqh"
#include "RBT_NormalPolicyLab.mqh"
#include "RBT_ManagerDatasetLogger.mqh"
#include "RBT_RiskManagerShadow.mqh"
#include "EA_ML_M5_PositionManagement.mqh"
#include "RBT_RecoveryManager.mqh"
#include "Visual/RBT_Hybrid_StructureOverlay.mqh"

bool HybridValidateStartupInputs(string &reason)
{
   reason = "OK";
   if(InpM5FeatureMode != M5_FEATURE_TRAINING_ALIGNED)
      reason = "XGBoost requires TRAINING_ALIGNED feature mode";
   else if(InpMinBuyProb < 0.0 || InpMinBuyProb > 1.0 ||
           InpMinSellProb < 0.0 || InpMinSellProb > 1.0 ||
           InpMinDecisionGap < 0.0 || InpMinDecisionGap > 1.0)
      reason = "XGBoost confidence thresholds must be in [0,1]";
   else if(InpStopLossPips <= 0.0 || InpTakeProfitMoney <= 0.0)
      reason = "SL pips and TP money must be positive";
   else if(InpHybridFirstProfitEpsilonMoney < 0.0)
      reason = "First-profit epsilon cannot be negative";
   else if(InpManagerDatasetSampleSeconds < 1)
      reason = "Manager dataset sample seconds must be at least 1";
   else if(InpRiskManagerThreshold < 0.0 || InpRiskManagerThreshold > 1.0)
      reason = "Risk manager threshold must be in [0,1]";
   else if(InpRiskManagerReducedLotMultiplier <= 0.0 || InpRiskManagerReducedLotMultiplier > 1.0)
      reason = "Risk manager reduced multiplier must be in (0,1]";
   else if(!NormalPolicyValidateInputs(reason))
      return false;
   return (reason == "OK");
}

int OnInit()
{
   string recoveryReason="";
   if(!RecoveryValidateInputs(recoveryReason))
   {
      Print("RECOVERY invalid inputs | ",recoveryReason);
      return INIT_PARAMETERS_INCORRECT;
   }
   if(!RecoveryInit()) return INIT_FAILED; // RecoveryInit prints the file and exact MT5 error.
   string inputReason = "";
   if(!HybridValidateStartupInputs(inputReason))
   {
      Print("HYBRID startup refused: ", inputReason);
      return INIT_PARAMETERS_INCORRECT;
   }
   if(_Period != PERIOD_M5)
      Print("Warning: RBT M5 Hybrid is intended for an M5 chart.");

   hRSI      = iRSI(_Symbol, PERIOD_M5, 14, PRICE_CLOSE);
   hMACD     = iMACD(_Symbol, PERIOD_M5, 12, 26, 9, PRICE_CLOSE);
   hEMA      = iMA(_Symbol, PERIOD_M5, 20, 0, MODE_EMA, PRICE_CLOSE);
   hATR      = iATR(_Symbol, PERIOD_M5, 14);
   hADX      = iADX(_Symbol, PERIOD_M5, 14);
   hCCI      = iCCI(_Symbol, PERIOD_M5, 14, PRICE_TYPICAL);
   hStoch    = iStochastic(_Symbol, PERIOD_M5, 14, 3, 3, MODE_SMA, STO_LOWHIGH);
   hMomentum = iMomentum(_Symbol, PERIOD_M5, 14, PRICE_CLOSE);
   hWPR      = iWPR(_Symbol, PERIOD_M5, 14);
   hBands    = iBands(_Symbol, PERIOD_M5, 20, 0, 2.0, PRICE_CLOSE);
   if(hRSI == INVALID_HANDLE || hMACD == INVALID_HANDLE ||
      hEMA == INVALID_HANDLE || hATR == INVALID_HANDLE ||
      hADX == INVALID_HANDLE || hCCI == INVALID_HANDLE ||
      hStoch == INVALID_HANDLE || hMomentum == INVALID_HANDLE ||
      hWPR == INVALID_HANDLE || hBands == INVALID_HANDLE)
   {
      Print("HYBRID failed to create indicator handles.");
      return INIT_FAILED;
   }

   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, true);
   PanelInitializeRuntime();
   if(!PropRiskInitialize())
      return INIT_PARAMETERS_INCORRECT;

   double startupLots = 0.0;
   string startupLotReason = "";
   if(!PanelValidateRuntimeLotsValue(g_runtimeLots, startupLots, startupLotReason))
   {
      Print("HYBRID invalid startup lot: ", startupLotReason);
      return INIT_PARAMETERS_INCORRECT;
   }
   g_runtimeLots = startupLots;
   PanelCreate();
   HybridStructureOverlayInitialize();

   if(!RBTHybridMotifInitialize(g_RBTHybridMotifModelBytes))
      return INIT_PARAMETERS_INCORRECT;
   if(!HybridCSVInitialize())
      return INIT_FAILED;
   if(!HybridTrajectoryInitialize())
      return INIT_FAILED;
   if(!NormalPolicyInitialize())
      return INIT_FAILED;
   if(!ManagerDatasetInitialize())
      return INIT_FAILED;
   if(!RiskManagerInitialize(g_RBTRiskManagerModelBytes))
      return INIT_FAILED;

   PrintFormat("RBT M5 HYBRID v5.10.20 ready | recovery_mode=%d failure_live=%d delay=%.0fm activation=%.1f stop=%.1f window=%.0fm negative=%.2f slope_lt=%.3f | risk_shadow=%d threshold=%.3f reduced_mult=%.3f | manager_dataset=%d/%ds | XGB BUY=%.3f SELL=%.3f GAP=%.3f | motif=%s | base lot=%.2f fixedSL=%.2f | policy_lab=%d prudent_A=%.1f/%.1f prudent_O=%.1f/%.1f permissive_A=%.1f/%.1f permissive_O=%.1f/%.1f",
      (int)InpRecoveryMode,(int)InpRecoveryFailureProtection,InpRecoveryFailureDelayMinutes,
      InpRecoveryFailureActivationMoney,InpRecoveryFailureStopMoney,
      InpRecoveryFailureWindowMinutes,InpRecoveryFailureNegativeRatio,
      InpRecoveryFailureMaxSlopeMoneyPerMinute,
      (int)InpRiskManagerShadowEnable,InpRiskManagerThreshold,InpRiskManagerReducedLotMultiplier,
      (int)InpManagerDatasetEnable,InpManagerDatasetSampleSeconds,
      InpMinBuyProb, InpMinSellProb, InpMinDecisionGap,
      (InpHybridMotifEnable ? "QUALITY_RISK_ACTIVE" : "OFF"),
      g_runtimeLots,InpStopLossPips,(int)InpNormalPolicyLabEnable,
      InpNormalPrudentAgreeArmPctTP,InpNormalPrudentAgreeFloorPctTP,
      InpNormalPrudentOpposeArmPctTP,InpNormalPrudentOpposeFloorPctTP,
      InpNormalPermissiveAgreeArmPctTP,InpNormalPermissiveAgreeFloorPctTP,
      InpNormalPermissiveOpposeArmPctTP,InpNormalPermissiveOpposeFloorPctTP);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   HybridStructureOverlayShutdown();
   RecoveryShutdown();
   RiskManagerShutdown();
   ManagerDatasetShutdown();
   NormalPolicyShutdown(reason);
   HybridTrajectoryShutdown(reason);
   HybridCSVShutdown(reason);
   RBTHybridMotifShutdown(reason);
   PropRiskDeinitialize();
   PanelDestroy();
   if(hRSI != INVALID_HANDLE) IndicatorRelease(hRSI);
   if(hMACD != INVALID_HANDLE) IndicatorRelease(hMACD);
   if(hEMA != INVALID_HANDLE) IndicatorRelease(hEMA);
   if(hATR != INVALID_HANDLE) IndicatorRelease(hATR);
   if(hADX != INVALID_HANDLE) IndicatorRelease(hADX);
   if(hCCI != INVALID_HANDLE) IndicatorRelease(hCCI);
   if(hStoch != INVALID_HANDLE) IndicatorRelease(hStoch);
   if(hMomentum != INVALID_HANDLE) IndicatorRelease(hMomentum);
   if(hWPR != INVALID_HANDLE) IndicatorRelease(hWPR);
   if(hBands != INVALID_HANDLE) IndicatorRelease(hBands);
}

void OnChartEvent(const int id, const long &lparam,
                  const double &dparam, const string &sparam)
{
   PanelHandleEvent(id, lparam, dparam, sparam);
   if(g_panelStructureLinesRefreshRequested)
   {
      g_panelStructureLinesRefreshRequested=false;
      V3O_Update();
   }
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   OnRepeatWideSLBuyAfterFastTPTradeTransaction(trans);
   PropRiskOnTradeTransaction(trans);
   HybridCSVOnTradeTransaction(trans);
   HybridTrajectoryOnTradeTransaction(trans);
   NormalPolicyOnTradeTransaction(trans);
   RiskManagerOnTradeTransaction(trans);
}

void OnTick()
{
   // Must observe every real tick; inference itself remains hourly.
   RBTHybridMotifProcessTick();
   HybridTrajectoryProcessTick();
   NormalPolicyProcessTick();
   ManagerDatasetProcessTick();

   if(InpShowControlPanel && g_panelVisible && !g_panelCreated)
      PanelCreate();
   const bool propRiskLocked = PropRiskProcess();
   PanelUpdateStatus();
   if(propRiskLocked)
      return;

   if(g_runtimeUseMaxLossMoney)
      ManageOpenPositionsMaxLoss();
   ManageOpenPositionsFridayClose();
   RecoveryProcess();
   HybridStructureOverlayProcess();
   if(g_runtimeManageOpenPositions && g_runtimeUseProfitSteps &&
      InpProfitStepManageEveryTick)
      ManageOpenPositionsProfitSteps();

   if(!IsNewBar())
      return;
   if(g_runtimeManageOpenPositions && g_runtimeUseProfitSteps &&
      !InpProfitStepManageEveryTick)
      ManageOpenPositionsProfitSteps();

   double f[];
   double RSI, MACD, MACD_signal, MACD_hist, EMA, ATR, Volume, ADX, CCI;
   double Stochastic, Momentum, Williams_R;
   double Bollinger_upper, Bollinger_middle, Bollinger_lower;
   double SR_support, SR_resistance;
   double Dist_to_support_ATR, Dist_to_resistance_ATR;
   double Ret_1, Ret_3, Ret_12;
   if(!BuildFeatureVector(f, RSI, MACD, MACD_signal, MACD_hist, EMA, ATR,
      Volume, ADX, CCI, Stochastic, Momentum, Williams_R,
      Bollinger_upper, Bollinger_middle, Bollinger_lower,
      SR_support, SR_resistance, Dist_to_support_ATR,
      Dist_to_resistance_ATR, Ret_1, Ret_3, Ret_12))
   {
      Print("HYBRID failed to build XGBoost feature vector.");
      return;
   }

   double pSell = 0.0, pHold = 0.0, pBuy = 0.0;
   int decision = 1;
   M5_SelectedClassifierPredict(f, pSell, pHold, pBuy, decision);
   double rawTop=pSell,rawSecond=MathMax(pHold,pBuy);
   if(pHold>rawTop) { rawSecond=MathMax(rawTop,pBuy); rawTop=pHold; }
   if(pBuy>rawTop) { rawSecond=MathMax(rawTop,pHold); rawTop=pBuy; }
   ManagerDatasetSetXGB(decision,pSell,pHold,pBuy,rawTop-rawSecond);
   double regPred = (InpUseRegressorLog ? M5_RegressorPredict(f) : 0.0);
   PanelSetLastMLSignal(decision, pSell, pHold, pBuy, regPred);

   if(InpPrintFeatureLog)
      PrintMLInputs(decision, pSell, pHold, pBuy, regPred, RSI, MACD,
         MACD_signal, MACD_hist, EMA, ATR, Volume, ADX, CCI, Stochastic,
         Momentum, Williams_R, Bollinger_upper, Bollinger_middle,
         Bollinger_lower, SR_support, SR_resistance,
         Dist_to_support_ATR, Dist_to_resistance_ATR, Ret_1, Ret_3, Ret_12);

   if(decision == 1)
      return;

   double chosen = 0.0, second = 0.0, gap = 0.0;
   string confidenceReason = "";
   if(InpUseConfidenceFilter &&
      !PassesMLConfidenceFilter(decision, pSell, pHold, pBuy,
                                chosen, second, gap, confidenceReason))
      return;
   if(!InpUseConfidenceFilter)
   {
      chosen = (decision == 2 ? pBuy : pSell);
      second = (decision == 2 ? MathMax(pSell,pHold) : MathMax(pBuy,pHold));
      gap = chosen - second;
   }

   string trendReason = "", exhaustionReason = "", timingReason = "";
   if(!PassTrendStrengthFilter(decision, ADX, MACD_hist, Ret_3, Ret_12, trendReason) ||
      !PassExhaustionFilter(decision, Stochastic, Williams_R, CCI,
                            MACD_hist, exhaustionReason) ||
      !PassEntryTimingFilter(decision, Dist_to_support_ATR,
                             Dist_to_resistance_ATR, Ret_3, ATR, timingReason))
      return;

   string propReason = "";
   if(!PropRiskAllowsNewTrade(propReason))
   {
      PropRiskLogEntryBlock(propReason);
      return;
   }

   double lotMultiplier = 1.0, tpMultiplier = 1.0;
   bool allowTrade = true;
   string hybridReason = "XGBOOST_BASELINE";
   ENUM_RBT_HYBRID_MOTIF_STATE motifState = RBT_HYBRID_MOTIF_UNAVAILABLE;
   const bool applyMotifRisk = InpHybridMotifEnable;
   if(applyMotifRisk)
      motifState = RBTHybridResolveRisk(decision, lotMultiplier, tpMultiplier,
                                        allowTrade, hybridReason);
   const double baseTPMoney = g_runtimeTakeProfitMoney;
   const double effectiveTPMoney = baseTPMoney * MathMax(0.0,tpMultiplier);
   const double auditSLPips = (InpUseDynamicSL ? -1.0 : InpStopLossPips);

   PrintFormat("HYBRID ENTRY | xgb=%s pS=%.5f pH=%.5f pB=%.5f gap=%.5f | motif=%s age=%.1fm conf=%.4f netATR=%.4f | lot_mult=%.3f tp_mult=%.3f allow=%d reason=%s",
      M5_DecisionName(decision), pSell, pHold, pBuy, gap,
      RBTHybridMotifStateName(motifState),
      (g_hybridMotifLast.valid ?
       (double)(TimeCurrent()-g_hybridMotifLast.anchorTime)/60.0 : -1.0),
      g_hybridMotifLast.confidence, g_hybridMotifLast.expectedNetATR,
      lotMultiplier, tpMultiplier, (int)allowTrade, hybridReason);
   if(!allowTrade)
   {
      HybridCSVLogEntry(decision,pSell,pHold,pBuy,chosen,gap,motifState,
         g_runtimeLots,lotMultiplier,0.0,baseTPMoney,
         tpMultiplier,0.0,auditSLPips,
         false,hybridReason,false,0,0,0,"blocked by hybrid risk");
      return;
   }

   const double effectiveLot = NormalizeLotsToSymbol(g_runtimeLots * MathMax(0.0,lotMultiplier));
   const bool opened = OpenTradeFromDecision(decision, pSell, pHold, pBuy, regPred,
      RSI, MACD_hist, ATR, ADX, CCI, Stochastic, Williams_R,
      Dist_to_support_ATR, Dist_to_resistance_ATR, Ret_3, Ret_12,
      lotMultiplier, tpMultiplier, false, DYN_SL_NORMAL,
      "HYBRID_RUNTIME_CLASSIFICATION",false,0.0,0.0);
   if(opened)
   {
      double riskProbability=0.0,riskRecommendedMultiplier=1.0;
      const bool riskValid=RiskManagerPredict(decision,pSell,pHold,pBuy,gap,
         riskProbability,riskRecommendedMultiplier);
      if(!riskValid) riskRecommendedMultiplier=1.0;
      RiskManagerRegisterOpenedDeal(trade.ResultDeal(),riskProbability,riskRecommendedMultiplier);
      PrintFormat("RISK SHADOW ENTRY | valid=%d probability=%.6f threshold=%.6f class=%s baseline_mult=%.4f recommended_mult=%.4f real_actions=0",
         (int)riskValid,riskProbability,InpRiskManagerThreshold,
         (riskRecommendedMultiplier<1.0?"REDUCED":"FULL"),lotMultiplier,riskRecommendedMultiplier);
   }
   HybridCSVLogEntry(decision,pSell,pHold,pBuy,chosen,gap,motifState,
      g_runtimeLots,lotMultiplier,effectiveLot,baseTPMoney,
      tpMultiplier,effectiveTPMoney,auditSLPips,allowTrade,hybridReason,
      opened,(long)trade.ResultRetcode(),
      (opened ? trade.ResultOrder() : 0),(opened ? trade.ResultDeal() : 0),
      trade.ResultComment());
}
