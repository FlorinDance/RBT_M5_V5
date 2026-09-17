#ifndef RBT_RECOVERY_MANAGER
#define RBT_RECOVERY_MANAGER

#define RBT_RECOVERY_FAILURE_MAX_SAMPLES 256

// Recovery states: 0 untriggered, 1 waiting, 2 disabled-fast, 3 protected,
// 4 trailing, 5 filtered failure stop armed.
// Global modes use stages 10..13 and are isolated from the legacy recovery states.
struct RecoveryState
{
   ulong    id;
   int      stage;
   datetime trigger;
   double   stop;
   bool     failureEvaluated;
   datetime failureLastSample;
   int      failureSampleCount;
   datetime failureSampleTime[RBT_RECOVERY_FAILURE_MAX_SAMPLES];
   double   failureSampleMoney[RBT_RECOVERY_FAILURE_MAX_SAMPLES];
};

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
   GlobalVariableSet(RecoveryKey(recoveryStates[i].id,"feval"),recoveryStates[i].failureEvaluated?1.0:0.0);
   GlobalVariablesFlush();
}

void RecoveryLog(const ulong ticket,const int stage,const string event,
                 const double money,const double sl,
                 const double negativeRatio=EMPTY_VALUE,
                 const double slopeMoneyPerMinute=EMPTY_VALUE)
{
   if(recoveryLog==INVALID_HANDLE) return;
   const string ratioText=(negativeRatio==EMPTY_VALUE?"":DoubleToString(negativeRatio,6));
   const string slopeText=(slopeMoneyPerMinute==EMPTY_VALUE?"":DoubleToString(slopeMoneyPerMinute,6));
   FileWrite(recoveryLog,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),ticket,
             (int)InpRecoveryMode,stage,event,money,sl,ratioText,slopeText);
   FileFlush(recoveryLog);
}

void RecoveryFailureReset(const int i)
{
   recoveryStates[i].failureEvaluated=false;
   recoveryStates[i].failureLastSample=0;
   recoveryStates[i].failureSampleCount=0;
}

void RecoveryFailureAddSample(const int i,const double money,
                              const datetime now,const bool force=false)
{
   if(!InpRecoveryFailureProtection) return;
   const datetime last=recoveryStates[i].failureLastSample;
   if(last==now) return;
   if(!force && last>0 && (now-last)<InpRecoveryFailureSampleSeconds) return;

   int count=recoveryStates[i].failureSampleCount;
   if(count>=RBT_RECOVERY_FAILURE_MAX_SAMPLES)
   {
      for(int s=1;s<RBT_RECOVERY_FAILURE_MAX_SAMPLES;s++)
      {
         recoveryStates[i].failureSampleTime[s-1]=recoveryStates[i].failureSampleTime[s];
         recoveryStates[i].failureSampleMoney[s-1]=recoveryStates[i].failureSampleMoney[s];
      }
      count=RBT_RECOVERY_FAILURE_MAX_SAMPLES-1;
   }

   recoveryStates[i].failureSampleTime[count]=now;
   recoveryStates[i].failureSampleMoney[count]=money;
   recoveryStates[i].failureSampleCount=count+1;
   recoveryStates[i].failureLastSample=now;
}

bool RecoveryFailureStats(const int i,const datetime now,
                          double &negativeRatio,double &slopeMoneyPerMinute)
{
   negativeRatio=0.0;
   slopeMoneyPerMinute=0.0;
   const int windowSeconds=(int)MathRound(InpRecoveryFailureWindowMinutes*60.0);
   const datetime fromTime=now-windowSeconds;
   int first=-1;
   int count=0;
   int negative=0;

   for(int s=0;s<recoveryStates[i].failureSampleCount;s++)
   {
      if(recoveryStates[i].failureSampleTime[s]<fromTime) continue;
      if(first<0) first=s;
      count++;
      if(recoveryStates[i].failureSampleMoney[s]<0.0) negative++;
   }

   const int required=(int)MathCeil((double)windowSeconds/InpRecoveryFailureSampleSeconds);
   if(first<0 || count<required || count<2) return false;
   const int coverage=(int)(now-recoveryStates[i].failureSampleTime[first]);
   if(coverage<windowSeconds-2*InpRecoveryFailureSampleSeconds) return false;

   double sumX=0.0,sumY=0.0,sumXX=0.0,sumXY=0.0;
   const datetime origin=recoveryStates[i].failureSampleTime[first];
   for(int s=first;s<recoveryStates[i].failureSampleCount;s++)
   {
      if(recoveryStates[i].failureSampleTime[s]<fromTime) continue;
      const double x=(double)(recoveryStates[i].failureSampleTime[s]-origin)/60.0;
      const double y=recoveryStates[i].failureSampleMoney[s];
      sumX+=x;
      sumY+=y;
      sumXX+=x*x;
      sumXY+=x*y;
   }

   const double denominator=count*sumXX-sumX*sumX;
   if(MathAbs(denominator)<1.0e-12) return false;
   negativeRatio=(double)negative/count;
   slopeMoneyPerMinute=(count*sumXY-sumX*sumY)/denominator;
   return true;
}

