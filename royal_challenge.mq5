
#property copyright "Copyright 2025, Anony$peedy"
#property link      "https://www.mql5.com"
#property version   "1.00"

#include <Trade\Trade.mqh>
CTrade            trade;
CPositionInfo     posinfo;
COrderInfo        ordinfo;
CHistoryOrderInfo hisinfo;
CDealInfo         dealinfo;

enum enumLotType{Fixed_Lots=0, Pct_of_Balance=1, Pct_of_Equity=2, Pct_of_Free_Margin=3};

input group "GENERAL SETTINGS"; // General Settings
input int InpMagic = 123456; //Magic Number
input int Slippage = 1;

input group "TIME SETTINGS";
input int StartHour = 16; //Start trading Hour
input int EndHour   = 17; //End trading Hour
input int Secs      = 60; // Order Modifications (should be the same as time frame)

input group "MONEY MANAGEMENT"; // Money Management
input enumLotType LotType = 0; //type of lotsize calculation
input double      FixedLot = 0.01; // Fixed Lots 
input double      RiskPercent = 1; // Risk MM%

input group "TRADING SETTING IN POINTS"; //TRADE SETTINGS
input double   Delta = 0.5; // order distance
input double   MaxDistance = 7; // Theta (max order distance)
input double   Stop  = 10; // Stop Loss Size
input double   MaxTrailing = 4; // COS (Start of Trailing stop)   
input int      MaxSpread   = 5555; // Max Spread Limit

double DeltaX = Delta;
double MinOrderDistance = 0.5;
double MaxTrailingLimit = 7.5;
double OrderModificationFactor = 3;
int    TickCounter = 0;
double PriceToPipRatio = 0;
double BaseTrailingStop = 0;
double TrailingStopBuffer = 0;
double TrailingStopIncrement = 0;
double TrailingStopThreshold = 0;
long   AccountLeverageValue = 0;
double LotStepSize = 0;
double MaxLotSize = 0;
double MinLotSize = 0;
double MarginPerMinLot = 0;
double MinStopDistance = 0;
int BrokerStopLevel = 0;
double MinFreezeDistance = 0;
int BrokerFreezeLevel = 0;
double CurrentSpread = 0;
double AverageSpread = 0;
int EAModeFlage = 0;
int SpreadArraySize = 0;
int DefaultSpeardPeriod = 30;
double MaxAllowedSpread = 0;
double CalculatedLotSize = 0;
double CommissionPerPip = 0;
int  SpreadMultiplier = 1;
double AdjustedOrderDistance = 0;
double MinOrderModification = 0;
double TrailingStopActive = 0;   
double TrailingStopMax = 0;
double MaxOrderPlacementDistance = 0;
double OrderPlacementStep = 0;
double CalculatedStopLoss = 0;
bool AllowBuyOrders = false;   
bool AllowSellOrders = false;
bool SpreadAcceptable = false;
int  LastOrderTimeDiff = 0;
int  LastOrderTime = 0;
int  MinOrderInterval = 10;
double CurrentBuySL = 0;
string OrderCommentText = "EA Order";
int    LastBuyOrderTime = 0;
bool   TradeAllowed = false;
double CurrentSellSL = 0;
int LastSellOrderTime = 0;
int OrderCheckFrequency = 2;
int SpreadCalculationMethod = 1;
bool EnableTrading = true;
double SpreadHistoryArray[];

