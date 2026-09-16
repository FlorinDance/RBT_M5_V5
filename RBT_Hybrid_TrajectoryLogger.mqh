//+------------------------------------------------------------------+
//| RBT_Hybrid_TrajectoryLogger.mqh                                  |
//| Tick-causal trajectory for the normal hybrid audit.              |
//+------------------------------------------------------------------+
#ifndef __RBT_HYBRID_TRAJECTORY_LOGGER_MQH__
#define __RBT_HYBRID_TRAJECTORY_LOGGER_MQH__

#define RBT_HYBRID_TRAJECTORY_SCHEMA "RBT-M5-HYBRID-TRAJECTORY-4"

struct SRBTHybridTrajectory
{
   long positionId;
   datetime openTime;
   long openTimeMsc;
   int direction;
   double entryPrice;
   double initialVolume;
   double riskMultiplier;
   double entryCosts;
   bool firstProfitSeen;
   datetime firstProfitTime;
   long firstProfitTimeMsc;
   double firstProfitMinutes;
   double firstProfitMoney;
   bool seen5;
   bool seen10;
   bool seen15;
   bool seen30;
   double money5;
   double money10;
   double money15;
   double money30;
   double maxMoney5;
   double maxMoney10;
   double maxMoney15;
   double maxMoney30;
   double maxMoneyLifetime;
   double minMoneyLifetime;
   bool profitProtectEnabled;
   string profitProtectPolicy;
   double profitProtectArmThresholdMoney;
   double profitProtectFloorMoney;
   bool profitProtectArmed;
   datetime profitProtectArmTime;
   long profitProtectArmTimeMsc;
   double profitProtectArmMinutes;
   double profitProtectArmMoney;
   string requestedExitPolicy;
   double requestedExitMoney;
   int motifDirection;
   double motifConfidence;
   double motifExpectedNetATR;
   double motifGrossCostRatio;
};

int g_hybridTrajectoryHandle = INVALID_HANDLE;
string g_hybridTrajectoryName = "";
long g_hybridTrajectoryRows = 0;
SRBTHybridTrajectory g_hybridTrajectories[];

int HybridTrajectoryFind(const long positionId)
{
   for(int i=0; i<ArraySize(g_hybridTrajectories); i++)
      if(g_hybridTrajectories[i].positionId == positionId)
         return i;
   return -1;
}

bool HybridTrajectoryTrackingRequired()
{
   return InpHybridTrajectoryEnable;
}

void HybridTrajectorySetRequestedExitPolicy(const long positionId,
   const string policy,const double requestMoney)
{
   const int index = HybridTrajectoryFind(positionId);
   if(index < 0)
      return;
   g_hybridTrajectories[index].requestedExitPolicy = policy;
   g_hybridTrajectories[index].requestedExitMoney = requestMoney;
}

void HybridTrajectoryClearRequestedExitPolicy(const long positionId)
{
   const int index = HybridTrajectoryFind(positionId);
   if(index < 0)
      return;
   g_hybridTrajectories[index].requestedExitPolicy = "";
   g_hybridTrajectories[index].requestedExitMoney = 0.0;
}

bool HybridTrajectorySelectPosition(const long positionId)
{
   for(int i=0; i<PositionsTotal(); i++)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket > 0 && (long)PositionGetInteger(POSITION_IDENTIFIER) == positionId)
         return true;
   }
   return false;
}

string HybridTrajectoryNumber(const bool available,const double value,const int digits=2)
{
   return (available ? DoubleToString(value,digits) : "");
}

double HybridTrajectoryMoneyScale(const SRBTHybridTrajectory &t)
{
   return (InpHybridScaleTPWithLot ? MathMax(0.0,t.riskMultiplier) : 1.0);
}

void HybridTrajectoryResolveProfitProtectPolicy(SRBTHybridTrajectory &t)
{
   t.profitProtectEnabled = false;
   t.profitProtectPolicy = "DISABLED";
   t.profitProtectArmThresholdMoney = 0.0;
   t.profitProtectFloorMoney = 0.0;
}

