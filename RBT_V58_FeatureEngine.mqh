//+------------------------------------------------------------------+
//| RBT_V58_FeatureEngine.mqh                                        |
//| Causal EURUSD M1/M5 feature reconstruction for frozen V5.8.      |
//+------------------------------------------------------------------+
#ifndef RBT_V58_FEATURE_ENGINE_MQH
#define RBT_V58_FEATURE_ENGINE_MQH

#define RBTV58_M1_CAPACITY 1600
#define RBTV58_M5_CAPACITY 2048
#define RBTV58_M5_SEED_BARS 20000

struct SRBTV58Accumulator
{
   bool     active;
   bool     completeFromStart;
   datetime barTime;
   double   openBid;
   double   highBid;
   double   lowBid;
   double   closeBid;
   double   previousBid;
   long     observedTicks;
   long     upTicks;
   long     downTicks;
   long     flatTicks;
   double   pathPrice;
   double   spreadSumPips;
};

struct SRBTV58M1Bar
{
   datetime time;
   double   close;
   double   bodyPips;
   double   rangePips;
   double   pathPips;
   double   imbalance;
   double   logTicks;
   double   spreadPips;
   double   efficiency;
   bool     microValid;
};

struct SRBTV58M5Bar
{
   datetime time;
   double   open;
   double   high;
   double   low;
   double   close;
   double   trueRange;
   double   atr;
   double   imbalance;
   double   efficiency;
   double   logTicks;
   double   spreadPips;
   bool     microValid;
};

double RBTV58_Clip20(const double value)
{
   return MathMax(-20.0, MathMin(20.0, value));
}

double RBTV58_Quantize(const double value, const int digits)
{
   // The frozen model was trained from the V5.4 CSV.  Recreate the exact
   // DoubleToString -> CSV -> double boundary used by that collector.
   return StringToDouble(DoubleToString(value, digits));
}

class CRBTV58FeatureEngine
{
private:
   string m_symbol;
   double m_point;
   double m_pip;
   SRBTV58Accumulator m_m1Accumulator;
   SRBTV58Accumulator m_m5Accumulator;
   SRBTV58M1Bar m_m1Bars[];
   SRBTV58M5Bar m_m5Bars[];
   int m_m1Head;
   int m_m1Count;
   int m_m5Head;
   int m_m5Count;
   long m_lastTickMsc;
   long m_outOfOrderTicks;
   int m_completedM5SinceStart;
   datetime m_lastAnchorTime;
   double m_atrState;
   bool m_atrSeeded;

   datetime AlignedTime(const datetime tickTime, const int seconds) const
   {
      return (datetime)(((long)tickTime / seconds) * seconds);
   }

   void ResetAccumulator(SRBTV58Accumulator &bar)
   {
      bar.active = false;
      bar.completeFromStart = false;
      bar.barTime = 0;
      bar.openBid = 0.0;
      bar.highBid = 0.0;
      bar.lowBid = 0.0;
      bar.closeBid = 0.0;
      bar.previousBid = 0.0;
      bar.observedTicks = 0;
      bar.upTicks = 0;
      bar.downTicks = 0;
      bar.flatTicks = 0;
      bar.pathPrice = 0.0;
      bar.spreadSumPips = 0.0;
   }

   void StartAccumulator(SRBTV58Accumulator &bar, const datetime barTime,
                         const MqlTick &tick, const double spreadPips,
                         const bool completeFromStart)
   {
      ResetAccumulator(bar);
      bar.active = true;
      bar.completeFromStart = completeFromStart;
      bar.barTime = barTime;
      bar.openBid = tick.bid;
      bar.highBid = tick.bid;
      bar.lowBid = tick.bid;
      bar.closeBid = tick.bid;
      bar.previousBid = tick.bid;
      bar.observedTicks = 1;
      bar.flatTicks = 1;
      bar.spreadSumPips = spreadPips;
   }

   void UpdateAccumulator(SRBTV58Accumulator &bar, const MqlTick &tick,
                          const double spreadPips)
   {
      const double delta = tick.bid - bar.previousBid;
      bar.pathPrice += MathAbs(delta);
      if(delta > m_point * 0.1)
         bar.upTicks++;
      else if(delta < -m_point * 0.1)
         bar.downTicks++;
      else
         bar.flatTicks++;
      bar.highBid = MathMax(bar.highBid, tick.bid);
      bar.lowBid = MathMin(bar.lowBid, tick.bid);
      bar.closeBid = tick.bid;
      bar.previousBid = tick.bid;
      bar.observedTicks++;
      bar.spreadSumPips += spreadPips;
   }

