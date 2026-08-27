//+------------------------------------------------------------------+
//| EA_ML_M5_PositionManagement.mqh                                  |
//| Management pentru pozițiile deja deschise: profit lock + TP step. |
//| Nu schimbă logica de intrare ML; rulează doar după ce există trade.|
//+------------------------------------------------------------------+

#ifndef __EA_ML_M5_POSITION_MANAGEMENT_MQH__
#define __EA_ML_M5_POSITION_MANAGEMENT_MQH__

//+------------------------------------------------------------------+
//| GetProfitStepTargets
//| Alege cea mai mare treaptă atinsă de profitul curent și întoarce
//| profitul care trebuie blocat prin SL și noul target TP în bani.
//+------------------------------------------------------------------+
bool GetProfitStepTargets(const double currentProfitMoney,
                          int &stepIndex,
                          double &lockMoney,
                          double &newTPMoney)
{
   stepIndex = 0;
   lockMoney = 0.0;
   newTPMoney = 0.0;

   if(InpProfitStep1_TriggerMoney > 0.0 && currentProfitMoney >= InpProfitStep1_TriggerMoney)
   {
      stepIndex = 1;
      lockMoney = InpProfitStep1_LockMoney;
      newTPMoney = InpProfitStep1_NewTPMoney;
   }

   if(InpProfitStep2_TriggerMoney > 0.0 && currentProfitMoney >= InpProfitStep2_TriggerMoney)
   {
      stepIndex = 2;
      lockMoney = InpProfitStep2_LockMoney;
      newTPMoney = InpProfitStep2_NewTPMoney;
   }

   if(InpProfitStep3_TriggerMoney > 0.0 && currentProfitMoney >= InpProfitStep3_TriggerMoney)
   {
      stepIndex = 3;
      lockMoney = InpProfitStep3_LockMoney;
      newTPMoney = InpProfitStep3_NewTPMoney;
   }

   if(InpProfitStep4_TriggerMoney > 0.0 && currentProfitMoney >= InpProfitStep4_TriggerMoney)
   {
      stepIndex = 4;
      lockMoney = InpProfitStep4_LockMoney;
      newTPMoney = InpProfitStep4_NewTPMoney;
   }

   return (stepIndex > 0 && lockMoney > 0.0 && newTPMoney > lockMoney);
}

//+------------------------------------------------------------------+
//| IsBetterSL
//| Verifică dacă noul SL este mai bun decât SL-ul actual, separat
//| pentru BUY și SELL. Nu permite mutarea SL-ului înapoi.
//+------------------------------------------------------------------+
bool IsBetterSL(const ENUM_POSITION_TYPE positionType,
                const double currentSL,
                const double candidateSL)
{
   if(candidateSL <= 0.0)
      return false;

   double minDiff = _Point * 2.0;

   if(positionType == POSITION_TYPE_BUY)
   {
      if(currentSL <= 0.0)
         return true;
      return (candidateSL > currentSL + minDiff);
   }

   if(positionType == POSITION_TYPE_SELL)
   {
      if(currentSL <= 0.0)
         return true;
      return (candidateSL < currentSL - minDiff);
   }

   return false;
}

//+------------------------------------------------------------------+
//| IsBetterTP
//| Verifică dacă noul TP extinde ținta față de TP-ul curent.
//+------------------------------------------------------------------+
bool IsBetterTP(const ENUM_POSITION_TYPE positionType,
                const double currentTP,
                const double candidateTP)
{
   if(candidateTP <= 0.0)
      return false;

   double minDiff = _Point * 2.0;

   if(positionType == POSITION_TYPE_BUY)
   {
      if(currentTP <= 0.0)
         return true;
      return (candidateTP > currentTP + minDiff);
   }

   if(positionType == POSITION_TYPE_SELL)
   {
      if(currentTP <= 0.0)
         return true;
      return (candidateTP < currentTP - minDiff);
   }

   return false;
}