int OnInit(){
   trade.SetExpertMagicNumber(InpMagic);
   ChartSetInteger(0,CHART_SHOW_GRID,false);
   
   if((MinOrderDistance > Delta)) {
      DeltaX = (MinOrderDistance + 0.1);
   }
   if((MaxTrailing > MaxTrailingLimit)) {
      MaxTrailingLimit = (MaxTrailing + 0.1);
   }
   if((OrderModificationFactor < 1)) {
      OrderModificationFactor = 1;
   }
   
   TickCounter = 0;
   PriceToPipRatio = 0;
   BaseTrailingStop = 0;
   TrailingStopIncrement = 0;
   TrailingStopThreshold = 0;
   AccountLeverageValue = AccountInfoInteger(ACCOUNT_LEVERAGE);
   
   LotStepSize = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   MaxLotSize  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   MinLotSize  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   MarginPerMinLot = SymbolInfoDouble(_Symbol, SYMBOL_MARGIN_INITIAL);
   
   MinStopDistance = 0;
   BrokerStopLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(BrokerStopLevel > 0) MinStopDistance = (BrokerStopLevel + 1) * _Point;
   
   MinFreezeDistance = 0;
   BrokerFreezeLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   if(BrokerFreezeLevel > 0) MinFreezeDistance = (BrokerFreezeLevel + 1) * _Point;
   
   if(BrokerStopLevel > 0 || BrokerFreezeLevel > 0) {
      Comment("WARNING! Broker is not suitable, the stoplevel is greater than zero.");
   }
   
   double Ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double Bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   CurrentSpread = NormalizeDouble(Ask - Bid, _Digits);
   AverageSpread = CurrentSpread;
   
   SpreadArraySize = (EAModeFlage == 0) ? DefaultSpeardPeriod : 3;
   ArrayResize(SpreadHistoryArray, SpreadArraySize, 0);
   
   for(int i = 0; i < SpreadArraySize; i++){
      SpreadHistoryArray[i] = CurrentSpread;
   }
   
   MaxAllowedSpread = NormalizeDouble((MaxSpread * _Point), _Digits);
   TesterHideIndicators(true);
      
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason){  
}

