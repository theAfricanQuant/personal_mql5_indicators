//+------------------------------------------------------------------+
//|                                   threefold_market_structure.mq5 |
//|                                      Ricky Macharm, MScFE        |
//|                     Based on Larry Williams' Market Structure    |
//|                                      https://www.SisengAI.com    |
//+------------------------------------------------------------------+
#property copyright "Ricky Macharm, MScFE"
#property link      "https://www.SisengAI.com"
#property version   "1.13"
#property indicator_chart_window
#property indicator_buffers 4
#property indicator_plots   4


//--- plot Short Term Highs
#property indicator_label1  "STH"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  3

//--- plot Short Term Lows
#property indicator_label2  "STL"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrBlue
#property indicator_style2  STYLE_SOLID
#property indicator_width2  3

//--- plot Intermediate Term Highs
#property indicator_label3  "ITH"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrGold
#property indicator_style3  STYLE_SOLID
#property indicator_width3  5

//--- plot Intermediate Term Lows
#property indicator_label4  "ITL"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrGold
#property indicator_style4  STYLE_SOLID
#property indicator_width4  5

//--- input parameters
input int InpBarsBack = 1000; // Bars to look back from current
input bool InpAlternatingMode = true; // Alternating STH/STL mode
input bool InpShowDebug = false; // Show debug info
input bool InpShowUnconfirmed = true; // Show unconfirmed swing points
input int InpConfirmationBars = 2; // Bars needed for confirmation
input int InpSwingStrength = 2; // Swing strength (bars on each side)

//--- indicator buffers
double HighArrowBuffer[];
double LowArrowBuffer[];
double IntHighArrowBuffer[];
double IntLowArrowBuffer[];

//--- global variables
struct SwingPoint {
    int bar;
    double price;  
    double confirmationLevel;
    datetime time;
    bool isValid;
    bool isConfirmed;
};

SwingPoint allSTH[];
SwingPoint allSTL[];
SwingPoint allITH[];
SwingPoint allITL[];
int sthCount = 0;
int stlCount = 0;
int ithCount = 0;
int itlCount = 0;

