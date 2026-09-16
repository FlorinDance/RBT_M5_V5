//+------------------------------------------------------------------+
//| RBT_NormalPolicyLab.mqh                                          |
//| Tick-causal shadow comparison for normal RBT profit protection.  |
//+------------------------------------------------------------------+
#ifndef __RBT_NORMAL_POLICY_LAB_MQH__
#define __RBT_NORMAL_POLICY_LAB_MQH__

#define RBT_NORMAL_POLICY_SCHEMA "RBT-M5-NORMAL-POLICY-1"

struct SRBTNormalShadowArm
{
   string name;
   double armMoney;
   double floorMoney;
   bool armed;
   bool closed;
   datetime closeTime;
   double closePrice;
   double finalMoney;
   string exitReason;
};

struct SRBTNormalPolicyTrade
{
   long positionId;
   datetime openTime;
   int direction;
   double entryPrice;
   double volume;
   double initialSL;
   double initialTP;
   double targetMoney;
   string motifRelation;
   bool actualClosed;
   datetime actualCloseTime;
   double actualMoney;
   string actualReason;
   SRBTNormalShadowArm prudent;
   SRBTNormalShadowArm permissive;
};

SRBTNormalPolicyTrade g_normalPolicyTrades[];
int g_normalPolicyHandle=INVALID_HANDLE;
string g_normalPolicyName="";
long g_normalPolicyRows=0;

int NormalPolicyFind(const long positionId)
{
   for(int i=0;i<ArraySize(g_normalPolicyTrades);i++)
      if(g_normalPolicyTrades[i].positionId==positionId) return i;
   return -1;
}

bool NormalPolicyValidateInputs(string &reason)
{
   reason="OK";
   const double p[]={InpNormalPrudentAgreeArmPctTP,InpNormalPrudentAgreeFloorPctTP,
      InpNormalPrudentOpposeArmPctTP,InpNormalPrudentOpposeFloorPctTP,
      InpNormalPermissiveAgreeArmPctTP,InpNormalPermissiveAgreeFloorPctTP,
      InpNormalPermissiveOpposeArmPctTP,InpNormalPermissiveOpposeFloorPctTP};
   for(int i=0;i<ArraySize(p);i++)
      if(p[i]<0.0 || p[i]>100.0) { reason="Normal policy percentages must be in [0,100]"; return false; }
   if(InpNormalPrudentAgreeFloorPctTP>=InpNormalPrudentAgreeArmPctTP ||
      InpNormalPrudentOpposeFloorPctTP>=InpNormalPrudentOpposeArmPctTP ||
      InpNormalPermissiveAgreeFloorPctTP>=InpNormalPermissiveAgreeArmPctTP ||
      InpNormalPermissiveOpposeFloorPctTP>=InpNormalPermissiveOpposeArmPctTP)
      reason="Each normal policy floor must be below its arm";
   return (reason=="OK");
}

bool NormalPolicyInitialize()
{
   ArrayResize(g_normalPolicyTrades,0);
   if(!InpNormalPolicyLabEnable) return true;
   int flags=FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ;
   if(InpHybridCSVUseCommonFiles) { flags|=FILE_COMMON; FolderCreate("RBT_M5_V5",FILE_COMMON); }
   else FolderCreate("RBT_M5_V5");
   g_normalPolicyName="RBT_M5_V5\\RBT_M5_NORMAL_POLICY_"+HybridCSVRuntimeLabel()+".csv";
   g_normalPolicyHandle=FileOpen(g_normalPolicyName,flags,';',CP_UTF8);
   if(g_normalPolicyHandle==INVALID_HANDLE) return false;
   FileWrite(g_normalPolicyHandle,"schema","version","symbol","position_id","open_time",
      "direction","volume","entry_price","initial_sl","initial_tp","target_money",
      "motif_relation","policy","arm_money","floor_money","armed","close_time",
      "close_price","final_money","exit_reason","contract");
   FileFlush(g_normalPolicyHandle);
   return true;
}

void NormalPolicyWrite(const SRBTNormalPolicyTrade &t,const SRBTNormalShadowArm &a)
{
   if(g_normalPolicyHandle==INVALID_HANDLE) return;
   FileWrite(g_normalPolicyHandle,RBT_NORMAL_POLICY_SCHEMA,"5.10.17",_Symbol,
      t.positionId,TimeToString(t.openTime,TIME_DATE|TIME_SECONDS),
      (t.direction>0?"BUY":"SELL"),DoubleToString(t.volume,2),
      DoubleToString(t.entryPrice,_Digits),DoubleToString(t.initialSL,_Digits),
      DoubleToString(t.initialTP,_Digits),DoubleToString(t.targetMoney,2),t.motifRelation,
      a.name,DoubleToString(a.armMoney,2),DoubleToString(a.floorMoney,2),(int)a.armed,
      TimeToString(a.closeTime,TIME_DATE|TIME_SECONDS),DoubleToString(a.closePrice,_Digits),
      DoubleToString(a.finalMoney,2),a.exitReason,"SHADOW_ONLY_NO_REAL_ACTIONS");
   g_normalPolicyRows++;
   if(InpHybridCSVFlushEveryRows<=1 || g_normalPolicyRows%InpHybridCSVFlushEveryRows==0)
      FileFlush(g_normalPolicyHandle);
}