bool HybridTrajectoryInitialize()
{
   ArrayResize(g_hybridTrajectories,0);
   if(!InpHybridTrajectoryEnable)
      return true;
   int flags = FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_SHARE_READ;
   if(InpHybridCSVUseCommonFiles)
   {
      flags |= FILE_COMMON;
      FolderCreate("RBT_M5_V5",FILE_COMMON);
   }
   else
      FolderCreate("RBT_M5_V5");
   g_hybridTrajectoryName = "RBT_M5_V5\\RBT_M5_HYBRID_TRAJECTORY_" +
      HybridCSVRuntimeLabel() + ".csv";
   g_hybridTrajectoryHandle = FileOpen(g_hybridTrajectoryName,flags,';',CP_UTF8);
   if(g_hybridTrajectoryHandle == INVALID_HANDLE)
   {
      PrintFormat("HYBRID trajectory CSV open failed | file=%s error=%d",
                  g_hybridTrajectoryName,GetLastError());
      return false;
   }
   FileWrite(g_hybridTrajectoryHandle,
      "schema","version","symbol","position_id","direction","open_time",
      "close_time","entry_price","initial_volume","risk_multiplier","first_profit_seen",
      "first_profit_time","first_profit_minutes","first_profit_money",
      "first_profit_bucket","money_at_5m","money_at_10m","money_at_15m",
      "money_at_30m","max_money_0_5m","max_money_0_10m","max_money_0_15m",
      "max_money_0_30m","max_money_lifetime","min_money_lifetime",
      "profit_protect_enabled","profit_protect_policy",
      "profit_protect_arm_threshold_money",
      "profit_protect_floor_money","profit_protect_armed",
      "profit_protect_arm_time","profit_protect_arm_minutes",
      "profit_protect_arm_money","exit_request_money",
      "close_minutes","final_net_money","final_result","motif_direction",
      "motif_confidence","motif_expected_net_atr","motif_gross_cost_ratio",
      "motif_oppose_at_020","motif_oppose_at_040","motif_oppose_at_060",
      "exit_policy","runtime_mode","contract");
   FileFlush(g_hybridTrajectoryHandle);
   PrintFormat("HYBRID trajectory CSV ready | %s%s",
      (InpHybridCSVUseCommonFiles ? "Common\\Files\\" : "MQL5\\Files\\"),
      g_hybridTrajectoryName);
   return true;
}

void HybridTrajectoryAddEntry(const ulong dealTicket)
{
   const long positionId = (long)HistoryDealGetInteger(dealTicket,DEAL_POSITION_ID);
   if(positionId <= 0 || HybridTrajectoryFind(positionId) >= 0)
      return;
   const int n = ArraySize(g_hybridTrajectories);
   ArrayResize(g_hybridTrajectories,n+1);
   SRBTHybridTrajectory t;
   ZeroMemory(t);
   t.positionId = positionId;
   t.openTime = (datetime)HistoryDealGetInteger(dealTicket,DEAL_TIME);
   t.openTimeMsc = (long)HistoryDealGetInteger(dealTicket,DEAL_TIME_MSC);
   const ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(dealTicket,DEAL_TYPE);
   t.direction = (dealType == DEAL_TYPE_BUY ? 1 : -1);
   t.entryPrice = HistoryDealGetDouble(dealTicket,DEAL_PRICE);
   t.initialVolume = HistoryDealGetDouble(dealTicket,DEAL_VOLUME);
   t.riskMultiplier = (g_runtimeLots > 0.0 ?
      MathMax(0.0,t.initialVolume/g_runtimeLots) : 1.0);
   t.entryCosts = HistoryDealGetDouble(dealTicket,DEAL_COMMISSION) +
                  HistoryDealGetDouble(dealTicket,DEAL_FEE) +
                  HistoryDealGetDouble(dealTicket,DEAL_SWAP);
   t.maxMoney5 = t.maxMoney10 = t.maxMoney15 = t.maxMoney30 = -1.0e308;
   t.maxMoneyLifetime = -1.0e308;
   t.minMoneyLifetime = 1.0e308;
   t.requestedExitPolicy = "";
   t.motifDirection = g_hybridMotifLast.direction;
   t.motifConfidence = g_hybridMotifLast.confidence;
   t.motifExpectedNetATR = g_hybridMotifLast.expectedNetATR;
   t.motifGrossCostRatio = g_hybridMotifLast.grossToCostRatio;
   HybridTrajectoryResolveProfitProtectPolicy(t);
   g_hybridTrajectories[n] = t;
}

void HybridTrajectoryUpdate(const int index,const long nowMsc)
{
   if(index < 0 || index >= ArraySize(g_hybridTrajectories) ||
      !HybridTrajectorySelectPosition(g_hybridTrajectories[index].positionId))
      return;
   SRBTHybridTrajectory t = g_hybridTrajectories[index];
   const double elapsed = MathMax(0.0,(double)(nowMsc-t.openTimeMsc)/60000.0);
   const double money = PositionGetDouble(POSITION_PROFIT) +
                        PositionGetDouble(POSITION_SWAP) + t.entryCosts;
   t.maxMoneyLifetime = MathMax(t.maxMoneyLifetime,money);
   t.minMoneyLifetime = MathMin(t.minMoneyLifetime,money);
   if(elapsed <= 5.0)  t.maxMoney5  = MathMax(t.maxMoney5,money);
   if(elapsed <= 10.0) t.maxMoney10 = MathMax(t.maxMoney10,money);
   if(elapsed <= 15.0) t.maxMoney15 = MathMax(t.maxMoney15,money);
   if(elapsed <= 30.0) t.maxMoney30 = MathMax(t.maxMoney30,money);
   if(!t.firstProfitSeen && money >= InpHybridFirstProfitEpsilonMoney)
   {
      t.firstProfitSeen = true;
      t.firstProfitTimeMsc = nowMsc;
      t.firstProfitTime = (datetime)(nowMsc/1000);
      t.firstProfitMinutes = elapsed;
      t.firstProfitMoney = money;
   }
   if(!t.seen5 && elapsed >= 5.0)   { t.seen5=true;  t.money5=money; }
   if(!t.seen10 && elapsed >= 10.0) { t.seen10=true; t.money10=money; }
   if(!t.seen15 && elapsed >= 15.0) { t.seen15=true; t.money15=money; }
   if(!t.seen30 && elapsed >= 30.0) { t.seen30=true; t.money30=money; }
   g_hybridTrajectories[index] = t;
}

