//+------------------------------------------------------------------+
//| RBT_ManagerDatasetLogger.mqh                                     |
//| Causal multi-timeframe dataset for the future trade manager ML.  |
//+------------------------------------------------------------------+
#ifndef __RBT_MANAGER_DATASET_LOGGER_MQH__
#define __RBT_MANAGER_DATASET_LOGGER_MQH__

#define RBT_MANAGER_DATASET_SCHEMA "RBT-M5-MANAGER-DATASET-1"
#define RBT_MANAGER_TF_COUNT 5

struct SRBTManagerTFState
{
   double atrPips;
   double rsi;
   double macdHist;
   double adx;
   double closeEmaATR;
   double ret1ATR;
   double bodyATR;
   double rangeATR;
   double upperWickATR;
   double lowerWickATR;
   double plusDI;
   double minusDI;
   double emaSlopeATR;
   double volumeRatio20;
   double swingLow5ATR;
   double swingHigh5ATR;
   double swingLow20ATR;
   double swingHigh20ATR;
   double stochastic;
   double cci;
   double momentumDelta;
   double williamsR;
   double bandPosition;
   double bandWidthATR;
};

ENUM_TIMEFRAMES g_managerTF[RBT_MANAGER_TF_COUNT]={PERIOD_M1,PERIOD_M5,PERIOD_M15,PERIOD_H1,PERIOD_H4};
string g_managerTFName[RBT_MANAGER_TF_COUNT]={"m1","m5","m15","h1","h4"};
int g_managerRSI[RBT_MANAGER_TF_COUNT];
int g_managerMACD[RBT_MANAGER_TF_COUNT];
int g_managerADX[RBT_MANAGER_TF_COUNT];
int g_managerATR[RBT_MANAGER_TF_COUNT];
int g_managerEMA[RBT_MANAGER_TF_COUNT];
int g_managerStoch[RBT_MANAGER_TF_COUNT];
int g_managerCCI[RBT_MANAGER_TF_COUNT];
int g_managerMomentum[RBT_MANAGER_TF_COUNT];
int g_managerWPR[RBT_MANAGER_TF_COUNT];
int g_managerBands[RBT_MANAGER_TF_COUNT];

int g_managerDatasetHandle=INVALID_HANDLE;
string g_managerDatasetName="";
long g_managerDatasetRows=0;
long g_managerPositionId=0;
long g_managerOpenTimeMsc=0;
long g_managerLastSampleMsc=0;
double g_managerMFEMoney=-1.0e308;
double g_managerMAEMoney=1.0e308;
double g_managerIntervalMaxMoney=-1.0e308;
double g_managerIntervalMinMoney=1.0e308;
int g_managerLastXGBDecision=1;
double g_managerLastPSell=0.0,g_managerLastPHold=1.0,g_managerLastPBuy=0.0,g_managerLastXGBGap=0.0;
datetime g_managerLastXGBTime=0;

void ManagerDatasetSetXGB(const int decision,const double pSell,const double pHold,
   const double pBuy,const double gap)
{
   g_managerLastXGBDecision=decision;
   g_managerLastPSell=pSell; g_managerLastPHold=pHold; g_managerLastPBuy=pBuy;
   g_managerLastXGBGap=gap; g_managerLastXGBTime=TimeCurrent();
}

double ManagerDatasetPipSize()
{
   return ((_Digits==3 || _Digits==5) ? 10.0*_Point : _Point);
}

bool ManagerDatasetBufferValue(const int handle,const int buffer,const int shift,double &value)
{
   value=0.0; double v[1];
   if(handle==INVALID_HANDLE || CopyBuffer(handle,buffer,shift,1,v)!=1) return false;
   value=v[0]; return MathIsValidNumber(value);
}

