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
    //--- check for minimum bars
    if(rates_total < InpSwingStrength * 2 + 5) {
        if(InpShowDebug) 
            Print("Not enough bars: ", rates_total);
        return(0);
    }
    
    //--- Calculate start position
    int start = InpSwingStrength + 1;
    int limit = rates_total - InpSwingStrength - 1;
    
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
        start = MathMax(start, prev_calculated - 20);
    }
    
    // Limit processing based on InpBarsBack
    if(InpBarsBack > 0 && rates_total > InpBarsBack) {
        start = MathMax(start, rates_total - InpBarsBack);
    }
    
    //--- Process each bar for swing points
    for(int i = start; i < limit; i++) {
        // Check for swing points
        if(IsSwingHigh(high, i, InpSwingStrength)) {
            ProcessPotentialSTH(i, high[i], low[i], time[i]);
        }
        
        if(IsSwingLow(low, i, InpSwingStrength)) {
            ProcessPotentialSTL(i, low[i], high[i], time[i]);
        }
    }
    
    //--- Check confirmations
    CheckConfirmations(high, low, rates_total);
    
    //--- Process intermediate term points
    ProcessIntermediateTermPoints();
    
    //--- Update display
    UpdateArrows();
    
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
    double currentHigh = high[bar];
    
    // Check bars before
    for(int i = 1; i <= strength; i++) {
        if(bar - i < 0 || high[bar - i] >= currentHigh)
            return false;
    }
    
    // Check bars after
    for(int i = 1; i <= strength; i++) {
        if(bar + i >= ArraySize(high) || high[bar + i] >= currentHigh)
            return false;
    }
    
    if(InpShowDebug)
        Print("Swing High detected at bar ", bar, " price ", currentHigh);
    return true;
}

//+------------------------------------------------------------------+
//| Check if bar is a swing low                                     |
//+------------------------------------------------------------------+
bool IsSwingLow(const double &low[], int bar, int strength)
{
    double currentLow = low[bar];
    
    // Check bars before
    for(int i = 1; i <= strength; i++) {
        if(bar - i < 0 || low[bar - i] <= currentLow)
            return false;
    }
    
    // Check bars after
    for(int i = 1; i <= strength; i++) {
        if(bar + i >= ArraySize(low) || low[bar + i] <= currentLow)
            return false;
    }
    
    if(InpShowDebug)
        Print("Swing Low detected at bar ", bar, " price ", currentLow);
    return true;
}

//+------------------------------------------------------------------+
//| Check confirmations for swing points                            |
//+------------------------------------------------------------------+
void CheckConfirmations(const double &high[], const double &low[], int rates_total)
{
    // Check STH confirmations
    for(int i = 0; i < sthCount; i++) {
        if(!allSTH[i].isConfirmed && allSTH[i].isValid) {
            if(rates_total - allSTH[i].bar >= InpConfirmationBars) {
                allSTH[i].isConfirmed = true;
                if(InpShowDebug)
                    Print("STH confirmed at bar ", allSTH[i].bar);
            }
        }
    }
    
    // Check STL confirmations
    for(int i = 0; i < stlCount; i++) {
        if(!allSTL[i].isConfirmed && allSTL[i].isValid) {
            if(rates_total - allSTL[i].bar >= InpConfirmationBars) {
                allSTL[i].isConfirmed = true;
                if(InpShowDebug)
                    Print("STL confirmed at bar ", allSTL[i].bar);
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
        if(!expectingSTL) { // We're looking for STH
            if(sthCount == 0 || bar > allSTH[sthCount-1].bar) {
                AddSTH(bar, highPrice, lowPrice, t);
                expectingSTL = true; // Now expect STL
            } else if(sthCount > 0 && highPrice > allSTH[sthCount-1].price) {
                // Update existing STH with higher price
                allSTH[sthCount-1].bar = bar;
                allSTH[sthCount-1].price = highPrice;
                allSTH[sthCount-1].confirmationLevel = lowPrice;
                allSTH[sthCount-1].time = t;
                allSTH[sthCount-1].isConfirmed = false;
            }
        }
    } else {
        AddSTH(bar, highPrice, lowPrice, t);
    }
}

//+------------------------------------------------------------------+
//| Process potential STL                                           |
//+------------------------------------------------------------------+
void ProcessPotentialSTL(int bar, double lowPrice, double highPrice, datetime t)
{
    if(InpAlternatingMode) {
        if(expectingSTL) { // We're looking for STL
            if(stlCount == 0 || bar > allSTL[stlCount-1].bar) {
                AddSTL(bar, lowPrice, highPrice, t);
                expectingSTL = false; // Now expect STH
            } else if(stlCount > 0 && lowPrice < allSTL[stlCount-1].price) {
                // Update existing STL with lower price
                allSTL[stlCount-1].bar = bar;
                allSTL[stlCount-1].price = lowPrice;
                allSTL[stlCount-1].confirmationLevel = highPrice;
                allSTL[stlCount-1].time = t;
                allSTL[stlCount-1].isConfirmed = false;
            }
        }
    } else {
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
//| Update arrow display                                             |
//+------------------------------------------------------------------+
void UpdateArrows()
{
    // Clear all arrows
    ArrayInitialize(HighArrowBuffer, EMPTY_VALUE);
    ArrayInitialize(LowArrowBuffer, EMPTY_VALUE);
    ArrayInitialize(IntHighArrowBuffer, EMPTY_VALUE);
    ArrayInitialize(IntLowArrowBuffer, EMPTY_VALUE);
    
    // Display STH arrows
    for(int i = 0; i < sthCount; i++) {
        if(allSTH[i].isValid && (allSTH[i].isConfirmed || InpShowUnconfirmed)) {
            int bufferSize = ArraySize(HighArrowBuffer);
            if(allSTH[i].bar >= 0 && allSTH[i].bar < bufferSize) {
                HighArrowBuffer[allSTH[i].bar] = allSTH[i].price;
            }
        }
    }
    
    // Display STL arrows
    for(int i = 0; i < stlCount; i++) {
        if(allSTL[i].isValid && (allSTL[i].isConfirmed || InpShowUnconfirmed)) {
            int bufferSize = ArraySize(LowArrowBuffer);
            if(allSTL[i].bar >= 0 && allSTL[i].bar < bufferSize) {
                LowArrowBuffer[allSTL[i].bar] = allSTL[i].price;
            }
        }
    }
    
    // Display ITH arrows
    for(int i = 0; i < ithCount; i++) {
        if(allITH[i].isValid) {
            int bufferSize = ArraySize(IntHighArrowBuffer);
            if(allITH[i].bar >= 0 && allITH[i].bar < bufferSize) {
                IntHighArrowBuffer[allITH[i].bar] = allITH[i].price;
            }
        }
    }
    
    // Display ITL arrows
    for(int i = 0; i < itlCount; i++) {
        if(allITL[i].isValid) {
            int bufferSize = ArraySize(IntLowArrowBuffer);
            if(allITL[i].bar >= 0 && allITL[i].bar < bufferSize) {
                IntLowArrowBuffer[allITL[i].bar] = allITL[i].price;
            }
        }
    }
}