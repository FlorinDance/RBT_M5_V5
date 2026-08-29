//+------------------------------------------------------------------+
//| RBT_Hybrid_Scalper.mqh                                          |
//| Optional XGBoost-only fast-exit and profit-protection policy.    |
//+------------------------------------------------------------------+
#ifndef __RBT_HYBRID_SCALPER_MQH__
#define __RBT_HYBRID_SCALPER_MQH__

bool HybridScalperValidateInputs(string &reason)
{
   reason = "OK";
   if(!InpScalperMode)
      return true;
   if(InpScalperTakeProfitMoney <= 0.0)
      reason = "Scalper TP money must be positive";
   else if(InpScalperStopLossPips <= 0.0)
      reason = "Scalper SL pips must be positive";
   else if(InpScalperMaximumMinutes < 1 || InpScalperMaximumMinutes > 1440)
      reason = "Scalper timeout must be in [1,1440] minutes";
   else if(InpScalperNoProfitCutEnable &&
      (InpScalperNoProfitCutMinutes < 0.10 ||
       InpScalperNoProfitCutMinutes >= (double)InpScalperMaximumMinutes))
      reason = "No-profit cut minutes must be >=0.10 and below timeout";
   else if(InpScalperProfitProtectEnable &&
      (InpScalperProfitProtectArmMoney <= 0.0 ||
       InpScalperProfitProtectArmMoney >= InpScalperTakeProfitMoney))
      reason = "Profit-protect arm money must be positive and below Scalper TP";
   else if(InpScalperProfitProtectEnable &&
      (InpScalperProfitProtectFloorMoney < 0.0 ||
       InpScalperProfitProtectFloorMoney >= InpScalperProfitProtectArmMoney))
      reason = "Profit-protect floor must be non-negative and below arm money";
   return (reason == "OK");
}

void HybridScalperProcessTick()
{
   if(!InpScalperMode ||
      (!InpScalperCloseAtTimeout && !InpScalperNoProfitCutEnable &&
       !InpScalperProfitProtectEnable))
      return;
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick))
      return;
   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || PositionGetString(POSITION_SYMBOL) != _Symbol ||
         (long)PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;
      const long openTimeMsc = (long)PositionGetInteger(POSITION_TIME_MSC);
      const long positionId = (long)PositionGetInteger(POSITION_IDENTIFIER);
      const double ageMinutes = MathMax(0.0,(double)((long)tick.time_msc-openTimeMsc)/60000.0);
      const int trajectoryIndex = HybridTrajectoryFind(positionId);
      double entryCosts = 0.0;
      if(trajectoryIndex >= 0)
         entryCosts = g_hybridTrajectories[trajectoryIndex].entryCosts;
      const double currentNetMoney = PositionGetDouble(POSITION_PROFIT) +
                                     PositionGetDouble(POSITION_SWAP) + entryCosts;
      bool closeForProfitProtect = false;
      if(InpScalperProfitProtectEnable && trajectoryIndex >= 0 &&
         g_hybridTrajectories[trajectoryIndex].profitProtectArmed &&
         currentNetMoney <= InpScalperProfitProtectFloorMoney)
         closeForProfitProtect = true;
      bool closeForNoProfit = false;
      if(InpScalperNoProfitCutEnable &&
         ageMinutes >= InpScalperNoProfitCutMinutes)
      {
         if(trajectoryIndex >= 0 &&
            !g_hybridTrajectories[trajectoryIndex].firstProfitSeen)
            closeForNoProfit = true;
      }
      const bool closeForTimeout = (InpScalperCloseAtTimeout &&
         ageMinutes >= (double)InpScalperMaximumMinutes);
      if(!closeForProfitProtect && !closeForNoProfit && !closeForTimeout)
         continue;
      string exitPolicy = "TIMEOUT";
      if(closeForProfitProtect)
         exitPolicy = "PROFIT_PROTECT";
      else if(closeForNoProfit)
         exitPolicy = "NO_PROFIT_CUT";
      HybridTrajectorySetRequestedExitPolicy(positionId,exitPolicy,currentNetMoney);
      trade.SetDeviationInPoints(InpDeviationPoints);
      const bool closed = trade.PositionClose(ticket,(ulong)InpDeviationPoints);
      if(!closed)
         HybridTrajectoryClearRequestedExitPolicy(positionId);
      if(InpScalperLog)
         PrintFormat("SCALPER %s | ticket=%I64u age=%.3fm profit=%.2f closed=%d retcode=%u %s",
            exitPolicy,ticket,ageMinutes,currentNetMoney,(int)closed,trade.ResultRetcode(),
            trade.ResultRetcodeDescription());
   }
}

#endif