bool expectingSTL = false; // For alternating mode

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- indicator buffers mapping
    SetIndexBuffer(0, HighArrowBuffer, INDICATOR_DATA);
    SetIndexBuffer(1, LowArrowBuffer, INDICATOR_DATA);
    SetIndexBuffer(2, IntHighArrowBuffer, INDICATOR_DATA);
    SetIndexBuffer(3, IntLowArrowBuffer, INDICATOR_DATA);
    
    //--- set arrow symbols - using round dots
    PlotIndexSetInteger(0, PLOT_ARROW, 159); // Small round dot for STH
    PlotIndexSetInteger(1, PLOT_ARROW, 159); // Small round dot for STL
    PlotIndexSetInteger(2, PLOT_ARROW, 161); // Large round dot for ITH
    PlotIndexSetInteger(3, PLOT_ARROW, 161); // Large round dot for ITL
    
    //--- set empty values
    PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);
    
    //--- set indicator name
    IndicatorSetString(INDICATOR_SHORTNAME, "Market Structure");
    
    if(InpShowDebug)
        Print("Market Structure Indicator initialized, Alternating mode: ", InpAlternatingMode);
    
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
    // Set all arrays as series for consistent indexing
    ArraySetAsSeries(time, true);
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(HighArrowBuffer, true);
    ArraySetAsSeries(LowArrowBuffer, true);
    ArraySetAsSeries(IntHighArrowBuffer, true);
    ArraySetAsSeries(IntLowArrowBuffer, true);

    //--- check for minimum bars
    if(rates_total < InpSwingStrength * 2 + 5) {
        if(InpShowDebug) 
            Print("Not enough bars: ", rates_total);
        return(0);
    }
    
    //--- Calculate start position (corrected for time series)
    int start = InpSwingStrength;
    int end = rates_total - InpSwingStrength;
    
    if(prev_calculated == 0) {
        // Full recalculation
        ArrayInitialize(HighArrowBuffer, EMPTY_VALUE);
        ArrayInitialize(LowArrowBuffer, EMPTY_VALUE);
        ArrayInitialize(IntHighArrowBuffer, EMPTY_VALUE);
        ArrayInitialize(IntLowArrowBuffer, EMPTY_VALUE);
        
        // Reset swing point arrays
        ArrayResize(allSTH, 0);
        ArrayResize(allSTL, 0);
        ArrayResize(allITH, 0);
        ArrayResize(allITL, 0);
        sthCount = 0;
        stlCount = 0;
        ithCount = 0;
        itlCount = 0;
        expectingSTL = false;
        
        if(InpShowDebug) 
            Print("Full recalculation starting for ", rates_total, " bars");
    } else {
        start = MathMax(start, rates_total - prev_calculated - 20);
    }
    
    // Limit processing based on InpBarsBack
    if(InpBarsBack > 0 && rates_total > InpBarsBack) {
        start = MathMax(start, rates_total - InpBarsBack);
    }
    
    //--- Process from oldest to newest (right to left on chart)
    for(int i = end - 1; i >= start; i--) {
        // Check for swing points
        if(IsSwingHigh(high, i, InpSwingStrength)) {
            ProcessPotentialSTH(i, high[i], low[i], time[i]);
        }
        
        if(IsSwingLow(low, i, InpSwingStrength)) {
            ProcessPotentialSTL(i, low[i], high[i], time[i]);
        }
    }
    
    //--- Check confirmations (pass time array)
    CheckConfirmations(high, low, time, rates_total);
    
    //--- Process intermediate term points
    ProcessIntermediateTermPoints();
    
    //--- Update display (pass time array)
    UpdateArrows(time, rates_total);
    
    if(InpShowDebug && prev_calculated == 0) {
        Print("Calculation complete. STH count: ", sthCount, ", STL count: ", stlCount, 
              ", ITH count: ", ithCount, ", ITL count: ", itlCount);
    }
    
    return(rates_total);
}

