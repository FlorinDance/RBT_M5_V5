//+------------------------------------------------------------------+
//| EA_ML_M5_ML.mqh                                                 |
//| V3 Phase 0: feature schema alignment + legacy parity mode.      |
//+------------------------------------------------------------------+

#ifndef __EA_ML_M5_ML_MQH__
#define __EA_ML_M5_ML_MQH__

string M5_FeatureModeName(const ENUM_M5_FEATURE_MODE mode)
{
   if(mode == M5_FEATURE_LEGACY_COMPAT)
      return "LEGACY_COMPAT";
   return "TRAINING_ALIGNED";
}

string M5_TemporalModelName(const ENUM_M5_TEMPORAL_MODEL model)
{
   return "PRODUCTION_5_6D";
}

void M5_SelectedClassifierPredict(const double &f[],
                                  double &pSell, double &pHold, double &pBuy,
                                  int &decision)
{
   M5_ClassifierPredict(f, pSell, pHold, pBuy, decision);
}

string M5_DecisionName(const int decision)
{
   if(decision == 0) return "SELL";
   if(decision == 2) return "BUY";
   return "HOLD";
}

bool M5_IsUsableNumber(const double value)
{
   if(!MathIsValidNumber(value))
      return false;
   if(value == EMPTY_VALUE)
      return false;
   if(MathAbs(value) > 1.0e100)
      return false;
   return true;
}

void M5_ApplyAlignedMissingPolicy(double &f[])
{
   if(ArraySize(f) < 22)
      return;

   for(int i = 0; i < 22; ++i)
   {
      if(!M5_IsUsableNumber(f[i]))
         f[i] = M5_MEDIANS[i];
   }

   // A zero tick-volume on the last closed candle means unavailable/incomplete
   // broker history for this model. Zero was outside the training distribution.
   if(f[6] <= 0.0)
      f[6] = M5_MEDIANS[6];
}

bool M5_ValidateAlignedVector(const double &f[], string &reason)
{
   reason = "OK";
   if(ArraySize(f) != 22)
   {
      reason = StringFormat("feature count=%d, expected=22", ArraySize(f));
      return false;
   }

   for(int i = 0; i < 22; ++i)
   {
      if(!M5_IsUsableNumber(f[i]))
      {
         reason = StringFormat("feature[%d] is invalid", i);
         return false;
      }
   }

   if(f[0] < 0.0 || f[0] > 100.0) { reason = "RSI outside [0,100]"; return false; }
   if(f[5] <= 0.0 || f[5] > 0.10) { reason = "ATR outside expected EURUSD range"; return false; }
   if(f[6] <= 0.0) { reason = "Volume <= 0"; return false; }
   if(f[7] < 0.0 || f[7] > 100.0) { reason = "ADX outside [0,100]"; return false; }
   if(f[9] < -0.001 || f[9] > 100.001) { reason = "Stochastic outside [0,100]"; return false; }
   if(MathAbs(f[10]) > 0.10) { reason = "Momentum has ratio/percent scale instead of price-delta scale"; return false; }
   if(f[11] < -100.001 || f[11] > 0.001) { reason = "Williams_R outside [-100,0]"; return false; }

   // Model schema order: upper, middle, lower.
   if(!(f[14] <= f[13] && f[13] <= f[12]))
   {
      reason = StringFormat("Bollinger order invalid: lower=%.8f middle=%.8f upper=%.8f", f[14], f[13], f[12]);
      return false;
   }

   if(f[15] > f[16]) { reason = "SR_support > SR_resistance"; return false; }
   if(f[17] < -0.001 || f[18] < -0.001) { reason = "negative ATR distance to rolling range"; return false; }
   if(MathAbs(f[19]) > 0.10 || MathAbs(f[20]) > 0.10 || MathAbs(f[21]) > 0.10)
   {
      reason = "Ret_1/3/12 outside price-difference scale";
      return false;
   }

   return true;
}

