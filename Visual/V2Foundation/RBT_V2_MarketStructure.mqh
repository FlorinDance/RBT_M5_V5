#ifndef __RBT_V2_MARKET_STRUCTURE_MQH__
#define __RBT_V2_MARKET_STRUCTURE_MQH__

void RBT_StructureLayerReset(SStructureLayerSnapshot &layer)
{
   layer.direction = RBT_STRUCTURE_NEUTRAL;
   layer.lastSwingType = RBT_SWING_NONE;
   layer.lastHigh = 0.0;
   layer.lastLow = 0.0;
   layer.lastHighTime = 0;
   layer.lastLowTime = 0;
   layer.lastHighShift = -1;
   layer.lastLowShift = -1;
   layer.bullishCount = 0;
   layer.bearishCount = 0;
   layer.barsSinceHigh = -1;
   layer.barsSinceLow = -1;
   layer.bullishBOS = false;
   layer.bearishBOS = false;
   layer.bullishCHOCH = false;
   layer.bearishCHOCH = false;
   layer.barsSinceBullishBOS = RBT_EVENT_NOT_FOUND_BARS;
   layer.barsSinceBearishBOS = RBT_EVENT_NOT_FOUND_BARS;
   layer.barsSinceBullishCHOCH = RBT_EVENT_NOT_FOUND_BARS;
   layer.barsSinceBearishCHOCH = RBT_EVENT_NOT_FOUND_BARS;
   layer.lastBOSStrengthATR = 0.0;
   layer.lastBOSBodyStrength = 0.0;
   layer.lastCHOCHStrengthATR = 0.0;
   layer.breakStrengthATR = 0.0;
   layer.breakBodyStrength = 0.0;
   layer.valid = false;
   layer.error = "";
}

void RBT_StructureSnapshotReset(SStructureSnapshot &snapshot)
{
   RBT_StructureLayerReset(snapshot.internalLayer);
   RBT_StructureLayerReset(snapshot.externalLayer);
   snapshot.alignment = RBT_STRUCTURE_NEUTRAL;
   snapshot.pullbackDepth = 0.0;
   snapshot.pullbackBars = 0;
   snapshot.pullbackVelocity = 0.0;
   snapshot.rangePosition = 0.5;
   snapshot.impulseSizeATR = 0.0;
   snapshot.impulseBars = 0;
   snapshot.impulseVelocity = 0.0;
   snapshot.impulseEfficiency = 0.0;
   snapshot.valid = false;
   snapshot.error = "";
}

int RBT_FindLatestSwingIndexByKind(const SSwingSeries &series, const int kind)
{
   for(int i = series.count - 1; i >= 0; --i)
   {
      if(series.points[i].kind == kind)
         return i;
   }
   return -1;
}

int RBT_FindPreviousSwingIndexByKind(const SSwingSeries &series,
                                     const int startIndex,
                                     const int kind)
{
   for(int i = startIndex - 1; i >= 0; --i)
   {
      if(series.points[i].kind == kind)
         return i;
   }
   return -1;
}

int RBT_DetectStructureDirection(const SSwingSeries &series,
                                 const int latestHighIndex,
                                 const int latestLowIndex)
{
   if(latestHighIndex < 0 || latestLowIndex < 0)
      return RBT_STRUCTURE_NEUTRAL;

   const int highType = series.points[latestHighIndex].classification;
   const int lowType = series.points[latestLowIndex].classification;

   if(highType == RBT_SWING_HH && lowType == RBT_SWING_HL)
      return RBT_STRUCTURE_BULLISH;

   if(highType == RBT_SWING_LH && lowType == RBT_SWING_LL)
      return RBT_STRUCTURE_BEARISH;

   int bullishScore = 0;
   int bearishScore = 0;
   int inspected = 0;
   for(int i = series.count - 1; i >= 0 && inspected < 6; --i)
   {
      const int type = series.points[i].classification;
      if(type == RBT_SWING_HH || type == RBT_SWING_HL)
         bullishScore++;
      else if(type == RBT_SWING_LH || type == RBT_SWING_LL)
         bearishScore++;

      if(type != RBT_SWING_NONE)
         inspected++;
   }

   if(bullishScore >= bearishScore + 2)
      return RBT_STRUCTURE_BULLISH;
   if(bearishScore >= bullishScore + 2)
      return RBT_STRUCTURE_BEARISH;

   return RBT_STRUCTURE_NEUTRAL;
}

