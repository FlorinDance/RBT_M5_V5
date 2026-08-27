//+------------------------------------------------------------------+
//| RBT_Hybrid_CSVLogger.mqh                                         |
//| One auditable CSV: hybrid entry attempts and realized closes.    |
//+------------------------------------------------------------------+
#ifndef __RBT_HYBRID_CSV_LOGGER_MQH__
#define __RBT_HYBRID_CSV_LOGGER_MQH__

#define RBT_HYBRID_CSV_SCHEMA "RBT-M5-HYBRID-EVENT-1"

int g_hybridCSVHandle = INVALID_HANDLE;
string g_hybridCSVName = "";
long g_hybridCSVRows = 0;
long g_hybridCSVSignalNumber = 0;

string HybridCSVSafeText(string value)
{
   StringReplace(value, ";", ",");
   StringReplace(value, "\r", " ");
   StringReplace(value, "\n", " ");
   return value;
}

string HybridCSVSafeLabel(string value)
{
   StringReplace(value, "\\", "_");
   StringReplace(value, "/", "_");
   StringReplace(value, ":", "_");
   StringReplace(value, "*", "_");
   StringReplace(value, "?", "_");
   StringReplace(value, "\"", "_");
   StringReplace(value, "<", "_");
   StringReplace(value, ">", "_");
   StringReplace(value, "|", "_");
   StringReplace(value, " ", "_");
   return value;
}

bool HybridCSVInitialize()
{
   if(!InpHybridCSVEnable)
      return true;
   const string label = HybridCSVSafeLabel(InpHybridRunLabel);
   if(StringLen(label) < 1)
   {
      Print("HYBRID CSV invalid empty run label.");
      return false;
   }
   int flags = FILE_WRITE | FILE_CSV | FILE_ANSI | FILE_SHARE_READ;
   if(InpHybridCSVUseCommonFiles)
   {
      flags |= FILE_COMMON;
      FolderCreate("RBT_M5_V5", FILE_COMMON);
   }
   else
      FolderCreate("RBT_M5_V5");
   g_hybridCSVName = "RBT_M5_V5\\RBT_M5_HYBRID_EVENTS_" + label + ".csv";
   g_hybridCSVHandle = FileOpen(g_hybridCSVName, flags, ';', CP_UTF8);
   if(g_hybridCSVHandle == INVALID_HANDLE)
   {
      PrintFormat("HYBRID CSV open failed | file=%s error=%d", g_hybridCSVName, GetLastError());
      return false;
   }
   FileWrite(g_hybridCSVHandle,
      "schema","version","event","server_time","time_msc","signal_number",
      "symbol","timeframe","xgb_decision","p_sell","p_hold","p_buy",
      "chosen_probability","decision_gap","motif_state","motif_anchor",
      "motif_age_minutes","motif_id","motif_direction","motif_confidence",
      "motif_expected_net_atr","motif_gross_cost_ratio","motif_strong",
      "base_lot","lot_multiplier","effective_lot","base_tp_money",
      "tp_multiplier","effective_tp_money","sl_pips","allow_trade",
      "hybrid_reason","opened","retcode","order_ticket","deal_ticket",
      "position_id","deal_entry","deal_reason","deal_price","deal_volume",
      "profit","commission","swap","fee","net_money","comment","contract");
   FileFlush(g_hybridCSVHandle);
   PrintFormat("HYBRID CSV ready | %s%s",
      (InpHybridCSVUseCommonFiles ? "Common\\Files\\" : "MQL5\\Files\\"),
      g_hybridCSVName);
   return true;
}

void HybridCSVFlushIfNeeded()
{
   if(g_hybridCSVHandle != INVALID_HANDLE && InpHybridCSVFlushEveryRows > 0 &&
      (g_hybridCSVRows % InpHybridCSVFlushEveryRows) == 0)
      FileFlush(g_hybridCSVHandle);
}