bool RecoveryPriceForLoss(const bool buy,const double lots,const double entry,
                          const double lossMoney,double &price)
{
   price=0.0;
   if(lots<=0.0 || entry<=0.0 || lossMoney<=0.0) return false;
   const ENUM_ORDER_TYPE type=buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
   const double direction=buy?-1.0:1.0;
   double high=PipSize();
   bool bracketed=false;

   for(int n=0;n<48;n++)
   {
      const double probe=entry+direction*high;
      if(probe<=0.0) return false;
      double profit=0.0;
      if(!OrderCalcProfit(type,_Symbol,lots,entry,probe,profit)) return false;
      if(profit<=-lossMoney)
      {
         bracketed=true;
         break;
      }
      high*=2.0;
   }
   if(!bracketed) return false;

   double low=0.0;
   for(int n=0;n<64;n++)
   {
      const double middle=(low+high)*0.5;
      const double probe=entry+direction*middle;
      double profit=0.0;
      if(!OrderCalcProfit(type,_Symbol,lots,entry,probe,profit)) return false;
      if(profit<=-lossMoney) high=middle;
      else low=middle;
   }

   const double step=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(step<=0.0) return false;
   const double raw=entry+direction*high;
   price=NormalizeDouble((buy?MathCeil(raw/step):MathFloor(raw/step))*step,_Digits);
   return price>0.0;
}

// Convert a requested positive profit amount into a price suitable for a profit-side SL.
bool RecoveryPriceForProfit(const bool buy,const double lots,const double entry,
                            const double profitMoney,double &price)
{
   price=0.0;
   if(lots<=0.0 || entry<=0.0 || profitMoney<=0.0) return false;

   const ENUM_ORDER_TYPE type=buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL;
   const double direction=buy?1.0:-1.0;
   double high=PipSize();
   bool bracketed=false;

   for(int n=0;n<48;n++)
   {
      const double probe=entry+direction*high;
      if(probe<=0.0) return false;
      double profit=0.0;
      if(!OrderCalcProfit(type,_Symbol,lots,entry,probe,profit)) return false;
      if(profit>=profitMoney)
      {
         bracketed=true;
         break;
      }
      high*=2.0;
   }
   if(!bracketed) return false;

   double low=0.0;
   for(int n=0;n<64;n++)
   {
      const double middle=(low+high)*0.5;
      const double probe=entry+direction*middle;
      double profit=0.0;
      if(!OrderCalcProfit(type,_Symbol,lots,entry,probe,profit)) return false;
      if(profit>=profitMoney) high=middle;
      else low=middle;
   }

   const double step=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(step<=0.0) return false;

   const double raw=entry+direction*high;
   // Conservative rounding: do not overstate the requested protected profit.
   price=NormalizeDouble((buy?MathFloor(raw/step):MathCeil(raw/step))*step,_Digits);
   return price>0.0;
}

bool RecoveryGlobalResolveTarget(const double money,const double scale,
                                 int &stage,double &lockMoney,string &eventName)
{
   stage=0;
   lockMoney=0.0;
   eventName="";

   if(InpRecoveryMode==RECOVERY_GLOBAL_LOCK)
   {
      if(money<InpGlobalLockTriggerMoney*scale) return false;
      stage=10;
      lockMoney=InpGlobalLockFloorMoney*scale;
      eventName="GLOBAL_LOCK_ARMED";
      return true;
   }

   if(InpRecoveryMode!=RECOVERY_GLOBAL_STEP_TRAIL)
      return false;

   // Highest reached step wins and protection never moves backwards.
   if(money>=InpGlobalStep3TriggerMoney*scale)
   {
      stage=13;
      lockMoney=InpGlobalStep3FloorMoney*scale;
      eventName="GLOBAL_STEP3_ARMED";
      return true;
   }
   if(money>=InpGlobalStep2TriggerMoney*scale)
   {
      stage=12;
      lockMoney=InpGlobalStep2FloorMoney*scale;
      eventName="GLOBAL_STEP2_ARMED";
      return true;
   }
   if(money>=InpGlobalStep1TriggerMoney*scale)
   {
      stage=11;
      lockMoney=InpGlobalStep1FloorMoney*scale;
      eventName="GLOBAL_STEP1_ARMED";
      return true;
   }

   return false;
}

