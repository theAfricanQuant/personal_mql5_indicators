//+------------------------------------------------------------------+
//|                                            Commercial_Proxy.mq5 |
//|                                             Ricky Macharm, MScFE |
//|                                         https://www.SisengAI.com |
//+------------------------------------------------------------------+
#property copyright "Ricky Macharm, MScFE"
#property link      "https://www.SisengAI.com"
#property version   "1.00"
#property indicator_separate_window

#property indicator_buffers 1
#property indicator_plots   1

//--- Plot 1: Commercial Proxy Index
#property indicator_label1  "Commercial Proxy"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrBurlyWood
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Indicator levels
#property indicator_level1 30
#property indicator_level2 50
#property indicator_level3 70
#property indicator_levelcolor clrDimGray
#property indicator_levelstyle STYLE_DOT

//--- Input parameters
input int     Commercial_Period = 8;          // Period for Super Smoother

//--- Indicator buffers
double Commercial_Proxy_Buffer[];

//--- Internal calculation buffers
double Open_Close_Diff[];
double Range_Values[];

//--- Super Smoother coefficients (used when enabled)
double a1, b1, c1, c2, c3;

//--- Super Smoother internal buffers
double SS_OC_Buffer[], SS_Range_Buffer[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Indicator buffers mapping
   SetIndexBuffer(0, Commercial_Proxy_Buffer, INDICATOR_DATA);
   
   //--- Set empty values
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
   //--- Initialize Super Smoother coefficients
   InitSuperSmoother(Commercial_Period, a1, b1, c1, c2, c3);
   
   //--- Resize Super Smoother buffers
   ArrayResize(SS_OC_Buffer, Bars(Symbol(), PERIOD_CURRENT));
   ArrayResize(SS_Range_Buffer, Bars(Symbol(), PERIOD_CURRENT));
   
   //--- Resize internal buffers
   ArrayResize(Open_Close_Diff, Bars(Symbol(), PERIOD_CURRENT));
   ArrayResize(Range_Values, Bars(Symbol(), PERIOD_CURRENT));
   
   //--- Set indicator name
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("Commercial Proxy(%d,SuperSmoother)", Commercial_Period));
   
   //--- Set precision
   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   
   //--- Set indicator range
   IndicatorSetDouble(INDICATOR_MINIMUM, 0);
   IndicatorSetDouble(INDICATOR_MAXIMUM, 100);
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Initialize Super Smoother coefficients                          |
//+------------------------------------------------------------------+
void InitSuperSmoother(int period, double &out_a1, double &out_b1, double &out_c1, double &out_c2, double &out_c3)
{
   double pi = 3.14159265359;
   double sqrt2 = 1.41421356237;
   
   out_a1 = MathExp(-sqrt2 * pi / period);
   out_b1 = 2.0 * out_a1 * MathCos(sqrt2 * pi / period);
   out_c2 = out_b1;
   out_c3 = -out_a1 * out_a1;
   out_c1 = 1.0 - out_c2 - out_c3;
}

//+------------------------------------------------------------------+
//| Calculate Super Smoother value                                  |
//+------------------------------------------------------------------+
double CalculateSuperSmoother(double value, int index, double &buffer[], 
                             double coeff_c1, double coeff_c2, double coeff_c3)
{
   if(index < 2)
   {
      buffer[index] = value;
      return value;
   }
   
   buffer[index] = coeff_c1 * value + coeff_c2 * buffer[index-1] + coeff_c3 * buffer[index-2];
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
   if(rates_total < Commercial_Period + 2)
      return(0);
   
   //--- Calculate starting position
   int start = MathMax(prev_calculated - 1, 0);
   if(start < 0) start = 0;
   
   //--- Resize buffers if needed
   if(ArraySize(Open_Close_Diff) < rates_total)
   {
      ArrayResize(Open_Close_Diff, rates_total);
      ArrayResize(Range_Values, rates_total);
      ArrayResize(SS_OC_Buffer, rates_total);
      ArrayResize(SS_Range_Buffer, rates_total);
   }
   
   //--- Calculate raw values for all bars
   for(int i = start; i < rates_total; i++)
   {
      //--- Calculate Open - Close difference
      Open_Close_Diff[i] = close[i] - open[i];
      
      //--- Calculate Range (High - Low)
      Range_Values[i] = high[i] - low[i];
   }
   
   //--- Calculate moving averages and final Commercial Proxy Index
   for(int i = MathMax(start, Commercial_Period - 1); i < rates_total; i++)
   {
      //--- Use Super Smoother
      double ma_oc = CalculateSuperSmoother(Open_Close_Diff[i], i, SS_OC_Buffer, c1, c2, c3);
      double ma_range = CalculateSuperSmoother(Range_Values[i], i, SS_Range_Buffer, c1, c2, c3);
      
      //--- Calculate Commercial Proxy Index: MA(Open-Close) / MA(Range) * 50 + 50
      if(ma_range > 0)
      {
         Commercial_Proxy_Buffer[i] = (ma_oc / ma_range) * 50.0 + 50.0;
      }
      else
      {
         Commercial_Proxy_Buffer[i] = 50.0; // Neutral value when range is zero
      }
   }
   
   return(rates_total);
}
//+------------------------------------------------------------------+
