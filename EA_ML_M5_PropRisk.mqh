//+------------------------------------------------------------------+
//| EA_ML_M5_PropRisk.mqh                                            |
//| Optional account-level risk guard for prop/evaluation accounts.  |
//| It never alters signals, lots, TP or SL. It can only block new    |
//| entries and emergency-close positions that belong to this EA.    |
//+------------------------------------------------------------------+

#ifndef __EA_ML_M5_PROP_RISK_MQH__
#define __EA_ML_M5_PROP_RISK_MQH__

bool     g_runtimePropRiskEnable       = false;
double   g_runtimePropAccountValue     = 0.0;
bool     g_propRiskInitialized         = false;
datetime g_propRiskDayStart            = 0;
double   g_propRiskDayStartBalance     = 0.0;
double   g_propRiskDailyLossMoney      = 0.0;
double   g_propRiskTotalLossMoney      = 0.0;
double   g_propRiskDailyLimitMoney     = 0.0;
double   g_propRiskTotalLimitMoney     = 0.0;
double   g_propRiskFirmDailyLimitMoney = 0.0;
double   g_propRiskFirmTotalLimitMoney = 0.0;
int      g_propRiskConsecutiveLosses   = 0;
bool     g_propRiskDailyLocked         = false;
bool     g_propRiskTotalLocked         = false;
string   g_propRiskDailyLockReason     = "";
string   g_propRiskTotalLockReason     = "";
string   g_propRiskLastBlockLogReason  = "";
bool     g_propRiskCloseAttemptActive  = false;

//+------------------------------------------------------------------+
//| PropRiskServerTime                                               |
//+------------------------------------------------------------------+
datetime PropRiskServerTime()
{
   datetime now = TimeTradeServer();
   if(now <= 0)
      now = TimeCurrent();
   return now;
}

