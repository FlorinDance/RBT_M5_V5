//+------------------------------------------------------------------+
//| EA_ML_M5_Panel.mqh                                               |
//| Panel grafic cu două coloane: control runtime în stânga și       |
//| contextul live MTF/structure în dreapta. Inputurile rămân pentru |
//| backtest/optimizare; panelul modifică doar variabile runtime după   |
//| apăsarea butonului Apply.                                         |
//+------------------------------------------------------------------+

#ifndef __EA_ML_M5_PANEL_MQH__
#define __EA_ML_M5_PANEL_MQH__

//========================== RUNTIME SETTINGS ========================//
double g_runtimeLots                  = 0.0;
double g_runtimeTakeProfitMoney       = 0.0;
double g_runtimeMaxLossMoney           = 0.0;
double g_runtimeMaxSpreadPips         = 0.0;
double g_runtimeMinBuyProb            = 0.0;
double g_runtimeMinSellProb           = 0.0;
double g_runtimeMinDecisionGap        = 0.0;

bool   g_runtimeUseMaxSpreadFilter    = true;
bool   g_runtimeUseMaxLossMoney        = false;
bool   g_runtimeAllowBuy              = true;
bool   g_runtimeAllowSell             = true;
bool   g_runtimeAllowNewTrades        = true;
bool   g_runtimeManageOpenPositions   = true;
bool   g_runtimeUseProfitSteps        = false;
bool   g_runtimeShowStructureLines    = false;

//========================== PANEL STATUS ============================//
int      g_panelLastDecision           = -1;
double   g_panelLastSellProb           = 0.0;
double   g_panelLastHoldProb           = 0.0;
double   g_panelLastBuyProb            = 0.0;
double   g_panelLastRegPred            = 0.0;
datetime g_panelLastSignalTime         = 0;
bool     g_panelStructureLinesRefreshRequested = false;

//========================== PANEL CONSTANTS =========================//
#define PANEL_PREFIX "EA_ML_M5_PANEL_"
#define PANEL_CONTEXT_PREFIX "RBT_V3O_PANEL_"
#define PANEL_LEFT_COLUMN_WIDTH 300
#define PANEL_CONTEXT_X_OFFSET  310
#define PANEL_CONTEXT_Y_OFFSET  34
#define PANEL_CONTEXT_ROW_HEIGHT 15

int  g_panelX        = 10;
int  g_panelY        = 20;
int  g_panelW        = 610;
int  g_panelH        = 405;
bool g_panelVisible  = true;
bool g_panelCreated  = false;
bool g_panelDragging = false;
int  g_panelDragOffsetX = 0;
int  g_panelDragOffsetY = 0;
bool g_panelOldMouseScroll = true;
bool g_panelMouseScrollSaved = false;

//========================== PANEL COLORS ============================//
// Culorile sunt definite ca macro-uri pentru că MQL5 cere constante
// reale în valorile default ale parametrilor funcțiilor.
#define PANEL_FRAME_COLOR      clrBlack
#define PANEL_HEADER_BG_COLOR  clrGainsboro
#define PANEL_BODY_BG_COLOR    clrWhiteSmoke
#define PANEL_BUTTON_BG_COLOR  clrGainsboro
#define PANEL_INPUT_BG_COLOR   clrWhite
#define PANEL_TEXT_COLOR       clrBlack

//+------------------------------------------------------------------+
//| PanelBoolText
//| Returnează text ON/OFF pentru controalele boolean.
//+------------------------------------------------------------------+
string PanelBoolText(const bool value)
{
   return value ? "ON" : "OFF";
}

//+------------------------------------------------------------------+
//| PanelCheckboxText
//| Returnează textul pentru căsuța checkbox.
//+------------------------------------------------------------------+
string PanelCheckboxText(const bool value)
{
   return value ? "✓" : "";
}


//+------------------------------------------------------------------+
//| PanelLotDigits
//| Volum digits derived from the broker lot step.
//+------------------------------------------------------------------+
int PanelLotDigits(const double stepLot)
{
   if(stepLot >= 1.0)   return 0;
   if(stepLot >= 0.1)   return 1;
   if(stepLot >= 0.01)  return 2;
   if(stepLot >= 0.001) return 3;
   return 4;
}

