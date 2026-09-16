#ifndef __RBT_V2_SWINGS_MQH__
#define __RBT_V2_SWINGS_MQH__

void RBT_SwingPointReset(SSwingPoint &point)
{
   point.time = 0;
   point.shift = -1;
   point.kind = RBT_PIVOT_NONE;
   point.classification = RBT_SWING_NONE;
   point.price = 0.0;
   point.atr = 0.0;
   point.prominenceATR = 0.0;
}

void RBT_SwingSeriesReset(SSwingSeries &series)
{
   ArrayFree(series.points);
   series.count = 0;
   series.pivotBars = 0;
   series.minSwingATR = 0.0;
   series.equalToleranceATR = 0.0;
   series.valid = false;
   series.error = "";
}

double RBT_LocalATRAt(const SMarketDataCache &market,
                      const int shift,
                      const int period = 14)
{
   if(!market.valid || period < 2 || shift < 1 || shift + period >= market.loadedBars)
      return 0.0;

   double sum = 0.0;
   for(int i = shift; i < shift + period; ++i)
      sum += RBT_TrueRangeAt(market, i);

   return sum / period;
}

bool RBT_IsConfirmedPivotHigh(const SMarketDataCache &market,
                              const int shift,
                              const int pivotBars)
{
   if(!market.valid || pivotBars < 1)
      return false;
   if(shift - pivotBars < 1 || shift + pivotBars >= market.loadedBars)
      return false;

   const double candidate = market.rates[shift].high;
   for(int i = 1; i <= pivotBars; ++i)
   {
      if(candidate <= market.rates[shift - i].high)
         return false;
      if(candidate < market.rates[shift + i].high)
         return false;
   }
   return true;
}

bool RBT_IsConfirmedPivotLow(const SMarketDataCache &market,
                             const int shift,
                             const int pivotBars)
{
   if(!market.valid || pivotBars < 1)
      return false;
   if(shift - pivotBars < 1 || shift + pivotBars >= market.loadedBars)
      return false;

   const double candidate = market.rates[shift].low;
   for(int i = 1; i <= pivotBars; ++i)
   {
      if(candidate >= market.rates[shift - i].low)
         return false;
      if(candidate > market.rates[shift + i].low)
         return false;
   }
   return true;
}

double RBT_PivotProminenceATR(const SMarketDataCache &market,
                              const int shift,
                              const int pivotBars,
                              const int kind,
                              const double atr)
{
   if(atr <= 0.0)
      return 0.0;

   if(kind == RBT_PIVOT_HIGH)
   {
      double neighbourHigh = -1.0e100;
      for(int i = 1; i <= pivotBars; ++i)
      {
         neighbourHigh = MathMax(neighbourHigh, market.rates[shift - i].high);
         neighbourHigh = MathMax(neighbourHigh, market.rates[shift + i].high);
      }
      return RBT_SafeDiv(market.rates[shift].high - neighbourHigh, atr, 0.0);
   }

   if(kind == RBT_PIVOT_LOW)
   {
      double neighbourLow = 1.0e100;
      for(int i = 1; i <= pivotBars; ++i)
      {
         neighbourLow = MathMin(neighbourLow, market.rates[shift - i].low);
         neighbourLow = MathMin(neighbourLow, market.rates[shift + i].low);
      }
      return RBT_SafeDiv(neighbourLow - market.rates[shift].low, atr, 0.0);
   }

   return 0.0;
}

bool RBT_SwingSeriesAppend(SSwingSeries &series, const SSwingPoint &point)
{
   const int newSize = series.count + 1;
   if(ArrayResize(series.points, newSize) != newSize)
   {
      series.error = "Cannot resize swing-series array.";
      return false;
   }

   series.points[series.count] = point;
   series.count = newSize;
   return true;
}

bool RBT_IsMoreExtremeSameKind(const SSwingPoint &candidate,
                               const SSwingPoint &existing)
{
   if(candidate.kind != existing.kind)
      return false;

   if(candidate.kind == RBT_PIVOT_HIGH)
      return candidate.price > existing.price;

   if(candidate.kind == RBT_PIVOT_LOW)
      return candidate.price < existing.price;

   return false;
}

