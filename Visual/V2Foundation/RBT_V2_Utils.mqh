#ifndef __RBT_V2_UTILS_MQH__
#define __RBT_V2_UTILS_MQH__

double RBT_Clamp(const double value, const double minimum, const double maximum)
{
   if(value < minimum) return minimum;
   if(value > maximum) return maximum;
   return value;
}

double RBT_SafeDiv(const double numerator, const double denominator, const double fallback = 0.0)
{
   if(!MathIsValidNumber(numerator) || !MathIsValidNumber(denominator))
      return fallback;
   if(MathAbs(denominator) < 1e-12)
      return fallback;
   return numerator / denominator;
}

bool RBT_IsFinite(const double value)
{
   return MathIsValidNumber(value);
}

double RBT_PipSize(const string symbol = "")
{
   string usedSymbol = symbol;
   if(usedSymbol == "")
      usedSymbol = _Symbol;

   const int digits = (int)SymbolInfoInteger(usedSymbol, SYMBOL_DIGITS);
   const double point = SymbolInfoDouble(usedSymbol, SYMBOL_POINT);
   if(digits == 3 || digits == 5)
      return point * 10.0;
   return point;
}

double RBT_NormalizePrice(const double price, const string symbol = "")
{
   string usedSymbol = symbol;
   if(usedSymbol == "")
      usedSymbol = _Symbol;
   const int digits = (int)SymbolInfoInteger(usedSymbol, SYMBOL_DIGITS);
   return NormalizeDouble(price, digits);
}

double RBT_CurrentSpreadPips(const string symbol = "")
{
   string usedSymbol = symbol;
   if(usedSymbol == "")
      usedSymbol = _Symbol;

   MqlTick tick;
   if(!SymbolInfoTick(usedSymbol, tick))
      return 0.0;
   return RBT_SafeDiv(tick.ask - tick.bid, RBT_PipSize(usedSymbol), 0.0);
}

string RBT_DirectionToString(const int direction)
{
   if(direction == RBT_DIR_BUY) return "BUY";
   if(direction == RBT_DIR_SELL) return "SELL";
   return "HOLD";
}

string RBT_StructureDirectionToString(const int direction)
{
   if(direction == RBT_STRUCTURE_BULLISH) return "BULLISH";
   if(direction == RBT_STRUCTURE_BEARISH) return "BEARISH";
   return "NEUTRAL";
}

string RBT_SwingTypeToString(const int swingType)
{
   switch(swingType)
   {
      case RBT_SWING_HH:         return "HH";
      case RBT_SWING_HL:         return "HL";
      case RBT_SWING_LH:         return "LH";
      case RBT_SWING_LL:         return "LL";
      case RBT_SWING_EQUAL_HIGH: return "EH";
      case RBT_SWING_EQUAL_LOW:  return "EL";
   }
   return "--";
}

string RBT_PivotKindToString(const int kind)
{
   if(kind == RBT_PIVOT_HIGH) return "HIGH";
   if(kind == RBT_PIVOT_LOW) return "LOW";
   return "NONE";
}

string RBT_ExecutionModeToString(const ERBTExecutionMode mode)
{
   if(mode == RBT_MODE_TRADE) return "TRADE";
   if(mode == RBT_MODE_DATASET_EXPORT) return "DATASET_EXPORT";
   return "DIAGNOSTIC";
}

bool RBT_SymbolLooksLikeEURUSD(const string symbol)
{
   return (StringFind(symbol, "EURUSD") >= 0);
}


double RBT_HistoricalSpreadPipsAt(const SMarketDataCache &market,
                                  const int shift,
                                  const double fallbackPips)
{
   const double safeFallback = MathMax(0.0, fallbackPips);
   if(!market.valid || shift < 0 || shift >= market.loadedBars)
      return safeFallback;

   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double pip = RBT_PipSize();
   if(point <= 0.0 || pip <= 0.0)
      return safeFallback;

   const double historicalPips = (double)market.rates[shift].spread * point / pip;
   if(RBT_IsFinite(historicalPips) && historicalPips > 0.0)
      return historicalPips;

   return safeFallback;
}

double RBT_HistoricalSpreadPriceAt(const SMarketDataCache &market,
                                   const int shift,
                                   const double fallbackPips)
{
   return RBT_HistoricalSpreadPipsAt(market, shift, fallbackPips) * RBT_PipSize();
}

#endif
