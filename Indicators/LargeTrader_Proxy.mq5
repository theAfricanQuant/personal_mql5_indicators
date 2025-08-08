//+------------------------------------------------------------------+
//|                                           LargeTrader_Proxy.mq5 |
//|                                             Ricky Macharm, MScFE |
//|                                         https://www.SisengAI.com |
//+------------------------------------------------------------------+
#property copyright "Ricky Macharm, MScFE"
#property link      "https://www.SisengAI.com"
#property version   "1.00"
#property indicator_separate_window

#property indicator_buffers 1
#property indicator_plots   1

//--- Plot 1: LargeTrader Proxy Histogram
#property indicator_label1  "LargeTrader Proxy"
#property indicator_type1   DRAW_HISTOGRAM
#property indicator_color1  clrBurlyWood
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Indicator levels
#property indicator_level1 0
#property indicator_levelcolor clrDimGray
#property indicator_levelstyle STYLE_DOT

//--- Input parameters
input int     LargeTrader_Period = 40;        // Period for Super Smoother

//--- Indicator buffers
double LargeTrader_Proxy_Buffer[];

//--- Internal calculation buffers
double Close_Diff[];
double True_Range[];
double Raw_Signal[];
double Signal_MA[];

//--- Super Smoother coefficients
double a1, b1, c1, c2, c3;

//--- Super Smoother internal buffers
double SS_Close_Buffer[], SS_TR_Buffer[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Indicator buffers mapping
   SetIndexBuffer(0, LargeTrader_Proxy_Buffer, INDICATOR_DATA);
   
   //--- Set empty values
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
   //--- Initialize Super Smoother coefficients
   InitSuperSmoother(LargeTrader_Period, a1, b1, c1, c2, c3);
   
   //--- Resize Super Smoother buffers
   ArrayResize(SS_Close_Buffer, Bars(Symbol(), PERIOD_CURRENT));
   ArrayResize(SS_TR_Buffer, Bars(Symbol(), PERIOD_CURRENT));
   
   //--- Resize internal buffers
   ArrayResize(Close_Diff, Bars(Symbol(), PERIOD_CURRENT));
   ArrayResize(True_Range, Bars(Symbol(), PERIOD_CURRENT));
   ArrayResize(Raw_Signal, Bars(Symbol(), PERIOD_CURRENT));
   ArrayResize(Signal_MA, Bars(Symbol(), PERIOD_CURRENT));
   
   //--- Set indicator name
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("LargeTrader Proxy Histogram(%d,SuperSmoother)", LargeTrader_Period));
   
   //--- Set precision
   IndicatorSetInteger(INDICATOR_DIGITS, 4);
   
   //--- Remove fixed range to allow auto-scaling
   //IndicatorSetDouble(INDICATOR_MINIMUM, 0);
   //IndicatorSetDouble(INDICATOR_MAXIMUM, 100);
   
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
//| Calculate 4-period Simple Moving Average                        |
//+------------------------------------------------------------------+
double Calculate4PeriodSMA(double &data[], int index)
{
   if(index < 3) // Need at least 4 bars (0,1,2,3)
      return data[index];
      
   double sum = 0.0;
   for(int i = 0; i < 4; i++)
   {
      sum += data[index - i];
   }
   return sum / 4.0;
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
   //--- Check if we have enough data (need 8 bars for close lag + period)
   if(rates_total < LargeTrader_Period + 8)
      return(0);
   
   //--- Calculate starting position
   int start = MathMax(prev_calculated - 1, 8); // Start from bar 8 to have Close[i-8]
   if(start < 8) start = 8;
   
   //--- Resize buffers if needed
   if(ArraySize(Close_Diff) < rates_total)
   {
      ArrayResize(Close_Diff, rates_total);
      ArrayResize(True_Range, rates_total);
      ArrayResize(Raw_Signal, rates_total);
      ArrayResize(Signal_MA, rates_total);
      ArrayResize(SS_Close_Buffer, rates_total);
      ArrayResize(SS_TR_Buffer, rates_total);
   }
   
   //--- Calculate raw values for all bars
   for(int i = start; i < rates_total; i++)
   {
      //--- Calculate Close - Close[i-8] difference
      Close_Diff[i] = close[i] - close[i-8];
      
      //--- Calculate True Range
      double tr1 = high[i] - low[i];
      double tr2 = MathAbs(high[i] - close[i-1]);
      double tr3 = MathAbs(low[i] - close[i-1]);
      True_Range[i] = MathMax(tr1, MathMax(tr2, tr3));
   }
   
   //--- Calculate Super Smoother raw signal first
   for(int i = MathMax(start, LargeTrader_Period - 1); i < rates_total; i++)
   {
      //--- Use Super Smoother
      double ss_close = CalculateSuperSmoother(Close_Diff[i], i, SS_Close_Buffer, c1, c2, c3);
      double ss_tr = CalculateSuperSmoother(True_Range[i], i, SS_TR_Buffer, c1, c2, c3);
      
      //--- Calculate raw signal: SS(Close-Close[8]) / SS(True Range)
      if(ss_tr > 0)
      {
         Raw_Signal[i] = ss_close / ss_tr;
      }
      else
      {
         Raw_Signal[i] = 0.0; // Neutral value when True Range is zero
      }
   }
   
   //--- Calculate 4-period moving average of the raw signal and create histogram
   for(int i = MathMax(start, LargeTrader_Period + 3); i < rates_total; i++)
   {
      //--- Calculate 4-period SMA of raw signal
      Signal_MA[i] = Calculate4PeriodSMA(Raw_Signal, i);
      
      //--- Create histogram: Raw Signal - Its 4-period MA
      LargeTrader_Proxy_Buffer[i] = Raw_Signal[i] - Signal_MA[i];
   }
   
   return(rates_total);
}
//+------------------------------------------------------------------+
