//+------------------------------------------------------------------+
//| RBT_RiskManagerShadow.mqh                                       |
//| Frozen ExtraTrees entry-risk model. Shadow recommendations only. |
//+------------------------------------------------------------------+
#ifndef __RBT_RISK_MANAGER_SHADOW_MQH__
#define __RBT_RISK_MANAGER_SHADOW_MQH__

#define RBT_RISK_SCHEMA "RBT-M5-ENTRY-RISK-SHADOW-1"
#define RBT_RISK_FEATURES 139

union SRBTRiskDoubleBits { ulong bits; double value; };
struct SRBTRiskNode
{
   int feature;
   int left;
   int right;
   double threshold;
   double probability;
};
struct SRBTRiskTrade
{
   long positionId;
   datetime openTime;
   int direction;
   double riskProbability;
   double threshold;
   double recommendedMultiplier;
   double baselineLot;
};

SRBTRiskNode g_riskNodes[];
int g_riskTreeOffset[];
int g_riskTreeCount[];
int g_riskTreeTotal=0;
bool g_riskReady=false;
int g_riskShadowHandle=INVALID_HANDLE;
string g_riskShadowName="";
SRBTRiskTrade g_riskTrades[];

uint RiskReadU32(const uchar &bytes[],int &cursor)
{
   const uint v=(uint)bytes[cursor] | ((uint)bytes[cursor+1]<<8) |
      ((uint)bytes[cursor+2]<<16) | ((uint)bytes[cursor+3]<<24);
   cursor+=4; return v;
}
int RiskReadI32(const uchar &bytes[],int &cursor) { return (int)RiskReadU32(bytes,cursor); }
double RiskReadDouble(const uchar &bytes[],int &cursor)
{
   SRBTRiskDoubleBits u; u.bits=0;
   for(int i=0;i<8;i++) u.bits|=((ulong)bytes[cursor+i]<<(8*i));
   cursor+=8; return u.value;
}

bool RiskManagerLoadModel(const uchar &bytes[])
{
   g_riskReady=false;
   const int size=ArraySize(bytes);
   if(size<20) return false;
   const string magic="RBTRSK13";
   for(int i=0;i<8;i++) if(bytes[i]!=(uchar)StringGetCharacter(magic,i)) return false;
   int cursor=8;
   const uint version=RiskReadU32(bytes,cursor);
   const uint features=RiskReadU32(bytes,cursor);
   const uint trees=RiskReadU32(bytes,cursor);
   if(version!=1 || features!=RBT_RISK_FEATURES || trees<1 || trees>2000) return false;
   ArrayResize(g_riskTreeOffset,(int)trees);
   ArrayResize(g_riskTreeCount,(int)trees);
   ArrayResize(g_riskNodes,0);
   int total=0;
   for(int t=0;t<(int)trees;t++)
   {
      if(cursor+4>size) return false;
      const int count=(int)RiskReadU32(bytes,cursor);
      if(count<1 || count>100000 || cursor+count*28>size) return false;
      g_riskTreeOffset[t]=total; g_riskTreeCount[t]=count;
      ArrayResize(g_riskNodes,total+count);
      for(int n=0;n<count;n++)
      {
         SRBTRiskNode node;
         node.feature=RiskReadI32(bytes,cursor);
         node.left=RiskReadI32(bytes,cursor);
         node.right=RiskReadI32(bytes,cursor);
         node.threshold=RiskReadDouble(bytes,cursor);
         node.probability=RiskReadDouble(bytes,cursor);
         if(node.feature>=RBT_RISK_FEATURES || node.feature < -2 ||
            !MathIsValidNumber(node.threshold) || !MathIsValidNumber(node.probability)) return false;
         g_riskNodes[total+n]=node;
      }
      total+=count;
   }
   if(cursor!=size) return false;
   g_riskTreeTotal=(int)trees; g_riskReady=true;
   PrintFormat("RISK MANAGER model ready | trees=%d nodes=%d features=%d shadow_only=1",
      g_riskTreeTotal,total,RBT_RISK_FEATURES);
   return true;
}

