//+------------------------------------------------------------------+
//|                                               RiseUp.mq5         |
//|                                  Copyright 2025, Anony$peedy     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, Anony$peedy"
#property link      "https://t.me/AnonySpeedy"
#property version   "1.3"

#define EA_VERSION "1.3"

#include <Trade\Trade.mqh>    //included to save lot of time like buying selling positioning code included there
#include <PropfirmPanel.mqh>
   CTrade         trade;      //on Class trade when can buy sell open close positions
   CPositionInfo  posinfo;    //on cposition tells us wheter the position opened or closed
   COrderInfo     ord;    //on corderinfo tells us all orders like buystop sellstop buy limit sell limit 
   CPropfirmPanel panel;

enum enumSystemType{Fixed_pips_profile=0, Pct_of_Price_Profile=1};
enum StartHours     {Inactive=0, _1=1, _2=2, _3=3, _4=4, _5=5, _6=6, _7=7, _8=8, _9=9, _10=10, _11=11, _12=12, _13=13, _14=14, _15=15, _16=16, _17=17, _18=18, _19=19, _20=20, _21=21, _22=22, _23=23, _24=24};
enum EndHours     {Inactive=0, _1=1, _2=2, _3=3, _4=4, _5=5, _6=6, _7=7, _8=8, _9=9, _10=10, _11=11, _12=12, _13=13, _14=14, _15=15, _16=16, _17=17, _18=18, _19=19, _20=20, _21=21, _22=22, _23=23, _24=24};
enum enumLotType  {Fixed_Lots=0, Pct_of_Balance=1, Pct_of_Equity=2, Pct_of_Free_Margin=3};
enum TSLType      {Default_Trail=0, Prevous_Candle=1, Fast_MA=2, Tenkansen=3};

double   BegofDayBalance, BegofWeekBalance, BegofMthBalance;
double   DD_1D_Pct=0, DD_7D_Pct=0, DD_30D_Pct=0, DD_AT_Pct=0, Prf_1D_Pct=0, Prf_7D_Pct=0, Prf_30D_Pct=0, Prf_AT_Pct=0;
double   EqHigh_1D=0, EqHigh_7D=0, EqHigh_30D=0, EqHigh_AT=0;
string   StartDayofChallenge;
MqlDateTime ChallengeStart;
 

int      handleRSI, handleMovAvg, handleTrailMA, handleIchimoku;

// --- License Inputs ---
string WebAppURL = "https://script.google.com/macros/s/AKfycbzp8mGCKByjZO4N5ERA2Lk0TNpSErI97WiZ968Ega_dt8tfNt1s4voYHJTXEwIv4G3o/exec";
string DefaultTelegramContact = "https://t.me/AnonySpeedy"; // Your primary Telegram link for support
int LicenseCheckIntervalHours = 1; // How often to check license (hours)

// --- License Global Variables ---
datetime lastLicenseCheckTime = 0;
long     accountNumber = 0;
string   hwid = "";
string   accountType = ""; // "real" or "demo"
double   eaTotalRealizedProfit = 0.0; // Profit accumulated by this specific EA instance
double   eaTotalSwap = 0.0;
double   eaTotalCommission = 0.0;
string   currentTelegramContact = DefaultTelegramContact;
string   profitFileName = "ea_profit_data.bin";

// License status variables
bool     isLicensed = false;
bool     isTrialActive = false;
bool     isLocked = false;
bool     isProfitLocked = false;
int      trialDaysRemaining = 0;
double   profitThreshold = 0.0;
string   licenseMessage = "Initializing...";

input group "=== Trading Profiles ==="
input enumSystemType SType=0; //Trading System applied (Forex, Crypto, Gold, Indices)

input group "=== Common Trading Inputs ==="
input enumLotType          LotType     = 1;     //Type of Lotsize (Fixed or % Risk)
input double               FixedLots   = 0.01;  // Fixed Lots (if selected)
input double               RiskPercent    =2;      //Risk in % on each trade
input ENUM_TIMEFRAMES      Timeframe = PERIOD_M5;  //Time frame to run
input int                  InpMagic = 123456;      //EA ID
input string               TradeComment = "RizeUpV1.1";  //Trade Comment

input StartHours     SHInput=4;     //Start Hour
input EndHours      EHInput=20;     //End Hour

input int      BarN          = 100;     //No of Bars to identify high/low
input int      ExpirationBars = 300;   //No of Bars before order is expired

      bool     Tradingenabled       = true;
input bool     HideIndicators       = true;     // Hide Indicators on Chats?
      string   TradingEnabledComm   = "";

input group "=== Forex Trading Inputs ==="
input int      TppointsInput       = 200;   // Take Profit (10 points = 1 pip)
input int      SlPointsInput       = 200;   // Stop Loss (10 points - 1 pip)
input int      TslPointsInput      = 10;    //Trailing Stop Loss (10 points = 1 pip)
input int      Ts1TriggerPointsInput = 20;  //Points in profit before Trailing SL is activated (10 points = 1 pip)
input double   OrderDistPointsInput = 100;
double   Tppoints, Slpoints, TslPoints, TslTriggerPoints, OrderDistPoints;