bool ManagerDatasetReadTF(const int index,SRBTManagerTFState &s)
{
   ZeroMemory(s);
   if(index<0 || index>=RBT_MANAGER_TF_COUNT) return false;
   double atr=0.0,ema=0.0,emaPrevious=0.0,macd=0.0,signal=0.0,upper=0.0,lower=0.0;
   if(!ManagerDatasetBufferValue(g_managerATR[index],0,0,atr) || atr<=0.0 ||
      !ManagerDatasetBufferValue(g_managerEMA[index],0,0,ema) ||
      !ManagerDatasetBufferValue(g_managerRSI[index],0,0,s.rsi) ||
      !ManagerDatasetBufferValue(g_managerMACD[index],0,0,macd) ||
      !ManagerDatasetBufferValue(g_managerMACD[index],1,0,signal) ||
      !ManagerDatasetBufferValue(g_managerADX[index],0,0,s.adx) ||
      !ManagerDatasetBufferValue(g_managerADX[index],1,0,s.plusDI) ||
      !ManagerDatasetBufferValue(g_managerADX[index],2,0,s.minusDI) ||
      !ManagerDatasetBufferValue(g_managerEMA[index],0,1,emaPrevious) ||
      !ManagerDatasetBufferValue(g_managerStoch[index],0,0,s.stochastic) ||
      !ManagerDatasetBufferValue(g_managerCCI[index],0,0,s.cci) ||
      !ManagerDatasetBufferValue(g_managerMomentum[index],0,0,s.momentumDelta) ||
      !ManagerDatasetBufferValue(g_managerWPR[index],0,0,s.williamsR) ||
      !ManagerDatasetBufferValue(g_managerBands[index],1,0,upper) ||
      !ManagerDatasetBufferValue(g_managerBands[index],2,0,lower)) return false;
   MqlRates rates[]; ArraySetAsSeries(rates,true);
   if(CopyRates(_Symbol,g_managerTF[index],0,21,rates)!=21) return false;
   const double high=rates[0].high,low=rates[0].low,open=rates[0].open,close=rates[0].close;
   const double top=MathMax(open,close),bottom=MathMin(open,close);
   s.atrPips=atr/ManagerDatasetPipSize();
   s.macdHist=macd-signal;
   s.closeEmaATR=(close-ema)/atr;
   s.ret1ATR=(close-rates[1].close)/atr;
   s.bodyATR=(close-open)/atr;
   s.rangeATR=(high-low)/atr;
   s.upperWickATR=(high-top)/atr;
   s.lowerWickATR=(bottom-low)/atr;
   s.emaSlopeATR=(ema-emaPrevious)/atr;
   double volumeSum=0.0;
   for(int i=1;i<=20;i++) volumeSum+=(double)rates[i].tick_volume;
   const double volumeAverage=volumeSum/20.0;
   s.volumeRatio20=(volumeAverage>0.0?(double)rates[0].tick_volume/volumeAverage:0.0);
   double low5=rates[0].low,high5=rates[0].high,low20=rates[0].low,high20=rates[0].high;
   for(int i=1;i<20;i++)
   {
      low20=MathMin(low20,rates[i].low); high20=MathMax(high20,rates[i].high);
      if(i<5) { low5=MathMin(low5,rates[i].low); high5=MathMax(high5,rates[i].high); }
   }
   s.swingLow5ATR=(close-low5)/atr; s.swingHigh5ATR=(high5-close)/atr;
   s.swingLow20ATR=(close-low20)/atr; s.swingHigh20ATR=(high20-close)/atr;
   s.momentumDelta-=100.0;
   const double bandWidth=upper-lower;
   s.bandPosition=(bandWidth>0.0?(close-lower)/bandWidth:0.5);
   s.bandWidthATR=bandWidth/atr;
   return true;
}

bool ManagerDatasetSelectPosition(ulong &ticket,long &positionId)
{
   ticket=0; positionId=0;
   for(int i=0;i<PositionsTotal();i++)
   {
      const ulong t=PositionGetTicket(i);
      if(t>0 && PositionGetString(POSITION_SYMBOL)==_Symbol &&
         PositionGetInteger(POSITION_MAGIC)==InpMagicNumber)
      { ticket=t; positionId=(long)PositionGetInteger(POSITION_IDENTIFIER); return true; }
   }
   return false;
}