void HybridTrajectoryProcessTick()
{
   if(!HybridTrajectoryTrackingRequired())
      return;
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick))
      return;
   for(int i=0; i<ArraySize(g_hybridTrajectories); i++)
      HybridTrajectoryUpdate(i,(long)tick.time_msc);
}

string HybridTrajectoryFirstProfitBucket(const SRBTHybridTrajectory &t)
{
   if(!t.firstProfitSeen) return "NEVER";
   if(t.firstProfitMinutes <= 5.0) return "0_5_MIN";
   if(t.firstProfitMinutes <= 10.0) return "5_10_MIN";
   if(t.firstProfitMinutes <= 15.0) return "10_15_MIN";
   if(t.firstProfitMinutes <= 30.0) return "15_30_MIN";
   return "AFTER_30_MIN";
}

double HybridTrajectoryFinalNet(const long positionId)
{
   double net = 0.0;
   if(!HistorySelectByPosition((ulong)positionId))
      return net;
   for(int i=0; i<HistoryDealsTotal(); i++)
   {
      const ulong deal = HistoryDealGetTicket(i);
      if(deal == 0) continue;
      net += HistoryDealGetDouble(deal,DEAL_PROFIT) +
             HistoryDealGetDouble(deal,DEAL_COMMISSION) +
             HistoryDealGetDouble(deal,DEAL_SWAP) +
             HistoryDealGetDouble(deal,DEAL_FEE);
   }
   return net;
}

void HybridTrajectoryRemove(const int index)
{
   const int n = ArraySize(g_hybridTrajectories);
   for(int i=index; i<n-1; i++)
      g_hybridTrajectories[i] = g_hybridTrajectories[i+1];
   ArrayResize(g_hybridTrajectories,n-1);
}

