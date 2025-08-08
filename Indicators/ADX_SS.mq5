//+------------------------------------------------------------------+
//|                                                    ADX_SS.mq5 |
//|                                             Ricky Macharm, MScFE |
//|                                         https://www.SisengAI.com |
//+------------------------------------------------------------------+
#property copyright "Ricky Macharm, MScFE"
#property link      "https://www.SisengAI.com"
#property version   "1.00"
#property indicator_separate_window

#property indicator_buffers 7
#property indicator_plots   3

//--- Plot 1: ADX Line
#property indicator_label1  "ADX SS"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrBurlyWood
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: +DI Line
#property indicator_label2  "+DI SS"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrLimeGreen
#property indicator_style2  STYLE_SOLID
#property indicator_width2  1

//--- Plot 3: -DI Line
#property indicator_label3  "-DI SS"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrCrimson
#property indicator_style3  STYLE_SOLID
#property indicator_width3  1

//--- Indicator levels
#property indicator_level1 20
#property indicator_level2 50
#property indicator_levelcolor clrDimGray
#property indicator_levelstyle STYLE_DOT

//--- Input parameters
input int     ADX_Period = 14;          // ADX Period for Super Smoother

//--- Indicator buffers
double ADX_Buffer[];
double Plus_DI_Buffer[];
double Minus_DI_Buffer[];
double Plus_DM_Buffer[];   // Internal buffer
double Minus_DM_Buffer[];  // Internal buffer
double TR_Buffer[];        // Internal buffer
double DX_Buffer[];        // Internal buffer

//--- Super Smoother coefficients
double a1, b1, c1, c2, c3;

//--- Super Smoother internal buffers
double SS_Plus_DM[], SS_Minus_DM[], SS_TR[];
//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Indicator buffers mapping
   SetIndexBuffer(0, ADX_Buffer, INDICATOR_DATA);
   SetIndexBuffer(1, Plus_DI_Buffer, INDICATOR_DATA);
   SetIndexBuffer(2, Minus_DI_Buffer, INDICATOR_DATA);
   SetIndexBuffer(3, Plus_DM_Buffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(4, Minus_DM_Buffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, TR_Buffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, DX_Buffer, INDICATOR_CALCULATIONS);
   
   //--- Set empty values
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
   //--- Initialize Super Smoother coefficients
   InitSuperSmoother(ADX_Period, a1, b1, c1, c2, c3);
   
   //--- Resize Super Smoother buffers
   ArrayResize(SS_Plus_DM, Bars(Symbol(), PERIOD_CURRENT));
   ArrayResize(SS_Minus_DM, Bars(Symbol(), PERIOD_CURRENT));
   ArrayResize(SS_TR, Bars(Symbol(), PERIOD_CURRENT));
   
   //--- Set indicator name
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("ADX SS(%d)", ADX_Period));
   
   //--- Set precision
   IndicatorSetInteger(INDICATOR_DIGITS, 2);
   
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
   if(rates_total < ADX_Period + 2)
      return(0);
   
   //--- Calculate starting position
   int start = MathMax(prev_calculated - 1, 1);
   if(start < 1) start = 1;
   
   //--- Resize Super Smoother buffers if needed
   if(ArraySize(SS_Plus_DM) < rates_total)
   {
      ArrayResize(SS_Plus_DM, rates_total);
      ArrayResize(SS_Minus_DM, rates_total);
      ArrayResize(SS_TR, rates_total);
   }
   
   //--- Main calculation loop
   for(int i = start; i < rates_total; i++)
   {
      //--- Calculate Directional Movement and True Range
      double high_diff = high[i] - high[i-1];
      double low_diff = low[i-1] - low[i];
      
      //--- Calculate +DM and -DM
      Plus_DM_Buffer[i] = 0.0;
      Minus_DM_Buffer[i] = 0.0;
      
      if(high_diff > low_diff && high_diff > 0)
         Plus_DM_Buffer[i] = high_diff;
      
      if(low_diff > high_diff && low_diff > 0)
         Minus_DM_Buffer[i] = low_diff;
      
      //--- Calculate True Range
      double tr1 = high[i] - low[i];
      double tr2 = MathAbs(high[i] - close[i-1]);
      double tr3 = MathAbs(low[i] - close[i-1]);
      TR_Buffer[i] = MathMax(tr1, MathMax(tr2, tr3));
      
      //--- Apply Super Smoother to DM and TR values
      double smoothed_plus_dm = CalculateSuperSmoother(Plus_DM_Buffer[i], i, SS_Plus_DM, c1, c2, c3);
      double smoothed_minus_dm = CalculateSuperSmoother(Minus_DM_Buffer[i], i, SS_Minus_DM, c1, c2, c3);
      double smoothed_tr = CalculateSuperSmoother(TR_Buffer[i], i, SS_TR, c1, c2, c3);
      
      //--- Calculate +DI and -DI
      if(smoothed_tr > 0)
      {
         Plus_DI_Buffer[i] = 100.0 * smoothed_plus_dm / smoothed_tr;
         Minus_DI_Buffer[i] = 100.0 * smoothed_minus_dm / smoothed_tr;
      }
      else
      {
         Plus_DI_Buffer[i] = 0.0;
         Minus_DI_Buffer[i] = 0.0;
      }
      
      //--- Calculate DX
      double di_sum = Plus_DI_Buffer[i] + Minus_DI_Buffer[i];
      double di_diff = MathAbs(Plus_DI_Buffer[i] - Minus_DI_Buffer[i]);
      
      if(di_sum > 0)
         DX_Buffer[i] = 100.0 * di_diff / di_sum;
      else
         DX_Buffer[i] = 0.0;
   }
   
   //--- Calculate ADX using Super Smoother on DX values
   //--- Need a separate loop for ADX as it requires DX values to be calculated first
   for(int i = MathMax(start, ADX_Period); i < rates_total; i++)
   {
      //--- Calculate average DX over the period for initial ADX value
      if(i == ADX_Period)
      {
         double dx_sum = 0.0;
         for(int j = 1; j <= ADX_Period; j++)
         {
            dx_sum += DX_Buffer[i - j + 1];
         }
         ADX_Buffer[i] = dx_sum / ADX_Period;
      }
      else
      {
         //--- Apply modified smoothing similar to Wilder's but with Super Smoother characteristics
         //--- Use a blend of previous ADX and current DX
         double alpha = 2.0 / (ADX_Period + 1.0);  // EMA-like smoothing factor
         ADX_Buffer[i] = alpha * DX_Buffer[i] + (1.0 - alpha) * ADX_Buffer[i-1];
      }
   }
   
   return(rates_total);
}
//+------------------------------------------------------------------+
