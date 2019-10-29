import 'package:decimal/decimal.dart';
import 'dart:convert' as convert;
import 'package:http/http.dart' as http;

var baseUrl = "https://test.bronze.exchange/api/v1/";

enum Side { 
   buy, 
   sell 
}

class MarketDepthItem
{
  Decimal price;
  Decimal amount;
}

class MarketDepth {
  final Iterable<MarketDepthItem> asks;
  final Iterable<MarketDepthItem> bids;

  MarketDepth({this.asks, this.bids});

  factory MarketDepth.fromJson(Map<String, dynamic> json) {
    var bids = List<MarketDepthItem>();
    var asks = List<MarketDepthItem>();
    for (var bid in json["bids"])
      bids.add(MarketDepthItem()
        ..price = Decimal.parse(bid[0])
        ..amount = Decimal.parse(bid[1])
      );
    for (var ask in json["asks"])
      asks.add(MarketDepthItem()
        ..price = Decimal.parse(ask[0])
        ..amount = Decimal.parse(ask[1])
      );
    return MarketDepth(
      bids: bids,
      asks: asks,
    );
  }
}

Future<Decimal> equivalentZapForNzd(Decimal nzdReqOrProvided, Side zapSide) async {
  var url = baseUrl + "MarketDepth";
  var body = convert.jsonEncode({"market": "ZAPNZD", "merge": "0.01"});
  var response = await http.post(url, headers: {"Content-Type": "application/json"}, body: body);
  if (response.statusCode == 200) {
    var marketDepth = MarketDepth.fromJson(convert.json.decode(response.body));
    var amountZap = Decimal.fromInt(0);
    Iterable<MarketDepthItem> book;
    if (zapSide == Side.sell)
      // calculate the amount of zap to sell to get the required NZD
      book = marketDepth.bids;
    else
      // calculate the amount of zap available to buy with the provided NZD
      book = marketDepth.asks;
    for (var item in book) {
      if (nzdReqOrProvided <= Decimal.fromInt(0))
        break;
      // lower amount if it is too much
      var nzd = item.amount * item.price;
      var amount = item.amount;
      if (nzd > nzdReqOrProvided)
        amount = nzdReqOrProvided / nzd * item.amount;
      // calc amount of zap for this portion of liquidity
      amountZap += amount;
      nzdReqOrProvided -= amount * item.price;
    }
    if (nzdReqOrProvided > Decimal.fromInt(0))
      throw new Exception("not enough liquidity");
    return amountZap;
  }
  throw new Exception("cant reach bronze");
}