//+------------------------------------------------------------------+
//| PanelValidateRuntimeLotsValue
//| Validates GUI lot against broker range/step and optional manual cap.
//+------------------------------------------------------------------+
bool PanelValidateRuntimeLotsValue(const double requestedLots,
                                   double &normalizedLots,
                                   string &reason)
{
   normalizedLots = 0.0;
   reason = "";

   if(!MathIsValidNumber(requestedLots) || requestedLots <= 0.0)
   {
      reason = "lot must be a finite value greater than zero";
      return false;
   }

   const double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   const double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   const double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(minLot <= 0.0 || maxLot <= 0.0 || stepLot <= 0.0)
   {
      reason = "broker volume specification is unavailable";
      return false;
   }

   const double configuredHardMax =
      (InpLotSafetyEnable && InpLotSafetyAbsoluteMaxLots > 0.0 ?
       InpLotSafetyAbsoluteMaxLots : maxLot);
   const double allowedMax = MathMin(maxLot, configuredHardMax);
   const double epsilon = MathMax(0.0000001, stepLot * 0.0001);

   if(requestedLots < minLot - epsilon)
   {
      reason = StringFormat("lot %.4f is below broker minimum %.4f",
                            requestedLots, minLot);
      return false;
   }
   if(requestedLots > allowedMax + epsilon)
   {
      reason = StringFormat("lot %.4f exceeds allowed maximum %.4f",
                            requestedLots, allowedMax);
      return false;
   }

   normalizedLots = MathFloor((requestedLots + epsilon) / stepLot) * stepLot;
   normalizedLots = NormalizeDouble(normalizedLots, PanelLotDigits(stepLot));
   if(normalizedLots < minLot - epsilon || normalizedLots > allowedMax + epsilon)
   {
      reason = StringFormat("normalized lot %.4f is outside [%.4f, %.4f]",
                            normalizedLots, minLot, allowedMax);
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| PanelWarnLotTPCompatibility
//| Warning only. It never changes lot or TP selected by the user.
//+------------------------------------------------------------------+
void PanelWarnLotTPCompatibility(const double lots,
                                 const double tpMoney,
                                 const string source)
{
   // Phase 5.7B-R1: lot and TP are independent GUI/runtime choices.
   // No fixed 0.50/25 or 0.40/20 ratio is enforced or warned against.
   if(lots <= 0.0 || tpMoney <= 0.0)
      PrintFormat("GUI TRADE GEOMETRY WARNING | source=%s lot=%.4f tpMoney=%.2f must both be > 0",
                  source, lots, tpMoney);
}

//+------------------------------------------------------------------+
//| PanelObjectName
//| Construiește numele obiectelor grafice, cu prefix unic.
//+------------------------------------------------------------------+
string PanelObjectName(const string suffix)
{
   return PANEL_PREFIX + suffix;
}

//+------------------------------------------------------------------+
//| PanelSetChartMouseProtection
//| Dezactivează temporar tragerea/scroll-ul graficului cât timp panelul
//| este vizibil, ca drag-ul panelului să nu miște chart-ul din spate.
//+------------------------------------------------------------------+
void PanelSetChartMouseProtection(const bool enable)
{
   if(enable)
   {
      if(!g_panelMouseScrollSaved)
      {
         g_panelOldMouseScroll = (bool)ChartGetInteger(0, CHART_MOUSE_SCROLL);
         g_panelMouseScrollSaved = true;
      }
      ChartSetInteger(0, CHART_MOUSE_SCROLL, false);
   }
   else
   {
      if(g_panelMouseScrollSaved)
      {
         ChartSetInteger(0, CHART_MOUSE_SCROLL, g_panelOldMouseScroll);
         g_panelMouseScrollSaved = false;
      }
   }
}

//+------------------------------------------------------------------+
//| PanelPrepareObject
//| Setează proprietățile comune pentru obiectele panelului.
//+------------------------------------------------------------------+
void PanelPrepareObject(const string name,
                        const int x,
                        const int y,
                        const int width,
                        const int height,
                        const bool selectable = false)
{
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, selectable);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| PanelCreateLabel
//| Creează un label text în panel.
//+------------------------------------------------------------------+
bool PanelCreateLabel(const string suffix,
                      const string text,
                      const int x,
                      const int y,
                      const int width = 120,
                      const int fontSize = 8,
                      const color textColor = clrBlack,
                      const bool selectable = false)
{
   string name = PanelObjectName(suffix);
   ObjectDelete(0, name);

   if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0))
      return false;

   PanelPrepareObject(name, x, y, width, 18, selectable);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   return true;
}

//+------------------------------------------------------------------+
//| PanelCreateEdit
//| Creează un câmp editabil numeric în panel.
//+------------------------------------------------------------------+
bool PanelCreateEdit(const string suffix,
                     const string text,
                     const int x,
                     const int y,
                     const int width = 72,
                     const int height = 18)
{
   string name = PanelObjectName(suffix);
   ObjectDelete(0, name);

   if(!ObjectCreate(0, name, OBJ_EDIT, 0, 0, 0))
      return false;

   PanelPrepareObject(name, x, y, width, height, false);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, name, OBJPROP_COLOR, PANEL_TEXT_COLOR);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, PANEL_INPUT_BG_COLOR);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, PANEL_FRAME_COLOR);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   return true;
}

//+------------------------------------------------------------------+
//| PanelCreateButton
//| Creează un buton în panel.
//+------------------------------------------------------------------+
bool PanelCreateButton(const string suffix,
                       const string text,
                       const int x,
                       const int y,
                       const int width = 75,
                       const int height = 20,
                       const color bgColor = PANEL_BUTTON_BG_COLOR,
                       const color textColor = PANEL_TEXT_COLOR)
{
   string name = PanelObjectName(suffix);
   ObjectDelete(0, name);

   if(!ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0))
      return false;

   PanelPrepareObject(name, x, y, width, height, false);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgColor);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, PANEL_FRAME_COLOR);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   return true;
}

//+------------------------------------------------------------------+
//| PanelCreateCheckbox
//| Creează un checkbox vizual: pătrat clickabil + label text.
//+------------------------------------------------------------------+
bool PanelCreateCheckbox(const string suffix,
                         const string label,
                         const bool value,
                         const int x,
                         const int y,
                         const int labelWidth = 170)
{
   bool okBox = PanelCreateButton(suffix + "_BOX",
                                  PanelCheckboxText(value),
                                  x,
                                  y,
                                  18,
                                  18,
                                  clrWhite,
                                  clrBlack);
   if(okBox)
   {
      ObjectSetInteger(0, PanelObjectName(suffix + "_BOX"), OBJPROP_FONTSIZE, 9);
      ObjectSetInteger(0, PanelObjectName(suffix + "_BOX"), OBJPROP_BORDER_COLOR, PANEL_FRAME_COLOR);
   }

   bool okLabel = PanelCreateLabel(suffix + "_LABEL",
                                   label,
                                   x + 24,
                                   y + 2,
                                   labelWidth,
                                   8,
                                   clrBlack,
                                   true);
   return okBox && okLabel;
}

