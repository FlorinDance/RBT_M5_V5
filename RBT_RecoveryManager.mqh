#ifndef RBT_RECOVERY_MANAGER
#define RBT_RECOVERY_MANAGER

#define RBT_RECOVERY_FAILURE_MAX_SAMPLES 256
#define RBT_RECOVERY_DEGRADATION_MAX_SAMPLES 16

// Recovery states: 0 untriggered, 1 waiting, 2 disabled-fast, 3 protected,
// 4 trailing, 5 filtered failure stop armed.
// Global modes use stages 10..13 and are isolated from the legacy recovery states.
struct RecoveryState
{
   ulong    id;
   int      stage;
   datetime trigger;
   double   stop;
   bool     globalLockArmed;
   double   globalLockStop;
   bool     failureEvaluated;
   datetime failureLastSample;
   int      failureSampleCount;
   datetime failureSampleTime[RBT_RECOVERY_FAILURE_MAX_SAMPLES];
   double   failureSampleMoney[RBT_RECOVERY_FAILURE_MAX_SAMPLES];

   // v5.10.21 live degradation detector state (mode 7).
   bool     degradationSegmentActive;
   datetime degradationSegmentStart;
   bool     degradationSegmentRearmed;
   bool     degradationRecoverySeen;
   bool     degradationAboveLossSeen;
   bool     degradationAWarningLogged;
   bool     degradationB1Attempted;
   datetime degradationB1CandidateTime;
   datetime degradationB2CandidateTime;
   datetime degradationLastSample;
   int      degradationSampleCount;
   datetime degradationSampleTime[RBT_RECOVERY_DEGRADATION_MAX_SAMPLES];
   double   degradationSamplePrice[RBT_RECOVERY_DEGRADATION_MAX_SAMPLES];
   bool     degradationD2Armed;
   datetime degradationD2Start;
   double   degradationD2BaselineMoney;
   int      degradationCloseStage;
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
   GlobalVariableSet(RecoveryKey(recoveryStates[i].id,"garm"),recoveryStates[i].globalLockArmed?1.0:0.0);
   GlobalVariableSet(RecoveryKey(recoveryStates[i].id,"gstop"),recoveryStates[i].globalLockStop);
   GlobalVariableSet(RecoveryKey(recoveryStates[i].id,"feval"),recoveryStates[i].failureEvaluated?1.0:0.0);
   GlobalVariableSet(RecoveryKey(recoveryStates[i].id,"d2arm"),recoveryStates[i].degradationD2Armed?1.0:0.0);
   GlobalVariableSet(RecoveryKey(recoveryStates[i].id,"d2time"),(double)recoveryStates[i].degradationD2Start);
   GlobalVariableSet(RecoveryKey(recoveryStates[i].id,"d2base"),recoveryStates[i].degradationD2BaselineMoney);
   GlobalVariableSet(RecoveryKey(recoveryStates[i].id,"dgclose"),(double)recoveryStates[i].degradationCloseStage);
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

void RecoveryDegradationReset(const int i)
{
   recoveryStates[i].degradationSegmentActive=false;
   recoveryStates[i].degradationSegmentStart=0;
   recoveryStates[i].degradationSegmentRearmed=false;
   recoveryStates[i].degradationRecoverySeen=false;
   recoveryStates[i].degradationAboveLossSeen=false;
   recoveryStates[i].degradationAWarningLogged=false;
   recoveryStates[i].degradationB1Attempted=false;
   recoveryStates[i].degradationB1CandidateTime=0;
   recoveryStates[i].degradationB2CandidateTime=0;
   recoveryStates[i].degradationLastSample=0;
   recoveryStates[i].degradationSampleCount=0;
   recoveryStates[i].degradationD2Armed=false;
   recoveryStates[i].degradationD2Start=0;
   recoveryStates[i].degradationD2BaselineMoney=0.0;
   recoveryStates[i].degradationCloseStage=0;
}

bool RecoveryDegradationEnabled()
{
   return InpRecoveryMode==RECOVERY_GLOBAL_LOCK_RECOVERY_DEGRADATION_TIME_STOP &&
          InpDegradationProtection;
}

void RecoveryDegradationLoadPersistent(const int i,const ulong id)
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   if(GlobalVariableCheck(RecoveryKey(id,"d2arm")))
      recoveryStates[i].degradationD2Armed=(GlobalVariableGet(RecoveryKey(id,"d2arm"))>0.5);
   if(GlobalVariableCheck(RecoveryKey(id,"d2time")))
      recoveryStates[i].degradationD2Start=(datetime)GlobalVariableGet(RecoveryKey(id,"d2time"));
   if(GlobalVariableCheck(RecoveryKey(id,"d2base")))
      recoveryStates[i].degradationD2BaselineMoney=GlobalVariableGet(RecoveryKey(id,"d2base"));
   if(GlobalVariableCheck(RecoveryKey(id,"dgclose")))
      recoveryStates[i].degradationCloseStage=(int)GlobalVariableGet(RecoveryKey(id,"dgclose"));
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