bool ManagerDatasetInitialize()
{
   for(int i=0;i<RBT_MANAGER_TF_COUNT;i++)
   {
      g_managerRSI[i]=g_managerMACD[i]=g_managerADX[i]=g_managerATR[i]=g_managerEMA[i]=INVALID_HANDLE;
      g_managerStoch[i]=g_managerCCI[i]=g_managerMomentum[i]=g_managerWPR[i]=g_managerBands[i]=INVALID_HANDLE;
      if(!InpManagerDatasetEnable) continue;
      g_managerRSI[i]=iRSI(_Symbol,g_managerTF[i],14,PRICE_CLOSE);
      g_managerMACD[i]=iMACD(_Symbol,g_managerTF[i],12,26,9,PRICE_CLOSE);
      g_managerADX[i]=iADX(_Symbol,g_managerTF[i],14);
      g_managerATR[i]=iATR(_Symbol,g_managerTF[i],14);
      g_managerEMA[i]=iMA(_Symbol,g_managerTF[i],20,0,MODE_EMA,PRICE_CLOSE);
      g_managerStoch[i]=iStochastic(_Symbol,g_managerTF[i],14,3,3,MODE_SMA,STO_LOWHIGH);
      g_managerCCI[i]=iCCI(_Symbol,g_managerTF[i],14,PRICE_TYPICAL);
      g_managerMomentum[i]=iMomentum(_Symbol,g_managerTF[i],14,PRICE_CLOSE);
      g_managerWPR[i]=iWPR(_Symbol,g_managerTF[i],14);
      g_managerBands[i]=iBands(_Symbol,g_managerTF[i],20,0,2.0,PRICE_CLOSE);
      if(g_managerRSI[i]==INVALID_HANDLE || g_managerMACD[i]==INVALID_HANDLE ||
         g_managerADX[i]==INVALID_HANDLE || g_managerATR[i]==INVALID_HANDLE ||
         g_managerEMA[i]==INVALID_HANDLE || g_managerStoch[i]==INVALID_HANDLE ||
         g_managerCCI[i]==INVALID_HANDLE || g_managerMomentum[i]==INVALID_HANDLE ||
         g_managerWPR[i]==INVALID_HANDLE || g_managerBands[i]==INVALID_HANDLE) return false;
   }
   if(!InpManagerDatasetEnable) return true;
   int flags=FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ;
   if(InpHybridCSVUseCommonFiles) { flags|=FILE_COMMON; FolderCreate("RBT_M5_V5",FILE_COMMON); }
   else FolderCreate("RBT_M5_V5");
   g_managerDatasetName="RBT_M5_V5\\RBT_M5_MANAGER_DATASET_"+HybridCSVRuntimeLabel()+".csv";
   g_managerDatasetHandle=FileOpen(g_managerDatasetName,flags,';',CP_UTF8);
   if(g_managerDatasetHandle==INVALID_HANDLE) return false;
   string header="schema;version;symbol;position_id;sample_time;age_minutes;direction;volume;entry_price;market_price;current_sl;current_tp;";
   header+="profit_money;profit_pips;mfe_money;mae_money;interval_max_money;interval_min_money;spread_pips;reported_spread_pips;";
   header+="xgb_decision;xgb_p_sell;xgb_p_hold;xgb_p_buy;xgb_gap;xgb_age_minutes;";
   header+="motif_direction;motif_confidence;motif_expected_net_atr;motif_gross_cost_ratio;motif_age_minutes;";
   for(int i=0;i<RBT_MANAGER_TF_COUNT;i++)
   {
      const string n=g_managerTFName[i];
      header+=n+"_atr_pips;"+n+"_rsi;"+n+"_macd_hist;"+n+"_adx;"+n+"_close_ema_atr;";
      header+=n+"_ret1_atr;"+n+"_body_atr;"+n+"_range_atr;"+n+"_upper_wick_atr;"+n+"_lower_wick_atr;";
      header+=n+"_plus_di;"+n+"_minus_di;"+n+"_ema_slope_atr;"+n+"_volume_ratio20;";
      header+=n+"_swing_low5_atr;"+n+"_swing_high5_atr;"+n+"_swing_low20_atr;"+n+"_swing_high20_atr;";
      header+=n+"_stochastic;"+n+"_cci;"+n+"_momentum_delta;"+n+"_williams_r;"+n+"_band_position;"+n+"_band_width_atr;";
   }
   header+="contract\r\n";
   FileWriteString(g_managerDatasetHandle,header);
   FileFlush(g_managerDatasetHandle);
   return true;
}

