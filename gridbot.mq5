//+------------------------------------------------------------------+
//|                                                      GridBot.mq5 |
//|                                                      AriZone2023 |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "AriZone2023"
#property link "https://www.mql5.com"
#property version "1.00"

#property script_show_inputs
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

//--- Input Parameters
enum selectGridType
{
  arithmetic = 0, // Arithmetic (Each Grid has an equal price difference)
  geometric = 1,  // TODO: Geometric (Each Grid has an equal price diffence ratio)
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

input string symbol; // Symbol

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

double gridPrice[]; // Array containing all the prices to work with

void priceSizeArithmetic()
{
  double price = lowerPrice;
  double stepPrice = (upperPrice - lowerPrice) / gridSize;
  for (int i = 0; price <= upperPrice; i++)
  {
    gridPrice[i] = price;
    price += stepPrice;
  }
}

void priceSizeGeometric()
{
  double price = lowerPrice;
  double stepPrice = pow((upperPrice / lowerPrice), (1 / gridSize));
  for (int i = 0; price <= upperPrice; i++)
  {
    gridPrice[i] = price;
    price += pow(stepPrice, i);
  }
}

void fillPriceArray()
{
  ArrayResize(gridPrice, gridSize + 2);
  if (gridType == 0)
    priceSizeArithmetic();
  else
    priceSizeGeometric();
}

int OnInit()
{
  //---
  // TODO: Check all Inputs are valid
  // TODO: Set step size
  // TODO: Set Order Size
  fillPriceArray();
  //---
  return (INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
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
