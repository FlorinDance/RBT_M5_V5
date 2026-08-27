// Auto-generated wrapper for local M5 XGBoost

#ifndef __XGB_M5_WRAPPER_MQH__
#define __XGB_M5_WRAPPER_MQH__

#include "XGB_M5_Classifier.mqh"

#include "XGB_M5_Regressor.mqh"

static const double M5_MEDIANS[22] = {
      50.2120484955560471, 0.00000501598993785, 0.00000468842582132, 0.00000028682934531, 1.11786079006932937, 0.0003553559834057,
      194, 22.22217102763934804, 2.93742706613851334, 51.61290322583533197, 0.00001000000000007, -47.99999999998682654,
      1.11881727093453343, 1.11804024999999996, 1.11716797062451478, 1.11711000000000005, 1.11888999999999994, 2.14205852268243646,
      1.9789746526824441, 0, 0, 0.00000861382087817
   };

void M5_BuildFeatureVectorFromServerStyle(
   double RSI,
   double MACD,
   double MACD_signal,
   double MACD_hist,
   double EMA,
   double ATR,
   double Volume,
   double ADX,
   double CCI,
   double Stochastic,
   double Momentum,
   double Williams_R,
   double Bollinger_upper,
   double Bollinger_middle,
   double Bollinger_lower,
   double SR_support,
   double SR_resistance,
   double Dist_to_support_ATR,
   double Dist_to_resistance_ATR,
   double Ret_1,
   double Ret_3,
   double Ret_12,
   double &f[])
  {
   ArrayResize(f, 22);
   f[0]  = RSI;
   f[1]  = MACD;
   f[2]  = MACD_signal;
   f[3]  = MACD_hist;
   f[4]  = EMA;
   f[5]  = ATR;
   f[6]  = Volume;
   f[7]  = ADX;
   f[8]  = CCI;
   f[9]  = Stochastic;
   f[10] = Momentum;
   f[11] = Williams_R;
   f[12] = Bollinger_upper;
   f[13] = Bollinger_middle;
   f[14] = Bollinger_lower;
   f[15] = SR_support;
   f[16] = SR_resistance;
   f[17] = Dist_to_support_ATR;
   f[18] = Dist_to_resistance_ATR;
   f[19] = Ret_1;
   f[20] = Ret_3;
   f[21] = Ret_12;
  }

void M5_ApplyMedians(double &f[])
  {
   int n = ArraySize(f);
   if(n < 22) return;
   for(int i=0; i<22; i++)
     {
      if(!MathIsValidNumber(f[i]))
         f[i] = M5_MEDIANS[i];
     }
  }

#endif