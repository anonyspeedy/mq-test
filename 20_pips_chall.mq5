//+------------------------------------------------------------------+
//| Optimized EMA Crossover EA with Visual Signals                  |
//+------------------------------------------------------------------+
#property copyright "Anony$peedy"
#property version   "1.11"
#property strict

// --- Input Parameters ---
input int FastEMA_Period = 10;    // Fast EMA period
input int SlowEMA_Period = 20;    // Slow EMA period
input double LotSize = 0.1;       // Fixed lot size
input double StopLoss = 50;       // Stop Loss in pips
input double TakeProfit = 100;    // Take Profit in pips
input int Slippage = 3;           // Slippage
input int MagicNumber = 12345;    // Unique identifier for orders

// --- Allowed Trading Symbols ---
string AllowedSymbols[] = {"EURUSD", "CADJPY", "XAUUSD"};

// --- Global Variables ---
int FastEMA_Handle, SlowEMA_Handle;
double FastEMA_Buffer[], SlowEMA_Buffer[];
string CSVFileName = "EMA_Crossover_Data.csv";

//+------------------------------------------------------------------+
//| Expert Initialization Function                                  |
//+------------------------------------------------------------------+
int OnInit()
{
    // Disable grid on the chart
    ChartSetInteger(0, CHART_SHOW_GRID, false);

    // Enable auto-scroll
    ChartSetInteger(0, CHART_AUTOSCROLL, true);

    // Initialize EMA handles
    FastEMA_Handle = iMA(_Symbol, PERIOD_M15, FastEMA_Period, 0, MODE_EMA, PRICE_CLOSE);
    SlowEMA_Handle = iMA(_Symbol, PERIOD_M15, SlowEMA_Period, 0, MODE_EMA, PRICE_CLOSE);

    if (FastEMA_Handle == INVALID_HANDLE || SlowEMA_Handle == INVALID_HANDLE)
    {
        Print("❌ Failed to create indicator handles!");
        return INIT_FAILED;
    }

    // Create CSV file and write header
    int fileHandle = FileOpen(CSVFileName, FILE_WRITE | FILE_CSV | FILE_ANSI, ",");
    if (fileHandle == INVALID_HANDLE)
    {
        Print("❌ Failed to create CSV file! Error: ", GetLastError());
        return INIT_FAILED;
    }
    
    FileWrite(fileHandle, "Timestamp", "Symbol", "Bid", "Ask", "FastEMA", "SlowEMA", "BuySignal", "SellSignal", "Spread", "PositionType", "PositionSize", "Outcome");
    FileClose(fileHandle);

    Print("✅ EA Initialized successfully.");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnTick Function - Main Trading Logic                            |
//+------------------------------------------------------------------+
void OnTick()
{
    // Check if the current symbol is allowed
    if (!IsSymbolAllowed(_Symbol)) return;

    // Execute logic only on a new candle
    if (IsNewCandle())
    {
        // Copy EMA values
        if (CopyBuffer(FastEMA_Handle, 0, 0, 2, FastEMA_Buffer) != 2 ||
            CopyBuffer(SlowEMA_Handle, 0, 0, 2, SlowEMA_Buffer) != 2)
        {
            Print("❌ Failed to copy EMA buffers!");
            return;
        }

        // Get price data
        double Bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double Ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double Spread = Ask - Bid;

        // Determine EMA crossover signals
        int BuySignal = 0, SellSignal = 0;
        if (FastEMA_Buffer[1] < SlowEMA_Buffer[1] && FastEMA_Buffer[0] > SlowEMA_Buffer[0]) BuySignal = 1;
        if (FastEMA_Buffer[1] > SlowEMA_Buffer[1] && FastEMA_Buffer[0] < SlowEMA_Buffer[0]) SellSignal = 1;

        // Check for open positions
        if (!PositionSelect(_Symbol))
        {
            // No open position, check for new trade signals
            if (BuySignal || SellSignal)
            {
                double SL, TP;
                string positionOutcome = "Unknown"; // Initialize Outcome as Unknown
                if (BuySignal)
                {
                    SL = NormalizeDouble(Bid - StopLoss * _Point * GetPipMultiplier(), _Digits);
                    TP = NormalizeDouble(Bid + TakeProfit * _Point * GetPipMultiplier(), _Digits);
                    OpenTrade(ORDER_TYPE_BUY, LotSize, Ask, SL, TP);

                    // Outcome can be defined here, for example, if TP/SL is hit
                    positionOutcome = "BuySignal";

                    // Draw bullish signal (green triangle)
                    DrawSignal("BuySignal", TimeCurrent(), Bid, clrGreen, 234);
                }
                else if (SellSignal)
                {
                    SL = NormalizeDouble(Ask + StopLoss * _Point * GetPipMultiplier(), _Digits);
                    TP = NormalizeDouble(Ask - TakeProfit * _Point * GetPipMultiplier(), _Digits);
                    OpenTrade(ORDER_TYPE_SELL, LotSize, Bid, SL, TP);

                    // Outcome can be defined here, for example, if TP/SL is hit
                    positionOutcome = "SellSignal";

                    // Draw bearish signal (red triangle)
                    DrawSignal("SellSignal", TimeCurrent(), Ask, clrRed, 233);
                }

                // Log position opened data, including the outcome
                LogPositionData(BuySignal ? "Buy" : "Sell", LotSize, GetLastTradeOutcome());
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Open Trade Function                                             |
//+------------------------------------------------------------------+
void OpenTrade(ENUM_ORDER_TYPE orderType, double lot, double price, double sl, double tp)
{
    MqlTradeRequest request = {};
    MqlTradeResult result = {};

    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.volume = lot;
    request.type = orderType;
    request.price = price;
    request.sl = sl;
    request.tp = tp;
    request.deviation = Slippage;
    request.magic = MagicNumber;

    if (OrderSend(request, result))
    {
        if (result.retcode == 10009 || result.retcode == 10008)
            Print("✅ Trade executed: ", result.comment);
        else
            Print("❌ Trade failed! Error code: ", result.retcode);
    }
}

string GetLastTradeOutcome()
{
    // Select all closed trades within the last 100 bars
    if (!HistorySelect(0, TimeCurrent()))
        return "Unknown";

    // Get the total number of closed positions
    int totalHistory = HistoryDealsTotal();
    
    for (int i = totalHistory - 1; i >= 0; i--)
    {
        ulong ticket = HistoryDealGetTicket(i);
        if (ticket > 0)
        {
            string symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
            if (symbol == _Symbol)
            {
                double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
                if (profit > 0) return "Win";
                if (profit < 0) return "Loss";
            }
        }
    }
    return "Unknown"; // No closed trades found
}


//+------------------------------------------------------------------+
//| Log Position Data                                               |
//+------------------------------------------------------------------+
void LogPositionData(string positionType, double positionSize, string outcome)
{
           
    // Copy EMA values
    if (CopyBuffer(FastEMA_Handle, 0, 0, 1, FastEMA_Buffer) < 1 ||
        CopyBuffer(SlowEMA_Handle, 0, 0, 1, SlowEMA_Buffer) < 1)
    {
        Print("❌ Failed to copy EMA buffers!");
        return;
    }

    // Get price data
    double Bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double Ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double Spread = Ask - Bid;

    // Determine EMA crossover signals
    int BuySignal = (FastEMA_Buffer[0] > SlowEMA_Buffer[0]) ? 1: 0;
    int SellSignal = (FastEMA_Buffer[0] < SlowEMA_Buffer[0]) ? 1 : 0;

    // Log data to CSV
    int fileHandle = FileOpen(CSVFileName, FILE_READ | FILE_WRITE | FILE_CSV | FILE_ANSI , ",");
    if (fileHandle != INVALID_HANDLE)
    {
        FileSeek(fileHandle, 0, SEEK_END);
        FileWrite(
            fileHandle,
            TimeToString(TimeCurrent()), // Timestamp
            _Symbol, // Symbol
            DoubleToString(Bid, _Digits), // Bid
            DoubleToString(Ask, _Digits), // Ask
            DoubleToString(FastEMA_Buffer[0], _Digits), // FastEMA
            DoubleToString(SlowEMA_Buffer[0], _Digits), // SlowEMA
            IntegerToString(BuySignal), // BuySignal
            IntegerToString(SellSignal), // SellSignal
            DoubleToString(Spread, _Digits), // Spread
            positionType, // PositionType
            DoubleToString(positionSize, 2), // PositionSize
            outcome // Outcome
        );
        FileClose(fileHandle);
    }
    else
    {
        Print("❌ Failed to open CSV file for writing!");
    }
}

//+------------------------------------------------------------------+
//| Draw Signal on Chart                                            |
//+------------------------------------------------------------------+
void DrawSignal(string name, datetime time, double price, color clr, int code)
{
    // Create a unique object name
    string objName = name + "_" + IntegerToString(time);

    // Draw a triangle (Wingdings font)
    ObjectCreate(0, objName, OBJ_TEXT, 0, time, price);
    ObjectSetString(0, objName, OBJPROP_FONT, "Wingdings");
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, objName, OBJPROP_ANCHOR, ANCHOR_CENTER);
    ObjectSetString(0, objName, OBJPROP_TEXT, CharToString(code));
    ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 10);
}

//+------------------------------------------------------------------+
bool IsSymbolAllowed(const string symbol)
{
    for (int i = 0; i < ArraySize(AllowedSymbols); i++)
        if (symbol == AllowedSymbols[i]) return true;
    return false;
}

double GetPipMultiplier() { return (StringFind(_Symbol, "JPY") != -1) ? 0.1 : 1.0; }

bool IsNewCandle()
{
    static datetime lastTime = 0;
    datetime currentTime = iTime(_Symbol, PERIOD_M15, 0);
    if (lastTime != currentTime) { lastTime = currentTime; return true; }
    return false;
}
