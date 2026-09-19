// Restored from v3p5.7.10: chart objects and original swing algorithms only.
// No trade API, shadow trade manager, entry gate or experimental policy.
#ifndef RBT_HYBRID_STRUCTURE_OVERLAY
#define RBT_HYBRID_STRUCTURE_OVERLAY
#ifndef RBT_EVENT_NOT_FOUND_BARS
#define RBT_EVENT_NOT_FOUND_BARS 999
#endif
#ifndef RBT_MIN_HISTORY_BARS
#define RBT_MIN_HISTORY_BARS 120
#endif
#ifndef RBT_SIGNAL_TIMEFRAME
#define RBT_SIGNAL_TIMEFRAME PERIOD_M5
#endif
#include "V2Foundation/RBT_V2_Types.mqh"
#include "V2Foundation/RBT_V2_Utils.mqh"
#include "V2Foundation/RBT_V2_MarketData.mqh"
#include "V2Foundation/RBT_V2_Swings.mqh"
#include "V2Foundation/RBT_V2_MarketStructure.mqh"
#define V3O_PREFIX "RBT_HYBRID_STRUCTURE_"

struct RBTOverlayState
{
   SMarketDataCache market;
   SIndicatorSnapshot indicators;
   SSwingSeries internalSwings;
   SSwingSeries externalSwings;
   SStructureSnapshot structure;
   bool valid;
};
RBTOverlayState g_hybridOverlayM5;
datetime g_hybridOverlayBar=0;
datetime g_hybridOverlayAttempt=0;

bool HybridStructureOverlayCanDraw()
{
   return InpV3OverlayEnable &&
      (!MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE));
}

bool HybridStructureOverlayRefresh()
{
   g_hybridOverlayM5.valid=false;
   if(!RBT_MarketDataRefresh(g_hybridOverlayM5.market)) return false;
   const double atr=RBT_LocalATRAt(g_hybridOverlayM5.market,1,14);
   if(atr<=0.0 || !MathIsValidNumber(atr)) return false;
   g_hybridOverlayM5.indicators.barTime=g_hybridOverlayM5.market.rates[1].time;
   g_hybridOverlayM5.indicators.shift=1;
   g_hybridOverlayM5.indicators.atr=atr;
   g_hybridOverlayM5.indicators.valid=true;
   if(!RBT_BuildSwingSeries(g_hybridOverlayM5.market,
      InpV3ShadowInternalPivotBars,InpV3ShadowInternalMinSwingATR,
      InpV3ShadowEqualSwingToleranceATR,g_hybridOverlayM5.internalSwings)) return false;
   if(!RBT_BuildSwingSeries(g_hybridOverlayM5.market,
      InpV3ShadowExternalPivotBars,InpV3ShadowExternalMinSwingATR,
      InpV3ShadowEqualSwingToleranceATR,g_hybridOverlayM5.externalSwings)) return false;
   if(!RBT_EvaluateMarketStructure(g_hybridOverlayM5.market,g_hybridOverlayM5.indicators,
      g_hybridOverlayM5.internalSwings,g_hybridOverlayM5.externalSwings,
      InpV3ShadowBreakConfirmATR,g_hybridOverlayM5.structure)) return false;
   g_hybridOverlayM5.valid=true;
   return true;
}

string V3O_SwingText(const int c)
{
   return RBT_SwingTypeToString(c);
}

void V3O_DeleteObjects()
{
   const int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; --i)
   {
      const string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, V3O_PREFIX) == 0)
         ObjectDelete(0, name);
   }
}

bool V3O_CreateText(const string name,
                    const datetime t,
                    const double price,
                    const string text,
                    const color clr,
                    const int fontSize)
{
   ResetLastError();
   if(!ObjectCreate(0, name, OBJ_TEXT, 0, t, price))
   {
      PrintFormat("V3_OVERLAY_CREATE_FAIL | type=TEXT name=%s err=%d", name, GetLastError());
      return false;
   }
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 30);
   return true;
}