input group "=== as % of Price Profile Inputs =="
input double      TPasPct       = 0.4;   // TP as % of Price
input double      SLasPct       = 0.4;   // SL as % of Price
input double      TSLasPctofSL  = 5;    //Trail SL as % of SL
input double      TSLTgrasPctofSL = 10;  //Trigger of Trail sl % of SL
input double      OrderDisPtasPctofSL = 50; //Minimum order distance as % of SL

input group "===Trailing Stop Management ==="
input TSLType     TrailType            = 0;  //Type of Trailing StopLoss
input int         PrvCandleN           = 1;  //No of candles to trail SL (if selected)
input int         FMAperiod            = 5;  //Fast-moving avg period to trail on (if selected)

input group "=== News Filter ==="
input bool        NewsFilterOn         = true;     //Filter For News?
enum  sep_dropdown{comma=0, semicolon=1};
input sep_dropdown   separator         = 0;        //Separator to separate news keywords
input string         KeyNews           = "BCB,NFP,JOLTS,Nonfarm,PMI,Retail,GDP,Confidence,Interst Rate"; //Keywords in News to avoid (separated by separator)
input string         NewsCurrencies    ="USD";  //Currencies for news lookup
input int            DaysNewsLookUP    = 100;         //No of Days to look up news
input int            StopBeforMin      = 15;          // Stop Trading Before (in Min)
input int            StartTradingMin   = 15;          //Start Trading after   (in min)
      bool           TrDisabledNews    = false;       // Variable to store if trading disabled due to news

      
      ushort      sep_code;
      string      Newstoavoid[];
      datetime    LastNewsAvoided;

input group "=== RSI Filter ==="
input bool           RSIFilterOn       =false;        //Filter for RSI extremes?
input ENUM_TIMEFRAMES RSITimeframe     = PERIOD_H1;    // TimeFrame for RSI filter
input int            RSIlowerlvl       = 20;          // RSI Lower Level to filter
input int            RSIUpperlvl       = 80;          // RSI Upper Level to filter
input int            RSI_MA            = 14;          // RSI Period
input ENUM_APPLIED_PRICE   RSI_AppPrice = PRICE_MEDIAN;// RSI Applied Price

input group "=== MA Filter ==="
input bool           MAFilterOn        =false;        //Filter for Moving Average extremes ?
input ENUM_TIMEFRAMES   MATimeframe    = PERIOD_H4;    //Timeframe for Moving Average Filter
input   double         PctPricefromMA    = 3;           //% Price is away from Mov AVG to be extreme
input int            MA_Period         = 200;         // Moving Average Period
input ENUM_MA_METHOD MA_Mode           = MODE_EMA;    // Moving Average Mode
input ENUM_APPLIED_PRICE MA_AppPrice   = PRICE_MEDIAN; // Moving Avg Applied Price

input group "=== Trading Allowed by Days ==="
input bool           AllowedMonday        = true;     // Trading Allowed on Monday?
input bool           AllowedTuesday       = true;     // Trading Allowed on Tuesday?
input bool           AllowedWednesday     = true;     // Trading Allowed on Wednesday?
input bool           AllowedThursday      = true;     // Trading Allowed on Thursday?
input bool           AllowedFriday        = true;     // Trading Allowed on Friday?
input bool           AllowedSaturday      = false;     // Trading Allowed on Saturday?
input bool           AllowedSunday        = false;     // Trading Allowed on Sunday?
      bool           DayFilterOn          = true;     

input group "=== Propfirm Rules Settings ==="
input int            InitialBalance       = 5000;     // Initial Balance
input double         ProfitTraget         = 10;       // Profit Target for Prop Challenge
input datetime       StartofChallenge     = D'2025.5.7 00:00'; // Start day of the month (for Challenge)
input int            ChallengeLenght      = 30;       // No of days for challenge
input double         MaxDDday             = 4;        // Max Drawdown for day allowed
input double         MaxDDweek            = 8;        // Max Drawdown for week allowed
input double         MaxDDMonth           = 12;        // Max Drawdown for 30-days allowed
input double         MaxDDTotal           = 8;        // Max Drawdown for entire cahllenge allowed

//+------------------------------------------------------------------+
//| License Helper Functions                                         |
//+------------------------------------------------------------------+

string GetPseudoHWID()
{
    long accNum = AccountInfoInteger(ACCOUNT_LOGIN);
    return IntegerToString(accNum);
}

string GetAccountType()
{
    if(AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_DEMO)
        return "demo";
    return "real";
}

double GetEAProfitFromFile()
{
    int fileHandle = FileOpen(profitFileName, FILE_BIN | FILE_READ);
    if(fileHandle != INVALID_HANDLE)
    {
        double savedProfit = FileReadDouble(fileHandle);
        double savedSwap = FileReadDouble(fileHandle);
        double savedCommission = FileReadDouble(fileHandle);
        FileClose(fileHandle);
        eaTotalSwap = savedSwap;
        eaTotalCommission = savedCommission;
        return savedProfit;
    }
    return 0.0;
}

