#property copyright "Copyright ©2024, Sachin Gautam"
#property link "Join our Telegram channel https://t.me/SachinFX"
#property version "3.0"
#property description "timeframe M1, pair US30.i or US30"
#property description "Market Watch 16:30 hrs"

// --- User Settings ---
extern string GeneralSettings = "GENERAL SETTINGS";
extern int MagicNumber = 7;              // Magic Number for trade identification
extern int Slippage = 1;                 // Maximum price slippage in points
extern string TimeSettings = "TIME SETTINGS";
extern int StartHour = 16;               // Trading Start Hour
extern int EndHour = 22;                 // Trading End Hour
extern string MoneyManagement = "MONEY MANAGEMENT";
extern double FixedLot = 0.01;           // Fixed lot size (0.0 enables Risk-based MM)
extern double RiskPercent = 2.0;         // Risk percentage for Money Management
extern string TradeSettings = "TRADE SETTINGS";
extern double Delta = 0.5;               // Order distance in points
extern double MaxDistance = 7;           // Maximum order distance
extern double StopLoss = 10;             // Stop loss in points
extern double TrailingStop = 4;          // Trailing stop in points
extern int MaxSpread = 16000;            // Maximum spread in points
extern int MaxTradesPerDay = 5;          // Maximum trades allowed per day
extern bool EnableBreakEven = true;      // Enable break-even feature
extern double BreakEvenBuffer = 2;       // Buffer for break-even in points

// --- Internal Variables ---
double PointValue, LotStep, MinLot, MaxLot, MarginRequired;
int DigitsCount, SpreadLevel, StopLevel, FreezeLevel;
int DailyTradeCount = 0;
datetime LastTradeDay;

enum TradeDirection { BUY, SELL };

// --- Function Declarations ---
bool IsBreakEvenTriggered(double openPrice, double currentPrice, TradeDirection direction);
int ValidateInputs();
void InitializeSettings();
double CalculateLotSize();
void ManageOpenTrades();
void ModifyOrder(int ticket, double newStopLoss, double newTakeProfit);
void PlaceTrade(TradeDirection direction);

// --- Check Break-Even Trigger ---
bool IsBreakEvenTriggered(double openPrice, double currentPrice, TradeDirection direction) {
    if (direction == BUY) {
        return currentPrice >= openPrice + BreakEvenBuffer * PointValue;
    } else {
        return currentPrice <= openPrice - BreakEvenBuffer * PointValue;
    }
}

// --- Initialization ---
int OnInit() {
    if (ValidateInputs() != 0) {
        return INIT_FAILED;
    }
    InitializeSettings();
    Print("Expert Advisor initialized successfully.");
    return INIT_SUCCEEDED;
}

// --- Main Function ---
int OnTick() {
    if (SpreadLevel > MaxSpread) {
        Print("Spread exceeds the maximum allowed level.");
        return 0;
    }

    if (Hour() < StartHour || Hour() >= EndHour) {
        Print("Out of trading hours.");
        return 0;
    }

    if (Day() != TimeDay(LastTradeDay)) {
        DailyTradeCount = 0;
        LastTradeDay = TimeCurrent();
    }

    if (DailyTradeCount >= MaxTradesPerDay) {
        Print("Daily trade limit reached.");
        return 0;
    }

    ManageOpenTrades();

    if (OrdersTotal() == 0) {
        PlaceTrade(BUY);
        PlaceTrade(SELL);
        DailyTradeCount += 2;
    }

    return 0;
}

// --- Validate Inputs ---
int ValidateInputs() {
    if (FixedLot < 0 || RiskPercent < 0 || Delta <= 0 || StopLoss <= 0 || MaxDistance <= 0 || TrailingStop < 0) {
        Print("Invalid input parameters.");
        return -1;
    }
    return 0;
}