//+------------------------------------------------------------------+
//| Check if bar is a swing high                                    |
//+------------------------------------------------------------------+
bool IsSwingHigh(const double &high[], int bar, int strength)
{
    // Remember: with ArraySetAsSeries(true):
    // bar 0 = current/newest
    // increasing bar = older bars
    double currentHigh = high[bar];
    
    // Check newer bars (lower indices)
    for(int i = 1; i <= strength; i++) {
        int idx = bar - i;
        if(idx < 0) return false;
        if(high[idx] >= currentHigh) return false;
    }
    
    // Check older bars (higher indices)
    for(int i = 1; i <= strength; i++) {
        int idx = bar + i;
        if(idx >= ArraySize(high)) return false;
        if(high[idx] >= currentHigh) return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check if bar is a swing low                                     |
//+------------------------------------------------------------------+
bool IsSwingLow(const double &low[], int bar, int strength)
{
    double currentLow = low[bar];
    
    // Check newer bars (lower indices)
    for(int i = 1; i <= strength; i++) {
        int idx = bar - i;
        if(idx < 0) return false;
        if(low[idx] <= currentLow) return false;
    }
    
    // Check older bars (higher indices)
    for(int i = 1; i <= strength; i++) {
        int idx = bar + i;
        if(idx >= ArraySize(low)) return false;
        if(low[idx] <= currentLow) return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Check confirmations using time mapping                          |
//+------------------------------------------------------------------+
void CheckConfirmations(const double &high[], const double &low[], const datetime &time[], int rates_total)
{
    // Check STH confirmations
    for(int i = 0; i < sthCount; i++) {
        if(!allSTH[i].isConfirmed && allSTH[i].isValid) {
            int currentBarIndex = FindBarByTime(time, rates_total, allSTH[i].time);
            if(currentBarIndex != -1 && currentBarIndex >= InpConfirmationBars) {
                allSTH[i].isConfirmed = true;
                if(InpShowDebug)
                    Print("STH confirmed at time ", allSTH[i].time, " current index ", currentBarIndex);
            }
        }
    }
    
    // Check STL confirmations
    for(int i = 0; i < stlCount; i++) {
        if(!allSTL[i].isConfirmed && allSTL[i].isValid) {
            int currentBarIndex = FindBarByTime(time, rates_total, allSTL[i].time);
            if(currentBarIndex != -1 && currentBarIndex >= InpConfirmationBars) {
                allSTL[i].isConfirmed = true;
                if(InpShowDebug)
                    Print("STL confirmed at time ", allSTL[i].time, " current index ", currentBarIndex);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Process potential STH                                           |
//+------------------------------------------------------------------+
void ProcessPotentialSTH(int bar, double highPrice, double lowPrice, datetime t)
{
    if(InpAlternatingMode) {
        // In alternating mode, we need to track the sequence properly
        if(sthCount == 0) {
            // First STH, always add
            AddSTH(bar, highPrice, lowPrice, t);
            expectingSTL = true;
            if(InpShowDebug) Print("First STH added, now expecting STL");
        } else if(expectingSTL) {
            // We're expecting STL but found STH - update if it's better
            if(highPrice > allSTH[sthCount-1].price) {
                allSTH[sthCount-1].bar = bar;
                allSTH[sthCount-1].price = highPrice;
                allSTH[sthCount-1].confirmationLevel = lowPrice;
                allSTH[sthCount-1].time = t;
                allSTH[sthCount-1].isConfirmed = false;
                if(InpShowDebug) Print("Updated STH with higher price: ", highPrice);
            }
        } else {
            // We found STH when expecting STH (after STL) - add new one
            AddSTH(bar, highPrice, lowPrice, t);
            expectingSTL = true;
            if(InpShowDebug) Print("New STH after STL, now expecting STL");
        }
    } else {
        // Non-alternating mode: add all swing highs
        AddSTH(bar, highPrice, lowPrice, t);
    }
}

//+------------------------------------------------------------------+
//| Process potential STL                                           |
//+------------------------------------------------------------------+
void ProcessPotentialSTL(int bar, double lowPrice, double highPrice, datetime t)
{
    if(InpAlternatingMode) {
        // In alternating mode, keep logic consistent with STH processing
        if(stlCount == 0 && expectingSTL) {
            // First STL after a STH
            AddSTL(bar, lowPrice, highPrice, t);
            expectingSTL = false;
            if(InpShowDebug) Print("First STL added, now expecting STH");
        }
        else if(expectingSTL) {
            // We are expecting an STL (after the last STH) -> add new one
            AddSTL(bar, lowPrice, highPrice, t);
            expectingSTL = false;
            if(InpShowDebug) Print("New STL after STH, now expecting STH");
        }
        else {
            // We are NOT expecting an STL (we expect a STH). If we still find an STL,
            // allow updating the most recent STL if this one is "better" (lower)
            if(stlCount > 0 && lowPrice < allSTL[stlCount-1].price) {
                allSTL[stlCount-1].bar = bar;
                allSTL[stlCount-1].price = lowPrice;
                allSTL[stlCount-1].confirmationLevel = highPrice;
                allSTL[stlCount-1].time = t;
                allSTL[stlCount-1].isConfirmed = false;
                if(InpShowDebug) Print("Updated STL with lower price: ", lowPrice);
            }
        }
    } else {
        // Non-alternating mode: add all swing lows
        AddSTL(bar, lowPrice, highPrice, t);
    }
}

//+------------------------------------------------------------------+
//| Process intermediate term points                                 |
//+------------------------------------------------------------------+
void ProcessIntermediateTermPoints()
{
    // Reset intermediate term arrays
    ArrayResize(allITH, 0);
    ArrayResize(allITL, 0);
    ithCount = 0;
    itlCount = 0;
    
    // Process ITH - need at least 3 confirmed STHs
    for(int i = 1; i < sthCount - 1; i++) {
        if(allSTH[i-1].isConfirmed && allSTH[i].isConfirmed && allSTH[i+1].isConfirmed) {
            if(allSTH[i].price > allSTH[i-1].price && allSTH[i].price > allSTH[i+1].price) {
                AddITH(allSTH[i].bar, allSTH[i].price, allSTH[i].time);
            }
        }
    }
    
    // Process ITL - need at least 3 confirmed STLs
    for(int i = 1; i < stlCount - 1; i++) {
        if(allSTL[i-1].isConfirmed && allSTL[i].isConfirmed && allSTL[i+1].isConfirmed) {
            if(allSTL[i].price < allSTL[i-1].price && allSTL[i].price < allSTL[i+1].price) {
                AddITL(allSTL[i].bar, allSTL[i].price, allSTL[i].time);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Add STH to array                                                 |
//+------------------------------------------------------------------+
void AddSTH(int bar, double highPrice, double lowPrice, datetime t)
{
    ArrayResize(allSTH, sthCount + 1);
    allSTH[sthCount].bar = bar;
    allSTH[sthCount].price = highPrice;
    allSTH[sthCount].confirmationLevel = lowPrice;
    allSTH[sthCount].time = t;
    allSTH[sthCount].isValid = true;
    allSTH[sthCount].isConfirmed = false;
    sthCount++;
    
    if(InpShowDebug)
        Print("STH added at bar ", bar, " price ", highPrice);
}

//+------------------------------------------------------------------+
//| Add STL to array                                                 |
//+------------------------------------------------------------------+
void AddSTL(int bar, double lowPrice, double highPrice, datetime t)
{
    ArrayResize(allSTL, stlCount + 1);
    allSTL[stlCount].bar = bar;
    allSTL[stlCount].price = lowPrice;
    allSTL[stlCount].confirmationLevel = highPrice;
    allSTL[stlCount].time = t;
    allSTL[stlCount].isValid = true;
    allSTL[stlCount].isConfirmed = false;
    stlCount++;
    
    if(InpShowDebug)
        Print("STL added at bar ", bar, " price ", lowPrice);
}

//+------------------------------------------------------------------+
//| Add ITH to array                                                 |
//+------------------------------------------------------------------+
void AddITH(int bar, double price, datetime t)
{
    ArrayResize(allITH, ithCount + 1);
    allITH[ithCount].bar = bar;
    allITH[ithCount].price = price;
    allITH[ithCount].time = t;
    allITH[ithCount].isValid = true;
    allITH[ithCount].isConfirmed = true;
    ithCount++;
}

//+------------------------------------------------------------------+
//| Add ITL to array                                                 |
//+------------------------------------------------------------------+
void AddITL(int bar, double price, datetime t)
{
    ArrayResize(allITL, itlCount + 1);
    allITL[itlCount].bar = bar;
    allITL[itlCount].price = price;
    allITL[itlCount].time = t;
    allITL[itlCount].isValid = true;
    allITL[itlCount].isConfirmed = true;
    itlCount++;
}

//+------------------------------------------------------------------+
//| Update arrow display using time mapping                         |
//+------------------------------------------------------------------+
void UpdateArrows(const datetime &timeArr[], int rates_total)
{
    ArraySetAsSeries(HighArrowBuffer, true);
    ArraySetAsSeries(LowArrowBuffer, true);
    ArraySetAsSeries(IntHighArrowBuffer, true);
    ArraySetAsSeries(IntLowArrowBuffer, true);

    ArrayInitialize(HighArrowBuffer, EMPTY_VALUE);
    ArrayInitialize(LowArrowBuffer, EMPTY_VALUE);
    ArrayInitialize(IntHighArrowBuffer, EMPTY_VALUE);
    ArrayInitialize(IntLowArrowBuffer, EMPTY_VALUE);

    // Display STH arrows using current time mapping (with fallback to stored bar index)
    for(int i = 0; i < sthCount; i++) {
        if(allSTH[i].isValid && (allSTH[i].isConfirmed || InpShowUnconfirmed)) {
            int idx = FindBarByTime(timeArr, rates_total, allSTH[i].time);
            if(idx == -1) { // fallback: use stored bar index if it fits in current array
                if(allSTH[i].bar >= 0 && allSTH[i].bar < rates_total)
                    idx = allSTH[i].bar;
                if(InpShowDebug)
                    Print("FindBarByTime failed for STH time ", allSTH[i].time, " using fallback bar ", allSTH[i].bar, " --> idx=", idx);
            }
            if(idx != -1 && idx >= 0 && idx < ArraySize(HighArrowBuffer)) {
                HighArrowBuffer[idx] = allSTH[i].price;
                if(InpShowDebug)
                    Print("Displaying STH at index ", idx, " time ", allSTH[i].time, " price ", allSTH[i].price);
            }
        }
    }

    // Display STL arrows using current time mapping (with fallback)
    for(int i = 0; i < stlCount; i++) {
        if(allSTL[i].isValid && (allSTL[i].isConfirmed || InpShowUnconfirmed)) {
            int idx = FindBarByTime(timeArr, rates_total, allSTL[i].time);
            if(idx == -1) {
                if(allSTL[i].bar >= 0 && allSTL[i].bar < rates_total)
                    idx = allSTL[i].bar;
                if(InpShowDebug)
                    Print("FindBarByTime failed for STL time ", allSTL[i].time, " using fallback bar ", allSTL[i].bar, " --> idx=", idx);
            }
            if(idx != -1 && idx >= 0 && idx < ArraySize(LowArrowBuffer)) {
                LowArrowBuffer[idx] = allSTL[i].price;
                if(InpShowDebug)
                    Print("Displaying STL at index ", idx, " time ", allSTL[i].time, " price ", allSTL[i].price);
            }
        }
    }

    // ITH
    for(int i = 0; i < ithCount; i++) {
        if(allITH[i].isValid) {
            int idx = FindBarByTime(timeArr, rates_total, allITH[i].time);
            if(idx == -1 && allITH[i].bar >= 0 && allITH[i].bar < rates_total) idx = allITH[i].bar;
            if(idx != -1 && idx >= 0 && idx < ArraySize(IntHighArrowBuffer)) {
                IntHighArrowBuffer[idx] = allITH[i].price;
                if(InpShowDebug) Print("Displaying ITH at idx ", idx, " price ", allITH[i].price);
            }
        }
    }

    // ITL
    for(int i = 0; i < itlCount; i++) {
        if(allITL[i].isValid) {
            int idx = FindBarByTime(timeArr, rates_total, allITL[i].time);
            if(idx == -1 && allITL[i].bar >= 0 && allITL[i].bar < rates_total) idx = allITL[i].bar;
            if(idx != -1 && idx >= 0 && idx < ArraySize(IntLowArrowBuffer)) {
                IntLowArrowBuffer[idx] = allITL[i].price;
                if(InpShowDebug) Print("Displaying ITL at idx ", idx, " price ", allITL[i].price);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Helper function to find current bar index by time               |
//+------------------------------------------------------------------+
int FindBarByTime(const datetime &timeArr[], int rates_total, datetime t)
{
    // ensure caller and this function use the same series orientation
    // most callers set ArraySetAsSeries(..., true), but make local safe
    // NOTE: ArraySetAsSeries modifies the array metadata; it's safe to call here.
    // However we cannot call ArraySetAsSeries(timeArr, true) for const reference,
    // so assume timeArr is series (set in OnCalculate). Use tolerant search.
    for(int j = 0; j < rates_total; j++) {
        if(timeArr[j] == t)
            return j;
    }
    // If not found using forward scan (series=true), try reverse scan (series=false)
    for(int j = rates_total - 1; j >= 0; j--) {
        if(timeArr[j] == t)
            return j;
    }
    return -1; // Not found
}