void SaveEAProfitToFile(double profit, double swap, double commission)
{
    int fileHandle = FileOpen(profitFileName, FILE_BIN | FILE_WRITE);
    if(fileHandle != INVALID_HANDLE)
    {
        FileWriteDouble(fileHandle, profit);
        FileWriteDouble(fileHandle, swap);
        FileWriteDouble(fileHandle, commission);
        FileClose(fileHandle);
    }
}


double GetTotalEAProfit() {
    double totalProfit = 0.0;
    HistorySelect(0, TimeCurrent());
    for(long i = 0; i < HistoryDealsTotal(); i++) {
        ulong dealTicket = HistoryDealGetTicket(i);
        if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) == InpMagic &&
           HistoryDealGetInteger(dealTicket, DEAL_ENTRY) == DEAL_ENTRY_OUT) {
            double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
            double dealSwap = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
            double dealCommission = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
            totalProfit += (dealProfit + dealSwap + dealCommission);
        }
    }
    return totalProfit;
}

bool SendLicenseRequest(string &message)
{
    double profit = GetTotalEAProfit();
    string fullUrl = StringFormat("%s?hwid=%s&accountNumber=%I64d&accountType=%s&currentProfit=%.2f", 
    WebAppURL, hwid, accountNumber, accountType, profit);

    Print("DEBUG: Sending WebRequest to: ", fullUrl);

    char result[];
    string resultHeaders;
    char emptyData[];
    int timeout = 10000;
    
    ResetLastError();
    int res = WebRequest("GET", fullUrl, "", "", timeout, emptyData, 0, result, resultHeaders);
    
    if(res == -1)
    {
        int error = GetLastError();
        message = "WebRequest failed. Error: " + IntegerToString(error);
        Print("DEBUG: WebRequest failed. Error: ", error);
        
        // Common errors that users can fix
        if(error == 4014) // ERR_FUNCTION_NOT_ALLOWED
            message += "\nPlease enable WebRequest in MetaTrader settings and add URL to allowed list";
        else if(error == 4060) // ERR_WEBREQUEST_REQUEST_FAILED
            message += "\nNetwork connection failed. Please check your internet";
            
        return false;
    }

    string response = CharArrayToString(result);
    Print("DEBUG: Server response: ", response);
    
    // Parse JSON response
    if(StringFind(response, "{\"status\":") == 0)
    {
        int p = 0;
        string status = "";
        string msg = "";
        
        // Simple JSON parsing (for more complex needs, consider a JSON library)
        p = StringFind(response, "\"status\":\"", p);
        if(p >= 0)
        {
            p += 10; // length of "\"status\":\""
            int end = StringFind(response, "\"", p);
            if(end > p) status = StringSubstr(response, p, end - p);
        }
        
        p = StringFind(response, "\"message\":\"", p);
        if(p >= 0)
        {
            p += 11; // length of "\"message\":\""
            int end = StringFind(response, "\"", p);
            if(end > p) msg = StringSubstr(response, p, end - p);
        }
        
        // Update license status based on response
        if(status == "valid")
        {
            isLicensed = true;
            isTrialActive = false;
            isLocked = false;
            message = "EA LICENSED. All features active.";
        }
        else if(status == "trial_active")
        {
            isLicensed = false;
            isTrialActive = true;
            isLocked = false;
            
            // Get days remaining
            p = StringFind(response, "\"days_remaining\":", p);
            if(p >= 0)
            {
                p += 17; // length of "\"days_remaining\":"
                int end = StringFind(response, ",", p);
                if(end > p) 
                    trialDaysRemaining = (int)StringToInteger(StringSubstr(response, p, end - p));
            }
            
            // Get profit threshold
            p = StringFind(response, "\"profit_threshold\":", p);
            if(p >= 0)
            {
                p += 19; // length of "\"profit_threshold\":"
                int end = StringFind(response, ",", p);
                if(end > p) 
                    profitThreshold = StringToDouble(StringSubstr(response, p, end - p));
            }
            
            // Get telegram contact if different
            p = StringFind(response, "\"telegram_contact\":\"", p);
            if(p >= 0)
            {
                p += 20; // length of "\"telegram_contact\":\""
                int end = StringFind(response, "\"", p);
                if(end > p) 
                    currentTelegramContact = StringSubstr(response, p, end - p);
            }
            
            message = StringFormat("TRIAL ACTIVE: %d days left\nProfit Limit: $%.2f\nYour Profit: $%.2f",
                      trialDaysRemaining, profitThreshold, eaTotalRealizedProfit);
        }
        else if(status == "locked")
        {
            isLicensed = false;
            isTrialActive = false;
            isLocked = true;
            
            // Check if locked due to profit
            p = StringFind(response, "\"profit_locked\":", p);
            if(p >= 0)
            {
                p += 16; // length of "\"profit_locked\":"
                int end = StringFind(response, ",", p);
                if(end > p) 
                    isProfitLocked = (StringSubstr(response, p, end - p) == "true");
            }
            
            if(isProfitLocked)
            {
                message = StringFormat("LICENSE LOCKED: Profit limit of $%.2f reached\nContact: %s",
                          profitThreshold, currentTelegramContact);
            }
            else
            {
                message = msg + "\nContact: " + currentTelegramContact;
            }
        }
        else
        {
            isLicensed = false;
            isTrialActive = false;
            isLocked = true;
            message = "License check failed: " + msg;
        }
        
        return true;
    }
    
    message = "Invalid server response format";
    return false;
}