// --- Initialize Broker Settings ---
void InitializeSettings() {
    PointValue = MarketInfo(Symbol(), MODE_POINT);
    LotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
    MinLot = MarketInfo(Symbol(), MODE_MINLOT);
    MaxLot = MarketInfo(Symbol(), MODE_MAXLOT);
    MarginRequired = MarketInfo(Symbol(), MODE_MARGINREQUIRED);
    DigitsCount = MarketInfo(Symbol(), MODE_DIGITS);
    SpreadLevel = MarketInfo(Symbol(), MODE_SPREAD) * PointValue;
    StopLevel = MarketInfo(Symbol(), MODE_STOPLEVEL) * PointValue;
    FreezeLevel = MarketInfo(Symbol(), MODE_FREEZELEVEL) * PointValue;
}

// --- Calculate Lot Size ---
double CalculateLotSize() {
    if (FixedLot > 0) {
        return FixedLot;
    }

    double AccountRisk = (RiskPercent / 100.0) * AccountBalance();
    double LotSize = AccountRisk / (StopLoss * PointValue * MarginRequired);

    if (LotSize > MaxLot) LotSize = MaxLot;
    if (LotSize < MinLot) LotSize = MinLot;

    return NormalizeDouble(LotSize, 2);
}

// --- Manage Open Trades ---
void ManageOpenTrades() {
    for (int i = OrdersTotal() - 1; i >= 0; i--) {
        if (!OrderSelect(i, SELECT_BY_POS)) continue;

        if (OrderMagicNumber() != MagicNumber || OrderSymbol() != Symbol()) continue;

        double Profit = OrderProfit();
        double OpenPrice = OrderOpenPrice();
        double StopLoss = OrderStopLoss();
        double CurrentPrice = (OrderType() == OP_BUY) ? Bid : Ask;

        // Trailing Stop
        if ((OrderType() == OP_BUY && CurrentPrice - OpenPrice > TrailingStop * PointValue) ||
            (OrderType() == OP_SELL && OpenPrice - CurrentPrice > TrailingStop * PointValue)) {
            double NewStop = (OrderType() == OP_BUY) ? CurrentPrice - TrailingStop * PointValue
                                                    : CurrentPrice + TrailingStop * PointValue;
            ModifyOrder(OrderTicket(), NormalizeDouble(NewStop, DigitsCount), OrderTakeProfit());
        }

        // Break-Even
        if (EnableBreakEven && IsBreakEvenTriggered(OpenPrice, CurrentPrice, (OrderType() == OP_BUY) ? BUY : SELL)) {
            double BreakEvenPrice = (OrderType() == OP_BUY) ? OpenPrice + BreakEvenBuffer * PointValue
                                                           : OpenPrice - BreakEvenBuffer * PointValue;
            ModifyOrder(OrderTicket(), NormalizeDouble(BreakEvenPrice, DigitsCount), OrderTakeProfit());
        }
    }
}

// --- Modify Order ---
void ModifyOrder(int ticket, double newStopLoss, double newTakeProfit) {
    if (!OrderModify(ticket, OrderOpenPrice(), newStopLoss, newTakeProfit, OrderExpiration(), clrNONE)) {
        Print("Error modifying order: ", GetLastError());
    }
}

// --- Place Trade ---
void PlaceTrade(TradeDirection direction) {
    double LotSize = CalculateLotSize();
    double EntryPrice = (direction == BUY) ? Ask : Bid;
    double SL = (direction == BUY) ? EntryPrice - StopLoss * PointValue : EntryPrice + StopLoss * PointValue;
    double TP = (direction == BUY) ? EntryPrice + MaxDistance * PointValue : EntryPrice - MaxDistance * PointValue;

    int Ticket = OrderSend(Symbol(), direction == BUY ? OP_BUY : OP_SELL, LotSize, EntryPrice, Slippage, SL, TP, "", MagicNumber, 0, clrNONE);

    if (Ticket < 0) {
        Print("OrderSend failed with error: ", GetLastError());
    } else {
        Print("Order placed successfully. Ticket: ", Ticket);
    }
}