string ManagerDatasetTFText(const SRBTManagerTFState &s)
{
   string v=DoubleToString(s.atrPips,6)+";"+DoubleToString(s.rsi,6)+";";
   v+=DoubleToString(s.macdHist,10)+";"+DoubleToString(s.adx,6)+";"+DoubleToString(s.closeEmaATR,8)+";";
   v+=DoubleToString(s.ret1ATR,8)+";"+DoubleToString(s.bodyATR,8)+";"+DoubleToString(s.rangeATR,8)+";";
   v+=DoubleToString(s.upperWickATR,8)+";"+DoubleToString(s.lowerWickATR,8)+";";
   v+=DoubleToString(s.plusDI,6)+";"+DoubleToString(s.minusDI,6)+";"+DoubleToString(s.emaSlopeATR,8)+";";
   v+=DoubleToString(s.volumeRatio20,8)+";"+DoubleToString(s.swingLow5ATR,8)+";"+DoubleToString(s.swingHigh5ATR,8)+";";
   v+=DoubleToString(s.swingLow20ATR,8)+";"+DoubleToString(s.swingHigh20ATR,8)+";";
   v+=DoubleToString(s.stochastic,6)+";"+DoubleToString(s.cci,6)+";"+DoubleToString(s.momentumDelta,8)+";";
   v+=DoubleToString(s.williamsR,6)+";"+DoubleToString(s.bandPosition,8)+";"+DoubleToString(s.bandWidthATR,8)+";";
   return v;
}

void ManagerDatasetWriteRow(const long nowMsc,const ulong ticket,const long positionId)
{
   if(!PositionSelectByTicket(ticket) || g_managerDatasetHandle==INVALID_HANDLE) return;
   SRBTManagerTFState s[RBT_MANAGER_TF_COUNT];
   for(int i=0;i<RBT_MANAGER_TF_COUNT;i++) if(!ManagerDatasetReadTF(i,s[i])) return;
   const ENUM_POSITION_TYPE pt=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
   const int direction=(pt==POSITION_TYPE_BUY?1:-1);
   const double entry=PositionGetDouble(POSITION_PRICE_OPEN);
   MqlTick tick; if(!SymbolInfoTick(_Symbol,tick)) return;
   const double price=(direction>0?tick.bid:tick.ask);
   const double profit=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
   const double pip=ManagerDatasetPipSize();
   const double profitPips=(direction>0?(price-entry):(entry-price))/pip;
   const double xgbAge=(g_managerLastXGBTime>0?(double)(TimeCurrent()-g_managerLastXGBTime)/60.0:-1.0);
   const double motifAge=(g_hybridMotifLast.valid?(double)(TimeCurrent()-g_hybridMotifLast.anchorTime)/60.0:-1.0);
   string line=RBT_MANAGER_DATASET_SCHEMA+";5.10.13;"+_Symbol+";"+(string)positionId+";";
   line+=TimeToString((datetime)(nowMsc/1000),TIME_DATE|TIME_SECONDS)+";";
   line+=DoubleToString((double)(nowMsc-g_managerOpenTimeMsc)/60000.0,6)+";"+(direction>0?"BUY":"SELL")+";";
   line+=DoubleToString(PositionGetDouble(POSITION_VOLUME),4)+";"+DoubleToString(entry,_Digits)+";"+DoubleToString(price,_Digits)+";";
   line+=DoubleToString(PositionGetDouble(POSITION_SL),_Digits)+";"+DoubleToString(PositionGetDouble(POSITION_TP),_Digits)+";";
   line+=DoubleToString(profit,2)+";"+DoubleToString(profitPips,6)+";"+DoubleToString(g_managerMFEMoney,2)+";";
   line+=DoubleToString(g_managerMAEMoney,2)+";"+DoubleToString(g_managerIntervalMaxMoney,2)+";";
   const double reportedSpread=(double)SymbolInfoInteger(_Symbol,SYMBOL_SPREAD)*_Point/pip;
   line+=DoubleToString(g_managerIntervalMinMoney,2)+";"+DoubleToString((tick.ask-tick.bid)/pip,6)+";";
   line+=DoubleToString(reportedSpread,6)+";";
   line+=M5_DecisionName(g_managerLastXGBDecision)+";"+DoubleToString(g_managerLastPSell,8)+";";
   line+=DoubleToString(g_managerLastPHold,8)+";"+DoubleToString(g_managerLastPBuy,8)+";";
   line+=DoubleToString(g_managerLastXGBGap,8)+";"+DoubleToString(xgbAge,6)+";";
   line+=(string)g_hybridMotifLast.direction+";"+DoubleToString(g_hybridMotifLast.confidence,8)+";";
   line+=DoubleToString(g_hybridMotifLast.expectedNetATR,8)+";"+DoubleToString(g_hybridMotifLast.grossToCostRatio,8)+";";
   line+=DoubleToString(motifAge,6)+";";
   for(int i=0;i<RBT_MANAGER_TF_COUNT;i++) line+=ManagerDatasetTFText(s[i]);
   line+="DATASET_ONLY_NO_TRADE_ACTIONS\r\n";
   FileWriteString(g_managerDatasetHandle,line);
   g_managerDatasetRows++;
   if(InpHybridCSVFlushEveryRows<=1 || g_managerDatasetRows%InpHybridCSVFlushEveryRows==0) FileFlush(g_managerDatasetHandle);
}