int RecoveryGlobalStateIndex(const ulong id)
{
   int i=0;
   for(;i<ArraySize(recoveryStates);i++)
      if(recoveryStates[i].id==id) break;

   if(i==ArraySize(recoveryStates))
   {
      ArrayResize(recoveryStates,i+1);
      recoveryStates[i].id=id;
      recoveryStates[i].stage=0;
      recoveryStates[i].trigger=0;
      recoveryStates[i].stop=0.0;
      RecoveryFailureReset(i);

      if(!MQLInfoInteger(MQL_TESTER) && GlobalVariableCheck(RecoveryKey(id,"state")))
      {
         recoveryStates[i].stage=(int)GlobalVariableGet(RecoveryKey(id,"state"));
         recoveryStates[i].trigger=(datetime)GlobalVariableGet(RecoveryKey(id,"time"));
         recoveryStates[i].stop=GlobalVariableGet(RecoveryKey(id,"stop"));
         if(GlobalVariableCheck(RecoveryKey(id,"feval")))
            recoveryStates[i].failureEvaluated=(GlobalVariableGet(RecoveryKey(id,"feval"))>0.5);
      }
   }

   // Safe switch from an old recovery mode while a position is already open.
   if(recoveryStates[i].stage>0 && recoveryStates[i].stage<10)
   {
      recoveryStates[i].stage=0;
      recoveryStates[i].trigger=0;
      recoveryStates[i].stop=0.0;
      RecoveryFailureReset(i);
      RecoverySave(i);
   }

   return i;
}

void RecoveryProcessGlobalProfitMode()
{
   for(int p=PositionsTotal()-1;p>=0;p--)
   {
      const ulong ticket=PositionGetTicket(p);
      if(ticket==0 || PositionGetString(POSITION_SYMBOL)!=_Symbol ||
         PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber) continue;

      const ulong id=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      const int i=RecoveryGlobalStateIndex(id);

      const double money=PositionGetDouble(POSITION_PROFIT);
      const double volume=PositionGetDouble(POSITION_VOLUME);
      const double scale=InpRecoveryScaleWithLot?volume/InpRecoveryReferenceLot:1.0;
      const bool buy=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY;
      const double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      const double oldSL=PositionGetDouble(POSITION_SL);
      const double tp=PositionGetDouble(POSITION_TP);

      MqlTick tick;
      if(!SymbolInfoTick(_Symbol,tick)) continue;
      const double market=buy?tick.bid:tick.ask;

      int desiredStage=0;
      double lockMoney=0.0;
      string eventName="";

      if(RecoveryGlobalResolveTarget(money,scale,desiredStage,lockMoney,eventName) &&
         desiredStage>recoveryStates[i].stage)
      {
         double candidate=0.0;
         if(RecoveryPriceForProfit(buy,volume,entry,lockMoney,candidate))
         {
            recoveryStates[i].stage=desiredStage;
            recoveryStates[i].stop=candidate;
            RecoverySave(i);
            RecoveryLog(ticket,desiredStage,eventName,money,candidate);
         }
      }

      if(recoveryStates[i].stage<10 || recoveryStates[i].stop<=0.0)
         continue;

      const double step=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
      if(step<=0.0) continue;

      double target=recoveryStates[i].stop;
      // Preserve an already-better SL from any other active manager.
      if(oldSL>0.0)
         target=buy?MathMax(target,oldSL):MathMin(target,oldSL);

      // If broker stop/freeze distance prevented SL placement and price already crossed
      // the remembered floor, close immediately instead of losing the protection.
      if(buy?market<=target:market>=target)
      {
         const bool ok=trade.PositionClose(ticket);
         const uint code=trade.ResultRetcode();
         RecoveryLog(ticket,recoveryStates[i].stage,
                     (ok && (code==TRADE_RETCODE_DONE ||
                             code==TRADE_RETCODE_DONE_PARTIAL))
                        ?"GLOBAL_CLOSE_EXECUTED":"GLOBAL_CLOSE_RETRY",
                     money,target);
         continue;
      }

      const double distance=(double)MathMax(SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL),
                                            SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL))*_Point;
      if(MathAbs(market-target)<=distance+step) continue;

      if(oldSL>0.0 &&
         (buy?target<=oldSL+step*0.5:target>=oldSL-step*0.5))
         continue;

      const bool ok=trade.PositionModify(ticket,target,tp);
      const uint code=trade.ResultRetcode();
      RecoveryLog(ticket,recoveryStates[i].stage,
                  (ok && code==TRADE_RETCODE_DONE)
                     ?"GLOBAL_SL_MODIFIED":"GLOBAL_SL_RETRY",
                  money,target);
   }
}

