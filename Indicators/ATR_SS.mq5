//+------------------------------------------------------------------+
//|                                                       ATR_SS.mq5 |
//|                                             Ricky Macharm, MScFE |
//|                                         https://www.SisengAI.com |
//+------------------------------------------------------------------+
#property copyright "Ricky Macharm, MScFE"
#property link      "https://www.SisengAI.com"
#property version   "1.00"
#property indicator_separate_window

#property indicator_buffers 1
#property indicator_plots   1

//--- Plot 1: ATR Super Smoother
#property indicator_label1  "ATR SS"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrBurlyWood
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Input parameters
input int     ATR_Period = 14;          // ATR Period for Super Smoother

//--- Indicator buffers
double ATR_SS_Buffer[];

//--- Super Smoother buffers (internal calculations)
double TrueRange_Buffer[];
double SS_Buffer[];

//--- Super Smoother coefficients
double a1, b1, c1, c2, c3;
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Indicator buffers mapping
   SetIndexBuffer(0, ATR_SS_Buffer, INDICATOR_DATA);
   
   //--- Set empty values
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
   //--- Initialize Super Smoother coefficients
   InitSuperSmoother(ATR_Period, a1, b1, c1, c2, c3);
   
   //--- Resize internal buffers
   ArrayResize(TrueRange_Buffer, Bars(Symbol(), PERIOD_CURRENT));
   ArrayResize(SS_Buffer, Bars(Symbol(), PERIOD_CURRENT));
   
   //--- Set indicator name
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("ATR SS(%d)", ATR_Period));
   
   //--- Set precision
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits + 1);
   
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
//| Calculate True Range                                             |
//+------------------------------------------------------------------+
double CalculateTrueRange(double high, double low, double prev_close)
{
   double tr1 = high - low;                    // Current high - current low
   double tr2 = MathAbs(high - prev_close);    // Current high - previous close
   double tr3 = MathAbs(low - prev_close);     // Current low - previous close
   
   return MathMax(tr1, MathMax(tr2, tr3));
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
   if(rates_total < ATR_Period + 2)
      return(0);
   
   //--- Calculate starting position
   int start = MathMax(prev_calculated - 1, 1); // Start from index 1 (need previous close)
   if(start < 1) start = 1;
   
   //--- Resize buffers if needed
   if(ArraySize(TrueRange_Buffer) < rates_total)
   {
      ArrayResize(TrueRange_Buffer, rates_total);
      ArrayResize(SS_Buffer, rates_total);
   }
   
   //--- Main calculation loop
   for(int i = start; i < rates_total; i++)
   {
      //--- Calculate True Range for current bar
      double prev_close_price = (i > 0) ? close[i-1] : close[i];
      TrueRange_Buffer[i] = CalculateTrueRange(high[i], low[i], prev_close_price);
      
      //--- Apply Super Smoother to True Range values
      double smoothed_tr = CalculateSuperSmoother(TrueRange_Buffer[i], i, SS_Buffer, c1, c2, c3);
      
      //--- Store the result
      ATR_SS_Buffer[i] = smoothed_tr;
   }
   
   return(rates_total);
}
//+------------------------------------------------------------------+