//+------------------------------------------------------------------+
//| ModifyPositionSLTPByTicket
//| Modifică SL/TP pentru o poziție anume folosind ticket-ul poziției.
//+------------------------------------------------------------------+
bool ModifyPositionSLTPByTicket(const ulong ticket,
                                const string symbol,
                                const double sl,
                                const double tp)
{
   MqlTradeRequest request;
   MqlTradeResult  result;
   ZeroMemory(request);
   ZeroMemory(result);

   request.action   = TRADE_ACTION_SLTP;
   request.position = ticket;
   request.symbol   = symbol;
   request.sl       = sl;
   request.tp       = tp;
   request.magic    = InpMagicNumber;

   if(!OrderSend(request, result))
   {
      PrintFormat("ProfitStep modify failed: OrderSend=false | ticket=%I64u | retcode=%d | %s",
                  ticket, result.retcode, result.comment);
      return false;
   }

   if(result.retcode != TRADE_RETCODE_DONE && result.retcode != TRADE_RETCODE_PLACED)
   {
      PrintFormat("ProfitStep modify failed | ticket=%I64u | retcode=%d | %s",
                  ticket, result.retcode, result.comment);
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| ManageProfitStepForPosition
//| Pentru poziția selectată, dacă profitul a atins o treaptă, mută SL
//| pe profit și extinde TP-ul. Funcția nu coboară niciodată protecția.
//+------------------------------------------------------------------+
bool ManageProfitStepForPosition(const ulong ticket)
{
   if(!PositionSelectByTicket(ticket))
      return false;

   string symbol = PositionGetString(POSITION_SYMBOL);
   long magic = PositionGetInteger(POSITION_MAGIC);

   if(symbol != _Symbol || magic != InpMagicNumber)
      return false;

   ENUM_POSITION_TYPE positionType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   double lots = PositionGetDouble(POSITION_VOLUME);
   double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSL = PositionGetDouble(POSITION_SL);
   double currentTP = PositionGetDouble(POSITION_TP);
   double currentProfitMoney = PositionGetDouble(POSITION_PROFIT);

   int stepIndex = 0;
   double lockMoney = 0.0;
   double newTPMoney = 0.0;

   if(!GetProfitStepTargets(currentProfitMoney, stepIndex, lockMoney, newTPMoney))
      return false;

   ENUM_ORDER_TYPE orderType = ORDER_TYPE_BUY;
   if(positionType == POSITION_TYPE_SELL)
      orderType = ORDER_TYPE_SELL;
   else if(positionType != POSITION_TYPE_BUY)
      return false;

   double candidateSL = FindTakeProfitPriceByMoney(orderType, lots, entryPrice, lockMoney);
   double candidateTP = FindTakeProfitPriceByMoney(orderType, lots, entryPrice, newTPMoney);

   if(candidateSL <= 0.0 || candidateTP <= 0.0)
      return false;

   candidateSL = NormalizeDouble(candidateSL, _Digits);
   candidateTP = NormalizeDouble(candidateTP, _Digits);

   bool improveSL = IsBetterSL(positionType, currentSL, candidateSL);
   bool improveTP = IsBetterTP(positionType, currentTP, candidateTP);

   if(!improveSL && !improveTP)
      return false;

   double finalSL = currentSL;
   double finalTP = currentTP;

   if(improveSL)
      finalSL = candidateSL;
   if(improveTP)
      finalTP = candidateTP;

   bool ok = ModifyPositionSLTPByTicket(ticket, symbol, finalSL, finalTP);

   if(ok && InpLogProfitStepManagement)
   {
      PrintFormat("ProfitStep applied | step=%d | ticket=%I64u | profit=%.2f | lock=%.2f | targetTP=%.2f | oldSL=%.5f oldTP=%.5f | newSL=%.5f newTP=%.5f",
                  stepIndex, ticket, currentProfitMoney, lockMoney, newTPMoney,
                  currentSL, currentTP, finalSL, finalTP);
   }

   return ok;
}

//+------------------------------------------------------------------+
//| ClosePositionByTicket
//| Force-closes a selected position by ticket. Used by emergency
//| account-currency max loss protection.
//+------------------------------------------------------------------+
bool ClosePositionByTicket(const ulong ticket)
{
   if(!PositionSelectByTicket(ticket))
      return false;

   string symbol = PositionGetString(POSITION_SYMBOL);
   long magic = PositionGetInteger(POSITION_MAGIC);

   if(symbol != _Symbol || magic != InpMagicNumber)
      return false;

   trade.SetExpertMagicNumber(InpMagicNumber);

   bool ok = trade.PositionClose(ticket);
   if(!ok)
   {
      PrintFormat("MaxLoss close failed | ticket=%I64u | retcode=%d | %s",
                  ticket, trade.ResultRetcode(), trade.ResultComment());
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Market structure post-entry monitor
//| States:
//| NORMAL            - poziție largă urmărită, fără pattern periculos.
//| STRUCTURE_RISK    - respingeri repetate la rezistență/suport.
//| CONFIRMED_BREAK   - CHoCH: break de swing contra poziției.
//| RECOVERY          - zona ruptă a fost recuperată; lăsăm trade-ul să curgă.
//+------------------------------------------------------------------+
enum MarketStructureMonitorState
{
   MS_MON_NONE = 0,
   MS_MON_NORMAL = 1,
   MS_MON_STRUCTURE_RISK = 2,
   MS_MON_CONFIRMED_BREAK = 3,
   MS_MON_RECOVERY = 4
};

ulong              g_msMonTicket = 0;
datetime           g_msMonEntryTime = 0;
datetime           g_msMonBreakTime = 0;
ENUM_POSITION_TYPE g_msMonType = POSITION_TYPE_BUY;
double             g_msMonEntryPrice = 0.0;
double             g_msMonStructureLevel = 0.0;
double             g_msMonBreakLevel = 0.0;
double             g_msMonInitialSLPips = 0.0;
int                g_msMonTouchesAtEntry = 0;
int                g_msMonState = MS_MON_NONE;
int                g_msMonLastProfitStep = 0;
bool               g_msMonFastImpulseBreak = false;

void ResetMarketStructureMonitorState()
{
   g_msMonTicket = 0;
   g_msMonEntryTime = 0;
   g_msMonBreakTime = 0;
   g_msMonEntryPrice = 0.0;
   g_msMonStructureLevel = 0.0;
   g_msMonBreakLevel = 0.0;
   g_msMonInitialSLPips = 0.0;
   g_msMonTouchesAtEntry = 0;
   g_msMonState = MS_MON_NONE;
   g_msMonLastProfitStep = 0;
   g_msMonFastImpulseBreak = false;
}

bool MSSideEnabled(const ENUM_POSITION_TYPE positionType)
{
   if(positionType == POSITION_TYPE_BUY)
      return InpMS_BuyEnabled;
   if(positionType == POSITION_TYPE_SELL)
      return InpMS_SellEnabled;
   return false;
}

double MSMarketPrice(const ENUM_POSITION_TYPE positionType)
{
   if(positionType == POSITION_TYPE_BUY)
      return SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(positionType == POSITION_TYPE_SELL)
      return SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   return 0.0;
}

double MSSLPips(const ENUM_POSITION_TYPE positionType,
                const double entryPrice,
                const double sl)
{
   if(sl <= 0.0)
      return 0.0;

   double pip = PipSize();
   if(pip <= 0.0)
      return 0.0;

   if(positionType == POSITION_TYPE_BUY)
      return (entryPrice - sl) / pip;
   if(positionType == POSITION_TYPE_SELL)
      return (sl - entryPrice) / pip;

   return 0.0;
}

bool MSIsValidSL(const ENUM_POSITION_TYPE positionType,
                 const double candidateSL)
{
   if(candidateSL <= 0.0)
      return false;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   long stopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDistance = ((double)stopsLevel + 2.0) * _Point;

   if(positionType == POSITION_TYPE_BUY)
      return (candidateSL < bid - minDistance);
   if(positionType == POSITION_TYPE_SELL)
      return (candidateSL > ask + minDistance);

   return false;
}

double MSSLByLossPips(const ENUM_POSITION_TYPE positionType,
                      const double entryPrice,
                      const double lossPips)
{
   double pip = PipSize();
   if(pip <= 0.0 || lossPips <= 0.0)
      return 0.0;

   if(positionType == POSITION_TYPE_BUY)
      return NormalizeDouble(entryPrice - lossPips * pip, _Digits);
   if(positionType == POSITION_TYPE_SELL)
      return NormalizeDouble(entryPrice + lossPips * pip, _Digits);

   return 0.0;
}

double MSSLByLockMoney(const ENUM_POSITION_TYPE positionType,
                       const double lots,
                       const double entryPrice,
                       const double lockMoney)
{
   if(lockMoney <= 0.0)
      return NormalizeDouble(entryPrice, _Digits);

   ENUM_ORDER_TYPE orderType = ORDER_TYPE_BUY;
   if(positionType == POSITION_TYPE_SELL)
      orderType = ORDER_TYPE_SELL;
   else if(positionType != POSITION_TYPE_BUY)
      return 0.0;

   double sl = FindTakeProfitPriceByMoney(orderType, lots, entryPrice, lockMoney);
   if(sl <= 0.0)
      return 0.0;

   return NormalizeDouble(sl, _Digits);
}

bool MSHasLossSLAtOrBetter(const ENUM_POSITION_TYPE positionType,
                           const double currentSL,
                           const double entryPrice,
                           const double lossPips)
{
   if(currentSL <= 0.0)
      return false;

   double targetSL = MSSLByLossPips(positionType, entryPrice, lossPips);
   if(targetSL <= 0.0)
      return false;

   double minDiff = _Point * 2.0;
   if(positionType == POSITION_TYPE_BUY)
      return (currentSL >= targetSL - minDiff);
   if(positionType == POSITION_TYPE_SELL)
      return (currentSL <= targetSL + minDiff);

   return false;
}

bool MSGetProfitLockTarget(const double currentProfitMoney,
                           int &stepIndex,
                           double &lockMoney)
{
   stepIndex = 0;
   lockMoney = 0.0;

   if(InpMS_ProfitStep1Trigger > 0.0 && currentProfitMoney >= InpMS_ProfitStep1Trigger)
   {
      stepIndex = 1;
      lockMoney = InpMS_ProfitStep1Lock;
   }
   if(InpMS_ProfitStep2Trigger > 0.0 && currentProfitMoney >= InpMS_ProfitStep2Trigger)
   {
      stepIndex = 2;
      lockMoney = InpMS_ProfitStep2Lock;
   }
   if(InpMS_ProfitStep3Trigger > 0.0 && currentProfitMoney >= InpMS_ProfitStep3Trigger)
   {
      stepIndex = 3;
      lockMoney = InpMS_ProfitStep3Lock;
   }
   if(InpMS_ProfitStep4Trigger > 0.0 && currentProfitMoney >= InpMS_ProfitStep4Trigger)
   {
      stepIndex = 4;
      lockMoney = InpMS_ProfitStep4Lock;
   }

   return (stepIndex > 0 && lockMoney >= 0.0);
}

double MSHighestHigh(const int lookbackBars)
{
   double level = 0.0;
   int bars = (lookbackBars > 10 ? lookbackBars : 10);
   for(int shift = 1; shift <= bars; ++shift)
   {
      double high = iHigh(_Symbol, PERIOD_M5, shift);
      if(high > level)
         level = high;
   }
   return level;
}

double MSLowestLow(const int lookbackBars)
{
   double level = 0.0;
   int bars = (lookbackBars > 10 ? lookbackBars : 10);
   for(int shift = 1; shift <= bars; ++shift)
   {
      double low = iLow(_Symbol, PERIOD_M5, shift);
      if(low <= 0.0)
         continue;
      if(level <= 0.0 || low < level)
         level = low;
   }
   return level;
}

double MSUpperWick(const int shift)
{
   double open = iOpen(_Symbol, PERIOD_M5, shift);
   double close = iClose(_Symbol, PERIOD_M5, shift);
   double high = iHigh(_Symbol, PERIOD_M5, shift);
   return MathMax(0.0, high - MathMax(open, close));
}

double MSLowerWick(const int shift)
{
   double open = iOpen(_Symbol, PERIOD_M5, shift);
   double close = iClose(_Symbol, PERIOD_M5, shift);
   double low = iLow(_Symbol, PERIOD_M5, shift);
   return MathMax(0.0, MathMin(open, close) - low);
}

int MSCountResistanceTouches(const double level,
                             const double atr)
{
   if(level <= 0.0 || atr <= 0.0)
      return 0;

   int touches = 0;
   int lastTouchShift = -10000;
   for(int shift = InpMS_LookbackBars; shift >= 1; --shift)
   {
      double high = iHigh(_Symbol, PERIOD_M5, shift);
      double close = iClose(_Symbol, PERIOD_M5, shift);
      double wick = MSUpperWick(shift);
      bool nearLevel = (high >= level - InpMS_TouchToleranceATR * atr);
      bool rejected = (close < level - 0.03 * atr || wick >= InpMS_MinRejectionWickATR * atr);

      if(nearLevel && rejected && MathAbs(shift - lastTouchShift) >= InpMS_MinBarsBetweenTouches)
      {
         touches++;
         lastTouchShift = shift;
      }
   }
   return touches;
}

int MSCountSupportTouches(const double level,
                          const double atr)
{
   if(level <= 0.0 || atr <= 0.0)
      return 0;

   int touches = 0;
   int lastTouchShift = -10000;
   for(int shift = InpMS_LookbackBars; shift >= 1; --shift)
   {
      double low = iLow(_Symbol, PERIOD_M5, shift);
      double close = iClose(_Symbol, PERIOD_M5, shift);
      double wick = MSLowerWick(shift);
      bool nearLevel = (low <= level + InpMS_TouchToleranceATR * atr);
      bool rejected = (close > level + 0.03 * atr || wick >= InpMS_MinRejectionWickATR * atr);

      if(nearLevel && rejected && MathAbs(shift - lastTouchShift) >= InpMS_MinBarsBetweenTouches)
      {
         touches++;
         lastTouchShift = shift;
      }
   }
   return touches;
}

bool MSFindLastSwingLow(double &swingLow,
                        int &swingShift)
{
   int lr = (InpMS_SwingLeftRight > 1 ? InpMS_SwingLeftRight : 1);
   int maxShift = ((InpMS_LookbackBars - lr) > (lr + 3) ? (InpMS_LookbackBars - lr) : (lr + 3));

   for(int shift = lr + 1; shift <= maxShift; ++shift)
   {
      double low = iLow(_Symbol, PERIOD_M5, shift);
      if(low <= 0.0)
         continue;

      bool isSwing = true;
      for(int j = 1; j <= lr; ++j)
      {
         if(low > iLow(_Symbol, PERIOD_M5, shift - j) || low >= iLow(_Symbol, PERIOD_M5, shift + j))
         {
            isSwing = false;
            break;
         }
      }

      if(isSwing)
      {
         swingLow = low;
         swingShift = shift;
         return true;
      }
   }

   return false;
}

bool MSFindLastSwingHigh(double &swingHigh,
                         int &swingShift)
{
   int lr = (InpMS_SwingLeftRight > 1 ? InpMS_SwingLeftRight : 1);
   int maxShift = ((InpMS_LookbackBars - lr) > (lr + 3) ? (InpMS_LookbackBars - lr) : (lr + 3));

   for(int shift = lr + 1; shift <= maxShift; ++shift)
   {
      double high = iHigh(_Symbol, PERIOD_M5, shift);
      if(high <= 0.0)
         continue;

      bool isSwing = true;
      for(int j = 1; j <= lr; ++j)
      {
         if(high < iHigh(_Symbol, PERIOD_M5, shift - j) || high <= iHigh(_Symbol, PERIOD_M5, shift + j))
         {
            isSwing = false;
            break;
         }
      }

      if(isSwing)
      {
         swingHigh = high;
         swingShift = shift;
         return true;
      }
   }

   return false;
}

double MSAverageVolume(const int bars)
{
   int count = (bars > 1 ? bars : 1);
   double sum = 0.0;
   int valid = 0;

   for(int shift = 2; shift < 2 + count; ++shift)
   {
      long volume = iVolume(_Symbol, PERIOD_M5, shift);
      if(volume <= 0)
         continue;

      sum += (double)volume;
      valid++;
   }

   if(valid <= 0)
      return 0.0;

   return sum / (double)valid;
}

bool MSVolumeSpike()
{
   if(!InpMS_UseVolumeSpikeConfirm)
      return false;

   double avgVolume = MSAverageVolume(InpMS_VolumeAvgBars);
   long currentVolume = iVolume(_Symbol, PERIOD_M5, 1);

   if(avgVolume <= 0.0 || currentVolume <= 0)
      return false;

   return ((double)currentVolume >= avgVolume * InpMS_VolumeSpikeMultiplier);
}

bool MSGetMACDHistAtShift(const int shift,
                          double &hist)
{
   hist = 0.0;

   if(hMACD == INVALID_HANDLE)
      return false;

   double macdMain[];
   double macdSignal[];

   if(CopyBuffer(hMACD, 0, shift, 1, macdMain) < 1)
      return false;
   if(CopyBuffer(hMACD, 1, shift, 1, macdSignal) < 1)
      return false;

   hist = macdMain[0] - macdSignal[0];
   return true;
}

bool MSMACDHistSlopeAgainst(const ENUM_POSITION_TYPE positionType,
                            const double currentMACDHist)
{
   double previousHist = 0.0;
   if(!MSGetMACDHistAtShift(2, previousHist))
      return false;

   if(positionType == POSITION_TYPE_BUY)
      return (currentMACDHist < previousHist);
   if(positionType == POSITION_TYPE_SELL)
      return (currentMACDHist > previousHist);

   return false;
}

bool MSFastImpulseAgainst(const ENUM_POSITION_TYPE positionType,
                          const double breakLevel,
                          const double MACD_hist,
                          const double ATR,
                          const double Ret_3,
                          const double Ret_12)
{
   if(!InpMS_UseFastImpulseAgainst || breakLevel <= 0.0 || ATR <= 0.0)
      return false;

   double close1 = iClose(_Symbol, PERIOD_M5, 1);
   double ret3ATR = SafeDiv(Ret_3, ATR);
   double ret12ATR = SafeDiv(Ret_12, ATR);
   bool macdSlopeAgainst = MSMACDHistSlopeAgainst(positionType, MACD_hist);
   bool volumeSpike = MSVolumeSpike();

   if(positionType == POSITION_TYPE_BUY)
   {
      bool brokeSwing = (close1 < breakLevel - InpMS_CHoCHBreakATR * ATR);
      bool impulse = (ret3ATR <= -InpMS_FastImpulseRet3ATR &&
                      ret12ATR <= -InpMS_FastImpulseRet12ATR &&
                      MACD_hist < 0.0 &&
                      macdSlopeAgainst);
      bool participation = (volumeSpike || ret12ATR <= -InpMS_FastImpulseRet12ATR * 1.35);
      return (brokeSwing && impulse && participation);
   }

   if(positionType == POSITION_TYPE_SELL)
   {
      bool brokeSwing = (close1 > breakLevel + InpMS_CHoCHBreakATR * ATR);
      bool impulse = (ret3ATR >= InpMS_FastImpulseRet3ATR &&
                      ret12ATR >= InpMS_FastImpulseRet12ATR &&
                      MACD_hist > 0.0 &&
                      macdSlopeAgainst);
      bool participation = (volumeSpike || ret12ATR >= InpMS_FastImpulseRet12ATR * 1.35);
      return (brokeSwing && impulse && participation);
   }

   return false;
}

int MSStructureScore(const ENUM_POSITION_TYPE positionType,
                     const int decision,
                     const double pSell,
                     const double pHold,
                     const double pBuy,
                     const double level,
                     const int touches,
                     const double MACD_hist,
                     const double ATR,
                     const double Ret_3,
                     const double Ret_12)
{
   if(level <= 0.0 || ATR <= 0.0)
      return 0;

   bool isBuy = (positionType == POSITION_TYPE_BUY);
   double close1 = iClose(_Symbol, PERIOD_M5, 1);
   double high1 = iHigh(_Symbol, PERIOD_M5, 1);
   double low1 = iLow(_Symbol, PERIOD_M5, 1);
   double chosenProb = isBuy ? pBuy : pSell;
   double oppositeProb = isBuy ? pSell : pBuy;
   bool macdSlopeAgainst = MSMACDHistSlopeAgainst(positionType, MACD_hist);
   bool volumeSpike = MSVolumeSpike();
   int score = 0;

   if(touches >= InpMS_MinTouches)
      score += 2;

   if(isBuy)
   {
      double distATR = (level - close1) / ATR;
      if(distATR >= -0.10 && distATR <= InpMS_NearLevelATR)
         score++;
      if(high1 >= level - InpMS_TouchToleranceATR * ATR && close1 < level)
         score++;
      if(MSUpperWick(1) >= InpMS_MinRejectionWickATR * ATR)
         score++;
      if(MACD_hist < 0.0 || Ret_3 < 0.0)
         score++;
      if(macdSlopeAgainst)
         score++;
      if(volumeSpike && Ret_3 < 0.0)
         score++;
      if(Ret_12 < 0.0)
         score++;
      if(decision == 0 || oppositeProb > chosenProb || pHold > chosenProb)
         score++;
   }
   else
   {
      double distATR = (close1 - level) / ATR;
      if(distATR >= -0.10 && distATR <= InpMS_NearLevelATR)
         score++;
      if(low1 <= level + InpMS_TouchToleranceATR * ATR && close1 > level)
         score++;
      if(MSLowerWick(1) >= InpMS_MinRejectionWickATR * ATR)
         score++;
      if(MACD_hist > 0.0 || Ret_3 > 0.0)
         score++;
      if(macdSlopeAgainst)
         score++;
      if(volumeSpike && Ret_3 > 0.0)
         score++;
      if(Ret_12 > 0.0)
         score++;
      if(decision == 2 || oppositeProb > chosenProb || pHold > chosenProb)
         score++;
   }

   return score;
}

int MSBreakScore(const ENUM_POSITION_TYPE positionType,
                 const int decision,
                 const double pSell,
                 const double pHold,
                 const double pBuy,
                 const double breakLevel,
                 const double MACD_hist,
                 const double ATR,
                 const double ADX,
                 const double Ret_3,
                 const double Ret_12)
{
   if(breakLevel <= 0.0 || ATR <= 0.0)
      return 0;

   bool isBuy = (positionType == POSITION_TYPE_BUY);
   double close1 = iClose(_Symbol, PERIOD_M5, 1);
   double chosenProb = isBuy ? pBuy : pSell;
   double oppositeProb = isBuy ? pSell : pBuy;
   bool macdSlopeAgainst = MSMACDHistSlopeAgainst(positionType, MACD_hist);
   bool volumeSpike = MSVolumeSpike();
   int score = 0;

   if(isBuy)
   {
      if(close1 < breakLevel - InpMS_CHoCHBreakATR * ATR)
         score += 2;
      if(Ret_3 < 0.0)
         score++;
      if(Ret_12 < 0.0)
         score++;
      if(MACD_hist < 0.0)
         score++;
      if(macdSlopeAgainst)
         score++;
      if(volumeSpike)
         score++;
      if(decision == 0 || oppositeProb > chosenProb || pHold > chosenProb)
         score++;
   }
   else
   {
      if(close1 > breakLevel + InpMS_CHoCHBreakATR * ATR)
         score += 2;
      if(Ret_3 > 0.0)
         score++;
      if(Ret_12 > 0.0)
         score++;
      if(MACD_hist > 0.0)
         score++;
      if(macdSlopeAgainst)
         score++;
      if(volumeSpike)
         score++;
      if(decision == 2 || oppositeProb > chosenProb || pHold > chosenProb)
         score++;
   }

   if(ADX >= 20.0)
      score++;

   return score;
}

bool MSApplyLossSL(const ulong ticket,
                   const ENUM_POSITION_TYPE positionType,
                   const double entryPrice,
                   const double currentSL,
                   const double currentTP,
                   const double lossPips,
                   const string reason)
{
   double candidateSL = MSSLByLossPips(positionType, entryPrice, lossPips);
   if(candidateSL <= 0.0 || !IsBetterSL(positionType, currentSL, candidateSL))
      return false;
   if(!MSIsValidSL(positionType, candidateSL))
      return false;

   bool ok = ModifyPositionSLTPByTicket(ticket, _Symbol, candidateSL, currentTP);
   if(ok && InpMS_Log)
   {
      PrintFormat("MSMonitor SL tightened | ticket=%I64u | state=%d | reason=%s | oldSL=%.5f newSL=%.5f | targetLossPips=%.2f",
                  ticket, g_msMonState, reason, currentSL, candidateSL, lossPips);
   }
   return ok;
}

bool MSApplyProfitLock(const ulong ticket,
                       const ENUM_POSITION_TYPE positionType,
                       const double lots,
                       const double entryPrice,
                       const double currentSL,
                       const double currentTP,
                       const double currentProfitMoney)
{
   if(g_msMonState != MS_MON_STRUCTURE_RISK &&
      g_msMonState != MS_MON_CONFIRMED_BREAK &&
      g_msMonState != MS_MON_RECOVERY)
      return false;

   int stepIndex = 0;
   double lockMoney = 0.0;
   if(!MSGetProfitLockTarget(currentProfitMoney, stepIndex, lockMoney))
      return false;
   if(stepIndex <= g_msMonLastProfitStep)
      return false;

   double candidateSL = MSSLByLockMoney(positionType, lots, entryPrice, lockMoney);
   if(candidateSL <= 0.0 || !IsBetterSL(positionType, currentSL, candidateSL))
      return false;
   if(!MSIsValidSL(positionType, candidateSL))
      return false;

   bool ok = ModifyPositionSLTPByTicket(ticket, _Symbol, candidateSL, currentTP);
   if(ok)
   {
      g_msMonLastProfitStep = stepIndex;
      if(InpMS_Log)
      {
         PrintFormat("MSMonitor profit lock | ticket=%I64u | step=%d | profit=%.2f | lockMoney=%.2f | oldSL=%.5f newSL=%.5f",
                     ticket, stepIndex, currentProfitMoney, lockMoney, currentSL, candidateSL);
      }
   }
   return ok;
}

bool RegisterMarketStructureMonitorFromSignal(const int decision,
                                              const double pSell,
                                              const double pHold,
                                              const double pBuy,
                                              const double MACD_hist,
                                              const double ATR,
                                              const double ADX,
                                              const double Ret_3,
                                              const double Ret_12)
{
   if(!InpUseMarketStructureRiskMonitor)
      return false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      long magic = PositionGetInteger(POSITION_MAGIC);
      if(symbol != _Symbol || magic != InpMagicNumber)
         continue;

      ENUM_POSITION_TYPE positionType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(!MSSideEnabled(positionType))
         continue;

      double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double slPips = MSSLPips(positionType, entryPrice, currentSL);
      if(slPips < InpMS_MinInitialSLPips)
         continue;

      double level = (positionType == POSITION_TYPE_BUY) ? MSHighestHigh(InpMS_LookbackBars) : MSLowestLow(InpMS_LookbackBars);
      int touches = (positionType == POSITION_TYPE_BUY) ? MSCountResistanceTouches(level, ATR) : MSCountSupportTouches(level, ATR);
      int structureScore = MSStructureScore(positionType, decision, pSell, pHold, pBuy,
                                            level, touches, MACD_hist, ATR, Ret_3, Ret_12);

      ResetMarketStructureMonitorState();
      g_msMonTicket = ticket;
      g_msMonEntryTime = (datetime)PositionGetInteger(POSITION_TIME);
      g_msMonType = positionType;
      g_msMonEntryPrice = entryPrice;
      g_msMonStructureLevel = level;
      g_msMonTouchesAtEntry = touches;
      g_msMonInitialSLPips = slPips;
      g_msMonState = (structureScore >= InpMS_MinStructureScore ? MS_MON_STRUCTURE_RISK : MS_MON_NORMAL);

      if(InpMS_Log)
      {
         PrintFormat("MSMonitor registered | ticket=%I64u | type=%s | entry=%.5f | slPips=%.2f | level=%.5f | touches=%d | score=%d | state=%d | decision=%d pSell=%.5f pHold=%.5f pBuy=%.5f",
                     ticket,
                     positionType == POSITION_TYPE_BUY ? "BUY" : "SELL",
                     entryPrice, slPips, level, touches, structureScore,
                     g_msMonState, decision, pSell, pHold, pBuy);
      }
      return true;
   }

   return false;
}

bool ManageMarketStructureForPosition(const ulong ticket,
                                      const int decision,
                                      const double pSell,
                                      const double pHold,
                                      const double pBuy,
                                      const double MACD_hist,
                                      const double ATR,
                                      const double ADX,
                                      const double Ret_3,
                                      const double Ret_12)
{
   if(!InpUseMarketStructureRiskMonitor || ATR <= 0.0)
      return false;
   if(!PositionSelectByTicket(ticket))
      return false;

   string symbol = PositionGetString(POSITION_SYMBOL);
   long magic = PositionGetInteger(POSITION_MAGIC);
   if(symbol != _Symbol || magic != InpMagicNumber)
      return false;

   ENUM_POSITION_TYPE positionType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   if(!MSSideEnabled(positionType))
      return false;

   if(g_msMonTicket != ticket)
      RegisterMarketStructureMonitorFromSignal(decision, pSell, pHold, pBuy, MACD_hist, ATR, ADX, Ret_3, Ret_12);

   if(g_msMonTicket != ticket || g_msMonState == MS_MON_NONE)
      return false;

   double lots = PositionGetDouble(POSITION_VOLUME);
   double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSL = PositionGetDouble(POSITION_SL);
   double currentTP = PositionGetDouble(POSITION_TP);
   double currentProfitMoney = PositionGetDouble(POSITION_PROFIT);

   double level = g_msMonStructureLevel;
   if(level <= 0.0)
      level = (positionType == POSITION_TYPE_BUY) ? MSHighestHigh(InpMS_LookbackBars) : MSLowestLow(InpMS_LookbackBars);

   int touches = (positionType == POSITION_TYPE_BUY) ? MSCountResistanceTouches(level, ATR) : MSCountSupportTouches(level, ATR);
   int structureScore = MSStructureScore(positionType, decision, pSell, pHold, pBuy,
                                         level, touches, MACD_hist, ATR, Ret_3, Ret_12);

   if(g_msMonState == MS_MON_NORMAL && structureScore >= InpMS_MinStructureScore)
   {
      g_msMonState = MS_MON_STRUCTURE_RISK;
      if(InpMS_Log)
      {
         PrintFormat("MSMonitor STRUCTURE_RISK | ticket=%I64u | score=%d | level=%.5f | touches=%d | profit=%.2f",
                     ticket, structureScore, level, touches, currentProfitMoney);
      }
      MSApplyLossSL(ticket, positionType, entryPrice, currentSL, currentTP,
                    InpMS_StructureRiskSLPips, "structure-risk-soft");
   }

   double breakLevel = 0.0;
   int swingShift = 0;
   bool hasSwing = false;
   if(positionType == POSITION_TYPE_BUY)
      hasSwing = MSFindLastSwingLow(breakLevel, swingShift);
   else
      hasSwing = MSFindLastSwingHigh(breakLevel, swingShift);

   if(hasSwing)
   {
      int breakScore = MSBreakScore(positionType, decision, pSell, pHold, pBuy,
                                    breakLevel, MACD_hist, ATR, ADX, Ret_3, Ret_12);
      bool fastImpulse = MSFastImpulseAgainst(positionType, breakLevel, MACD_hist, ATR, Ret_3, Ret_12);
      bool confirmed = (breakScore >= InpMS_MinBreakScore || fastImpulse);

      if(confirmed && g_msMonState != MS_MON_CONFIRMED_BREAK)
      {
         g_msMonState = MS_MON_CONFIRMED_BREAK;
         g_msMonBreakLevel = breakLevel;
         g_msMonBreakTime = TimeCurrent();
         g_msMonFastImpulseBreak = fastImpulse;

         if(InpMS_Log)
         {
            PrintFormat("MSMonitor CONFIRMED_BREAK | ticket=%I64u | breakLevel=%.5f | breakScore=%d | fastImpulse=%s | swingShift=%d | profit=%.2f | decision=%d",
                        ticket, breakLevel, breakScore, fastImpulse ? "true" : "false",
                        swingShift, currentProfitMoney, decision);
         }

         MSApplyLossSL(ticket, positionType, entryPrice, currentSL, currentTP,
                       InpMS_ConfirmedBreakSLPips, "confirmed-break");
      }
   }

   PositionSelectByTicket(ticket);
   currentSL = PositionGetDouble(POSITION_SL);
   currentTP = PositionGetDouble(POSITION_TP);
   currentProfitMoney = PositionGetDouble(POSITION_PROFIT);

   MSApplyProfitLock(ticket, positionType, lots, entryPrice, currentSL, currentTP, currentProfitMoney);

   if(g_msMonState == MS_MON_CONFIRMED_BREAK && g_msMonBreakLevel > 0.0)
   {
      double close1 = iClose(_Symbol, PERIOD_M5, 1);
      bool reclaimed = false;

      if(positionType == POSITION_TYPE_BUY)
         reclaimed = (close1 > g_msMonBreakLevel + InpMS_ReclaimATR * ATR);
      else
         reclaimed = (close1 < g_msMonBreakLevel - InpMS_ReclaimATR * ATR);

      if(reclaimed)
      {
         g_msMonState = MS_MON_RECOVERY;
         if(InpMS_Log)
         {
            PrintFormat("MSMonitor RECOVERY_RECLAIM | ticket=%I64u | breakLevel=%.5f | close=%.5f | profit=%.2f",
                        ticket, g_msMonBreakLevel, close1, currentProfitMoney);
         }
         return false;
      }

      int barsSinceBreak = 0;
      if(g_msMonBreakTime > 0)
         barsSinceBreak = (int)((TimeCurrent() - g_msMonBreakTime) / PeriodSeconds(PERIOD_M5));

      int reclaimBarsLimit = (g_msMonFastImpulseBreak ? InpMS_FastReclaimBars : InpMS_MaxBarsToWaitForReclaim);
      if(reclaimBarsLimit < 1)
         reclaimBarsLimit = 1;

      if(barsSinceBreak >= reclaimBarsLimit)
      {
         bool alreadyProtected = MSHasLossSLAtOrBetter(positionType, currentSL, entryPrice,
                                                       InpMS_ConfirmedBreakSLPips);
         if(!alreadyProtected)
         {
            MSApplyLossSL(ticket, positionType, entryPrice, currentSL, currentTP,
                          InpMS_ConfirmedBreakSLPips, "reclaim-wait-expired");
         }

         if(InpMS_CloseOnReclaimFail && currentProfitMoney <= 0.0)
         {
            if(InpMS_Log)
            {
               PrintFormat("MSMonitor CLOSE_RECLAIM_FAILED | ticket=%I64u | barsSinceBreak=%d | limit=%d | fastImpulse=%s | breakLevel=%.5f | close=%.5f | profit=%.2f",
                           ticket, barsSinceBreak, reclaimBarsLimit,
                           g_msMonFastImpulseBreak ? "true" : "false",
                           g_msMonBreakLevel, close1, currentProfitMoney);
            }
            return ClosePositionByTicket(ticket);
         }
      }
   }

   return false;
}

void ManageOpenPositionsMarketStructureMonitor(const int decision,
                                               const double pSell,
                                               const double pHold,
                                               const double pBuy,
                                               const double MACD_hist,
                                               const double ATR,
                                               const double ADX,
                                               const double Dist_to_support_ATR,
                                               const double Dist_to_resistance_ATR,
                                               const double Ret_3,
                                               const double Ret_12)
{
   if(!InpUseMarketStructureRiskMonitor)
      return;

   bool foundTrackedTicket = false;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      if(ticket == g_msMonTicket)
         foundTrackedTicket = true;

      ManageMarketStructureForPosition(ticket, decision, pSell, pHold, pBuy,
                                       MACD_hist, ATR, ADX, Ret_3, Ret_12);
   }

   if(g_msMonTicket != 0 && !foundTrackedTicket)
      ResetMarketStructureMonitorState();
}


//+------------------------------------------------------------------+
//| IsFridayCloseTime
//| Returns true on Friday at/after configured close time.
//| MQL5: day_of_week -> 0 Sunday, 1 Monday, ..., 5 Friday, 6 Saturday.
//+------------------------------------------------------------------+
bool IsFridayCloseTime()
{
   if(!InpUseFridayCloseProtection)
      return false;

   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);

   if(dt.day_of_week != 5) // Friday only
      return false;

   if(dt.hour > InpFridayCloseHour)
      return true;

   if(dt.hour == InpFridayCloseHour && dt.min >= InpFridayCloseMinute)
      return true;

   return false;
}


//+------------------------------------------------------------------+
//| ManageFridayCloseForPosition
//| Force-closes one EA position on Friday at/after configured time.
//+------------------------------------------------------------------+
bool ManageFridayCloseForPosition(const ulong ticket)
{
   if(!IsFridayCloseTime())
      return false;

   if(!PositionSelectByTicket(ticket))
      return false;

   string symbol = PositionGetString(POSITION_SYMBOL);
   long magic = PositionGetInteger(POSITION_MAGIC);

   if(symbol != _Symbol || magic != InpMagicNumber)
      return false;

   double profit = PositionGetDouble(POSITION_PROFIT);
   ENUM_POSITION_TYPE positionType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

   if(InpLogFridayCloseProtection)
   {
      PrintFormat(
         "FridayClose triggered | ticket=%I64u | type=%s | profit=%.2f | time=%s | closing position before weekend",
         ticket,
         positionType == POSITION_TYPE_BUY ? "BUY" : "SELL",
         profit,
         TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS)
      );
   }

   return ClosePositionByTicket(ticket);
}