void RBT_CountRecentStructureEvidence(const SSwingSeries &series,
                                      int &bullishCount,
                                      int &bearishCount)
{
   bullishCount = 0;
   bearishCount = 0;

   for(int i = series.count - 1; i >= 0; --i)
   {
      const int type = series.points[i].classification;
      if(type == RBT_SWING_NONE || type == RBT_SWING_EQUAL_HIGH || type == RBT_SWING_EQUAL_LOW)
         continue;

      if(type == RBT_SWING_HH || type == RBT_SWING_HL)
      {
         if(bearishCount > 0)
            break;
         bullishCount++;
      }
      else if(type == RBT_SWING_LH || type == RBT_SWING_LL)
      {
         if(bullishCount > 0)
            break;
         bearishCount++;
      }
   }
}

double RBT_BodyStrengthAt(const SMarketDataCache &market, const int shift)
{
   if(!market.valid || shift < 0 || shift >= market.loadedBars)
      return 0.0;

   const double range = market.rates[shift].high - market.rates[shift].low;
   return RBT_SafeDiv(MathAbs(market.rates[shift].close - market.rates[shift].open), range, 0.0);
}

void RBT_UpdateStructureEvent(const bool bullish,
                              const bool choch,
                              const int barsSince,
                              const double strengthATR,
                              const double bodyStrength,
                              SStructureLayerSnapshot &layer,
                              int &latestBOSBars,
                              int &latestCHOCHBars)
{
   if(choch)
   {
      if(bullish)
         layer.barsSinceBullishCHOCH = MathMin(layer.barsSinceBullishCHOCH, barsSince);
      else
         layer.barsSinceBearishCHOCH = MathMin(layer.barsSinceBearishCHOCH, barsSince);

      if(barsSince < latestCHOCHBars)
      {
         latestCHOCHBars = barsSince;
         layer.lastCHOCHStrengthATR = strengthATR;
      }
   }
   else
   {
      if(bullish)
         layer.barsSinceBullishBOS = MathMin(layer.barsSinceBullishBOS, barsSince);
      else
         layer.barsSinceBearishBOS = MathMin(layer.barsSinceBearishBOS, barsSince);

      if(barsSince < latestBOSBars)
      {
         latestBOSBars = barsSince;
         layer.lastBOSStrengthATR = strengthATR;
         layer.lastBOSBodyStrength = bodyStrength;
      }
   }

   if(barsSince == 0)
   {
      if(choch)
      {
         if(bullish) layer.bullishCHOCH = true;
         else        layer.bearishCHOCH = true;
      }
      else
      {
         if(bullish) layer.bullishBOS = true;
         else        layer.bearishBOS = true;
      }

      if(strengthATR >= layer.breakStrengthATR)
      {
         layer.breakStrengthATR = strengthATR;
         layer.breakBodyStrength = bodyStrength;
      }
   }
}

void RBT_ScanStructureEvents(const SMarketDataCache &market,
                             const SSwingSeries &series,
                             const double breakConfirmATR,
                             SStructureLayerSnapshot &layer)
{
   int latestBOSBars = RBT_EVENT_NOT_FOUND_BARS;
   int latestCHOCHBars = RBT_EVENT_NOT_FOUND_BARS;

   const int firstIndex = MathMax(0, series.count - 40);
   for(int i = firstIndex; i < series.count; ++i)
   {
      const SSwingPoint point = series.points[i];
      if(point.classification == RBT_SWING_NONE)
         continue;

      bool bullish = false;
      bool choch = false;
      bool supportedType = true;

      if(point.kind == RBT_PIVOT_HIGH)
      {
         bullish = true;
         if(point.classification == RBT_SWING_LH)
            choch = true;
         else if(point.classification == RBT_SWING_HH || point.classification == RBT_SWING_EQUAL_HIGH)
            choch = false;
         else
            supportedType = false;
      }
      else if(point.kind == RBT_PIVOT_LOW)
      {
         bullish = false;
         if(point.classification == RBT_SWING_HL)
            choch = true;
         else if(point.classification == RBT_SWING_LL || point.classification == RBT_SWING_EQUAL_LOW)
            choch = false;
         else
            supportedType = false;
      }
      else
      {
         supportedType = false;
      }

      if(!supportedType)
         continue;

      // A pivot is usable only after pivotBars newer bars have closed.
      const int confirmationShift = point.shift - series.pivotBars;
      if(confirmationShift < 1)
         continue;

      for(int shift = confirmationShift; shift >= 1; --shift)
      {
         if(shift + 1 >= market.loadedBars)
            continue;

         const double localATR = RBT_LocalATRAt(market, shift, 14);
         if(localATR <= 0.0)
            continue;

         const double closeNow = market.rates[shift].close;
         const double closePrevious = market.rates[shift + 1].close;
         bool crossed = false;
         double strengthATR = 0.0;

         if(bullish)
         {
            const double threshold = point.price + breakConfirmATR * localATR;
            crossed = (closeNow > threshold && closePrevious <= threshold);
            strengthATR = RBT_SafeDiv(closeNow - point.price, localATR, 0.0);
         }
         else
         {
            const double threshold = point.price - breakConfirmATR * localATR;
            crossed = (closeNow < threshold && closePrevious >= threshold);
            strengthATR = RBT_SafeDiv(point.price - closeNow, localATR, 0.0);
         }

         if(!crossed)
            continue;

         const int barsSince = MathMax(0, shift - 1);
         RBT_UpdateStructureEvent(bullish,
                                  choch,
                                  barsSince,
                                  strengthATR,
                                  RBT_BodyStrengthAt(market, shift),
                                  layer,
                                  latestBOSBars,
                                  latestCHOCHBars);
         break;
      }
   }
}

