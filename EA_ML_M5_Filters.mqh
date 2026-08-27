//+------------------------------------------------------------------+
//| EA_ML_M5_Filters.mqh                                            |
//| Filtre, reclasificări și clasificări de setup pentru strategie.  |
//| ATENȚIE: corpul funcțiilor este păstrat ca în fișierul anterior; |
//| aici sunt adăugate doar descrieri, organizare și include guard.  |
//+------------------------------------------------------------------+

#ifndef __EA_ML_M5_FILTERS_MQH__
#define __EA_ML_M5_FILTERS_MQH__


//+------------------------------------------------------------------+
//| Runtime memory for Repeat Wide SL BUY After Fast TP Filter
//+------------------------------------------------------------------+
datetime g_lastBuyEntryTimeForRepeatFilter = 0;
datetime g_lastFastBuyTPCloseTime          = 0;
bool     g_lastBuyClosedFastTP             = false;
ulong    g_lastBuyPositionIdForRepeatFilter = 0;

//+------------------------------------------------------------------+
//| IsRepeatFilterTPCloseDeal
//| Detectează închiderea pe TP folosind DEAL_REASON când este disponibil
//| și comment-ul ca fallback pentru tester / brokeri diferiți.
//+------------------------------------------------------------------+
bool IsRepeatFilterTPCloseDeal(const ulong dealTicket)
{
   long reason = HistoryDealGetInteger(dealTicket, DEAL_REASON);
   if(reason == DEAL_REASON_TP)
      return true;

   string comment = HistoryDealGetString(dealTicket, DEAL_COMMENT);
   if(StringFind(comment, "tp") >= 0 || StringFind(comment, "TP") >= 0)
      return true;

   return false;
}

//+------------------------------------------------------------------+
//| RegisterRepeatFilterBuyEntry
//| Salvează intrarea BUY care poate deveni ulterior Fast BUY TP.
//+------------------------------------------------------------------+
void RegisterRepeatFilterBuyEntry(const datetime entryTime,
                                  const ulong positionId)
{
   g_lastBuyEntryTimeForRepeatFilter  = entryTime;
   g_lastBuyPositionIdForRepeatFilter = positionId;
}

//+------------------------------------------------------------------+
//| RegisterRepeatFilterBuyClose
//| Marchează Fast BUY TP dacă poziția BUY s-a închis pe TP foarte rapid.
//+------------------------------------------------------------------+
void RegisterRepeatFilterBuyClose(const datetime closeTime,
                                  const ulong positionId,
                                  const bool closedByTP)
{
   if(!closedByTP)
      return;

   if(g_lastBuyEntryTimeForRepeatFilter <= 0)
      return;

   // Dacă avem position id valid, nu amestecăm intrări / ieșiri diferite.
   if(positionId > 0 &&
      g_lastBuyPositionIdForRepeatFilter > 0 &&
      positionId != g_lastBuyPositionIdForRepeatFilter)
   {
      return;
   }

   int secondsFromEntry = (int)(closeTime - g_lastBuyEntryTimeForRepeatFilter);

   if(secondsFromEntry >= 0 &&
      secondsFromEntry <= InpDynSL_MaxMinutesForFastBuyTP * 60)
   {
      g_lastFastBuyTPCloseTime = closeTime;
      g_lastBuyClosedFastTP    = true;

      if(InpDynSL_LogRepeatWideSLBuyAfterFastTPReclassify)
      {
         PrintFormat(
            "RepeatWideSLBuyAfterFastTP memory updated | BUY fast TP detected | entry=%s close=%s seconds=%d positionId=%I64u",
            TimeToString(g_lastBuyEntryTimeForRepeatFilter, TIME_DATE|TIME_MINUTES|TIME_SECONDS),
            TimeToString(closeTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS),
            secondsFromEntry,
            positionId
         );
      }
   }
}



bool ShouldReclassifyExtremeOversoldFalseWideBuyToUnsafe(
   int decision,
   double chosenProb,
   double gap,
   double ADX,
   double CCI,
   double Williams_R,
   double MACD_hist,
   double Dist_to_support_ATR,
   double slPips,
   string &reason
)
{
   reason = "";

   if(!InpDynSL_XOFW_Enable)
      return false;

   if(decision != 2) // BUY only
      return false;

   bool badBuy =
      chosenProb <= InpDynSL_XOFW_MaxProb &&
      gap <= InpDynSL_XOFW_MaxGap &&
      slPips >= InpDynSL_XOFW_MinSL &&
      ADX <= InpDynSL_XOFW_MaxADX &&
      CCI <= InpDynSL_XOFW_MaxCCI &&
      Williams_R <= InpDynSL_XOFW_MaxWPR &&
      Dist_to_support_ATR <= InpDynSL_XOFW_MaxDistSup &&
      ((!InpDynSL_XOFW_RequireMACDHistNeg) || MACD_hist < 0.0);

   if(!badBuy)
      return false;

   reason = StringFormat(
      "EXTREME_OVERSOLD_FALSE_REVERSAL_WIDE_SL_BUY->UNSAFE | p=%.5f gap=%.5f ADX=%.2f CCI=%.2f WPR=%.2f MACDhist=%.5f DistSupATR=%.2f slPips=%.2f",
      chosenProb, gap, ADX, CCI, Williams_R, MACD_hist, Dist_to_support_ATR, slPips
   );

   return true;
}


//+------------------------------------------------------------------+
//| ShouldReclassifyBearishContinuationNormalWideBuyToUnsafe
//| Blocks normal-looking BUY entries where bearish pressure is still
//| active after a weak bounce near support.
//+------------------------------------------------------------------+
bool ShouldReclassifyBearishContinuationNormalWideBuyToUnsafe(
   int decision,
   double chosenProb,
   double gap,
   double ADX,
   double CCI,
   double Stochastic,
   double Williams_R,
   double MACD_hist,
   double Dist_to_support_ATR,
   double Ret_12,
   double ATR,
   double slPips,
   string &reason
)
{
   reason = "";

   if(!InpDynSL_BCNW_Enable)
      return false;

   if(decision != 2) // BUY only
      return false;

   double bearishRet12ATR = -SafeDiv(Ret_12, ATR);

   bool badBuy =
      chosenProb <= InpDynSL_BCNW_MaxProb &&
      gap <= InpDynSL_BCNW_MaxGap &&
      slPips >= InpDynSL_BCNW_MinSL &&
      ADX <= InpDynSL_BCNW_MaxADX &&
      CCI <= InpDynSL_BCNW_MaxCCI &&
      Williams_R <= InpDynSL_BCNW_MaxWPR &&
      Stochastic <= InpDynSL_BCNW_MaxStoch &&
      Dist_to_support_ATR <= InpDynSL_BCNW_MaxDistSup &&
      bearishRet12ATR >= InpDynSL_BCNW_MinBearishRet12ATR &&
      ((!InpDynSL_BCNW_RequireMACDHistNeg) || MACD_hist < 0.0);

   if(!badBuy)
      return false;

   reason = StringFormat(
      "BEARISH_CONTINUATION_NORMAL_WIDE_SL_BUY->UNSAFE | p=%.5f gap=%.5f ADX=%.2f CCI=%.2f Stoch=%.2f WPR=%.2f MACDhist=%.5f DistSupATR=%.2f bearishRet12ATR=%.2f slPips=%.2f",
      chosenProb, gap, ADX, CCI, Stochastic, Williams_R, MACD_hist, Dist_to_support_ATR, bearishRet12ATR, slPips
   );

   return true;
}


//+------------------------------------------------------------------+
//| ShouldReclassifyLateSessionWeakWideSLBuyToUnsafe
//| Blocks weak late-session BUY entries that need a wide SL while
//| bearish pressure is still active.
//+------------------------------------------------------------------+
bool ShouldReclassifyLateSessionWeakWideSLBuyToUnsafe(
   int decision,
   double chosenProb,
   double gap,
   double ADX,
   double CCI,
   double Stochastic,
   double Williams_R,
   double MACD_hist,
   double Dist_to_support_ATR,
   double Ret_12,
   double ATR,
   double slPips,
   datetime nowTime,
   string &reason
)
{
   reason = "";

   if(!InpDynSL_EnableLateSessionWeakWideSLBuyFilter)
      return false;

   if(decision != 2) // BUY only
      return false;

   MqlDateTime dt;
   TimeToStruct(nowTime, dt);

   double bearishRet12ATR = -SafeDiv(Ret_12, ATR);

   bool lateSession =
      (dt.hour >= InpDynSL_LateSessionWeakWideSLBuyStartHour);

   bool badBuy =
      lateSession &&
      chosenProb <= InpDynSL_MaxChosenProbForLateSessionWeakWideSLBuy &&
      gap <= InpDynSL_MaxGapForLateSessionWeakWideSLBuy &&
      slPips >= InpDynSL_MinSLPipsForLateSessionWeakWideSLBuy &&
      ADX <= InpDynSL_MaxADXForLateSessionWeakWideSLBuy &&
      CCI <= InpDynSL_MaxCCIForLateSessionWeakWideSLBuy &&
      Stochastic <= InpDynSL_MaxStochForLateSessionWeakWideSLBuy &&
      Williams_R <= InpDynSL_MaxWPRForLateSessionWeakWideSLBuy &&
      Dist_to_support_ATR >= InpDynSL_MinDistSupATRForLateSessionWeakWideSLBuy &&
      bearishRet12ATR >= InpDynSL_MinBearishRet12ATRForLateSessionWeakWideSLBuy &&
      ((!InpDynSL_RequireMACDHistNegForLateSessionWeakWideSLBuy) || MACD_hist < 0.0);

   if(!badBuy)
      return false;

   reason = StringFormat(
      "LATE_SESSION_WEAK_WIDE_SL_BUY->UNSAFE | hour=%d p=%.5f gap=%.5f ADX=%.2f CCI=%.2f Stoch=%.2f WPR=%.2f MACDhist=%.5f DistSupATR=%.2f bearishRet12ATR=%.2f slPips=%.2f",
      dt.hour, chosenProb, gap, ADX, CCI, Stochastic, Williams_R, MACD_hist, Dist_to_support_ATR, bearishRet12ATR, slPips
   );

   return true;
}

//+------------------------------------------------------------------+
//| ShouldReclassifyWeakLateBullishBreakoutWideSLBuyToUnsafe
//+------------------------------------------------------------------+
bool ShouldReclassifyWeakLateBullishBreakoutWideSLBuyToUnsafe(
   int decision,
   double chosenProb,
   double gap,
   double ADX,
   double CCI,
   double MACD_hist,
   double Dist_to_support_ATR,
   double Ret_3,
   double Ret_12,
   double slPips,
   string &reason
)
{
   reason = "";

   if(!InpDynSL_EnableWeakLateBullishBreakoutWideSLBuyFilter)
      return false;

   if(decision != 2) // BUY only
      return false;

   bool weakProbability =
      chosenProb <= InpDynSL_MaxChosenProbForWeakLateBullishBreakoutWideSLBuy;

   bool weakGap =
      gap <= InpDynSL_MaxGapForWeakLateBullishBreakoutWideSLBuy;

   bool wideSL =
      slPips >= InpDynSL_MinSLPipsForWeakLateBullishBreakoutWideSLBuy;

   bool highCCI =
      CCI >= InpDynSL_MinCCIForWeakLateBullishBreakoutWideSLBuy;

   bool adxInRange =
      ADX >= InpDynSL_MinADXForWeakLateBullishBreakoutWideSLBuy &&
      ADX <= InpDynSL_MaxADXForWeakLateBullishBreakoutWideSLBuy;

   bool farFromSupport =
      Dist_to_support_ATR >= InpDynSL_MinDistSupATRForWeakLateBullishBreakoutWideSLBuy;

   bool weakRet3 =
      Ret_3 <= InpDynSL_MaxRet3ForWeakLateBullishBreakoutWideSLBuy;

   bool weakRet12 =
      Ret_12 <= InpDynSL_MaxRet12ForWeakLateBullishBreakoutWideSLBuy;

   bool bullishMACD =
      (!InpDynSL_RequireMACDHistPosForWeakLateBullishBreakoutWideSLBuy) ||
      (MACD_hist > 0.0);

   bool badBuy =
      weakProbability &&
      weakGap &&
      wideSL &&
      highCCI &&
      adxInRange &&
      farFromSupport &&
      weakRet3 &&
      weakRet12 &&
      bullishMACD;

   if(badBuy)
   {
      reason = StringFormat(
         "WEAK_LATE_BULLISH_BREAKOUT_WIDE_SL_BUY->UNSAFE | p=%.5f maxP=%.5f gap=%.5f maxGap=%.5f ADX=%.2f minADX=%.2f maxADX=%.2f CCI=%.2f minCCI=%.2f MACDhist=%.5f DistSupATR=%.2f minDistSup=%.2f Ret3=%.5f maxRet3=%.5f Ret12=%.5f maxRet12=%.5f slPips=%.2f minSL=%.2f",
         chosenProb,
         InpDynSL_MaxChosenProbForWeakLateBullishBreakoutWideSLBuy,
         gap,
         InpDynSL_MaxGapForWeakLateBullishBreakoutWideSLBuy,
         ADX,
         InpDynSL_MinADXForWeakLateBullishBreakoutWideSLBuy,
         InpDynSL_MaxADXForWeakLateBullishBreakoutWideSLBuy,
         CCI,
         InpDynSL_MinCCIForWeakLateBullishBreakoutWideSLBuy,
         MACD_hist,
         Dist_to_support_ATR,
         InpDynSL_MinDistSupATRForWeakLateBullishBreakoutWideSLBuy,
         Ret_3,
         InpDynSL_MaxRet3ForWeakLateBullishBreakoutWideSLBuy,
         Ret_12,
         InpDynSL_MaxRet12ForWeakLateBullishBreakoutWideSLBuy,
         slPips,
         InpDynSL_MinSLPipsForWeakLateBullishBreakoutWideSLBuy
      );

      return true;
   }

   return false;
}


//+------------------------------------------------------------------+
//| ShouldReclassifyStrongBearishImpulseWideSLBuyToUnsafe
//+------------------------------------------------------------------+
bool ShouldReclassifyStrongBearishImpulseWideSLBuyToUnsafe(
   int decision,
   double chosenProb,
   double gap,
   double RSI,
   double ADX,
   double CCI,
   double MACD_hist,
   double Williams_R,
   double Dist_to_support_ATR,
   double Ret_3,
   double Ret_12,
   double slPips,
   string &reason
)
{
   reason = "";

   if(!InpDynSL_EnableStrongBearishImpulseWideSLBuyFilter)
      return false;

   if(decision != 2) // BUY only
      return false;

   // La pierderea din 2026.06.22 16:05 WPR a fost -59.16031.
   // Folosim -55 ca prag cu mic buffer, fiindca -60 ar rata exact cazul.
   double maxWPRForStrongBearishImpulseWideSLBuy = -55.0;

   bool weakProbability =
      chosenProb <= InpDynSL_MaxChosenProbForStrongBearishImpulseWideSLBuy;

   bool weakGap =
      gap <= InpDynSL_MaxGapForStrongBearishImpulseWideSLBuy;

   bool wideSL =
      slPips >= InpDynSL_MinSLPipsForStrongBearishImpulseWideSLBuy;

   bool strongADX =
      ADX >= InpDynSL_MinADXForStrongBearishImpulseWideSLBuy;

   bool extremeBearishCCI =
      CCI <= InpDynSL_MaxCCIForStrongBearishImpulseWideSLBuy;

   bool lowRSI =
      RSI <= InpDynSL_MaxRSIForStrongBearishImpulseWideSLBuy;

   bool bearishRet3 =
      Ret_3 <= InpDynSL_MaxRet3ForStrongBearishImpulseWideSLBuy;

   bool bearishRet12 =
      Ret_12 <= InpDynSL_MaxRet12ForStrongBearishImpulseWideSLBuy;

   bool bearishWPR =
      Williams_R <= maxWPRForStrongBearishImpulseWideSLBuy;

   bool farFromSupport =
      Dist_to_support_ATR >= InpDynSL_MinDistSupATRForStrongBearishImpulseWideSLBuy;

   bool bearishMACD =
      (!InpDynSL_RequireMACDHistNegForStrongBearishImpulseWideSLBuy) ||
      (MACD_hist < 0.0);

   bool badBuy =
      weakProbability &&
      weakGap &&
      wideSL &&
      strongADX &&
      extremeBearishCCI &&
      lowRSI &&
      bearishRet3 &&
      bearishRet12 &&
      bearishWPR &&
      farFromSupport &&
      bearishMACD;

   if(badBuy)
   {
      reason = StringFormat(
         "STRONG_BEARISH_IMPULSE_WIDE_SL_BUY->UNSAFE | p=%.5f maxP=%.5f gap=%.5f maxGap=%.5f RSI=%.2f maxRSI=%.2f ADX=%.2f minADX=%.2f CCI=%.2f maxCCI=%.2f MACDhist=%.5f WPR=%.2f maxWPR=%.2f DistSupATR=%.2f minDistSupATR=%.2f Ret3=%.5f maxRet3=%.5f Ret12=%.5f maxRet12=%.5f slPips=%.2f minSL=%.2f",
         chosenProb,
         InpDynSL_MaxChosenProbForStrongBearishImpulseWideSLBuy,
         gap,
         InpDynSL_MaxGapForStrongBearishImpulseWideSLBuy,
         RSI,
         InpDynSL_MaxRSIForStrongBearishImpulseWideSLBuy,
         ADX,
         InpDynSL_MinADXForStrongBearishImpulseWideSLBuy,
         CCI,
         InpDynSL_MaxCCIForStrongBearishImpulseWideSLBuy,
         MACD_hist,
         Williams_R,
         maxWPRForStrongBearishImpulseWideSLBuy,
         Dist_to_support_ATR,
         InpDynSL_MinDistSupATRForStrongBearishImpulseWideSLBuy,
         Ret_3,
         InpDynSL_MaxRet3ForStrongBearishImpulseWideSLBuy,
         Ret_12,
         InpDynSL_MaxRet12ForStrongBearishImpulseWideSLBuy,
         slPips,
         InpDynSL_MinSLPipsForStrongBearishImpulseWideSLBuy
      );

      return true;
   }

   return false;
}