void OnTick(){
   int CurrentTime = (int)TimeCurrent();
   int PendingBuyCount = 0;
   int PendingSellCount = 0;
   int OpenBuyCount = 0;
   int OpenSellCount = 0;
   int TotalBuyCount = 0;
   int TotalSellCount = 0;
   double BuyOrdersPriceSum = 0;
   double BuyOrdersLotSum = 0;
   double SellOrdersPriceSum = 0;
   double SellOrderLotSum = 0;
   double AverageBuyPrice = 0;
   double AverageSellPrice = 0;
   double LowestBuyPrice = 99999;
   double HighestSellPrice = 0;
   
   TickCounter++;
   
   if(PriceToPipRatio == 0){
      HistorySelect(0, TimeCurrent());
      for(int i = HistoryDealsTotal()-1; i >= 0; i--) {
         ulong ticket = HistoryDealGetTicket(i);
         if(ticket == 0) continue;
         
         if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol) continue;
         if(HistoryDealGetDouble(ticket, DEAL_PROFIT) == 0) continue;
         if(HistoryDealGetInteger(ticket, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
         
         ulong posID = HistoryDealGetInteger(ticket, DEAL_POSITION_ID);
         if(posID == 0) continue;  
         
         if(HistoryDealSelect(posID)){
            double entryPrice = HistoryDealGetDouble(posID, DEAL_PRICE);
            double exitPrice = HistoryDealGetDouble(ticket, DEAL_PRICE);
            double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
            double commission = HistoryDealGetDouble(ticket, DEAL_COMMISSION);
            
            if(exitPrice != entryPrice){
               PriceToPipRatio = fabs(profit / (exitPrice - entryPrice));
               CommissionPerPip = -commission / PriceToPipRatio;
               break;
            }
         }
      }
   }

   double Ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double Bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);
   
   double newSpread = NormalizeDouble(Ask - Bid, _Digits-1);
   ArrayCopy(SpreadHistoryArray, SpreadHistoryArray, 0, 1, SpreadArraySize-1);
   SpreadHistoryArray[SpreadArraySize-1] = newSpread;
   
   double sum = 0;
   for(int i = 0; i < SpreadArraySize; i++){
      sum += SpreadHistoryArray[i];
   }
   CurrentSpread = sum / SpreadArraySize;
   
   AverageSpread = MathMax(SpreadMultiplier * _Point, CurrentSpread + CommissionPerPip);
   AdjustedOrderDistance = MathMax(AverageSpread * Delta, MinStopDistance);
   MinOrderModification = MathMax(AverageSpread * MinOrderDistance, MinFreezeDistance);
   TrailingStopActive = AverageSpread * MaxTrailing;
   TrailingStopMax = AverageSpread * MaxTrailingLimit;
   MaxOrderPlacementDistance = AverageSpread * MaxDistance;
   OrderPlacementStep = MinOrderModification / OrderModificationFactor;
   CalculatedStopLoss = MathMax(AverageSpread * Stop, MinStopDistance);

   for(int i = PositionsTotal()-1; i >= 0; i--) {
      if(posinfo.SelectByIndex(i) && posinfo.Symbol() == _Symbol && posinfo.Magic() == InpMagic){
         double price = posinfo.PriceOpen();
         double lots = posinfo.Volume();
         double sl = posinfo.StopLoss();
         
         if(posinfo.PositionType() == POSITION_TYPE_BUY) {
            OpenBuyCount++;
            if(sl == 0 || (sl > 0 && price > sl)) {
               TotalBuyCount++;
               CurrentBuySL = sl;
            }
            BuyOrdersPriceSum += price * lots;
            BuyOrdersLotSum += lots;
            if(price < LowestBuyPrice) LowestBuyPrice = price;
         }
         else if(posinfo.PositionType() == POSITION_TYPE_SELL){
            OpenSellCount++;
            if(sl == 0 || (sl > 0 && sl > price)) {
               TotalSellCount++;
               CurrentSellSL = sl;
            }
            SellOrdersPriceSum += price * lots;
            SellOrderLotSum += lots;
            if(price > HighestSellPrice) HighestSellPrice = price;
         }
      }
   }
      
   for(int i = OrdersTotal()-1; i >= 0; i--){
      if(ordinfo.SelectByIndex(i) && ordinfo.Symbol() == _Symbol && ordinfo.Magic() == InpMagic){
         if(ordinfo.OrderType() == ORDER_TYPE_BUY_STOP){
            PendingBuyCount++;
            TotalBuyCount++;
         }
         else if (ordinfo.OrderType() == ORDER_TYPE_SELL_STOP){
            PendingSellCount++;
            TotalSellCount++;
         }
      }
   }
      
   if(BuyOrdersLotSum > 0){
      AverageBuyPrice = NormalizeDouble((BuyOrdersPriceSum / BuyOrdersLotSum), _Digits);
   }
   if(SellOrderLotSum > 0){
      AverageSellPrice = NormalizeDouble((SellOrdersPriceSum / SellOrderLotSum), _Digits);
   }

   MqlDateTime BrokerTime;
   TimeCurrent(BrokerTime);      
   
   for(int i = OrdersTotal()-1; i >= 0; i--){
      if(!ordinfo.SelectByIndex(i)) continue;
      if(ordinfo.Symbol() != _Symbol || ordinfo.Magic() != InpMagic) continue;
      
      ulong ticket = ordinfo.Ticket();
      ENUM_ORDER_TYPE type = ordinfo.OrderType();
      double openPrice = ordinfo.PriceOpen();
      double sl = ordinfo.StopLoss();
      double tp = ordinfo.TakeProfit();
      double lots = ordinfo.VolumeCurrent();
      
      if(type == ORDER_TYPE_BUY_STOP){
         bool allowTrade = (BrokerTime.hour >= StartHour && BrokerTime.hour <= EndHour);
         if(AverageSpread > MaxAllowedSpread || !allowTrade){
            trade.OrderDelete(ticket);
            continue;
         }
         int timeDiff = (int)(CurrentTime - LastBuyOrderTime);
         
         bool needsModification = (timeDiff > Secs) ||
                                 (TickCounter % OrderCheckFrequency == 0 &&
                                 ((OpenBuyCount < 1 && (openPrice - Ask) < MinOrderModification) || 
                                 (openPrice - Ask) < OrderPlacementStep ||
                                 (openPrice - Ask) > MaxOrderPlacementDistance));
                                 
         if(needsModification){
            double distance = AdjustedOrderDistance;
            if(OpenBuyCount > 0) distance /= OrderModificationFactor;
            distance = MathMax(distance, MinStopDistance);
            
            double modifiedPrice = NormalizeDouble(Ask + distance, _Digits);
            double modifiedsl = (OpenBuyCount > 0) ? CurrentBuySL : NormalizeDouble(modifiedPrice - CalculatedStopLoss, _Digits);
            
            if((OpenBuyCount == 0 || modifiedPrice > AverageBuyPrice) &&
               modifiedPrice != openPrice &&
               (openPrice - Ask) > MinFreezeDistance){
               trade.OrderModify(ticket, modifiedPrice, modifiedsl, tp, 0, 0);
               LastBuyOrderTime = CurrentTime;
            }
         }
      }
      else if(type == ORDER_TYPE_SELL_STOP){
         bool allowTrade = (BrokerTime.hour >= StartHour && BrokerTime.hour <= EndHour);
         if(AverageSpread > MaxAllowedSpread || !allowTrade){
               trade.OrderDelete(ticket);
               continue;
         }
         
         int timeDiff = (int)(CurrentTime - LastSellOrderTime);
         bool needsModification = (timeDiff > Secs) ||
                                 (TickCounter % OrderCheckFrequency == 0 &&
                                 ((OpenSellCount < 1 && (Bid - openPrice) < MinOrderModification) ||
                                 (Bid - openPrice) < OrderPlacementStep ||
                                 (Bid - openPrice) > MaxOrderPlacementDistance));
                                 
         if(needsModification) {
            double distance = AdjustedOrderDistance;
            if(OpenSellCount > 0) distance /= OrderModificationFactor;
            distance = MathMax(distance, MinStopDistance);
            
            double modifiedPrice = NormalizeDouble(Bid - distance, _Digits);
            double modifiedsl = (OpenSellCount > 0) ? CurrentSellSL : NormalizeDouble(modifiedPrice + CalculatedStopLoss, _Digits);
            
            if((OpenSellCount == 0 || modifiedPrice < AverageSellPrice) &&
               modifiedPrice != openPrice &&
               (Bid - openPrice) > MinFreezeDistance){
               trade.OrderModify(ticket, modifiedPrice, modifiedsl, tp, 0, 0);
               LastSellOrderTime = CurrentTime;
            }
         }
      }
   }
         
   for(int i = PositionsTotal()-1; i >= 0; i--){
      if(!posinfo.SelectByIndex(i)) continue;
      if(posinfo.Symbol() != _Symbol || posinfo.Magic() != InpMagic) continue;
      
      ulong ticket = posinfo.Ticket();
      ENUM_POSITION_TYPE type = posinfo.PositionType();
      double openPrice = posinfo.PriceOpen();
      double sl = posinfo.StopLoss();
      double tp = posinfo.TakeProfit();
      
      if(type == POSITION_TYPE_BUY){
         double priceMove = MathMax(Bid - openPrice + CommissionPerPip, 0);
         double trailDist = CalculateTrailingStop(priceMove, MinStopDistance, TrailingStopActive, BaseTrailingStop, TrailingStopMax);
         
         double modifiedsl = NormalizeDouble(Bid - trailDist, _Digits);
         double triggerLevel = openPrice + CommissionPerPip + TrailingStopIncrement;
         
         if((Bid - triggerLevel) > trailDist &&
            (sl == 0 || (Bid - sl) > trailDist) &&
            modifiedsl != sl) {
               trade.PositionModify(ticket, modifiedsl, tp);
            }
         }
         else if(type == POSITION_TYPE_SELL){
            double priceMove = MathMax(openPrice - Ask - CommissionPerPip, 0);
            double trailDist = CalculateTrailingStop(priceMove, MinStopDistance, TrailingStopActive, BaseTrailingStop, TrailingStopMax);
            
            double modifiedsl = NormalizeDouble(Ask + trailDist, _Digits);
            double triggerLevel = openPrice - CommissionPerPip - TrailingStopIncrement;
            
            if((triggerLevel - Ask) > trailDist &&
               (sl == 0 || (sl - Ask) > trailDist) &&
               modifiedsl != sl){
               trade.PositionModify(ticket, modifiedsl, tp);
            }
         }
   }
   
   if(((OrderModificationFactor > 1 && TotalBuyCount < 1) || OpenBuyCount < 1) && PendingBuyCount < 1){
      bool spreadOK = (AverageSpread <= MaxAllowedSpread);
      bool timeOK = (BrokerTime.hour >= StartHour && BrokerTime.hour <= EndHour);
      
      if(spreadOK && timeOK && (CurrentTime - LastOrderTime) > MinOrderInterval && EAModeFlage == 0){
         if(LotType == 0) {
            CalculatedLotSize = MathCeil(FixedLot / LotStepSize) * LotStepSize;
            CalculatedLotSize = MathMax(CalculatedLotSize, MinLotSize);
         }
         else if(LotType > 0){
            CalculatedLotSize = calcLots(CalculatedStopLoss);
         }
         
         double marginRequired = 0.0;
         if(OrderCalcMargin(ORDER_TYPE_BUY_STOP, _Symbol, CalculatedLotSize, Ask, marginRequired) &&
            AccountInfoDouble(ACCOUNT_MARGIN_FREE) > marginRequired){
            
            double orderDist = MathMax(MathMax(AdjustedOrderDistance, MinFreezeDistance), MinStopDistance);
            double orderPrice = NormalizeDouble(Ask + orderDist, _Digits);
            double orderSL = (OpenBuyCount > 0) ? CurrentBuySL : NormalizeDouble(orderPrice - CalculatedStopLoss, _Digits);
            
            if(trade.BuyStop(CalculatedLotSize, orderPrice, _Symbol, orderSL, 0, 0, 0, OrderCommentText)){
               LastBuyOrderTime = (int)TimeCurrent();
               LastOrderTime = (int)TimeCurrent();
            }
         }
      }
   } 
   
   if(((OrderModificationFactor > 1 && TotalSellCount < 1) || OpenSellCount < 1) && PendingSellCount < 1){  
      bool spreadOK = (AverageSpread <= MaxAllowedSpread);
      bool timeOK = (BrokerTime.hour >= StartHour && BrokerTime.hour <= EndHour);
      
      if(spreadOK && timeOK && (CurrentTime - LastOrderTime) > MinOrderInterval && EAModeFlage == 0){
         if(LotType == 0) {
            CalculatedLotSize = MathCeil(FixedLot / LotStepSize) * LotStepSize;
            CalculatedLotSize = MathMax(CalculatedLotSize, MinLotSize);
         }
         else if(LotType > 0) {
            CalculatedLotSize = calcLots(CalculatedStopLoss);
         }
         
         double marginRequired = 0.0;
         if(OrderCalcMargin(ORDER_TYPE_SELL_STOP, _Symbol, CalculatedLotSize, Bid, marginRequired) &&
            AccountInfoDouble(ACCOUNT_MARGIN_FREE) > marginRequired){
            
            double orderDist = MathMax(MathMax(AdjustedOrderDistance, MinFreezeDistance), MinStopDistance);
            double orderPrice = NormalizeDouble(Bid - orderDist, _Digits);
            double orderSL = (OpenSellCount > 0) ? CurrentSellSL : NormalizeDouble(orderPrice + CalculatedStopLoss, _Digits);
            
            if(trade.SellStop(CalculatedLotSize, orderPrice, _Symbol, orderSL, 0, 0, 0, OrderCommentText)){
               LastSellOrderTime = (int)TimeCurrent();
               LastOrderTime = (int)TimeCurrent();
            }
         }
      }
   }    
}