bool RecoveryFailureEvaluate(const int i,const ulong ticket,const double money,
                             const double recoveryScale,const bool buy)
{
   if(!InpRecoveryFailureProtection || recoveryStates[i].failureEvaluated) return false;
   const datetime now=TimeCurrent();
   const double minutes=(double)(now-recoveryStates[i].trigger)/60.0;
   if(minutes<InpRecoveryFailureDelayMinutes) return false;

   RecoveryFailureAddSample(i,money,now,true);
   recoveryStates[i].failureEvaluated=true;

   double negativeRatio=0.0,slope=0.0;
   if(!RecoveryFailureStats(i,now,negativeRatio,slope))
   {
      RecoverySave(i);
      RecoveryLog(ticket,1,"FAILURE_SKIPPED_NO_HISTORY",money,0.0);
      return false;
   }

   const double activationLoss=InpRecoveryFailureActivationMoney*recoveryScale;
   if(money>-activationLoss)
   {
      RecoverySave(i);
      RecoveryLog(ticket,1,"FAILURE_REJECT_MONEY",money,0.0,negativeRatio,slope);
      return false;
   }
   if(negativeRatio<InpRecoveryFailureNegativeRatio)
   {
      RecoverySave(i);
      RecoveryLog(ticket,1,"FAILURE_REJECT_NEGATIVE_RATIO",money,0.0,negativeRatio,slope);
      return false;
   }
   const double scaledMaxSlope=InpRecoveryFailureMaxSlopeMoneyPerMinute*recoveryScale;
   if(slope>=scaledMaxSlope)
   {
      RecoverySave(i);
      RecoveryLog(ticket,1,"FAILURE_REJECT_SLOPE",money,0.0,negativeRatio,slope);
      return false;
   }

   const double stopLossMoney=InpRecoveryFailureStopMoney*recoveryScale;
   double target=0.0;
   RecoveryPriceForLoss(buy,PositionGetDouble(POSITION_VOLUME),
                        PositionGetDouble(POSITION_PRICE_OPEN),stopLossMoney,target);
   recoveryStates[i].stage=5;
   recoveryStates[i].stop=target;
   RecoverySave(i);
   RecoveryLog(ticket,5,"FAILURE_ARMED",money,target,negativeRatio,slope);
   return true;
}