   if(InpRecoveryMode==RECOVERY_GLOBAL_LOCK ||
      InpRecoveryMode==RECOVERY_GLOBAL_LOCK_PLUS_RECOVERY_ONLY)
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
      recoveryStates[i].globalLockArmed=false;
      recoveryStates[i].globalLockStop=0.0;
      RecoveryFailureReset(i);
      RecoveryDegradationReset(i);

      if(!MQLInfoInteger(MQL_TESTER) && GlobalVariableCheck(RecoveryKey(id,"state")))
      {
         recoveryStates[i].stage=(int)GlobalVariableGet(RecoveryKey(id,"state"));
         recoveryStates[i].trigger=(datetime)GlobalVariableGet(RecoveryKey(id,"time"));
         recoveryStates[i].stop=GlobalVariableGet(RecoveryKey(id,"stop"));
         if(GlobalVariableCheck(RecoveryKey(id,"garm")))
            recoveryStates[i].globalLockArmed=(GlobalVariableGet(RecoveryKey(id,"garm"))>0.5);
         if(GlobalVariableCheck(RecoveryKey(id,"gstop")))
            recoveryStates[i].globalLockStop=GlobalVariableGet(RecoveryKey(id,"gstop"));
         if(GlobalVariableCheck(RecoveryKey(id,"feval")))
            recoveryStates[i].failureEvaluated=(GlobalVariableGet(RecoveryKey(id,"feval"))>0.5);
         RecoveryDegradationLoadPersistent(i,id);
      }
   }

   // Safe switch from an old recovery mode while a position is already open.
   if(recoveryStates[i].stage>0 && recoveryStates[i].stage<10)
   {
      recoveryStates[i].stage=0;
      recoveryStates[i].trigger=0;
      recoveryStates[i].stop=0.0;
      recoveryStates[i].globalLockArmed=false;
      recoveryStates[i].globalLockStop=0.0;
      RecoveryFailureReset(i);
      RecoveryDegradationReset(i);
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

// Mode 5 overlay: global +10 -> +5 protection runs independently from the
// legacy RECOVERY_ONLY state machine. This keeps the -20/+10 recovery logic
// and the 60-minute failure filter alive at the same time.
// Returns true when the position was closed (or a close retry is required),
// so the caller must not continue modifying the same position on that tick.
bool RecoveryProcessCombinedGlobalLock(const int i,const ulong ticket,
                                       const double money,const double scale,
                                       const bool buy,const double volume,
                                       const double market)
{
   const double trigger=InpGlobalLockTriggerMoney*scale;
   const double floorMoney=InpGlobalLockFloorMoney*scale;

   if(!recoveryStates[i].globalLockArmed && money>=trigger)
   {
      const double entry=PositionGetDouble(POSITION_PRICE_OPEN);
      double candidate=0.0;
      if(RecoveryPriceForProfit(buy,volume,entry,floorMoney,candidate))
      {
         recoveryStates[i].globalLockArmed=true;
         recoveryStates[i].globalLockStop=candidate;
         RecoverySave(i);
         RecoveryLog(ticket,20,"COMBINED_GLOBAL_LOCK_ARMED",money,candidate);
      }
   }

   if(!recoveryStates[i].globalLockArmed || recoveryStates[i].globalLockStop<=0.0)
      return false;

   const double step=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(step<=0.0) return false;

   const double oldSL=PositionGetDouble(POSITION_SL);
   const double tp=PositionGetDouble(POSITION_TP);
   double target=recoveryStates[i].globalLockStop;

   // A better SL from any other manager always wins.
   if(oldSL>0.0)
      target=buy?MathMax(target,oldSL):MathMin(target,oldSL);

   // If broker freeze/stops prevented placement and the remembered floor has
   // already been crossed, force a market close to preserve the protection.
   if(buy?market<=target:market>=target)
   {
      const bool ok=trade.PositionClose(ticket);
      const uint code=trade.ResultRetcode();
      RecoveryLog(ticket,20,
                  (ok && (code==TRADE_RETCODE_DONE || code==TRADE_RETCODE_DONE_PARTIAL))
                     ?"COMBINED_GLOBAL_CLOSE_EXECUTED":"COMBINED_GLOBAL_CLOSE_RETRY",
                  money,target);
      return true;
   }

   const double distance=(double)MathMax(SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL),
                                         SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL))*_Point;
   if(MathAbs(market-target)<=distance+step)
      return false;

   if(oldSL>0.0 && (buy?target<=oldSL+step*0.5:target>=oldSL-step*0.5))
      return false;

   const bool ok=trade.PositionModify(ticket,target,tp);
   const uint code=trade.ResultRetcode();
   RecoveryLog(ticket,20,
               (ok && code==TRADE_RETCODE_DONE)
                  ?"COMBINED_GLOBAL_SL_MODIFIED":"COMBINED_GLOBAL_SL_RETRY",
               money,target);
   return false;
}