void ManagerDatasetProcessTick()
{
   if(!InpManagerDatasetEnable) return;
   MqlTick tick; if(!SymbolInfoTick(_Symbol,tick)) return;
   ulong ticket=0; long positionId=0;
   if(!ManagerDatasetSelectPosition(ticket,positionId))
   { g_managerPositionId=0; g_managerOpenTimeMsc=0; g_managerLastSampleMsc=0; return; }
   if(!PositionSelectByTicket(ticket)) return;
   const double profit=PositionGetDouble(POSITION_PROFIT)+PositionGetDouble(POSITION_SWAP);
   if(positionId!=g_managerPositionId)
   {
      g_managerPositionId=positionId;
      g_managerOpenTimeMsc=(long)PositionGetInteger(POSITION_TIME_MSC);
      g_managerLastSampleMsc=0;
      g_managerMFEMoney=g_managerIntervalMaxMoney=profit;
      g_managerMAEMoney=g_managerIntervalMinMoney=profit;
   }
   g_managerMFEMoney=MathMax(g_managerMFEMoney,profit);
   g_managerMAEMoney=MathMin(g_managerMAEMoney,profit);
   g_managerIntervalMaxMoney=MathMax(g_managerIntervalMaxMoney,profit);
   g_managerIntervalMinMoney=MathMin(g_managerIntervalMinMoney,profit);
   const long interval=(long)MathMax(1,InpManagerDatasetSampleSeconds)*1000;
   if(g_managerLastSampleMsc==0 || (long)tick.time_msc-g_managerLastSampleMsc>=interval)
   {
      ManagerDatasetWriteRow((long)tick.time_msc,ticket,positionId);
      g_managerLastSampleMsc=(long)tick.time_msc;
      g_managerIntervalMaxMoney=profit; g_managerIntervalMinMoney=profit;
   }
}

void ManagerDatasetShutdown()
{
   if(g_managerDatasetHandle!=INVALID_HANDLE) { FileFlush(g_managerDatasetHandle); FileClose(g_managerDatasetHandle); }
   g_managerDatasetHandle=INVALID_HANDLE;
   for(int i=0;i<RBT_MANAGER_TF_COUNT;i++)
   {
      if(g_managerRSI[i]!=INVALID_HANDLE) IndicatorRelease(g_managerRSI[i]);
      if(g_managerMACD[i]!=INVALID_HANDLE) IndicatorRelease(g_managerMACD[i]);
      if(g_managerADX[i]!=INVALID_HANDLE) IndicatorRelease(g_managerADX[i]);
      if(g_managerATR[i]!=INVALID_HANDLE) IndicatorRelease(g_managerATR[i]);
      if(g_managerEMA[i]!=INVALID_HANDLE) IndicatorRelease(g_managerEMA[i]);
      if(g_managerStoch[i]!=INVALID_HANDLE) IndicatorRelease(g_managerStoch[i]);
      if(g_managerCCI[i]!=INVALID_HANDLE) IndicatorRelease(g_managerCCI[i]);
      if(g_managerMomentum[i]!=INVALID_HANDLE) IndicatorRelease(g_managerMomentum[i]);
      if(g_managerWPR[i]!=INVALID_HANDLE) IndicatorRelease(g_managerWPR[i]);
      if(g_managerBands[i]!=INVALID_HANDLE) IndicatorRelease(g_managerBands[i]);
   }
}

#endif