bool CheckLicenseStatus() // Changed return type to bool
{
    // Skip license checks in Strategy Tester/Optimization
    if(MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_OPTIMIZATION))
    {
        licenseMessage = "⚠️ Running in Strategy Tester (License checks disabled)";
        isLicensed = true;
        isLocked = false;
        return true; // Return true to allow trading in tester
    }

    // Original license check for live/demo trading
    string message = "";
    bool success = SendLicenseRequest(message);
    
    if(success)
    {
        licenseMessage = message + "\nContact: " + currentTelegramContact;
    }
    else
    {
        licenseMessage = message;
        isLocked = true; 
    }
    
    SaveEAProfitToFile(eaTotalRealizedProfit, eaTotalSwap, eaTotalCommission);
    return success; // Return the send status
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    // Show important setup message
    MessageBox("IMPORTANT: For the EA to function, you MUST enable WebRequest for the URL:\n" + WebAppURL + 
               "\n\nGo to Tools -> Options -> Expert Advisors Tab and check 'Allow WebRequest for listed URL:'. Then add this URL to the list.\n\nClick OK to continue.",
               "EA License Check Setup", MB_OK | MB_ICONINFORMATION);

    // Initialize license info
    accountNumber = AccountInfoInteger(ACCOUNT_LOGIN);
    hwid = GetPseudoHWID();
    accountType = GetAccountType();
    eaTotalRealizedProfit = GetTotalEAProfit();

    
    CheckLicenseStatus();
    
    if(isLocked)
    {
        MessageBox(licenseMessage, "EA Locked", MB_ICONSTOP);
    }
    
    lastLicenseCheckTime = TimeCurrent();

    // Original initialization code
    trade.SetExpertMagicNumber(InpMagic);
    panel.Oninit();
     
    TimeToStruct(StartofChallenge,ChallengeStart);
    StartDayofChallenge = EnumToString((ENUM_DAY_OF_WEEK)ChallengeStart.day_of_week);
   
    BegofDayBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    BegofWeekBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    BegofMthBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   
    ChartSetInteger(0,CHART_SHOW_GRID,false);
      
    double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   
    switch(SType){
        case 0:
            Tppoints = TppointsInput;
            Slpoints = SlPointsInput;
            TslTriggerPoints = Ts1TriggerPointsInput;
            TslPoints = Ts1TriggerPointsInput;
            OrderDistPoints = OrderDistPointsInput;
            break;
        case 1:
            Tppoints = ask * TPasPct/100/_Point;
            Slpoints = ask * SLasPct/100/_Point;
            OrderDistPoints = Slpoints * OrderDisPtasPctofSL/100;            
            TslPoints = Slpoints * TSLasPctofSL/100;
            TslTriggerPoints = Slpoints * TSLTgrasPctofSL/100;
            break;
    }
   
    int stoplevel = (int) SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
    Print("Minimum Stoploss Distance Required by Broker on ", _Symbol, ": ", stoplevel, " Points.");
   
    if(TslPoints<stoplevel){
        Print("Trailing Stoploss value of ", (int)TslPoints, "is smaller than allowed by broker.");
        Print("Overriding to Broker Minimum of ", stoplevel, " points.");
        TslPoints = stoplevel;
    }else
    {
        Print("Current Trailing Stop value of ", (int)TslPoints, " is OK.");
    }
   
    TesterHideIndicators(false);
         
    if(HideIndicators==true) TesterHideIndicators(true);
   
    handleRSI = iRSI(_Symbol,RSITimeframe,RSI_MA, RSI_AppPrice);
    handleMovAvg= iMA(_Symbol, MATimeframe, MA_Period, 0, MA_Mode, MA_AppPrice);
    if(TrailType==2) handleTrailMA = iMA(_Symbol,Timeframe,FMAperiod,0,MA_Mode,MA_AppPrice);
    if(TrailType==3) handleIchimoku = iIchimoku(_Symbol,Timeframe,9,26,52);
   
    //--- Create a status label with proper alignment
    ObjectCreate(0, "EA_Status", OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, "EA_Status", OBJPROP_CORNER, CORNER_RIGHT_UPPER);
    ObjectSetInteger(0, "EA_Status", OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
    ObjectSetInteger(0, "EA_Status", OBJPROP_XDISTANCE, 20);
    ObjectSetInteger(0, "EA_Status", OBJPROP_YDISTANCE, 20);
    ObjectSetInteger(0, "EA_Status", OBJPROP_FONTSIZE, 10);
    ObjectSetInteger(0, "EA_Status", OBJPROP_COLOR, clrWhite);
    ObjectSetString(0, "EA_Status", OBJPROP_FONT, "Consolas");
   
   
    return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
    SaveEAProfitToFile(eaTotalRealizedProfit, eaTotalSwap, eaTotalCommission);
    panel.Destroy(reason);
}