double NormalPolicyMoney(const SRBTNormalPolicyTrade &t,const double exitPrice)
{
   double value=0.0;
   const ENUM_ORDER_TYPE type=(t.direction>0?ORDER_TYPE_BUY:ORDER_TYPE_SELL);
   if(!OrderCalcProfit(type,_Symbol,t.volume,t.entryPrice,exitPrice,value)) return 0.0;
   return value;
}

void NormalPolicyConfigureArm(SRBTNormalShadowArm &a,const string name,const double target,
   const bool agree,const bool prudent)
{
   a.name=name;
   const double armPct=(prudent ? (agree?InpNormalPrudentAgreeArmPctTP:InpNormalPrudentOpposeArmPctTP)
                                  : (agree?InpNormalPermissiveAgreeArmPctTP:InpNormalPermissiveOpposeArmPctTP));
   const double floorPct=(prudent ? (agree?InpNormalPrudentAgreeFloorPctTP:InpNormalPrudentOpposeFloorPctTP)
                                    : (agree?InpNormalPermissiveAgreeFloorPctTP:InpNormalPermissiveOpposeFloorPctTP));
   a.armMoney=target*armPct/100.0;
   a.floorMoney=target*floorPct/100.0;
}

void NormalPolicyAddEntry(const ulong dealTicket)
{
   if(!InpNormalPolicyLabEnable) return;
   const long id=(long)HistoryDealGetInteger(dealTicket,DEAL_POSITION_ID);
   if(id<=0 || NormalPolicyFind(id)>=0) return;
   const int n=ArraySize(g_normalPolicyTrades); ArrayResize(g_normalPolicyTrades,n+1);
   SRBTNormalPolicyTrade t; ZeroMemory(t);
   t.positionId=id; t.openTime=(datetime)HistoryDealGetInteger(dealTicket,DEAL_TIME);
   t.entryPrice=HistoryDealGetDouble(dealTicket,DEAL_PRICE);
   t.volume=HistoryDealGetDouble(dealTicket,DEAL_VOLUME);
   const ENUM_DEAL_TYPE dt=(ENUM_DEAL_TYPE)HistoryDealGetInteger(dealTicket,DEAL_TYPE);
   t.direction=(dt==DEAL_TYPE_BUY?1:-1);
   t.targetMoney=g_runtimeTakeProfitMoney*(InpHybridScaleTPWithLot && g_runtimeLots>0.0 ? t.volume/g_runtimeLots : 1.0);
   t.initialSL=0.0; t.initialTP=0.0;
   for(int i=0;i<PositionsTotal();i++)
   {
      const ulong ticket=PositionGetTicket(i);
      if(ticket>0 && (long)PositionGetInteger(POSITION_IDENTIFIER)==id)
      { t.initialSL=PositionGetDouble(POSITION_SL); t.initialTP=PositionGetDouble(POSITION_TP); break; }
   }
   if(t.initialTP>0.0)
   {
      const double tpValue=MathAbs(NormalPolicyMoney(t,t.initialTP));
      if(tpValue>0.0) t.targetMoney=tpValue;
   }
   const bool fresh=(g_hybridMotifLast.valid && TimeCurrent()>=g_hybridMotifLast.anchorTime &&
      TimeCurrent()-g_hybridMotifLast.anchorTime<=InpHybridMotifMaximumAgeMinutes*60);
   const bool agree=(fresh && g_hybridMotifLast.direction==t.direction);
   t.motifRelation=(agree?"AGREE":(fresh && g_hybridMotifLast.direction!=0?"OPPOSE":"UNAVAILABLE"));
   NormalPolicyConfigureArm(t.prudent,"PRUDENT",t.targetMoney,agree,true);
   NormalPolicyConfigureArm(t.permissive,"PERMISSIVE",t.targetMoney,agree,false);
   g_normalPolicyTrades[n]=t;
}

void NormalPolicyCloseArm(SRBTNormalPolicyTrade &t,SRBTNormalShadowArm &a,
   const datetime now,const double price,const double money,const string reason)
{
   if(a.closed) return;
   a.closed=true; a.closeTime=now; a.closePrice=price; a.finalMoney=money; a.exitReason=reason;
   NormalPolicyWrite(t,a);
}