bool RecoveryValidateInputs(string &reason)
{
   reason="";
   if(InpRecoveryReferenceLot<=0) reason="InpRecoveryReferenceLot must be > 0";
   else if(InpRecoveryLossMoney<=0) reason="InpRecoveryLossMoney must be > 0";
   else if(InpRecoveryArmMoney<=InpRecoveryFloorMoney)
      reason="InpRecoveryArmMoney must be > InpRecoveryFloorMoney";
   else if(InpRecoveryFloorMoney<=0) reason="InpRecoveryFloorMoney must be > 0";
   else if(InpRecoveryMinMinutes<0) reason="InpRecoveryMinMinutes must be >= 0";
   else if(InpRecoveryTrailMinutes<=InpRecoveryMinMinutes)
      reason="InpRecoveryTrailMinutes must be > InpRecoveryMinMinutes";
   else if(InpRecoveryTrailPips<=0) reason="InpRecoveryTrailPips must be > 0";
   if(reason!="") return false;

   if(InpRecoveryMode==RECOVERY_GLOBAL_LOCK)
   {
      if(InpGlobalLockFloorMoney<=0.0)
         reason="InpGlobalLockFloorMoney must be > 0";
      else if(InpGlobalLockTriggerMoney<=InpGlobalLockFloorMoney)
         reason="InpGlobalLockTriggerMoney must be > InpGlobalLockFloorMoney";
      if(reason!="") return false;
   }

   if(InpRecoveryMode==RECOVERY_GLOBAL_STEP_TRAIL)
   {
      if(InpGlobalStep1FloorMoney<=0.0 ||
         InpGlobalStep2FloorMoney<=0.0 ||
         InpGlobalStep3FloorMoney<=0.0)
         reason="Global step floors must be > 0";
      else if(InpGlobalStep1TriggerMoney<=InpGlobalStep1FloorMoney ||
              InpGlobalStep2TriggerMoney<=InpGlobalStep2FloorMoney ||
              InpGlobalStep3TriggerMoney<=InpGlobalStep3FloorMoney)
         reason="Each global step trigger must be > its floor";
      else if(InpGlobalStep2TriggerMoney<=InpGlobalStep1TriggerMoney ||
              InpGlobalStep3TriggerMoney<=InpGlobalStep2TriggerMoney)
         reason="Global step triggers must increase";
      else if(InpGlobalStep2FloorMoney<InpGlobalStep1FloorMoney ||
              InpGlobalStep3FloorMoney<InpGlobalStep2FloorMoney)
         reason="Global step floors must not decrease";
      if(reason!="") return false;
   }

   if(InpRecoveryFailureProtection)
   {
      const int windowSeconds=(int)MathRound(InpRecoveryFailureWindowMinutes*60.0);
      const int required=(InpRecoveryFailureSampleSeconds>0 ?
         (int)MathCeil((double)windowSeconds/InpRecoveryFailureSampleSeconds)+2 :
         RBT_RECOVERY_FAILURE_MAX_SAMPLES+1);
      if(InpRecoveryFailureDelayMinutes<=0.0)
         reason="InpRecoveryFailureDelayMinutes must be > 0";
      else if(InpRecoveryFailureWindowMinutes<=0.0)
         reason="InpRecoveryFailureWindowMinutes must be > 0";
      else if(InpRecoveryFailureWindowMinutes>InpRecoveryFailureDelayMinutes)
         reason="InpRecoveryFailureWindowMinutes must be <= InpRecoveryFailureDelayMinutes";
      else if(InpRecoveryFailureActivationMoney<=InpRecoveryLossMoney)
         reason="InpRecoveryFailureActivationMoney must be > InpRecoveryLossMoney";
      else if(InpRecoveryFailureStopMoney<=InpRecoveryFailureActivationMoney)
         reason="InpRecoveryFailureStopMoney must be > InpRecoveryFailureActivationMoney";
      else if(InpRecoveryFailureNegativeRatio<0.0 || InpRecoveryFailureNegativeRatio>1.0)
         reason="InpRecoveryFailureNegativeRatio must be in [0,1]";
      else if(InpRecoveryFailureSampleSeconds<1)
         reason="InpRecoveryFailureSampleSeconds must be >= 1";
      else if(required>RBT_RECOVERY_FAILURE_MAX_SAMPLES)
         reason="Recovery window/sample interval exceeds the history buffer";
   }
   return reason=="";
}

bool RecoveryInit()
{
   string reason="";
   if(!RecoveryValidateInputs(reason))
   {
      Print("RECOVERY invalid inputs | ",reason);
      return false;
   }
   ArrayResize(recoveryStates,0);
   if(InpRecoveryMode==RECOVERY_NORMAL) return true;
   int flags=FILE_WRITE|FILE_CSV|FILE_ANSI|FILE_SHARE_READ;
   if(InpHybridCSVUseCommonFiles)
   {
      flags|=FILE_COMMON;
      FolderCreate("RBT_M5_V5",FILE_COMMON);
   }
   else FolderCreate("RBT_M5_V5");
   const string path="RBT_M5_V5\\RBT_M5_RECOVERY_"+HybridCSVRuntimeLabel()+".csv";
   ResetLastError();
   recoveryLog=FileOpen(path,flags,';',CP_UTF8);
   if(recoveryLog==INVALID_HANDLE)
   {
      const int error=GetLastError();
      PrintFormat("RECOVERY CSV open failed | file=%s common=%d error=%d | label=%s",
         path,(int)InpHybridCSVUseCommonFiles,error,InpHybridRunLabel);
      return false;
   }
   ResetLastError();
   const uint written=FileWrite(recoveryLog,"time","ticket","mode","stage","event","floating_money",
                "target_sl","negative_ratio","slope_money_per_minute");
   if(written==0)
   {
      const int error=GetLastError();
      PrintFormat("RECOVERY CSV header write failed | file=%s error=%d",path,error);
      FileClose(recoveryLog);
      recoveryLog=INVALID_HANDLE;
      return false;
   }
   FileFlush(recoveryLog);
   PrintFormat("RECOVERY CSV ready | file=%s common=%d mode=%d failure_live=%d",
      path,(int)InpHybridCSVUseCommonFiles,(int)InpRecoveryMode,(int)InpRecoveryFailureProtection);
   return true;
}

