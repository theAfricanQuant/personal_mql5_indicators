//+------------------------------------------------------------------+
//|                                  weekly_volatility_breakouts.mq5 |
//|                                             Ricky Macharm, MScFE |
//|                                         https://www.SisengAI.com |
//+------------------------------------------------------------------+
#property copyright "Ricky Macharm, MScFE"
#property link      "https://www.SisengAI.com"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

//--- plot Upper Breakout
#property indicator_label1  "Upper Breakout"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- plot Lower Breakout
#property indicator_label2  "Lower Breakout"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

//--- input parameters
input double Range_Multiplier = 2.5; // Weekly Range Multiplier
input int    Weeks_Back = 4;         // Number of weeks to display lines

//--- indicator buffers
double UpperBreakoutBuffer[];
double LowerBreakoutBuffer[];

//--- global variables
datetime last_week_processed = 0;
double current_upper_level = 0;
double current_lower_level = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- check if we're on 4-hour timeframe
    if(Period() != PERIOD_H4)
    {
        Print("This indicator only works on 4-hour (H4) charts!");
        MessageBox("This indicator only works on 4-hour (H4) charts!", "Wrong Timeframe", MB_OK | MB_ICONWARNING);
        return(INIT_FAILED);
    }
    
    //--- indicator buffers mapping
    SetIndexBuffer(0, UpperBreakoutBuffer, INDICATOR_DATA);
    SetIndexBuffer(1, LowerBreakoutBuffer, INDICATOR_DATA);
    
    //--- set indexing as time series
    ArraySetAsSeries(UpperBreakoutBuffer, true);
    ArraySetAsSeries(LowerBreakoutBuffer, true);
    
    //--- set indicator properties
    IndicatorSetString(INDICATOR_SHORTNAME, "Weekly Volatility Breakouts (H4)");
    IndicatorSetInteger(INDICATOR_DIGITS, _Digits);
    
    //--- initialize buffers with empty values
    PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Get start of week (Monday 00:00) for given time                 |
//+------------------------------------------------------------------+
datetime GetWeekStart(datetime time)
{
    MqlDateTime tm;
    TimeToStruct(time, tm);
    
    // Calculate days to subtract to get to Monday (week start)
    int days_to_subtract = (tm.day_of_week == 0) ? 6 : tm.day_of_week - 1;
    
    // Set time to start of day
    tm.hour = 0;
    tm.min = 0;
    tm.sec = 0;
    
    datetime week_start = StructToTime(tm) - days_to_subtract * 24 * 60 * 60;
    return week_start;
}

//+------------------------------------------------------------------+
//| Get weekly data (open, high, low) for a specific week           |
//+------------------------------------------------------------------+
bool GetWeeklyData(datetime week_start, double &weekly_open, double &weekly_high, double &weekly_low)
{
    MqlRates weekly_rates[];
    ArraySetAsSeries(weekly_rates, true);
    
    // Get the weekly bar for the specified week
    int copied = CopyRates(NULL, PERIOD_W1, week_start, 1, weekly_rates);
    if(copied > 0)
    {
        weekly_open = weekly_rates[0].open;
        weekly_high = weekly_rates[0].high;
        weekly_low = weekly_rates[0].low;
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| Check if bar time is within display range                       |
//+------------------------------------------------------------------+
bool IsWithinDisplayRange(datetime bar_time)
{
    if(Weeks_Back <= 0) return true; // Show all if 0 or negative
    
    datetime current_time = TimeCurrent();
    datetime cutoff_time = current_time - (Weeks_Back * 7 * 24 * 60 * 60); // Weeks_Back weeks ago
    
    return (bar_time >= cutoff_time);
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
    if(rates_total < 2)
        return 0;
    
    //--- set arrays as time series
    ArraySetAsSeries(time, true);
    
    //--- calculate start position
    int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
    
    //--- main calculation loop
    for(int i = start; i < rates_total; i++)
    {
        int pos = rates_total - 1 - i; // convert to time series index
        
        // Initialize buffer values as empty
        UpperBreakoutBuffer[pos] = EMPTY_VALUE;
        LowerBreakoutBuffer[pos] = EMPTY_VALUE;
        
        // Get current bar time
        datetime current_time = time[pos];
        
        // Check if this bar is within our display range
        if(!IsWithinDisplayRange(current_time))
            continue;
        
        // Get current week start
        datetime current_week_start = GetWeekStart(current_time);
        
        // Check if we're processing a new week
        if(current_week_start != last_week_processed)
        {
            // Get previous week start (one week earlier)
            datetime previous_week_start = current_week_start - (7 * 24 * 60 * 60);
            
            // Get previous week's data
            double prev_week_open, prev_week_high, prev_week_low;
            bool prev_week_data_valid = GetWeeklyData(previous_week_start, prev_week_open, prev_week_high, prev_week_low);
            
            // Get current week's open
            double current_week_open, current_week_high, current_week_low;
            bool current_week_data_valid = GetWeeklyData(current_week_start, current_week_open, current_week_high, current_week_low);
            
            // Calculate breakout levels if we have valid data
            if(prev_week_data_valid && current_week_data_valid)
            {
                // Calculate previous week's range
                double previous_week_range = prev_week_high - prev_week_low;
                
                // Apply multiplier
                double range_offset = previous_week_range * Range_Multiplier;
                
                // Calculate breakout levels using current week's open
                current_upper_level = current_week_open + range_offset;
                current_lower_level = current_week_open - range_offset;
            }
            
            last_week_processed = current_week_start;
        }
        
        // Set buffer values if we have valid levels
        if(current_upper_level > 0 && current_lower_level > 0)
        {
            UpperBreakoutBuffer[pos] = current_upper_level;
            LowerBreakoutBuffer[pos] = current_lower_level;
        }
    }
    
    return rates_total;
}
//+------------------------------------------------------------------+