// Builds exactly one of the two feature contracts:
//  - LEGACY_COMPAT: reproduces V1 wiring, including the historical Momentum
//    ratio and the historical iBands buffer permutation.
//  - TRAINING_ALIGNED: Momentum is Close[1]-Close[15] and iBands is
//    0=middle, 1=upper, 2=lower before schema ordering upper/middle/lower.
bool BuildFeatureVectorForMode(
   const ENUM_M5_FEATURE_MODE mode,
   double &f[],
   double &RSI,
   double &MACD,
   double &MACD_signal,
   double &MACD_hist,
   double &EMA,
   double &ATR,
   double &Volume,
   double &ADX,
   double &CCI,
   double &Stochastic,
   double &Momentum,
   double &Williams_R,
   double &Bollinger_upper,
   double &Bollinger_middle,
   double &Bollinger_lower,
   double &SR_support,
   double &SR_resistance,
   double &Dist_to_support_ATR,
   double &Dist_to_resistance_ATR,
   double &Ret_1,
   double &Ret_3,
   double &Ret_12
)
{
   const int shift = 1; // last closed M5 candle only

   RSI = EMPTY_VALUE;
   MACD = EMPTY_VALUE;
   MACD_signal = EMPTY_VALUE;
   MACD_hist = EMPTY_VALUE;
   EMA = EMPTY_VALUE;
   ATR = EMPTY_VALUE;
   Volume = EMPTY_VALUE;
   ADX = EMPTY_VALUE;
   CCI = EMPTY_VALUE;
   Stochastic = EMPTY_VALUE;
   Momentum = EMPTY_VALUE;
   Williams_R = EMPTY_VALUE;
   Bollinger_upper = EMPTY_VALUE;
   Bollinger_middle = EMPTY_VALUE;
   Bollinger_lower = EMPTY_VALUE;
   SR_support = EMPTY_VALUE;
   SR_resistance = EMPTY_VALUE;
   Dist_to_support_ATR = EMPTY_VALUE;
   Dist_to_resistance_ATR = EMPTY_VALUE;
   Ret_1 = EMPTY_VALUE;
   Ret_3 = EMPTY_VALUE;
   Ret_12 = EMPTY_VALUE;

   if(!CopyOneBufferValue(hRSI,      0, shift, RSI))        return false;
   if(!CopyOneBufferValue(hEMA,      0, shift, EMA))        return false;
   if(!CopyOneBufferValue(hATR,      0, shift, ATR))        return false;
   if(!CopyOneBufferValue(hADX,      0, shift, ADX))        return false;
   if(!CopyOneBufferValue(hCCI,      0, shift, CCI))        return false;
   if(!CopyOneBufferValue(hStoch,    0, shift, Stochastic)) return false;
   if(!CopyOneBufferValue(hWPR,      0, shift, Williams_R)) return false;

   // MQL5 iBands contract: 0=BASE_LINE(middle), 1=UPPER, 2=LOWER.
   double bbMiddleRaw = EMPTY_VALUE;
   double bbUpperRaw  = EMPTY_VALUE;
   double bbLowerRaw  = EMPTY_VALUE;
   if(!CopyOneBufferValue(hBands, 0, shift, bbMiddleRaw)) return false;
   if(!CopyOneBufferValue(hBands, 1, shift, bbUpperRaw))  return false;
   if(!CopyOneBufferValue(hBands, 2, shift, bbLowerRaw))  return false;

   double macdMain[], macdSignal[];
   ArraySetAsSeries(macdMain, true);
   ArraySetAsSeries(macdSignal, true);
   if(CopyBuffer(hMACD, 0, shift, 1, macdMain) < 1)   return false;
   if(CopyBuffer(hMACD, 1, shift, 1, macdSignal) < 1) return false;
   MACD        = macdMain[0];
   MACD_signal = macdSignal[0];
   MACD_hist   = MACD - MACD_signal;

   Volume = (double)iVolume(_Symbol, PERIOD_M5, shift);

   SR_support = DBL_MAX;
   SR_resistance = -DBL_MAX;
   for(int i = shift; i < shift + InpSRLookbackBars; ++i)
   {
      double lo = iLow(_Symbol, PERIOD_M5, i);
      double hi = iHigh(_Symbol, PERIOD_M5, i);
      if(lo != 0.0 && lo < SR_support) SR_support = lo;
      if(hi != 0.0 && hi > SR_resistance) SR_resistance = hi;
   }
   if(SR_support == DBL_MAX || SR_resistance == -DBL_MAX)
      return false;

   double close1 = 0.0, close2 = 0.0, close4 = 0.0, close13 = 0.0;
   if(!GetClosePrice(1, close1))   return false;
   if(!GetClosePrice(2, close2))   return false;
   if(!GetClosePrice(4, close4))   return false;
   if(!GetClosePrice(13, close13)) return false;

   if(ATR <= 0.0)
      return false;

   Dist_to_support_ATR    = (close1 - SR_support) / ATR;
   Dist_to_resistance_ATR = (SR_resistance - close1) / ATR;

   Ret_1  = close1 - close2;
   Ret_3  = close1 - close4;
   Ret_12 = close1 - close13;

   if(mode == M5_FEATURE_LEGACY_COMPAT)
   {
      // Historical V1 behavior kept only for regression/backtest parity.
      if(!CopyOneBufferValue(hMomentum, 0, shift, Momentum)) return false;
      Bollinger_upper  = bbMiddleRaw;
      Bollinger_lower  = bbUpperRaw;
      Bollinger_middle = bbLowerRaw;
   }
   else
   {
      double close15 = 0.0;
      if(!GetClosePrice(15, close15)) return false;
      Momentum = close1 - close15; // 14-bar price delta; model thresholds are around +/-0.005.
      Bollinger_upper  = bbUpperRaw;
      Bollinger_middle = bbMiddleRaw;
      Bollinger_lower  = bbLowerRaw;
   }

   M5_BuildFeatureVectorFromServerStyle(
      RSI, MACD, MACD_signal, MACD_hist, EMA, ATR, Volume, ADX, CCI,
      Stochastic, Momentum, Williams_R,
      Bollinger_upper, Bollinger_middle, Bollinger_lower,
      SR_support, SR_resistance,
      Dist_to_support_ATR, Dist_to_resistance_ATR,
      Ret_1, Ret_3, Ret_12,
      f
   );

   if(mode == M5_FEATURE_LEGACY_COMPAT)
   {
      M5_ApplyMedians(f);
   }
   else
   {
      M5_ApplyAlignedMissingPolicy(f);
      string validationReason = "";
      if(!M5_ValidateAlignedVector(f, validationReason))
      {
         if(InpM5FeatureSanityLog)
            PrintFormat("FEATURE_SANITY_REJECT | mode=%s | %s", M5_FeatureModeName(mode), validationReason);
         return false;
      }
   }

   return true;
}