void RecoveryShutdown()
{
   if(recoveryLog!=INVALID_HANDLE)
   {
      FileClose(recoveryLog);
      recoveryLog=INVALID_HANDLE;
   }
}

void RecoveryProcess()
{
   if(InpRecoveryMode==RECOVERY_NORMAL) return;

   // Modes 3/4 are independent global profit-protection alternatives.
   // They watch every EA trade from entry and do not require the -20 recovery trigger.
   if(InpRecoveryMode==RECOVERY_GLOBAL_LOCK ||
      InpRecoveryMode==RECOVERY_GLOBAL_STEP_TRAIL)
   {
      RecoveryProcessGlobalProfitMode();
      return;
   }

   for(int p=PositionsTotal()-1;p>=0;p--)
   {
      const ulong ticket=PositionGetTicket(p);
      if(ticket==0 || PositionGetString(POSITION_SYMBOL)!=_Symbol ||
         PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber) continue;
      const ulong id=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      int i=0;
      for(;i<ArraySize(recoveryStates);i++)
         if(recoveryStates[i].id==id) break;

      if(i==ArraySize(recoveryStates))
      {
         ArrayResize(recoveryStates,i+1);
         recoveryStates[i].id=id;
         recoveryStates[i].stage=0;
         recoveryStates[i].trigger=0;
         recoveryStates[i].stop=0.0;
         RecoveryFailureReset(i);
         if(!MQLInfoInteger(MQL_TESTER) && GlobalVariableCheck(RecoveryKey(id,"state")))
         {
            recoveryStates[i].stage=(int)GlobalVariableGet(RecoveryKey(id,"state"));
            recoveryStates[i].trigger=(datetime)GlobalVariableGet(RecoveryKey(id,"time"));
            recoveryStates[i].stop=GlobalVariableGet(RecoveryKey(id,"stop"));
            if(GlobalVariableCheck(RecoveryKey(id,"feval")))
               recoveryStates[i].failureEvaluated=(GlobalVariableGet(RecoveryKey(id,"feval"))>0.5);
         }
      }

      // If the EA was switched back from a global mode while a trade is open,
      // do not reinterpret stages 10..13 as legacy Recovery stages.
      if(recoveryStates[i].stage>=10)
      {
         recoveryStates[i].stage=0;
         recoveryStates[i].trigger=0;
         recoveryStates[i].stop=0.0;
         RecoveryFailureReset(i);
         RecoverySave(i);
      }

      const double money=PositionGetDouble(POSITION_PROFIT);
      const double volume=PositionGetDouble(POSITION_VOLUME);
      const double recoveryScale=InpRecoveryScaleWithLot?volume/InpRecoveryReferenceLot:1.0;
      const double lossThreshold=InpRecoveryLossMoney*recoveryScale;
      const double armThreshold=InpRecoveryArmMoney*recoveryScale;
      const double floorThreshold=InpRecoveryFloorMoney*recoveryScale;
      const bool buy=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY;
      MqlTick tick;
      if(!SymbolInfoTick(_Symbol,tick)) continue;
      const double market=buy?tick.bid:tick.ask;
      int before=recoveryStates[i].stage;

      if(before==0 && money<=-lossThreshold)
      {
         recoveryStates[i].stage=1;
         recoveryStates[i].trigger=TimeCurrent();
         recoveryStates[i].stop=0.0;
         RecoveryFailureReset(i);
         RecoveryFailureAddSample(i,money,recoveryStates[i].trigger,true);
         RecoverySave(i);
         RecoveryLog(ticket,1,"TRIGGER",money,0.0);
         continue;
      }

      if(before==1)
      {
         RecoveryFailureAddSample(i,money,TimeCurrent());
         const double minutes=(double)(TimeCurrent()-recoveryStates[i].trigger)/60.0;
         if(money>=armThreshold)
            recoveryStates[i].stage=minutes<=InpRecoveryMinMinutes?2:3;
         else
         {
            RecoveryFailureEvaluate(i,ticket,money,recoveryScale,buy);
            if(recoveryStates[i].stage==1 && InpRecoveryMode==RECOVERY_WITH_TRAIL &&
               minutes>=InpRecoveryTrailMinutes && money<0.0)
               recoveryStates[i].stage=4;
         }
         if(recoveryStates[i].stage!=before && recoveryStates[i].stage!=5)
         {
            RecoverySave(i);
            RecoveryLog(ticket,recoveryStates[i].stage,"STATE",money,0.0);
         }
      }
      else if(before==5)
      {
         const double minutes=(double)(TimeCurrent()-recoveryStates[i].trigger)/60.0;
         if(money>=armThreshold)
            recoveryStates[i].stage=3;
         else if(InpRecoveryMode==RECOVERY_WITH_TRAIL &&
                 minutes>=InpRecoveryTrailMinutes && money<0.0)
            recoveryStates[i].stage=4;
         if(recoveryStates[i].stage!=before)
         {
            RecoverySave(i);
            RecoveryLog(ticket,recoveryStates[i].stage,"STATE",money,recoveryStates[i].stop);
         }
      }

      const int state=recoveryStates[i].stage;
      if(state<3) continue;
      const double oldSL=PositionGetDouble(POSITION_SL);
      const double tp=PositionGetDouble(POSITION_TP);
      const double step=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
      if(step<=0.0) continue;
      double candidate=0.0;

      if(state==3)
      {
         const double entry=PositionGetDouble(POSITION_PRICE_OPEN);
         double unit=0.0;
         if(!OrderCalcProfit(buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,_Symbol,volume,entry,
                             entry+(buy?1.0:-1.0)*PipSize(),unit) || unit<=0.0) continue;
         candidate=entry+(buy?1.0:-1.0)*floorThreshold/unit*PipSize();
         candidate=NormalizeDouble((buy?MathFloor(candidate/step):MathCeil(candidate/step))*step,_Digits);
      }
      else if(state==4)
      {
         candidate=market+(buy?-1.0:1.0)*InpRecoveryTrailPips*PipSize();
         candidate=NormalizeDouble((buy?MathFloor(candidate/step):MathCeil(candidate/step))*step,_Digits);
      }
      else
      {
         candidate=recoveryStates[i].stop;
         if(candidate<=0.0)
         {
            const double stopLossMoney=InpRecoveryFailureStopMoney*recoveryScale;
            if(!RecoveryPriceForLoss(buy,volume,PositionGetDouble(POSITION_PRICE_OPEN),
                                     stopLossMoney,candidate)) continue;
         }
      }

      const double saved=recoveryStates[i].stop;
      if(saved==0.0 || (buy?candidate>saved:candidate<saved))
      {
         recoveryStates[i].stop=candidate;
         RecoverySave(i);
      }
      double target=recoveryStates[i].stop;
      if(oldSL>0.0) target=buy?MathMax(target,oldSL):MathMin(target,oldSL);

      if(buy?market<=target:market>=target)
      {
         const bool ok=trade.PositionClose(ticket);
         const uint code=trade.ResultRetcode();
         const string prefix=(state==5?"FAILURE_":"");
         RecoveryLog(ticket,state,prefix+((ok && (code==TRADE_RETCODE_DONE ||
                     code==TRADE_RETCODE_DONE_PARTIAL))?"CLOSE_EXECUTED":"CLOSE_RETRY"),
                     money,target);
         continue;
      }

      const double distance=(double)MathMax(SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL),
                                             SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL))*_Point;
      if(MathAbs(market-target)<=distance+step) continue;
      if(oldSL>0.0 && (buy?target<=oldSL+step*0.5:target>=oldSL-step*0.5)) continue;
      const bool ok=trade.PositionModify(ticket,target,tp);
      const uint code=trade.ResultRetcode();
      const string prefix=(state==5?"FAILURE_":"");
      RecoveryLog(ticket,state,prefix+((ok && code==TRADE_RETCODE_DONE)?"SL_MODIFIED":"SL_RETRY"),
                  money,target);
   }
}

#endif
