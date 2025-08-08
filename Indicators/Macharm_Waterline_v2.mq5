//+------------------------------------------------------------------+
//|                                        Macharm_Waterline_v2.mq5 |
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
#property indicator_label1  "Waterline v2"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrBurlyWood
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

//--- Indicator levels
#property indicator_level1 1.5
#property indicator_levelcolor clrDimGray
#property indicator_levelstyle STYLE_DOT

//--- Input parameters
input int     SS1_Period = 10;          // Super Smoother 1 Period
input int     SS2_Period = 25;          // Super Smoother 2 Period
input int     SS3_Period = 72;          // Super Smoother 3 Period
input int     SS4_Period = 200;         // Super Smoother 4 Period
input int     ATR_Period = 14;          // ATR Period

//--- Indicator buffers
double WaterlineBuffer[];

//--- Super Smoother buffers (internal calculations)
double SS1_Buffer[], SS2_Buffer[], SS3_Buffer[], SS4_Buffer[];

//--- Handles for indicators
int ATR_Handle;

//--- Super Smoother coefficients
double a1_1, b1_1, c1_1, c2_1, c3_1;  // SS1 coefficients
double a1_2, b1_2, c1_2, c2_2, c3_2;  // SS2 coefficients  
double a1_3, b1_3, c1_3, c2_3, c3_3;  // SS3 coefficients
double a1_4, b1_4, c1_4, c2_4, c3_4;  // SS4 coefficients
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Indicator buffers mapping
   SetIndexBuffer(0, WaterlineBuffer, INDICATOR_DATA);
   
   //--- Set empty values
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
   //--- Create handle for ATR
   ATR_Handle = iATR(Symbol(), PERIOD_CURRENT, ATR_Period);
   
   //--- Check if handle is valid
   if(ATR_Handle == INVALID_HANDLE)
   {
      Print("Error creating ATR handle");
      return(INIT_FAILED);
   }
   
   //--- Initialize Super Smoother coefficients
   InitSuperSmoother(SS1_Period, a1_1, b1_1, c1_1, c2_1, c3_1);
   InitSuperSmoother(SS2_Period, a1_2, b1_2, c1_2, c2_2, c3_2);
   InitSuperSmoother(SS3_Period, a1_3, b1_3, c1_3, c2_3, c3_3);
   InitSuperSmoother(SS4_Period, a1_4, b1_4, c1_4, c2_4, c3_4);
   
   //--- Resize Super Smoother buffers
   ArrayResize(SS1_Buffer, Bars(Symbol(), PERIOD_CURRENT));
   ArrayResize(SS2_Buffer, Bars(Symbol(), PERIOD_CURRENT));
   ArrayResize(SS3_Buffer, Bars(Symbol(), PERIOD_CURRENT));
   ArrayResize(SS4_Buffer, Bars(Symbol(), PERIOD_CURRENT));
   
   //--- Set indicator name
   IndicatorSetString(INDICATOR_SHORTNAME, "Macharm Waterline v2");
   
   //--- Set precision
   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Initialize Super Smoother coefficients                          |
//+------------------------------------------------------------------+
void InitSuperSmoother(int period, double &a1, double &b1, double &c1, double &c2, double &c3)
{
   double pi = 3.14159265359;
   double sqrt2 = 1.41421356237;
   
   a1 = MathExp(-sqrt2 * pi / period);
   b1 = 2.0 * a1 * MathCos(sqrt2 * pi / period);
   c2 = b1;
   c3 = -a1 * a1;
   c1 = 1.0 - c2 - c3;
}

//+------------------------------------------------------------------+
//| Calculate Super Smoother value                                  |
//+------------------------------------------------------------------+
double CalculateSuperSmoother(double price, int index, double &buffer[], 
                             double c1, double c2, double c3)
{
   if(index < 2)
   {
      buffer[index] = price;
      return price;
   }
   
   buffer[index] = c1 * price + c2 * buffer[index-1] + c3 * buffer[index-2];
   return buffer[index];
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
   int max_period = MathMax(MathMax(SS1_Period, SS2_Period), MathMax(SS3_Period, SS4_Period));
   max_period = MathMax(max_period, ATR_Period);
   
   if(rates_total < max_period)
      return(0);
   
   //--- Calculate starting position
   int start = MathMax(prev_calculated - 1, max_period);
   if(start < max_period) start = max_period;
   
   //--- Resize buffers if needed
   if(ArraySize(SS1_Buffer) < rates_total)
   {
      ArrayResize(SS1_Buffer, rates_total);
      ArrayResize(SS2_Buffer, rates_total);
      ArrayResize(SS3_Buffer, rates_total);
      ArrayResize(SS4_Buffer, rates_total);
   }
   
   //--- Get data from ATR
   double atr[];
   if(CopyBuffer(ATR_Handle, 0, 0, rates_total, atr) <= 0) return(0);
   
   //--- Main calculation loop
   for(int i = start; i < rates_total; i++)
   {
      //--- Calculate Super Smoother values
      double ss1 = CalculateSuperSmoother(close[i], i, SS1_Buffer, c1_1, c2_1, c3_1);
      double ss2 = CalculateSuperSmoother(close[i], i, SS2_Buffer, c1_2, c2_2, c3_2);
      double ss3 = CalculateSuperSmoother(close[i], i, SS3_Buffer, c1_3, c2_3, c3_3);
      double ss4 = CalculateSuperSmoother(close[i], i, SS4_Buffer, c1_4, c2_4, c3_4);
      
      //--- Safety check for ATR
      if(atr[i] <= 0)
      {
         WaterlineBuffer[i] = EMPTY_VALUE;
         continue;
      }
      
      //--- Find highest and lowest Super Smoother values
      double ss_values[4];
      ss_values[0] = ss1;
      ss_values[1] = ss2;
      ss_values[2] = ss3;
      ss_values[3] = ss4;
      
      //--- Find min and max SS values
      double max_ss = ss_values[0];
      double min_ss = ss_values[0];
      
      for(int j = 1; j < 4; j++)
      {
         if(ss_values[j] > max_ss) max_ss = ss_values[j];
         if(ss_values[j] < min_ss) min_ss = ss_values[j];
      }
      
      //--- Calculate Waterline v2: (Highest SS - Lowest SS) / ATR
      WaterlineBuffer[i] = (max_ss - min_ss) / atr[i];
   }
   
   return(rates_total);
}
//+------------------------------------------------------------------+