// Compatibility wrapper used by the original V1 call site.
bool BuildFeatureVector(
   double &f[],
   double &RSI,
   double &MACD,
   double &MACD_signal,
   double &MACD_hist,
   double &EMA,
   double &ATR,
   double &Volume,
   double &ADX,
   double &CCI,
   double &Stochastic,
   double &Momentum,
   double &Williams_R,
   double &Bollinger_upper,
   double &Bollinger_middle,
   double &Bollinger_lower,
   double &SR_support,
   double &SR_resistance,
   double &Dist_to_support_ATR,
   double &Dist_to_resistance_ATR,
   double &Ret_1,
   double &Ret_3,
   double &Ret_12
)
{
   return BuildFeatureVectorForMode(
      InpM5FeatureMode,
      f,
      RSI, MACD, MACD_signal, MACD_hist, EMA, ATR, Volume, ADX, CCI,
      Stochastic, Momentum, Williams_R,
      Bollinger_upper, Bollinger_middle, Bollinger_lower,
      SR_support, SR_resistance,
      Dist_to_support_ATR, Dist_to_resistance_ATR,
      Ret_1, Ret_3, Ret_12
   );
}

// Shadow parity logger. It never opens, blocks, modifies or closes a trade.
void LogM5FeatureModeComparison(const double &activeF[],
                                const int activeDecision,
                                const double activePSell,
                                const double activePHold,
                                const double activePBuy,
                                const double activeRegPred)
{
   if(!InpM5FeatureShadowCompare || ArraySize(activeF) < 22)
      return;

   ENUM_M5_FEATURE_MODE altMode = M5_FEATURE_LEGACY_COMPAT;
   if(InpM5FeatureMode == M5_FEATURE_LEGACY_COMPAT)
      altMode = M5_FEATURE_TRAINING_ALIGNED;

   double altF[];
   double rsi, macd, macdSignal, macdHist, ema, atr, volume, adx, cci;
   double stochastic, momentum, wpr;
   double bbUpper, bbMiddle, bbLower;
   double srSupport, srResistance, distSupport, distResistance;
   double ret1, ret3, ret12;

   if(!BuildFeatureVectorForMode(
         altMode,
         altF,
         rsi, macd, macdSignal, macdHist, ema, atr, volume, adx, cci,
         stochastic, momentum, wpr,
         bbUpper, bbMiddle, bbLower,
         srSupport, srResistance,
         distSupport, distResistance,
         ret1, ret3, ret12))
   {
      PrintFormat("FEATURE_SHADOW_FAIL | active=%s alt=%s",
                  M5_FeatureModeName(InpM5FeatureMode), M5_FeatureModeName(altMode));
      return;
   }

   double altPSell = 0.0, altPHold = 0.0, altPBuy = 0.0;
   int altDecision = 1;
   M5_SelectedClassifierPredict(altF, altPSell, altPHold, altPBuy, altDecision);
   double altRegPred = 0.0;
   if(InpUseRegressorLog)
      altRegPred = M5_RegressorPredict(altF);

   double legacyF[];
   double alignedF[];
   ArrayResize(legacyF, 22);
   ArrayResize(alignedF, 22);
   if(InpM5FeatureMode == M5_FEATURE_LEGACY_COMPAT)
   {
      ArrayCopy(legacyF, activeF, 0, 0, 22);
      ArrayCopy(alignedF, altF, 0, 0, 22);
   }
   else
   {
      ArrayCopy(alignedF, activeF, 0, 0, 22);
      ArrayCopy(legacyF, altF, 0, 0, 22);
   }

   int changed = 0;
   for(int i = 0; i < 22; ++i)
   {
      if(MathAbs(legacyF[i] - alignedF[i]) > 1.0e-12)
         ++changed;
   }

   double legacyPSell, legacyPHold, legacyPBuy, legacyReg;
   double alignedPSell, alignedPHold, alignedPBuy, alignedReg;
   int legacyDecision, alignedDecision;

   if(InpM5FeatureMode == M5_FEATURE_LEGACY_COMPAT)
   {
      legacyPSell=activePSell; legacyPHold=activePHold; legacyPBuy=activePBuy; legacyReg=activeRegPred; legacyDecision=activeDecision;
      alignedPSell=altPSell; alignedPHold=altPHold; alignedPBuy=altPBuy; alignedReg=altRegPred; alignedDecision=altDecision;
   }
   else
   {
      alignedPSell=activePSell; alignedPHold=activePHold; alignedPBuy=activePBuy; alignedReg=activeRegPred; alignedDecision=activeDecision;
      legacyPSell=altPSell; legacyPHold=altPHold; legacyPBuy=altPBuy; legacyReg=altRegPred; legacyDecision=altDecision;
   }

   PrintFormat(
      "FEATURE_SHADOW | changed=%d | legacy=%s pS=%.5f pH=%.5f pB=%.5f reg=%.5f | aligned=%s pS=%.5f pH=%.5f pB=%.5f reg=%.5f | "
      "Momentum legacy=%.8f aligned=%.8f | BB legacy(U/M/L)=%.5f/%.5f/%.5f aligned(U/M/L)=%.5f/%.5f/%.5f",
      changed,
      M5_DecisionName(legacyDecision), legacyPSell, legacyPHold, legacyPBuy, legacyReg,
      M5_DecisionName(alignedDecision), alignedPSell, alignedPHold, alignedPBuy, alignedReg,
      legacyF[10], alignedF[10],
      legacyF[12], legacyF[13], legacyF[14],
      alignedF[12], alignedF[13], alignedF[14]
   );
}

