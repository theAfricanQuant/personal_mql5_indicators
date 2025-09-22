//+------------------------------------------------------------------+
//|                                  weekly_volatility_breakouts.mq5 |
//|                                             Ricky Macharm, MScFE |
//|                                         https://www.SisengAI.com |
//+------------------------------------------------------------------+
#property copyright "Ricky Macharm, MScFE"
#property link      "https://www.SisengAI.com"
#property version   "1.00"
#property indicator_chart_window

#property indicator_plots 0

// Enumeration for volatility calculation method
enum ENUM_VOLATILITY_METHOD
{
    LARRY = 0,      // ATR-based method only
    CRABEL = 1,     // Min(High-Open, Open-Low) SMA method only
    BOTH = 2        // Show both methods
};

//--- Input parameters
input int    Historical_Weeks = 152;                    // Number of historical weeks to draw
input ENUM_VOLATILITY_METHOD Volatility_Method = LARRY; // Volatility calculation method
input int    ATR_Period = 1;                           // ATR Period (Larry method)
input double ATR_Multiplier = .25;                     // ATR Multiplier (Larry method)
input int    Crabel_SMA_Period = 10;                   // SMA Period for Crabel method
input double Crabel_Multiplier = 1.1;                  // Crabel Multiplier
input color  Larry_Upper_Color = clrGold;               // Larry Upper Line Color
input color  Larry_Lower_Color = clrTeal;              // Larry Lower Line Color
input color  Crabel_Upper_Color = clrBurlyWood;           // Crabel Upper Line Color
input color  Crabel_Lower_Color = clrGreen;            // Crabel Lower Line Color
input ENUM_LINE_STYLE Line_Style = STYLE_SOLID;        // Line Style
input int    Line_Width = 4;                           // Line Width
input bool   Show_Labels = true;                       // Show Price Labels
input color  Label_Color = clrWhite;                   // Label Color
input int    Label_Font_Size = 10;                     // Label Font Size

//--- Global variables
int atr_handle;
string indicator_prefix = "WeeklyVol_";

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    // Create ATR handle for weekly timeframe (needed for both methods)
    atr_handle = iATR(_Symbol, PERIOD_W1, ATR_Period);
    
    if(atr_handle == INVALID_HANDLE)
    {
        Print("Error creating ATR handle: ", GetLastError());
        return(INIT_FAILED);
    }
    
    string method_name = "";
    if(Volatility_Method == LARRY) method_name = "Larry (ATR)";
    else if(Volatility_Method == CRABEL) method_name = "Crabel (Min SMA)";
    else method_name = "Both Methods";
    Print("Weekly Volatility indicator initialized successfully - Method: ", method_name);
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                      |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    // Clean up objects
    ObjectsDeleteAll(0, indicator_prefix);
    
    // Release ATR handle
    if(atr_handle != INVALID_HANDLE)
        IndicatorRelease(atr_handle);
    
    Print("Weekly Volatility indicator deinitialized");
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
    // Only process if we have enough data
    if(rates_total < 10)
        return(0);
    
    // Wait for ATR data to be ready
    if(BarsCalculated(atr_handle) < ATR_Period)
        return(0);
    
    // Get current week start time
    datetime current_week_start = GetWeekStart(TimeCurrent());
    
    Print("Processing week starting: ", TimeToString(current_week_start));
    
    // Draw lines for current week
    DrawWeeklyVolatilityLines(current_week_start);
    
    // Draw lines for historical weeks based on input parameter
    for(int i = 1; i <= Historical_Weeks; i++)
    {
        datetime prev_week_start = current_week_start - i * 604800; // 604800 = 1 week in seconds
        DrawWeeklyVolatilityLines(prev_week_start);
    }
    
    return(rates_total);
}