// Modes 6/7 hard time-stop: close every still-open EA trade once its age reaches
// InpCombinedTimeStopMinutes. Age is measured from POSITION_TIME (trade entry).
bool RecoveryProcessCombinedTimeStop(const ulong ticket,const double money)
{
   if(InpRecoveryMode!=RECOVERY_GLOBAL_LOCK_RECOVERY_ONLY_TIME_STOP &&
      InpRecoveryMode!=RECOVERY_GLOBAL_LOCK_RECOVERY_DEGRADATION_TIME_STOP)
      return false;

   if(InpCombinedTimeStopMinutes<=0.0)
      return false;

   const datetime entryTime=(datetime)PositionGetInteger(POSITION_TIME);
   if(entryTime<=0)
      return false;

   const double ageMinutes=(double)(TimeCurrent()-entryTime)/60.0;
   if(ageMinutes<InpCombinedTimeStopMinutes)
      return false;

   const bool ok=trade.PositionClose(ticket);
   const uint code=trade.ResultRetcode();
   RecoveryLog(ticket,21,
               (ok && (code==TRADE_RETCODE_DONE || code==TRADE_RETCODE_DONE_PARTIAL))
                  ?"COMBINED_TIME_STOP_CLOSE_EXECUTED":"COMBINED_TIME_STOP_CLOSE_RETRY",
               money,0.0);
   return true;
}

string RecoveryDegradationName(const int stage)
{
   if(stage==31) return "B1_FAST_SHOCK";
   if(stage==32) return "B2_SUSTAINED_COLLAPSE";
   if(stage==34) return "D2_CONFIRMED_DETERIORATION";
   return "DEGRADATION";
}

void RecoveryDegradationAddSample(const int i,const datetime now,
                                  const double market,const bool force=false)
{
   if(!RecoveryDegradationEnabled()) return;
   const datetime last=recoveryStates[i].degradationLastSample;
   if(last==now) return;
   if(!force && last>0 && (now-last)<InpDegradationSampleSeconds) return;

   int count=recoveryStates[i].degradationSampleCount;
   if(count>=RBT_RECOVERY_DEGRADATION_MAX_SAMPLES)
   {
      for(int s=1;s<RBT_RECOVERY_DEGRADATION_MAX_SAMPLES;s++)
      {
         recoveryStates[i].degradationSampleTime[s-1]=recoveryStates[i].degradationSampleTime[s];
         recoveryStates[i].degradationSamplePrice[s-1]=recoveryStates[i].degradationSamplePrice[s];
      }
      count=RBT_RECOVERY_DEGRADATION_MAX_SAMPLES-1;
   }

   recoveryStates[i].degradationSampleTime[count]=now;
   recoveryStates[i].degradationSamplePrice[count]=market;
   recoveryStates[i].degradationSampleCount=count+1;
   recoveryStates[i].degradationLastSample=now;
}