//+------------------------------------------------------------------+
//| PrintMLInputs
//| Printează feature-urile și scorurile ML pentru debug/backtest.
//+------------------------------------------------------------------+
void PrintMLInputs(
   int decision,
   double pSell,
   double pHold,
   double pBuy,
   double regPred,
   double RSI,
   double MACD,
   double MACD_signal,
   double MACD_hist,
   double EMA,
   double ATR,
   double Volume,
   double ADX,
   double CCI,
   double Stochastic,
   double Momentum,
   double Williams_R,
   double Bollinger_upper,
   double Bollinger_middle,
   double Bollinger_lower,
   double SR_support,
   double SR_resistance,
   double Dist_to_support_ATR,
   double Dist_to_resistance_ATR,
   double Ret_1,
   double Ret_3,
   double Ret_12
)
{
   string decisionText = "HOLD";
   if(decision == 0) decisionText = "SELL";
   if(decision == 2) decisionText = "BUY";

   PrintFormat(
      "ML INPUTS | decision=%s | pSell=%.5f pHold=%.5f pBuy=%.5f reg=%.5f | "
      "RSI=%.5f MACD=%.5f MACDsig=%.5f MACDhist=%.5f EMA=%.5f ATR=%.5f Vol=%.0f ADX=%.5f CCI=%.5f Stoch=%.5f Mom=%.5f WPR=%.5f | "
      "BBup=%.5f BBmid=%.5f BBlow=%.5f | "
      "SRsup=%.5f SRres=%.5f DistSupATR=%.5f DistResATR=%.5f | "
      "Ret1=%.5f Ret3=%.5f Ret12=%.5f",
      decisionText,
      pSell, pHold, pBuy, regPred,
      RSI, MACD, MACD_signal, MACD_hist, EMA, ATR, Volume, ADX, CCI, Stochastic, Momentum, Williams_R,
      Bollinger_upper, Bollinger_middle, Bollinger_lower,
      SR_support, SR_resistance, Dist_to_support_ATR, Dist_to_resistance_ATR,
      Ret_1, Ret_3, Ret_12
   );
}