//+------------------------------------------------------------------+
//| ShouldReclassifyOverboughtNearResistanceWideSLBuyToUnsafe
//+------------------------------------------------------------------+
bool ShouldReclassifyOverboughtNearResistanceWideSLBuyToUnsafe(
   int decision,
   double chosenProb,
   double gap,
   double RSI,
   double ADX,
   double CCI,
   double Stochastic,
   double Williams_R,
   double Dist_to_support_ATR,
   double Dist_to_resistance_ATR,
   double slPips,
   string &reason
)
{
   reason = "";

   if(!InpDynSL_EnableOverboughtNearResistanceWideSLBuyFilter)
      return false;

   if(decision != 2) // BUY only
      return false;

   bool weakProbability =
      chosenProb <= InpDynSL_MaxChosenProbForOverboughtNearResistanceWideSLBuy;

   bool weakGap =
      gap <= InpDynSL_MaxGapForOverboughtNearResistanceWideSLBuy;

   bool wideSL =
      slPips >= InpDynSL_MinSLPipsForOverboughtNearResistanceWideSLBuy;

   bool overboughtRSI =
      RSI >= InpDynSL_MinRSIForOverboughtNearResistanceWideSLBuy;

   bool overboughtStoch =
      Stochastic >= InpDynSL_MinStochForOverboughtNearResistanceWideSLBuy;

   bool overboughtWPR =
      Williams_R >= InpDynSL_MinWPRForOverboughtNearResistanceWideSLBuy;

   bool overboughtCCI =
      CCI >= InpDynSL_MinCCIForOverboughtNearResistanceWideSLBuy;

   bool weakADX =
      ADX <= InpDynSL_MaxADXForOverboughtNearResistanceWideSLBuy;

   bool veryNearResistance =
      Dist_to_resistance_ATR <= InpDynSL_MaxDistResATRForOverboughtNearResistanceWideSLBuy;

   bool farFromSupport =
      Dist_to_support_ATR >= InpDynSL_MinDistSupATRForOverboughtNearResistanceWideSLBuy;

   bool badBuy =
      weakProbability &&
      weakGap &&
      wideSL &&
      overboughtRSI &&
      overboughtStoch &&
      overboughtWPR &&
      overboughtCCI &&
      weakADX &&
      veryNearResistance &&
      farFromSupport;

   if(badBuy)
   {
      reason = StringFormat(
         "OVERBOUGHT_NEAR_RESISTANCE_WIDE_SL_BUY->UNSAFE | p=%.5f maxP=%.5f gap=%.5f maxGap=%.5f RSI=%.2f minRSI=%.2f ADX=%.2f maxADX=%.2f CCI=%.2f minCCI=%.2f Stoch=%.2f minStoch=%.2f WPR=%.2f minWPR=%.2f DistResATR=%.2f maxDistRes=%.2f DistSupATR=%.2f minDistSup=%.2f slPips=%.2f minSL=%.2f",
         chosenProb,
         InpDynSL_MaxChosenProbForOverboughtNearResistanceWideSLBuy,
         gap,
         InpDynSL_MaxGapForOverboughtNearResistanceWideSLBuy,
         RSI,
         InpDynSL_MinRSIForOverboughtNearResistanceWideSLBuy,
         ADX,
         InpDynSL_MaxADXForOverboughtNearResistanceWideSLBuy,
         CCI,
         InpDynSL_MinCCIForOverboughtNearResistanceWideSLBuy,
         Stochastic,
         InpDynSL_MinStochForOverboughtNearResistanceWideSLBuy,
         Williams_R,
         InpDynSL_MinWPRForOverboughtNearResistanceWideSLBuy,
         Dist_to_resistance_ATR,
         InpDynSL_MaxDistResATRForOverboughtNearResistanceWideSLBuy,
         Dist_to_support_ATR,
         InpDynSL_MinDistSupATRForOverboughtNearResistanceWideSLBuy,
         slPips,
         InpDynSL_MinSLPipsForOverboughtNearResistanceWideSLBuy
      );

      return true;
   }

   return false;
}


//+------------------------------------------------------------------+
//| UpdateRepeatWideSLBuyAfterFastTPMemoryFromDeal
//| Procesează un singur deal, în ordine cronologică.
//+------------------------------------------------------------------+
void UpdateRepeatWideSLBuyAfterFastTPMemoryFromDeal(const ulong dealTicket)
{
   if(!InpDynSL_EnableRepeatWideSLBuyAfterFastTPFilter)
      return;

   if(dealTicket == 0)
      return;

   if(!HistoryDealSelect(dealTicket))
      return;

   string symbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
   if(symbol != _Symbol)
      return;

   long magic = (long)HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
   if(magic != InpMagicNumber)
      return;

   long dealType  = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
   long entryType = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);

   datetime dealTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
   ulong positionId  = (ulong)HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);

   // BUY position entry.
   if(dealType == DEAL_TYPE_BUY && entryType == DEAL_ENTRY_IN)
   {
      RegisterRepeatFilterBuyEntry(dealTime, positionId);
      return;
   }

   // BUY position close = SELL deal with DEAL_ENTRY_OUT.
   if(dealType == DEAL_TYPE_SELL && entryType == DEAL_ENTRY_OUT)
   {
      bool closedByTP = IsRepeatFilterTPCloseDeal(dealTicket);
      RegisterRepeatFilterBuyClose(dealTime, positionId, closedByTP);
      return;
   }
}

//+------------------------------------------------------------------+
//| OnRepeatWideSLBuyAfterFastTPTradeTransaction
//| Varianta principală și cea mai corectă: memoria se actualizează
//| exact când apare deal-ul, nu prin scanări inverse ale istoricului.
//+------------------------------------------------------------------+
void OnRepeatWideSLBuyAfterFastTPTradeTransaction(const MqlTradeTransaction &trans)
{
   if(!InpDynSL_EnableRepeatWideSLBuyAfterFastTPFilter)
      return;

   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;

   UpdateRepeatWideSLBuyAfterFastTPMemoryFromDeal(trans.deal);
}

//+------------------------------------------------------------------+
//| UpdateRepeatWideSLBuyAfterFastTPMemory
//| Fallback cronologic pentru backtest/restart. Nu mai procesează invers,
//| deci TP-ul nu mai este văzut înaintea intrării BUY.
//+------------------------------------------------------------------+
void UpdateRepeatWideSLBuyAfterFastTPMemory()
{
   if(!InpDynSL_EnableRepeatWideSLBuyAfterFastTPFilter)
      return;

   static ulong lastProcessedDealTicket = 0;
   bool processNewDeals = (lastProcessedDealTicket == 0);

   if(!HistorySelect(0, TimeCurrent()))
      return;

   int total = HistoryDealsTotal();
   if(total <= 0)
      return;

   for(int i = 0; i < total; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0)
         continue;

      if(!processNewDeals)
      {
         if(dealTicket == lastProcessedDealTicket)
            processNewDeals = true;

         continue;
      }

      if(dealTicket == lastProcessedDealTicket)
         continue;

      UpdateRepeatWideSLBuyAfterFastTPMemoryFromDeal(dealTicket);
      lastProcessedDealTicket = dealTicket;
   }
}


//+------------------------------------------------------------------+
//| ShouldReclassifyWeakNormalWideSLSellToUnsafe
//| Blocks SELL entries that are still classified as NORMAL,
//| but have weak confidence/gap and wide SL in a weak-trend context.
//+------------------------------------------------------------------+
bool ShouldReclassifyWeakNormalWideSLSellToUnsafe(
   int decision,
   double chosenProb,
   double gap,
   double ADX,
   double Williams_R,
   double Dist_to_resistance_ATR,
   double slPips,
   string &reason
)
{
   reason = "";

   if(!InpDynSL_EnableWeakNormalWideSLSellFilter)
      return false;

   if(decision != 0) // SELL only
      return false;

   bool weakProbability =
      (chosenProb <= InpDynSL_MaxChosenProbForWeakNormalWideSLSell);

   bool weakDecisionGap =
      (gap <= InpDynSL_MaxGapForWeakNormalWideSLSell);

   bool wideSL =
      (slPips >= InpDynSL_MinSLPipsForWeakNormalWideSLSell);

   bool weakADX =
      (ADX <= InpDynSL_MaxADXForWeakNormalWideSLSell);

   bool farFromResistance =
      (Dist_to_resistance_ATR >= InpDynSL_MinDistResATRForWeakNormalWideSLSell);

   bool oversoldWPR =
      (!InpDynSL_RequireWPROversoldForWeakNormalWideSLSell) ||
      (Williams_R <= InpDynSL_MaxWPRForWeakNormalWideSLSell);

   bool badSell =
      weakProbability &&
      weakDecisionGap &&
      wideSL &&
      weakADX &&
      farFromResistance &&
      oversoldWPR;

   if(badSell)
   {
      reason = StringFormat(
         "WEAK_NORMAL_WIDE_SL_SELL->UNSAFE | p=%.5f maxP=%.5f gap=%.5f maxGap=%.5f ADX=%.2f maxADX=%.2f WPR=%.2f maxWPR=%.2f DistResATR=%.2f minDistRes=%.2f slPips=%.2f minSL=%.2f",
         chosenProb,
         InpDynSL_MaxChosenProbForWeakNormalWideSLSell,
         gap,
         InpDynSL_MaxGapForWeakNormalWideSLSell,
         ADX,
         InpDynSL_MaxADXForWeakNormalWideSLSell,
         Williams_R,
         InpDynSL_MaxWPRForWeakNormalWideSLSell,
         Dist_to_resistance_ATR,
         InpDynSL_MinDistResATRForWeakNormalWideSLSell,
         slPips,
         InpDynSL_MinSLPipsForWeakNormalWideSLSell
      );

      return true;
   }

   return false;
}


//+------------------------------------------------------------------+
//| ShouldReclassifyBullishBreakoutContinuationWideSLSellToUnsafe
//+------------------------------------------------------------------+
bool ShouldReclassifyBullishBreakoutContinuationWideSLSellToUnsafe(
   int decision,
   double chosenProb,
   double gap,
   double ADX,
   double CCI,
   double Williams_R,
   double MACD_hist,
   double Dist_to_resistance_ATR,
   double ret3ATR,
   double ret12ATR,
   double slPips,
   string &reason
)
{
   reason = "";

   if(!InpDynSL_BBCS_Enable)
      return false;

   if(decision != 0) // SELL only
      return false;

   bool weakProbability =
      chosenProb <= InpDynSL_BBCS_MaxProb;

   bool weakGap =
      gap <= InpDynSL_BBCS_MaxGap;

   bool wideSL =
      slPips >= InpDynSL_BBCS_MinSL;

   bool strongADX =
      ADX >= InpDynSL_BBCS_MinADX;

   bool bullishCCI =
      CCI >= InpDynSL_BBCS_MinCCI;

   bool bullishWPR =
      Williams_R >= InpDynSL_BBCS_MinWPR;

   bool bullishRet3 =
      ret3ATR >= InpDynSL_BBCS_MinRet3ATR;

   bool bullishRet12 =
      ret12ATR >= InpDynSL_BBCS_MinRet12ATR;

   bool nearResistance =
      Dist_to_resistance_ATR <= InpDynSL_BBCS_MaxDistRes;

   bool bullishMACD =
      (!InpDynSL_BBCS_RequireMACDHistPos) ||
      (MACD_hist > 0.0);

   bool badSell =
      weakProbability &&
      weakGap &&
      wideSL &&
      strongADX &&
      bullishCCI &&
      bullishWPR &&
      bullishRet3 &&
      bullishRet12 &&
      nearResistance &&
      bullishMACD;

   if(badSell)
   {
      reason = StringFormat(
         "BULLISH_BREAKOUT_CONTINUATION_WIDE_SL_SELL->UNSAFE | p=%.5f maxP=%.5f gap=%.5f maxGap=%.5f ADX=%.2f minADX=%.2f CCI=%.2f minCCI=%.2f WPR=%.2f minWPR=%.2f MACDhist=%.5f DistResATR=%.2f maxDistRes=%.2f ret3ATR=%.2f minRet3ATR=%.2f ret12ATR=%.2f minRet12ATR=%.2f slPips=%.2f minSL=%.2f",
         chosenProb,
         InpDynSL_BBCS_MaxProb,
         gap,
         InpDynSL_BBCS_MaxGap,
         ADX,
         InpDynSL_BBCS_MinADX,
         CCI,
         InpDynSL_BBCS_MinCCI,
         Williams_R,
         InpDynSL_BBCS_MinWPR,
         MACD_hist,
         Dist_to_resistance_ATR,
         InpDynSL_BBCS_MaxDistRes,
         ret3ATR,
         InpDynSL_BBCS_MinRet3ATR,
         ret12ATR,
         InpDynSL_BBCS_MinRet12ATR,
         slPips,
         InpDynSL_BBCS_MinSL
      );

      return true;
   }

   return false;
}


//+------------------------------------------------------------------+
//| ShouldReclassifyBullishMomentumWideSLSellToUnsafe
//| Blocks SELL entries with wide SL when bullish momentum is still
//| active and the SELL signal is weak.
//+------------------------------------------------------------------+
bool ShouldReclassifyBullishMomentumWideSLSellToUnsafe(
   int decision,
   double chosenProb,
   double gap,
   double ADX,
   double CCI,
   double Stochastic,
   double MACD_hist,
   double Dist_to_resistance_ATR,
   double ret3ATR,
   double slPips,
   string &reason
)
{
   reason = "";

   if(!InpDynSL_EnableBullishMomentumWideSLSellFilter)
      return false;

   if(decision != 0) // SELL only: SELL=0, HOLD=1, BUY=2
      return false;

   bool weakProbability =
      (chosenProb <= InpDynSL_MaxChosenProbForBullishMomentumWideSLSell);

   bool weakDecisionGap =
      (gap <= InpDynSL_MaxGapForBullishMomentumWideSLSell);

   bool wideSL =
      (slPips >= InpDynSL_MinSLPipsForBullishMomentumWideSLSell);

   bool strongADX =
      (ADX >= InpDynSL_MinADXForBullishMomentumWideSLSell);

   bool closeToResistance =
      (Dist_to_resistance_ATR <= InpDynSL_MaxDistResATRForBullishMomentumWideSLSell);

   bool strongCCI =
      (CCI >= InpDynSL_MinCCIForBullishMomentumWideSLSell);

   bool strongStoch =
      (Stochastic >= InpDynSL_MinStochForBullishMomentumWideSLSell);

   bool bullishMACD =
      (!InpDynSL_RequireMACDHistPosForBullishMomentumWideSLSell) ||
      (MACD_hist > 0.0);

   bool strongRet3 =
      (ret3ATR >= InpDynSL_MinRet3ATRForBullishMomentumWideSLSell);

   bool badSell =
      weakProbability &&
      weakDecisionGap &&
      wideSL &&
      strongADX &&
      closeToResistance &&
      strongCCI &&
      strongStoch &&
      bullishMACD &&
      strongRet3;

   if(badSell)
   {
      reason = StringFormat(
         "BULLISH_MOMENTUM_WIDE_SL_SELL->UNSAFE | p=%.5f maxP=%.5f gap=%.5f maxGap=%.5f ADX=%.2f minADX=%.2f CCI=%.2f minCCI=%.2f Stoch=%.2f minStoch=%.2f MACDhist=%.5f DistResATR=%.2f maxDistRes=%.2f ret3ATR=%.2f minRet3ATR=%.2f slPips=%.2f minSL=%.2f",
         chosenProb,
         InpDynSL_MaxChosenProbForBullishMomentumWideSLSell,
         gap,
         InpDynSL_MaxGapForBullishMomentumWideSLSell,
         ADX,
         InpDynSL_MinADXForBullishMomentumWideSLSell,
         CCI,
         InpDynSL_MinCCIForBullishMomentumWideSLSell,
         Stochastic,
         InpDynSL_MinStochForBullishMomentumWideSLSell,
         MACD_hist,
         Dist_to_resistance_ATR,
         InpDynSL_MaxDistResATRForBullishMomentumWideSLSell,
         ret3ATR,
         InpDynSL_MinRet3ATRForBullishMomentumWideSLSell,
         slPips,
         InpDynSL_MinSLPipsForBullishMomentumWideSLSell
      );

      return true;
   }

   return false;
}