void OnTick()
{
    
    
    // Check license status periodically
    if(TimeCurrent() - lastLicenseCheckTime > LicenseCheckIntervalHours * 3600)
    {
        CheckLicenseStatus();
        lastLicenseCheckTime = TimeCurrent();
    }
    
    // Stop trading if locked
    if(isLocked)
    {
        CloseAllPositionsNow();
        CloseAllOrders();
        Comment(licenseMessage);
        return;
    }

    // Original OnTick logic
    TrailStop();
    UpdateInitialBalances();
    UpdatePropfirmValues();
    panel.Update();
    IsTradingAllowedPropValues();
   
    if(IsNewBar()){
        string statusText = "RiseUp v" + EA_VERSION + " 🟢 ENABLED";
        color textColor = clrLime;

        if (!IsTradingAllowedPropValues()) {
            statusText = "RiseUp v" + EA_VERSION + " 🔴 Max DD: " + StringSubstr((string)DD_AT_Pct, 0, 4) + "%";
            textColor = clrOrangeRed;
        }
        else if (IsRSIFilter()) {
            double rsiValue = iRSI(_Symbol, RSITimeframe, RSI_MA, RSI_AppPrice);
            statusText = "RiseUp v" + EA_VERSION + " ⚠️ RSI: " + StringSubstr((string)rsiValue, 0, 4);
            textColor = clrGold;
        }
        else if (IsMAFilter()) {
            statusText = "RiseUp v" + EA_VERSION + " 📉 MA Filter Active";
            textColor = clrViolet;
        }
        else if (IsUpcomingNews()) {
            statusText = "RiseUp v" + EA_VERSION + " 📢 News Ahead";
            textColor = clrDeepPink;
        }

        ObjectSetString(0, "EA_Status", OBJPROP_TEXT, statusText);
        ObjectSetInteger(0, "EA_Status", OBJPROP_COLOR, textColor);
        ChartRedraw(0);
    }
   
    if( IsRSIFilter() || IsUpcomingNews() || IsMAFilter() || !IsTradingAllowedbyDay() || !IsTradingAllowedPropValues()){
        CloseAllOrders();
        Tradingenabled=false;
        if(TradingEnabledComm!= "Printed")
            Print(TradingEnabledComm);
        TradingEnabledComm="Printed";
        return;
    }
   
    Tradingenabled=true;
    if(TradingEnabledComm!=""){
        Print("Trading is enabled again");
        TradingEnabledComm = "";
    }
    
    MqlDateTime time;
    TimeToStruct(TimeCurrent(),time);
    int Hournow =  time.hour;
   
    if(Hournow < SHInput){CloseAllOrders();  return;}
    if(Hournow >= EHInput && EHInput!=0){CloseAllOrders(); return;}
   
    int BuyTotal=0;
    int SellTotal=0;
   
    for(int i=OrdersTotal()-1; i>=0; i--){
        ord.SelectByIndex(i);
        if(ord.OrderType()== ORDER_TYPE_BUY_STOP && ord.Symbol()==_Symbol && ord.Magic()==InpMagic) BuyTotal++;
        if(ord.OrderType()== ORDER_TYPE_SELL_STOP && ord.Symbol()==_Symbol && ord.Magic()==InpMagic) SellTotal++;
    }
   
    for(int i=OrdersTotal()-1; i>=0; i--){
        ord.SelectByIndex(i);
        if(posinfo.PositionType()== POSITION_TYPE_BUY && ord.Symbol()==_Symbol && ord.Magic()==InpMagic) BuyTotal++;
        if(posinfo.PositionType()== POSITION_TYPE_SELL && ord.Symbol()==_Symbol && ord.Magic()==InpMagic) SellTotal++;
    }
   
    if(BuyTotal <=0){
        double high = findHigh();
        if(high > 0){
            executeBuy(high);
        }
    }
   
    if(SellTotal <=0){
        double low = findLow();
        if(low > 0){
            executeSell(low);
        }
    }
}

bool IsNewBar(){
      static datetime previousTime= 0;
      datetime currentTime = iTime(_Symbol, Timeframe, 0);
      if(previousTime!=currentTime){
         previousTime=currentTime;
         return true;
      }
      return false;
}

void CloseAllPositionsNow()
{
    for(int i = PositionsTotal()-1; i >= 0; i--)
    {
        if(posinfo.SelectByIndex(i) && 
           posinfo.Symbol() == _Symbol && 
           posinfo.Magic() == InpMagic)
        {
            trade.PositionClose(posinfo.Ticket());
        }
    }
}


