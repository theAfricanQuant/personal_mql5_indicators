//+------------------------------------------------------------------+
//|                                               momentum_burst.mq5 |
//|                                             Ricky Macharm, MScFE |
//|                                         https://www.SisengAI.com |
//+------------------------------------------------------------------+
#property copyright "Ricky Macharm, MScFE"
#property link      "https://www.SisengAI.com"
#property version   "1.00"
#property indicator_chart_window

#property indicator_buffers 5
#property indicator_plots   1

//--- Plot settings
#property indicator_label1  "Shaved Candles"
#property indicator_type1   DRAW_COLOR_CANDLES
#property indicator_color1  clrSilver,clrBurlyWood,clrMaroon
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Input parameters
input int     LookbackBars = 3;               // Number of previous bars to compare size against
input double  ClosePositionPct = 80.0;        // Close position percentage (80 = top 80% for bullish)
input int     AvgSizeBars = 5;                // Number of bars to calculate average size
input double  MaxSizeMultiplier = 3.0;        // Maximum size multiplier vs average (3.0 = max 3x average)
input double  MinBodyPct = 50.0;              // Minimum body size percentage of total range (50 = 50% body)
input double  MaxShadowPct = 15.0;            // Maximum shadow percentage for shaved candles (15 = max 15% shadow)
input bool    EnableAlerts = true;            // Enable Alerts
input bool    EnablePopupAlerts = true;       // Enable Popup Alerts
input bool    EnableSoundAlerts = true;       // Enable Sound Alerts
input bool    EnableEmailAlerts = false;      // Enable Email Alerts
input string  AlertSoundFile = "alert.wav";   // Alert Sound File

//--- Indicator buffers
double OpenBuffer[];
double HighBuffer[];
double LowBuffer[];
double CloseBuffer[];
double ColorBuffer[];