bool RBT_BuildStructureLayer(const SMarketDataCache &market,
                             const SIndicatorSnapshot &indicators,
                             const SSwingSeries &series,
                             const double breakConfirmATR,
                             SStructureLayerSnapshot &layer)
{
   RBT_StructureLayerReset(layer);

   if(!market.valid || !indicators.valid || !series.valid)
   {
      layer.error = "Invalid market, indicators or swing series.";
      return false;
   }

   const int latestHighIndex = RBT_FindLatestSwingIndexByKind(series, RBT_PIVOT_HIGH);
   const int latestLowIndex = RBT_FindLatestSwingIndexByKind(series, RBT_PIVOT_LOW);
   if(latestHighIndex < 0 || latestLowIndex < 0)
   {
      layer.error = "Cannot locate latest high and low.";
      return false;
   }

   const SSwingPoint latestHigh = series.points[latestHighIndex];
   const SSwingPoint latestLow = series.points[latestLowIndex];
   const SSwingPoint latestPoint = series.points[series.count - 1];

   layer.lastHigh = latestHigh.price;
   layer.lastLow = latestLow.price;
   layer.lastHighTime = latestHigh.time;
   layer.lastLowTime = latestLow.time;
   layer.lastHighShift = latestHigh.shift;
   layer.lastLowShift = latestLow.shift;
   layer.barsSinceHigh = MathMax(0, latestHigh.shift - 1);
   layer.barsSinceLow = MathMax(0, latestLow.shift - 1);
   layer.lastSwingType = latestPoint.classification;
   layer.direction = RBT_DetectStructureDirection(series, latestHighIndex, latestLowIndex);
   RBT_CountRecentStructureEvidence(series, layer.bullishCount, layer.bearishCount);
   RBT_ScanStructureEvents(market, series, breakConfirmATR, layer);

   layer.valid = true;
   return true;
}

double RBT_PathEfficiencyBetweenShifts(const SMarketDataCache &market,
                                       const int olderShift,
                                       const int newerShift)
{
   if(!market.valid || olderShift <= newerShift || newerShift < 1 || olderShift >= market.loadedBars)
      return 0.0;

   const double netMovement = MathAbs(market.rates[newerShift].close - market.rates[olderShift].close);
   double totalMovement = 0.0;
   for(int shift = olderShift - 1; shift >= newerShift; --shift)
      totalMovement += MathAbs(market.rates[shift].close - market.rates[shift + 1].close);

   return RBT_SafeDiv(netMovement, totalMovement, 0.0);
}

