//+------------------------------------------------------------------+
//|                                                        ProGo.mq5 |
//|                                             Ricky Macharm, MScFE |
//|                                         https://www.SisengAI.com |
//+------------------------------------------------------------------+
#property copyright "Ricky Macharm, MScFE"
#property link      "https://www.SisengAI.com"
#property version   "1.00"
#property indicator_separate_window

#property indicator_buffers 2
#property indicator_plots   2

//--- Plot 1: Professionals (Close - Open)
#property indicator_label1  "Professionals"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrBurlyWood
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: Public (Open - Previous Close)
#property indicator_label2  "Public"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrCrimson
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

//--- Indicator levels
#property indicator_level1 0
#property indicator_levelcolor clrDimGray
#property indicator_levelstyle STYLE_DOT

//--- Input parameters
input int     ProGo_Period = 14;              // Period for Super Smoother
input bool    ShowProfessionals = true;       // Show Professionals line (Close-Open)
input bool    ShowPublic = true;              // Show Public line (Open-PrevClose)

//--- Indicator buffers
double Professionals_Buffer[];
double Public_Buffer[];

//--- Internal calculation buffers
double Close_Open_Diff[];
double Open_PrevClose_Diff[];

//--- Super Smoother coefficients
double a1, b1, c1, c2, c3;

//--- Super Smoother internal buffers
double SS_Prof_Buffer[], SS_Public_Buffer[];

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Indicator buffers mapping
   SetIndexBuffer(0, Professionals_Buffer, INDICATOR_DATA);
   SetIndexBuffer(1, Public_Buffer, INDICATOR_DATA);
   
   //--- Set empty values (use 0.0 instead of EMPTY_VALUE for this indicator)
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, 0.0);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, 0.0);
   
   //--- Control visibility based on input parameters
   PlotIndexSetInteger(0, PLOT_DRAW_TYPE, ShowProfessionals ? DRAW_LINE : DRAW_NONE);
   PlotIndexSetInteger(1, PLOT_DRAW_TYPE, ShowPublic ? DRAW_LINE : DRAW_NONE);
   
   //--- Initialize Super Smoother coefficients
   InitSuperSmoother(ProGo_Period, a1, b1, c1, c2, c3);
   
   //--- Resize Super Smoother buffers
   ArrayResize(SS_Prof_Buffer, Bars(Symbol(), PERIOD_CURRENT));
   ArrayResize(SS_Public_Buffer, Bars(Symbol(), PERIOD_CURRENT));
   
   //--- Resize internal buffers
   ArrayResize(Close_Open_Diff, Bars(Symbol(), PERIOD_CURRENT));
   ArrayResize(Open_PrevClose_Diff, Bars(Symbol(), PERIOD_CURRENT));
   
   //--- Set indicator name
   IndicatorSetString(INDICATOR_SHORTNAME, StringFormat("ProGo(%d,SuperSmoother)", ProGo_Period));
   
   //--- Set precision
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   
   //--- Allow auto-scaling
   
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
   if(rates_total < ProGo_Period + 2)
      return(0);
   
   //--- Calculate starting position
   int start = MathMax(prev_calculated - 1, 0);
   if(start < 0) start = 0;
   
   //--- For initial calculation, ensure we start from the beginning
   if(prev_calculated == 0) start = 0;
   
   //--- Resize buffers if needed
   if(ArraySize(Close_Open_Diff) < rates_total)
   {
      ArrayResize(Close_Open_Diff, rates_total);
      ArrayResize(Open_PrevClose_Diff, rates_total);
      ArrayResize(SS_Prof_Buffer, rates_total);
      ArrayResize(SS_Public_Buffer, rates_total);
      ArrayResize(Professionals_Buffer, rates_total);
      ArrayResize(Public_Buffer, rates_total);
   }
   
   //--- Calculate Close - Open and Open - Previous Close differences and apply Super Smoother
   for(int i = start; i < rates_total; i++)
   {
      //--- Calculate Close - Open difference (Professionals)
      Close_Open_Diff[i] = close[i] - open[i];
      
      //--- Calculate Open - Previous Close difference (Public)
      if(i > 0)
         Open_PrevClose_Diff[i] = open[i] - close[i-1];
      else
         Open_PrevClose_Diff[i] = 0.0; // No previous close for first bar
      
      //--- Apply Super Smoother to both signals
      if(ShowProfessionals)
         Professionals_Buffer[i] = CalculateSuperSmoother(Close_Open_Diff[i], i, SS_Prof_Buffer, c1, c2, c3);
      
      if(ShowPublic)
         Public_Buffer[i] = CalculateSuperSmoother(Open_PrevClose_Diff[i], i, SS_Public_Buffer, c1, c2, c3);
   }
   
   return(rates_total);
}
//+------------------------------------------------------------------+