//+------------------------------------------------------------------+
//| PanelSetText
//| Setează textul unui obiect din panel dacă acesta există.
//+------------------------------------------------------------------+
void PanelSetText(const string suffix, const string text)
{
   string name = PanelObjectName(suffix);
   if(ObjectFind(0, name) >= 0)
      ObjectSetString(0, name, OBJPROP_TEXT, text);
}

//+------------------------------------------------------------------+
//| PanelSetTooltip
//| Setează tooltip-ul unui obiect din panel, afișat la hover cu mouse-ul.
//+------------------------------------------------------------------+
void PanelSetTooltip(const string suffix, const string tooltip)
{
   string name = PanelObjectName(suffix);
   if(ObjectFind(0, name) >= 0)
      ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);
}

//+------------------------------------------------------------------+
//| PanelSetEditEnabled
//| Makes an edit field visually and functionally enabled/disabled.
//+------------------------------------------------------------------+
void PanelSetEditEnabled(const string suffix, const bool enabled)
{
   string name = PanelObjectName(suffix);
   if(ObjectFind(0, name) < 0)
      return;

   ObjectSetInteger(0, name, OBJPROP_READONLY, !enabled);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, enabled ? PANEL_INPUT_BG_COLOR : clrGainsboro);
   ObjectSetInteger(0, name, OBJPROP_COLOR, enabled ? PANEL_TEXT_COLOR : clrDimGray);
}

//+------------------------------------------------------------------+
//| PanelGetDouble
//| Citește un double dintr-un câmp editabil; dacă e invalid, păstrează fallback.
//+------------------------------------------------------------------+
double PanelGetDouble(const string suffix, const double fallback)
{
   string name = PanelObjectName(suffix);
   if(ObjectFind(0, name) < 0)
      return fallback;

   string txt = ObjectGetString(0, name, OBJPROP_TEXT);
   double value = StringToDouble(txt);

   if(value <= 0.0)
      return fallback;

   return value;
}

//+------------------------------------------------------------------+
//| PanelSetEditValuesFromRuntime
//| Scrie valorile runtime curente în câmpurile editabile.
//+------------------------------------------------------------------+
void PanelSetEditValuesFromRuntime()
{
   PanelSetText("EDIT_LOTS",          DoubleToString(g_runtimeLots, 2));
   PanelSetText("EDIT_TP",            DoubleToString(g_runtimeTakeProfitMoney, 2));
   PanelSetText("EDIT_MAX_LOSS",      DoubleToString(g_runtimeMaxLossMoney, 2));
   PanelSetText("EDIT_SPREAD",        DoubleToString(g_runtimeMaxSpreadPips, 2));
   PanelSetText("EDIT_PROP_ACCOUNT",  DoubleToString(g_runtimePropAccountValue, 2));
}

//+------------------------------------------------------------------+
//| PanelRefreshControls
//| Actualizează checkbox-urile și statusul controlului live.
//+------------------------------------------------------------------+
void PanelRefreshControls()
{
   PanelSetText("CHK_TRADING_BOX",    PanelCheckboxText(g_runtimeAllowNewTrades));
   PanelSetText("CHK_SPREAD_BOX",     PanelCheckboxText(g_runtimeUseMaxSpreadFilter));
   PanelSetText("CHK_MAX_LOSS_BOX",   PanelCheckboxText(g_runtimeUseMaxLossMoney));
   PanelSetText("CHK_STRUCTURE_LINES_BOX", PanelCheckboxText(g_runtimeShowStructureLines));
   PanelSetText("CHK_PROP_RISK_BOX",  PanelCheckboxText(g_runtimePropRiskEnable));
   PanelSetEditEnabled("EDIT_MAX_LOSS", g_runtimeUseMaxLossMoney);
   PanelSetEditEnabled("EDIT_SPREAD", g_runtimeUseMaxSpreadFilter);
   PanelSetEditEnabled("EDIT_PROP_ACCOUNT", g_runtimePropRiskEnable);
}

//+------------------------------------------------------------------+
//| PanelInitializeRuntime
//| Inițializează valorile runtime din inputuri la pornirea EA-ului.
//+------------------------------------------------------------------+
void PanelInitializeRuntime()
{
   // One source of truth in tester, demo and live: public inputs / panel.
   g_runtimeLots                = InpLots;
   g_runtimeTakeProfitMoney     = InpTakeProfitMoney;
   g_runtimeMaxLossMoney       = InpMaxLossMoneyPerTrade;
   g_runtimeMaxSpreadPips       = InpMaxSpreadPips;
   g_runtimePropAccountValue    = InpPropAccountValue;
   g_runtimeMinBuyProb          = InpMinBuyProb;
   g_runtimeMinSellProb         = InpMinSellProb;
   g_runtimeMinDecisionGap      = InpMinDecisionGap;

   g_runtimeUseMaxSpreadFilter  = true;
   g_runtimeUseMaxLossMoney    = InpUseMaxLossMoneyProtection;
   g_runtimeAllowBuy            = InpAllowBuy;
   g_runtimeAllowSell           = InpAllowSell;
   g_runtimeAllowNewTrades      = true;
   g_runtimeManageOpenPositions = true;
   g_runtimeUseProfitSteps      = InpUseProfitStepManagement;
   g_runtimeShowStructureLines  = false;

   g_panelX                     = InpPanelX;
   g_panelY                     = InpPanelY;
   g_panelVisible               = InpShowControlPanel;
   g_panelCreated               = false;
}