void RecoveryDegradationStartSegment(const int i,const datetime startTime,
                                     const bool rearmed,const double market)
{
   recoveryStates[i].degradationSegmentActive=true;
   recoveryStates[i].degradationSegmentStart=startTime;
   recoveryStates[i].degradationSegmentRearmed=rearmed;
   recoveryStates[i].degradationRecoverySeen=false;
   recoveryStates[i].degradationAboveLossSeen=false;
   recoveryStates[i].degradationAWarningLogged=false;
   recoveryStates[i].degradationB1Attempted=false;
   recoveryStates[i].degradationB1CandidateTime=0;
   recoveryStates[i].degradationB2CandidateTime=0;
   recoveryStates[i].degradationLastSample=0;
   recoveryStates[i].degradationSampleCount=0;
   RecoveryDegradationAddSample(i,TimeCurrent(),market,true);
}

bool RecoveryDegradationAttemptClose(const int i,const ulong ticket,
                                     const double money,const int requestedStage)
{
   if(recoveryStates[i].degradationCloseStage==0)
   {
      recoveryStates[i].degradationCloseStage=requestedStage;
      RecoverySave(i);
   }

   const int stage=recoveryStates[i].degradationCloseStage;
   const string name=RecoveryDegradationName(stage);
   const bool ok=trade.PositionClose(ticket);
   const uint code=trade.ResultRetcode();
   RecoveryLog(ticket,stage,
      name+((ok && (code==TRADE_RETCODE_DONE || code==TRADE_RETCODE_DONE_PARTIAL))
              ?"_CLOSE_EXECUTED":"_CLOSE_RETRY"),money,0.0);
   return true;
}

bool RecoveryDegradationCheckA(const int i,const ulong ticket,const double money,
                               const double scale,const bool buy)
{
   if(recoveryStates[i].degradationAWarningLogged) return false;
   if(money>-InpDegradationALossMoney*scale) return false;
   if(recoveryStates[i].degradationAboveLossSeen) return false;

   const int moves=InpDegradationAConsecutiveM5Moves;
   if(moves<1) return false;
   MqlRates rates[];
   ArraySetAsSeries(rates,true);
   if(CopyRates(_Symbol,PERIOD_M5,1,moves+1,rates)!=(moves+1)) return false;
   if(rates[moves].time<recoveryStates[i].degradationSegmentStart) return false;

   for(int k=moves;k>0;k--)
   {
      const double older=rates[k].close;
      const double newer=rates[k-1].close;
      const bool adverse=buy?(newer<older):(newer>older);
      if(!adverse) return false;
   }

   const double pips=MathAbs(rates[0].close-rates[moves].close)/PipSize();
   if(pips<InpDegradationAAdversePips) return false;

   recoveryStates[i].degradationAWarningLogged=true;
   RecoveryLog(ticket,30,"DEGRADATION_A_WARNING",money,0.0,EMPTY_VALUE,pips);
   return true;
}

bool RecoveryDegradationB2Pattern(const int i,const bool buy,double &adversePips)
{
   adversePips=0.0;
   const int moves=InpDegradationB2ConsecutiveMoves;
   if(moves<1) return false;
   const int count=recoveryStates[i].degradationSampleCount;
   if(count<moves+1) return false;

   const int first=count-moves-1;
   for(int s=first+1;s<count;s++)
   {
      const datetime dt=recoveryStates[i].degradationSampleTime[s]-
                        recoveryStates[i].degradationSampleTime[s-1];
      if(dt<=0 || dt>InpDegradationSampleSeconds*2+10) return false;
      const double older=recoveryStates[i].degradationSamplePrice[s-1];
      const double newer=recoveryStates[i].degradationSamplePrice[s];
      const bool adverse=buy?(newer<older):(newer>older);
      if(!adverse) return false;
   }

   adversePips=MathAbs(recoveryStates[i].degradationSamplePrice[count-1]-
                       recoveryStates[i].degradationSamplePrice[first])/PipSize();
   return true;
}

