//+------------------------------------------------------------------+
//| EA_ML_M5_Helpers.mqh                                            |
//| Helper-e tehnice generale extrase din EA-ul principal.           |
//| ATENȚIE: corpul funcțiilor este păstrat ca în fișierul anterior; |
//| aici sunt adăugate doar descrieri, organizare și include guard.  |
//+------------------------------------------------------------------+

#ifndef __EA_ML_M5_HELPERS_MQH__
#define __EA_ML_M5_HELPERS_MQH__

//+------------------------------------------------------------------+
//| PipSize
//| Returnează mărimea unui pip pentru simbolul curent, adaptată la numărul de digits.
//+------------------------------------------------------------------+
double PipSize()
{
   if(_Digits == 3 || _Digits == 5)
      return _Point * 10.0;
   return _Point;
}
//------------------------------------------------------------------//
//+------------------------------------------------------------------+
//| IsNewBar
//| Detectează apariția unei lumânări M5 noi și actualizează timpul ultimei bare procesate.
//+------------------------------------------------------------------+
bool IsNewBar()
{
   datetime t = iTime(_Symbol, PERIOD_M5, 0);
   if(t == 0)
      return false;

   if(t != g_lastBarTime)
   {
      g_lastBarTime = t;
      return true;
   }
   return false;
}

//-------------dinamic sl
//+------------------------------------------------------------------+
//| CountTrue
//| Numără câte condiții booleene sunt adevărate.
//+------------------------------------------------------------------+
int CountTrue(const bool a, const bool b, const bool c, const bool d)
{
   int count = 0;
   if(a) count++;
   if(b) count++;
   if(c) count++;
   if(d) count++;
   return count;
}

//+------------------------------------------------------------------+
//| SafeDiv
//| Împarte două valori cu protecție la împărțirea la zero sau valori foarte mici.
//+------------------------------------------------------------------+
double SafeDiv(double a, double b)
{
   if(MathAbs(b) < 1e-10)
      return 0.0;
   return a / b;
}


//------------------------------------------------------------------//
//+------------------------------------------------------------------+
//| HasOpenPositionOnSymbol
//| Verifică dacă există deja o poziție deschisă pe simbolul curent.
//+------------------------------------------------------------------+
bool HasOpenPositionOnSymbol()
{
   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;

      if(PositionSelectByTicket(ticket))
      {
         string sym = PositionGetString(POSITION_SYMBOL);
         long   mag = PositionGetInteger(POSITION_MAGIC);
         if(sym == _Symbol && mag == InpMagicNumber)
            return true;
      }
   }
   return false;
}
//------------------------------------------------------------------//
// v5.10.22 degradation post-close cooldown.
// Shared by the Recovery manager (arms it) and the entry path (enforces it).
datetime g_degradationEntryCooldownUntil = 0;

string DegradationEntryCooldownKey()
{
   return StringFormat("RBT.DGCD.%I64d.%s.%I64d",
                       AccountInfoInteger(ACCOUNT_LOGIN),_Symbol,InpMagicNumber);
}

void DegradationEntryCooldownInitialize()
{
   g_degradationEntryCooldownUntil=0;
   if(!InpDegradationProtection ||
      InpRecoveryMode!=RECOVERY_GLOBAL_LOCK_RECOVERY_DEGRADATION_TIME_STOP)
      return;
   if(MQLInfoInteger(MQL_TESTER)) return;

   const string key=DegradationEntryCooldownKey();
   if(!GlobalVariableCheck(key)) return;

   const datetime until=(datetime)GlobalVariableGet(key);
   if(until>TimeCurrent())
      g_degradationEntryCooldownUntil=until;
   else
      GlobalVariableDel(key);
}

void DegradationEntryCooldownArm(const datetime now)
{
   if(InpDegradationPostCloseCooldownMinutes<=0.0) return;
   const datetime until=now+(datetime)MathRound(InpDegradationPostCloseCooldownMinutes*60.0);
   if(until<=g_degradationEntryCooldownUntil) return;

   g_degradationEntryCooldownUntil=until;
   if(!MQLInfoInteger(MQL_TESTER))
   {
      GlobalVariableSet(DegradationEntryCooldownKey(),(double)until);
      GlobalVariablesFlush();
   }
}

bool DegradationEntryCooldownActive(int &secondsRemaining)
{
   secondsRemaining=0;
   if(!InpDegradationProtection ||
      InpRecoveryMode!=RECOVERY_GLOBAL_LOCK_RECOVERY_DEGRADATION_TIME_STOP)
      return false;
   if(g_degradationEntryCooldownUntil<=0) return false;

   const datetime now=TimeCurrent();
   if(now>=g_degradationEntryCooldownUntil)
   {
      g_degradationEntryCooldownUntil=0;
      if(!MQLInfoInteger(MQL_TESTER))
         GlobalVariableDel(DegradationEntryCooldownKey());
      return false;
   }

   secondsRemaining=(int)(g_degradationEntryCooldownUntil-now);
   return true;
}

//------------------------------------------------------------------//
//+------------------------------------------------------------------+
//| CopyOneBufferValue
//| Copiază o singură valoare dintr-un buffer de indicator MT5.
//+------------------------------------------------------------------+
bool CopyOneBufferValue(const int handle, const int bufferIndex, const int shift, double &outValue)
{
   if(handle == INVALID_HANDLE)
      return false;

   double arr[];
   ArraySetAsSeries(arr, true);

   if(CopyBuffer(handle, bufferIndex, shift, 1, arr) < 1)
      return false;

   outValue = arr[0];
   return true;
}
//------------------------------------------------------------------//
//+------------------------------------------------------------------+
//| GetClosePrice
//| Citește prețul de închidere pentru lumânarea cerută.
//+------------------------------------------------------------------+
bool GetClosePrice(const int shift, double &value)
{
   value = iClose(_Symbol, PERIOD_M5, shift);
   return (value != 0.0);
}

#endif // __EA_ML_M5_HELPERS_MQH__