bool V3O_CreateSegment(const string name,
                       const datetime t1,
                       const double p1,
                       const datetime t2,
                       const double p2,
                       const color clr,
                       const int width,
                       const ENUM_LINE_STYLE style)
{
   if(t1 <= 0 || t2 <= 0 || p1 <= 0.0 || p2 <= 0.0 || t2 <= t1)
      return false;

   ResetLastError();
   if(!ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2))
   {
      PrintFormat("V3_OVERLAY_CREATE_FAIL | type=TREND name=%s err=%d", name, GetLastError());
      return false;
   }
   ObjectSetInteger(0, name, OBJPROP_RAY_LEFT, false);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, MathMax(1, width));
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 10);
   return true;
}

void V3O_DrawSwingPath(const SSwingSeries &series,
                       const string layer,
                       const bool externalLayer,
                       int &segmentsDrawn)
{
   if(!series.valid || series.count < 2)
      return;

   const int maxSegments = MathMax(1, InpV3OverlayMaxSwingSegments);
   const int firstPoint = MathMax(0, series.count - maxSegments - 1);
   const color lineColor = (externalLayer ? clrGold : clrOrange);
   const int lineWidth = (externalLayer ? InpV3OverlayExternalLineWidth : InpV3OverlayInternalLineWidth);
   const ENUM_LINE_STYLE style = (externalLayer ? STYLE_DASH : STYLE_SOLID);

   for(int i = firstPoint + 1; i < series.count; ++i)
   {
      const SSwingPoint a = series.points[i - 1];
      const SSwingPoint b = series.points[i];
      const string name = StringFormat(V3O_PREFIX + "PATH_%s_%I64d_%I64d", layer, (long)a.time, (long)b.time);
      if(V3O_CreateSegment(name, a.time, a.price, b.time, b.price, lineColor, lineWidth, style))
         segmentsDrawn++;
   }
}

void V3O_DrawSwingLabels(const SSwingSeries &series,
                         const string layer,
                         const bool externalLayer,
                         int &labelsDrawn)
{
   if(!series.valid || series.count <= 0)
      return;

   const int maxLabels = MathMax(1, InpV3OverlayMaxSwingLabels);
   const int start = MathMax(0, series.count - maxLabels);
   for(int i = start; i < series.count; ++i)
   {
      const SSwingPoint p = series.points[i];
      if(p.time <= 0 || p.price <= 0.0 || p.classification == RBT_SWING_NONE)
         continue;

      const bool highType = (p.classification == RBT_SWING_HH ||
                             p.classification == RBT_SWING_LH ||
                             p.classification == RBT_SWING_EQUAL_HIGH);
      const double offset = MathMax(p.atr * (externalLayer ? 0.20 : 0.12), 8.0 * _Point);
      const double y = (highType ? p.price + offset : p.price - offset);
      const color clr = externalLayer ? clrGold : (highType ? clrTomato : clrDeepSkyBlue);
      const string label = V3O_SwingText(p.classification) + (externalLayer ? " E" : "");
      const string name = StringFormat(V3O_PREFIX + "SW_%s_%I64d_%d", layer, (long)p.time, i);
      if(V3O_CreateText(name, p.time, y, label, clr, externalLayer ? 9 : 8))
         labelsDrawn++;
   }
}

void V3O_DrawBreakLabel(const string tag,
                        const bool active,
                        const datetime barTime,
                        const double price,
                        const string text,
                        const color clr)
{
   if(!active || barTime <= 0 || price <= 0.0)
      return;
   const string name = StringFormat(V3O_PREFIX + "%s_%I64d", tag, (long)barTime);
   V3O_CreateText(name, barTime, price, text, clr, 9);
}