   int M1PhysicalIndex(const int ago) const
   {
      int index = (m_m1Head + m_m1Count - 1 - ago) % RBTV58_M1_CAPACITY;
      if(index < 0)
         index += RBTV58_M1_CAPACITY;
      return index;
   }

   int M5PhysicalIndex(const int ago) const
   {
      int index = (m_m5Head + m_m5Count - 1 - ago) % RBTV58_M5_CAPACITY;
      if(index < 0)
         index += RBTV58_M5_CAPACITY;
      return index;
   }

   bool GetM1(const int ago, SRBTV58M1Bar &bar) const
   {
      if(ago < 0 || ago >= m_m1Count)
         return false;
      bar = m_m1Bars[M1PhysicalIndex(ago)];
      return true;
   }

   bool GetM5(const int ago, SRBTV58M5Bar &bar) const
   {
      if(ago < 0 || ago >= m_m5Count)
         return false;
      bar = m_m5Bars[M5PhysicalIndex(ago)];
      return true;
   }

   void PushM1(const SRBTV58M1Bar &bar)
   {
      int index = 0;
      if(m_m1Count < RBTV58_M1_CAPACITY)
      {
         index = (m_m1Head + m_m1Count) % RBTV58_M1_CAPACITY;
         m_m1Count++;
      }
      else
      {
         index = m_m1Head;
         m_m1Head = (m_m1Head + 1) % RBTV58_M1_CAPACITY;
      }
      m_m1Bars[index] = bar;
   }

   void PushM5(const SRBTV58M5Bar &bar)
   {
      int index = 0;
      if(m_m5Count < RBTV58_M5_CAPACITY)
      {
         index = (m_m5Head + m_m5Count) % RBTV58_M5_CAPACITY;
         m_m5Count++;
      }
      else
      {
         index = m_m5Head;
         m_m5Head = (m_m5Head + 1) % RBTV58_M5_CAPACITY;
      }
      m_m5Bars[index] = bar;
   }

   bool LoadOfficialBar(const ENUM_TIMEFRAMES timeframe, const datetime barTime,
                        MqlRates &rate) const
   {
      MqlRates values[];
      ArrayResize(values, 1);
      ArraySetAsSeries(values, false);
      const int copied = CopyRates(m_symbol, timeframe, barTime, 1, values);
      if(copied != 1 || values[0].time != barTime)
         return false;
      rate = values[0];
      return true;
   }

   void SeedM1History(void)
   {
      MqlRates rates[];
      ArraySetAsSeries(rates, false);
      const int copied = CopyRates(m_symbol, PERIOD_M1, 1, RBTV58_M1_CAPACITY, rates);
      if(copied <= 0)
         return;
      for(int index = 0; index < copied; index++)
      {
         SRBTV58M1Bar bar;
         bar.time = rates[index].time;
         bar.close = rates[index].close;
         bar.bodyPips = 0.0;
         bar.rangePips = 0.0;
         bar.pathPips = 0.0;
         bar.imbalance = 0.0;
         bar.logTicks = MathLog(1.0 + (double)rates[index].tick_volume);
         bar.spreadPips = (double)rates[index].spread * m_point / m_pip;
         bar.efficiency = 0.0;
         bar.microValid = false;
         PushM1(bar);
      }
   }

   void SeedM5History(void)
   {
      MqlRates rates[];
      ArraySetAsSeries(rates, false);
      const int copied = CopyRates(m_symbol, PERIOD_M5, 1, RBTV58_M5_SEED_BARS, rates);
      if(copied <= 0)
         return;
      double previousClose = rates[0].close;
      for(int index = 0; index < copied; index++)
      {
         const double trueRange = (index == 0
            ? rates[index].high - rates[index].low
            : MathMax(rates[index].high - rates[index].low,
               MathMax(MathAbs(rates[index].high - previousClose),
                       MathAbs(rates[index].low - previousClose))));
         if(!m_atrSeeded)
         {
            m_atrState = trueRange;
            m_atrSeeded = true;
         }
         else
         {
            m_atrState = (trueRange / 14.0) + (13.0 / 14.0) * m_atrState;
         }
         SRBTV58M5Bar bar;
         bar.time = rates[index].time;
         bar.open = rates[index].open;
         bar.high = rates[index].high;
         bar.low = rates[index].low;
         bar.close = rates[index].close;
         bar.trueRange = trueRange;
         bar.atr = m_atrState;
         bar.imbalance = 0.0;
         bar.efficiency = 0.0;
         bar.logTicks = MathLog(1.0 + (double)rates[index].tick_volume);
         bar.spreadPips = (double)rates[index].spread * m_point / m_pip;
         bar.microValid = false;
         PushM5(bar);
         previousClose = rates[index].close;
      }
   }

