/ -----------------------------------------
/ KDB learning Mini-Project
/ -----------------------------------------

/ Exercise 1: Create Orders and Trades Tables

orderBook: ([] orderId: (1001;1002;1003;1004;1005;1006); sym: (`AAPL;`AAPL;`TSLA;`TSLA;`GOOG;`GOOG); side: (`B;`S;`B;`S;`B;`S); price: 150 + 5 * til 6; size: 100 + 100 * til 6);

trade: ([] tradeId: (2001;2002;2003;2004);sym: (`AAPL;`TSLA;`GOOG;`TSLA);price: (152;160;168;161); size:(200;100;50;150); orderId: (1001;1003;1005;1002));

/ Add timestamps for time-based computations
show "Adding time columns to orderBook and trade"
now: .z.p;
trade[`time]: now + 00:00:10 * til count trade;
orderBook[`time]: now + 00:00:05 * 2 * til count orderBook;

/ Exercise 2: SQL-like joins and some window joins

"1. Left Join (Trades with Order Info):";

tradeWithOrders: trade lj `orderId xkey orderBook;
show "Trades with Orders";
show tradeWithOrders;

"2. Inner Join (Only Matched):";
matchedTrades: trade ij `orderId xkey orderBook;
show "Matched Trades";
show matchedTrades;

"3. Right Join (Orders with trade info):";
ordersWithTrade: orderBook lj `orderId xkey trade;
show "Orders with Trades"
show ordersWithTrade;

"4. Asof Join:";
tradeAsof: aj[`sym`time; trade; orderBook];
show "Trades as of"
show tradeAsof;

"5. Self Join (Buy/Sell Order Match on sym+size):";
buys: select from orderBook where side=`B;
sells: select from orderBook where side=`S;
buySellMatch: buys lj (`sym`size) xkey sells;
show "Buy and Sell matches"
show buySellMatch;

/ Exercise 3: Basic computations

"1. VWAP (Volume Weighted Avg Price) by Symbol:";
show "Volume Weighted Average Price"
VWAPSym: select vwap: sum price * size % sum size by sym from tradeWithOrders;
show VWAPSym;

"3. Buy vs Sell Volume:";
show "Buy vs Sell Volumes"
buySellVolume: select totalVolume: sum size by side from tradeWithOrders;
show buySellVolume;

"4. Fill Ratio (Traded Size / Order Size):";
show "Fill Ratio (Trades to Orders - Grouped by symbol and side)"
fillRatio: select fillRatio: sum size % sum orderBook[`size] by sym, side from tradeWithOrders;
show fillRatio;

"5. Participation Rate (Trade Size / Total Order Book Size):";
show "Participation Rate (Trades to Orders - Grouped by symbol)"
participation: select participation: sum size % sum orderBook[`size] by sym from tradeWithOrders;
show participation;

"6. Price Impact Estimate (Last Trade - Order Price):";
show "Price Impact Estimate (Last Trade for symbol - last Order Price for symbol):"
priceImpact: select impact: last price - last orderBook[`price] by sym from tradeWithOrders;
show priceImpact;

