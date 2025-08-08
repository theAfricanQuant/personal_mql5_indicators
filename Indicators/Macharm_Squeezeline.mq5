//+------------------------------------------------------------------+
//|                                          Macharm_Squeezeline.mq5 |
//|                                             Ricky Macharm, MScFE |
//|                                         https://www.SisengAI.com |
//+------------------------------------------------------------------+
#property copyright "Ricky Macharm, MScFE"
#property link      "https://www.SisengAI.com"
#property version   "1.00"
#property indicator_separate_window

#property indicator_buffers 2
#property indicator_plots   1

//--- Plot 1: Squeezeline Histogram
#property indicator_label1  "Squeezeline"
#property indicator_type1   DRAW_COLOR_HISTOGRAM
#property indicator_color1  clrBurlyWood,clrMaroon
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

//--- Indicator levels
#property indicator_level1 2.5
#property indicator_levelcolor clrDimGray
#property indicator_levelstyle STYLE_DOT

//--- Input parameters
input int     BB_Period = 20;           // Bollinger Bands Period
input double  BB_Deviation = 2.0;       // Bollinger Bands Deviation
input int     ATR_Period = 14;          // ATR Period
input double  SqueezeLevel = 2.5;       // Squeeze level threshold (color changes when <= this value)

//--- Indicator buffers
double SqueezelineBuffer[];
double ColorBuffer[];

//--- Handles for indicators
int BB_Handle, ATR_Handle;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Indicator buffers mapping
   SetIndexBuffer(0, SqueezelineBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, ColorBuffer, INDICATOR_COLOR_INDEX);
   
   //--- Set empty values
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
   //--- Create handles for Bollinger Bands and ATR
   BB_Handle = iBands(Symbol(), PERIOD_CURRENT, BB_Period, 0, BB_Deviation, PRICE_CLOSE);
   ATR_Handle = iATR(Symbol(), PERIOD_CURRENT, ATR_Period);
   
   //--- Check if handles are valid
   if(BB_Handle == INVALID_HANDLE || ATR_Handle == INVALID_HANDLE)
   {
      Print("Error creating indicator handles");
      return(INIT_FAILED);
   }
   
   //--- Set indicator name
   IndicatorSetString(INDICATOR_SHORTNAME, "Macharm Squeezeline");
   
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
   int max_period = MathMax(BB_Period, ATR_Period);
   
   if(rates_total < max_period)
      return(0);
   
   //--- Calculate starting position
   int start = MathMax(prev_calculated - 1, max_period);
   if(start < max_period) start = max_period;
   
   //--- Get data from indicators
   double bb_upper[], bb_lower[], atr[];
   
   //--- Copy data from indicators
   // Bollinger Bands: 0=middle, 1=upper, 2=lower
   if(CopyBuffer(BB_Handle, 1, 0, rates_total, bb_upper) <= 0) return(0);  // Upper band
   if(CopyBuffer(BB_Handle, 2, 0, rates_total, bb_lower) <= 0) return(0);  // Lower band
   if(CopyBuffer(ATR_Handle, 0, 0, rates_total, atr) <= 0) return(0);
   
   //--- Main calculation loop
   for(int i = start; i < rates_total; i++)
   {
      //--- Safety check for ATR
      if(atr[i] <= 0)
      {
         SqueezelineBuffer[i] = EMPTY_VALUE;
         ColorBuffer[i] = 0; // Default color
         continue;
      }
      
      //--- Calculate Squeezeline: (Upper BB - Lower BB) / ATR
      SqueezelineBuffer[i] = (bb_upper[i] - bb_lower[i]) / atr[i];
      
      //--- Determine color based on squeeze level
      if(SqueezelineBuffer[i] <= SqueezeLevel)
      {
         ColorBuffer[i] = 1; // Maroon color when in squeeze (equal to or below squeeze level)
      }
      else
      {
         ColorBuffer[i] = 0; // BurlyWood color when expanded (above squeeze level)
      }
   }
   
   return(rates_total);
}
//+------------------------------------------------------------------+