bool RBT_CalculateExternalLegMetrics(const SMarketDataCache &market,
                                     const SIndicatorSnapshot &indicators,
                                     const SSwingSeries &externalSeries,
                                     const SStructureLayerSnapshot &externalLayer,
                                     SStructureSnapshot &snapshot)
{
   const int highIndex = RBT_FindLatestSwingIndexByKind(externalSeries, RBT_PIVOT_HIGH);
   const int lowIndex = RBT_FindLatestSwingIndexByKind(externalSeries, RBT_PIVOT_LOW);
   if(highIndex < 0 || lowIndex < 0)
      return false;

   const double currentClose = market.rates[1].close;
   const double currentATR = indicators.atr;
   const double rangeUpper = MathMax(externalLayer.lastHigh, externalLayer.lastLow);
   const double rangeLower = MathMin(externalLayer.lastHigh, externalLayer.lastLow);
   const double structuralRange = rangeUpper - rangeLower;
   snapshot.rangePosition = RBT_Clamp(RBT_SafeDiv(currentClose - rangeLower,
                                                  structuralRange,
                                                  0.5),
                                      -1.0,
                                      2.0);

   int impulseStartIndex = -1;
   int impulseEndIndex = -1;

   if(externalLayer.direction == RBT_STRUCTURE_BULLISH)
   {
      impulseEndIndex = highIndex;
      impulseStartIndex = RBT_FindPreviousSwingIndexByKind(externalSeries,
                                                            impulseEndIndex,
                                                            RBT_PIVOT_LOW);
      if(impulseStartIndex < 0)
         return true;

      const SSwingPoint startPoint = externalSeries.points[impulseStartIndex];
      const SSwingPoint endPoint = externalSeries.points[impulseEndIndex];
      const double impulsePrice = endPoint.price - startPoint.price;
      if(impulsePrice <= 0.0)
         return true;

      snapshot.impulseSizeATR = RBT_SafeDiv(impulsePrice, currentATR, 0.0);
      snapshot.impulseBars = MathMax(1, startPoint.shift - endPoint.shift);
      snapshot.impulseVelocity = RBT_SafeDiv(snapshot.impulseSizeATR, snapshot.impulseBars, 0.0);
      snapshot.impulseEfficiency = RBT_PathEfficiencyBetweenShifts(market,
                                                                   startPoint.shift,
                                                                   endPoint.shift);
      snapshot.pullbackDepth = RBT_SafeDiv(endPoint.price - currentClose, impulsePrice, 0.0);
      snapshot.pullbackBars = MathMax(0, endPoint.shift - 1);
      snapshot.pullbackVelocity = RBT_SafeDiv(RBT_SafeDiv(endPoint.price - currentClose,
                                                          currentATR,
                                                          0.0),
                                              MathMax(1, snapshot.pullbackBars),
                                              0.0);
   }
   else if(externalLayer.direction == RBT_STRUCTURE_BEARISH)
   {
      impulseEndIndex = lowIndex;
      impulseStartIndex = RBT_FindPreviousSwingIndexByKind(externalSeries,
                                                            impulseEndIndex,
                                                            RBT_PIVOT_HIGH);
      if(impulseStartIndex < 0)
         return true;

      const SSwingPoint startPoint = externalSeries.points[impulseStartIndex];
      const SSwingPoint endPoint = externalSeries.points[impulseEndIndex];
      const double impulsePrice = startPoint.price - endPoint.price;
      if(impulsePrice <= 0.0)
         return true;

      snapshot.impulseSizeATR = RBT_SafeDiv(impulsePrice, currentATR, 0.0);
      snapshot.impulseBars = MathMax(1, startPoint.shift - endPoint.shift);
      snapshot.impulseVelocity = RBT_SafeDiv(snapshot.impulseSizeATR, snapshot.impulseBars, 0.0);
      snapshot.impulseEfficiency = RBT_PathEfficiencyBetweenShifts(market,
                                                                   startPoint.shift,
                                                                   endPoint.shift);
      snapshot.pullbackDepth = RBT_SafeDiv(currentClose - endPoint.price, impulsePrice, 0.0);
      snapshot.pullbackBars = MathMax(0, endPoint.shift - 1);
      snapshot.pullbackVelocity = RBT_SafeDiv(RBT_SafeDiv(currentClose - endPoint.price,
                                                          currentATR,
                                                          0.0),
                                              MathMax(1, snapshot.pullbackBars),
                                              0.0);
   }

   return true;
}

bool RBT_EvaluateMarketStructure(const SMarketDataCache &market,
                                 const SIndicatorSnapshot &indicators,
                                 const SSwingSeries &internalSeries,
                                 const SSwingSeries &externalSeries,
                                 const double breakConfirmATR,
                                 SStructureSnapshot &snapshot)
{
   RBT_StructureSnapshotReset(snapshot);

   if(!RBT_BuildStructureLayer(market,
                               indicators,
                               internalSeries,
                               breakConfirmATR,
                               snapshot.internalLayer))
   {
      snapshot.error = "Internal structure: " + snapshot.internalLayer.error;
      return false;
   }

   if(!RBT_BuildStructureLayer(market,
                               indicators,
                               externalSeries,
                               breakConfirmATR,
                               snapshot.externalLayer))
   {
      snapshot.error = "External structure: " + snapshot.externalLayer.error;
      return false;
   }

   if(snapshot.internalLayer.direction == snapshot.externalLayer.direction &&
      snapshot.externalLayer.direction != RBT_STRUCTURE_NEUTRAL)
   {
      snapshot.alignment = snapshot.externalLayer.direction;
   }
   else
   {
      snapshot.alignment = RBT_STRUCTURE_NEUTRAL;
   }

   RBT_CalculateExternalLegMetrics(market,
                                   indicators,
                                   externalSeries,
                                   snapshot.externalLayer,
                                   snapshot);

   snapshot.valid = true;
   return true;
}

#endif