bool RecoveryProcessDegradation(const int i,const ulong ticket,const double money,
                                const double scale,const bool buy,
                                const double market,const double lossThreshold,
                                const double armThreshold)
{
   if(!RecoveryDegradationEnabled()) return false;
   const datetime now=TimeCurrent();

   // A previously confirmed live close is authoritative and is retried until executed.
   if(recoveryStates[i].degradationCloseStage!=0)
      return RecoveryDegradationAttemptClose(i,ticket,money,recoveryStates[i].degradationCloseStage);

   // D2: the 1h failure filter already classified the trade as degraded. If it
   // loses another configured amount during the next window, close immediately.
   if(recoveryStates[i].degradationD2Armed)
   {
      const double age=(double)(now-recoveryStates[i].degradationD2Start)/60.0;
      if(age>InpDegradationD2WindowMinutes)
      {
         recoveryStates[i].degradationD2Armed=false;
         RecoverySave(i);
         RecoveryLog(ticket,34,"DEGRADATION_D2_EXPIRED",money,0.0);
      }
      else if(money<=recoveryStates[i].degradationD2BaselineMoney-
                     InpDegradationD2AdditionalLossMoney*scale)
      {
         return RecoveryDegradationAttemptClose(i,ticket,money,34);
      }
   }

   // Once +10 is reached the global +10/+5 protection owns the position.
   if(money>=armThreshold)
   {
      RecoveryDegradationReset(i);
      RecoverySave(i);
      return false;
   }

   // Recover state after an EA/terminal restart while an already-triggered
   // Recovery trade is still open. Sample history starts fresh, conservatively.
   if(!recoveryStates[i].degradationSegmentActive &&
      recoveryStates[i].trigger>0 &&
      (recoveryStates[i].stage==1 || recoveryStates[i].stage==5))
   {
      RecoveryDegradationStartSegment(i,recoveryStates[i].trigger,false,market);
   }
   if(!recoveryStates[i].degradationSegmentActive) return false;

   // Track recovery above the -20 boundary. A recovery to at least -15 marks C.
   if(money>-lossThreshold)
      recoveryStates[i].degradationAboveLossSeen=true;
   if(money>=-InpDegradationCRecoveryMoney*scale && money<armThreshold)
      recoveryStates[i].degradationRecoverySeen=true;

   // C - failed recovery: when price falls through -20 again, start a fresh
   // degradation segment. The re-armed B2 requires a stricter pip impulse.
   if(recoveryStates[i].degradationRecoverySeen && money<=-lossThreshold)
   {
      RecoveryDegradationStartSegment(i,now,true,market);
      RecoveryLog(ticket,33,"DEGRADATION_C_REARM",money,0.0);
   }

   RecoveryDegradationAddSample(i,now,market);
   RecoveryDegradationCheckA(i,ticket,money,scale,buy);

   const double segmentAge=(double)(now-recoveryStates[i].degradationSegmentStart)/60.0;

   // B1 candidate and confirmation.
   if(recoveryStates[i].degradationB1CandidateTime>0)
   {
      const int elapsed=(int)(now-recoveryStates[i].degradationB1CandidateTime);
      if(elapsed>InpDegradationB1ConfirmMaxSeconds)
      {
         recoveryStates[i].degradationB1CandidateTime=0;
      }
      else if(elapsed>=InpDegradationB1ConfirmMinSeconds &&
              money<=-InpDegradationB1ConfirmLossMoney*scale)
      {
         return RecoveryDegradationAttemptClose(i,ticket,money,31);
      }
   }
   if(!recoveryStates[i].degradationB1Attempted &&
      recoveryStates[i].degradationB1CandidateTime==0 &&
      segmentAge<=InpDegradationB1FirstWindowMinutes &&
      money<=-InpDegradationB1FirstLossMoney*scale)
   {
      recoveryStates[i].degradationB1Attempted=true;
      recoveryStates[i].degradationB1CandidateTime=now;
      RecoveryLog(ticket,31,"DEGRADATION_B1_ARMED",money,0.0);
   }

   // B2 candidate and confirmation. The candidate is based on sampled market
   // price every ~60 seconds, not candle color, so BUY/SELL are symmetric.
   if(recoveryStates[i].degradationB2CandidateTime>0)
   {
      const int elapsed=(int)(now-recoveryStates[i].degradationB2CandidateTime);
      if(money>-lossThreshold)
      {
         recoveryStates[i].degradationB2CandidateTime=0;
      }
      else if(elapsed>InpDegradationB2ConfirmMaxSeconds)
      {
         recoveryStates[i].degradationB2CandidateTime=0;
      }
      else if(elapsed>=InpDegradationB2ConfirmMinSeconds &&
              money<=-InpDegradationB2ConfirmLossMoney*scale)
      {
         return RecoveryDegradationAttemptClose(i,ticket,money,32);
      }
   }

   if(recoveryStates[i].degradationB2CandidateTime==0 &&
      segmentAge<=InpDegradationB2WindowMinutes &&
      !recoveryStates[i].degradationAboveLossSeen &&
      money<=-InpDegradationB2ArmLossMoney*scale)
   {
      double adversePips=0.0;
      if(RecoveryDegradationB2Pattern(i,buy,adversePips))
      {
         const double requiredPips=(recoveryStates[i].degradationSegmentRearmed
            ?InpDegradationB2RearmedAdversePips
            :InpDegradationB2InitialAdversePips);
         if(adversePips>=requiredPips)
         {
            recoveryStates[i].degradationB2CandidateTime=now;
            RecoveryLog(ticket,32,"DEGRADATION_B2_ARMED",money,0.0,EMPTY_VALUE,adversePips);
         }
      }
   }

   return false;
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
   if(RecoveryDegradationEnabled())
   {
      recoveryStates[i].degradationD2Armed=true;
      recoveryStates[i].degradationD2Start=now;
      recoveryStates[i].degradationD2BaselineMoney=money;
   }
   RecoverySave(i);
   RecoveryLog(ticket,5,"FAILURE_ARMED",money,target,negativeRatio,slope);
   if(RecoveryDegradationEnabled())
      RecoveryLog(ticket,34,"DEGRADATION_D2_ARMED",money,0.0,negativeRatio,slope);
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

   if(InpRecoveryMode==RECOVERY_GLOBAL_LOCK ||
      InpRecoveryMode==RECOVERY_GLOBAL_LOCK_PLUS_RECOVERY_ONLY ||
      InpRecoveryMode==RECOVERY_GLOBAL_LOCK_RECOVERY_ONLY_TIME_STOP ||
      InpRecoveryMode==RECOVERY_GLOBAL_LOCK_RECOVERY_DEGRADATION_TIME_STOP)
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

   if((InpRecoveryMode==RECOVERY_GLOBAL_LOCK_RECOVERY_ONLY_TIME_STOP ||
       InpRecoveryMode==RECOVERY_GLOBAL_LOCK_RECOVERY_DEGRADATION_TIME_STOP) &&
      InpCombinedTimeStopMinutes<=0.0)
   {
      reason="InpCombinedTimeStopMinutes must be > 0";
      return false;
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

   if(reason=="" && InpRecoveryMode==RECOVERY_GLOBAL_LOCK_RECOVERY_DEGRADATION_TIME_STOP &&
      InpDegradationProtection)
   {
      if(InpDegradationSampleSeconds<1)
         reason="InpDegradationSampleSeconds must be >= 1";
      else if(InpDegradationAConsecutiveM5Moves<1 || InpDegradationAConsecutiveM5Moves>8)
         reason="InpDegradationAConsecutiveM5Moves must be in [1,8]";
      else if(InpDegradationAAdversePips<=0.0 || InpDegradationALossMoney<=InpRecoveryLossMoney)
         reason="A degradation thresholds are invalid";
      else if(InpDegradationB1FirstWindowMinutes<=0.0 ||
              InpDegradationB1FirstLossMoney<=InpRecoveryLossMoney ||
              InpDegradationB1ConfirmLossMoney<=InpDegradationB1FirstLossMoney)
         reason="B1 degradation thresholds are invalid";
      else if(InpDegradationB1ConfirmMinSeconds<1 ||
              InpDegradationB1ConfirmMaxSeconds<InpDegradationB1ConfirmMinSeconds)
         reason="B1 confirmation timing is invalid";
      else if(InpDegradationB2WindowMinutes<=0.0 ||
              InpDegradationB2ConsecutiveMoves<2 ||
              InpDegradationB2ConsecutiveMoves>=RBT_RECOVERY_DEGRADATION_MAX_SAMPLES ||
              InpDegradationB2InitialAdversePips<=0.0 ||
              InpDegradationB2RearmedAdversePips<InpDegradationB2InitialAdversePips ||
              InpDegradationB2ArmLossMoney<=InpRecoveryLossMoney ||
              InpDegradationB2ConfirmLossMoney<=InpDegradationB2ArmLossMoney)
         reason="B2 degradation thresholds are invalid";
      else if(InpDegradationB2ConfirmMinSeconds<1 ||
              InpDegradationB2ConfirmMaxSeconds<InpDegradationB2ConfirmMinSeconds)
         reason="B2 confirmation timing is invalid";
      else if(InpDegradationCRecoveryMoney<=0.0 ||
              InpDegradationCRecoveryMoney>=InpRecoveryLossMoney)
         reason="InpDegradationCRecoveryMoney must be in (0, RecoveryLossMoney)";
      else if(InpDegradationD2AdditionalLossMoney<=0.0 ||
              InpDegradationD2WindowMinutes<=0.0)
         reason="D2 degradation thresholds are invalid";
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
         recoveryStates[i].globalLockArmed=false;
         recoveryStates[i].globalLockStop=0.0;
         RecoveryFailureReset(i);
         RecoveryDegradationReset(i);
         if(!MQLInfoInteger(MQL_TESTER) && GlobalVariableCheck(RecoveryKey(id,"state")))
         {
            recoveryStates[i].stage=(int)GlobalVariableGet(RecoveryKey(id,"state"));
            recoveryStates[i].trigger=(datetime)GlobalVariableGet(RecoveryKey(id,"time"));
            recoveryStates[i].stop=GlobalVariableGet(RecoveryKey(id,"stop"));
            if(GlobalVariableCheck(RecoveryKey(id,"garm")))
               recoveryStates[i].globalLockArmed=(GlobalVariableGet(RecoveryKey(id,"garm"))>0.5);
            if(GlobalVariableCheck(RecoveryKey(id,"gstop")))
               recoveryStates[i].globalLockStop=GlobalVariableGet(RecoveryKey(id,"gstop"));
            if(GlobalVariableCheck(RecoveryKey(id,"feval")))
               recoveryStates[i].failureEvaluated=(GlobalVariableGet(RecoveryKey(id,"feval"))>0.5);
            RecoveryDegradationLoadPersistent(i,id);
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
         RecoveryDegradationReset(i);
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

      // Modes 5/6/7 = global +10/+5 overlay + the complete RECOVERY_ONLY logic below.
      // Modes 6/7 also apply the configurable hard time-stop from trade entry.
      // Mode 7 additionally executes the LIVE B1/B2/D2 degradation exits.
      if(InpRecoveryMode==RECOVERY_GLOBAL_LOCK_PLUS_RECOVERY_ONLY ||
         InpRecoveryMode==RECOVERY_GLOBAL_LOCK_RECOVERY_ONLY_TIME_STOP ||
         InpRecoveryMode==RECOVERY_GLOBAL_LOCK_RECOVERY_DEGRADATION_TIME_STOP)
      {
         // Time-stop is authoritative in modes 6/7.
         if(RecoveryProcessCombinedTimeStop(ticket,money))
            continue;
         if(!PositionSelectByTicket(ticket))
            continue;

         if(RecoveryProcessCombinedGlobalLock(i,ticket,money,recoveryScale,buy,volume,market))
            continue;
         if(!PositionSelectByTicket(ticket))
            continue;

         if(RecoveryProcessDegradation(i,ticket,money,recoveryScale,buy,market,
                                       lossThreshold,armThreshold))
            continue;
         if(!PositionSelectByTicket(ticket))
            continue;
      }

      int before=recoveryStates[i].stage;

      if(before==0 && money<=-lossThreshold)
      {
         recoveryStates[i].stage=1;
         recoveryStates[i].trigger=TimeCurrent();
         recoveryStates[i].stop=0.0;
         RecoveryFailureReset(i);
         RecoveryDegradationReset(i);
         RecoveryFailureAddSample(i,money,recoveryStates[i].trigger,true);
         if(RecoveryDegradationEnabled())
            RecoveryDegradationStartSegment(i,recoveryStates[i].trigger,false,market);
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