//+------------------------------------------------------------------+
//| PropRiskValidateParameters                                       |
//+------------------------------------------------------------------+
bool PropRiskValidateParameters(string &reason)
{
   reason = "";
   if(!MathIsValidNumber(g_runtimePropAccountValue) || g_runtimePropAccountValue <= 0.0)
   {
      reason = "Prop Account Value must be greater than zero";
      return false;
   }
   if(!MathIsValidNumber(InpPropFirmDailyLossLimitPct) ||
      InpPropFirmDailyLossLimitPct <= 0.0 || InpPropFirmDailyLossLimitPct >= 100.0)
   {
      reason = "Firm Daily Loss Limit % must be in (0, 100)";
      return false;
   }
   if(!MathIsValidNumber(InpPropFirmTotalLossLimitPct) ||
      InpPropFirmTotalLossLimitPct <= 0.0 || InpPropFirmTotalLossLimitPct >= 100.0)
   {
      reason = "Firm Total Loss Limit % must be in (0, 100)";
      return false;
   }
   if(InpPropFirmTotalLossLimitPct < InpPropFirmDailyLossLimitPct)
   {
      reason = "Firm Total Loss Limit % cannot be below the daily limit %";
      return false;
   }
   if(!MathIsValidNumber(InpPropDailySafetyBufferMoney) ||
      InpPropDailySafetyBufferMoney < 0.0)
   {
      reason = "Daily Safety Buffer cannot be negative";
      return false;
   }
   if(!MathIsValidNumber(InpPropTotalSafetyBufferMoney) ||
      InpPropTotalSafetyBufferMoney < 0.0)
   {
      reason = "Total Safety Buffer cannot be negative";
      return false;
   }
   const double firmDailyMoney =
      g_runtimePropAccountValue * InpPropFirmDailyLossLimitPct / 100.0;
   const double firmTotalMoney =
      g_runtimePropAccountValue * InpPropFirmTotalLossLimitPct / 100.0;
   if(InpPropDailySafetyBufferMoney >= firmDailyMoney)
   {
      reason = "Daily Safety Buffer must be below the firm's daily money limit";
      return false;
   }
   if(InpPropTotalSafetyBufferMoney >= firmTotalMoney)
   {
      reason = "Total Safety Buffer must be below the firm's total money limit";
      return false;
   }
   if(InpPropMaxConsecutiveLosses < 0)
   {
      reason = "Max Consecutive Losses cannot be negative";
      return false;
   }
   if(InpPropDayResetHourServer < 0 || InpPropDayResetHourServer > 23)
   {
      reason = "Day Reset Hour Server must be between 0 and 23";
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| PropRiskCalculateDayStart                                        |
//+------------------------------------------------------------------+
datetime PropRiskCalculateDayStart(const datetime now)
{
   MqlDateTime parts;
   TimeToStruct(now, parts);
   parts.hour = InpPropDayResetHourServer;
   parts.min = 0;
   parts.sec = 0;
   datetime dayStart = StructToTime(parts);
   if(now < dayStart)
      dayStart -= 86400;
   return dayStart;
}

//+------------------------------------------------------------------+
//| PropRiskClosedTradingNet                                         |
//| Account trading result since day start. Deposits/withdrawals are |
//| deliberately excluded. This lets the EA reconstruct midnight     |
//| balance even when attached later during the same day.             |
//+------------------------------------------------------------------+
double PropRiskClosedTradingNet(const datetime fromTime,
                                const datetime toTime,
                                bool &historyReady)
{
   historyReady = HistorySelect(fromTime, toTime);
   if(!historyReady)
      return 0.0;

   double net = 0.0;
   const int deals = HistoryDealsTotal();
   for(int i = 0; i < deals; ++i)
   {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;

      const long dealType = HistoryDealGetInteger(deal, DEAL_TYPE);
      // Capital operations do not represent trading P/L. All other deal
      // types are included so separate commission, charge, interest, tax or
      // swap records cannot disappear from the reconstructed daily result.
      if(dealType == DEAL_TYPE_BALANCE ||
         dealType == DEAL_TYPE_CREDIT ||
         dealType == DEAL_TYPE_BONUS)
         continue;

      net += HistoryDealGetDouble(deal, DEAL_PROFIT);
      net += HistoryDealGetDouble(deal, DEAL_COMMISSION);
      net += HistoryDealGetDouble(deal, DEAL_SWAP);
      net += HistoryDealGetDouble(deal, DEAL_FEE);
   }
   return net;
}

//+------------------------------------------------------------------+
//| PropRiskCountConsecutiveLosses                                   |
//| Counts consecutive losing EA exits during the current risk day.  |
//+------------------------------------------------------------------+
int PropRiskCountConsecutiveLosses(const datetime fromTime,
                                   const datetime toTime)
{
   if(!HistorySelect(fromTime, toTime))
      return 0;

   int consecutive = 0;
   long lastPositionId = -1;
   const int deals = HistoryDealsTotal();
   for(int i = 0; i < deals; ++i)
   {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0)
         continue;
      if(HistoryDealGetInteger(deal, DEAL_MAGIC) != InpMagicNumber)
         continue;

      const long entryType = HistoryDealGetInteger(deal, DEAL_ENTRY);
      if(entryType != DEAL_ENTRY_OUT &&
         entryType != DEAL_ENTRY_OUT_BY &&
         entryType != DEAL_ENTRY_INOUT)
         continue;

      const long positionId = HistoryDealGetInteger(deal, DEAL_POSITION_ID);
      if(positionId > 0 && positionId == lastPositionId)
         continue;
      lastPositionId = positionId;

      double net = HistoryDealGetDouble(deal, DEAL_PROFIT);
      net += HistoryDealGetDouble(deal, DEAL_COMMISSION);
      net += HistoryDealGetDouble(deal, DEAL_SWAP);
      net += HistoryDealGetDouble(deal, DEAL_FEE);

      if(net < -0.005)
         consecutive++;
      else
         consecutive = 0;
   }
   return consecutive;
}

//+------------------------------------------------------------------+
//| PropRiskRefreshDayAnchor                                         |
//+------------------------------------------------------------------+
void PropRiskRefreshDayAnchor(const datetime now,
                              const bool force)
{
   const datetime calculatedStart = PropRiskCalculateDayStart(now);
   if(!force && calculatedStart == g_propRiskDayStart)
      return;

   bool historyReady = false;
   const double closedNet = PropRiskClosedTradingNet(calculatedStart, now, historyReady);
   const double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);

   g_propRiskDayStart = calculatedStart;
   g_propRiskDayStartBalance = (historyReady ? currentBalance - closedNet : currentBalance);
   g_propRiskDailyLocked = false;
   g_propRiskDailyLockReason = "";
   g_propRiskLastBlockLogReason = "";

   if(InpPropRiskLog && g_runtimePropRiskEnable)
   {
      PrintFormat("PROP RISK DAY RESET | start=%s startBalance=%.2f currentBalance=%.2f reconstructed=%s resetHourServer=%d",
                  TimeToString(g_propRiskDayStart, TIME_DATE | TIME_MINUTES),
                  g_propRiskDayStartBalance,
                  currentBalance,
                  (historyReady ? "YES" : "NO"),
                  InpPropDayResetHourServer);
   }
}