bool RiskManagerBuildFeatures(const int decision,const double pSell,const double pHold,
   const double pBuy,const double gap,double &f[])
{
   ArrayResize(f,RBT_RISK_FEATURES); ArrayInitialize(f,0.0);
   MqlTick tick; if(!SymbolInfoTick(_Symbol,tick)) return false;
   const double pip=ManagerDatasetPipSize();
   ulong positionTicket=0; long positionId=0;
   if(ManagerDatasetSelectPosition(positionTicket,positionId) && PositionSelectByTicket(positionTicket))
   {
      const double volume=MathMax(0.01,PositionGetDouble(POSITION_VOLUME));
      const double profit=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
      const ENUM_POSITION_TYPE type=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      const double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      const double price=(type==POSITION_TYPE_BUY ? tick.bid : tick.ask);
      f[0]=MathMax(0.0,(double)((long)tick.time_msc-(long)PositionGetInteger(POSITION_TIME_MSC))/60000.0);
      f[1]=profit/volume;
      f[2]=(pip>0.0 ? (type==POSITION_TYPE_BUY ? price-entry : entry-price)/pip : 0.0);
      f[3]=f[4]=f[5]=f[6]=f[1];
   }
   f[7]=(pip>0.0 ? MathMax(0.0,tick.ask-tick.bid)/pip : 0.0);
   f[8]=(pip>0.0 ? (double)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)*_Point/pip : 0.0);
   f[9]=pSell; f[10]=pHold; f[11]=pBuy; f[12]=gap;
   f[13]=(g_managerLastXGBTime>0 ? MathMax(0.0,(double)(TimeCurrent()-g_managerLastXGBTime)/60.0) : 0.0);
   f[14]=(double)g_hybridMotifLast.direction;
   f[15]=g_hybridMotifLast.confidence;
   f[16]=g_hybridMotifLast.expectedNetATR;
   f[17]=g_hybridMotifLast.grossToCostRatio;
   f[18]=(g_hybridMotifLast.valid ?
      MathMax(0.0,(double)(TimeCurrent()-g_hybridMotifLast.anchorTime)/60.0) : -1.0);
   int k=19;
   for(int i=0;i<RBT_MANAGER_TF_COUNT;i++)
   {
      SRBTManagerTFState s; if(!ManagerDatasetReadTF(i,s)) return false;
      f[k++]=s.atrPips; f[k++]=s.rsi; f[k++]=s.macdHist; f[k++]=s.adx;
      f[k++]=s.closeEmaATR; f[k++]=s.ret1ATR; f[k++]=s.bodyATR; f[k++]=s.rangeATR;
      f[k++]=s.upperWickATR; f[k++]=s.lowerWickATR; f[k++]=s.plusDI; f[k++]=s.minusDI;
      f[k++]=s.emaSlopeATR; f[k++]=s.volumeRatio20; f[k++]=s.swingLow5ATR;
      f[k++]=s.swingHigh5ATR; f[k++]=s.swingLow20ATR; f[k++]=s.swingHigh20ATR;
      f[k++]=s.stochastic; f[k++]=s.cci; f[k++]=s.momentumDelta; f[k++]=s.williamsR;
      f[k++]=s.bandPosition; f[k++]=s.bandWidthATR;
   }
   return (k==RBT_RISK_FEATURES);
}

bool RiskManagerPredict(const int decision,const double pSell,const double pHold,
   const double pBuy,const double gap,double &probability,double &recommendedMultiplier)
{
   probability=0.0; recommendedMultiplier=1.0;
   if(!InpRiskManagerShadowEnable || !g_riskReady) return false;
   double f[]; if(!RiskManagerBuildFeatures(decision,pSell,pHold,pBuy,gap,f)) return false;
   double sum=0.0;
   for(int t=0;t<g_riskTreeTotal;t++)
   {
      int local=0; const int offset=g_riskTreeOffset[t]; const int count=g_riskTreeCount[t];
      for(int guard=0;guard<count;guard++)
      {
         const SRBTRiskNode node=g_riskNodes[offset+local];
         if(node.feature<0) { sum+=node.probability; break; }
         local=(f[node.feature]<=node.threshold ? node.left : node.right);
         if(local<0 || local>=count) return false;
      }
   }
   probability=sum/(double)g_riskTreeTotal;
   recommendedMultiplier=(probability>=InpRiskManagerThreshold ?
      InpRiskManagerReducedLotMultiplier : 1.0);
   return true;
}

int RiskShadowFind(const long positionId)
{
   for(int i=0;i<ArraySize(g_riskTrades);i++) if(g_riskTrades[i].positionId==positionId) return i;
   return -1;
}

double RiskShadowPositionNet(const long positionId)
{
   double net=0.0; if(!HistorySelectByPosition((ulong)positionId)) return net;
   for(int i=0;i<HistoryDealsTotal();i++)
   {
      const ulong deal=HistoryDealGetTicket(i); if(deal==0) continue;
      net+=HistoryDealGetDouble(deal,DEAL_PROFIT)+HistoryDealGetDouble(deal,DEAL_COMMISSION)+
           HistoryDealGetDouble(deal,DEAL_SWAP)+HistoryDealGetDouble(deal,DEAL_FEE);
   }
   return net;
}

