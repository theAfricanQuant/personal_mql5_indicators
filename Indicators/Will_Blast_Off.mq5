//+------------------------------------------------------------------+
//|                                               Will_Blast_Off.mq5 |
//|                                             Ricky Macharm, MScFE |
//|                                         https://www.SisengAI.com |
//+------------------------------------------------------------------+
#property copyright "Ricky Macharm, MScFE"
#property link      "https://www.SisengAI.com"
#property version   "1.03"
#property indicator_separate_window
#property indicator_buffers 3
#property indicator_plots   1

//--- plot Will_Blast_Off
#property indicator_label1  "Will_Blast_Off"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- input parameters
input int X_Days = 1; // Period for moving averages

//--- indicator buffers
double WillBlastOffBuffer[];
double BodySizeBuffer[];
double TrueRangeBuffer[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
//--- indicator buffers mapping
   SetIndexBuffer(0, WillBlastOffBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, BodySizeBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(2, TrueRangeBuffer, INDICATOR_CALCULATIONS);
   
//--- set index style
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, X_Days);
   
//--- set index labels
   PlotIndexSetString(0, PLOT_LABEL, "Will_Blast_Off(" + IntegerToString(X_Days) + ")");
   
//--- set indicator name
   IndicatorSetString(INDICATOR_SHORTNAME, "Will_Blast_Off(" + IntegerToString(X_Days) + ")");
   
//--- set indicator digits
   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   
//--- check for input parameter
   if(X_Days <= 0)
   {
      Print("Error: X_Days must be greater than 0");
      return(INIT_PARAMETERS_INCORRECT);
   }
   
//--- set timer to force updates every 5 seconds
   EventSetTimer(5);
   
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
//--- check for minimum bars
   if(rates_total < X_Days + 1)
      return(0);

//--- determine starting position for calculations
   int start = prev_calculated - 1;
   if(prev_calculated == 0)
   {
      start = 0;
      // Initialize buffers
      ArrayInitialize(WillBlastOffBuffer, EMPTY_VALUE);
      ArrayInitialize(BodySizeBuffer, 0.0);
      ArrayInitialize(TrueRangeBuffer, 0.0);
   }
   
   // Ensure we don't go below 0
   if(start < 0) start = 0;

//--- calculate Body Size and True Range for all bars from start position
   for(int i = start; i < rates_total; i++)
   {
      // Calculate Body Size: Abs(Close - Open)
      BodySizeBuffer[i] = MathAbs(close[i] - open[i]);
      
      // Calculate True Range
      if(i == 0)
      {
         // First bar: TR = High - Low
         TrueRangeBuffer[i] = high[i] - low[i];
      }
      else
      {
         double hl = high[i] - low[i];
         double hc = MathAbs(high[i] - close[i-1]);
         double lc = MathAbs(low[i] - close[i-1]);
         TrueRangeBuffer[i] = MathMax(hl, MathMax(hc, lc));
      }
   }

//--- calculate indicator values
   for(int i = MathMax(start, X_Days - 1); i < rates_total; i++)
   {
      // Calculate Moving Average of Body Size
      double sum_body = 0.0;
      for(int j = 0; j < X_Days; j++)
      {
         if(i - j >= 0)
            sum_body += BodySizeBuffer[i - j];
      }
      double ma_body = sum_body / X_Days;
      
      // Calculate Moving Average of True Range
      double sum_tr = 0.0;
      for(int j = 0; j < X_Days; j++)
      {
         if(i - j >= 0)
            sum_tr += TrueRangeBuffer[i - j];
      }
      double ma_tr = sum_tr / X_Days;
      
      // Calculate final indicator value
      if(ma_tr > 0.0)
      {
         WillBlastOffBuffer[i] = (ma_body / ma_tr) * 100.0;
      }
      else
      {
         WillBlastOffBuffer[i] = 0.0;
      }
   }

//--- force chart redraw on every calculation
   ChartRedraw();

//--- return value of prev_calculated for next call
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Timer function to force regular updates                         |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Force indicator recalculation
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Deinitialization function                                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clean up timer
   EventKillTimer();
}
//+------------------------------------------------------------------+