double CalculateTrailingStop(double priceMove, double minDist, double activeDist, double baseDist, double maxDist){
   if(maxDist == 0) return MathMax(activeDist, minDist);
   
   double ratio = priceMove / maxDist;
   double dynamicDist = (activeDist - baseDist) * ratio + baseDist;
   return MathMax(MathMin(dynamicDist, activeDist), minDist);
}

double calcLots(double slPoints){
   double lots = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   
   if(LotType == 0){
      return FixedLot;
   }
   
   double AccountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double EquityBalance = AccountInfoDouble(ACCOUNT_EQUITY);
   double FreeMargin     = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   
   double risk = 0;
   switch(LotType){
      case 1: risk = AccountBalance * RiskPercent / 100; break;
      case 2: risk = EquityBalance * RiskPercent / 100; break;
      case 3: risk = FreeMargin * RiskPercent / 100; break;
   }
   
   double ticksize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickvalue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double lotstep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   if(ticksize == 0 || tickvalue == 0 || lotstep == 0) return MinLotSize;
   
   double moneyPerLotstep = slPoints / ticksize * tickvalue * lotstep;
   if(moneyPerLotstep == 0) return MinLotSize;
   
   lots = MathFloor(risk / moneyPerLotstep) * lotstep;
   
   double minvolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxvolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   
   if(maxvolume != 0) lots = MathMin(lots, maxvolume);
   if(minvolume != 0) lots = MathMax(lots, minvolume);
   
   lots = NormalizeDouble(lots, 2);
   return lots;
}