double findHigh(){
   double highestHigh = 0;
   for(int i =0; i < 200; i++){
      double high = iHigh(_Symbol,Timeframe,i);
      if(i > BarN && iHighest(_Symbol,Timeframe,MODE_HIGH,BarN*2+1, i-BarN) == i){
         if(high > highestHigh){
            return high;
         }
      }
      highestHigh = MathMax(high,highestHigh);
   }
   return -1;
}

double findLow(){
   double LowestLow = DBL_MAX;
   for(int i =0; i < 200; i++){
      double low = iLow(_Symbol,Timeframe,i);
      if(i > BarN && iLowest(_Symbol,Timeframe,MODE_LOW,BarN*2+1, i-BarN) == i){
         if(low < LowestLow){
            return low;
         }
      }
      LowestLow = MathMin(low,LowestLow);
   }
   return -1;
}

double calcLots(double slPoints){

   double lots = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   
   double AccountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double EquityBalance  = AccountInfoDouble(ACCOUNT_EQUITY);
   double FreeMargin     = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   
   double risk = 0;
   
   switch(LotType){
      case 0: lots=FixedLots; return lots;
      case 1: risk = AccountBalance * RiskPercent / 100; break;
      case 2: risk = EquityBalance * RiskPercent / 100;  break;
      case 3: risk = FreeMargin * RiskPercent / 100;     break;
   }
    
   double ticksize = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   double tickvalue = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);
   double lotstep   = SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   
   double moneyPerLotstep = slPoints / ticksize * tickvalue * lotstep;
   lots = MathFloor(risk / moneyPerLotstep) * lotstep;
      
   double minvolume = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double maxvolume = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   double volumelimit= SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_LIMIT);
    
   if(volumelimit !=0) lots = MathMin(lots,volumelimit);
   if(maxvolume !=0) lots = MathMin(lots, SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX));
   if(minvolume !=0) lots = MathMax(lots, SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN));
   lots= NormalizeDouble(lots, 2);
   
   return lots;
}          


void executeBuy(double  entry){
   double ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   
   if(ask > entry - OrderDistPoints * _Point) return;
   
   double tp = entry + Tppoints * _Point;
   double sl = entry - Slpoints * _Point;
   
   double lots = 0.01;
   if(RiskPercent > 0) lots = calcLots(entry-sl);
   
   datetime expiration = iTime(_Symbol,Timeframe,0) + ExpirationBars * PeriodSeconds(Timeframe);
   trade.BuyStop(lots,entry, _Symbol,sl,tp, ORDER_TIME_SPECIFIED, expiration);
}

void executeSell(double  entry){
   double bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   
   if(bid < entry - OrderDistPoints * _Point) return;
   
   double tp = entry - Tppoints * _Point;
   double sl = entry + Slpoints * _Point;
   
   double lots = 0.01;
   if(RiskPercent > 0) lots = calcLots(sl-entry);
   
   datetime expiration = iTime(_Symbol,Timeframe,0) + ExpirationBars * PeriodSeconds(Timeframe);
   trade.SellStop(lots,entry, _Symbol,sl,tp, ORDER_TIME_SPECIFIED, expiration);
}

void CloseAllOrders(){
   for(int i=OrdersTotal()-1;i>=0;i--){
      ord.SelectByIndex(i);
      ulong ticket = ord.Ticket();
      if(ord.Symbol()==_Symbol && ord.Magic()==InpMagic){
         trade.OrderDelete(ticket);
      }
   }
}

void TrailStop(){
   double sl=0;
   double tp=0;
   double ask= SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double bid= SymbolInfoDouble(_Symbol,SYMBOL_BID);
   int stoplevel  =  (int) SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   double indbuffer[];
   
   for (int i=PositionsTotal()-1; i>=0; i--){
      if(posinfo.SelectByIndex(i)){
         ulong ticket = posinfo.Ticket();
         if(posinfo.Magic()==InpMagic && posinfo.Symbol()==_Symbol){
            if(posinfo.PositionType()==POSITION_TYPE_BUY){
               if(bid-posinfo.PriceOpen() > TslTriggerPoints * _Point){
                  tp = posinfo.TakeProfit();
               if(posinfo.StopLoss()<posinfo.PriceOpen()){
                  sl = bid - (TslPoints * _Point);
                  trade.PositionModify(ticket,sl,tp);
                  }
               }
               switch(TrailType){
                  case 0: sl = bid - (TslPoints * _Point);
                          break;
                  case 1: sl = iLow(_Symbol,Timeframe,PrvCandleN);
                          break;
                  case 2: CopyBuffer(handleTrailMA,MAIN_LINE,1,1,indbuffer);
                          ArraySetAsSeries(indbuffer, true);
                          sl = NormalizeDouble(indbuffer[0], _Digits);
                          break;
                  case 3: CopyBuffer(handleIchimoku, TENKANSEN_LINE,1,1,indbuffer);
                          ArraySetAsSeries(indbuffer,true);
                          sl = NormalizeDouble(indbuffer[0],_Digits);
                          break;
               }
               if(sl > posinfo.StopLoss() && sl!=0 && sl > posinfo.PriceOpen() && sl < bid){
                     trade.PositionModify(ticket,sl,tp);
               }
               
            }  else if(posinfo.PositionType()== POSITION_TYPE_SELL){
               if(ask+(TslTriggerPoints * _Point)< posinfo.PriceOpen()){
                     tp = posinfo.TakeProfit();
                     if(posinfo.StopLoss()>posinfo.PriceOpen()){
                        sl = ask + (TslPoints * _Point);
                        trade.PositionModify(ticket,sl,tp);
                     }
                   
                   switch(TrailType){
                     case 0: sl = ask + (TslPoints * _Point);
                             break;
                     case 1: sl = iHigh(_Symbol,Timeframe,PrvCandleN);
                             break;
                     case 2: CopyBuffer(handleTrailMA,MAIN_LINE,1,1,indbuffer);
                             ArraySetAsSeries(indbuffer, true);
                             sl = NormalizeDouble(indbuffer[0], _Digits);
                             break;
                     case 3: CopyBuffer(handleIchimoku, TENKANSEN_LINE,1,1,indbuffer);
                             ArraySetAsSeries(indbuffer,true);
                             sl = NormalizeDouble(indbuffer[0],_Digits);
                             break;
                  }
                   if(sl < posinfo.StopLoss() && sl!=0 && sl < posinfo.PriceOpen() && sl > ask){
                     trade.PositionModify(ticket,sl,tp);
                   }
                   }
               }
            }
         }
      }
   }