//+------------------------------------------------------------------+
//| ManageOpenPositionsFridayClose
//| Checks all EA positions on the current symbol and force-closes them
//| on Friday at/after configured time.
//+------------------------------------------------------------------+
void ManageOpenPositionsFridayClose()
{
   if(!IsFridayCloseTime())
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      ManageFridayCloseForPosition(ticket);
   }
}


//+------------------------------------------------------------------+
//| ManageMaxLossForPosition
//| If enabled, force-closes the position when floating loss reaches
//| the configured account-currency amount. This does not change the
//| initial SL; it is an emergency runtime protection.
//+------------------------------------------------------------------+
bool ManageMaxLossForPosition(const ulong ticket)
{
   if(!g_runtimeUseMaxLossMoney || g_runtimeMaxLossMoney <= 0.0)
      return false;

   if(!PositionSelectByTicket(ticket))
      return false;

   string symbol = PositionGetString(POSITION_SYMBOL);
   long magic = PositionGetInteger(POSITION_MAGIC);

   if(symbol != _Symbol || magic != InpMagicNumber)
      return false;

   double currentProfitMoney = PositionGetDouble(POSITION_PROFIT);

   if(currentProfitMoney > -g_runtimeMaxLossMoney)
      return false;

   if(InpLogMaxLossMoneyProtection)
   {
      PrintFormat("MaxLoss triggered | ticket=%I64u | profit=%.2f | maxLoss=%.2f | closing position",
                  ticket, currentProfitMoney, g_runtimeMaxLossMoney);
   }

   return ClosePositionByTicket(ticket);
}

//+------------------------------------------------------------------+
//| ManageOpenPositionsMaxLoss
//| Checks all EA positions on the current symbol and applies emergency
//| max loss protection. Should run every tick when position management
//| is enabled.
//+------------------------------------------------------------------+
void ManageOpenPositionsMaxLoss()
{
   if(!g_runtimeUseMaxLossMoney || g_runtimeMaxLossMoney <= 0.0)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      ManageMaxLossForPosition(ticket);
   }
}

//+------------------------------------------------------------------+
//| ManageOpenPositionsProfitSteps
//| Parcurge pozițiile deschise pe simbolul curent și aplică sistemul
//| de trepte pentru pozițiile cu magic number-ul EA-ului.
//+------------------------------------------------------------------+
void ManageOpenPositionsProfitSteps()
{
   if(!g_runtimeUseProfitSteps)
      return;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      ManageProfitStepForPosition(ticket);
   }
}

#endif // __EA_ML_M5_POSITION_MANAGEMENT_MQH__
