#ifndef RBT_RECOVERY_MANAGER
#define RBT_RECOVERY_MANAGER
// States: 0 untriggered, 1 waiting, 2 disabled-fast, 3 protected, 4 trailing.
struct RecoveryState { ulong id; int stage; datetime trigger; double stop; };
RecoveryState recoveryStates[];
int recoveryLog=INVALID_HANDLE;
string RecoveryKey(const ulong id,const string field)
{
 return StringFormat("R514.%I64d.%I64u.%s",AccountInfoInteger(ACCOUNT_LOGIN),id,field);
}
void RecoverySave(const int i)
{
 if(MQLInfoInteger(MQL_TESTER)) return;
 GlobalVariableSet(RecoveryKey(recoveryStates[i].id,"state"),recoveryStates[i].stage);
 GlobalVariableSet(RecoveryKey(recoveryStates[i].id,"time"),(double)recoveryStates[i].trigger);
 GlobalVariableSet(RecoveryKey(recoveryStates[i].id,"stop"),recoveryStates[i].stop);
 GlobalVariablesFlush();
}
void RecoveryLog(const ulong ticket,const int stage,const string event,const double money,const double sl)
{
 if(recoveryLog!=INVALID_HANDLE) {
  FileWrite(recoveryLog,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),ticket,(int)InpRecoveryMode,stage,event,money,sl);
  FileFlush(recoveryLog);
 }
}
bool RecoveryInit()
{
 if(InpRecoveryReferenceLot<=0 || InpRecoveryLossMoney<=0 || InpRecoveryArmMoney<=InpRecoveryFloorMoney || InpRecoveryFloorMoney<=0 || InpRecoveryMinMinutes<0 || InpRecoveryTrailMinutes<=InpRecoveryMinMinutes || InpRecoveryTrailPips<=0) return false;
 ArrayResize(recoveryStates,0);
 if(InpRecoveryMode==RECOVERY_NORMAL) return true;
 FolderCreate("RBT_M5_V5",FILE_COMMON);
 string path="RBT_M5_V5\\RBT_M5_RECOVERY_"+InpHybridRunLabel+".csv";
 recoveryLog=FileOpen(path,FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_COMMON,';');
 if(recoveryLog==INVALID_HANDLE) return false;
 if(FileSize(recoveryLog)==0) FileWrite(recoveryLog,"time","ticket","mode","stage","event","floating_money","target_sl");
 FileSeek(recoveryLog,0,SEEK_END);
 return true;
}
void RecoveryShutdown() { if(recoveryLog!=INVALID_HANDLE) {FileClose(recoveryLog);recoveryLog=INVALID_HANDLE;} }
void RecoveryProcess()
{
 if(InpRecoveryMode==RECOVERY_NORMAL) return;
 for(int p=PositionsTotal()-1;p>=0;p--) {
  ulong ticket=PositionGetTicket(p);
  if(ticket==0 || PositionGetString(POSITION_SYMBOL)!=_Symbol || PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber) continue;
  ulong id=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
  int i=0; for(;i<ArraySize(recoveryStates);i++) if(recoveryStates[i].id==id) break;
  if(i==ArraySize(recoveryStates)) {
   ArrayResize(recoveryStates,i+1);recoveryStates[i].id=id;recoveryStates[i].stage=0;recoveryStates[i].trigger=0;recoveryStates[i].stop=0;
   if(!MQLInfoInteger(MQL_TESTER) && GlobalVariableCheck(RecoveryKey(id,"state"))) {
    recoveryStates[i].stage=(int)GlobalVariableGet(RecoveryKey(id,"state"));
    recoveryStates[i].trigger=(datetime)GlobalVariableGet(RecoveryKey(id,"time"));
    recoveryStates[i].stop=GlobalVariableGet(RecoveryKey(id,"stop"));
   }
  }
  double money=PositionGetDouble(POSITION_PROFIT); // Same measure as research dataset; excludes commission/swap.
  const double recoveryScale=InpRecoveryScaleWithLot?PositionGetDouble(POSITION_VOLUME)/InpRecoveryReferenceLot:1.0;
  const double lossThreshold=InpRecoveryLossMoney*recoveryScale;
  const double armThreshold=InpRecoveryArmMoney*recoveryScale;
  const double floorThreshold=InpRecoveryFloorMoney*recoveryScale;
  bool buy=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY;
  MqlTick tick;if(!SymbolInfoTick(_Symbol,tick)) continue;
  double market=buy?tick.bid:tick.ask;
  int before=recoveryStates[i].stage;
  if(before==0 && money<=-lossThreshold) {
   recoveryStates[i].stage=1;recoveryStates[i].trigger=TimeCurrent();RecoverySave(i);
   RecoveryLog(ticket,1,"TRIGGER",money,0);continue;
  }
  if(before==1) {
   double minutes=(double)(TimeCurrent()-recoveryStates[i].trigger)/60.0;
   if(money>=armThreshold) recoveryStates[i].stage=minutes<=InpRecoveryMinMinutes?2:3;
   else if(InpRecoveryMode==RECOVERY_WITH_TRAIL && minutes>=InpRecoveryTrailMinutes && money<0) recoveryStates[i].stage=4;
   if(recoveryStates[i].stage!=before) {RecoverySave(i);RecoveryLog(ticket,recoveryStates[i].stage,"STATE",money,0);}
  }
  int state=recoveryStates[i].stage;if(state<3) continue;
  double oldSL=PositionGetDouble(POSITION_SL),tp=PositionGetDouble(POSITION_TP);
  double step=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);if(step<=0) continue;
  double candidate=0;
  if(state==3) {
   double entry=PositionGetDouble(POSITION_PRICE_OPEN),unit=0;
   if(!OrderCalcProfit(buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,_Symbol,PositionGetDouble(POSITION_VOLUME),entry,entry+(buy?1:-1)*PipSize(),unit) || unit<=0) continue;
   candidate=entry+(buy?1:-1)*floorThreshold/unit*PipSize();
  } else candidate=market+(buy?-1:1)*InpRecoveryTrailPips*PipSize();
  candidate=NormalizeDouble((buy?MathFloor(candidate/step):MathCeil(candidate/step))*step,_Digits);
  double saved=recoveryStates[i].stop;
  if(saved==0 || (buy?candidate>saved:candidate<saved)) {recoveryStates[i].stop=candidate;RecoverySave(i);}
  double target=recoveryStates[i].stop;
  // Never weaken an existing broker stop.
  if(oldSL>0) target=buy?MathMax(target,oldSL):MathMin(target,oldSL);
  if(buy?market<=target:market>=target) {
   bool ok=trade.PositionClose(ticket);uint code=trade.ResultRetcode();
   RecoveryLog(ticket,state,(ok && (code==TRADE_RETCODE_DONE || code==TRADE_RETCODE_DONE_PARTIAL))?"CLOSE_EXECUTED":"CLOSE_RETRY",money,target);
   continue;
  }
  double distance=(double)MathMax(SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL),SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL))*_Point;
  if(MathAbs(market-target)<=distance+step) continue; // Virtual protection remains active while broker placement is blocked.
  if(oldSL>0 && (buy?target<=oldSL+step*0.5:target>=oldSL-step*0.5)) continue;
  bool ok=trade.PositionModify(ticket,target,tp);uint code=trade.ResultRetcode();
  RecoveryLog(ticket,state,(ok && code==TRADE_RETCODE_DONE)?"SL_MODIFIED":"SL_RETRY",money,target);
 }
}
#endif
