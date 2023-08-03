//+------------------------------------------------------------------+
//|                                                      GridBot.mq5 |
//|                                                      AriZone2023 |
//|                     https://github.com/AriZoneVibes/MQL5-GridBot |
//+------------------------------------------------------------------+
#property copyright "AriZone 2023 owo"
#property link "https://github.com/AriZoneVibes/MQL5-GridBot"
#property version "1.0"

#property script_show_inputs

#include <Trade\Trade.mqh>
#include <Trade\AccountInfo.mqh>
#include <Trade\SymbolInfo.mqh>
CTrade trade;
CAccountInfo accountInfo;
CSymbolInfo symbolInfo;

enum selectGridType
{
  arithmetic, // Arithmetic: Each Grid has an equal price difference
  geometric   // Geometric: Each Grid has an equal price diffence ratio
};

enum selectGridDirection
{
  neutralDirection, // Neutral
  longDirection,    // TODO: Long
  shortDirection,   // TODO: Short
};

// * Make separate functions for each action
// If they start to use optimization, update input to sinput
// https://www.mql5.com/en/docs/basis/variables/inputvariables#sinput

//--- Input Parameters
input int expertAdvisorID = 31254; // Expert Advisor ID "Magic Number"
// Set to make randomly in final of Initial Release

input string currentSymbol = "USDJPY"; // Symbol

input selectGridDirection gridDirection = neutralDirection; // Direction

input group "Price Range";
input double lowerPrice = 120; // Lower Price
input double upperPrice = 150; // Upper Price

input group "Grid";
input int gridSize = 20;                    // Number of Grids
input selectGridType gridType = arithmetic; // Grid Type

input group "Investment";
input double lotSize; // Amount of Lots to buy per grid

input group "Advanced";                   // TODO
input bool gridTriggerActivation = false; // Grid Trigger
input double gridTriggerBottomPrice;      // Bottom Price
input double gridTriggerUpperPrice;       // Upper Price
input bool stopTriggerActivation = false; // Stop Trigger
input double stopTriggerBottomPrice;      // Bottom Price
input double stopTriggerUpperPrice;       // Upper Price
input bool cancelOrdersOnStop = false;    // Cancel all orders on stop
input bool closePositionsOnStop = false;  // Close all positions on stop

double currentMargin = 0;

enum orderDirection
{
  orderLong,
  orderShort,
  orderVoid
};

struct gridOrders
{
  double price;
  ulong ticket;
  orderDirection direction;
};
gridOrders gridPrice[]; // Array containing all the orders

bool dataValidation()
{
  if (!SymbolInfoInteger(currentSymbol, SYMBOL_EXIST))
  {
    Print("Symbol not found");
    return false;
  }
  if (upperPrice <= lowerPrice)
  {
    Print("Upper Limit cannot be lower or equal to the Lower Limit");
    return false;
  }
  if (gridSize <= 0)
  {
    Print("Number of grids cannot be equal or lower to zero");
    return false;
  }
  if (lotSize <= 0)
  {
    Print("Investment cannot be lower or equal to zero");
    return false;
  }
  if (gridTriggerUpperPrice <= gridTriggerBottomPrice && gridTriggerActivation == true)
  {
    Print("Grid Trigger Activation Upper Price cannot be lower or equal to the Lower Price");
    return false;
  }
  if (stopTriggerUpperPrice <= stopTriggerBottomPrice && stopTriggerActivation == true)
  {
    Print("Grid Stop Activation Upper Price cannot be lower or equal to the Lower Price");
    return false;
  }
  if (!accountInfo.TradeExpert())
  {
    Print("Account doesn't allow automated trades");
    return false;
  }
  if (accountInfo.LimitOrders() < gridSize)
  {
    Print("Number of grids allowed by Account exceded. Please lower the amount of grids");
    return false;
  }

  return true;
}

void priceSizeArithmetic()
{
  double price = symbolInfo.NormalizePrice(lowerPrice);
  double stepPrice = symbolInfo.NormalizePrice((upperPrice - lowerPrice) / gridSize);

  for (int i = 0; price <= upperPrice; i++)
  {
    gridPrice[i].price = price;
    price += stepPrice;
    Print("Price for Grid #", i, " = ", price);
  }
}

void priceSizeGeometric()
{
  double price = symbolInfo.NormalizePrice(lowerPrice);
  double stepPrice = pow((upperPrice / lowerPrice), (1 / gridSize));

  for (int i = 0; price <= upperPrice; i++)
  {
    gridPrice[i].price = price;
    price *= symbolInfo.NormalizePrice(pow(stepPrice, i));
    Print("Price for Grid #", i, " = ", price);
  }
}