"7. Order Fill Status:";
show "Order Fill Status"
orderFillStatus: select orderId, sym, filled: orderId in trade[`orderId] from orderBook;
show orderFillStatus;

/ Exercise 4: Time-Based computations

"8. VWAP by Symbol and Minute:";
show "VWAP by minute"
tradeWithOrders: update minute: time - (time mod 60000000000) from tradeWithOrders;
show select vwap: sum price * size % sum size by sym, minute from tradeWithOrders;

"9. Volume per Minute:";
show "Volume per minute"
show select totalVolume: sum size by sym, minute from tradeWithOrders;

"10. Trade Count per Minute:";
show "Trade count per minute"
show select numTrades: count i by sym, minute from tradeWithOrders;


/ ----------------- Unit Tests -----------------

/ Expected for tradeWithOrders
expectedTradeWithOrders: 
    ([] tradeId: 2001 2002 2003 2004;
        sym: `AAPL`TSLA`GOOG`AAPL;
        price: 150 160 170 155;
        size: 100 300 500 200;
        orderId: 1001 1003 1005 1002;
        sym_order: `AAPL`TSLA`GOOG`AAPL;
        side: `B`B`B`S;
        price_order: 150 160 170 155;
        size_order: 100 300 500 200;
        time_trade: (now + 00:00:10 * til 4);
        time_order: (now + 00:00:05 * 2 * (1001 1003 1005 1002 - 1001))
    );

/ Expected for matchedTrades
expectedMatchedTrades: ([] tradeId: 2001 2002 2003 2004;
        sym: `AAPL`TSLA`GOOG`AAPL;
        price: 150 160 170 155;
        size: 100 300 500 200;
        orderId: 1001 1003 1005 1002;
        sym_order: `AAPL`TSLA`GOOG`AAPL;
        side: `B`B`B`S;
        price_order: 150 160 170 155;
        size_order: 100 300 500 200;
        time_trade: (now + 00:00:10 * til 4);
        time_order: (now + 00:00:05 * 2 * (1001 1003 1005 1002 - 1001))
    );
expectedBuySellMatch: 
    select sym, size, side, price, time, orderId, sym1: sym, size1: size, side1: side, price1: price, time1: time, orderId1: orderId 
    from buys lj (`sym`size) xkey sells;

/ Expected VWAP
expectedVWAPSym:
       `sym xkey ([] sym: (`AAPL`GOOG`AAPL);
        vwap: (153.3333 170 160));
/ Expected Buy vs Sell Volume
expectedBuySellVolume: `side xkey ([] side: `B`S; totalVolume: (900;200));

/ Expected FillRatio
expectedFillRatio:
    `sym`side xkey ([] sym: `AAPL`AAPL`GOOG`TSLA; side: `B`S`B`B;
       fillRatio: (0.04761905;0.0952381;0.2380952;0.1428571));

/ Expected Participation
expectedParticipation:
    `sym xkey ([] sym: `AAPL`GOOG`TSLA;
       participation: ((1%7);0.2380952;((1%7))));

/ Expected Price Impact
expectedPriceImpact:
    `sym xkey ([] sym: `AAPL`GOOG`TSLA;
       impact: (-20;-5;-15));

/ Expected Order Fill Status
expectedOrderFillStatus:
    ([] orderId: 1001 1002 1003 1004 1005 1006;
        sym: `AAPL`AAPL`TSLA`TSLA`GOOG`GOOG;
        filled: (1b;1b;1b;0b;1b;0b)
    );


/ Helper function for testing
reportTest:{[actual;expected]
	    if[actual ~ expected; status: "PASS"];
	    if[not actual ~ expected; status: "FAIL"];
	    status};


tradeWithOrdersTest: reportTest[select tradeId, sym, price, size, orderId, side from tradeWithOrders; select tradeId, sym, price, size, orderId, side from expectedTradeWithOrders];
matchedTradesTest: reportTest[select tradeId, sym, price, size, orderId, side from matchedTrades; select tradeId, sym, price, size, orderId, side from expectedMatchedTrades];
buySellMatchTest: reportTest[select sym, side, size from buySellMatch; select sym, side, size from expectedBuySellMatch];
vwapTest: reportTest[VWAPSym; expectedVWAPSym]; /Tolerance related - reading up on KDB tolerance
buySellVolumeTest: reportTest[keyedBuySellVolume; expectedBuySellVolume];
fillRatioTest: reportTest[fillRatio; expectedFillRatio]; /Tolerance related - reading up on KDB tolerance
participationTest: reportTest[participation; expectedParticipation]; /Tolerance related - reading up on KDB tolerance
priceImpactTest: reportTest[priceImpact; expectedPriceImpact];
orderFillTest: reportTest[orderFillStatus; expectedOrderFillStatus];

/ ----------------- Display Test Report -----------------
testResults: ([] testName: (`TradeWithOrders;`MatchedTrades;`BuySellMatch;`VWAP;`BuySellVolume;`FillRatio;`Participation;`PriceImpact; `OrderFillStatus); testStatus: (tradeWithOrdersTest; matchedTradesTest; buySellMatchTest; vwapTest; buySellVolumeTest; fillRatioTest; participationTest; priceImpactTest; orderFillTest));
show testResults;