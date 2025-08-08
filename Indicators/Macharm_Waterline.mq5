//+------------------------------------------------------------------+
//|                                            Macharm_Waterline.mq5 |
//|                                             Ricky Macharm, MScFE |
//|                                         https://www.SisengAI.com |
//+------------------------------------------------------------------+
#property copyright "Ricky Macharm, MScFE"
#property link      "https://www.SisengAI.com"
#property version   "1.00"
#property indicator_separate_window

#property indicator_buffers 1
#property indicator_plots   1

//--- Plot 1: Main Waterline Oscillator
#property indicator_label1  "Waterline"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrBurlyWood
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

//--- Indicator levels
#property indicator_level1 1.5
#property indicator_levelcolor clrDimGray
#property indicator_levelstyle STYLE_DOT

//--- Input parameters
input int     EMA1_Period = 10;         // EMA 1 Period
input int     EMA2_Period = 25;         // EMA 2 Period
input int     EMA3_Period = 72;         // EMA 3 Period
input int     EMA4_Period = 200;        // EMA 4 Period
input int     ATR_Period = 14;          // ATR Period

//--- Indicator buffers
double WaterlineBuffer[];

//--- Handles for indicators
int EMA1_Handle, EMA2_Handle, EMA3_Handle, EMA4_Handle, ATR_Handle;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Indicator buffers mapping
   SetIndexBuffer(0, WaterlineBuffer, INDICATOR_DATA);
   
   //--- Set empty values
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
   //--- Create handles for EMAs and ATR
   EMA1_Handle = iMA(Symbol(), PERIOD_CURRENT, EMA1_Period, 0, MODE_EMA, PRICE_CLOSE);
   EMA2_Handle = iMA(Symbol(), PERIOD_CURRENT, EMA2_Period, 0, MODE_EMA, PRICE_CLOSE);
   EMA3_Handle = iMA(Symbol(), PERIOD_CURRENT, EMA3_Period, 0, MODE_EMA, PRICE_CLOSE);
   EMA4_Handle = iMA(Symbol(), PERIOD_CURRENT, EMA4_Period, 0, MODE_EMA, PRICE_CLOSE);
   ATR_Handle = iATR(Symbol(), PERIOD_CURRENT, ATR_Period);
   
   //--- Check if handles are valid
   if(EMA1_Handle == INVALID_HANDLE || EMA2_Handle == INVALID_HANDLE || 
      EMA3_Handle == INVALID_HANDLE || EMA4_Handle == INVALID_HANDLE || 
      ATR_Handle == INVALID_HANDLE)
   {
      Print("Error creating indicator handles");
      return(INIT_FAILED);
   }
   
   //--- Set indicator name
   IndicatorSetString(INDICATOR_SHORTNAME, "Macharm Waterline");
   
   //--- Set precision
   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   //--- Check if we have enough data
   int max_period = MathMax(MathMax(EMA1_Period, EMA2_Period), MathMax(EMA3_Period, EMA4_Period));
   max_period = MathMax(max_period, ATR_Period);
   
   if(rates_total < max_period)
      return(0);
   
   //--- Calculate starting position
   int start = MathMax(prev_calculated - 1, max_period);
   if(start < max_period) start = max_period;
   
   //--- Get data from indicators
   double ema1[], ema2[], ema3[], ema4[], atr[];
   
   //--- Copy data from indicators
   if(CopyBuffer(EMA1_Handle, 0, 0, rates_total, ema1) <= 0) return(0);
   if(CopyBuffer(EMA2_Handle, 0, 0, rates_total, ema2) <= 0) return(0);
   if(CopyBuffer(EMA3_Handle, 0, 0, rates_total, ema3) <= 0) return(0);
   if(CopyBuffer(EMA4_Handle, 0, 0, rates_total, ema4) <= 0) return(0);
   if(CopyBuffer(ATR_Handle, 0, 0, rates_total, atr) <= 0) return(0);
   
   //--- Main calculation loop
   for(int i = start; i < rates_total; i++)
   {
      //--- Safety check for ATR
      if(atr[i] <= 0)
      {
         WaterlineBuffer[i] = EMPTY_VALUE;
         continue;
      }
      
      //--- Find highest and lowest EMA values at current bar
      double ema_values[4];
      ema_values[0] = ema1[i];
      ema_values[1] = ema2[i];
      ema_values[2] = ema3[i];
      ema_values[3] = ema4[i];
      
      //--- Find min and max EMA values
      double max_ema = ema_values[0];
      double min_ema = ema_values[0];
      
      for(int j = 1; j < 4; j++)
      {
         if(ema_values[j] > max_ema) max_ema = ema_values[j];
         if(ema_values[j] < min_ema) min_ema = ema_values[j];
      }
      
      //--- Calculate Waterline: (Highest EMA - Lowest EMA) / ATR
      WaterlineBuffer[i] = (max_ema - min_ema) / atr[i];
   }
   
   return(rates_total);
}
//+------------------------------------------------------------------+