//+------------------------------------------------------------------+
//| PanelApplyRuntimeFromEdits
//| Aplică valorile scrise în UI către variabilele runtime.
//+------------------------------------------------------------------+
void PanelApplyRuntimeFromEdits()
{
   const double previousLots = g_runtimeLots;
   const double requestedLots = PanelGetDouble("EDIT_LOTS", previousLots);
   double normalizedLots = 0.0;
   string lotReason = "";
   if(PanelValidateRuntimeLotsValue(requestedLots, normalizedLots, lotReason))
   {
      g_runtimeLots = normalizedLots;
   }
   else
   {
      g_runtimeLots = previousLots;
      PrintFormat("LOT SAFETY REJECTED | GUI requested=%.4f kept=%.4f reason=%s",
                  requestedLots, previousLots, lotReason);
   }

   g_runtimeTakeProfitMoney  = PanelGetDouble("EDIT_TP",        g_runtimeTakeProfitMoney);
   if(g_runtimeUseMaxLossMoney)
      g_runtimeMaxLossMoney = PanelGetDouble("EDIT_MAX_LOSS",  g_runtimeMaxLossMoney);
   if(g_runtimeUseMaxSpreadFilter)
      g_runtimeMaxSpreadPips = PanelGetDouble("EDIT_SPREAD",   g_runtimeMaxSpreadPips);

   const double requestedPropAccount =
      PanelGetDouble("EDIT_PROP_ACCOUNT", g_runtimePropAccountValue);
   PropRiskSetRuntimeAccountValue(requestedPropAccount, "PANEL_APPLY");

   if(g_runtimeMinBuyProb > 1.0)       g_runtimeMinBuyProb = 1.0;
   if(g_runtimeMinSellProb > 1.0)      g_runtimeMinSellProb = 1.0;
   if(g_runtimeMinDecisionGap > 1.0)   g_runtimeMinDecisionGap = 1.0;

   PanelSetEditValuesFromRuntime();
   PanelWarnLotTPCompatibility(g_runtimeLots, g_runtimeTakeProfitMoney, "GUI_APPLY");

   PrintFormat("Panel Apply | lots=%.2f tpMoney=%.2f maxLoss=%.2f maxSpread=%.2f propAccount=%.2f minBuy=%.2f minSell=%.2f gap=%.2f | trading=%s manage=%s maxLossProtect=%s steps=%s spread=%s propRisk=%s",
               g_runtimeLots,
               g_runtimeTakeProfitMoney,
               g_runtimeMaxLossMoney,
               g_runtimeMaxSpreadPips,
               g_runtimePropAccountValue,
               g_runtimeMinBuyProb,
               g_runtimeMinSellProb,
               g_runtimeMinDecisionGap,
               PanelBoolText(g_runtimeAllowNewTrades),
               PanelBoolText(g_runtimeManageOpenPositions),
               PanelBoolText(g_runtimeUseMaxLossMoney),
               PanelBoolText(g_runtimeUseProfitSteps),
               PanelBoolText(g_runtimeUseMaxSpreadFilter),
               PanelBoolText(g_runtimePropRiskEnable));
}

//+------------------------------------------------------------------+
//| PanelResetRuntimeToInputs
//| Resetează valorile runtime la valorile inputurilor inițiale.
//+------------------------------------------------------------------+
void PanelResetRuntimeToInputs()
{
   bool oldVisible = g_panelVisible;
   int oldX = g_panelX;
   int oldY = g_panelY;

   PanelInitializeRuntime();
   PropRiskSetRuntimeEnabled(InpPropRiskEnable, "PANEL_RESET");
   g_panelStructureLinesRefreshRequested = true;
   g_panelVisible = oldVisible;
   g_panelX = oldX;
   g_panelY = oldY;

   PanelSetEditValuesFromRuntime();
   PanelRefreshControls();
   Print("Panel Reset: runtime settings restored from EA inputs.");
}

//+------------------------------------------------------------------+
//| PanelDecisionText
//| Transformă decizia modelului în text pentru status.
//+------------------------------------------------------------------+
string PanelDecisionText(const int decision)
{
   if(decision == 2) return "BUY";
   if(decision == 0) return "SELL";
   if(decision == 1) return "HOLD";
   return "N/A";
}

//+------------------------------------------------------------------+
//| PanelSetLastMLSignal
//| Salvează ultima decizie ML pentru afișarea în statusul live.
//+------------------------------------------------------------------+
void PanelSetLastMLSignal(const int decision,
                          const double pSell,
                          const double pHold,
                          const double pBuy,
                          const double regPred)
{
   g_panelLastDecision   = decision;
   g_panelLastSellProb   = pSell;
   g_panelLastHoldProb   = pHold;
   g_panelLastBuyProb    = pBuy;
   g_panelLastRegPred    = regPred;
   g_panelLastSignalTime = TimeCurrent();
}

//+------------------------------------------------------------------+
//| PanelGetOpenProfitMoney
//| Calculează profitul pozițiilor EA-ului pe simbolul curent.
//+------------------------------------------------------------------+
double PanelGetOpenProfitMoney()
{
   double profit = 0.0;

   for(int i = PositionsTotal() - 1; i >= 0; --i)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      string symbol = PositionGetString(POSITION_SYMBOL);
      long magic = PositionGetInteger(POSITION_MAGIC);

      if(symbol == _Symbol && magic == InpMagicNumber)
         profit += PositionGetDouble(POSITION_PROFIT);
   }

   return profit;
}

//+------------------------------------------------------------------+
//| PanelDestroy
//| Șterge toate obiectele panelului.
//+------------------------------------------------------------------+
void PanelDestroy()
{
   PanelSetChartMouseProtection(false);

   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; --i)
   {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, PANEL_PREFIX) == 0 ||
         StringFind(name, PANEL_CONTEXT_PREFIX) == 0)
         ObjectDelete(0, name);
   }
   g_panelCreated = false;
}