   void FinalizeM1(void)
   {
      if(!m_m1Accumulator.active || !m_m1Accumulator.completeFromStart ||
         m_m1Accumulator.observedTicks <= 0)
         return;
      MqlRates official;
      ZeroMemory(official);
      const bool officialAvailable = LoadOfficialBar(
         PERIOD_M1, m_m1Accumulator.barTime, official);
      const double directional = (double)(m_m1Accumulator.upTicks
         + m_m1Accumulator.downTicks);
      SRBTV58M1Bar bar;
      bar.time = m_m1Accumulator.barTime;
      bar.close = (officialAvailable ? official.close : m_m1Accumulator.closeBid);
      bar.bodyPips = RBTV58_Quantize(
         (m_m1Accumulator.closeBid - m_m1Accumulator.openBid) / m_pip, 6);
      bar.rangePips = RBTV58_Quantize(
         (m_m1Accumulator.highBid - m_m1Accumulator.lowBid) / m_pip, 6);
      bar.pathPips = RBTV58_Quantize(m_m1Accumulator.pathPrice / m_pip, 6);
      bar.imbalance = RBTV58_Quantize((directional > 0.0
         ? (double)(m_m1Accumulator.upTicks - m_m1Accumulator.downTicks) / directional
         : 0.0), 8);
      bar.logTicks = MathLog(1.0 + (double)m_m1Accumulator.observedTicks);
      bar.spreadPips = RBTV58_Quantize(m_m1Accumulator.spreadSumPips
         / (double)m_m1Accumulator.observedTicks, 6);
      bar.efficiency = RBTV58_Quantize((m_m1Accumulator.pathPrice > 0.0
         ? MathAbs(m_m1Accumulator.closeBid - m_m1Accumulator.openBid)
            / m_m1Accumulator.pathPrice : 0.0), 8);
      bar.microValid = true;
      PushM1(bar);
   }

   void FinalizeM5(void)
   {
      if(!m_m5Accumulator.active || !m_m5Accumulator.completeFromStart ||
         m_m5Accumulator.observedTicks <= 0)
         return;
      MqlRates official;
      ZeroMemory(official);
      const bool officialAvailable = LoadOfficialBar(
         PERIOD_M5, m_m5Accumulator.barTime, official);
      const double outputOpen = (officialAvailable ? official.open : m_m5Accumulator.openBid);
      const double outputHigh = (officialAvailable ? official.high : m_m5Accumulator.highBid);
      const double outputLow = (officialAvailable ? official.low : m_m5Accumulator.lowBid);
      const double outputClose = (officialAvailable ? official.close : m_m5Accumulator.closeBid);
      SRBTV58M5Bar previous;
      const bool previousAvailable = GetM5(0, previous);
      const double trueRange = (previousAvailable
         ? MathMax(outputHigh - outputLow,
            MathMax(MathAbs(outputHigh - previous.close), MathAbs(outputLow - previous.close)))
         : outputHigh - outputLow);
      if(!m_atrSeeded)
      {
         m_atrState = trueRange;
         m_atrSeeded = true;
      }
      else
      {
         m_atrState = (trueRange / 14.0) + (13.0 / 14.0) * m_atrState;
      }
      const double directional = (double)(m_m5Accumulator.upTicks
         + m_m5Accumulator.downTicks);
      SRBTV58M5Bar bar;
      bar.time = m_m5Accumulator.barTime;
      bar.open = outputOpen;
      bar.high = outputHigh;
      bar.low = outputLow;
      bar.close = outputClose;
      bar.trueRange = trueRange;
      bar.atr = m_atrState;
      bar.imbalance = RBTV58_Quantize((directional > 0.0
         ? (double)(m_m5Accumulator.upTicks - m_m5Accumulator.downTicks) / directional
         : 0.0), 8);
      bar.efficiency = RBTV58_Quantize((m_m5Accumulator.pathPrice > 0.0
         ? MathAbs(m_m5Accumulator.closeBid - m_m5Accumulator.openBid)
            / m_m5Accumulator.pathPrice : 0.0), 8);
      bar.logTicks = MathLog(1.0 + (double)m_m5Accumulator.observedTicks);
      bar.spreadPips = RBTV58_Quantize(m_m5Accumulator.spreadSumPips
         / (double)m_m5Accumulator.observedTicks, 6);
      bar.microValid = true;
      PushM5(bar);
      m_completedM5SinceStart++;
      m_lastAnchorTime = m_m5Accumulator.barTime + 300;
   }