//+------------------------------------------------------------------+
//| Get the start of the week (Monday 00:00)                        |
//+------------------------------------------------------------------+
datetime GetWeekStart(datetime dt)
{
    MqlDateTime mdt;
    TimeToStruct(dt, mdt);
    
    // Calculate days to subtract to get to Monday (day_of_week: 1=Monday, 0=Sunday)
    int days_to_subtract = (mdt.day_of_week == 0) ? 6 : mdt.day_of_week - 1;
    
    // Set to start of day
    mdt.hour = 0;
    mdt.min = 0;
    mdt.sec = 0;
    
    datetime week_start = StructToTime(mdt) - days_to_subtract * 86400; // 86400 = 1 day in seconds
    
    return week_start;
}

//+------------------------------------------------------------------+
//| Calculate Crabel volatility value                               |
//+------------------------------------------------------------------+
double CalculateCrabelVolatility(int week_index, const double &week_high[], const double &week_open[], const double &week_low[])
{
    // Need enough historical data for SMA calculation
    int required_bars = week_index + Crabel_SMA_Period;
    if(required_bars > ArraySize(week_high))
        return 0.0;
    
    double sum = 0.0;
    int valid_values = 0;
    
    // Calculate SMA of Min(High-Open, Open-Low) for the specified period
    for(int i = week_index; i < week_index + Crabel_SMA_Period && i < ArraySize(week_high); i++)
    {
        double high_minus_open = week_high[i] - week_open[i];
        double open_minus_low = week_open[i] - week_low[i];
        double min_value = MathMin(high_minus_open, open_minus_low);
        
        if(min_value > 0) // Only include positive values
        {
            sum += min_value;
            valid_values++;
        }
    }
    
    if(valid_values > 0)
        return sum / valid_values;
    else
        return 0.0;
}

