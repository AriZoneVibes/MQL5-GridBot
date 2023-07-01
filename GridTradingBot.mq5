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
CTrade trade;

enum selectGridType
{
  arithmetic, // Arithmetic Each Grid has an equal price difference
  geometric   // Geometric Each Grid has an equal price diffence ratio
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

input string currentSymbol = "USDJPY"; // Symbol

input selectGridDirection gridDirection = neutralDirection; // Direction

input group "Price Range";
input double lowerPrice = 120; // Lower Price
input double upperPrice = 150; // Upper Price

input group "Grid";
input int gridSize = 20;                    // Number of Grids
input selectGridType gridType = arithmetic; // Grid Type

input group "Investment";
input double initialMagin = 100; // Initial Margin
input int leverage = 1;          // Leverage

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

double orderSize = (initialMagin * leverage) / gridSize; // * Size of each Buy/Sell order. Need to confirm need of leverage

bool dataValidation()
{
  bool symbolValidation = SymbolInfoInteger(currentSymbol, SYMBOL_EXIST);
  if (symbolValidation == false)
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
  if (initialMagin <= 0 || leverage <= 0)
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
  return true;
}

void priceSizeArithmetic()
{
  double price = lowerPrice;
  double stepPrice = (upperPrice - lowerPrice) / gridSize;

  for (int i = 0; price <= upperPrice; i++)
  {
    gridPrice[i].price = price;
    price += stepPrice;
    Print("✔️[gridbot.mq5:125]: price: ", price);
  }
}

void priceSizeGeometric()
{
  double price = lowerPrice;
  double stepPrice = pow((upperPrice / lowerPrice), (1 / gridSize));

  for (int i = 0; price <= upperPrice; i++)
  {
    gridPrice[i].price = price;
    price *= pow(stepPrice, i);
    Print("✔️[gridbot.mq5:138]: price: ", price);
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
    reply = trade.BuyLimit(orderSize, gridPrice[orderIndex].price, NULL, 0, gridPrice[orderIndex + 1].price);
    break;

  case orderShort:
    reply = trade.SellLimit(orderSize, gridPrice[orderIndex].price, NULL, 0, gridPrice[orderIndex - 1].price);
    break;

  case orderVoid:
    break;
  }

  orderReply(reply);
  gridPrice[orderIndex].ticket = trade.ResultOrder();
  Print("✔️[GridTradingBot.mq5:194]: ticket: ", gridPrice[orderIndex].ticket);
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
  int orderIndex = 0; // Can make it so the indexFromTicket returns -1 if not found

  orderIndex = indexFromTicket(ticket);

  if (orderIndex == -1)
  {
    return;
  }

  // trade.PositionClose(gridPrice[orderIndex].ticket);

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
  Print("Ticket Activated ", ticket);
  for (int i = 0; i < ArraySize(gridPrice); i++)
  {
    Print("Searching. Currently: ", i);
    Print("Current Ticket: ", gridPrice[i].ticket);
    Print("Direction: ", gridPrice[i].direction);
    if (ticket == gridPrice[i].ticket)
      return i;
  }
  Print("Ticket not found");
  // ExpertRemove();
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
  MqlTick currentPrice;

  // Check all Inputs are valid
  if (!dataValidation())
  {
    Print("Init Failed");
    return (INIT_FAILED); // F
  }

  // Global trading settings
  trade.SetExpertMagicNumber(expertAdvisorID);
  trade.SetTypeFilling(ORDER_FILLING_RETURN);
  trade.LogLevel(2);
  trade.SetAsyncMode(false);
  // trade.SetDeviationInPoints(deviation);
  // * Ask if slippage is neccesary

  if (!SymbolInfoTick(currentSymbol, currentPrice)) // Grab Current Price to set orders
  {
    printf("Current price of Symbol couldn't be found");
    return (INIT_FAILED);
  }

  fillPriceArray(); // Set Prices where orders will happen

  Print(currentPrice.last); // ! Change to currentprice.last  when outside of backtesting
  Print(currentPrice.ask);
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

  //* Next Step, handle orders while running "OnTradeTransaction"
  // https://www.binance.com/en/support/faq/what-is-spot-grid-trading-and-how-does-it-work-d5f441e8ab544a5b98241e00efb3a4ab
}