   bool AddM1Path(double &raw[], int &cursor, const int window,
                  const int &positions[], const int count, const double atr) const
   {
      SRBTV58M1Bar oldest;
      if(!GetM1(window - 1, oldest))
         return false;
      for(int index = 0; index < count; index++)
      {
         SRBTV58M1Bar sampled;
         const int ago = window - 1 - positions[index];
         if(!GetM1(ago, sampled))
            return false;
         raw[cursor++] = RBTV58_Clip20((sampled.close - oldest.close) / atr);
      }
      return true;
   }

   bool AddM5Path(double &raw[], int &cursor, const int window,
                  const int &positions[], const int count, const double atr) const
   {
      SRBTV58M5Bar oldest;
      if(!GetM5(window - 1, oldest))
         return false;
      for(int index = 0; index < count; index++)
      {
         SRBTV58M5Bar sampled;
         const int ago = window - 1 - positions[index];
         if(!GetM5(ago, sampled))
            return false;
         raw[cursor++] = RBTV58_Clip20((sampled.close - oldest.close) / atr);
      }
      return true;
   }

   double MicroValue(const SRBTV58M1Bar &bar, const int channel,
                     const double atrPips) const
   {
      if(channel == 0) return bar.bodyPips / atrPips;
      if(channel == 1) return bar.rangePips / atrPips;
      if(channel == 2) return bar.pathPips / atrPips;
      if(channel == 3) return bar.imbalance;
      if(channel == 4) return bar.logTicks;
      if(channel == 5) return bar.spreadPips / atrPips;
      return bar.efficiency;
   }

   bool HasCleanM1Window(string &reason) const
   {
      if(m_m1Count < 1440)
      {
         reason = "M1_HISTORY_LT_1440";
         return false;
      }
      for(int ago = 0; ago < 60; ago++)
      {
         SRBTV58M1Bar bar;
         if(!GetM1(ago, bar) || !bar.microValid)
         {
            reason = "M1_LIVE_MICRO_LT_60";
            return false;
         }
      }
      SRBTV58M1Bar newer, older;
      for(int ago = 0; ago < 1439; ago++)
      {
         if(!GetM1(ago, newer) || !GetM1(ago + 1, older) ||
            newer.time <= older.time || newer.time - older.time > 300)
         {
            reason = "M1_GAP_IN_1440";
            return false;
         }
      }
      return true;
   }

public:
   CRBTV58FeatureEngine(void)
   {
      m_symbol = "";
      m_point = 0.0;
      m_pip = 0.0;
      m_m1Head = 0;
      m_m1Count = 0;
      m_m5Head = 0;
      m_m5Count = 0;
      m_lastTickMsc = 0;
      m_outOfOrderTicks = 0;
      m_completedM5SinceStart = 0;
      m_lastAnchorTime = 0;
      m_atrState = 0.0;
      m_atrSeeded = false;
      ResetAccumulator(m_m1Accumulator);
      ResetAccumulator(m_m5Accumulator);
   }

   bool Initialize(const string symbol)
   {
      m_symbol = symbol;
      m_point = SymbolInfoDouble(symbol, SYMBOL_POINT);
      const int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      m_pip = ((digits == 3 || digits == 5) ? m_point * 10.0 : m_point);
      if(m_point <= 0.0 || m_pip <= 0.0)
         return false;
      if(ArrayResize(m_m1Bars, RBTV58_M1_CAPACITY) != RBTV58_M1_CAPACITY ||
         ArrayResize(m_m5Bars, RBTV58_M5_CAPACITY) != RBTV58_M5_CAPACITY)
         return false;
      SeedM1History();
      SeedM5History();
      return (m_m1Count >= 1440 && m_m5Count >= 1441 && m_atrSeeded);
   }