//+------------------------------------------------------------------+
//| PropRiskRefresh                                                  |
//+------------------------------------------------------------------+
void PropRiskRefresh(const bool forceDayAnchor = false)
{
   if(!g_propRiskInitialized)
      return;

   const datetime now = PropRiskServerTime();
   PropRiskRefreshDayAnchor(now, forceDayAnchor);

   g_propRiskFirmDailyLimitMoney =
      g_runtimePropAccountValue * InpPropFirmDailyLossLimitPct / 100.0;
   g_propRiskFirmTotalLimitMoney =
      g_runtimePropAccountValue * InpPropFirmTotalLossLimitPct / 100.0;
   g_propRiskDailyLimitMoney =
      MathMax(0.0, g_propRiskFirmDailyLimitMoney - InpPropDailySafetyBufferMoney);
   g_propRiskTotalLimitMoney =
      MathMax(0.0, g_propRiskFirmTotalLimitMoney - InpPropTotalSafetyBufferMoney);

   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_propRiskDailyLossMoney = MathMax(0.0, g_propRiskDayStartBalance - equity);
   g_propRiskTotalLossMoney = MathMax(0.0, g_runtimePropAccountValue - equity);
   g_propRiskConsecutiveLosses =
      PropRiskCountConsecutiveLosses(g_propRiskDayStart, now);

   if(!g_runtimePropRiskEnable)
      return;

   if(!g_propRiskTotalLocked &&
      g_propRiskTotalLossMoney + 0.005 >= g_propRiskTotalLimitMoney)
   {
      g_propRiskTotalLocked = true;
      g_propRiskTotalLockReason = "TOTAL_DD_LIMIT";
      if(InpPropRiskLog)
         PrintFormat("PROP RISK LOCK | reason=%s equity=%.2f totalDD=%.2f limit=%.2f",
                     g_propRiskTotalLockReason, equity,
                     g_propRiskTotalLossMoney, g_propRiskTotalLimitMoney);
   }

   if(!g_propRiskDailyLocked &&
      g_propRiskDailyLossMoney + 0.005 >= g_propRiskDailyLimitMoney)
   {
      g_propRiskDailyLocked = true;
      g_propRiskDailyLockReason = "DAILY_DD_LIMIT";
      if(InpPropRiskLog)
         PrintFormat("PROP RISK LOCK | reason=%s equity=%.2f dayStartBalance=%.2f dailyDD=%.2f limit=%.2f",
                     g_propRiskDailyLockReason, equity,
                     g_propRiskDayStartBalance,
                     g_propRiskDailyLossMoney, g_propRiskDailyLimitMoney);
   }

   if(!g_propRiskDailyLocked &&
      InpPropMaxConsecutiveLosses > 0 &&
      g_propRiskConsecutiveLosses >= InpPropMaxConsecutiveLosses)
   {
      g_propRiskDailyLocked = true;
      g_propRiskDailyLockReason = "CONSECUTIVE_LOSSES";
      if(InpPropRiskLog)
         PrintFormat("PROP RISK LOCK | reason=%s losses=%d limit=%d",
                     g_propRiskDailyLockReason,
                     g_propRiskConsecutiveLosses,
                     InpPropMaxConsecutiveLosses);
   }
}