void fillPriceArray()
{
  ArrayResize(gridPrice, gridSize + 1);
  if (gridType == 0)
    priceSizeArithmetic();
  else
    priceSizeGeometric();
}

void initialOrders(double currentPrice)
{
  int i = 0;

  while (gridPrice[i].price <= currentPrice) // Place Buy Orders
  {
    gridPrice[i].direction = orderLong;
    placeOrder(i);
    i++;
  }

  gridPrice[i].direction = orderVoid; // Skip the middle order
  gridPrice[i].ticket = 0;
  i++;

  while (i < ArraySize(gridPrice)) // Place Sell Orders
  {
    gridPrice[i].direction = orderShort;
    placeOrder(i);
    i++;
  }
}

void placeOrder(int orderIndex)
{
  bool reply = false;

  switch (gridPrice[orderIndex].direction)
  {
  case orderLong:
    reply = trade.BuyLimit(lotSize, gridPrice[orderIndex].price, NULL, 0, gridPrice[orderIndex + 1].price);
    break;

  case orderShort:
    reply = trade.SellLimit(lotSize, gridPrice[orderIndex].price, NULL, 0, gridPrice[orderIndex - 1].price);
    break;

  case orderVoid:
    break;
  }

  orderReply(reply);
  gridPrice[orderIndex].ticket = trade.ResultOrder();
  Print("Grid: ", gridPrice[orderIndex].price, " ticket: ", gridPrice[orderIndex].ticket);
}

void orderReply(bool reply)
{
  if (!reply)
  {
    Print("Order Limit failed.");
    Print("Return code=", trade.ResultRetcode(), ". Code description: ", trade.ResultRetcodeDescription());
    ExpertRemove();
  }
  else
  {
    Print("Order Limit executed successfully.");
    Print("Return code=", trade.ResultRetcode(), ". Code description: ", trade.ResultRetcodeDescription());
  }
}

void updateOrders(ulong ticket)
{
  int orderIndex = 0;

  orderIndex = indexFromTicket(ticket);

  if (orderIndex == -1)
  {
    return;
  }

  switch (gridPrice[orderIndex].direction)
  {
  case orderLong:
    gridPrice[orderIndex + 1].direction = orderShort;
    placeOrder(orderIndex + 1);
    break;

  case orderShort:
    gridPrice[orderIndex - 1].direction = orderLong;
    placeOrder(orderIndex - 1);
    break;

  case orderVoid:
    break;
  }
  gridPrice[orderIndex].direction = orderVoid;
  gridPrice[orderIndex].ticket = 0;
}

int indexFromTicket(ulong ticket)
{
  for (int i = 0; i < ArraySize(gridPrice); i++)
  {
    if (ticket == gridPrice[i].ticket)
      return i;
  }
  return -1;
}

void closeAllPositions()
{
  trade.PositionClose(currentSymbol);
}

void closeAllOrders()
{
  for (int i = 0; i < ArraySize(gridPrice); i++)
  {
    if (gridPrice[i].ticket != 0)
    {
      trade.OrderDelete(gridPrice[i].ticket);
    }
  }
}

int OnInit()
{
  //---
  symbolInfo.Name(currentSymbol);

  // Check all Inputs are valid
  if (!dataValidation())
  {
    Print("Init Failed");
    return (INIT_FAILED); // F
  }

  if (!symbolInfo.IsSynchronized())
  {
    Print("Symbol not found or out of sync");
    return (INIT_FAILED);
  }

  // Global trading settings
  trade.SetExpertMagicNumber(expertAdvisorID);
  trade.SetTypeFilling(ORDER_FILLING_RETURN);
  trade.LogLevel(2);
  trade.SetAsyncMode(false);

  fillPriceArray(); // Set Prices where orders will happen

  MqlTick currentPrice;

  Print("Current Price: ", SymbolInfoTick(currentSymbol, currentPrice));

  Print("Current Price: ", currentPrice.last);
  initialOrders(currentPrice.ask); // Place Initial Orders. Decide the direction based on Last Price

  return (INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
  if (closePositionsOnStop == true)
  {
    closeAllPositions(); // TODO
  }
  if (cancelOrdersOnStop == true)
  {
    closeAllOrders(); // TODO
  }
}

void OnTick()
{
  //---
}

void OnTradeTransaction(
    const MqlTradeTransaction &trans,
    const MqlTradeRequest &request,
    const MqlTradeResult &result)
{
  if (trans.order_state == ORDER_STATE_FILLED)
  {
    updateOrders(trans.order);
  }
  // https://www.binance.com/en/support/faq/what-is-spot-grid-trading-and-how-does-it-work-d5f441e8ab544a5b98241e00efb3a4ab
}