   bool ProcessTick(const MqlTick &tick, bool &candidateDue)
   {
      candidateDue = false;
      if(tick.time_msc <= 0 || tick.bid <= 0.0 || tick.ask <= 0.0 ||
         tick.ask < tick.bid)
         return false;
      if(m_lastTickMsc > 0 && tick.time_msc < m_lastTickMsc)
      {
         m_outOfOrderTicks++;
         return false;
      }
      m_lastTickMsc = tick.time_msc;
      const double spreadPips = (tick.ask - tick.bid) / m_pip;
      const datetime m1Time = AlignedTime(tick.time, 60);
      const datetime m5Time = AlignedTime(tick.time, 300);
      const bool tester = (bool)MQLInfoInteger(MQL_TESTER);

      if(!m_m1Accumulator.active)
      {
         StartAccumulator(m_m1Accumulator, m1Time, tick, spreadPips, tester);
      }
      else if(m1Time > m_m1Accumulator.barTime)
      {
         FinalizeM1();
         StartAccumulator(m_m1Accumulator, m1Time, tick, spreadPips, true);
      }
      else if(m1Time == m_m1Accumulator.barTime)
      {
         UpdateAccumulator(m_m1Accumulator, tick, spreadPips);
      }

      if(!m_m5Accumulator.active)
      {
         StartAccumulator(m_m5Accumulator, m5Time, tick, spreadPips, tester);
      }
      else if(m5Time > m_m5Accumulator.barTime)
      {
         const int previousCompleted = m_completedM5SinceStart;
         FinalizeM5();
         StartAccumulator(m_m5Accumulator, m5Time, tick, spreadPips, true);
         candidateDue = (m_completedM5SinceStart > previousCompleted &&
                         (m_completedM5SinceStart % 12) == 0);
      }
      else if(m5Time == m_m5Accumulator.barTime)
      {
         UpdateAccumulator(m_m5Accumulator, tick, spreadPips);
      }
      return true;
   }