void V3O_Update()
{
   if(!HybridStructureOverlayCanDraw())
      return;

   // The GUI checkbox owns the complete structure overlay: swing labels,
   // connecting paths and BOS/CHOCH labels. Hidden means nothing remains.
   if(!g_runtimeShowStructureLines)
   {
      V3O_DeleteObjects();
      ChartRedraw(0);
      return;
   }

   // If the user enables the overlay before the first regular refresh, build
   // the current snapshot immediately so HH/HL/LH/LL and paths appear together.
   if(!g_hybridOverlayM5.valid && !HybridStructureOverlayRefresh())
      return;

   V3O_DeleteObjects();
   int labelsDrawn = 0;
   int segmentsDrawn = 0;

   // Draw paths first so labels remain readable above them.
   if(InpV3OverlayShowInternalSwings &&
      InpV3OverlayConnectInternalSwings)
      V3O_DrawSwingPath(g_hybridOverlayM5.internalSwings, "INT", false, segmentsDrawn);
   if(InpV3OverlayShowExternalSwings &&
      InpV3OverlayConnectExternalSwings)
      V3O_DrawSwingPath(g_hybridOverlayM5.externalSwings, "EXT", true, segmentsDrawn);

   if(InpV3OverlayShowInternalSwings)
      V3O_DrawSwingLabels(g_hybridOverlayM5.internalSwings, "INT", false, labelsDrawn);
   if(InpV3OverlayShowExternalSwings)
      V3O_DrawSwingLabels(g_hybridOverlayM5.externalSwings, "EXT", true, labelsDrawn);

   if(g_hybridOverlayM5.valid && g_hybridOverlayM5.structure.valid)
   {
      const SStructureLayerSnapshot ext = g_hybridOverlayM5.structure.externalLayer;
      const datetime t = g_hybridOverlayM5.market.rates[1].time;
      const double atr = g_hybridOverlayM5.indicators.atr;
      const double highY = g_hybridOverlayM5.market.rates[1].high + atr * 0.35;
      const double lowY  = g_hybridOverlayM5.market.rates[1].low  - atr * 0.35;
      if(InpV3OverlayShowBOS)
      {
         V3O_DrawBreakLabel("BOS_UP", ext.bullishBOS && ext.barsSinceBullishBOS <= InpV3OverlayRecentEventBars,
                           t, lowY, "BOS UP", clrLimeGreen);
         V3O_DrawBreakLabel("BOS_DN", ext.bearishBOS && ext.barsSinceBearishBOS <= InpV3OverlayRecentEventBars,
                           t, highY, "BOS DOWN", clrTomato);
      }
      if(InpV3OverlayShowCHOCH)
      {
         V3O_DrawBreakLabel("CHOCH_UP", ext.bullishCHOCH && ext.barsSinceBullishCHOCH <= InpV3OverlayRecentEventBars,
                           t, lowY - atr * 0.15, "CHOCH UP", clrAqua);
         V3O_DrawBreakLabel("CHOCH_DN", ext.bearishCHOCH && ext.barsSinceBearishCHOCH <= InpV3OverlayRecentEventBars,
                           t, highY + atr * 0.15, "CHOCH DOWN", clrOrangeRed);
      }
   }

   ChartRedraw(0);
}

void HybridStructureOverlayInitialize()
{
   g_hybridOverlayBar=0;
   g_hybridOverlayAttempt=0;
   g_hybridOverlayM5.valid=false;
   RBT_MarketDataInitialize(g_hybridOverlayM5.market,InpV3ShadowHistoryBars);
   RBT_SwingSeriesReset(g_hybridOverlayM5.internalSwings);
   RBT_SwingSeriesReset(g_hybridOverlayM5.externalSwings);
   RBT_StructureSnapshotReset(g_hybridOverlayM5.structure);
   // Always remove stale objects from an older EA instance/version.
   V3O_DeleteObjects();
}

void HybridStructureOverlayProcess()
{
   if(!HybridStructureOverlayCanDraw()) return;
   const datetime bar=iTime(_Symbol,PERIOD_M5,0);
   if(bar<=0 || bar==g_hybridOverlayBar) return;
   // A missing visual history must not fail EA initialization or block trading.
   if(g_hybridOverlayAttempt>0 && TimeCurrent()-g_hybridOverlayAttempt<30) return;
   g_hybridOverlayAttempt=TimeCurrent();
   if(!HybridStructureOverlayRefresh()) return;
   g_hybridOverlayBar=bar;
   V3O_Update();
}

void HybridStructureOverlayShutdown()
{
   V3O_DeleteObjects();
   RBT_MarketDataReset(g_hybridOverlayM5.market);
}
#endif