bool IsUpcomingNews(){
   if(NewsFilterOn == false) return(false);
   
   if(TrDisabledNews && TimeCurrent()- LastNewsAvoided < StartTradingMin*PeriodSeconds(PERIOD_M1)) return true;
   
   TrDisabledNews = false;
   
   string sep;
   switch(separator){
      case 0: sep = ","; break;
      case 1: sep = ";"; break;
   }

   sep_code = StringGetCharacter(sep,0);
   
   int k = StringSplit(KeyNews,sep_code,Newstoavoid);
   
   MqlCalendarValue values[];
   datetime starttime = TimeCurrent(); //iTime(_Symbol, PERIOD_D1,0);
   datetime endtime   = starttime + PeriodSeconds(PERIOD_M1)*DaysNewsLookUP;
   
   
   CalendarValueHistory(values,starttime,endtime,NULL,NULL);
   
   for(int i = 0; i < ArraySize(values); i++){
      MqlCalendarEvent event;
      CalendarEventById(values[i].event_id, event);
      MqlCalendarCountry country;
      CalendarCountryById(event.country_id, country);
      
      if(StringFind(NewsCurrencies,country.currency) < 0 )continue;
      
      for(int j=0; j<k; j++){
         string currentevent = Newstoavoid[j];
         string currentnews = event.name;
         if(StringFind(currentnews, currentevent) < 0) continue;
         
         Comment("Next News: ",country.currency, ": ", event.name, " -> ", values[i].time);
         if(values[i].time - TimeCurrent() < StopBeforMin*PeriodSeconds(PERIOD_M1)){
            LastNewsAvoided = values[i].time;
            TrDisabledNews  = true;
            if(TradingEnabledComm == "" || TradingEnabledComm!= "Printed"){
               TradingEnabledComm = "Trading is disabled due to upcoming news: " + event.name;
            }
            return true;
         }
         return false;
      }
   }
   return false;
}

bool IsRSIFilter(){
   if(RSIFilterOn==false) return(false);
   
   double RSI[];
   
   CopyBuffer(handleRSI,MAIN_LINE,0,1,RSI);
   ArraySetAsSeries(RSI,true);
   
   double RSInow = RSI[0];
   
   Comment("RSI = ",RSInow);
   
   if(RSInow > RSIUpperlvl || RSInow < RSIlowerlvl){
      if(TradingEnabledComm== "" || TradingEnabledComm!="Printed"){
         TradingEnabledComm = "Trading is disabled due to RSI filter. RSI = " + DoubleToString(RSInow);
      }
      return(true);
   }
   return false;
}

bool IsMAFilter(){
   if(MAFilterOn==false) return(false);
   
   double MovAvg[];
   
   CopyBuffer(handleMovAvg,MAIN_LINE,0,1,MovAvg);
   ArraySetAsSeries(MovAvg,true);
   
   double MAnow = MovAvg[0];
   double ask   = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   
   if( ask > MAnow * (1 + PctPricefromMA/100) ||
       ask < MAnow * (1 - PctPricefromMA/100)){
         if(TradingEnabledComm=="" || TradingEnabledComm!="Printed"){
            TradingEnabledComm = "Trading is disabled due to Mov Avg Filter. Prices as % of MA = " + DoubleToString(ask*100/MAnow,2) + "%";
         }
      return true;
   }
   return false;
}