void HybridTrajectoryClose(const int index,const ulong closeDealTicket,
   const datetime closeTime,const long closeTimeMsc)
{
   if(index < 0 || index >= ArraySize(g_hybridTrajectories))
      return;
   const SRBTHybridTrajectory t = g_hybridTrajectories[index];
   if(g_hybridTrajectoryHandle == INVALID_HANDLE)
   {
      HybridTrajectoryRemove(index);
      return;
   }
   const double closeMinutes = MathMax(0.0,(double)(closeTimeMsc-t.openTimeMsc)/60000.0);
   const double finalNet = HybridTrajectoryFinalNet(t.positionId);
   const ENUM_DEAL_REASON dealReason = (ENUM_DEAL_REASON)
      HistoryDealGetInteger(closeDealTicket,DEAL_REASON);
   string exitPolicy = EnumToString(dealReason);
   if(dealReason == DEAL_REASON_TP) exitPolicy = "TP";
   else if(dealReason == DEAL_REASON_SL) exitPolicy = "SL";
   else if(dealReason == DEAL_REASON_EXPERT && StringLen(t.requestedExitPolicy)>0)
      exitPolicy = t.requestedExitPolicy;
   const int xgbDirection = t.direction;
   const bool motifOppose = (t.motifDirection != 0 && t.motifDirection != xgbDirection);
   const bool passBase = (t.motifConfidence >= InpMotifDirectionConfidence &&
      t.motifGrossCostRatio >= InpMotifMinimumGrossToCostRatio);
   FileWrite(g_hybridTrajectoryHandle,
      RBT_HYBRID_TRAJECTORY_SCHEMA,"5.10.17",_Symbol,t.positionId,
      (t.direction>0 ? "BUY" : "SELL"),
      TimeToString(t.openTime,TIME_DATE|TIME_SECONDS),
      TimeToString(closeTime,TIME_DATE|TIME_SECONDS),
      DoubleToString(t.entryPrice,_Digits),DoubleToString(t.initialVolume,4),
      DoubleToString(t.riskMultiplier,6),
      (int)t.firstProfitSeen,
      (t.firstProfitSeen ? TimeToString(t.firstProfitTime,TIME_DATE|TIME_SECONDS) : ""),
      HybridTrajectoryNumber(t.firstProfitSeen,t.firstProfitMinutes,6),
      HybridTrajectoryNumber(t.firstProfitSeen,t.firstProfitMoney,2),
      HybridTrajectoryFirstProfitBucket(t),
      HybridTrajectoryNumber(t.seen5,t.money5,2),
      HybridTrajectoryNumber(t.seen10,t.money10,2),
      HybridTrajectoryNumber(t.seen15,t.money15,2),
      HybridTrajectoryNumber(t.seen30,t.money30,2),
      HybridTrajectoryNumber(t.maxMoney5>-1.0e307,t.maxMoney5,2),
      HybridTrajectoryNumber(t.maxMoney10>-1.0e307,t.maxMoney10,2),
      HybridTrajectoryNumber(t.maxMoney15>-1.0e307,t.maxMoney15,2),
      HybridTrajectoryNumber(t.maxMoney30>-1.0e307,t.maxMoney30,2),
      HybridTrajectoryNumber(t.maxMoneyLifetime>-1.0e307,t.maxMoneyLifetime,2),
      HybridTrajectoryNumber(t.minMoneyLifetime<1.0e307,t.minMoneyLifetime,2),
      (int)t.profitProtectEnabled,t.profitProtectPolicy,
      DoubleToString(t.profitProtectArmThresholdMoney,2),
      DoubleToString(t.profitProtectFloorMoney,2),
      (int)t.profitProtectArmed,
      (t.profitProtectArmed ? TimeToString(t.profitProtectArmTime,TIME_DATE|TIME_SECONDS) : ""),
      HybridTrajectoryNumber(t.profitProtectArmed,t.profitProtectArmMinutes,6),
      HybridTrajectoryNumber(t.profitProtectArmed,t.profitProtectArmMoney,2),
      HybridTrajectoryNumber(StringLen(t.requestedExitPolicy)>0,t.requestedExitMoney,2),
      DoubleToString(closeMinutes,6),DoubleToString(finalNet,2),
      (finalNet>InpHybridFirstProfitEpsilonMoney ? "WIN" :
       (finalNet<-InpHybridFirstProfitEpsilonMoney ? "LOSS" : "BREAKEVEN")),
      t.motifDirection,DoubleToString(t.motifConfidence,8),
      DoubleToString(t.motifExpectedNetATR,8),DoubleToString(t.motifGrossCostRatio,8),
      (int)(motifOppose && passBase && t.motifExpectedNetATR>=0.20),
      (int)(motifOppose && passBase && t.motifExpectedNetATR>=0.40),
      (int)(motifOppose && passBase && t.motifExpectedNetATR>=0.60),
      exitPolicy,
      HybridCSVRuntimeMode(),
      "HYBRID_TEST");
   g_hybridTrajectoryRows++;
   FileFlush(g_hybridTrajectoryHandle);
   HybridTrajectoryRemove(index);
}

void HybridTrajectoryOnTradeTransaction(const MqlTradeTransaction &trans)
{
   if(!HybridTrajectoryTrackingRequired() ||
      trans.type != TRADE_TRANSACTION_DEAL_ADD || trans.deal == 0 ||
      !HistoryDealSelect(trans.deal) ||
      (long)HistoryDealGetInteger(trans.deal,DEAL_MAGIC) != InpMagicNumber ||
      HistoryDealGetString(trans.deal,DEAL_SYMBOL) != _Symbol)
      return;
   const ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal,DEAL_ENTRY);
   if(entry == DEAL_ENTRY_IN)
   {
      HybridTrajectoryAddEntry(trans.deal);
      return;
   }
   if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY && entry != DEAL_ENTRY_INOUT)
      return;
   const long positionId = (long)HistoryDealGetInteger(trans.deal,DEAL_POSITION_ID);
   const int index = HybridTrajectoryFind(positionId);
   if(index >= 0 && !HybridTrajectorySelectPosition(positionId))
      HybridTrajectoryClose(index,trans.deal,
         (datetime)HistoryDealGetInteger(trans.deal,DEAL_TIME),
         (long)HistoryDealGetInteger(trans.deal,DEAL_TIME_MSC));
}

void HybridTrajectoryShutdown(const int reason)
{
   if(g_hybridTrajectoryHandle != INVALID_HANDLE)
   {
      FileFlush(g_hybridTrajectoryHandle);
      FileClose(g_hybridTrajectoryHandle);
      g_hybridTrajectoryHandle = INVALID_HANDLE;
   }
   PrintFormat("HYBRID trajectory CSV finished | reason=%d rows=%I64d open=%d file=%s",
      reason,g_hybridTrajectoryRows,ArraySize(g_hybridTrajectories),g_hybridTrajectoryName);
}

#endif