//--- Global variables
datetime LastAlertTime = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Indicator buffers mapping for color candles
   SetIndexBuffer(0, OpenBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, HighBuffer, INDICATOR_DATA);
   SetIndexBuffer(2, LowBuffer, INDICATOR_DATA);
   SetIndexBuffer(3, CloseBuffer, INDICATOR_DATA);
   SetIndexBuffer(4, ColorBuffer, INDICATOR_COLOR_INDEX);
   
   //--- Set empty values
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   
   //--- Set indicator name
   IndicatorSetString(INDICATOR_SHORTNAME, "Shaved Candles");
   
   //--- Set precision
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
   
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
   //--- Check if we have enough data (need at least max of LookbackBars and AvgSizeBars + 1)
   int min_bars = MathMax(LookbackBars, AvgSizeBars) + 1;
   if(rates_total < min_bars)
      return(0);
   
   //--- Calculate from the last unprocessed bar
   int start = MathMax(prev_calculated - 1, MathMax(LookbackBars, AvgSizeBars));
   if(start < MathMax(LookbackBars, AvgSizeBars)) start = MathMax(LookbackBars, AvgSizeBars);
   
   //--- Main calculation loop  
   for(int i = start; i < rates_total; i++) // Process all bars including current one
   {
      //--- Initialize buffers with empty values
      OpenBuffer[i] = EMPTY_VALUE;
      HighBuffer[i] = EMPTY_VALUE;
      LowBuffer[i] = EMPTY_VALUE;
      CloseBuffer[i] = EMPTY_VALUE;
      ColorBuffer[i] = 0; // Default color (silver)
      
      //--- Skip if not enough historical data for this bar
      if(i < MathMax(LookbackBars, AvgSizeBars)) continue;
      
      //--- Check momentum burst conditions
      bool isLongSignal = false;
      bool isShortSignal = false;
      
      CheckMomentumBurst(i, open, high, low, close, volume, isLongSignal, isShortSignal);
      
      //--- Debug: Print detailed info for recent bars to see what's happening
      if(i >= rates_total - 5) // Check last 5 bars
      {
         double bar_size = high[i] - low[i];
         double body_size = MathAbs(close[i] - open[i]);
         double body_pct = bar_size > 0 ? (body_size / bar_size) * 100.0 : 0;
         double close_position = ((close[i] - low[i]) / bar_size) * 100.0;
         
         // Calculate shadows
         double body_high = MathMax(close[i], open[i]);
         double body_low = MathMin(close[i], open[i]);
         double top_shadow = high[i] - body_high;
         double bottom_shadow = body_low - low[i];
         double top_shadow_pct = bar_size > 0 ? (top_shadow / bar_size) * 100.0 : 0;
         double bottom_shadow_pct = bar_size > 0 ? (bottom_shadow / bar_size) * 100.0 : 0;
         
         // Calculate average size for debug
         double avg_size = 0;
         for(int j = 1; j <= AvgSizeBars; j++)
         {
            avg_size += (high[i-j] - low[i-j]);
         }
         avg_size /= AvgSizeBars;
         double size_ratio = bar_size / avg_size;
         
         Print("Bar ", i, " - Time: ", TimeToString(time[i]), 
               " - Size: ", DoubleToString(bar_size * MathPow(10, _Digits), 0), " pips",
               " - Body: ", DoubleToString(body_pct, 1), "%",
               " - Top Shadow: ", DoubleToString(top_shadow_pct, 1), "%",
               " - Bottom Shadow: ", DoubleToString(bottom_shadow_pct, 1), "%",
               " - Size Ratio: ", DoubleToString(size_ratio, 2), "x",
               " - Close Position: ", DoubleToString(close_position, 1), "%",
               " - Long: ", isLongSignal ? "YES" : "NO",
               " - Short: ", isShortSignal ? "YES" : "NO");
      }
      
      //--- Debug: Print signals found (only for recent bars)
      if((isLongSignal || isShortSignal) && i >= rates_total - 10)
      {
         Print("*** SIGNAL FOUND *** ", isLongSignal ? "BULLISH" : "BEARISH", " at bar ", i, " time ", TimeToString(time[i]));
      }
      
      //--- Only copy price data and set colors for bars with signals
      if(isLongSignal)
      {
         OpenBuffer[i] = open[i];
         HighBuffer[i] = high[i];
         LowBuffer[i] = low[i];
         CloseBuffer[i] = close[i];
         ColorBuffer[i] = 1; // BurlyWood color for bullish
         
         //--- Send alert for closed bar signal (not the current forming bar)
         if(EnableAlerts && i == rates_total - 2 && time[i] != LastAlertTime)
         {
            SendAlert("BULLISH", Symbol(), time[i]);
            LastAlertTime = time[i];
         }
      }
      else if(isShortSignal)
      {
         OpenBuffer[i] = open[i];
         HighBuffer[i] = high[i];
         LowBuffer[i] = low[i];
         CloseBuffer[i] = close[i];
         ColorBuffer[i] = 2; // Maroon color for bearish
         
         //--- Send alert for closed bar signal (not the current forming bar)
         if(EnableAlerts && i == rates_total - 2 && time[i] != LastAlertTime)
         {
            SendAlert("BEARISH", Symbol(), time[i]);
            LastAlertTime = time[i];
         }
      }
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Check Momentum Burst Conditions                                 |
//+------------------------------------------------------------------+
void CheckMomentumBurst(int pos, 
                       const double &open[],
                       const double &high[],
                       const double &low[],
                       const double &close[],
                       const long &volume[],
                       bool &longSignal,
                       bool &shortSignal)
{
   //--- Initialize signals
   longSignal = false;
   shortSignal = false;
   
   //--- Safety check
   if(pos < MathMax(LookbackBars, AvgSizeBars)) 
      return;
   
   //--- Current bar data
   double current_high = high[pos];
   double current_low = low[pos];
   double current_close = close[pos];
   double current_open = open[pos];
   double current_size = current_high - current_low;
   
   //--- Previous bar close for comparison
   double prev_close = close[pos-1];
   
   //--- Safety checks
   if(current_size <= 0 || current_close <= 0 || prev_close <= 0)
      return;
   
   //--- Calculate average size of previous N bars
   double avg_size = 0;
   for(int i = 1; i <= AvgSizeBars; i++)
   {
      avg_size += (high[pos-i] - low[pos-i]);
   }
   avg_size /= AvgSizeBars;
   
   //--- Check if current bar size is not too large (outlier filter)
   bool size_not_outlier = (current_size <= avg_size * MaxSizeMultiplier);
   
   //--- Calculate body size and percentage
   double body_size = MathAbs(current_close - current_open);
   double body_pct = current_size > 0 ? (body_size / current_size) * 100.0 : 0;
   bool has_strong_body = (body_pct >= MinBodyPct);
   
   //--- Calculate shadow sizes and percentages
   double body_high = MathMax(current_close, current_open);
   double body_low = MathMin(current_close, current_open);
   double top_shadow = current_high - body_high;
   double bottom_shadow = body_low - current_low;
   double top_shadow_pct = current_size > 0 ? (top_shadow / current_size) * 100.0 : 0;
   double bottom_shadow_pct = current_size > 0 ? (bottom_shadow / current_size) * 100.0 : 0;
   
   //--- Calculate where the close is positioned within the bar (0-100%)
   double close_position_pct = ((current_close - current_low) / current_size) * 100.0;
   
   //--- Check if current bar is larger than previous N bars
   bool is_larger_than_previous = true;
   for(int i = 1; i <= LookbackBars; i++)
   {
      double prev_bar_size = high[pos-i] - low[pos-i];
      if(current_size <= prev_bar_size)
      {
         is_larger_than_previous = false;
         break;
      }
   }
   
   //--- BULLISH SHAVED CANDLE CONDITIONS
   bool bullish_cond1 = (current_close > prev_close);                    // Close higher than previous
   bool bullish_cond2 = is_larger_than_previous;                         // Larger than previous N bars
   bool bullish_cond3 = (close_position_pct >= ClosePositionPct);        // Close in top % of bar
   bool bullish_cond4 = size_not_outlier;                                // Not an outlier size
   bool bullish_cond5 = has_strong_body;                                 // Body is at least MinBodyPct% of range
   bool bullish_cond6 = (top_shadow_pct <= MaxShadowPct);                // Top shadow ≤ max % (shaved top)
   
   //--- BEARISH SHAVED CANDLE CONDITIONS  
   bool bearish_cond1 = (current_close < prev_close);                    // Close lower than previous
   bool bearish_cond2 = is_larger_than_previous;                         // Larger than previous N bars
   bool bearish_cond3 = (close_position_pct <= (100.0 - ClosePositionPct)); // Close in bottom % of bar
   bool bearish_cond4 = size_not_outlier;                                // Not an outlier size
   bool bearish_cond5 = has_strong_body;                                 // Body is at least MinBodyPct% of range
   bool bearish_cond6 = (bottom_shadow_pct <= MaxShadowPct);             // Bottom shadow ≤ max % (shaved bottom)
   
   //--- Set signals
   longSignal = bullish_cond1 && bullish_cond2 && bullish_cond3 && bullish_cond4 && bullish_cond5 && bullish_cond6;
   shortSignal = bearish_cond1 && bearish_cond2 && bearish_cond3 && bearish_cond4 && bearish_cond5 && bearish_cond6;
}

//+------------------------------------------------------------------+
//| Send Alert Function                                              |
//+------------------------------------------------------------------+
void SendAlert(string signal_type, string symbol, datetime time)
{
   string message = StringFormat("Shaved Candle %s Signal on %s at %s", 
                                signal_type, symbol, TimeToString(time));
   
   //--- Popup alert
   if(EnablePopupAlerts)
      Alert(message);
   
   //--- Sound alert
   if(EnableSoundAlerts)
      PlaySound(AlertSoundFile);
   
   //--- Email alert
   if(EnableEmailAlerts)
   {
      string subject = StringFormat("Shaved Candle %s - %s", signal_type, symbol);
      SendMail(subject, message);
   }
   
   //--- Print to log
   Print(message);
}