bool IsTradingAllowedbyDay(){
   
   MqlDateTime today;
   TimeCurrent(today);
   string Daytoday = EnumToString((ENUM_DAY_OF_WEEK)today.day_of_week);
   
   
   if(AllowedMonday==true && Daytoday== "MONDAY") return true;
   if(AllowedTuesday==true && Daytoday== "TUESDAY") return true;
   if(AllowedWednesday==true && Daytoday== "WEDNESDAY") return true;
   if(AllowedThursday==true && Daytoday== "THURSDAY") return true;
   if(AllowedFriday==true && Daytoday== "FRIDAY") return true;
   if(AllowedSaturday==true && Daytoday== "SATURDAY") return true;
   if(AllowedSunday==true && Daytoday== "SUNDAY") return true;
   
   if(TradingEnabledComm=="" || TradingEnabledComm!= "Printed"){
      TradingEnabledComm = "Trading is not allowed on" + Daytoday;
   }
   return false;
}

void UpdateInitialBalances(){
   
   static   MqlDateTime prevcheck;
   
   MqlDateTime now;
   TimeCurrent(now);
   
   //Updating beg of day Balance
   
   if(now.day!=prevcheck.day){
      BegofDayBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      EqHigh_1D = BegofDayBalance;
      DD_1D_Pct = 0;
      Prf_1D_Pct = 0;
      prevcheck = now;
      
   }
   
   //Updating end of 7 day Balance
   static datetime _7dayperiod = StartofChallenge;
   
   if(TimeCurrent()>_7dayperiod){
      BegofWeekBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      EqHigh_7D = BegofWeekBalance;
      DD_7D_Pct = 0;
      Prf_7D_Pct = 0;
      _7dayperiod += PeriodSeconds(PERIOD_D1) * 7;
      
   }
   
   //Updating end of 30 day Balance
   static datetime _30dayperiod = StartofChallenge;
   
   if(TimeCurrent()>_30dayperiod){
      BegofMthBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      EqHigh_7D = BegofMthBalance;
      DD_30D_Pct = 0;
      Prf_30D_Pct = 0;
      _30dayperiod += PeriodSeconds(PERIOD_D1) * 30;
      
   }
}

void UpdatePropfirmValues(){
   
   double Equity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   if(BegofDayBalance!=0){
      Prf_1D_Pct = (Equity - BegofDayBalance) * 100 / BegofDayBalance;
      if(Equity>EqHigh_1D) EqHigh_1D = Equity;
      DD_1D_Pct = (Equity - EqHigh_1D) * 100 / EqHigh_1D;
      /*double curr1D_DD = (Equity - EqHigh_1D) * 100 / EqHigh_1D;
      if(curr1D_DD < DD_1D_Pct){
         DD_1D_Pct = curr1D_DD;
      }*/
   }
   
   
   if(BegofWeekBalance!=0){
      Prf_7D_Pct = (Equity - BegofWeekBalance) * 100 / BegofWeekBalance;
      if(Equity>EqHigh_7D) EqHigh_7D = Equity;
      double curr7D_DD = (Equity - EqHigh_7D) * 100 / EqHigh_7D;
      if(curr7D_DD < DD_7D_Pct){
         DD_7D_Pct = curr7D_DD;
      }
   }
   
   if(BegofMthBalance!=0){
      Prf_30D_Pct = (Equity - BegofMthBalance) * 100 / BegofMthBalance;
      if(Equity>EqHigh_30D) EqHigh_30D = Equity;
      double curr30D_DD = (Equity - EqHigh_30D) * 100 / EqHigh_30D;
      if(curr30D_DD < DD_30D_Pct){
         DD_30D_Pct = curr30D_DD;
      }
   }
   
   if(InitialBalance!=0){
      Prf_AT_Pct = (Equity- InitialBalance) * 100 / InitialBalance;
      if(Equity>EqHigh_AT) EqHigh_AT = Equity;
      double currAT_DD = (Equity - EqHigh_AT) * 100 / EqHigh_AT;
      if (currAT_DD < DD_AT_Pct){
         DD_AT_Pct = currAT_DD;
      }
   }
}

bool IsTradingAllowedPropValues(){
   
   if(DD_1D_Pct < -MaxDDday){
      if(TradingEnabledComm!="Printed") TradingEnabledComm = "Trading Disabled: Max Drawdown for Day Exceeded";
      return false;
   }
   
   if(DD_7D_Pct < -MaxDDweek){   
      if(TradingEnabledComm!="Printed") TradingEnabledComm = "Trading Disabled: Max Drawdown for Week Exceeded";
      return false;
   }
   
   if(DD_30D_Pct < -MaxDDMonth){
      if(TradingEnabledComm!="Printed") TradingEnabledComm = "Trading Disabled: Max Drawdown for Month Exceeded";
      return false;
   }
   
   if(DD_AT_Pct < -MaxDDTotal){
      if(TradingEnabledComm!="Printed") TradingEnabledComm = "Trading Disabled: Max Drawdown for All Time Exceeded";
      return false;
   }
   
   if(Prf_AT_Pct > ProfitTraget){
      if(TradingEnabledComm!="Printed") TradingEnabledComm = "We Got this Mina!!!!! Target Achieved";
      return false;
   }
return true;
}

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam){

   panel.ChartEvent(id,lparam,dparam,sparam);
}