//------------------------------------------------------------------//
//+------------------------------------------------------------------+
//| NormalizeLotsToSymbol
//| Normalizează volumul astfel încât să respecte min/max/step ale simbolului.
//+------------------------------------------------------------------+
double NormalizeLotsToSymbol(double lots)
{
   const double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   const double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   const double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(!MathIsValidNumber(lots) || lots <= 0.0 ||
      minLot <= 0.0 || maxLot <= 0.0 || stepLot <= 0.0)
      return 0.0;

   const double epsilon = MathMax(0.0000001, stepLot * 0.0001);
   if(lots < minLot - epsilon || lots > maxLot + epsilon)
      return 0.0;

   lots = MathFloor((lots + epsilon) / stepLot) * stepLot;

   int volDigits = 2;
   if(stepLot >= 1.0) volDigits = 0;
   else if(stepLot >= 0.1) volDigits = 1;
   else if(stepLot >= 0.01) volDigits = 2;
   else if(stepLot >= 0.001) volDigits = 3;
   else volDigits = 4;

   lots = NormalizeDouble(lots, volDigits);
   if(lots < minLot - epsilon || lots > maxLot + epsilon)
      return 0.0;
   return lots;
}

//+------------------------------------------------------------------+
//| ValidateOrderLotSafety
//| Checks the effective FULL/REDUCED lot immediately before send.
//+------------------------------------------------------------------+
bool ValidateOrderLotSafety(const ENUM_ORDER_TYPE orderType,
                            const double lots,
                            const double price,
                            string &reason)
{
   reason = "";

   const double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   const double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   if(lots <= 0.0 || minLot <= 0.0 || maxLot <= 0.0)
   {
      reason = StringFormat("invalid effective lot %.4f or broker volume specification", lots);
      return false;
   }

   if(lots < minLot - 0.0000001 || lots > maxLot + 0.0000001)
   {
      reason = StringFormat("effective lot %.4f outside broker range [%.4f, %.4f]",
                            lots, minLot, maxLot);
      return false;
   }

   if(!InpLotSafetyEnable)
      return true;

   if(InpLotSafetyAbsoluteMaxLots > 0.0 &&
      lots > InpLotSafetyAbsoluteMaxLots + 0.0000001)
   {
      reason = StringFormat("effective lot %.4f exceeds configured hard maximum %.4f",
                            lots, InpLotSafetyAbsoluteMaxLots);
      return false;
   }

   if(price <= 0.0)
   {
      reason = "invalid market price for margin calculation";
      return false;
   }

   double requiredMargin = 0.0;
   ResetLastError();
   if(!OrderCalcMargin(orderType, _Symbol, lots, price, requiredMargin) ||
      !MathIsValidNumber(requiredMargin) || requiredMargin < 0.0)
   {
      reason = StringFormat("OrderCalcMargin failed for %.2f lots err=%d",
                            lots, GetLastError());
      return false;
   }

   const double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(!MathIsValidNumber(freeMargin) || freeMargin <= 0.0)
   {
      reason = StringFormat("free margin invalid or unavailable: %.2f", freeMargin);
      return false;
   }

   const double usagePct =
      MathMax(1.0, MathMin(100.0, InpLotSafetyMaxMarginUsagePct));
   const double reserve =
      MathMax(0.0, InpLotSafetyMinFreeMarginAfterOpen);
   const double allowedByPct = freeMargin * usagePct / 100.0;
   const double allowedByReserve = freeMargin - reserve;
   const double allowedMargin = MathMin(allowedByPct, allowedByReserve);

   if(allowedMargin <= 0.0 || requiredMargin > allowedMargin + 0.01)
   {
      reason = StringFormat("lot %.2f requires margin %.2f; free=%.2f allowed=%.2f "
                            "(maxUsage=%.1f%% reserve=%.2f). Lower Lot Size in GUI.",
                            lots, requiredMargin, freeMargin, MathMax(0.0, allowedMargin),
                            usagePct, reserve);
      return false;
   }

   if(InpLotSafetyLog)
   {
      PrintFormat("LOT SAFETY PASS | type=%s lots=%.2f requiredMargin=%.2f freeMargin=%.2f "
                  "remaining=%.2f usage=%.1f%%",
                  EnumToString(orderType), lots, requiredMargin, freeMargin,
                  freeMargin - requiredMargin,
                  100.0 * requiredMargin / freeMargin);
   }
   return true;
}
//------------------------------------------------------------------//
//+------------------------------------------------------------------+
//| FindTakeProfitPriceByMoney
//| Calculează prețul de Take Profit necesar pentru ținta în bani.
//+------------------------------------------------------------------+
double FindTakeProfitPriceByMoney(ENUM_ORDER_TYPE orderType, double lots, double entryPrice, double targetMoney)
{
   if(targetMoney <= 0.0)
      return 0.0;

   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickSize <= 0.0)
      tickSize = _Point;

   double low = entryPrice;
   double high = entryPrice;

   // Expand search interval until profit exceeds target
   for(int i = 0; i < 200; i++)
   {
      double probe = 0.0;
      if(orderType == ORDER_TYPE_BUY)
      {
         high += tickSize * 50.0;
         probe = high;
      }
      else
      {
         low -= tickSize * 50.0;
         probe = low;
      }

      double profit = 0.0;
      if(OrderCalcProfit(orderType, _Symbol, lots, entryPrice, probe, profit))
      {
         if(profit >= targetMoney)
            break;
      }
   }

   // Binary search
   double left, right;
   if(orderType == ORDER_TYPE_BUY)
   {
      left  = entryPrice;
      right = high;
   }
   else
   {
      left  = low;
      right = entryPrice;
   }

   for(int i = 0; i < 60; i++)
   {
      double mid = 0.5 * (left + right);
      double profit = 0.0;

      if(!OrderCalcProfit(orderType, _Symbol, lots, entryPrice, mid, profit))
         break;

      if(orderType == ORDER_TYPE_BUY)
      {
         if(profit >= targetMoney) right = mid;
         else                      left  = mid;
      }
      else
      {
         if(profit >= targetMoney) left  = mid;
         else                      right = mid;
      }
   }

   double result = (orderType == ORDER_TYPE_BUY) ? right : left;
   return NormalizeDouble(result, _Digits);
}