//+------------------------------------------------------------------+
//| PanelCreate
//| Construiește panelul grafic pe chart.
//+------------------------------------------------------------------+
void PanelCreate()
{
   if(!InpShowControlPanel || !g_panelVisible)
   {
      PrintFormat("PanelCreate skipped | InpShowControlPanel=%s g_panelVisible=%s",
                  PanelBoolText(InpShowControlPanel),
                  PanelBoolText(g_panelVisible));
      return;
   }

   PanelDestroy();
   PanelSetChartMouseProtection(true);

   ResetLastError();
   if(!ObjectCreate(0, PanelObjectName("BG"), OBJ_RECTANGLE_LABEL, 0, 0, 0))
   {
      PrintFormat("PanelCreate failed: BG object could not be created. error=%d", GetLastError());
      return;
   }
   PanelPrepareObject(PanelObjectName("BG"), g_panelX, g_panelY, g_panelW, g_panelH, true);
   ObjectSetInteger(0, PanelObjectName("BG"), OBJPROP_BGCOLOR, PANEL_BODY_BG_COLOR);
   ObjectSetInteger(0, PanelObjectName("BG"), OBJPROP_BORDER_COLOR, PANEL_FRAME_COLOR);
   ObjectSetInteger(0, PanelObjectName("BG"), OBJPROP_BACK, false);

   ResetLastError();
   if(!ObjectCreate(0, PanelObjectName("HEADER"), OBJ_RECTANGLE_LABEL, 0, 0, 0))
   {
      PrintFormat("PanelCreate failed: HEADER object could not be created. error=%d", GetLastError());
      return;
   }
   PanelPrepareObject(PanelObjectName("HEADER"), g_panelX, g_panelY, g_panelW, 24, true);
   ObjectSetInteger(0, PanelObjectName("HEADER"), OBJPROP_BGCOLOR, PANEL_HEADER_BG_COLOR);
   ObjectSetInteger(0, PanelObjectName("HEADER"), OBJPROP_BORDER_COLOR, PANEL_FRAME_COLOR);
   ObjectSetInteger(0, PanelObjectName("HEADER"), OBJPROP_BACK, false);

   ResetLastError();
   if(!ObjectCreate(0, PanelObjectName("COLUMN_DIVIDER"), OBJ_RECTANGLE_LABEL, 0, 0, 0))
   {
      PrintFormat("PanelCreate failed: COLUMN_DIVIDER object could not be created. error=%d", GetLastError());
      return;
   }
   PanelPrepareObject(PanelObjectName("COLUMN_DIVIDER"),
                      g_panelX + PANEL_LEFT_COLUMN_WIDTH,
                      g_panelY + 24,
                      1,
                      g_panelH - 24,
                      false);
   ObjectSetInteger(0, PanelObjectName("COLUMN_DIVIDER"), OBJPROP_BGCOLOR, clrSilver);
   ObjectSetInteger(0, PanelObjectName("COLUMN_DIVIDER"), OBJPROP_BORDER_COLOR, clrSilver);
   ObjectSetInteger(0, PanelObjectName("COLUMN_DIVIDER"), OBJPROP_BACK, false);

   int x = g_panelX + 10;
   int y = g_panelY + 4;
   int row = 20;

   PanelCreateLabel("TITLE", "RBT M5 v5.10 HYBRID - CONTROL", x, y, 275, 9, clrBlack, true);
   PanelCreateLabel("CONTEXT_TITLE", "XGBOOST + MOTIF CONTEXT", g_panelX + PANEL_CONTEXT_X_OFFSET, y, 270, 9, clrBlack, true);
   PanelCreateButton("BTN_PANEL_X", "X", g_panelX + g_panelW - 24, g_panelY + 3, 20, 18, PANEL_BUTTON_BG_COLOR, PANEL_TEXT_COLOR);

   y = g_panelY + 32;

   PanelCreateLabel("LBL_LOTS",      "Lot Size",        x,       y); PanelCreateEdit("EDIT_LOTS",      DoubleToString(g_runtimeLots, 2),             x+150, y-2); y += row;
   PanelCreateLabel("LBL_TP",        "TP Acc. Money",   x,       y); PanelCreateEdit("EDIT_TP",        DoubleToString(g_runtimeTakeProfitMoney, 2),  x+150, y-2); y += row;
   PanelCreateLabel("LBL_MAX_LOSS",  "Max Loss / Trade",x,       y); PanelCreateEdit("EDIT_MAX_LOSS",  DoubleToString(g_runtimeMaxLossMoney, 2),     x+150, y-2); y += row;
   PanelCreateLabel("LBL_SPREAD",    "Max Spread pips", x,       y); PanelCreateEdit("EDIT_SPREAD",    DoubleToString(g_runtimeMaxSpreadPips, 2),    x+150, y-2); y += row;
   y += 4;

   PanelCreateButton("BTN_APPLY",     "Apply",           x,       y, 92, 20, PANEL_BUTTON_BG_COLOR, PANEL_TEXT_COLOR);
   PanelCreateButton("BTN_RESET",     "Reset",           x+100,   y, 92, 20, PANEL_BUTTON_BG_COLOR, PANEL_TEXT_COLOR); y += row + 4;

   PanelCreateCheckbox("CHK_TRADING", "Activate trading", g_runtimeAllowNewTrades,      x, y, 190); y += row + 2;
   PanelCreateCheckbox("CHK_MAX_LOSS", "Max Loss Protection", g_runtimeUseMaxLossMoney,    x, y, 190); y += row + 2;
   PanelCreateCheckbox("CHK_SPREAD",  "Spread filter",     g_runtimeUseMaxSpreadFilter,  x, y, 190); y += row + 2;
   PanelCreateCheckbox("CHK_STRUCTURE_LINES", "Chart structure", g_runtimeShowStructureLines, x, y, 190);
   y += row + 10;
   PanelCreateCheckbox("CHK_PROP_RISK", "Prop Risk", g_runtimePropRiskEnable, x, y, 190); y += row + 2;
   PanelCreateLabel("LBL_PROP_ACCOUNT", "Prop Account Value", x, y);
   PanelCreateEdit("EDIT_PROP_ACCOUNT", DoubleToString(g_runtimePropAccountValue, 2), x+150, y-2); y += row + 8;

   // Tooltips shown by MetaTrader when the user hovers over panel controls.
   PanelSetTooltip("LBL_LOTS",      "Fixed lot size used for new trades.");
   PanelSetTooltip("EDIT_LOTS",     "Fixed lot size used when opening new positions. Must respect the broker's min/max lot and lot step.");

   PanelSetTooltip("LBL_TP",        "Take Profit target in the account currency, not necessarily EUR. Example: 25 means 25 EUR on an EUR account or 25 USD on a USD account.");
   PanelSetTooltip("EDIT_TP",       "Profit target per trade, calculated by MT5 in the account deposit currency.");

   PanelSetTooltip("LBL_MAX_LOSS",  "Emergency maximum loss per trade, calculated in the account currency.");
   PanelSetTooltip("EDIT_MAX_LOSS", "If enabled, the EA force-closes the position when floating loss reaches this amount. Example: 50 means -50 EUR on an EUR account or -50 USD on a USD account. This emergency protection runs independently from regular position management.");

   PanelSetTooltip("LBL_SPREAD",    "Maximum allowed spread in pips. New trades are skipped when the current spread is higher.");
   PanelSetTooltip("EDIT_SPREAD",   "Maximum spread allowed for new entries, expressed in pips.");

   PanelSetTooltip("BTN_APPLY",     "Apply the values from the panel to the runtime settings. EA inputs are not changed.");
   PanelSetTooltip("BTN_RESET",     "Reset runtime settings back to the original EA input values.");
   PanelSetTooltip("BTN_PANEL_X",   "Hide the control panel. The EA continues running.");

   PanelSetTooltip("CHK_TRADING_BOX",   "Enable or disable opening new trades. Existing positions can still be managed if management is enabled.");
   PanelSetTooltip("CHK_TRADING_LABEL", "Enable or disable opening new trades. Existing positions can still be managed if management is enabled.");

   PanelSetTooltip("CHK_MAX_LOSS_BOX",  "Enable emergency max loss protection for open positions. This runs independently from regular position management.");
   PanelSetTooltip("CHK_MAX_LOSS_LABEL",
                "Emergency protection: closes the position when floating loss reaches the configured account-currency amount. Use this as a hard safety limit while keeping the regular Stop Loss wider if needed.");
                
   PanelSetTooltip("CHK_SPREAD_BOX",    "Enable or disable the maximum spread filter for new trades.");
   PanelSetTooltip("CHK_SPREAD_LABEL",  "Enable or disable the maximum spread filter for new trades.");
   PanelSetTooltip("CHK_STRUCTURE_LINES_BOX",   "Show or hide the complete chart structure overlay: HH/HL/LH/LL labels, swing paths and BOS/CHOCH. Default: hidden.");
   PanelSetTooltip("CHK_STRUCTURE_LINES_LABEL", "Show or hide the complete chart structure overlay: HH/HL/LH/LL labels, swing paths and BOS/CHOCH. This is visual only and does not affect trading.");
   PanelSetTooltip("CHK_PROP_RISK_BOX",  "Enable or disable the optional account-level Prop Risk guard. It can block new entries and emergency-close this EA's positions at the configured limits.");
   PanelSetTooltip("CHK_PROP_RISK_LABEL", "Limits are calculated from the Prop Account Value, firm percentages and safety buffers. This does not change the ML signal, lot or TP.");
   PanelSetTooltip("LBL_PROP_ACCOUNT", "Starting value of the prop/evaluation account. Default: 10000.");
   PanelSetTooltip("EDIT_PROP_ACCOUNT", "Account value used to calculate the prop limits. Press Apply after changing it.");

   PanelCreateLabel("STATUS1", "Spread: - | Open profit: -", x, y, 280, 8, clrBlack); y += 17;
   PanelCreateLabel("STATUS2", "Last signal: -",             x, y, 280, 8, clrBlack); y += 17;
   PanelCreateLabel("STATUS3", "Runtime: -",                 x, y, 280, 8, clrBlack); y += 17;
   PanelCreateLabel("STATUS_MOTIF", "Motif: warming up",      x, y, 285, 8, clrBlack); y += 17;
   PanelCreateLabel("STATUS_PROP1", "Prop: -",               x, y, 285, 8, clrBlack); y += 17;
   PanelCreateLabel("STATUS_PROP2", "Prop limits: -",        x, y, 285, 8, clrBlack);

   // Right column replaces legacy research telemetry in the clean Hybrid path.
   if(InpHybridMotifEnable)
   {
      const int hx = g_panelX + PANEL_CONTEXT_X_OFFSET;
      int hy = g_panelY + PANEL_CONTEXT_Y_OFFSET;
      PanelCreateLabel("HYBRID_XGB", "XGBoost: waiting for first M5 close", hx, hy, 280, 8, clrBlack); hy += 18;
      PanelCreateLabel("HYBRID_THRESH", StringFormat("Thresholds: B %.2f | S %.2f | gap %.2f",
         g_runtimeMinBuyProb, g_runtimeMinSellProb, g_runtimeMinDecisionGap), hx, hy, 280, 8, clrBlack); hy += 18;
      PanelCreateLabel("HYBRID_MOTIF", "Motif: hourly engine warming up", hx, hy, 280, 8, clrBlack); hy += 18;
      PanelCreateLabel("HYBRID_SCORE", "Motif score: -", hx, hy, 280, 8, clrBlack); hy += 18;
      PanelCreateLabel("HYBRID_RISK", StringFormat("Risk mult: HIGH %.2f | MED %.2f | LOW %.2f",
         InpHybridHighQualityLotMultiplier, InpHybridMediumQualityLotMultiplier,
         InpHybridLowQualityLotMultiplier), hx, hy, 280, 8, clrBlack); hy += 18;
      PanelCreateLabel("HYBRID_RULE", "Direction: XGBoost | Motif: quality/risk", hx, hy, 280, 8, clrDarkGreen, true);
   }

   PanelRefreshControls();
   g_panelCreated = true;
   ChartRedraw(0);
   Print("PanelCreate: control panel created successfully.");
}