long HybridCSVLogEntry(const int decision,
   const double pSell, const double pHold, const double pBuy,
   const double chosenProbability, const double decisionGap,
   const ENUM_RBT_HYBRID_MOTIF_STATE motifState,
   const double baseLot, const double lotMultiplier, const double effectiveLot,
   const double baseTPMoney, const double tpMultiplier,
   const double effectiveTPMoney, const double slPips,
   const bool allowTrade, const string hybridReason,
   const bool opened, const long retcode, const ulong orderTicket,
   const ulong dealTicket, const string comment)
{
   g_hybridCSVSignalNumber++;
   if(g_hybridCSVHandle == INVALID_HANDLE)
      return g_hybridCSVSignalNumber;
   MqlTick tick;
   ZeroMemory(tick);
   SymbolInfoTick(_Symbol, tick);
   const datetime now = TimeCurrent();
   const double motifAge = (g_hybridMotifLast.valid ?
      (double)(now - g_hybridMotifLast.anchorTime) / 60.0 : -1.0);
   const long positionId = (dealTicket > 0 ?
      (long)HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID) : 0);
   FileWrite(g_hybridCSVHandle,
      RBT_HYBRID_CSV_SCHEMA,"5.10.1","ENTRY",
      TimeToString(now,TIME_DATE|TIME_SECONDS),(long)tick.time_msc,
      g_hybridCSVSignalNumber,_Symbol,"M5",M5_DecisionName(decision),
      DoubleToString(pSell,8),DoubleToString(pHold,8),DoubleToString(pBuy,8),
      DoubleToString(chosenProbability,8),DoubleToString(decisionGap,8),
      RBTHybridMotifStateName(motifState),
      (g_hybridMotifLast.valid ? TimeToString(g_hybridMotifLast.anchorTime,TIME_DATE|TIME_SECONDS) : ""),
      DoubleToString(motifAge,3),g_hybridMotifLast.motifId,
      g_hybridMotifLast.direction,DoubleToString(g_hybridMotifLast.confidence,8),
      DoubleToString(g_hybridMotifLast.expectedNetATR,8),
      DoubleToString(g_hybridMotifLast.grossToCostRatio,8),(int)g_hybridMotifLast.strong,
      DoubleToString(baseLot,4),DoubleToString(lotMultiplier,6),
      DoubleToString(effectiveLot,4),DoubleToString(baseTPMoney,2),
      DoubleToString(tpMultiplier,6),DoubleToString(effectiveTPMoney,2),
      DoubleToString(slPips,3),(int)allowTrade,HybridCSVSafeText(hybridReason),
      (int)opened,retcode,orderTicket,dealTicket,positionId,"","",0.0,0.0,
      0.0,0.0,0.0,0.0,0.0,HybridCSVSafeText(comment),"HYBRID_TEST");
   g_hybridCSVRows++;
   HybridCSVFlushIfNeeded();
   return g_hybridCSVSignalNumber;
}

void HybridCSVOnTradeTransaction(const MqlTradeTransaction &trans)
{
   if(g_hybridCSVHandle == INVALID_HANDLE || trans.type != TRADE_TRANSACTION_DEAL_ADD ||
      trans.deal == 0 || !HistoryDealSelect(trans.deal))
      return;
   if((long)HistoryDealGetInteger(trans.deal, DEAL_MAGIC) != InpMagicNumber ||
      HistoryDealGetString(trans.deal, DEAL_SYMBOL) != _Symbol)
      return;
   const ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY && entry != DEAL_ENTRY_INOUT)
      return;
   const datetime dealTime = (datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME);
   const long dealTimeMsc = (long)HistoryDealGetInteger(trans.deal, DEAL_TIME_MSC);
   const long positionId = (long)HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
   const double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
   const double commission = HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
   const double swap = HistoryDealGetDouble(trans.deal, DEAL_SWAP);
   const double fee = HistoryDealGetDouble(trans.deal, DEAL_FEE);
   const double net = profit + commission + swap + fee;
   FileWrite(g_hybridCSVHandle,
      RBT_HYBRID_CSV_SCHEMA,"5.10.1","CLOSE",
      TimeToString(dealTime,TIME_DATE|TIME_SECONDS),dealTimeMsc,0,
      _Symbol,"M5","","","","","","","","","","","","","","","",
      "","","","","","","","","","",0,0,0,trans.deal,positionId,
      EnumToString(entry),EnumToString((ENUM_DEAL_REASON)HistoryDealGetInteger(trans.deal,DEAL_REASON)),
      DoubleToString(HistoryDealGetDouble(trans.deal,DEAL_PRICE),_Digits),
      DoubleToString(HistoryDealGetDouble(trans.deal,DEAL_VOLUME),4),
      DoubleToString(profit,2),DoubleToString(commission,2),DoubleToString(swap,2),
      DoubleToString(fee,2),DoubleToString(net,2),
      HybridCSVSafeText(HistoryDealGetString(trans.deal,DEAL_COMMENT)),"HYBRID_TEST");
   g_hybridCSVRows++;
   HybridCSVFlushIfNeeded();
}

void HybridCSVShutdown(const int reason)
{
   if(g_hybridCSVHandle != INVALID_HANDLE)
   {
      FileFlush(g_hybridCSVHandle);
      FileClose(g_hybridCSVHandle);
      g_hybridCSVHandle = INVALID_HANDLE;
   }
   PrintFormat("HYBRID CSV finished | reason=%d rows=%I64d signals=%I64d file=%s",
               reason,g_hybridCSVRows,g_hybridCSVSignalNumber,g_hybridCSVName);
}

#endif