//+------------------------------------------------------------------+
//| PassesMLConfidenceFilter
//| Verifică pragurile de încredere ML înainte de execuția ordinului.
//+------------------------------------------------------------------+
bool PassesMLConfidenceFilter(
   int decision,
   double pSell,
   double pHold,
   double pBuy,
   double &chosenProb,
   double &secondProb,
   double &decisionGap,
   string &reason
)
{
   chosenProb = 0.0;
   secondProb = 0.0;
   decisionGap = 0.0;
   reason = "";

   // decision assumed: 0=SELL, 1=HOLD, 2=BUY
   if(decision == 2) // BUY
   {
      chosenProb = pBuy;
      secondProb = MathMax(pSell, pHold);
      decisionGap = chosenProb - secondProb;

      if(chosenProb < g_runtimeMinBuyProb)
      {
         reason = StringFormat("BUY rejected: pBuy=%.5f < g_runtimeMinBuyProb=%.5f",
                               chosenProb, g_runtimeMinBuyProb);
         return false;
      }

      if(decisionGap < g_runtimeMinDecisionGap)
      {
         reason = StringFormat("BUY rejected: gap=%.5f < g_runtimeMinDecisionGap=%.5f",
                               decisionGap, g_runtimeMinDecisionGap);
         return false;
      }

      reason = StringFormat("BUY accepted: pBuy=%.5f gap=%.5f", chosenProb, decisionGap);
      return true;
   }
   else if(decision == 0) // SELL
   {
      chosenProb = pSell;
      secondProb = MathMax(pBuy, pHold);
      decisionGap = chosenProb - secondProb;

      if(chosenProb < g_runtimeMinSellProb)
      {
         reason = StringFormat("SELL rejected: pSell=%.5f < g_runtimeMinSellProb=%.5f",
                               chosenProb, g_runtimeMinSellProb);
         return false;
      }

      if(decisionGap < g_runtimeMinDecisionGap)
      {
         reason = StringFormat("SELL rejected: gap=%.5f < g_runtimeMinDecisionGap=%.5f",
                               decisionGap, g_runtimeMinDecisionGap);
         return false;
      }

      reason = StringFormat("SELL accepted: pSell=%.5f gap=%.5f", chosenProb, decisionGap);
      return true;
   }

   reason = "HOLD decision";
   return false;
}