//+------------------------------------------------------------------+
//| PanelPointInsideHeader
//| Verifică dacă mouse-ul este pe bara de titlu a panelului.
//+------------------------------------------------------------------+
bool PanelPointInsideHeader(const int mouseX, const int mouseY)
{
   return (mouseX >= g_panelX && mouseX <= g_panelX + g_panelW &&
           mouseY >= g_panelY && mouseY <= g_panelY + 24);
}

//+------------------------------------------------------------------+
//| PanelMoveBy
//| Mută toate obiectele panelului fără să le recreeze.
//+------------------------------------------------------------------+
void PanelMoveBy(const int dx, const int dy)
{
   if(dx == 0 && dy == 0)
      return;

   int total = ObjectsTotal(0, -1, -1);
   for(int i = total - 1; i >= 0; --i)
   {
      string name = ObjectName(0, i, -1, -1);
      if(StringFind(name, PANEL_PREFIX) != 0 &&
         StringFind(name, PANEL_CONTEXT_PREFIX) != 0)
         continue;

      int oldX = (int)ObjectGetInteger(0, name, OBJPROP_XDISTANCE);
      int oldY = (int)ObjectGetInteger(0, name, OBJPROP_YDISTANCE);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, oldX + dx);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, oldY + dy);
   }
}