//+------------------------------------------------------------------+
//| Draw Larry (ATR-based) volatility lines                         |
//+------------------------------------------------------------------+
void DrawLarryLines(datetime week_start, datetime week_end, double current_week_open, int week_index, const double &atr_values[])
{
    // Larry method: ATR-based
    int atr_index = (week_index + 1 < ArraySize(atr_values)) ? week_index + 1 : week_index;
    if(atr_values[atr_index] <= 0)
    {
        Print("Invalid ATR value: ", atr_values[atr_index]);
        return;
    }
    
    double volatility_range = atr_values[atr_index] * ATR_Multiplier;
    double upper_level = current_week_open + volatility_range;
    double lower_level = current_week_open - volatility_range;
    
    Print("Larry - Week: ", TimeToString(week_start), " Open: ", current_week_open, 
          " ATR: ", atr_values[atr_index], " Upper: ", upper_level, " Lower: ", lower_level);
    
    // Create unique object names for Larry
    string week_str = TimeToString(week_start, TIME_DATE);
    StringReplace(week_str, ".", "_");
    StringReplace(week_str, " ", "_");
    string upper_line_name = indicator_prefix + "Larry_Upper_" + week_str;
    string lower_line_name = indicator_prefix + "Larry_Lower_" + week_str;
    string upper_label_name = indicator_prefix + "Larry_UpperLabel_" + week_str;
    string lower_label_name = indicator_prefix + "Larry_LowerLabel_" + week_str;
    
    // Delete existing objects first
    ObjectDelete(0, upper_line_name);
    ObjectDelete(0, lower_line_name);
    ObjectDelete(0, upper_label_name);
    ObjectDelete(0, lower_label_name);
    
    // Draw Larry upper line
    if(ObjectCreate(0, upper_line_name, OBJ_TREND, 0, week_start, upper_level, week_end, upper_level))
    {
        ObjectSetInteger(0, upper_line_name, OBJPROP_COLOR, Larry_Upper_Color);
        ObjectSetInteger(0, upper_line_name, OBJPROP_STYLE, Line_Style);
        ObjectSetInteger(0, upper_line_name, OBJPROP_WIDTH, Line_Width);
        ObjectSetInteger(0, upper_line_name, OBJPROP_RAY_RIGHT, false);
        ObjectSetInteger(0, upper_line_name, OBJPROP_RAY_LEFT, false);
        ObjectSetInteger(0, upper_line_name, OBJPROP_BACK, false);
        ObjectSetInteger(0, upper_line_name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, upper_line_name, OBJPROP_SELECTED, false);
        ObjectSetInteger(0, upper_line_name, OBJPROP_HIDDEN, false);
    }
    
    // Draw Larry lower line
    if(ObjectCreate(0, lower_line_name, OBJ_TREND, 0, week_start, lower_level, week_end, lower_level))
    {
        ObjectSetInteger(0, lower_line_name, OBJPROP_COLOR, Larry_Lower_Color);
        ObjectSetInteger(0, lower_line_name, OBJPROP_STYLE, Line_Style);
        ObjectSetInteger(0, lower_line_name, OBJPROP_WIDTH, Line_Width);
        ObjectSetInteger(0, lower_line_name, OBJPROP_RAY_RIGHT, false);
        ObjectSetInteger(0, lower_line_name, OBJPROP_RAY_LEFT, false);
        ObjectSetInteger(0, lower_line_name, OBJPROP_BACK, false);
        ObjectSetInteger(0, lower_line_name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, lower_line_name, OBJPROP_SELECTED, false);
        ObjectSetInteger(0, lower_line_name, OBJPROP_HIDDEN, false);
    }
    
    // Draw Larry labels if enabled
    if(Show_Labels)
    {
        string upper_text = "Larry Volatility High: " + DoubleToString(upper_level, _Digits);
        string lower_text = "Larry Volatility Low: " + DoubleToString(lower_level, _Digits);
        
        // Larry Upper label
        if(ObjectCreate(0, upper_label_name, OBJ_TEXT, 0, week_start, upper_level))
        {
            ObjectSetString(0, upper_label_name, OBJPROP_TEXT, upper_text);
            ObjectSetInteger(0, upper_label_name, OBJPROP_COLOR, Label_Color);
            ObjectSetInteger(0, upper_label_name, OBJPROP_FONTSIZE, Label_Font_Size);
            ObjectSetInteger(0, upper_label_name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
            ObjectSetInteger(0, upper_label_name, OBJPROP_BACK, false);
            ObjectSetInteger(0, upper_label_name, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, upper_label_name, OBJPROP_SELECTED, false);
            ObjectSetInteger(0, upper_label_name, OBJPROP_HIDDEN, false);
        }
        
        // Larry Lower label
        if(ObjectCreate(0, lower_label_name, OBJ_TEXT, 0, week_start, lower_level))
        {
            ObjectSetString(0, lower_label_name, OBJPROP_TEXT, lower_text);
            ObjectSetInteger(0, lower_label_name, OBJPROP_COLOR, Label_Color);
            ObjectSetInteger(0, lower_label_name, OBJPROP_FONTSIZE, Label_Font_Size);
            ObjectSetInteger(0, lower_label_name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
            ObjectSetInteger(0, lower_label_name, OBJPROP_BACK, false);
            ObjectSetInteger(0, lower_label_name, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, lower_label_name, OBJPROP_SELECTED, false);
            ObjectSetInteger(0, lower_label_name, OBJPROP_HIDDEN, false);
        }
    }
}

//+------------------------------------------------------------------+
//| Draw Crabel volatility lines                                    |
//+------------------------------------------------------------------+
void DrawCrabelLines(datetime week_start, datetime week_end, double current_week_open, int week_index, 
                     const double &week_high[], const double &week_open[], const double &week_low[])
{
    // Crabel method: Min(High-Open, Open-Low) SMA with multiplier
    double crabel_value = CalculateCrabelVolatility(week_index + 1, week_high, week_open, week_low);
    if(crabel_value <= 0)
    {
        Print("Invalid Crabel volatility value: ", crabel_value);
        return;
    }
    
    double volatility_range = crabel_value * Crabel_Multiplier;
    double upper_level = current_week_open + volatility_range;
    double lower_level = current_week_open - volatility_range;
    
    Print("Crabel - Week: ", TimeToString(week_start), " Open: ", current_week_open, 
          " Range: ", volatility_range, " Upper: ", upper_level, " Lower: ", lower_level);
    
    // Create unique object names for Crabel
    string week_str = TimeToString(week_start, TIME_DATE);
    StringReplace(week_str, ".", "_");
    StringReplace(week_str, " ", "_");
    string upper_line_name = indicator_prefix + "Crabel_Upper_" + week_str;
    string lower_line_name = indicator_prefix + "Crabel_Lower_" + week_str;
    string upper_label_name = indicator_prefix + "Crabel_UpperLabel_" + week_str;
    string lower_label_name = indicator_prefix + "Crabel_LowerLabel_" + week_str;
    
    // Delete existing objects first
    ObjectDelete(0, upper_line_name);
    ObjectDelete(0, lower_line_name);
    ObjectDelete(0, upper_label_name);
    ObjectDelete(0, lower_label_name);
    
    // Draw Crabel upper line
    if(ObjectCreate(0, upper_line_name, OBJ_TREND, 0, week_start, upper_level, week_end, upper_level))
    {
        ObjectSetInteger(0, upper_line_name, OBJPROP_COLOR, Crabel_Upper_Color);
        ObjectSetInteger(0, upper_line_name, OBJPROP_STYLE, Line_Style);
        ObjectSetInteger(0, upper_line_name, OBJPROP_WIDTH, Line_Width);
        ObjectSetInteger(0, upper_line_name, OBJPROP_RAY_RIGHT, false);
        ObjectSetInteger(0, upper_line_name, OBJPROP_RAY_LEFT, false);
        ObjectSetInteger(0, upper_line_name, OBJPROP_BACK, false);
        ObjectSetInteger(0, upper_line_name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, upper_line_name, OBJPROP_SELECTED, false);
        ObjectSetInteger(0, upper_line_name, OBJPROP_HIDDEN, false);
    }
    
    // Draw Crabel lower line
    if(ObjectCreate(0, lower_line_name, OBJ_TREND, 0, week_start, lower_level, week_end, lower_level))
    {
        ObjectSetInteger(0, lower_line_name, OBJPROP_COLOR, Crabel_Lower_Color);
        ObjectSetInteger(0, lower_line_name, OBJPROP_STYLE, Line_Style);
        ObjectSetInteger(0, lower_line_name, OBJPROP_WIDTH, Line_Width);
        ObjectSetInteger(0, lower_line_name, OBJPROP_RAY_RIGHT, false);
        ObjectSetInteger(0, lower_line_name, OBJPROP_RAY_LEFT, false);
        ObjectSetInteger(0, lower_line_name, OBJPROP_BACK, false);
        ObjectSetInteger(0, lower_line_name, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, lower_line_name, OBJPROP_SELECTED, false);
        ObjectSetInteger(0, lower_line_name, OBJPROP_HIDDEN, false);
    }
    
    // Draw Crabel labels if enabled
    if(Show_Labels)
    {
        string upper_text = "Crabel Volatility High: " + DoubleToString(upper_level, _Digits);
        string lower_text = "Crabel Volatility Low: " + DoubleToString(lower_level, _Digits);
        
        // Crabel Upper label
        if(ObjectCreate(0, upper_label_name, OBJ_TEXT, 0, week_start, upper_level))
        {
            ObjectSetString(0, upper_label_name, OBJPROP_TEXT, upper_text);
            ObjectSetInteger(0, upper_label_name, OBJPROP_COLOR, Label_Color);
            ObjectSetInteger(0, upper_label_name, OBJPROP_FONTSIZE, Label_Font_Size);
            ObjectSetInteger(0, upper_label_name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
            ObjectSetInteger(0, upper_label_name, OBJPROP_BACK, false);
            ObjectSetInteger(0, upper_label_name, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, upper_label_name, OBJPROP_SELECTED, false);
            ObjectSetInteger(0, upper_label_name, OBJPROP_HIDDEN, false);
        }
        
        // Crabel Lower label
        if(ObjectCreate(0, lower_label_name, OBJ_TEXT, 0, week_start, lower_level))
        {
            ObjectSetString(0, lower_label_name, OBJPROP_TEXT, lower_text);
            ObjectSetInteger(0, lower_label_name, OBJPROP_COLOR, Label_Color);
            ObjectSetInteger(0, lower_label_name, OBJPROP_FONTSIZE, Label_Font_Size);
            ObjectSetInteger(0, lower_label_name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
            ObjectSetInteger(0, lower_label_name, OBJPROP_BACK, false);
            ObjectSetInteger(0, lower_label_name, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(0, lower_label_name, OBJPROP_SELECTED, false);
            ObjectSetInteger(0, lower_label_name, OBJPROP_HIDDEN, false);
        }
    }
}

//+------------------------------------------------------------------+
//| Draw weekly volatility lines                                    |
//+------------------------------------------------------------------+
void DrawWeeklyVolatilityLines(datetime week_start)
{
    // Arrays for weekly data
    double atr_values[];
    datetime week_times[];
    double week_open[], week_high[], week_low[];
    
    ArraySetAsSeries(atr_values, true);
    ArraySetAsSeries(week_times, true);
    ArraySetAsSeries(week_open, true);
    ArraySetAsSeries(week_high, true);
    ArraySetAsSeries(week_low, true);
    
    // Copy data with error checking (increased buffer size for more historical data)
    int buffer_size = MathMax(Historical_Weeks + Crabel_SMA_Period + 10, 100);
    int atr_copied = CopyBuffer(atr_handle, 0, 0, buffer_size, atr_values);
    int time_copied = CopyTime(_Symbol, PERIOD_W1, 0, buffer_size, week_times);
    int open_copied = CopyOpen(_Symbol, PERIOD_W1, 0, buffer_size, week_open);
    int high_copied = CopyHigh(_Symbol, PERIOD_W1, 0, buffer_size, week_high);
    int low_copied = CopyLow(_Symbol, PERIOD_W1, 0, buffer_size, week_low);
    
    if(atr_copied <= 0 || time_copied <= 0 || open_copied <= 0 || high_copied <= 0 || low_copied <= 0)
    {
        Print("Error copying data: ATR=", atr_copied, " Time=", time_copied, 
              " Open=", open_copied, " High=", high_copied, " Low=", low_copied);
        return;
    }
    
    // Find the weekly bar index for our target week
    int week_index = -1;
    for(int i = 0; i < ArraySize(week_times) - 1; i++)
    {
        if(week_times[i] <= week_start + 86400 && week_times[i] >= week_start - 86400) // Allow some tolerance
        {
            week_index = i;
            break;
        }
    }
    
    if(week_index == -1)
    {
        Print("Could not find week index for: ", TimeToString(week_start));
        return;
    }
    
    // Calculate week end time (end of Friday)
    datetime week_end = week_start + 604800 - 1; // End of week
    double current_week_open = week_open[week_index];
    
    // Draw lines based on selected method
    if(Volatility_Method == LARRY || Volatility_Method == BOTH)
    {
        DrawLarryLines(week_start, week_end, current_week_open, week_index, atr_values);
    }
    
    if(Volatility_Method == CRABEL || Volatility_Method == BOTH)
    {
        DrawCrabelLines(week_start, week_end, current_week_open, week_index, week_high, week_open, week_low);
    }
    
    // Force chart redraw
    ChartRedraw(0);
}

//+------------------------------------------------------------------+