//------------------------------------------------------------------//
//+------------------------------------------------------------------+
//| OpenTradeFromDecision
//| Deschide ordinul BUY/SELL rezultat din decizia ML, cu SL/TP calculate.
//+------------------------------------------------------------------+
bool OpenTradeFromDecision(
   int decision,
   double pSell,
   double pHold,
   double pBuy,
   double regPred,
   double RSI,
   double MACD_hist,
   double ATR,
   double ADX,
   double CCI,
   double Stochastic,
   double Williams_R,
   double Dist_to_support_ATR,
   double Dist_to_resistance_ATR,
   double Ret_3,
   double Ret_12,
   double lotMultiplier,
   double tpMoneyMultiplier,
   bool usePreclassifiedDynamicSL,
   DynamicSLSetupType preclassifiedDynamicSLSetup,
   string preclassifiedDynamicSLReason,
   bool scalperMode,
   double fixedSLOverridePips,
   double tpMoneyOverride
)
{
   if(!g_runtimeAllowNewTrades)
   {
      Print("ML skip: new trades disabled from panel.");
      return false;
   }

   if(InpOnlyOnePosition && HasOpenPositionOnSymbol())
   {
      Print("ML skip: already open position on symbol.");
      return false;
   }

   double lots = NormalizeLotsToSymbol(g_runtimeLots * MathMax(0.0, lotMultiplier));
   if(lots <= 0.0)
   {
      Print("Invalid lots after normalization.");
      return false;
   }

   double pip = PipSize();
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(ask <= 0.0 || bid <= 0.0)
   {
      Print("Invalid market prices.");
      return false;
   }

   if(decision == 2 || decision == 0)
   {
      const ENUM_ORDER_TYPE safetyOrderType =
         (decision == 2 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL);
      const double safetyPrice = (decision == 2 ? ask : bid);
      string lotSafetyReason = "";
      if(!ValidateOrderLotSafety(safetyOrderType, lots, safetyPrice, lotSafetyReason))
      {
         PrintFormat("LOT SAFETY BLOCK | decision=%d runtimeBase=%.2f multiplier=%.4f effective=%.2f reason=%s",
                     decision, g_runtimeLots, lotMultiplier, lots, lotSafetyReason);
         return false;
      }
   }

   double spreadPips = (ask - bid) / pip;
   if(g_runtimeUseMaxSpreadFilter && spreadPips > g_runtimeMaxSpreadPips)
   {
      PrintFormat("Spread filter skip: spread=%.2f pips > max=%.2f pips",
                  spreadPips, g_runtimeMaxSpreadPips);
      return false;
   }

   double chosenProb = 0.0;
   double secondProb = 0.0;
   double gap = 0.0;
   double ret3ATR = 0.0;
   double ret12ATR = 0.0;
   double macdHistATR = 0.0;
   string dynReason = "";
   double closePrice = iClose(_Symbol, PERIOD_M5, 1);
   //double EMA = iMA(_Symbol, PERIOD_M5, 20, 0, MODE_EMA, PRICE_CLOSE, 1);

   DynamicSLSetupType setupType = DYN_SL_NORMAL;
   if(usePreclassifiedDynamicSL)
   {
      setupType = preclassifiedDynamicSLSetup;
      dynReason = preclassifiedDynamicSLReason;
   }
   else
   {
      setupType = ClassifyDynamicSLSetup(
         decision,
         pSell,
         pHold,
         pBuy,
         closePrice,
         RSI,
         MACD_hist,
         ATR,
         ADX,
         CCI,
         Stochastic,
         Williams_R,
         Dist_to_support_ATR,
         Dist_to_resistance_ATR,
         Ret_3,
         Ret_12,
         chosenProb,
         secondProb,
         gap,
         ret3ATR,
         ret12ATR,
         macdHistATR,
         dynReason
      );
   }

   if(InpLogDynamicSLDetails)
      Print("DynamicSL classify | ", dynReason);

   if(!scalperMode && InpUseDynamicSL && InpSkipUnsafeDynamicSLTrades &&
      setupType == DYN_SL_UNSAFE)
   {
      Print("DynamicSL skip trade: setup classified as UNSAFE.");
      return false;
   }

   double finalSLPips = (fixedSLOverridePips > 0.0 ? fixedSLOverridePips :
                         ResolveDynamicSLPips(setupType));

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpDeviationPoints);

   bool ok = false;

   if(decision == 2 && g_runtimeAllowBuy)
   {
      double entry = ask;
      double sl    = NormalizeDouble(entry - finalSLPips * pip, _Digits);
      double tpMoney = (tpMoneyOverride > 0.0 ? tpMoneyOverride :
                        g_runtimeTakeProfitMoney * MathMax(0.0, tpMoneyMultiplier));
      double tp    = FindTakeProfitPriceByMoney(ORDER_TYPE_BUY, lots, entry, tpMoney);

      PrintFormat("ML BUY | pSell=%.5f pHold=%.5f pBuy=%.5f reg=%.5f | setupType=%d | slPips=%.2f | lots=%.2f tpMoney=%.2f | entry=%.5f sl=%.5f tp=%.5f",
                  pSell, pHold, pBuy, regPred, (int)setupType, finalSLPips, lots, tpMoney, entry, sl, tp);

      ok = trade.Buy(lots, _Symbol, 0.0, sl, tp,
                     (scalperMode ? "ML_M5_SCALP_BUY" : "ML_M5_TEST_BUY"));
      if(!ok)
         PrintFormat("BUY failed. Retcode=%d | %s", trade.ResultRetcode(), trade.ResultRetcodeDescription());
   }
   else if(decision == 0 && g_runtimeAllowSell)
   {
      double entry = bid;
      double sl    = NormalizeDouble(entry + finalSLPips * pip, _Digits);
      double tpMoney = (tpMoneyOverride > 0.0 ? tpMoneyOverride :
                        g_runtimeTakeProfitMoney * MathMax(0.0, tpMoneyMultiplier));
      double tp    = FindTakeProfitPriceByMoney(ORDER_TYPE_SELL, lots, entry, tpMoney);

      PrintFormat("ML SELL | pSell=%.5f pHold=%.5f pBuy=%.5f reg=%.5f | setupType=%d | slPips=%.2f | lots=%.2f tpMoney=%.2f | entry=%.5f sl=%.5f tp=%.5f",
                  pSell, pHold, pBuy, regPred, (int)setupType, finalSLPips, lots, tpMoney, entry, sl, tp);

      ok = trade.Sell(lots, _Symbol, 0.0, sl, tp,
                      (scalperMode ? "ML_M5_SCALP_SELL" : "ML_M5_TEST_SELL"));
      if(!ok)
         PrintFormat("SELL failed. Retcode=%d | %s", trade.ResultRetcode(), trade.ResultRetcodeDescription());
   }
   else
   {
      PrintFormat("ML HOLD/SKIP | decision=%d | pSell=%.5f pHold=%.5f pBuy=%.5f reg=%.5f",
                  decision, pSell, pHold, pBuy, regPred);
   }

   return ok;
}

#endif // __EA_ML_M5_ML_MQH__