void NormalPolicyUpdateArm(SRBTNormalPolicyTrade &t,SRBTNormalShadowArm &a,
   const datetime now,const double price,const double money)
{
   if(a.closed) return;
   if(!a.armed && money>=a.armMoney) a.armed=true;
   if(t.initialTP>0.0 && ((t.direction>0 && price>=t.initialTP)||(t.direction<0 && price<=t.initialTP)))
      NormalPolicyCloseArm(t,a,now,price,money,"TP_TICK_FILL");
   else if(t.initialSL>0.0 && ((t.direction>0 && price<=t.initialSL)||(t.direction<0 && price>=t.initialSL)))
      NormalPolicyCloseArm(t,a,now,price,money,"SL_TICK_FILL");
   else if(a.armed && money<=a.floorMoney)
      NormalPolicyCloseArm(t,a,now,price,money,"PROFIT_FLOOR");
}

void NormalPolicyProcessTick()
{
   if(!InpNormalPolicyLabEnable) return;
   MqlTick tick; if(!SymbolInfoTick(_Symbol,tick)) return;
   for(int i=0;i<ArraySize(g_normalPolicyTrades);i++)
   {
      SRBTNormalPolicyTrade t=g_normalPolicyTrades[i];
      if(t.prudent.closed && t.permissive.closed) continue;
      const double price=(t.direction>0?tick.bid:tick.ask);
      const double money=NormalPolicyMoney(t,price);
      NormalPolicyUpdateArm(t,t.prudent,(datetime)tick.time,price,money);
      NormalPolicyUpdateArm(t,t.permissive,(datetime)tick.time,price,money);
      g_normalPolicyTrades[i]=t;
   }
}

void NormalPolicySynchronizeActualClose(const ulong dealTicket)
{
   const long id=(long)HistoryDealGetInteger(dealTicket,DEAL_POSITION_ID);
   const int index=NormalPolicyFind(id);
   if(index<0) return;
   SRBTNormalPolicyTrade t=g_normalPolicyTrades[index];
   const datetime closeTime=(datetime)HistoryDealGetInteger(dealTicket,DEAL_TIME);
   const double closePrice=HistoryDealGetDouble(dealTicket,DEAL_PRICE);
   const double money=NormalPolicyMoney(t,closePrice);
   const ENUM_DEAL_REASON dr=(ENUM_DEAL_REASON)HistoryDealGetInteger(dealTicket,DEAL_REASON);
   string reason="BASELINE_CLOSE_"+EnumToString(dr);
   if(dr==DEAL_REASON_TP) reason="BASELINE_TP";
   else if(dr==DEAL_REASON_SL) reason="BASELINE_SL";
   else if(dr==DEAL_REASON_EXPERT) reason="BASELINE_EXPERT_CLOSE";
   if(!t.prudent.closed)
      NormalPolicyCloseArm(t,t.prudent,closeTime,closePrice,money,reason);
   if(!t.permissive.closed)
      NormalPolicyCloseArm(t,t.permissive,closeTime,closePrice,money,reason);
   t.actualClosed=true;
   t.actualCloseTime=closeTime;
   t.actualMoney=money;
   t.actualReason=reason;
   g_normalPolicyTrades[index]=t;
}

void NormalPolicyOnTradeTransaction(const MqlTradeTransaction &trans)
{
   if(!InpNormalPolicyLabEnable || trans.type!=TRADE_TRANSACTION_DEAL_ADD || trans.deal==0) return;
   if(!HistoryDealSelect(trans.deal)) return;
   if(HistoryDealGetString(trans.deal,DEAL_SYMBOL)!=_Symbol ||
      HistoryDealGetInteger(trans.deal,DEAL_MAGIC)!=InpMagicNumber) return;
   const ENUM_DEAL_ENTRY entry=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal,DEAL_ENTRY);
   if(entry==DEAL_ENTRY_IN) NormalPolicyAddEntry(trans.deal);
   else if(entry==DEAL_ENTRY_OUT || entry==DEAL_ENTRY_OUT_BY || entry==DEAL_ENTRY_INOUT)
      NormalPolicySynchronizeActualClose(trans.deal);
}

void NormalPolicyShutdown(const int reason)
{
   if(InpNormalPolicyLabEnable)
   {
      MqlTick tick;
      if(SymbolInfoTick(_Symbol,tick))
      {
         for(int i=0;i<ArraySize(g_normalPolicyTrades);i++)
         {
            SRBTNormalPolicyTrade t=g_normalPolicyTrades[i];
            const double price=(t.direction>0?tick.bid:tick.ask), money=NormalPolicyMoney(t,price);
            if(!t.prudent.closed) NormalPolicyCloseArm(t,t.prudent,(datetime)tick.time,price,money,"TEST_END");
            if(!t.permissive.closed) NormalPolicyCloseArm(t,t.permissive,(datetime)tick.time,price,money,"TEST_END");
            g_normalPolicyTrades[i]=t;
         }
      }
   }
   if(g_normalPolicyHandle!=INVALID_HANDLE) { FileFlush(g_normalPolicyHandle); FileClose(g_normalPolicyHandle); }
   g_normalPolicyHandle=INVALID_HANDLE;
}

#endif