void RBT_ClassifySwingSeries(SSwingSeries &series)
{
   double previousHigh = 0.0;
   double previousLow = 0.0;
   double previousHighATR = 0.0;
   double previousLowATR = 0.0;
   bool haveHigh = false;
   bool haveLow = false;

   for(int i = 0; i < series.count; ++i)
   {
      series.points[i].classification = RBT_SWING_NONE;
      const double currentATR = MathMax(series.points[i].atr, 1e-12);

      if(series.points[i].kind == RBT_PIVOT_HIGH)
      {
         if(haveHigh)
         {
            const double tolerance = series.equalToleranceATR * MathMax(currentATR, previousHighATR);
            if(series.points[i].price > previousHigh + tolerance)
               series.points[i].classification = RBT_SWING_HH;
            else if(series.points[i].price < previousHigh - tolerance)
               series.points[i].classification = RBT_SWING_LH;
            else
               series.points[i].classification = RBT_SWING_EQUAL_HIGH;
         }

         previousHigh = series.points[i].price;
         previousHighATR = currentATR;
         haveHigh = true;
      }
      else if(series.points[i].kind == RBT_PIVOT_LOW)
      {
         if(haveLow)
         {
            const double tolerance = series.equalToleranceATR * MathMax(currentATR, previousLowATR);
            if(series.points[i].price > previousLow + tolerance)
               series.points[i].classification = RBT_SWING_HL;
            else if(series.points[i].price < previousLow - tolerance)
               series.points[i].classification = RBT_SWING_LL;
            else
               series.points[i].classification = RBT_SWING_EQUAL_LOW;
         }

         previousLow = series.points[i].price;
         previousLowATR = currentATR;
         haveLow = true;
      }
   }
}

bool RBT_BuildSwingSeries(const SMarketDataCache &market,
                          const int pivotBars,
                          const double minSwingATR,
                          const double equalToleranceATR,
                          SSwingSeries &series)
{
   RBT_SwingSeriesReset(series);
   series.pivotBars = pivotBars;
   series.minSwingATR = minSwingATR;
   series.equalToleranceATR = equalToleranceATR;

   if(!market.valid)
   {
      series.error = "Market cache is invalid.";
      return false;
   }

   if(pivotBars < 1 || minSwingATR <= 0.0 || equalToleranceATR < 0.0)
   {
      series.error = "Invalid swing parameters.";
      return false;
   }

   const int newestConfirmedShift = pivotBars + 1;
   const int oldestCandidateShift = market.loadedBars - pivotBars - 16;
   if(oldestCandidateShift <= newestConfirmedShift)
   {
      series.error = "Not enough bars to build swing series.";
      return false;
   }

   for(int shift = oldestCandidateShift; shift >= newestConfirmedShift; --shift)
   {
      const bool isHigh = RBT_IsConfirmedPivotHigh(market, shift, pivotBars);
      const bool isLow = RBT_IsConfirmedPivotLow(market, shift, pivotBars);
      if(!isHigh && !isLow)
         continue;

      const double atr = RBT_LocalATRAt(market, shift, 14);
      if(atr <= 0.0)
         continue;

      int chosenKind = RBT_PIVOT_NONE;
      double chosenProminence = 0.0;

      if(isHigh && isLow)
      {
         const double highProminence = RBT_PivotProminenceATR(market, shift, pivotBars, RBT_PIVOT_HIGH, atr);
         const double lowProminence = RBT_PivotProminenceATR(market, shift, pivotBars, RBT_PIVOT_LOW, atr);
         if(highProminence >= lowProminence)
         {
            chosenKind = RBT_PIVOT_HIGH;
            chosenProminence = highProminence;
         }
         else
         {
            chosenKind = RBT_PIVOT_LOW;
            chosenProminence = lowProminence;
         }
      }
      else if(isHigh)
      {
         chosenKind = RBT_PIVOT_HIGH;
         chosenProminence = RBT_PivotProminenceATR(market, shift, pivotBars, chosenKind, atr);
      }
      else
      {
         chosenKind = RBT_PIVOT_LOW;
         chosenProminence = RBT_PivotProminenceATR(market, shift, pivotBars, chosenKind, atr);
      }

      SSwingPoint candidate;
      RBT_SwingPointReset(candidate);
      candidate.time = market.rates[shift].time;
      candidate.shift = shift;
      candidate.kind = chosenKind;
      candidate.price = (chosenKind == RBT_PIVOT_HIGH) ? market.rates[shift].high : market.rates[shift].low;
      candidate.atr = atr;
      candidate.prominenceATR = chosenProminence;

      if(series.count == 0)
      {
         if(!RBT_SwingSeriesAppend(series, candidate))
            return false;
         continue;
      }

      const int lastIndex = series.count - 1;
      const SSwingPoint lastPoint = series.points[lastIndex];

      if(candidate.kind == lastPoint.kind)
      {
         if(RBT_IsMoreExtremeSameKind(candidate, lastPoint))
            series.points[lastIndex] = candidate;
         continue;
      }

      const double thresholdATR = MathMax(candidate.atr, lastPoint.atr);
      const double amplitude = MathAbs(candidate.price - lastPoint.price);
      if(amplitude < minSwingATR * thresholdATR)
         continue;

      if(!RBT_SwingSeriesAppend(series, candidate))
         return false;
   }

   if(series.count < 4)
   {
      series.error = StringFormat("Only %d swing points passed filtering.", series.count);
      return false;
   }

   RBT_ClassifySwingSeries(series);
   series.valid = true;
   return true;
}

#endif
