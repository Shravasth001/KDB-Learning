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
show select vwap: sum price * size % sum size by sym from tradeWithOrders;

"3. Buy vs Sell Volume:";
show "Buy vs Sell Volumes"
show select totalVolume: sum size by side from tradeWithOrders;

"4. Fill Ratio (Traded Size / Order Size):";
show "Fill Ratio (Trades to Orders - Grouped by symbol and side)"
show select fillRatio: sum size % sum orderBook[`size] by sym, side from tradeWithOrders;

"5. Participation Rate (Trade Size / Total Order Book Size):";
show "Participation Rate (Trades to Orders - Grouped by symbol)"
show select participation: sum size % sum orderBook[`size] by sym from tradeWithOrders;

"6. Price Impact Estimate (Last Trade - Order Price):";
show "Price Impact Estimate (Last Trade for symbol - last Order Price for symbol):"
show select impact: last price - last orderBook[`price] by sym from tradeWithOrders;

"7. Order Fill Status:";
show "Order Fill Status"
show select orderId, sym, filled: orderId in trade[`orderId] from orderBook;

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
        sym: `AAPL`TSLA`GOOG`TSLA;
        price: 152 160 168 161;
        size: 200 100 50 150;
        orderId: 1001 1003 1005 1002;
        sym_order: `AAPL`TSLA`GOOG`TSLA;
        side: `B`B`B`S;
        price_order: 150 160 170 155;
        size_order: 100 300 500 200;
        time_trade: (now + 00:00:10 * til 4);
        time_order: (now + 00:00:05 * 2 * (1001 1003 1005 1002 - 1001))
    );

/ Expected for matchedTrades (exact same fields as trade)
expectedMatchedTrades: trade;


/ Expected
expectedBuySellMatch: 
    select sym, size, side, price, time, orderId, sym1: sym, size1: size, side1: side, price1: price, time1: time, orderId1: orderId 
    from buys lj (`sym`size) xkey sells;

/ Expected VWAP
expectedVWAPSym:
    ([] sym: `AAPL`GOOG`TSLA; vwap: (152f;168f; (100*160 + 150*161)%250) );

/ Expected Buy vs Sell Volume
expectedBuySellVolume:
    ([] side: `B`S; totalVolume: (200+100+50;150));

/ Expected FillRatio
expectedFillRatio:
    ([] sym: `AAPL`GOOG`TSLA`TSLA; side: `B`B`B`S;
       fillRatio: (200%100;50%500;100%300;150%200));

/ Expected Participation
expectedParticipation:
    ([] sym: `AAPL`GOOG`TSLA;
       participation: ((200%100);(50%500);((100+150)% (300+200))));

/ Expected Price Impact
expectedPriceImpact:
    ([] sym: `AAPL`GOOG`TSLA;
       impact: (152-150;168-170;(161-155)));

/ Expected Order Fill Status
expectedOrderFillStatus:
    ([] orderId: 1001 1002 1003 1004 1005 1006;
        sym: `AAPL`AAPL`TSLA`TSLA`GOOG`GOOG;
        filled: (1b;1b;1b;1b;1b;0b)
    );

/ Expected VWAP by minute
/ minute field for each trade
expectedTradeWithOrders: update minute: time_trade - (time_trade mod 60000000000) from expectedTradeWithOrders;
expectedVWAPByMinute: 
    select vwap: sum price * size % sum size by sym, minute from expectedTradeWithOrders;

/ Expected Volume by minute
expectedVolumeByMinute:
    select totalVolume: sum size by sym, minute from expectedTradeWithOrders;

/ Expected Trade Count by minute
expectedTradeCountByMinute:
    select numTrades: count i by sym, minute from expectedTradeWithOrders;

/ Store test results
testResults: ();

/ Helper function for testing - In the process of debugging some syntax + logic
reportTest:{[testName;actual;expected] status: if[actual= expected;"PASS","FAIL"];testResults, (testName, status); status};


reportTest["Test: tradeWithOrders"; select tradeId, sym, price, size, orderId, time, side from tradeWithOrders; select tradeId, sym, price, size, orderId, time: time_trade, side from expectedTradeWithOrders];
reportTest["Test: matchedTrades"; matchedTrades; expectedMatchedTrades];
reportTest["Test: ordersWithTrade"; select orderId, sym, side, price, size, tradeId, price_trade, size_trade from ordersWithTrade; expectedOrdersWithTrade];
reportTest["Test: buySellMatch"; select sym, side, size, price, sym1, side1, size1, price1 from buySellMatch; expectedBuySellMatch];
reportTest["Test: VWAP Sym"; vwapSym; expectedVWAPSym];
reportTest["Test: Buy Sell Volume"; buySellVolume; expectedBuySellVolume];
reportTest["Test: Fill Ratio"; fillRatio; expectedFillRatio];
reportTest["Test: Participation"; participation; expectedParticipation];
reportTest["Test: Price Impact"; priceImpact; expectedPriceImpact];
reportTest["Test: Order Fill Status"; orderFillStatus; expectedOrderFillStatus];
reportTest["Test: VWAP by Minute"; vwapByMinute; expectedVWAPByMinute];
reportTest["Test: Volume by Minute"; volumeByMinute; expectedVolumeByMinute];
reportTest["Test: Trade Count by Minute"; tradeCountByMinute; expectedTradeCountByMinute];

/ ----------------- Display Test Report -----------------
testResults