bool RiskManagerRegisterOpenedDeal(const ulong dealTicket,const double probability,
   const double multiplier)
{
   if(!InpRiskManagerShadowEnable || dealTicket==0 || !HistoryDealSelect(dealTicket)) return false;
   const long pid=(long)HistoryDealGetInteger(dealTicket,DEAL_POSITION_ID);
   if(pid<=0 || RiskShadowFind(pid)>=0) return false;
   const int n=ArraySize(g_riskTrades); ArrayResize(g_riskTrades,n+1);
   SRBTRiskTrade r; ZeroMemory(r); r.positionId=pid;
   r.openTime=(datetime)HistoryDealGetInteger(dealTicket,DEAL_TIME);
   r.direction=(HistoryDealGetInteger(dealTicket,DEAL_TYPE)==DEAL_TYPE_BUY ? 1 : -1);
   r.riskProbability=probability; r.threshold=InpRiskManagerThreshold;
   r.recommendedMultiplier=multiplier;
   r.baselineLot=HistoryDealGetDouble(dealTicket,DEAL_VOLUME); g_riskTrades[n]=r;
   if(g_riskShadowHandle!=INVALID_HANDLE)
   {
      FileWrite(g_riskShadowHandle,RBT_RISK_SCHEMA,"5.10.17","ENTRY",_Symbol,pid,
         TimeToString(r.openTime,TIME_DATE|TIME_SECONDS),(r.direction>0?"BUY":"SELL"),
         DoubleToString(r.riskProbability,8),DoubleToString(r.threshold,8),
         (r.recommendedMultiplier<1.0?"REDUCED":"FULL"),DoubleToString(r.baselineLot,4),
         DoubleToString(r.recommendedMultiplier,4),DoubleToString(r.baselineLot*r.recommendedMultiplier,4),
         "","","","SHADOW_ONLY_NO_REAL_ACTIONS");
      FileFlush(g_riskShadowHandle);
   }
   return true;
}

bool RiskManagerInitialize(const uchar &bytes[])
{
   ArrayResize(g_riskTrades,0);
   if(!RiskManagerLoadModel(bytes)) { Print("RISK MANAGER model load failed"); return false; }
   if(!InpRiskManagerShadowEnable) return true;
   int flags=FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ;
   if(InpHybridCSVUseCommonFiles) { flags|=FILE_COMMON; FolderCreate("RBT_M5_V5",FILE_COMMON); }
   else FolderCreate("RBT_M5_V5");
   g_riskShadowName="RBT_M5_V5\\RBT_M5_ENTRY_RISK_SHADOW_"+HybridCSVRuntimeLabel()+".csv";
   g_riskShadowHandle=FileOpen(g_riskShadowName,flags,';',CP_UTF8);
   if(g_riskShadowHandle==INVALID_HANDLE) return false;
   FileWrite(g_riskShadowHandle,"schema","version","event","symbol","position_id","time",
      "direction","risk_probability","risk_threshold","risk_class","baseline_lot",
      "recommended_multiplier","recommended_lot","baseline_net_money","shadow_net_money",
      "shadow_delta_money","contract");
   FileFlush(g_riskShadowHandle); return true;
}

void RiskManagerOnTradeTransaction(const MqlTradeTransaction &trans)
{
   if(!InpRiskManagerShadowEnable || trans.type!=TRADE_TRANSACTION_DEAL_ADD || trans.deal==0 ||
      !HistoryDealSelect(trans.deal) ||
      (long)HistoryDealGetInteger(trans.deal,DEAL_MAGIC)!=InpMagicNumber ||
      HistoryDealGetString(trans.deal,DEAL_SYMBOL)!=_Symbol) return;
   const ENUM_DEAL_ENTRY entry=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal,DEAL_ENTRY);
   const long pid=(long)HistoryDealGetInteger(trans.deal,DEAL_POSITION_ID);
   if(entry==DEAL_ENTRY_IN) return;
   if(entry!=DEAL_ENTRY_OUT && entry!=DEAL_ENTRY_OUT_BY && entry!=DEAL_ENTRY_INOUT) return;
   const int index=RiskShadowFind(pid); if(index<0) return;
   const SRBTRiskTrade r=g_riskTrades[index];
   const double baseline=RiskShadowPositionNet(pid);
   const double shadow=baseline*r.recommendedMultiplier;
   const datetime closeTime=(datetime)HistoryDealGetInteger(trans.deal,DEAL_TIME);
   if(g_riskShadowHandle!=INVALID_HANDLE)
   {
      FileWrite(g_riskShadowHandle,RBT_RISK_SCHEMA,"5.10.17","CLOSE",_Symbol,pid,
         TimeToString(closeTime,TIME_DATE|TIME_SECONDS),(r.direction>0?"BUY":"SELL"),
         DoubleToString(r.riskProbability,8),DoubleToString(r.threshold,8),
         (r.recommendedMultiplier<1.0?"REDUCED":"FULL"),DoubleToString(r.baselineLot,4),
         DoubleToString(r.recommendedMultiplier,4),DoubleToString(r.baselineLot*r.recommendedMultiplier,4),
         DoubleToString(baseline,2),DoubleToString(shadow,2),DoubleToString(shadow-baseline,2),
         "SHADOW_ONLY_NO_REAL_ACTIONS");
      FileFlush(g_riskShadowHandle);
   }
   for(int i=index;i<ArraySize(g_riskTrades)-1;i++) g_riskTrades[i]=g_riskTrades[i+1];
   ArrayResize(g_riskTrades,ArraySize(g_riskTrades)-1);
}

void RiskManagerShutdown()
{
   if(g_riskShadowHandle!=INVALID_HANDLE) { FileFlush(g_riskShadowHandle); FileClose(g_riskShadowHandle); }
   g_riskShadowHandle=INVALID_HANDLE; g_riskReady=false;
   ArrayResize(g_riskNodes,0); ArrayResize(g_riskTreeOffset,0); ArrayResize(g_riskTreeCount,0);
   ArrayResize(g_riskTrades,0);
}

#endif