//+------------------------------------------------------------------+
//| ShouldReclassifyWeakNeutralSellToUnsafe
//| Verifică dacă un SELL neutru/slab trebuie reclasificat ca UNSAFE.
//+------------------------------------------------------------------+
bool ShouldReclassifyWeakNeutralSellToUnsafe(
   int decision,
   int extremeVotes,
   int unsafeVotes,
   double ADX,
   double ret12ATR,
   double macdHistATR,
   double Dist_to_resistance_ATR,
   string &reason
)
{
   reason = "";

   if(!InpDynSL_EnableWeakNeutralSellFilter)
      return false;

   if(decision != 0) // doar SELL
      return false;

   bool weakNeutralSell =
      (extremeVotes <= InpDynSL_MaxExtremeVotesForWeakNeutralSell) &&
      (unsafeVotes <= InpDynSL_MaxUnsafeVotesForWeakNeutralSell) &&
      (Dist_to_resistance_ATR >= InpDynSL_MinDistResATRForWeakNeutralSell) &&
      (ret12ATR <= InpDynSL_MaxRet12ATRForWeakNeutralSell) &&
      (macdHistATR <= InpDynSL_MaxMACDHistATRForWeakNeutralSell) &&
      (ADX <= InpDynSL_MaxADXForWeakNeutralSell);

   if(weakNeutralSell)
   {
      reason = StringFormat(
         "WEAK_NEUTRAL_SELL->UNSAFE | votes=%d unsafeVotes=%d ADX=%.2f ret12ATR=%.2f macdHistATR=%.2f DistResATR=%.2f",
         extremeVotes, unsafeVotes, ADX, ret12ATR, macdHistATR, Dist_to_resistance_ATR
      );
      return true;
   }

   return false;
}




//+------------------------------------------------------------------+
//| ShouldReclassifyLocalFadeSellWeakToUnsafe
//| Verifică dacă un SELL de tip local fade slab trebuie reclasificat ca UNSAFE.
//+------------------------------------------------------------------+
bool ShouldReclassifyLocalFadeSellWeakToUnsafe(
   int decision,
   int extremeVotes,
   int unsafeVotes,
   double ADX,
   double CCI,
   double Williams_R,
   double ret12ATR,
   double macdHistATR,
   double Dist_to_resistance_ATR,
   string &reason
)
{
   reason = "";

   if(!InpDynSL_EnableLocalFadeSellWeakFilter)
      return false;

   if(decision != 0) // doar SELL
      return false;

   bool localFadeSellWeak =
      (extremeVotes >= InpDynSL_MinExtremeVotesForLocalFadeSell) &&
      (extremeVotes <= InpDynSL_MaxExtremeVotesForLocalFadeSell) &&
      (unsafeVotes <= InpDynSL_MaxUnsafeVotesForLocalFadeSell) &&
      (Dist_to_resistance_ATR <= InpDynSL_MaxDistResATRForLocalFadeSell) &&
      (ADX <= InpDynSL_MaxADXForLocalFadeSell) &&
      (ret12ATR <= InpDynSL_MaxRet12ATRForLocalFadeSell) &&
      (CCI >= InpDynSL_MinCCIForLocalFadeSell) &&
      (Williams_R >= InpDynSL_MinWPRForLocalFadeSell) &&
      (macdHistATR <= InpDynSL_MaxMACDHistATRForLocalFadeSell);

   if(localFadeSellWeak)
   {
      reason = StringFormat(
         "LOCAL_FADE_SELL_WEAK->UNSAFE | votes=%d unsafeVotes=%d ADX=%.2f CCI=%.2f WPR=%.2f ret12ATR=%.2f macdHistATR=%.2f DistResATR=%.2f",
         extremeVotes, unsafeVotes, ADX, CCI, Williams_R, ret12ATR, macdHistATR, Dist_to_resistance_ATR
      );
      return true;
   }

   return false;
}