//+------------------------------------------------------------------+
//| PropRiskSetRuntimeAccountValue                                   |
//| Keeps the panel value authoritative and recalculates every limit.|
//+------------------------------------------------------------------+
bool PropRiskSetRuntimeAccountValue(const double accountValue,
                                    const string source)
{
   const double previousValue = g_runtimePropAccountValue;
   g_runtimePropAccountValue = accountValue;

   string reason = "";
   if(!PropRiskValidateParameters(reason))
   {
      g_runtimePropAccountValue = previousValue;
      PrintFormat("PROP ACCOUNT VALUE REJECTED | source=%s requested=%.2f kept=%.2f reason=%s",
                  source, accountValue, previousValue, reason);
      return false;
   }

   g_propRiskDailyLocked = false;
   g_propRiskTotalLocked = false;
   g_propRiskDailyLockReason = "";
   g_propRiskTotalLockReason = "";
   g_propRiskLastBlockLogReason = "";
   if(g_propRiskInitialized)
      PropRiskRefresh(true);
   return true;
}

//+------------------------------------------------------------------+
//| PropRiskInitialize                                               |
//+------------------------------------------------------------------+
bool PropRiskInitialize()
{
   if(!MathIsValidNumber(g_runtimePropAccountValue) || g_runtimePropAccountValue <= 0.0)
      g_runtimePropAccountValue = InpPropAccountValue;

   string reason = "";
   if(InpPropRiskEnable && !PropRiskValidateParameters(reason))
   {
      Print("PROP RISK INVALID PARAMETERS | ", reason);
      return false;
   }

   g_propRiskInitialized = true;
   g_runtimePropRiskEnable = InpPropRiskEnable;
   g_propRiskDailyLocked = false;
   g_propRiskTotalLocked = false;
   g_propRiskDailyLockReason = "";
   g_propRiskTotalLockReason = "";
   PropRiskRefresh(true);

   if(InpPropRiskLog)
   {
      PrintFormat("PROP RISK INIT | enabled=%s account=%.2f firmDaily=%.2f%%/%.2f buffer=%.2f robotDaily=%.2f firmTotal=%.2f%%/%.2f buffer=%.2f robotTotal=%.2f maxLossSeq=%d emergencyCloseEA=%s",
                  (g_runtimePropRiskEnable ? "YES" : "NO"),
                  g_runtimePropAccountValue,
                  InpPropFirmDailyLossLimitPct,
                  g_propRiskFirmDailyLimitMoney,
                  InpPropDailySafetyBufferMoney,
                  g_propRiskDailyLimitMoney,
                  InpPropFirmTotalLossLimitPct,
                  g_propRiskFirmTotalLimitMoney,
                  InpPropTotalSafetyBufferMoney,
                  g_propRiskTotalLimitMoney,
                  InpPropMaxConsecutiveLosses,
                  (InpPropEmergencyCloseEAPositions ? "YES" : "NO"));
   }
   return true;
}

//+------------------------------------------------------------------+
//| PropRiskSetRuntimeEnabled                                        |
//+------------------------------------------------------------------+
bool PropRiskSetRuntimeEnabled(const bool enabled,
                               const string source)
{
   if(enabled)
   {
      string reason = "";
      if(!PropRiskValidateParameters(reason))
      {
         PrintFormat("PROP RISK ENABLE REJECTED | source=%s reason=%s", source, reason);
         g_runtimePropRiskEnable = false;
         return false;
      }
   }

   g_runtimePropRiskEnable = enabled;
   g_propRiskDailyLocked = false;
   g_propRiskTotalLocked = false;
   g_propRiskDailyLockReason = "";
   g_propRiskTotalLockReason = "";
   g_propRiskLastBlockLogReason = "";
   PropRiskRefresh(true);

   if(InpPropRiskLog)
      PrintFormat("PROP RISK RUNTIME | enabled=%s source=%s",
                  (enabled ? "YES" : "NO"), source);
   return true;
}

