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

CTrade *trade;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

//--- Input Parameters
enum selectGridType
{
  arithmetic = 0, // Arithmetic (Each Grid has an equal price difference)
  geometric = 1,  // Geometric (Each Grid has an equal price diffence ratio)
};

enum selectGridDirection
{
  neutralDirection = 0, // Neutral
  longDirection = 1,    // TODO: Long
  shortDirection = 2,   // TODO: Short
};

// * Make separate functions for each action
// If they start to use optimization, update input to sinput
// https://www.mql5.com/en/docs/basis/variables/inputvariables#sinput

sinput int expertAdvisorID = 31254; // Expert Advisor ID "Magic Number"

sinput string currentSymbol; // Symbol

input selectGridDirection gridDirection = neutralDirection;

input group "Price Range";
input double lowerPrice; // Lower Price
input double upperPrice; // Upper Price

input group "Grid";
input int gridSize;                         // Number of Grids
input selectGridType gridType = arithmetic; // Grid Type

input group "Investment";
input double initialMagin; // Initial Margin
input int leverage = 20;   // Leverage

input group "Advanced";
input bool gridTriggerActivation;    // Grid Trigger
input double gridTriggerBottomPrice; // Bottom Price
input double gridTriggerUpperPrice;  // Upper Price
input bool stopTriggerActivation;    // Stop Trigger
input double stopTriggerBottomPrice; // Bottom Price
input double stopTriggerUpperPrice;  // Upper Price
input bool cancelOrdersOnStop;       // Cancel all orders on stop
input bool closePositionsOnStop;     // Close all positions on stop

double currentMargin = 0;

enum orderDirection
{
  orderLong,
  orderShort
};

struct gridOrders
{
  double price;
  ulong ticket;
  orderDirection direction;
};
gridOrders gridPrice[]; // Array containing all the prices to work with

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
  if (gridTriggerUpperPrice <= gridTriggerBottomPrice)
  {
    Print("Grid Trigger Activation Upper Price cannot be lower or equal to the Lower Price");
    return false;
  }
  if (stopTriggerUpperPrice <= stopTriggerBottomPrice)
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
    Print("✔️[gridbot.mq5:129]: price: ", price);
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
    Print("✔️[gridbot.mq5:142]: price: ", price);
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

void initialOrders(double price)
{
  for (int i = 0; i <= ArraySize(gridPrice); i++)
  {
    directionOrder(i, price);
  }
}

void directionOrder(int i, double price)
{
  if (gridPrice[i].price <= price)
  {
    gridPrice[i].direction = orderLong;
    gridPrice[i].ticket = placeOrder(gridPrice[i].price, ORDER_TYPE_BUY_LIMIT);
  }
  else
  {
    gridPrice[i].direction = orderShort;
    gridPrice[i].ticket = placeOrder(gridPrice[i].price, ORDER_TYPE_SELL_LIMIT);
  }
}

ulong placeOrder(double price, ENUM_ORDER_TYPE direction)
{
  MqlTradeRequest request;
  MqlTradeResult reply;
  MqlTradeCheckResult replyValidate;
  bool orderReplyCheck;

  // Stucture to make the trade request at Market
  request.action = TRADE_ACTION_PENDING;
  request.magic = expertAdvisorID;
  request.symbol = currentSymbol;
  request.price = price;
  request.volume = orderSize;
  request.type = direction;
  request.type_filling = ORDER_FILLING_FOK;

  orderReplyCheck = OrderCheck(request, replyValidate);
  Print(replyValidate.comment);
  Print(reply.retcode);
  orderReply(orderReplyCheck);

  orderReplyCheck = OrderSend(request, reply); // * Read function documentation
  orderReply(orderReplyCheck);
  Print("Order #", reply.order);
  Print(reply.comment);
  Print(reply.retcode);

  return reply.order;
}

void orderReply(bool reply)
{
  if (reply == false)
  {
    Print("Order Failed. Exiting EA");
    ExpertRemove();
  }
}

void closeAllPositions()
{
}

void closeAllOrders()
{
}

int OnInit()
{
  //---
  // Check all Inputs are valid
  bool dataIsValid = false;
  bool currentPriceCheck = false;
  MqlTick currentPrice;

  dataIsValid = dataValidation();
  if (dataIsValid == false)
  {
    return (INIT_FAILED); // F
  }

  currentPriceCheck = SymbolInfoTick(currentSymbol, currentPrice); // Grab Current Price to set orders
  if (currentPriceCheck == false)
  {
    printf("Current price of Symbol couldn't be found");
    return (INIT_FAILED);
  }

  fillPriceArray(); // Set Prices where orders will happen

  initialOrders(currentPrice.last); // Place Initial Orders. Decide the direction based on Last Price
  //---
  return (INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
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

  //---
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
  //---
}
//+------------------------------------------------------------------+