//+------------------------------------------------------------------+
//| ShouldReclassifyLocalOverboughtSellToUnsafe
//| Verifică dacă un SELL în supracumpărare locală trebuie reclasificat ca UNSAFE.
//+------------------------------------------------------------------+
bool ShouldReclassifyLocalOverboughtSellToUnsafe(
   int decision,
   int extremeVotes,
   int unsafeVotes,
   double ADX,
   double ret12ATR,
   double macdHistATR,
   double Dist_to_resistance_ATR,
   string &reason
)
{
   reason = "";

   if(!InpDynSL_EnableLocalOverboughtSellFilter)
      return false;

   if(decision != 0) // doar SELL
      return false;

   bool localOverboughtSell =
      (extremeVotes >= InpDynSL_MinExtremeVotesForLocalOBSell) &&
      (unsafeVotes <= InpDynSL_MaxUnsafeVotesForLocalOBSell) &&
      (Dist_to_resistance_ATR <= InpDynSL_MaxDistResATRForLocalOBSell) &&
      (ADX >= InpDynSL_MinADXForLocalOBSell) &&
      (ret12ATR <= InpDynSL_MaxRet12ATRForLocalOBSell) &&
      (macdHistATR <= InpDynSL_MaxMACDHistATRForLocalOBSell);

   if(localOverboughtSell)
   {
      reason = StringFormat(
         "LOCAL_OVERBOUGHT_SELL->UNSAFE | votes=%d unsafeVotes=%d ADX=%.2f ret12ATR=%.2f macdHistATR=%.2f DistResATR=%.2f",
         extremeVotes, unsafeVotes, ADX, ret12ATR, macdHistATR, Dist_to_resistance_ATR
      );
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| ShouldReclassifySemiUnsafeSellToUnsafe
//| Prinde setup-uri SELL semi-periculoase și le marchează ca UNSAFE.
//+------------------------------------------------------------------+
bool ShouldReclassifySemiUnsafeSellToUnsafe(
   int decision,
   int extremeVotes,
   int unsafeVotes,
   double ADX,
   double ret12ATR,
   double macdHistATR,
   double Dist_to_resistance_ATR,
   string &reason
)
{
   reason = "";

   if(!InpDynSL_EnableSemiUnsafeSellFilter)
      return false;

   if(decision != 0) // SELL only
      return false;

   bool semiUnsafeSell =
      (extremeVotes >= InpDynSL_MinExtremeVotesForSemiUnsafeSell) &&
      (unsafeVotes >= InpDynSL_MinUnsafeVotesForSemiUnsafeSell) &&
      (ADX >= InpDynSL_MinADXForSemiUnsafeSell) &&
      (ret12ATR >= InpDynSL_MinRet12ATRForSemiUnsafeSell) &&
      (macdHistATR <= InpDynSL_MaxMACDHistATRForSemiUnsafeSell) &&
      (Dist_to_resistance_ATR <= InpDynSL_MaxDistResATRForSemiUnsafeSell);

   if(semiUnsafeSell)
   {
      reason = StringFormat(
         "SEMI_UNSAFE_SELL->UNSAFE | votes=%d unsafeVotes=%d ADX=%.2f ret12ATR=%.2f macdHistATR=%.2f DistResATR=%.2f",
         extremeVotes, unsafeVotes, ADX, ret12ATR, macdHistATR, Dist_to_resistance_ATR
      );
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| ShouldReclassifyLateSellChaseToUnsafe
//| Detectează SELL-uri urmărite prea târziu după o mișcare deja extinsă.
//+------------------------------------------------------------------+
bool ShouldReclassifyLateSellChaseToUnsafe(
   int decision,
   int extremeVotes,
   int unsafeVotes,
   double ADX,
   double MACD_hist,
   double ret12ATR,
   double Dist_to_resistance_ATR,
   string &reason
)
{
   reason = "";

   if(!InpDynSL_EnableLateSellChaseFilter)
      return false;

   if(decision != 0) // SELL only
      return false;

   bool lateSellChase =
      (extremeVotes <= InpDynSL_MaxExtremeVotesForLateSellChase) &&
      (unsafeVotes >= InpDynSL_MinUnsafeVotesForLateSellChase) &&
      (ADX <= InpDynSL_MaxADXForLateSellChase) &&
      (ret12ATR >= InpDynSL_MinRet12ATRForLateSellChase) &&
      (Dist_to_resistance_ATR >= InpDynSL_MinDistResATRForLateSellChase) &&
      ((!InpDynSL_RequireMACDHistNegForLateSellChase) || (MACD_hist <= 0.0));

   if(lateSellChase)
   {
      reason = StringFormat(
         "LATE_SELL_CHASE->UNSAFE | votes=%d unsafeVotes=%d ADX=%.2f MACDhist=%.5f ret12ATR=%.2f DistResATR=%.2f",
         extremeVotes, unsafeVotes, ADX, MACD_hist, ret12ATR, Dist_to_resistance_ATR
      );
      return true;
   }

   return false;
}


//+------------------------------------------------------------------+
//| ShouldReclassifyBearishPullbackWideSLBuyToUnsafe
//+------------------------------------------------------------------+
bool ShouldReclassifyBearishPullbackWideSLBuyToUnsafe(
   int decision,
   double chosenProb,
   double gap,
   double ADX,
   double CCI,
   double Williams_R,
   double Stochastic,
   double MACD_hist,
   double Dist_to_support_ATR,
   double ret12ATR,
   double slPips,
   string &reason
)
{
   reason = "";

   if(!InpDynSL_EnableBearishPullbackWideSLBuyFilter)
      return false;

   if(decision != 2) // BUY only
      return false;

   bool weakProbability =
      chosenProb <= InpDynSL_MaxChosenProbForBearishPullbackWideSLBuy;

   bool weakGap =
      gap <= InpDynSL_MaxGapForBearishPullbackWideSLBuy;

   bool wideSL =
      slPips >= InpDynSL_MinSLPipsForBearishPullbackWideSLBuy;

   bool weakADX =
      ADX <= InpDynSL_MaxADXForBearishPullbackWideSLBuy;

   bool bearishRet12 =
      ret12ATR >= InpDynSL_MinRet12ATRForBearishPullbackWideSLBuy;

   bool notCloseEnoughToSupport =
      Dist_to_support_ATR <= InpDynSL_MaxDistSupATRForBearishPullbackWideSLBuy;

   bool bearishCCI =
      CCI <= InpDynSL_MaxCCIForBearishPullbackWideSLBuy;

   bool bearishWPR =
      Williams_R <= InpDynSL_MaxWPRForBearishPullbackWideSLBuy;

   bool bearishStoch =
      Stochastic <= InpDynSL_MaxStochForBearishPullbackWideSLBuy;

   bool bearishMACD =
      (!InpDynSL_RequireMACDHistNegForBearishPullbackWideSLBuy) ||
      (MACD_hist < 0.0);

   bool badBuy =
      weakProbability &&
      weakGap &&
      wideSL &&
      weakADX &&
      bearishRet12 &&
      notCloseEnoughToSupport &&
      bearishCCI &&
      bearishWPR &&
      bearishStoch &&
      bearishMACD;

   if(badBuy)
   {
      reason = StringFormat(
         "BEARISH_PULLBACK_WIDE_SL_BUY->UNSAFE | p=%.5f maxP=%.5f gap=%.5f maxGap=%.5f ADX=%.2f maxADX=%.2f CCI=%.2f maxCCI=%.2f WPR=%.2f maxWPR=%.2f Stoch=%.2f maxStoch=%.2f MACDhist=%.5f DistSupATR=%.2f maxDistSup=%.2f ret12ATR=%.2f minRet12ATR=%.2f slPips=%.2f minSL=%.2f",
         chosenProb,
         InpDynSL_MaxChosenProbForBearishPullbackWideSLBuy,
         gap,
         InpDynSL_MaxGapForBearishPullbackWideSLBuy,
         ADX,
         InpDynSL_MaxADXForBearishPullbackWideSLBuy,
         CCI,
         InpDynSL_MaxCCIForBearishPullbackWideSLBuy,
         Williams_R,
         InpDynSL_MaxWPRForBearishPullbackWideSLBuy,
         Stochastic,
         InpDynSL_MaxStochForBearishPullbackWideSLBuy,
         MACD_hist,
         Dist_to_support_ATR,
         InpDynSL_MaxDistSupATRForBearishPullbackWideSLBuy,
         ret12ATR,
         InpDynSL_MinRet12ATRForBearishPullbackWideSLBuy,
         slPips,
         InpDynSL_MinSLPipsForBearishPullbackWideSLBuy
      );

      return true;
   }

   return false;
}



//+------------------------------------------------------------------+
//| ShouldReclassifyMidReboundBuyToUnsafe
//| Detectează BUY-uri de rebound mediu care au risc de continuare negativă.
//+------------------------------------------------------------------+
bool ShouldReclassifyMidReboundBuyToUnsafe(
   int decision,
   int extremeVotes,
   int unsafeVotes,
   double ADX,
   double ret12ATR,
   double macdHistATR,
   double Dist_to_support_ATR,
   string &reason
)
{
   reason = "";

   if(!InpDynSL_EnableMidReboundBuyFilter)
      return false;

   if(decision != 2) // doar BUY
      return false;

   bool midReboundBuy =
      (extremeVotes >= InpDynSL_MinVotesForMidReboundBuy) &&
      (unsafeVotes <= InpDynSL_MaxUnsafeVotesForMidReboundBuy) &&
      (ADX <= InpDynSL_MaxADXForMidReboundBuy) &&
      (ret12ATR >= InpDynSL_MinRet12ATRForMidReboundBuy) &&
      (macdHistATR <= InpDynSL_MaxMACDHistATRForMidReboundBuy) &&
      (Dist_to_support_ATR <= InpDynSL_MaxDistSupATRForMidReboundBuy);

   if(midReboundBuy)
   {
      reason = StringFormat(
         "MID_REBOUND_BUY->UNSAFE | votes=%d unsafeVotes=%d ADX=%.2f ret12ATR=%.2f macdHistATR=%.2f DistSupATR=%.2f",
         extremeVotes, unsafeVotes, ADX, ret12ATR, macdHistATR, Dist_to_support_ATR
      );
      return true;
   }

   return false;
}


//+------------------------------------------------------------------+
//| ShouldReclassifyRepeatWideSLBuyAfterFastTPToUnsafe
//| Blocks repeated BUY entries shortly after a very fast BUY TP,
//| but only when the new setup would use a wide SL.
//+------------------------------------------------------------------+
bool ShouldReclassifyRepeatWideSLBuyAfterFastTPToUnsafe(
   int decision,
   double slPips,
   datetime signalTime,
   string &reason
)
{
   reason = "";

   if(!InpDynSL_EnableRepeatWideSLBuyAfterFastTPFilter)
      return false;

   if(decision != 2) // BUY only
      return false;

   if(!g_lastBuyClosedFastTP || g_lastFastBuyTPCloseTime <= 0)
      return false;

   bool wideSL =
      (slPips >= InpDynSL_MinSLPipsForRepeatWideSLBuyAfterFastTP);

   int secondsAfterFastTP =
      (int)(signalTime - g_lastFastBuyTPCloseTime);

   bool insideBlockWindow =
      (secondsAfterFastTP >= 0 &&
       secondsAfterFastTP <= InpDynSL_BlockMinutesAfterFastBuyTP * 60);

   bool badRepeatBuy =
      wideSL &&
      insideBlockWindow;

   if(badRepeatBuy)
   {
      reason = StringFormat(
         "REPEAT_WIDE_SL_BUY_AFTER_FAST_TP->UNSAFE | secondsAfterFastTP=%d blockMinutes=%d slPips=%.2f lastFastTPClose=%s",
         secondsAfterFastTP,
         InpDynSL_BlockMinutesAfterFastBuyTP,
         slPips,
         TimeToString(g_lastFastBuyTPCloseTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS)
      );

      return true;
   }

   return false;
}


//+------------------------------------------------------------------+
//| ShouldReclassifyWeakNormalWideSLBuyToUnsafe
//| Blocks BUY entries that are still classified as NORMAL,
//| but have weak confidence/gap and wide SL.
//+------------------------------------------------------------------+
bool ShouldReclassifyWeakNormalWideSLBuyToUnsafe(
   int decision,
   double chosenProb,
   double gap,
   double slPips,
   string &reason
)
{
   reason = "";

   if(!InpDynSL_EnableWeakNormalWideSLBuyFilter)
      return false;

   if(decision != 2) // BUY only
      return false;

   bool weakProbability =
      (chosenProb <= InpDynSL_MaxChosenProbForWeakNormalWideSLBuy);

   bool weakDecisionGap =
      (gap <= InpDynSL_MaxGapForWeakNormalWideSLBuy);

   bool wideSL =
      (slPips >= InpDynSL_MinSLPipsForWeakNormalWideSLBuy);

   bool badBuy =
      weakProbability &&
      weakDecisionGap &&
      wideSL;

   if(badBuy)
   {
      reason = StringFormat(
         "WEAK_NORMAL_WIDE_SL_BUY->UNSAFE | p=%.5f maxP=%.5f gap=%.5f maxGap=%.5f slPips=%.2f minSL=%.2f",
         chosenProb,
         InpDynSL_MaxChosenProbForWeakNormalWideSLBuy,
         gap,
         InpDynSL_MaxGapForWeakNormalWideSLBuy,
         slPips,
         InpDynSL_MinSLPipsForWeakNormalWideSLBuy
      );

      return true;
   }

   return false;
}


//+------------------------------------------------------------------+
//| ShouldReclassifyBearishSupportWideSLBuyToUnsafe
//| Blocks BUY entries with wide SL near support when bearish pressure
//| is still active.
//+------------------------------------------------------------------+
bool ShouldReclassifyBearishSupportWideSLBuyToUnsafe(
   int decision,
   double chosenProb,
   double gap,
   double ADX,
   double CCI,
   double Williams_R,
   double MACD_hist,
   double Dist_to_support_ATR,
   double slPips,
   string &reason
)
{
   reason = "";

   if(!InpDynSL_EnableBearishSupportWideSLBuyFilter)
      return false;

   if(decision != 2) // BUY only
      return false;

   bool weakProbability =
      (chosenProb <= InpDynSL_MaxChosenProbForBearishSupportWideSLBuy);

   bool weakDecisionGap =
      (gap <= InpDynSL_MaxGapForBearishSupportWideSLBuy);

   bool wideSL =
      (slPips >= InpDynSL_MinSLPipsForBearishSupportWideSLBuy);

   bool lowMidADX =
      (ADX <= InpDynSL_MaxADXForBearishSupportWideSLBuy);

   bool closeToSupport =
      (Dist_to_support_ATR <= InpDynSL_MaxDistSupATRForBearishSupportWideSLBuy);

   bool bearishCCI =
      (CCI <= InpDynSL_MaxCCIForBearishSupportWideSLBuy);

   bool bearishWPR =
      (Williams_R <= InpDynSL_MaxWPRForBearishSupportWideSLBuy);

   bool bearishMACD =
      (!InpDynSL_RequireMACDHistNegForBearishSupportWideSLBuy) ||
      (MACD_hist < 0.0);

   bool badBuy =
      weakProbability &&
      weakDecisionGap &&
      wideSL &&
      lowMidADX &&
      closeToSupport &&
      bearishCCI &&
      bearishWPR &&
      bearishMACD;

   if(badBuy)
   {
      reason = StringFormat(
         "BEARISH_SUPPORT_WIDE_SL_BUY->UNSAFE | p=%.5f maxP=%.5f gap=%.5f maxGap=%.5f ADX=%.2f maxADX=%.2f CCI=%.2f maxCCI=%.2f WPR=%.2f maxWPR=%.2f MACDhist=%.5f DistSupATR=%.2f maxDistSup=%.2f slPips=%.2f minSL=%.2f",
         chosenProb,
         InpDynSL_MaxChosenProbForBearishSupportWideSLBuy,
         gap,
         InpDynSL_MaxGapForBearishSupportWideSLBuy,
         ADX,
         InpDynSL_MaxADXForBearishSupportWideSLBuy,
         CCI,
         InpDynSL_MaxCCIForBearishSupportWideSLBuy,
         Williams_R,
         InpDynSL_MaxWPRForBearishSupportWideSLBuy,
         MACD_hist,
         Dist_to_support_ATR,
         InpDynSL_MaxDistSupATRForBearishSupportWideSLBuy,
         slPips,
         InpDynSL_MinSLPipsForBearishSupportWideSLBuy
      );

      return true;
   }

   return false;
}


//+------------------------------------------------------------------+
//| ShouldReclassifyHighADXBearishWideSLBuyToUnsafe
//| Blocks BUY entries with wide SL when bearish pressure is still high.
//+------------------------------------------------------------------+
bool ShouldReclassifyHighADXBearishWideSLBuyToUnsafe(
   int decision,
   double ADX,
   double CCI,
   double Williams_R,
   double MACD_hist,
   double Dist_to_support_ATR,
   double slPips,
   string &reason
)
{
   reason = "";

   if(!InpDynSL_EnableHighADXBearishWideSLBuyFilter)
      return false;

   if(decision != 2) // BUY only
      return false;

   bool wideSL =
      (slPips >= InpDynSL_MinSLPipsForHighADXBearishWideSLBuy);

   bool strongTrend =
      (ADX >= InpDynSL_MinADXForHighADXBearishWideSLBuy);

   bool closeToSupport =
      (Dist_to_support_ATR <= InpDynSL_MaxDistSupATRForHighADXBearishWideSLBuy);

   bool bearishCCI =
      (CCI <= InpDynSL_MaxCCIForHighADXBearishWideSLBuy);

   bool bearishWPR =
      (Williams_R <= InpDynSL_MaxWPRForHighADXBearishWideSLBuy);

   bool bearishMACD =
      (!InpDynSL_RequireMACDHistNegForHighADXBearishWideSLBuy) ||
      (MACD_hist < 0.0);

   bool badBuy =
      wideSL &&
      strongTrend &&
      closeToSupport &&
      bearishCCI &&
      bearishWPR &&
      bearishMACD;

   if(badBuy)
   {
      reason = StringFormat(
         "HIGH_ADX_BEARISH_WIDE_SL_BUY->UNSAFE | ADX=%.2f minADX=%.2f CCI=%.2f maxCCI=%.2f WPR=%.2f maxWPR=%.2f MACDhist=%.5f DistSupATR=%.2f maxDistSup=%.2f slPips=%.2f minSL=%.2f",
         ADX,
         InpDynSL_MinADXForHighADXBearishWideSLBuy,
         CCI,
         InpDynSL_MaxCCIForHighADXBearishWideSLBuy,
         Williams_R,
         InpDynSL_MaxWPRForHighADXBearishWideSLBuy,
         MACD_hist,
         Dist_to_support_ATR,
         InpDynSL_MaxDistSupATRForHighADXBearishWideSLBuy,
         slPips,
         InpDynSL_MinSLPipsForHighADXBearishWideSLBuy
      );

      return true;
   }

   return false;
}


//+------------------------------------------------------------------+
//| ShouldReclassifyNeutralWideSLBuyToUnsafe
//| Blocks BUY entries with wide SL when the setup is neutral,
//| has weak momentum and is not close enough to support.
//+------------------------------------------------------------------+
bool ShouldReclassifyNeutralWideSLBuyToUnsafe(
   int decision,
   double chosenProb,
   double gap,
   double ADX,
   double ret12ATR,
   double macdHistATR,
   double Dist_to_support_ATR,
   double Dist_to_resistance_ATR,
   double slPips,
   string &reason
)
{
   reason = "";

   if(!InpDynSL_EnableNeutralWideSLBuyFilter)
      return false;

   if(decision != 2) // BUY only
      return false;

   bool weakProbability =
      (chosenProb <= InpDynSL_MaxChosenProbForNeutralWideSLBuy);

   bool weakDecisionGap =
      (gap <= InpDynSL_MaxGapForNeutralWideSLBuy);

   bool weakTrend =
      (ADX <= InpDynSL_MaxADXForNeutralWideSLBuy);

   bool neutralMediumMove =
      (MathAbs(ret12ATR) <= InpDynSL_MaxAbsRet12ATRForNeutralWideSLBuy);

   bool weakMACDMomentum =
      (MathAbs(macdHistATR) <= InpDynSL_MaxAbsMACDHistATRForNeutralWideSLBuy);

   bool notNearSupport =
      (Dist_to_support_ATR >= InpDynSL_MinDistSupATRForNeutralWideSLBuy);

   bool notNearResistance =
      (Dist_to_resistance_ATR >= InpDynSL_MinDistResATRForNeutralWideSLBuy);

   bool wideSL =
      (slPips >= InpDynSL_MinSLPipsForNeutralWideSLBuy);

   bool badBuy =
      weakProbability &&
      weakDecisionGap &&
      weakTrend &&
      neutralMediumMove &&
      weakMACDMomentum &&
      notNearSupport &&
      notNearResistance &&
      wideSL;

   if(badBuy)
   {
      reason = StringFormat(
         "NEUTRAL_WIDE_SL_BUY->UNSAFE | p=%.5f gap=%.5f ADX=%.2f ret12ATR=%.2f macdHistATR=%.2f DistSupATR=%.2f DistResATR=%.2f slPips=%.2f",
         chosenProb,
         gap,
         ADX,
         ret12ATR,
         macdHistATR,
         Dist_to_support_ATR,
         Dist_to_resistance_ATR,
         slPips
      );

      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| ShouldReclassifyWeakReboundBuyToUnsafe
//| Detectează BUY-uri de rebound slab și le poate marca UNSAFE.
//+------------------------------------------------------------------+
bool ShouldReclassifyWeakReboundBuyToUnsafe(
   int decision,
   int extremeVotes,
   double MACD_hist,
   double ADX,
   double ret12ATR,
   double Dist_to_support_ATR,
   string &reason
)
{
   reason = "";

   if(!InpDynSL_EnableWeakReboundBuyFilter)
      return false;

   if(decision != 2) // doar BUY
      return false;

   bool reboundCore =
      (extremeVotes >= InpDynSL_MinExtremeVotesForWeakBuy) &&
      (Dist_to_support_ATR <= InpDynSL_MaxDistSupATRForWeakBuy);

   bool stillRisky =
      (ADX >= InpDynSL_MinADXForWeakBuy) &&
      (ret12ATR >= InpDynSL_MinRet12ATRForWeakBuy);

   bool macdStillWeak =
      (!InpDynSL_RequireMACDHistNegForWeakBuy) || (MACD_hist <= 0.0);

   bool weakReboundBuy = reboundCore && stillRisky && macdStillWeak;

   if(weakReboundBuy)
   {
      reason = StringFormat(
         "WEAK_REBOUND_BUY->UNSAFE | votes=%d ADX=%.2f ret12ATR=%.2f MACDhist=%.5f DistSupATR=%.2f",
         extremeVotes, ADX, ret12ATR, MACD_hist, Dist_to_support_ATR
      );
      return true;
   }

   return false;
}



//+------------------------------------------------------------------+
//| ShouldReclassifyWeakSellToUnsafe
//| Detectează SELL-uri slabe, fără context suficient, și le poate marca UNSAFE.
//+------------------------------------------------------------------+
bool ShouldReclassifyWeakSellToUnsafe(
   int decision,
   int extremeVotes,
   int unsafeVotes,
   double ADX,
   double ret12ATR,
   double Dist_to_resistance_ATR,
   string &reason
)
{
   reason = "";

   if(!InpDynSL_EnableWeakSellFilter)
      return false;

   if(decision != 0) // doar SELL
      return false;

   bool weakSell =
      (extremeVotes <= InpDynSL_MaxExtremeVotesForWeakSell) &&
      (unsafeVotes <= InpDynSL_MaxUnsafeVotesForWeakSell) &&
      (ADX <= InpDynSL_MaxADXForWeakSell) &&
      (ret12ATR <= InpDynSL_MaxRet12ATRForWeakSell) &&
      (Dist_to_resistance_ATR >= InpDynSL_MinDistResATRForWeakSell);

   if(weakSell)
   {
      reason = StringFormat(
         "WEAK_SELL->UNSAFE | votes=%d unsafeVotes=%d ADX=%.2f ret12ATR=%.2f DistResATR=%.2f",
         extremeVotes, unsafeVotes, ADX, ret12ATR, Dist_to_resistance_ATR
      );
      return true;
   }

   return false;
}



//+------------------------------------------------------------------+
//| ShouldReclassifyOverboughtSellInStrongUptrendToUnsafe
//| Blochează SELL-uri contra unui uptrend puternic în zonă overbought.
//+------------------------------------------------------------------+
bool ShouldReclassifyOverboughtSellInStrongUptrendToUnsafe(
   int decision,
   int extremeVotes,
   double MACD_hist,
   double ADX,
   double ret12ATR,
   double Dist_to_resistance_ATR,
   string &reason
)
{
   reason = "";

   if(!InpDynSL_EnableStrongUptrendSellFilter)
      return false;

   if(decision != 0) // doar SELL
      return false;

   bool overboughtCore =
      (extremeVotes >= InpDynSL_MinExtremeVotesForUptrendSell) &&
      (Dist_to_resistance_ATR <= InpDynSL_MaxDistResATRForUptrendSell);

   bool strongTrend =
      (ADX >= InpDynSL_MinADXForUptrendSell) &&
      (ret12ATR >= InpDynSL_MinRet12ATRForUptrendSell);

   bool macdStillBullish =
      (!InpDynSL_RequireMACDHistPosForUptrendSell) || (MACD_hist > 0.0);

   bool badSell = overboughtCore && strongTrend && macdStillBullish;

   if(badSell)
   {
      reason = StringFormat(
         "OVERBOUGHT_SELL_IN_STRONG_UPTREND->UNSAFE | votes=%d ADX=%.2f ret12ATR=%.2f MACDhist=%.5f DistResATR=%.2f",
         extremeVotes, ADX, ret12ATR, MACD_hist, Dist_to_resistance_ATR
      );
      return true;
   }

   return false;
}


//+------------------------------------------------------------------+
//| ShouldReclassifyStrongUptrendContinuationSellToUnsafe
//| Blocks SELL entries when bullish momentum is still active.
//| This is designed for cases where the market is not extremely close
//| to resistance anymore, but the uptrend continuation risk is still high.
//+------------------------------------------------------------------+
bool ShouldReclassifyStrongUptrendContinuationSellToUnsafe(
   int decision,
   double RSI,
   double CCI,
   double Stochastic,
   double MACD_hist,
   double ADX,
   double ret12ATR,
   double macdHistATR,
   double Dist_to_resistance_ATR,
   string &reason
)
{
   reason = "";

   if(!InpDynSL_EnableStrongUptrendContinuationSellFilter)
      return false;

   if(decision != 0) // SELL only
      return false;

   bool strongTrend =
      (ADX >= InpDynSL_MinADXForStrongUptrendContinuationSell) &&
      (ret12ATR >= InpDynSL_MinRet12ATRForStrongUptrendContinuationSell);

   bool bullishMomentum =
      (MACD_hist > 0.0) &&
      (macdHistATR >= InpDynSL_MinMACDHistATRForStrongUptrendContinuationSell);

   bool stillNearResistanceZone =
      (Dist_to_resistance_ATR <= InpDynSL_MaxDistResATRForStrongUptrendContinuationSell);

   bool voteRSI =
      (RSI >= InpDynSL_MinRSIForStrongUptrendContinuationSell);

   bool voteStoch =
      (Stochastic >= InpDynSL_MinStochForStrongUptrendContinuationSell);

   bool voteCCI =
      (CCI >= InpDynSL_MinCCIForStrongUptrendContinuationSell);

   int overheatedVotes = CountTrue(voteRSI, voteStoch, voteCCI, false);

   bool badSell =
      strongTrend &&
      bullishMomentum &&
      stillNearResistanceZone &&
      (overheatedVotes >= InpDynSL_MinOverheatedVotesForStrongUptrendContinuationSell);

   if(badSell)
   {
      reason = StringFormat(
         "STRONG_UPTREND_CONTINUATION_SELL->UNSAFE | overheatedVotes=%d ADX=%.2f ret12ATR=%.2f macdHistATR=%.2f MACDhist=%.5f DistResATR=%.2f RSI=%.2f Stoch=%.2f CCI=%.2f",
         overheatedVotes,
         ADX,
         ret12ATR,
         macdHistATR,
         MACD_hist,
         Dist_to_resistance_ATR,
         RSI,
         Stochastic,
         CCI
      );

      return true;
   }

   return false;
}


//+------------------------------------------------------------------+
//| ShouldReclassifyLateSessionWideSLSellToUnsafe
//| Blocks late-session SELL entries when the setup requires a wide SL,
//| but momentum is not strong enough and price is too far from resistance.
//+------------------------------------------------------------------+
bool ShouldReclassifyLateSessionWideSLSellToUnsafe(
   int decision,
   double ADX,
   double ret12ATR,
   double macdHistATR,
   double Dist_to_resistance_ATR,
   double slPips,
   datetime signalTime,
   string &reason
)
{
   reason = "";

   if(!InpDynSL_EnableLateSessionWideSLSellFilter)
      return false;

   if(decision != 0) // SELL only
      return false;

   MqlDateTime dt;
   TimeToStruct(signalTime, dt);

   bool isLateSession =
      (dt.hour >= InpDynSL_LateSessionSellStartHour);

   bool wideSL =
      (slPips >= InpDynSL_MinSLPipsForLateSessionSell);

   bool farFromResistance =
      (Dist_to_resistance_ATR >= InpDynSL_MinDistResATRForLateSessionSell);

   bool weakMediumMomentum =
      (ret12ATR <= InpDynSL_MaxRet12ATRForLateSessionSell);

   bool weakMACDMomentum =
      (MathAbs(macdHistATR) <= InpDynSL_MaxMACDHistATRForLateSessionSell);

   bool badLateSell =
      isLateSession &&
      wideSL &&
      farFromResistance &&
      weakMediumMomentum &&
      weakMACDMomentum;

   if(badLateSell)
   {
      reason = StringFormat(
         "LATE_SESSION_WIDE_SL_SELL->UNSAFE | hour=%d slPips=%.2f ADX=%.2f ret12ATR=%.2f macdHistATR=%.2f DistResATR=%.2f",
         dt.hour,
         slPips,
         ADX,
         ret12ATR,
         macdHistATR,
         Dist_to_resistance_ATR
      );

      return true;
   }

   return false;
}


//+------------------------------------------------------------------+
//| ShouldReclassifyHighADXWeakPullbackSellToUnsafe
//| Blocks SELL entries when ADX is very high, but the bearish pullback
//| is weak and the setup would require a wide SL.
//+------------------------------------------------------------------+
bool ShouldReclassifyHighADXWeakPullbackSellToUnsafe(
   int decision,
   int extremeVotes,
   double ADX,
   double ret3ATR,
   double ret12ATR,
   double macdHistATR,
   double Dist_to_resistance_ATR,
   double slPips,
   string &reason
)
{
   reason = "";

   if(!InpDynSL_EnableHighADXWeakPullbackSellFilter)
      return false;

   if(decision != 0) // SELL only
      return false;

   bool veryStrongTrend =
      (ADX >= InpDynSL_MinADXForHighADXWeakPullbackSell);

   bool mediumMoveStillExtended =
      (ret12ATR >= InpDynSL_MinRet12ATRForHighADXWeakPullbackSell) &&
      (ret12ATR <= InpDynSL_MaxRet12ATRForHighADXWeakPullbackSell);

   bool weakShortPullback =
      (ret3ATR <= InpDynSL_MaxRet3ATRForHighADXWeakPullbackSell);

   bool farButNotTooFarFromResistance =
      (Dist_to_resistance_ATR >= InpDynSL_MinDistResATRForHighADXWeakPullbackSell) &&
      (Dist_to_resistance_ATR <= InpDynSL_MaxDistResATRForHighADXWeakPullbackSell);

   bool weakMACDMomentum =
      (macdHistATR <= InpDynSL_MaxMACDHistATRForHighADXWeakPullbackSell);

   bool notEnoughOverboughtConfirmation =
      (extremeVotes <= InpDynSL_MaxExtremeVotesForHighADXWeakPullbackSell);

   bool wideSL =
      (slPips >= InpDynSL_MinSLPipsForHighADXWeakPullbackSell);

   bool badSell =
      veryStrongTrend &&
      mediumMoveStillExtended &&
      weakShortPullback &&
      farButNotTooFarFromResistance &&
      weakMACDMomentum &&
      notEnoughOverboughtConfirmation &&
      wideSL;

   if(badSell)
   {
      reason = StringFormat(
         "HIGH_ADX_WEAK_PULLBACK_SELL->UNSAFE | votes=%d ADX=%.2f ret3ATR=%.2f ret12ATR=%.2f macdHistATR=%.2f DistResATR=%.2f slPips=%.2f",
         extremeVotes,
         ADX,
         ret3ATR,
         ret12ATR,
         macdHistATR,
         Dist_to_resistance_ATR,
         slPips
      );

      return true;
   }

   return false;
}


//+------------------------------------------------------------------+
//| ShouldReclassifyEarlyBullishExpansionSellToUnsafe
//| Blocks SELL entries opened too early during a bullish expansion.
//| The setup is close to resistance and slightly overbought, but there
//| is not enough bearish confirmation yet.
//+------------------------------------------------------------------+
bool ShouldReclassifyEarlyBullishExpansionSellToUnsafe(
   int decision,
   int extremeVotes,
   double ADX,
   double ret3ATR,
   double ret12ATR,
   double macdHistATR,
   double Dist_to_resistance_ATR,
   double slPips,
   string &reason
)
{
   reason = "";

   if(!InpDynSL_EnableEarlyBullishExpansionSellFilter)
      return false;

   if(decision != 0) // SELL only
      return false;

   bool mediumADX =
      (ADX >= InpDynSL_MinADXForEarlyBullishExpansionSell) &&
      (ADX <= InpDynSL_MaxADXForEarlyBullishExpansionSell);

   bool bullishShortMove =
      (ret3ATR >= InpDynSL_MinRet3ATRForEarlyBullishExpansionSell);

   bool bullishMediumMove =
      (ret12ATR >= InpDynSL_MinRet12ATRForEarlyBullishExpansionSell);

   bool nearResistance =
      (Dist_to_resistance_ATR <= InpDynSL_MaxDistResATRForEarlyBullishExpansionSell);

   bool weakReversalMomentum =
      (MathAbs(macdHistATR) <= InpDynSL_MaxAbsMACDHistATRForEarlyBullishExpansionSell);

   bool enoughOverboughtVotes =
      (extremeVotes >= InpDynSL_MinExtremeVotesForEarlyBullishExpansionSell);

   bool wideSL =
      (slPips >= InpDynSL_MinSLPipsForEarlyBullishExpansionSell);

   bool badSell =
      mediumADX &&
      bullishShortMove &&
      bullishMediumMove &&
      nearResistance &&
      weakReversalMomentum &&
      enoughOverboughtVotes &&
      wideSL;

   if(badSell)
   {
      reason = StringFormat(
         "EARLY_BULLISH_EXPANSION_SELL->UNSAFE | votes=%d ADX=%.2f ret3ATR=%.2f ret12ATR=%.2f macdHistATR=%.2f DistResATR=%.2f slPips=%.2f",
         extremeVotes,
         ADX,
         ret3ATR,
         ret12ATR,
         macdHistATR,
         Dist_to_resistance_ATR,
         slPips
      );

      return true;
   }

   return false;
}


//+------------------------------------------------------------------+
//| ShouldReclassifyHighADXBullishPressureWideSLSellToUnsafe
//+------------------------------------------------------------------+
bool ShouldReclassifyHighADXBullishPressureWideSLSellToUnsafe(
   int decision,
   double chosenProb,
   double gap,
   double ADX,
   double CCI,
   double Stochastic,
   double MACD_hist,
   double Dist_to_resistance_ATR,
   double ret12ATR,
   double slPips,
   string &reason
)
{
   reason = "";

   if(!InpDynSL_EnableHighADXBullishPressureWideSLSellFilter)
      return false;

   if(decision != 0) // SELL only
      return false;

   bool weakProbability = chosenProb <= InpDynSL_MaxChosenProbForHighADXBullishPressureWideSLSell;
   bool weakGap         = gap <= InpDynSL_MaxGapForHighADXBullishPressureWideSLSell;
   bool wideSL          = slPips >= InpDynSL_MinSLPipsForHighADXBullishPressureWideSLSell;

   bool highADX         = ADX >= InpDynSL_MinADXForHighADXBullishPressureWideSLSell;
   bool positiveRet12   = ret12ATR >= InpDynSL_MinRet12ATRForHighADXBullishPressureWideSLSell;

   bool pullbackFromResistance =
      Dist_to_resistance_ATR >= InpDynSL_MinDistResATRForHighADXBullishPressureWideSLSell &&
      Dist_to_resistance_ATR <= InpDynSL_MaxDistResATRForHighADXBullishPressureWideSLSell;

   bool bullishCCI      = CCI >= InpDynSL_MinCCIForHighADXBullishPressureWideSLSell;
   bool bullishStoch    = Stochastic >= InpDynSL_MinStochForHighADXBullishPressureWideSLSell;

   bool bullishMACD =
      (!InpDynSL_RequireMACDHistPosForHighADXBullishPressureWideSLSell) ||
      (MACD_hist > 0.0);

   bool badSell =
      weakProbability &&
      weakGap &&
      wideSL &&
      highADX &&
      positiveRet12 &&
      pullbackFromResistance &&
      bullishCCI &&
      bullishStoch &&
      bullishMACD;

   if(badSell)
   {
      reason = StringFormat(
         "HIGH_ADX_BULLISH_PRESSURE_WIDE_SL_SELL->UNSAFE | p=%.5f maxP=%.5f gap=%.5f maxGap=%.5f ADX=%.2f minADX=%.2f CCI=%.2f minCCI=%.2f Stoch=%.2f minStoch=%.2f MACDhist=%.5f DistResATR=%.2f minDistRes=%.2f maxDistRes=%.2f ret12ATR=%.2f minRet12ATR=%.2f slPips=%.2f minSL=%.2f",
         chosenProb,
         InpDynSL_MaxChosenProbForHighADXBullishPressureWideSLSell,
         gap,
         InpDynSL_MaxGapForHighADXBullishPressureWideSLSell,
         ADX,
         InpDynSL_MinADXForHighADXBullishPressureWideSLSell,
         CCI,
         InpDynSL_MinCCIForHighADXBullishPressureWideSLSell,
         Stochastic,
         InpDynSL_MinStochForHighADXBullishPressureWideSLSell,
         MACD_hist,
         Dist_to_resistance_ATR,
         InpDynSL_MinDistResATRForHighADXBullishPressureWideSLSell,
         InpDynSL_MaxDistResATRForHighADXBullishPressureWideSLSell,
         ret12ATR,
         InpDynSL_MinRet12ATRForHighADXBullishPressureWideSLSell,
         slPips,
         InpDynSL_MinSLPipsForHighADXBullishPressureWideSLSell
      );

      return true;
   }

   return false;
}


//+------------------------------------------------------------------+
//| ShouldReclassifyOversoldChaseSellToUnsafe
//| Blocks SELL entries opened too late after a strong bearish move.
//| The setup is close to support and the market is already oversold,
//| so the risk of rebound is high.
//+------------------------------------------------------------------+
bool ShouldReclassifyOversoldChaseSellToUnsafe(
   int decision,
   double RSI,
   double CCI,
   double Stochastic,
   double WPR,
   double ADX,
   double ret12ATR,
   double Dist_to_support_ATR,
   double slPips,
   string &reason
)
{
   reason = "";

   if(!InpDynSL_EnableOversoldChaseSellFilter)
      return false;

   if(decision != 0) // SELL only
      return false;

   bool strongTrend =
      (ADX >= InpDynSL_MinADXForOversoldChaseSell);

   bool extendedBearishMove =
      (ret12ATR >= InpDynSL_MinRet12ATRForOversoldChaseSell);

   bool closeToSupport =
      (Dist_to_support_ATR <= InpDynSL_MaxDistSupATRForOversoldChaseSell);

   bool voteRSI =
      (RSI <= InpDynSL_MaxRSIForOversoldChaseSell);

   bool voteStoch =
      (Stochastic <= InpDynSL_MaxStochForOversoldChaseSell);

   bool voteWPR =
      (WPR <= InpDynSL_MaxWPRForOversoldChaseSell);

   bool voteCCI =
      (CCI <= InpDynSL_MaxCCIForOversoldChaseSell);

   int oversoldVotes = CountTrue(voteRSI, voteStoch, voteWPR, voteCCI);

   bool wideSL =
      (slPips >= InpDynSL_MinSLPipsForOversoldChaseSell);

   bool badSell =
      strongTrend &&
      extendedBearishMove &&
      closeToSupport &&
      (oversoldVotes >= InpDynSL_MinOversoldVotesForOversoldChaseSell) &&
      wideSL;

   if(badSell)
   {
      reason = StringFormat(
         "OVERSOLD_CHASE_SELL->UNSAFE | oversoldVotes=%d ADX=%.2f ret12ATR=%.2f DistSupATR=%.2f RSI=%.2f Stoch=%.2f WPR=%.2f CCI=%.2f slPips=%.2f",
         oversoldVotes,
         ADX,
         ret12ATR,
         Dist_to_support_ATR,
         RSI,
         Stochastic,
         WPR,
         CCI,
         slPips
      );

      return true;
   }

   return false;
}



//+------------------------------------------------------------------+
//| ShouldReclassifyFallingKnifeBuyToUnsafe
//| Detectează BUY-uri de tip falling knife, unde prețul încă poate continua scăderea.
//+------------------------------------------------------------------+
bool ShouldReclassifyFallingKnifeBuyToUnsafe(
   int decision,
   int extremeVotes,
   double MACD_hist,
   double ret12ATR,
   double Dist_to_support_ATR,
   string &reason
)
{
   reason = "";

   if(!InpDynSL_EnableFallingKnifeBuyFilter)
      return false;

   if(decision != 2) // doar BUY
      return false;

   bool oversoldCore =
      (extremeVotes >= InpDynSL_MinExtremeVotesForKnifeBuy) &&
      (Dist_to_support_ATR <= InpDynSL_MaxDistSupATRForKnifeBuy) &&
      (ret12ATR >= InpDynSL_MinRet12ATRForKnifeBuy);

   bool macdStillBearish = (!InpDynSL_RequireMACDHistNegForKnifeBuy) || (MACD_hist < 0.0);

   bool fallingKnifeBuy = oversoldCore && macdStillBearish;

   if(fallingKnifeBuy)
   {
      reason = StringFormat(
         "FALLING_KNIFE_BUY->UNSAFE | votes=%d MACDhist=%.5f ret12ATR=%.2f DistSupATR=%.2f",
         extremeVotes, MACD_hist, ret12ATR, Dist_to_support_ATR
      );
      return true;
   }

   return false;
}




//+------------------------------------------------------------------+
//| ShouldReclassifyBadNormalToUnsafe
//| Reclasifică setup-uri aparent normale în UNSAFE când voturile și contextul indică risc.
//+------------------------------------------------------------------+
bool ShouldReclassifyBadNormalToUnsafe(
   int decision,
   int extremeVotes,
   int unsafeVotes,
   double ADX,
   double ret12ATR,
   double Dist_to_support_ATR,
   double Dist_to_resistance_ATR,
   string &reason
)
{
   reason = "";

   if(!InpDynSL_EnableBadNormalFilter)
      return false;

   //================ BAD NORMAL SELL ================//
   if(decision == 0) // SELL
   {
      bool badNormalSell =
         (extremeVotes >= InpDynSL_MinExtremeVotesForBadSell) &&
         (unsafeVotes >= InpDynSL_MinUnsafeVotesForBadSell) &&
         (
            (ADX >= InpDynSL_MinADXForBadSell) ||
            (ret12ATR >= InpDynSL_MinRet12ATRForBadSell) ||
            (Dist_to_resistance_ATR <= InpDynSL_MaxDistResATRForBadSell)
         );

      if(badNormalSell)
      {
         reason = StringFormat(
            "BAD_NORMAL->UNSAFE SELL | votes=%d unsafeVotes=%d ADX=%.2f ret12ATR=%.2f DistResATR=%.2f",
            extremeVotes, unsafeVotes, ADX, ret12ATR, Dist_to_resistance_ATR
         );
         return true;
      }
   }

   //================ BAD NORMAL BUY ================//
   if(decision == 2) // BUY
   {
      bool badNormalBuy =
         (extremeVotes <= InpDynSL_MaxExtremeVotesForBadBuy) &&
         (unsafeVotes >= InpDynSL_MinUnsafeVotesForBadBuy) &&
         (Dist_to_support_ATR >= InpDynSL_MinDistSupATRForBadBuy) &&
         (ret12ATR >= InpDynSL_MinRet12ATRForBadBuy);

      if(badNormalBuy)
      {
         reason = StringFormat(
            "BAD_NORMAL->UNSAFE BUY | votes=%d unsafeVotes=%d DistSupATR=%.2f ret12ATR=%.2f",
            extremeVotes, unsafeVotes, Dist_to_support_ATR, ret12ATR
         );
         return true;
      }
   }

   return false;
}



bool ShouldReclassifyBullishRegimePullbackWideSLSellToUnsafe(
   int decision,
   double chosenProb,
   double gap,
   double ADX,
   double CCI,
   double Stochastic,
   double MACD_hist,
   double Dist_to_resistance_ATR,
   double ret12ATR,
   double slPips,
   string &reason
)
{
   reason = "";

   if(!InpDynSL_EnableBullishRegimePullbackWideSLSellFilter)
      return false;

   if(decision != 0) // SELL only
      return false;

   bool weakProbability = chosenProb <= InpDynSL_MaxChosenProbForBullishRegimePullbackWideSLSell;
   bool weakDecisionGap = gap <= InpDynSL_MaxGapForBullishRegimePullbackWideSLSell;
   bool wideSL = slPips >= InpDynSL_MinSLPipsForBullishRegimePullbackWideSLSell;

   bool strongADX = ADX >= InpDynSL_MinADXForBullishRegimePullbackWideSLSell;
   bool bullishRet12 = ret12ATR >= InpDynSL_MinRet12ATRForBullishRegimePullbackWideSLSell;

   bool resistanceZone =
      Dist_to_resistance_ATR >= InpDynSL_MinDistResATRForBullishRegimePullbackWideSLSell &&
      Dist_to_resistance_ATR <= InpDynSL_MaxDistResATRForBullishRegimePullbackWideSLSell;

   bool bullishCCI = CCI >= InpDynSL_MinCCIForBullishRegimePullbackWideSLSell;
   bool bullishStoch = Stochastic >= InpDynSL_MinStochForBullishRegimePullbackWideSLSell;

   bool bullishMACD =
      !InpDynSL_RequireMACDHistPosForBullishRegimePullbackWideSLSell ||
      MACD_hist > 0.0;

   bool badSell =
      weakProbability &&
      weakDecisionGap &&
      wideSL &&
      strongADX &&
      bullishRet12 &&
      resistanceZone &&
      bullishCCI &&
      bullishStoch &&
      bullishMACD;

   if(badSell)
   {
      reason = StringFormat(
         "BULLISH_REGIME_PULLBACK_WIDE_SL_SELL->UNSAFE | p=%.5f maxP=%.5f gap=%.5f maxGap=%.5f ADX=%.2f minADX=%.2f CCI=%.2f minCCI=%.2f Stoch=%.2f minStoch=%.2f MACDhist=%.5f DistResATR=%.2f range=%.2f..%.2f ret12ATR=%.2f minRet12ATR=%.2f slPips=%.2f minSL=%.2f",
         chosenProb,
         InpDynSL_MaxChosenProbForBullishRegimePullbackWideSLSell,
         gap,
         InpDynSL_MaxGapForBullishRegimePullbackWideSLSell,
         ADX,
         InpDynSL_MinADXForBullishRegimePullbackWideSLSell,
         CCI,
         InpDynSL_MinCCIForBullishRegimePullbackWideSLSell,
         Stochastic,
         InpDynSL_MinStochForBullishRegimePullbackWideSLSell,
         MACD_hist,
         Dist_to_resistance_ATR,
         InpDynSL_MinDistResATRForBullishRegimePullbackWideSLSell,
         InpDynSL_MaxDistResATRForBullishRegimePullbackWideSLSell,
         ret12ATR,
         InpDynSL_MinRet12ATRForBullishRegimePullbackWideSLSell,
         slPips,
         InpDynSL_MinSLPipsForBullishRegimePullbackWideSLSell
      );

      return true;
   }

   return false;
}




//+------------------------------------------------------------------+
//| DynamicSLSetupType
//| Tipurile interne folosite pentru alegerea distanței Dynamic SL.
//+------------------------------------------------------------------+
enum DynamicSLSetupType
{
   DYN_SL_NORMAL = 0,
   DYN_SL_NOISY_GOOD = 1,
   DYN_SL_UNSAFE = 2
};



//+------------------------------------------------------------------+
//| ClassifyDynamicSLSetup
//| Clasifică setup-ul curent pentru Dynamic SL: normal, noisy-good sau unsafe.
//+------------------------------------------------------------------+
DynamicSLSetupType ClassifyDynamicSLSetup(
   int decision,
   double pSell,
   double pHold,
   double pBuy,
   double closePrice,
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
   double &chosenProb,
   double &secondProb,
   double &gap,
   double &ret3ATR,
   double &ret12ATR,
   double &macdHistATR,
   string &reason
)
{
   chosenProb = 0.0;
   secondProb = 0.0;
   gap = 0.0;
   ret3ATR = 0.0;
   ret12ATR = 0.0;
   macdHistATR = 0.0;
   reason = "NORMAL";

   if(decision == 2) // BUY
   {
      chosenProb = pBuy;
      secondProb = MathMax(pSell, pHold);
   }
   else if(decision == 0) // SELL
   {
      chosenProb = pSell;
      secondProb = MathMax(pBuy, pHold);
   }
   else
   {
      reason = "HOLD";
      return DYN_SL_NORMAL;
   }

   gap         = chosenProb - secondProb;
   ret3ATR     = MathAbs(SafeDiv(Ret_3, ATR));
   ret12ATR    = MathAbs(SafeDiv(Ret_12, ATR));
   macdHistATR = MathAbs(SafeDiv(MACD_hist, ATR));

   //======================== BUY ========================//
   if(decision == 2)
   {
      // confirmari de extrema / capitulare
      bool voteRSI   = (RSI <= InpDynSL_MaxRSIForBuy);
      bool voteCCI   = (CCI <= InpDynSL_MaxCCIForBuy);
      bool voteStoch = (Stochastic <= InpDynSL_MaxStochForBuy);
      bool voteWPR   = (Williams_R <= InpDynSL_MaxWPRForBuy);

      int extremeVotes = CountTrue(voteRSI, voteCCI, voteStoch, voteWPR);

      // nucleu setup noisy-good
      bool coreProb = (!InpDynSL_UseChosenProbCore) || (chosenProb >= InpDynSL_MinChosenProb);
      bool coreGap  = (!InpDynSL_UseGapCore)        || (gap >= InpDynSL_MinGap);
      bool coreDist = (!InpDynSL_UseDistanceCore)   || (Dist_to_support_ATR <= InpDynSL_MaxDistSupATR_Buy);
      bool coreRet3 = (!InpDynSL_UseRet3Core)       || (ret3ATR >= InpDynSL_MinRet3ATRForNoisy);

      bool noisyGoodBuy =
         coreProb &&
         coreGap &&
         coreDist &&
         coreRet3 &&
         (ADX <= InpDynSL_MaxADXForNoisy) &&
         (ret12ATR <= InpDynSL_MaxRet12ATRForNoisy) &&
         (macdHistATR <= InpDynSL_MaxAbsMACDHistATRNoisy) &&
         (extremeVotes >= InpDynSL_MinExtremeVotes);

      // voturi de pericol / trend inca prea viu
      bool unsafeADX    = (ADX >= InpDynSL_MaxADXForUnsafe);
      bool unsafeRet12  = (ret12ATR >= InpDynSL_MinRet12ATRForUnsafe);
      bool unsafeMACD   = (MACD_hist < 0.0 && macdHistATR >= InpDynSL_MinAbsMACDHistATRUnsafe);
      bool unsafeDist   = (Dist_to_support_ATR > InpDynSL_MaxDistSupATR_Buy * 1.50);

      int unsafeVotes = CountTrue(unsafeADX, unsafeRet12, unsafeMACD, unsafeDist);

      bool relaxUnsafe =
         InpDynSL_RelaxUnsafeByGap &&
         (chosenProb >= InpDynSL_StrongProbOverride) &&
         (gap >= InpDynSL_StrongGapOverride);

      bool unsafeBuy =
         !relaxUnsafe &&
         (extremeVotes >= 1) &&
         (unsafeVotes >= InpDynSL_MinUnsafeVotes);



      UpdateRepeatWideSLBuyAfterFastTPMemory();
      
      double repeatWideSLBuyAfterFastTPCheckSLPips =
         ResolveDynamicSLPips(noisyGoodBuy ? DYN_SL_NOISY_GOOD : DYN_SL_NORMAL);
      
      string repeatWideSLBuyAfterFastTPReason = "";
      if(ShouldReclassifyRepeatWideSLBuyAfterFastTPToUnsafe(
            decision,
            repeatWideSLBuyAfterFastTPCheckSLPips,
            TimeCurrent(),
            repeatWideSLBuyAfterFastTPReason))
      {
         if(InpDynSL_LogRepeatWideSLBuyAfterFastTPReclassify)
            reason = repeatWideSLBuyAfterFastTPReason;
         else
            reason = StringFormat(
               "UNSAFE BUY (repeat wide SL after fast TP) | p=%.5f gap=%.5f slPips=%.2f",
               chosenProb,
               gap,
               repeatWideSLBuyAfterFastTPCheckSLPips
            );
      
         return DYN_SL_UNSAFE;
      }


      double weakNormalWideSLBuyCheckSLPips =
         ResolveDynamicSLPips(noisyGoodBuy ? DYN_SL_NOISY_GOOD : DYN_SL_NORMAL);
      
      string weakNormalWideSLBuyReason = "";
      if(!noisyGoodBuy &&
         ShouldReclassifyWeakNormalWideSLBuyToUnsafe(
            decision,
            chosenProb,
            gap,
            weakNormalWideSLBuyCheckSLPips,
            weakNormalWideSLBuyReason))
      {
         if(InpDynSL_LogWeakNormalWideSLBuyReclassify)
            reason = weakNormalWideSLBuyReason;
         else
            reason = StringFormat(
               "UNSAFE BUY (weak normal wide SL) | p=%.5f gap=%.5f slPips=%.2f",
               chosenProb,
               gap,
               weakNormalWideSLBuyCheckSLPips
            );
      
         return DYN_SL_UNSAFE;
      }



      double neutralWideSLBuyCheckSLPips =
         ResolveDynamicSLPips(noisyGoodBuy ? DYN_SL_NOISY_GOOD : DYN_SL_NORMAL);
      
      string neutralWideSLBuyReason = "";
      if(ShouldReclassifyNeutralWideSLBuyToUnsafe(
            decision,
            chosenProb,
            gap,
            ADX,
            ret12ATR,
            macdHistATR,
            Dist_to_support_ATR,
            Dist_to_resistance_ATR,
            neutralWideSLBuyCheckSLPips,
            neutralWideSLBuyReason))
      {
         if(InpDynSL_LogNeutralWideSLBuyReclassify)
            reason = neutralWideSLBuyReason;
         else
            reason = StringFormat(
               "UNSAFE BUY (neutral wide SL) | p=%.5f gap=%.5f slPips=%.2f ADX=%.2f ret12ATR=%.2f macdHistATR=%.2f DistSupATR=%.2f DistResATR=%.2f",
               chosenProb,
               gap,
               neutralWideSLBuyCheckSLPips,
               ADX,
               ret12ATR,
               macdHistATR,
               Dist_to_support_ATR,
               Dist_to_resistance_ATR
            );
      
         return DYN_SL_UNSAFE;
      }



      double highADXBearishWideSLBuyCheckSLPips =
         ResolveDynamicSLPips(noisyGoodBuy ? DYN_SL_NOISY_GOOD : DYN_SL_NORMAL);
      
      string highADXBearishWideSLBuyReason = "";
      if(!noisyGoodBuy &&
         ShouldReclassifyHighADXBearishWideSLBuyToUnsafe(
            decision,
            ADX,
            CCI,
            Williams_R,
            MACD_hist,
            Dist_to_support_ATR,
            highADXBearishWideSLBuyCheckSLPips,
            highADXBearishWideSLBuyReason))
      {
         if(InpDynSL_LogHighADXBearishWideSLBuyReclassify)
            reason = highADXBearishWideSLBuyReason;
         else
            reason = StringFormat(
               "UNSAFE BUY (high ADX bearish wide SL) | ADX=%.2f CCI=%.2f WPR=%.2f MACDhist=%.5f DistSupATR=%.2f slPips=%.2f",
               ADX,
               CCI,
               Williams_R,
               MACD_hist,
               Dist_to_support_ATR,
               highADXBearishWideSLBuyCheckSLPips
            );
      
         return DYN_SL_UNSAFE;
      }


      double bearishSupportWideSLBuyCheckSLPips =
      ResolveDynamicSLPips(noisyGoodBuy ? DYN_SL_NOISY_GOOD : DYN_SL_NORMAL);
      
      string bearishSupportWideSLBuyReason = "";
      if(!noisyGoodBuy &&
         ShouldReclassifyBearishSupportWideSLBuyToUnsafe(
            decision,
            chosenProb,
            gap,
            ADX,
            CCI,
            Williams_R,
            MACD_hist,
            Dist_to_support_ATR,
            bearishSupportWideSLBuyCheckSLPips,
            bearishSupportWideSLBuyReason))
      {
         if(InpDynSL_LogBearishSupportWideSLBuyReclassify)
            reason = bearishSupportWideSLBuyReason;
         else
            reason = StringFormat(
               "UNSAFE BUY (bearish support wide SL) | p=%.5f gap=%.5f ADX=%.2f CCI=%.2f WPR=%.2f MACDhist=%.5f DistSupATR=%.2f slPips=%.2f",
               chosenProb,
               gap,
               ADX,
               CCI,
               Williams_R,
               MACD_hist,
               Dist_to_support_ATR,
               bearishSupportWideSLBuyCheckSLPips
            );
      
         return DYN_SL_UNSAFE;
      }
      
      
      double bearishPullbackWideSLBuyCheckSLPips =
         ResolveDynamicSLPips(noisyGoodBuy ? DYN_SL_NOISY_GOOD : DYN_SL_NORMAL);
      
      string bearishPullbackWideSLBuyReason = "";
      if(!noisyGoodBuy &&
         ShouldReclassifyBearishPullbackWideSLBuyToUnsafe(
            decision,
            chosenProb,
            gap,
            ADX,
            CCI,
            Williams_R,
            Stochastic,
            MACD_hist,
            Dist_to_support_ATR,
            ret12ATR,
            bearishPullbackWideSLBuyCheckSLPips,
            bearishPullbackWideSLBuyReason))
      {
         if(InpDynSL_LogBearishPullbackWideSLBuyReclassify)
            reason = bearishPullbackWideSLBuyReason;
         else
            reason = StringFormat(
               "UNSAFE BUY (bearish pullback wide SL) | p=%.5f gap=%.5f ADX=%.2f CCI=%.2f WPR=%.2f Stoch=%.2f MACDhist=%.5f DistSupATR=%.2f ret12ATR=%.2f slPips=%.2f",
               chosenProb,
               gap,
               ADX,
               CCI,
               Williams_R,
               Stochastic,
               MACD_hist,
               Dist_to_support_ATR,
               ret12ATR,
               bearishPullbackWideSLBuyCheckSLPips
            );
      
         return DYN_SL_UNSAFE;
      }
      
      
      
      string fallingKnifeReason = "";
      if(ShouldReclassifyFallingKnifeBuyToUnsafe(
            decision,
            extremeVotes,
            MACD_hist,
            ret12ATR,
            Dist_to_support_ATR,
            fallingKnifeReason))
      {
         if(InpDynSL_LogFallingKnifeBuyReclassify)
            reason = fallingKnifeReason;
         else
            reason = StringFormat(
               "UNSAFE BUY (falling knife) | p=%.5f gap=%.5f votes=%d MACDhist=%.5f ret12ATR=%.2f DistSupATR=%.2f",
               chosenProb, gap, extremeVotes, MACD_hist, ret12ATR, Dist_to_support_ATR
            );

         return DYN_SL_UNSAFE;
      }

      
      double strongBearishImpulseWideSLBuyCheckSLPips =
         ResolveDynamicSLPips(noisyGoodBuy ? DYN_SL_NOISY_GOOD : DYN_SL_NORMAL);
      
      string strongBearishImpulseWideSLBuyReason = "";
      if(!noisyGoodBuy &&
         ShouldReclassifyStrongBearishImpulseWideSLBuyToUnsafe(
            decision,
            chosenProb,
            gap,
            RSI,
            ADX,
            CCI,
            MACD_hist,
            Williams_R,
            Dist_to_support_ATR,
            Ret_3,
            Ret_12,
            strongBearishImpulseWideSLBuyCheckSLPips,
            strongBearishImpulseWideSLBuyReason))
      {
         if(InpDynSL_LogStrongBearishImpulseWideSLBuyReclassify)
            reason = strongBearishImpulseWideSLBuyReason;
         else
            reason = StringFormat(
               "UNSAFE BUY strong bearish impulse wide SL | p=%.5f gap=%.5f RSI=%.2f ADX=%.2f CCI=%.2f MACDhist=%.5f WPR=%.2f DistSupATR=%.2f Ret3=%.5f Ret12=%.5f slPips=%.2f",
               chosenProb,
               gap,
               RSI,
               ADX,
               CCI,
               MACD_hist,
               Williams_R,
               Dist_to_support_ATR,
               Ret_3,
               Ret_12,
               strongBearishImpulseWideSLBuyCheckSLPips
            );
      
         return DYN_SL_UNSAFE;
      }
  
  
      
      double overboughtNearResistanceWideSLBuyCheckSLPips =
         ResolveDynamicSLPips(noisyGoodBuy ? DYN_SL_NOISY_GOOD : DYN_SL_NORMAL);
      
      string overboughtNearResistanceWideSLBuyReason = "";
      if(!noisyGoodBuy &&
         ShouldReclassifyOverboughtNearResistanceWideSLBuyToUnsafe(
            decision,
            chosenProb,
            gap,
            RSI,
            ADX,
            CCI,
            Stochastic,
            Williams_R,
            Dist_to_support_ATR,
            Dist_to_resistance_ATR,
            overboughtNearResistanceWideSLBuyCheckSLPips,
            overboughtNearResistanceWideSLBuyReason))
      {
         if(InpDynSL_LogOverboughtNearResistanceWideSLBuyReclassify)
            reason = overboughtNearResistanceWideSLBuyReason;
         else
            reason = StringFormat(
               "UNSAFE BUY overbought near resistance wide SL | p=%.5f gap=%.5f RSI=%.2f ADX=%.2f CCI=%.2f Stoch=%.2f WPR=%.2f DistResATR=%.2f DistSupATR=%.2f slPips=%.2f",
               chosenProb,
               gap,
               RSI,
               ADX,
               CCI,
               Stochastic,
               Williams_R,
               Dist_to_resistance_ATR,
               Dist_to_support_ATR,
               overboughtNearResistanceWideSLBuyCheckSLPips
            );
      
         return DYN_SL_UNSAFE;
      }
      
      
      double weakLateBullishBreakoutWideSLBuyCheckSLPips =
         ResolveDynamicSLPips(noisyGoodBuy ? DYN_SL_NOISY_GOOD : DYN_SL_NORMAL);
      
      string weakLateBullishBreakoutWideSLBuyReason = "";
      if(!noisyGoodBuy &&
         ShouldReclassifyWeakLateBullishBreakoutWideSLBuyToUnsafe(
            decision,
            chosenProb,
            gap,
            ADX,
            CCI,
            MACD_hist,
            Dist_to_support_ATR,
            Ret_3,
            Ret_12,
            weakLateBullishBreakoutWideSLBuyCheckSLPips,
            weakLateBullishBreakoutWideSLBuyReason))
      {
         if(InpDynSL_LogWeakLateBullishBreakoutWideSLBuyReclassify)
            reason = weakLateBullishBreakoutWideSLBuyReason;
         else
            reason = StringFormat(
               "UNSAFE BUY weak late bullish breakout wide SL | p=%.5f gap=%.5f ADX=%.2f CCI=%.2f MACDhist=%.5f DistSupATR=%.2f Ret3=%.5f Ret12=%.5f slPips=%.2f",
               chosenProb,
               gap,
               ADX,
               CCI,
               MACD_hist,
               Dist_to_support_ATR,
               Ret_3,
               Ret_12,
               weakLateBullishBreakoutWideSLBuyCheckSLPips
            );
      
         return DYN_SL_UNSAFE;
      }
      
      
      

      string weakReboundBuyReason = "";
      if(ShouldReclassifyWeakReboundBuyToUnsafe(
            decision,
            extremeVotes,
            MACD_hist,
            ADX,
            ret12ATR,
            Dist_to_support_ATR,
            weakReboundBuyReason))
      {
         if(InpDynSL_LogWeakReboundBuyReclassify)
            reason = weakReboundBuyReason;
         else
            reason = StringFormat(
               "UNSAFE BUY (weak rebound) | p=%.5f gap=%.5f votes=%d ADX=%.2f ret12ATR=%.2f MACDhist=%.5f DistSupATR=%.2f",
               chosenProb, gap, extremeVotes, ADX, ret12ATR, MACD_hist, Dist_to_support_ATR
            );

         return DYN_SL_UNSAFE;
      }


      string midReboundBuyReason = "";
      if(ShouldReclassifyMidReboundBuyToUnsafe(
            decision,
            extremeVotes,
            unsafeVotes,
            ADX,
            ret12ATR,
            macdHistATR,
            Dist_to_support_ATR,
            midReboundBuyReason))
      {
         if(InpDynSL_LogMidReboundBuyReclassify)
            reason = midReboundBuyReason;
         else
            reason = StringFormat(
               "UNSAFE BUY (mid rebound) | p=%.5f gap=%.5f votes=%d unsafeVotes=%d ADX=%.2f ret12ATR=%.2f macdHistATR=%.2f DistSupATR=%.2f",
               chosenProb, gap, extremeVotes, unsafeVotes, ADX, ret12ATR, macdHistATR, Dist_to_support_ATR
            );

	         return DYN_SL_UNSAFE;
	      }
	      
	      
	      double lateSessionWeakWideSLBuyCheckSLPips =
	         ResolveDynamicSLPips(noisyGoodBuy ? DYN_SL_NOISY_GOOD : DYN_SL_NORMAL);
	      
	      string lateSessionWeakWideSLBuyReason = "";
	      if(!noisyGoodBuy &&
	         ShouldReclassifyLateSessionWeakWideSLBuyToUnsafe(
	            decision,
	            chosenProb,
	            gap,
	            ADX,
	            CCI,
	            Stochastic,
	            Williams_R,
	            MACD_hist,
	            Dist_to_support_ATR,
	            Ret_12,
	            ATR,
	            lateSessionWeakWideSLBuyCheckSLPips,
	            TimeCurrent(),
	            lateSessionWeakWideSLBuyReason))
	      {
	         if(InpDynSL_LogLateSessionWeakWideSLBuyReclassify)
	            reason = lateSessionWeakWideSLBuyReason;
	         else
	            reason = "UNSAFE BUY late session weak wide SL";
	      
	         return DYN_SL_UNSAFE;
	      }
	      
	      
	      double bearishContinuationNormalWideBuySLPips =
	         ResolveDynamicSLPips(noisyGoodBuy ? DYN_SL_NOISY_GOOD : DYN_SL_NORMAL);
	      
	      string bearishContinuationNormalWideBuyReason = "";
	      if(!noisyGoodBuy &&
	         ShouldReclassifyBearishContinuationNormalWideBuyToUnsafe(
	            decision,
	            chosenProb,
	            gap,
	            ADX,
	            CCI,
	            Stochastic,
	            Williams_R,
	            MACD_hist,
	            Dist_to_support_ATR,
	            Ret_12,
	            ATR,
	            bearishContinuationNormalWideBuySLPips,
	            bearishContinuationNormalWideBuyReason))
	      {
	         if(InpDynSL_BCNW_Log)
	            reason = bearishContinuationNormalWideBuyReason;
	         else
	            reason = "UNSAFE BUY bearish continuation normal wide SL";
	      
	         return DYN_SL_UNSAFE;
	      }
	      
	      
	      double extremeOversoldFalseWideBuySLPips =
	         ResolveDynamicSLPips(noisyGoodBuy ? DYN_SL_NOISY_GOOD : DYN_SL_NORMAL);
      
      string extremeOversoldFalseWideBuyReason = "";
      if(!noisyGoodBuy &&
         ShouldReclassifyExtremeOversoldFalseWideBuyToUnsafe(
            decision,
            chosenProb,
            gap,
            ADX,
            CCI,
            Williams_R,
            MACD_hist,
            Dist_to_support_ATR,
            extremeOversoldFalseWideBuySLPips,
            extremeOversoldFalseWideBuyReason))
      {
         if(InpDynSL_XOFW_Log)
            reason = extremeOversoldFalseWideBuyReason;
         else
            reason = "UNSAFE BUY extreme oversold false reversal wide SL";
      
         return DYN_SL_UNSAFE;
      }
      
      
       // BAD NORMAL detector for BUY
      string badNormalReason = "";
      if(ShouldReclassifyBadNormalToUnsafe(
            decision,
            extremeVotes,
            unsafeVotes,
            ADX,
            ret12ATR,
            Dist_to_support_ATR,
            Dist_to_resistance_ATR,
            badNormalReason))
      {
         if(InpDynSL_LogBadNormalReclassify)
            reason = badNormalReason;
         else
            reason = StringFormat(
               "UNSAFE BUY (bad normal) | p=%.5f gap=%.5f votes=%d unsafeVotes=%d ADX=%.2f ret12ATR=%.2f DistSupATR=%.2f",
               chosenProb, gap, extremeVotes, unsafeVotes, ADX, ret12ATR, Dist_to_support_ATR
            );

         return DYN_SL_UNSAFE;
      }
         

      if(unsafeBuy)
      {
         reason = StringFormat(
            "UNSAFE BUY | p=%.5f gap=%.5f votes=%d unsafeVotes=%d ADX=%.2f ret3ATR=%.2f ret12ATR=%.2f macdHistATR=%.2f DistSupATR=%.2f RSI=%.2f CCI=%.2f Stoch=%.2f WPR=%.2f",
            chosenProb, gap, extremeVotes, unsafeVotes, ADX, ret3ATR, ret12ATR, macdHistATR,
            Dist_to_support_ATR, RSI, CCI, Stochastic, Williams_R
         );
         return DYN_SL_UNSAFE;
      }

      if(noisyGoodBuy)
      {
         reason = StringFormat(
            "NOISY_GOOD BUY | p=%.5f gap=%.5f votes=%d unsafeVotes=%d ADX=%.2f ret3ATR=%.2f ret12ATR=%.2f macdHistATR=%.2f DistSupATR=%.2f RSI=%.2f CCI=%.2f Stoch=%.2f WPR=%.2f",
            chosenProb, gap, extremeVotes, unsafeVotes, ADX, ret3ATR, ret12ATR, macdHistATR,
            Dist_to_support_ATR, RSI, CCI, Stochastic, Williams_R
         );
         return DYN_SL_NOISY_GOOD;
      }
   

      reason = StringFormat(
         "NORMAL BUY | p=%.5f gap=%.5f votes=%d unsafeVotes=%d ADX=%.2f ret3ATR=%.2f ret12ATR=%.2f macdHistATR=%.2f DistSupATR=%.2f",
         chosenProb, gap, extremeVotes, unsafeVotes, ADX, ret3ATR, ret12ATR, macdHistATR, Dist_to_support_ATR
      );
      return DYN_SL_NORMAL;
   }

   //======================== SELL ========================//
   if(decision == 0)
   {
      // confirmari de extrema / epuizare sus
      bool voteRSI   = (RSI >= InpDynSL_MinRSIForSell);
      bool voteCCI   = (CCI >= InpDynSL_MinCCIForSell);
      bool voteStoch = (Stochastic >= InpDynSL_MinStochForSell);
      bool voteWPR   = (Williams_R >= InpDynSL_MinWPRForSell);

      int extremeVotes = CountTrue(voteRSI, voteCCI, voteStoch, voteWPR);

      // nucleu setup noisy-good
      bool coreProb = (!InpDynSL_UseChosenProbCore) || (chosenProb >= InpDynSL_MinChosenProb);
      bool coreGap  = (!InpDynSL_UseGapCore)        || (gap >= InpDynSL_MinGap);
      bool coreDist = (!InpDynSL_UseDistanceCore)   || (Dist_to_resistance_ATR <= InpDynSL_MaxDistResATR_Sell);
      bool coreRet3 = (!InpDynSL_UseRet3Core)       || (ret3ATR >= InpDynSL_MinRet3ATRForNoisy);

      bool noisyGoodSell =
         coreProb &&
         coreGap &&
         coreDist &&
         coreRet3 &&
         (ADX <= InpDynSL_MaxADXForNoisy) &&
         (ret12ATR <= InpDynSL_MaxRet12ATRForNoisy) &&
         (macdHistATR <= InpDynSL_MaxAbsMACDHistATRNoisy) &&
         (extremeVotes >= InpDynSL_MinExtremeVotes);

      // voturi de pericol / trend inca prea viu sus
      bool unsafeADX    = (ADX >= InpDynSL_MaxADXForUnsafe);
      bool unsafeRet12  = (ret12ATR >= InpDynSL_MinRet12ATRForUnsafe);
      bool unsafeMACD   = (MACD_hist > 0.0 && macdHistATR >= InpDynSL_MinAbsMACDHistATRUnsafe);
      bool unsafeDist   = (Dist_to_resistance_ATR > InpDynSL_MaxDistResATR_Sell * 1.50);

      int unsafeVotes = CountTrue(unsafeADX, unsafeRet12, unsafeMACD, unsafeDist);

      bool relaxUnsafe =
         InpDynSL_RelaxUnsafeByGap &&
         (chosenProb >= InpDynSL_StrongProbOverride) &&
         (gap >= InpDynSL_StrongGapOverride);

      bool unsafeSell =
         !relaxUnsafe &&
         (extremeVotes >= 1) &&
         (unsafeVotes >= InpDynSL_MinUnsafeVotes);
     

      string localOverboughtSellReason = "";
      if(ShouldReclassifyLocalOverboughtSellToUnsafe(
            decision,
            extremeVotes,
            unsafeVotes,
            ADX,
            ret12ATR,
            macdHistATR,
            Dist_to_resistance_ATR,
            localOverboughtSellReason))
      {
         if(InpDynSL_LogLocalOverboughtSellReclassify)
            reason = localOverboughtSellReason;
         else
            reason = StringFormat(
               "UNSAFE SELL (local overbought) | p=%.5f gap=%.5f votes=%d unsafeVotes=%d ADX=%.2f ret12ATR=%.2f macdHistATR=%.2f DistResATR=%.2f",
               chosenProb, gap, extremeVotes, unsafeVotes, ADX, ret12ATR, macdHistATR, Dist_to_resistance_ATR
            );

         return DYN_SL_UNSAFE;
      }


      string localFadeSellWeakReason = "";
      if(ShouldReclassifyLocalFadeSellWeakToUnsafe(
            decision,
            extremeVotes,
            unsafeVotes,
            ADX,
            CCI,
            Williams_R,
            ret12ATR,
            macdHistATR,
            Dist_to_resistance_ATR,
            localFadeSellWeakReason))
      {
         if(InpDynSL_LogLocalFadeSellWeakReclassify)
            reason = localFadeSellWeakReason;
         else
            reason = StringFormat(
               "UNSAFE SELL (local fade weak) | p=%.5f gap=%.5f votes=%d unsafeVotes=%d ADX=%.2f CCI=%.2f WPR=%.2f ret12ATR=%.2f macdHistATR=%.2f DistResATR=%.2f",
               chosenProb, gap, extremeVotes, unsafeVotes, ADX, CCI, Williams_R, ret12ATR, macdHistATR, Dist_to_resistance_ATR
            );
      
         return DYN_SL_UNSAFE;
      }


      string strongUptrendSellReason = "";
      if(ShouldReclassifyOverboughtSellInStrongUptrendToUnsafe(
            decision,
            extremeVotes,
            MACD_hist,
            ADX,
            ret12ATR,
            Dist_to_resistance_ATR,
            strongUptrendSellReason))
      {
         if(InpDynSL_LogStrongUptrendSellReclassify)
            reason = strongUptrendSellReason;
         else
            reason = StringFormat(
               "UNSAFE SELL (strong uptrend) | p=%.5f gap=%.5f votes=%d ADX=%.2f ret12ATR=%.2f MACDhist=%.5f DistResATR=%.2f",
               chosenProb, gap, extremeVotes, ADX, ret12ATR, MACD_hist, Dist_to_resistance_ATR
            );

         return DYN_SL_UNSAFE;
      }
      
      
      string strongUptrendContinuationSellReason = "";
      if(ShouldReclassifyStrongUptrendContinuationSellToUnsafe(
            decision,
            RSI,
            CCI,
            Stochastic,
            MACD_hist,
            ADX,
            ret12ATR,
            macdHistATR,
            Dist_to_resistance_ATR,
            strongUptrendContinuationSellReason))
      {
         if(InpDynSL_LogStrongUptrendContinuationSellReclassify)
            reason = strongUptrendContinuationSellReason;
         else
            reason = StringFormat(
               "UNSAFE SELL (strong uptrend continuation) | p=%.5f gap=%.5f ADX=%.2f ret12ATR=%.2f macdHistATR=%.2f DistResATR=%.2f RSI=%.2f Stoch=%.2f CCI=%.2f",
               chosenProb,
               gap,
               ADX,
               ret12ATR,
               macdHistATR,
               Dist_to_resistance_ATR,
               RSI,
               Stochastic,
               CCI
            );
      
         return DYN_SL_UNSAFE;
      }
      
      
      double lateSessionCheckSLPips =
         ResolveDynamicSLPips(noisyGoodSell ? DYN_SL_NOISY_GOOD : DYN_SL_NORMAL);
      
      string lateSessionWideSLSellReason = "";
      if(ShouldReclassifyLateSessionWideSLSellToUnsafe(
            decision,
            ADX,
            ret12ATR,
            macdHistATR,
            Dist_to_resistance_ATR,
            lateSessionCheckSLPips,
            TimeCurrent(),
            lateSessionWideSLSellReason))
      {
         if(InpDynSL_LogLateSessionWideSLSellReclassify)
            reason = lateSessionWideSLSellReason;
         else
            reason = StringFormat(
               "UNSAFE SELL (late session wide SL) | p=%.5f gap=%.5f slPips=%.2f ADX=%.2f ret12ATR=%.2f macdHistATR=%.2f DistResATR=%.2f",
               chosenProb,
               gap,
               lateSessionCheckSLPips,
               ADX,
               ret12ATR,
               macdHistATR,
               Dist_to_resistance_ATR
            );
      
         return DYN_SL_UNSAFE;
      }
      
      
      double highADXWeakPullbackCheckSLPips =
      ResolveDynamicSLPips(noisyGoodSell ? DYN_SL_NOISY_GOOD : DYN_SL_NORMAL);
      
      string highADXWeakPullbackSellReason = "";
      if(ShouldReclassifyHighADXWeakPullbackSellToUnsafe(
            decision,
            extremeVotes,
            ADX,
            ret3ATR,
            ret12ATR,
            macdHistATR,
            Dist_to_resistance_ATR,
            highADXWeakPullbackCheckSLPips,
            highADXWeakPullbackSellReason))
      {
         if(InpDynSL_LogHighADXWeakPullbackSellReclassify)
            reason = highADXWeakPullbackSellReason;
         else
            reason = StringFormat(
               "UNSAFE SELL (high ADX weak pullback) | p=%.5f gap=%.5f votes=%d slPips=%.2f ADX=%.2f ret3ATR=%.2f ret12ATR=%.2f macdHistATR=%.2f DistResATR=%.2f",
               chosenProb,
               gap,
               extremeVotes,
               highADXWeakPullbackCheckSLPips,
               ADX,
               ret3ATR,
               ret12ATR,
               macdHistATR,
               Dist_to_resistance_ATR
            );
      
         return DYN_SL_UNSAFE;
      }


      double earlyBullishExpansionCheckSLPips =
         ResolveDynamicSLPips(noisyGoodSell ? DYN_SL_NOISY_GOOD : DYN_SL_NORMAL);
      
      string earlyBullishExpansionSellReason = "";
      if(ShouldReclassifyEarlyBullishExpansionSellToUnsafe(
            decision,
            extremeVotes,
            ADX,
            ret3ATR,
            ret12ATR,
            macdHistATR,
            Dist_to_resistance_ATR,
            earlyBullishExpansionCheckSLPips,
            earlyBullishExpansionSellReason))
      {
         if(InpDynSL_LogEarlyBullishExpansionSellReclassify)
            reason = earlyBullishExpansionSellReason;
         else
            reason = StringFormat(
               "UNSAFE SELL (early bullish expansion) | p=%.5f gap=%.5f votes=%d slPips=%.2f ADX=%.2f ret3ATR=%.2f ret12ATR=%.2f macdHistATR=%.2f DistResATR=%.2f",
               chosenProb,
               gap,
               extremeVotes,
               earlyBullishExpansionCheckSLPips,
               ADX,
               ret3ATR,
               ret12ATR,
               macdHistATR,
               Dist_to_resistance_ATR
            );
      
         return DYN_SL_UNSAFE;
      }
      
      
      double weakNormalWideSLSellCheckSLPips =
      ResolveDynamicSLPips(noisyGoodSell ? DYN_SL_NOISY_GOOD : DYN_SL_NORMAL);
      
      string weakNormalWideSLSellReason = "";
      if(!noisyGoodSell &&
         ShouldReclassifyWeakNormalWideSLSellToUnsafe(
            decision,
            chosenProb,
            gap,
            ADX,
            Williams_R,
            Dist_to_resistance_ATR,
            weakNormalWideSLSellCheckSLPips,
            weakNormalWideSLSellReason))
      {
         if(InpDynSL_LogWeakNormalWideSLSellReclassify)
            reason = weakNormalWideSLSellReason;
         else
            reason = StringFormat(
               "UNSAFE SELL (weak normal wide SL) | p=%.5f gap=%.5f ADX=%.2f WPR=%.2f DistResATR=%.2f slPips=%.2f",
               chosenProb,
               gap,
               ADX,
               Williams_R,
               Dist_to_resistance_ATR,
               weakNormalWideSLSellCheckSLPips
            );
      
         return DYN_SL_UNSAFE;
      }



      double highADXBullishPressureWideSLSellCheckSLPips =
      ResolveDynamicSLPips(noisyGoodSell ? DYN_SL_NOISY_GOOD : DYN_SL_NORMAL);
      
      string highADXBullishPressureWideSLSellReason = "";
      if(!noisyGoodSell &&
         ShouldReclassifyHighADXBullishPressureWideSLSellToUnsafe(
            decision,
            chosenProb,
            gap,
            ADX,
            CCI,
            Stochastic,
            MACD_hist,
            Dist_to_resistance_ATR,
            ret12ATR,
            highADXBullishPressureWideSLSellCheckSLPips,
            highADXBullishPressureWideSLSellReason))
      {
         if(InpDynSL_LogHighADXBullishPressureWideSLSellReclassify)
            reason = highADXBullishPressureWideSLSellReason;
         else
            reason = StringFormat(
               "UNSAFE SELL (high ADX bullish pressure wide SL) | p=%.5f gap=%.5f ADX=%.2f CCI=%.2f Stoch=%.2f MACDhist=%.5f DistResATR=%.2f ret12ATR=%.2f slPips=%.2f",
               chosenProb,
               gap,
               ADX,
               CCI,
               Stochastic,
               MACD_hist,
               Dist_to_resistance_ATR,
               ret12ATR,
               highADXBullishPressureWideSLSellCheckSLPips
            );
      
         return DYN_SL_UNSAFE;
      }


      double bullishMomentumWideSLSellCheckSLPips =
      ResolveDynamicSLPips(noisyGoodSell ? DYN_SL_NOISY_GOOD : DYN_SL_NORMAL);
      
      string bullishMomentumWideSLSellReason = "";
      if(!noisyGoodSell &&
         ShouldReclassifyBullishMomentumWideSLSellToUnsafe(
            decision,
            chosenProb,
            gap,
            ADX,
            CCI,
            Stochastic,
            MACD_hist,
            Dist_to_resistance_ATR,
            ret3ATR,
            bullishMomentumWideSLSellCheckSLPips,
            bullishMomentumWideSLSellReason))
      {
         if(InpDynSL_LogBullishMomentumWideSLSellReclassify)
            reason = bullishMomentumWideSLSellReason;
         else
            reason = StringFormat(
               "UNSAFE SELL (bullish momentum wide SL) | p=%.5f gap=%.5f ADX=%.2f CCI=%.2f Stoch=%.2f MACDhist=%.5f DistResATR=%.2f ret3ATR=%.2f slPips=%.2f",
               chosenProb,
               gap,
               ADX,
               CCI,
               Stochastic,
               MACD_hist,
               Dist_to_resistance_ATR,
               ret3ATR,
               bullishMomentumWideSLSellCheckSLPips
            );
      
         return DYN_SL_UNSAFE;
      }

      
      double bullishRegimePullbackWideSLSellCheckSLPips =
      ResolveDynamicSLPips(noisyGoodSell ? DYN_SL_NOISY_GOOD : DYN_SL_NORMAL);
      
      string bullishRegimePullbackWideSLSellReason = "";
      if(!noisyGoodSell &&
         ShouldReclassifyBullishRegimePullbackWideSLSellToUnsafe(
            decision,
            chosenProb,
            gap,
            ADX,
            CCI,
            Stochastic,
            MACD_hist,
            Dist_to_resistance_ATR,
            ret12ATR,
            bullishRegimePullbackWideSLSellCheckSLPips,
            bullishRegimePullbackWideSLSellReason))
      {
         if(InpDynSL_LogBullishRegimePullbackWideSLSellReclassify)
            reason = bullishRegimePullbackWideSLSellReason;
         else
            reason = "UNSAFE SELL (bullish regime pullback wide SL)";
      
         return DYN_SL_UNSAFE;
      }
      
      
      double bullishBreakoutContinuationWideSLSellCheckSLPips =
         ResolveDynamicSLPips(noisyGoodSell ? DYN_SL_NOISY_GOOD : DYN_SL_NORMAL);
      
      string bullishBreakoutContinuationWideSLSellReason = "";
      if(!noisyGoodSell &&
         ShouldReclassifyBullishBreakoutContinuationWideSLSellToUnsafe(
            decision,
            chosenProb,
            gap,
            ADX,
            CCI,
            Williams_R,
            MACD_hist,
            Dist_to_resistance_ATR,
            ret3ATR,
            ret12ATR,
            bullishBreakoutContinuationWideSLSellCheckSLPips,
            bullishBreakoutContinuationWideSLSellReason))
      {
         if(InpDynSL_BBCS_Log)
            reason = bullishBreakoutContinuationWideSLSellReason;
         else
            reason = StringFormat(
               "UNSAFE SELL bullish breakout continuation wide SL | p=%.5f gap=%.5f ADX=%.2f CCI=%.2f WPR=%.2f MACDhist=%.5f DistResATR=%.2f ret3ATR=%.2f ret12ATR=%.2f slPips=%.2f",
               chosenProb,
               gap,
               ADX,
               CCI,
               Williams_R,
               MACD_hist,
               Dist_to_resistance_ATR,
               ret3ATR,
               ret12ATR,
               bullishBreakoutContinuationWideSLSellCheckSLPips
            );
      
         return DYN_SL_UNSAFE;
      }
            
      
      double oversoldChaseSellCheckSLPips =
      ResolveDynamicSLPips(noisyGoodSell ? DYN_SL_NOISY_GOOD : DYN_SL_NORMAL);
      
      string oversoldChaseSellReason = "";
      if(ShouldReclassifyOversoldChaseSellToUnsafe(
            decision,
            RSI,
            CCI,
            Stochastic,
            Williams_R,
            ADX,
            ret12ATR,
            Dist_to_support_ATR,
            oversoldChaseSellCheckSLPips,
            oversoldChaseSellReason))
      {
         if(InpDynSL_LogOversoldChaseSellReclassify)
            reason = oversoldChaseSellReason;
         else
            reason = StringFormat(
               "UNSAFE SELL (oversold chase) | p=%.5f gap=%.5f slPips=%.2f ADX=%.2f ret12ATR=%.2f DistSupATR=%.2f RSI=%.2f Stoch=%.2f WPR=%.2f CCI=%.2f",
               chosenProb,
               gap,
               oversoldChaseSellCheckSLPips,
               ADX,
               ret12ATR,
               Dist_to_support_ATR,
               RSI,
               Stochastic,
               Williams_R,
               CCI
            );
      
         return DYN_SL_UNSAFE;
      }
      
      
      
      string lateSellChaseReason = "";
      if(ShouldReclassifyLateSellChaseToUnsafe(
            decision,
            extremeVotes,
            unsafeVotes,
            ADX,
            MACD_hist,
            ret12ATR,
            Dist_to_resistance_ATR,
            lateSellChaseReason))
      {
         if(InpDynSL_LogLateSellChaseReclassify)
            reason = lateSellChaseReason;
         else
            reason = StringFormat(
               "UNSAFE SELL (late chase) | p=%.5f gap=%.5f votes=%d unsafeVotes=%d ADX=%.2f MACDhist=%.5f ret12ATR=%.2f DistResATR=%.2f",
               chosenProb, gap, extremeVotes, unsafeVotes, ADX, MACD_hist, ret12ATR, Dist_to_resistance_ATR
            );

         return DYN_SL_UNSAFE;
      }
      
      
      string semiUnsafeSellReason = "";
      if(ShouldReclassifySemiUnsafeSellToUnsafe(
            decision,
            extremeVotes,
            unsafeVotes,
            ADX,
            ret12ATR,
            macdHistATR,
            Dist_to_resistance_ATR,
            semiUnsafeSellReason))
      {
         if(InpDynSL_LogSemiUnsafeSellReclassify)
            reason = semiUnsafeSellReason;
         else
            reason = StringFormat(
               "UNSAFE SELL (semi-unsafe) | p=%.5f gap=%.5f votes=%d unsafeVotes=%d ADX=%.2f ret12ATR=%.2f macdHistATR=%.2f DistResATR=%.2f",
               chosenProb, gap, extremeVotes, unsafeVotes, ADX, ret12ATR, macdHistATR, Dist_to_resistance_ATR
            );

         return DYN_SL_UNSAFE;
      }

      string weakNeutralSellReason = "";
      if(ShouldReclassifyWeakNeutralSellToUnsafe(
            decision,
            extremeVotes,
            unsafeVotes,
            ADX,
            ret12ATR,
            macdHistATR,
            Dist_to_resistance_ATR,
            weakNeutralSellReason))
      {
         if(InpDynSL_LogWeakNeutralSellReclassify)
            reason = weakNeutralSellReason;
         else
            reason = StringFormat(
               "UNSAFE SELL (weak neutral) | p=%.5f gap=%.5f votes=%d unsafeVotes=%d ADX=%.2f ret12ATR=%.2f macdHistATR=%.2f DistResATR=%.2f",
               chosenProb, gap, extremeVotes, unsafeVotes, ADX, ret12ATR, macdHistATR, Dist_to_resistance_ATR
            );
      
         return DYN_SL_UNSAFE;
      }
   
      string weakSellReason = "";
      if(ShouldReclassifyWeakSellToUnsafe(
            decision,
            extremeVotes,
            unsafeVotes,
            ADX,
            ret12ATR,
            Dist_to_resistance_ATR,
            weakSellReason))
      {
         if(InpDynSL_LogWeakSellReclassify)
            reason = weakSellReason;
         else
            reason = StringFormat(
               "UNSAFE SELL (weak setup) | p=%.5f gap=%.5f votes=%d unsafeVotes=%d ADX=%.2f ret12ATR=%.2f DistResATR=%.2f",
               chosenProb, gap, extremeVotes, unsafeVotes, ADX, ret12ATR, Dist_to_resistance_ATR
            );

         return DYN_SL_UNSAFE;
      }
      
        
      

      if(unsafeSell)
      {
         reason = StringFormat(
            "UNSAFE SELL | p=%.5f gap=%.5f votes=%d unsafeVotes=%d ADX=%.2f ret3ATR=%.2f ret12ATR=%.2f macdHistATR=%.2f DistResATR=%.2f RSI=%.2f CCI=%.2f Stoch=%.2f WPR=%.2f",
            chosenProb, gap, extremeVotes, unsafeVotes, ADX, ret3ATR, ret12ATR, macdHistATR,
            Dist_to_resistance_ATR, RSI, CCI, Stochastic, Williams_R
         );
         return DYN_SL_UNSAFE;
      }

      if(noisyGoodSell)
      {
         reason = StringFormat(
            "NOISY_GOOD SELL | p=%.5f gap=%.5f votes=%d unsafeVotes=%d ADX=%.2f ret3ATR=%.2f ret12ATR=%.2f macdHistATR=%.2f DistResATR=%.2f RSI=%.2f CCI=%.2f Stoch=%.2f WPR=%.2f",
            chosenProb, gap, extremeVotes, unsafeVotes, ADX, ret3ATR, ret12ATR, macdHistATR,
            Dist_to_resistance_ATR, RSI, CCI, Stochastic, Williams_R
         );
         return DYN_SL_NOISY_GOOD;
      }

      // BAD NORMAL detector for SELL
      string badNormalReason = "";
      if(ShouldReclassifyBadNormalToUnsafe(
            decision,
            extremeVotes,
            unsafeVotes,
            ADX,
            ret12ATR,
            Dist_to_support_ATR,
            Dist_to_resistance_ATR,
            badNormalReason))
      {
         if(InpDynSL_LogBadNormalReclassify)
            reason = badNormalReason;
         else
            reason = StringFormat(
               "UNSAFE SELL (bad normal) | p=%.5f gap=%.5f votes=%d unsafeVotes=%d ADX=%.2f ret12ATR=%.2f DistResATR=%.2f",
               chosenProb, gap, extremeVotes, unsafeVotes, ADX, ret12ATR, Dist_to_resistance_ATR
            );

         return DYN_SL_UNSAFE;
      }

      reason = StringFormat(
         "NORMAL SELL | p=%.5f gap=%.5f votes=%d unsafeVotes=%d ADX=%.2f ret3ATR=%.2f ret12ATR=%.2f macdHistATR=%.2f DistResATR=%.2f",
         chosenProb, gap, extremeVotes, unsafeVotes, ADX, ret3ATR, ret12ATR, macdHistATR, Dist_to_resistance_ATR
      );
      return DYN_SL_NORMAL;
   }
   return DYN_SL_NORMAL;
}

//+------------------------------------------------------------------+
//| ResolveDynamicSLPips
//| Alege distanța SL în pips pe baza clasificării Dynamic SL.
//+------------------------------------------------------------------+
double ResolveDynamicSLPips(
   DynamicSLSetupType setupType
)
{
   if(!InpUseDynamicSL)
      return InpStopLossPips;

   if(setupType == DYN_SL_NOISY_GOOD)
      return InpDynamicSL_BasePips * InpDynamicSL_NoisyMultiplier;

   if(setupType == DYN_SL_UNSAFE)
      return InpDynamicSL_BasePips * InpDynamicSL_UnsafeMultiplier;

   return InpDynamicSL_BasePips * InpDynamicSL_NormalMultiplier;
}


//=======================



//+------------------------------------------------------------------+
//| PassTrendStrengthFilter
//| Aplică filtrul de trend puternic peste decizia ML.
//+------------------------------------------------------------------+
bool PassTrendStrengthFilter(
   int decision,
   double ADX,
   double MACD_hist,
   double Ret_3,
   double Ret_12,
   string &reason
)
{
   reason = "TrendStrength: pass";

   if(!InpUseTrendStrengthFilter)
   {
      reason = "TrendStrength: disabled";
      return true;
   }

   // SELL blocked if uptrend still strong
   if(decision == 0)
   {
      if(ADX >= InpTrendADXMin && MACD_hist > 0.0 && Ret_12 >= InpTrendRet12Min)
      {
         reason = StringFormat(
            "TrendStrength SELL blocked | ADX=%.2f MACD_hist=%.5f Ret12=%.5f",
            ADX, MACD_hist, Ret_12
         );
         return false;
      }
   }

   // BUY blocked if downtrend still strong
   if(decision == 2)
   {
      if(ADX >= InpTrendADXMin && MACD_hist < 0.0 && Ret_12 <= -InpTrendRet12Min)
      {
         reason = StringFormat(
            "TrendStrength BUY blocked | ADX=%.2f MACD_hist=%.5f Ret12=%.5f",
            ADX, MACD_hist, Ret_12
         );
         return false;
      }
   }

   return true;
}


//+------------------------------------------------------------------+
//| PassExhaustionFilter
//| Aplică filtrul de epuizare înainte de intrarea în BUY/SELL.
//+------------------------------------------------------------------+
bool PassExhaustionFilter(
   int decision,
   double Stochastic,
   double Williams_R,
   double CCI,
   double MACD_hist,
   string &reason
)
{
   reason = "Exhaustion: pass";

   if(!InpUseExhaustionFilter)
   {
      reason = "Exhaustion: disabled";
      return true;
   }

   // SELL blocked if market still looks too strong up
   if(decision == 0)
   {
      bool stillStrongUp =
         (Stochastic >= InpExhaustionMaxStochSell) &&
         (Williams_R >= InpExhaustionMaxWPRSell) &&
         (CCI > 100.0) &&
         (MACD_hist > 0.0);

      if(stillStrongUp)
      {
         reason = StringFormat(
            "Exhaustion SELL blocked | Stoch=%.2f WPR=%.2f CCI=%.2f MACD_hist=%.5f",
            Stochastic, Williams_R, CCI, MACD_hist
         );
         return false;
      }
   }

   // BUY blocked if market still looks too weak down
   if(decision == 2)
   {
      bool stillStrongDown =
         (Stochastic <= InpExhaustionMinStochBuy) &&
         (Williams_R <= InpExhaustionMinWPRBuy) &&
         (CCI < -100.0) &&
         (MACD_hist < 0.0);

      if(stillStrongDown)
      {
         reason = StringFormat(
            "Exhaustion BUY blocked | Stoch=%.2f WPR=%.2f CCI=%.2f MACD_hist=%.5f",
            Stochastic, Williams_R, CCI, MACD_hist
         );
         return false;
      }
   }

   return true;
}

//+------------------------------------------------------------------+
//| PassEntryTimingFilter
//| Aplică filtrul de timing și poziționare față de suport/rezistență.
//+------------------------------------------------------------------+
bool PassEntryTimingFilter(
   int decision,
   double Dist_to_support_ATR,
   double Dist_to_resistance_ATR,
   double Ret_3,
   double ATR,
   string &reason
)
{
   reason = "EntryTiming: pass";

   if(!InpUseEntryTimingFilter)
   {
      reason = "EntryTiming: disabled";
      return true;
   }

   double absRet3 = MathAbs(Ret_3);
   double oversizedMove = InpMaxATRMultiplierRet3 * ATR;

   // SELL: avoid selling too far from resistance or after oversized move
   if(decision == 0)
   {
      if(Dist_to_resistance_ATR > InpMaxDistResATRForSell)
      {
         reason = StringFormat(
            "EntryTiming SELL blocked | DistResATR=%.5f > %.5f",
            Dist_to_resistance_ATR, InpMaxDistResATRForSell
         );
         return false;
      }

      if(absRet3 > oversizedMove)
      {
         reason = StringFormat(
            "EntryTiming SELL blocked | abs(Ret3)=%.5f > %.5f",
            absRet3, oversizedMove
         );
         return false;
      }
   }

   // BUY: avoid buying too far from support or after oversized move
   if(decision == 2)
   {
      if(Dist_to_support_ATR > InpMaxDistSupATRForBuy)
      {
         reason = StringFormat(
            "EntryTiming BUY blocked | DistSupATR=%.5f > %.5f",
            Dist_to_support_ATR, InpMaxDistSupATRForBuy
         );
         return false;
      }

      if(absRet3 > oversizedMove)
      {
         reason = StringFormat(
            "EntryTiming BUY blocked | abs(Ret3)=%.5f > %.5f",
            absRet3, oversizedMove
         );
         return false;
      }
   }

   return true;
}

#endif // __EA_ML_M5_FILTERS_MQH__
