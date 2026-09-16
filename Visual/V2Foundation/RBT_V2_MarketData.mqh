#ifndef __RBT_V2_MARKET_DATA_MQH__
#define __RBT_V2_MARKET_DATA_MQH__

void RBT_MarketDataReset(SMarketDataCache &cache)
{
   ArrayFree(cache.rates);
   cache.requestedBars = 0;
   cache.loadedBars = 0;
   cache.refreshedAt = 0;
   cache.valid = false;
   cache.error = "";
}

bool RBT_MarketDataInitialize(SMarketDataCache &cache, const int requestedBars)
{
   RBT_MarketDataReset(cache);
   cache.requestedBars = MathMax(requestedBars, RBT_MIN_HISTORY_BARS);
   return true;
}

bool RBT_MarketDataRefresh(SMarketDataCache &cache)
{
   cache.valid = false;
   cache.error = "";

   ArraySetAsSeries(cache.rates, true);
   ResetLastError();
   const int copied = CopyRates(_Symbol,
                                RBT_SIGNAL_TIMEFRAME,
                                0,
                                cache.requestedBars,
                                cache.rates);
   if(copied < RBT_MIN_HISTORY_BARS)
   {
      cache.loadedBars = MathMax(copied, 0);
      cache.error = StringFormat("CopyRates returned %d bars; minimum required is %d. MT5 error=%d",
                                 copied,
                                 RBT_MIN_HISTORY_BARS,
                                 GetLastError());
      return false;
   }

   cache.loadedBars = copied;
   cache.refreshedAt = TimeCurrent();
   cache.valid = true;
   return true;
}

bool RBT_GetRate(const SMarketDataCache &cache, const int shift, MqlRates &bar)
{
   if(!cache.valid || shift < 0 || shift >= cache.loadedBars)
      return false;
   bar = cache.rates[shift];
   return true;
}

double RBT_TrueRangeAt(const SMarketDataCache &cache, const int shift)
{
   if(!cache.valid || shift < 0 || shift + 1 >= cache.loadedBars)
      return 0.0;

   const double high = cache.rates[shift].high;
   const double low = cache.rates[shift].low;
   const double previousClose = cache.rates[shift + 1].close;

   const double range1 = high - low;
   const double range2 = MathAbs(high - previousClose);
   const double range3 = MathAbs(low - previousClose);
   return MathMax(range1, MathMax(range2, range3));
}

double RBT_ReturnPrice(const SMarketDataCache &cache, const int startShift, const int barsBack)
{
   const int olderShift = startShift + barsBack;
   if(!cache.valid || startShift < 0 || olderShift >= cache.loadedBars)
      return 0.0;
   return cache.rates[startShift].close - cache.rates[olderShift].close;
}

bool RBT_VolumeStatistics(const SMarketDataCache &cache,
                          const int shift,
                          const int period,
                          double &ratio,
                          double &zscore)
{
   ratio = 0.0;
   zscore = 0.0;

   if(!cache.valid || period < 2 || shift + period >= cache.loadedBars)
      return false;

   double sum = 0.0;
   double sumSquares = 0.0;
   for(int i = shift + 1; i <= shift + period; ++i)
   {
      const double value = (double)cache.rates[i].tick_volume;
      sum += value;
      sumSquares += value * value;
   }

   const double mean = sum / period;
   const double variance = MathMax(0.0, sumSquares / period - mean * mean);
   const double standardDeviation = MathSqrt(variance);
   const double current = (double)cache.rates[shift].tick_volume;

   ratio = RBT_SafeDiv(current, mean, 0.0);
   zscore = RBT_SafeDiv(current - mean, standardDeviation, 0.0);
   return true;
}

#endif