   bool Build(double &raw[], double &context[], int &hour, int &weekday,
              double &atrPips, double &spreadPips, string &reason) const
   {
      reason = "";
      if(!HasCleanM1Window(reason))
         return false;
      if(m_m5Count < 1441)
      {
         reason = "M5_HISTORY_LT_1441";
         return false;
      }
      for(int ago = 0; ago < 12; ago++)
      {
         SRBTV58M5Bar testBar;
         if(!GetM5(ago, testBar) || !testBar.microValid)
         {
            reason = "M5_LIVE_MICRO_LT_12";
            return false;
         }
      }

      SRBTV58M5Bar current;
      if(!GetM5(0, current) || current.atr <= 0.0)
      {
         reason = "ATR_INVALID";
         return false;
      }
      atrPips = current.atr / m_pip;
      spreadPips = current.spreadPips;
      if(atrPips <= 0.0)
      {
         reason = "ATR_PIPS_INVALID";
         return false;
      }

      if(ArrayResize(raw, 254) != 254 || ArrayResize(context, 16) != 16)
      {
         reason = "MEMORY_ALLOCATION";
         return false;
      }
      int cursor = 0;
      const int m1x60[30] = {0,2,4,6,8,10,12,14,16,18,20,22,24,26,28,
         31,33,35,37,39,41,43,45,47,49,51,53,55,57,59};
      const int m1x240[32] = {0,8,15,23,31,39,46,54,62,69,77,85,93,100,108,
         116,123,131,139,146,154,162,170,177,185,193,200,208,216,224,231,239};
      const int m1x1440[48] = {0,31,61,92,122,153,184,214,245,276,306,337,
         367,398,429,459,490,520,551,582,612,643,674,704,735,765,796,827,
         857,888,919,949,980,1010,1041,1072,1102,1133,1163,1194,1225,1255,
         1286,1317,1347,1378,1408,1439};
      const int m5x96[16] = {0,6,13,19,25,32,38,44,51,57,63,70,76,82,89,95};
      const int m5x576[24] = {0,25,50,75,100,125,150,175,200,225,250,275,
         300,325,350,375,400,425,450,475,500,525,550,575};
      const int m5x1440[20] = {0,76,151,227,303,379,454,530,606,682,757,833,
         909,985,1060,1136,1212,1288,1363,1439};
      if(!AddM1Path(raw, cursor, 60, m1x60, 30, current.atr) ||
         !AddM1Path(raw, cursor, 240, m1x240, 32, current.atr) ||
         !AddM1Path(raw, cursor, 1440, m1x1440, 48, current.atr) ||
         !AddM5Path(raw, cursor, 96, m5x96, 16, current.atr) ||
         !AddM5Path(raw, cursor, 576, m5x576, 24, current.atr) ||
         !AddM5Path(raw, cursor, 1440, m5x1440, 20, current.atr))
      {
         reason = "PATH_FEATURE_FAILURE";
         return false;
      }

      for(int channel = 0; channel < 7; channel++)
      {
         for(int bin = 0; bin < 12; bin++)
         {
            double sum = 0.0;
            for(int item = 0; item < 5; item++)
            {
               const int chronological = bin * 5 + item;
               SRBTV58M1Bar bar;
               if(!GetM1(59 - chronological, bar))
               {
                  reason = "MICRO_FEATURE_FAILURE";
                  return false;
               }
               sum += MicroValue(bar, channel, atrPips);
            }
            raw[cursor++] = RBTV58_Clip20(sum / 5.0);
         }
      }
      if(cursor != 254)
      {
         reason = "RAW_DIMENSION_MISMATCH";
         return false;
      }

      const int trendWindows[4] = {12,48,288,1440};
      for(int index = 0; index < 4; index++)
      {
         SRBTV58M5Bar past;
         if(!GetM5(trendWindows[index], past))
         {
            reason = "TREND_HISTORY_FAILURE";
            return false;
         }
         context[index] = (current.close - past.close) / current.atr;
      }
      context[4] = MathAbs(context[1]);

      double longAtr = 0.0;
      for(int ago = 0; ago < 288; ago++)
      {
         SRBTV58M5Bar bar;
         GetM5(ago, bar);
         longAtr += bar.trueRange;
      }
      longAtr /= 288.0;
      context[5] = (longAtr > 0.0 ? current.atr / longAtr : 0.0);

      const int rangeWindows[3] = {12,48,288};
      for(int index = 0; index < 3; index++)
      {
         double highest = -1.0e308;
         double lowest = 1.0e308;
         for(int ago = 0; ago < rangeWindows[index]; ago++)
         {
            SRBTV58M5Bar bar;
            GetM5(ago, bar);
            highest = MathMax(highest, bar.high);
            lowest = MathMin(lowest, bar.low);
         }
         context[6 + index] = (highest - lowest) / current.atr;
      }

      const int positionWindows[2] = {48,288};
      for(int index = 0; index < 2; index++)
      {
         double highest = -1.0e308;
         double lowest = 1.0e308;
         for(int ago = 0; ago < positionWindows[index]; ago++)
         {
            SRBTV58M5Bar bar;
            GetM5(ago, bar);
            highest = MathMax(highest, bar.high);
            lowest = MathMin(lowest, bar.low);
         }
         const double width = highest - lowest;
         context[9 + index] = (width > 0.0 ? (current.close - lowest) / width : 0.5);
      }

      double persistence = 0.0;
      double efficiency = 0.0;
      double imbalance = 0.0;
      for(int ago = 0; ago < 12; ago++)
      {
         SRBTV58M5Bar newer, older;
         GetM5(ago, newer);
         GetM5(ago + 1, older);
         const double change = newer.close - older.close;
         persistence += (change > 0.0 ? 1.0 : (change < 0.0 ? -1.0 : 0.0));
         efficiency += newer.efficiency;
         imbalance += newer.imbalance;
      }
      context[11] = persistence / 12.0;
      context[12] = efficiency / 12.0;
      context[13] = imbalance / 12.0;

      double tickValues[];
      ArrayResize(tickValues, 288);
      for(int ago = 0; ago < 288; ago++)
      {
         SRBTV58M5Bar bar;
         GetM5(ago, bar);
         tickValues[ago] = bar.logTicks;
      }
      ArraySort(tickValues);
      const double tickMedian = (tickValues[143] + tickValues[144]) / 2.0;
      context[14] = current.logTicks - tickMedian;
      context[15] = current.spreadPips / atrPips;

      MqlDateTime parts;
      TimeToStruct(m_lastAnchorTime, parts);
      hour = parts.hour;
      weekday = (parts.day_of_week + 6) % 7;
      if(weekday < 0 || weekday > 4)
      {
         reason = "NON_TRADING_WEEKDAY";
         return false;
      }
      for(int index = 0; index < 254; index++)
      {
         if(!MathIsValidNumber(raw[index]))
         {
            reason = "RAW_NONFINITE";
            return false;
         }
      }
      for(int index = 0; index < 16; index++)
      {
         if(!MathIsValidNumber(context[index]))
         {
            reason = "CONTEXT_NONFINITE";
            return false;
         }
      }
      return true;
   }

   datetime LastAnchorTime(void) const { return m_lastAnchorTime; }
   int CompletedM5SinceStart(void) const { return m_completedM5SinceStart; }
   long OutOfOrderTicks(void) const { return m_outOfOrderTicks; }
};

#endif