//+------------------------------------------------------------------+
//| PanelHandleMouseMove
//| Mută panelul cu mouse-ul prin drag pe bara de sus.
//+------------------------------------------------------------------+
void PanelHandleMouseMove(const long &lparam, const double &dparam, const string &sparam)
{
   if(!InpShowControlPanel || !g_panelVisible || !g_panelCreated)
      return;

   int mouseX = (int)lparam;
   int mouseY = (int)dparam;
   int buttons = (int)StringToInteger(sparam);
   bool leftDown = ((buttons & 1) == 1);

   if(!leftDown)
   {
      g_panelDragging = false;
      return;
   }

   if(!g_panelDragging)
   {
      if(!PanelPointInsideHeader(mouseX, mouseY))
         return;

      g_panelDragging = true;
      g_panelDragOffsetX = mouseX - g_panelX;
      g_panelDragOffsetY = mouseY - g_panelY;
   }

   int newX = MathMax(0, mouseX - g_panelDragOffsetX);
   int newY = MathMax(0, mouseY - g_panelDragOffsetY);
   int dx = newX - g_panelX;
   int dy = newY - g_panelY;

   g_panelX = newX;
   g_panelY = newY;
   PanelMoveBy(dx, dy);
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| PanelUpdateStatus
//| Actualizează statusul live: spread, profit, ultimul semnal și setări runtime.
//+------------------------------------------------------------------+
void PanelUpdateStatus()
{
   if(!InpShowControlPanel || !g_panelVisible || !g_panelCreated)
      return;

   double pip = PipSize();
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double spreadPips = 0.0;
   if(pip > 0.0 && ask > 0.0 && bid > 0.0)
      spreadPips = (ask - bid) / pip;

   double profit = PanelGetOpenProfitMoney();

   PanelSetText("STATUS1", StringFormat("Spread: %.2f pips | Open profit: %.2f", spreadPips, profit));
   PanelSetText("STATUS2", StringFormat("Last: %s | S %.2f H %.2f B %.2f | reg %.5f",
                                         PanelDecisionText(g_panelLastDecision),
                                         g_panelLastSellProb,
                                         g_panelLastHoldProb,
                                         g_panelLastBuyProb,
                                         g_panelLastRegPred));
   if(InpHybridMotifEnable)
   {
      PanelSetText("HYBRID_XGB", StringFormat("XGBoost: %s | S %.3f H %.3f B %.3f",
         PanelDecisionText(g_panelLastDecision), g_panelLastSellProb,
         g_panelLastHoldProb, g_panelLastBuyProb));
      PanelSetText("HYBRID_THRESH", StringFormat("Thresholds: B %.2f | S %.2f | gap %.2f",
         g_runtimeMinBuyProb, g_runtimeMinSellProb, g_runtimeMinDecisionGap));
      if(g_hybridMotifLast.valid)
      {
         const double hybridPanelAge = (double)(TimeCurrent()-g_hybridMotifLast.anchorTime)/60.0;
         PanelSetText("HYBRID_MOTIF", StringFormat("Motif: %s | age %.0fm | HIGH %s",
            (g_hybridMotifLast.direction > 0 ? "BUY" :
             (g_hybridMotifLast.direction < 0 ? "SELL" : "NONE")),
            hybridPanelAge, (g_hybridMotifLast.strong ? "YES" : "NO")));
         PanelSetText("HYBRID_SCORE", StringFormat("Motif: conf %.3f | netATR %.3f | ratio %.2f",
            g_hybridMotifLast.confidence, g_hybridMotifLast.expectedNetATR,
            g_hybridMotifLast.grossToCostRatio));
      }
   }
   PanelSetText("STATUS3", StringFormat("Runtime: lot %.2f | TP %.2f | MLoss %.2f | spr %.2f",
                                         g_runtimeLots,
                                         g_runtimeTakeProfitMoney,
                                         g_runtimeMaxLossMoney,
                                         g_runtimeMaxSpreadPips));

   if(!InpHybridMotifEnable)
      PanelSetText("STATUS_MOTIF", "Motif risk: OFF | XGBoost baseline path");
   else if(!g_hybridMotifLast.valid)
      PanelSetText("STATUS_MOTIF", "Motif risk: warming up / no hourly snapshot");
   else
   {
      const double motifAge = (double)(TimeCurrent() - g_hybridMotifLast.anchorTime) / 60.0;
      PanelSetText("STATUS_MOTIF", StringFormat("Motif: %s | age %.0fm | conf %.2f | net %.2f",
         (g_hybridMotifLast.direction > 0 ? "BUY" :
          (g_hybridMotifLast.direction < 0 ? "SELL" : "NONE")),
         motifAge, g_hybridMotifLast.confidence, g_hybridMotifLast.expectedNetATR));
   }

   if(!g_runtimePropRiskEnable)
   {
      const double dailySafe =
         MathMax(0.0, g_runtimePropAccountValue * InpPropFirmDailyLossLimitPct / 100.0 -
                      InpPropDailySafetyBufferMoney);
      const double totalSafe =
         MathMax(0.0, g_runtimePropAccountValue * InpPropFirmTotalLossLimitPct / 100.0 -
                      InpPropTotalSafetyBufferMoney);
      PanelSetText("STATUS_PROP1", StringFormat("Prop: OFF | Account %.2f", g_runtimePropAccountValue));
      PanelSetText("STATUS_PROP2", StringFormat("Safe limits: day %.2f | total %.2f | loss seq %d",
                                                dailySafe,
                                                totalSafe,
                                                InpPropMaxConsecutiveLosses));
   }
   else
   {
      PropRiskRefresh(false);
      const string propMode = (g_propRiskDailyLocked || g_propRiskTotalLocked ? "LOCKED" : "ON");
      PanelSetText("STATUS_PROP1", StringFormat("Prop: %s | Daily DD %.2f / %.2f",
                                                propMode,
                                                g_propRiskDailyLossMoney,
                                                g_propRiskDailyLimitMoney));
      PanelSetText("STATUS_PROP2", StringFormat("Total DD %.2f / %.2f | loss seq %d / %d",
                                                g_propRiskTotalLossMoney,
                                                g_propRiskTotalLimitMoney,
                                                g_propRiskConsecutiveLosses,
                                                InpPropMaxConsecutiveLosses));
   }
}

//+------------------------------------------------------------------+
//| PanelHandleEvent
//| Tratează evenimentele de click și drag din panel.
//+------------------------------------------------------------------+
void PanelHandleEvent(const int id,
                      const long &lparam,
                      const double &dparam,
                      const string &sparam)
{
   if(!InpShowControlPanel || !g_panelVisible)
      return;

   if(id == CHARTEVENT_MOUSE_MOVE)
   {
      PanelHandleMouseMove(lparam, dparam, sparam);
      return;
   }

   if(StringFind(sparam, PANEL_PREFIX) != 0)
      return;

   string obj = StringSubstr(sparam, StringLen(PANEL_PREFIX));

   if(id != CHARTEVENT_OBJECT_CLICK)
      return;

   if(obj == "BTN_PANEL_X")
   {
      g_panelVisible = false;
      PanelDestroy();
      ChartRedraw(0);
      return;
   }
   else if(obj == "BTN_APPLY")
      PanelApplyRuntimeFromEdits();
   else if(obj == "BTN_RESET")
      PanelResetRuntimeToInputs();
   else if(StringFind(obj, "CHK_TRADING") == 0)
      g_runtimeAllowNewTrades = !g_runtimeAllowNewTrades;
   else if(StringFind(obj, "CHK_MAX_LOSS") == 0)
      g_runtimeUseMaxLossMoney = !g_runtimeUseMaxLossMoney;
   else if(StringFind(obj, "CHK_SPREAD") == 0)
      g_runtimeUseMaxSpreadFilter = !g_runtimeUseMaxSpreadFilter;
   else if(StringFind(obj, "CHK_PROP_RISK") == 0)
   {
      const bool enablePropRisk = !g_runtimePropRiskEnable;
      if(enablePropRisk)
      {
         const double requestedPropAccount =
            PanelGetDouble("EDIT_PROP_ACCOUNT", g_runtimePropAccountValue);
         if(PropRiskSetRuntimeAccountValue(requestedPropAccount, "PANEL_CHECKBOX"))
            PropRiskSetRuntimeEnabled(true, "PANEL_CHECKBOX");
      }
      else
         PropRiskSetRuntimeEnabled(false, "PANEL_CHECKBOX");
   }
   else if(StringFind(obj, "CHK_STRUCTURE_LINES") == 0)
   {
      g_runtimeShowStructureLines = !g_runtimeShowStructureLines;
      g_panelStructureLinesRefreshRequested = true;
   }

   PanelRefreshControls();
   PanelUpdateStatus();
   ChartRedraw(0);
}

#endif // __EA_ML_M5_PANEL_MQH__