//+------------------------------------------------------------------+
//| PropRiskCurrentLockReason                                        |
//+------------------------------------------------------------------+
string PropRiskCurrentLockReason()
{
   if(g_propRiskTotalLocked)
      return g_propRiskTotalLockReason;
   if(g_propRiskDailyLocked)
      return g_propRiskDailyLockReason;
   return "";
}

//+------------------------------------------------------------------+
//| PropRiskAllowsNewTrade                                           |
//+------------------------------------------------------------------+
bool PropRiskAllowsNewTrade(string &reason)
{
   reason = "";
   if(!g_runtimePropRiskEnable)
      return true;

   PropRiskRefresh(false);
   reason = PropRiskCurrentLockReason();
   return (reason == "");
}

//+------------------------------------------------------------------+
//| PropRiskLogEntryBlock                                            |
//+------------------------------------------------------------------+
void PropRiskLogEntryBlock(const string reason)
{
   if(!InpPropRiskLog || reason == "")
      return;
   if(reason == g_propRiskLastBlockLogReason)
      return;

   g_propRiskLastBlockLogReason = reason;
   PrintFormat("PROP RISK ENTRY BLOCK | reason=%s dailyDD=%.2f/%.2f totalDD=%.2f/%.2f lossSeq=%d/%d",
               reason,
               g_propRiskDailyLossMoney, g_propRiskDailyLimitMoney,
               g_propRiskTotalLossMoney, g_propRiskTotalLimitMoney,
               g_propRiskConsecutiveLosses, InpPropMaxConsecutiveLosses);
}

//+------------------------------------------------------------------+
//| PropRiskCloseEAPositions                                         |
//+------------------------------------------------------------------+
bool PropRiskCloseEAPositions(const string reason)
{
   if(g_propRiskCloseAttemptActive)
      return false;

   g_propRiskCloseAttemptActive = true;
   bool attempted = false;
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      attempted = true;
      const string symbol = PositionGetString(POSITION_SYMBOL);
      const double profit = PositionGetDouble(POSITION_PROFIT) +
                            PositionGetDouble(POSITION_SWAP);
      const bool closed = trade.PositionClose(ticket, (ulong)InpDeviationPoints);
      if(InpPropRiskLog)
      {
         PrintFormat("PROP RISK EMERGENCY CLOSE | reason=%s ticket=%I64u symbol=%s profit=%.2f result=%s retcode=%u comment=%s",
                     reason, ticket, symbol, profit,
                     (closed ? "SENT" : "FAILED"),
                     trade.ResultRetcode(), trade.ResultComment());
      }
   }
   g_propRiskCloseAttemptActive = false;
   return attempted;
}

//+------------------------------------------------------------------+
//| PropRiskProcess                                                  |
//| Returns true while the guard is locked, so the caller cannot run |
//| any new strategy/order action on the same tick.                  |
//+------------------------------------------------------------------+
bool PropRiskProcess()
{
   if(!g_runtimePropRiskEnable)
      return false;

   PropRiskRefresh(false);
   const string reason = PropRiskCurrentLockReason();
   if(reason == "")
      return false;

   PropRiskLogEntryBlock(reason);
   if(InpPropEmergencyCloseEAPositions)
      PropRiskCloseEAPositions(reason);
   return true;
}

//+------------------------------------------------------------------+
//| PropRiskOnTradeTransaction                                       |
//+------------------------------------------------------------------+
void PropRiskOnTradeTransaction(const MqlTradeTransaction &trans)
{
   if(!g_propRiskInitialized || trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;
   PropRiskRefresh(false);
}

//+------------------------------------------------------------------+
//| PropRiskDeinitialize                                             |
//+------------------------------------------------------------------+
void PropRiskDeinitialize()
{
   g_propRiskInitialized = false;
   g_propRiskCloseAttemptActive = false;
}

#endif // __EA_ML_M5_PROP_RISK_MQH__
