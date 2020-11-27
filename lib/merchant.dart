import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import "package:hex/hex.dart";
import 'package:decimal/decimal.dart';
import 'package:crypto/crypto.dart';
import 'package:socket_io_client/socket_io_client.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:intl/intl.dart';

import 'prefs.dart';
import 'zapdart/utils.dart';
import 'zapdart/widgets.dart';

class ClaimCode {
  final Decimal amount;
  final String token;
  final String secret;

  ClaimCode({this.amount, this.token, this.secret});

  String getAddressIfJsonMatches(Map<String, dynamic> json) {
    if (token == json["token"] && secret == json["secret"])
      return json["address"];
    return null;
  }

  factory ClaimCode.generate(Decimal _amount) {
    return ClaimCode(
      amount: _amount,
      token: HEX.encode(secureRandom(count: 8)),
      secret: HEX.encode(secureRandom(count: 16))
    );
  }
}

class ClaimCodeResult {
  final ClaimCode code;
  final int error;

  ClaimCodeResult(this.code, this.error);
}

ClaimCodeResult parseClaimCodeUri(String uri) {
  var token = '';
  var secret = '';
  var amount = Decimal.fromInt(0);
  int error = NO_ERROR;
  if (uri.length > 10 && uri.substring(0, 10).toLowerCase() == 'claimcode:') {
    var parts = uri.substring(10).split('?');
    if (parts.length == 2) {
      token = parts[0];
      parts = parts[1].split('&');
      for (var part in parts) {
        var res = parseUriParameter(part, 'secret');
        if (res != null) secret = res;
        res = parseUriParameter(part, 'amount');
        if (res != null) amount = Decimal.parse(res) / Decimal.fromInt(100);
      }
    }
  }
  else
    error = INVALID_CLAIMCODE_URI;
  return ClaimCodeResult(ClaimCode(amount: amount, token: token, secret: secret), error);
}

class Rates {
  final Decimal salesTax;
  final Decimal settlementFee;
  final Decimal merchantRate;
  final Decimal customerRate;
  final String settlementAddress;

  Rates({this.salesTax, this.settlementFee, this.merchantRate, this.customerRate, this.settlementAddress});
}

class Bank {
  final String token;
  final String accountName;
  final String accountNumber;
  final bool defaultAccount;

  Bank({this.token, this.accountName, this.accountNumber, this.defaultAccount});
}

class Settlement {
  final String token;
  final Decimal amount;
  final Decimal amountReceive;
  final String bankAccount;
  final String txid;
  final String status;

  Settlement({this.token, this.amount, this.amountReceive, this.bankAccount, this.txid, this.status});
}

class SettlementCalcResult {
  final Decimal amount;
  final Decimal amountReceive;
  final String error;

  SettlementCalcResult(this.amount, this.amountReceive, this.error);
}

class SettlementResult {
  final Settlement settlement;
  final String error;

  SettlementResult(this.settlement, this.error);
}

String claimCodeUri(ClaimCode claimCode) {
  return "claimcode:${claimCode.token}?secret=${claimCode.secret}";
}

List<int> secureRandom({count: 32}) {
  var random = Random.secure();
  return List<int>.generate(count, (i) => random.nextInt(256));
}

String createHmacSig(String secret, String message) {
  var secretBytes = utf8.encode(secret);
  var messageBytes = utf8.encode(message);
  var hmac = Hmac(sha256, secretBytes);
  var digest = hmac.convert(messageBytes);
  return base64.encode(digest.bytes);
}

class NoApiKeyException implements Exception {}

void checkApiKey(String apikey, String apisecret) {
  if (apikey == null)
    throw NoApiKeyException();
  if (apisecret == null)
    throw NoApiKeyException();
}

Future<ClaimCode> merchantRegister(Decimal amount, int amountInt) async {
  var claimCode = ClaimCode.generate(amount);
  var baseUrl = await Prefs.apiserverGet();
  var url = baseUrl + "register";
  var apikey = await Prefs.apikeyGet();
  var apisecret = await Prefs.apisecretGet();
  checkApiKey(apikey, apisecret);
  var nonce = DateTime.now().toUtc().millisecondsSinceEpoch / 1000;
  var body = jsonEncode({"api_key": apikey, "nonce": nonce, "token": claimCode.token, "amount": amountInt});
  var sig = createHmacSig(apisecret, body);
  var response = await post(url, body, extraHeaders: {"X-Signature": sig});
  if (response.statusCode == 200) {
    return claimCode;
  }
  return null;
}

Future<String> merchantCheck(ClaimCode claimCode) async {
  var baseUrl = await Prefs.apiserverGet();
  var url = baseUrl + "check";
  var apikey = await Prefs.apikeyGet();
  var apisecret = await Prefs.apisecretGet();
  checkApiKey(apikey, apisecret);
  var nonce = DateTime.now().toUtc().millisecondsSinceEpoch / 1000;
  var body = jsonEncode({"api_key": apikey, "nonce": nonce, "token": claimCode.token});
  var sig = createHmacSig(apisecret, body);
  var response = await post(url, body, extraHeaders: {"X-Signature": sig});
  if (response.statusCode == 200) {
    return claimCode.getAddressIfJsonMatches(json.decode(response.body));
  }
  return null;
}

Future<bool> merchantClaim(ClaimCode claimCode, String address) async {
  var baseUrl = await Prefs.apiserverGet();
  var url = baseUrl + "claim";
  var body = jsonEncode({"token": claimCode.token, "secret": claimCode.secret, "address": address});
  var response = await post(url, body);
  if (response.statusCode == 200) {
    return true;
  }
  return false;
}

Future<bool> merchantWatch(String address) async {
  var baseUrl = await Prefs.apiserverGet();
  var url = baseUrl + "watch";
  var apikey = await Prefs.apikeyGet();
  var apisecret = await Prefs.apisecretGet();
  checkApiKey(apikey, apisecret);
  var nonce = DateTime.now().toUtc().millisecondsSinceEpoch / 1000;
  var body = jsonEncode({"api_key": apikey, "nonce": nonce, "address": address});
  var sig = createHmacSig(apisecret, body);
  var response = await post(url, body, extraHeaders: {"X-Signature": sig});
  if (response.statusCode == 200) {
    return true;
  }
  return false;
}

Future<bool> merchantWalletAddress(String address) async {
  var baseUrl = await Prefs.apiserverGet();
  var url = baseUrl + "wallet_address";
  var apikey = await Prefs.apikeyGet();
  var apisecret = await Prefs.apisecretGet();
  checkApiKey(apikey, apisecret);
  var nonce = DateTime.now().toUtc().millisecondsSinceEpoch / 1000;
  var body = jsonEncode({"api_key": apikey, "nonce": nonce, "address": address});
  var sig = createHmacSig(apisecret, body);
  var response = await post(url, body, extraHeaders: {"X-Signature": sig});
  if (response.statusCode == 200) {
    return true;
  }
  return false;
}

Future<bool> merchantTx() async {
  var baseUrl = await Prefs.apiserverGet();
  var url = baseUrl + "merchanttx";
  var apikey = await Prefs.apikeyGet();
  var apisecret = await Prefs.apisecretGet();
  checkApiKey(apikey, apisecret);
  var nonce = DateTime.now().toUtc().millisecondsSinceEpoch / 1000;
  var body = jsonEncode({"api_key": apikey, "nonce": nonce,});
  var sig = createHmacSig(apisecret, body);
  var response = await post(url, body, extraHeaders: {"X-Signature": sig});
  if (response.statusCode == 200) {
    return true;
  }
  return false;
}

Future<Rates> merchantRates() async {
  var baseUrl = await Prefs.apiserverGet();
  var url = baseUrl + "rates";
  var apikey = await Prefs.apikeyGet();
  var apisecret = await Prefs.apisecretGet();
  checkApiKey(apikey, apisecret);
  var nonce = DateTime.now().toUtc().millisecondsSinceEpoch / 1000;
  var body = jsonEncode({"api_key": apikey, "nonce": nonce});
  var sig = createHmacSig(apisecret, body);
  var response = await post(url, body, extraHeaders: {"X-Signature": sig});
  if (response.statusCode == 200) {
    var jsnObj = json.decode(response.body);
    return Rates(salesTax: Decimal.parse(jsnObj["sales_tax"]), settlementFee: Decimal.parse(jsnObj["settlement_fee"]), customerRate: Decimal.parse(jsnObj["customer"]), merchantRate: Decimal.parse(jsnObj["merchant"]), settlementAddress: jsnObj["settlement_address"]);
  }
  return null;
}

Future<List<Bank>> merchantBanks() async {
  var baseUrl = await Prefs.apiserverGet();
  var url = baseUrl + "banks";
  var apikey = await Prefs.apikeyGet();
  var apisecret = await Prefs.apisecretGet();
  checkApiKey(apikey, apisecret);
  var nonce = DateTime.now().toUtc().millisecondsSinceEpoch / 1000;
  var body = jsonEncode({"api_key": apikey, "nonce": nonce});
  var sig = createHmacSig(apisecret, body);
  var response = await post(url, body, extraHeaders: {"X-Signature": sig});
  if (response.statusCode == 200) {
    var jsnObj = json.decode(response.body);
    var banks = List<Bank>();
    for (var jsnObjBank in jsnObj) {
      var bank = Bank(token: jsnObjBank["token"], accountName: jsnObjBank["account_name"], accountNumber: jsnObjBank["account_number"], defaultAccount: jsnObjBank["default_account"]);
      banks.add(bank);
    }
    return banks;  
  }
  return null;
}

Future<SettlementCalcResult> merchantSettlementCalc(Decimal amount) async {
  var baseUrl = await Prefs.apiserverGet();
  var url = baseUrl + "settlement_calc";
  var apikey = await Prefs.apikeyGet();
  var apisecret = await Prefs.apisecretGet();
  checkApiKey(apikey, apisecret);
  var nonce = DateTime.now().toUtc().millisecondsSinceEpoch / 1000;
  var d100 = Decimal.fromInt(100);
  var body = jsonEncode({"api_key": apikey, "nonce": nonce, "amount": (amount * d100).toInt()});
  var sig = createHmacSig(apisecret, body);
  var response = await post(url, body, extraHeaders: {"X-Signature": sig});
  if (response.statusCode == 200) {
    var jsnObj = json.decode(response.body);
    return SettlementCalcResult(Decimal.fromInt(jsnObj["amount"]) / d100, Decimal.fromInt(jsnObj["amount_receive"]) / d100, null);
  }
  var jsnObj = json.decode(response.body);
  return SettlementCalcResult(null, null, jsnObj["message"]);
}

Future<SettlementResult> merchantSettlement(Decimal amount, String bankToken) async {
  var baseUrl = await Prefs.apiserverGet();
  var url = baseUrl + "settlement";
  var apikey = await Prefs.apikeyGet();
  var apisecret = await Prefs.apisecretGet();
  checkApiKey(apikey, apisecret);
  var nonce = DateTime.now().toUtc().millisecondsSinceEpoch / 1000;
  var d100 = Decimal.fromInt(100);
  var body = jsonEncode({"api_key": apikey, "nonce": nonce, "bank": bankToken, "amount": (amount * d100).toInt()});
  var sig = createHmacSig(apisecret, body);
  var response = await post(url, body, extraHeaders: {"X-Signature": sig});
  if (response.statusCode == 200) {
    var jsnObj = json.decode(response.body);
    return SettlementResult(
      Settlement(token: jsnObj["token"], amount: Decimal.fromInt(jsnObj["amount"]) / d100, amountReceive: Decimal.fromInt(jsnObj["amount_receive"]) / d100, bankAccount: jsnObj["bankAccount"], txid: jsnObj["txid"], status: jsnObj["status"]),
      null);
  }
  var jsnObj = json.decode(response.body);
  return SettlementResult(null, jsnObj["message"]);
}

Future<SettlementResult> merchantSettlementUpdate(String token, String txid) async {
  var baseUrl = await Prefs.apiserverGet();
  var url = baseUrl + "settlement_set_txid";
  var apikey = await Prefs.apikeyGet();
  var apisecret = await Prefs.apisecretGet();
  checkApiKey(apikey, apisecret);
  var nonce = DateTime.now().toUtc().millisecondsSinceEpoch / 1000;
  var body = jsonEncode({"api_key": apikey, "nonce": nonce, "token": token, "txid": txid});
  var sig = createHmacSig(apisecret, body);
  var response = await post(url, body, extraHeaders: {"X-Signature": sig});
  if (response.statusCode == 200) {
    var jsnObj = json.decode(response.body);
    var d100 = Decimal.fromInt(100);
    return SettlementResult( 
      Settlement(token: jsnObj["token"], amount: Decimal.fromInt(jsnObj["amount"]) / d100, amountReceive: Decimal.fromInt(jsnObj["amount_receive"]) / d100, bankAccount: jsnObj["bankAccount"], txid: jsnObj["txid"], status: jsnObj["status"]),
      null);
  }
  var jsnObj = json.decode(response.body);
  return SettlementResult(null, jsnObj["message"]);
}

typedef TxNotificationCallback = void Function(String txid, String sender, String recipient, double amount, String attachment);
Future<Socket> merchantSocket(TxNotificationCallback txNotificationCallback) async {
  var baseUrl = await Prefs.apiserverGet();
  var apikey = await Prefs.apikeyGet();
  var apisecret = await Prefs.apisecretGet();
  var nonce = DateTime.now().toUtc().millisecondsSinceEpoch / 1000;
 
  var socket = io(baseUrl, <String, dynamic>{
    'secure': true,
    'transports': ['websocket'],
  });
  socket.on('connect', (_) {
    print('ws connect');
    var sig = createHmacSig(apisecret, nonce.toString());
    var auth = {"signature": sig, "api_key": apikey, "nonce": nonce};
    socket.emit('auth', auth);
  });
  socket.on('connecting', (_) {
    print('ws connecting');
  });
  socket.on('connect_error', (err) {
    print('ws connect error ($err)');
  });
  socket.on('connect_timeout', (_) {
    print('ws connect timeout');
  });
  socket.on('info', (data) {
    print(data);
  });
  socket.on('tx', (data) {
    print(data);
    var json = jsonDecode(data);
    txNotificationCallback(json["id"], json["sender"], json["recipient"], json["amount"].toDouble(), json["attachment"]);
  });
  socket.on('disconnect', (_) {
    print('ws disconnect');
  });
 
  return socket;
}

String toNZDAmount(Decimal amount, Rates rates) {
  if (rates != null) {
    var fee = (amount - (amount / (Decimal.fromInt(1) + rates.merchantRate))) * (Decimal.fromInt(1) + rates.salesTax);
    var amountNZD = amount - fee;
    return "${amountNZD.toStringAsFixed(2)} NZD";
  }
  return "";
}

Decimal equivalentCustomerZapForNzd(Decimal nzdRequired, Rates rates) {
  print('nzdRequired: $nzdRequired');
  var merchantFee = (nzdRequired * (Decimal.fromInt(1) + rates.customerRate)) - nzdRequired;
  print('merchantFee: $merchantFee');
  merchantFee = merchantFee * (Decimal.fromInt(1) + rates.salesTax);
  print('merchantFee (inc tax): $merchantFee');
  var amountZap = nzdRequired + merchantFee;
  print('amountZap: $amountZap');
  return amountZap;
}

class ListTx extends StatelessWidget {
  ListTx(this.onPressed, this.date, this.txid, this.amount, this.merchantRates, this.outgoing, {this.last = false}) : super();

  final VoidCallback onPressed;
  final DateTime date;
  final String txid;
  final Decimal amount;
  final Rates merchantRates;
  final bool outgoing;
  final bool last;

  @override
  Widget build(BuildContext context) {
    var color = outgoing ? zapyellow : zapgreen;
    var tsLeft = TextStyle(fontSize: 12, color: zapblacklight);
    var tsRight = TextStyle(fontSize: 12, color: color);
    var amountText = '${amount.toStringAsFixed(2)} ZAP';
    Widget amountWidget = Text(amountText, style: tsRight);
    if (merchantRates != null) {
      var amountNZD = Text(toNZDAmount(amount, merchantRates), style: tsRight);
      amountWidget = Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: <Widget>[
        amountWidget,
        amountNZD
      ]);
    }
    var icon = outgoing ? MaterialCommunityIcons.chevron_double_up : MaterialCommunityIcons.chevron_double_down;
    return Column(
      children: <Widget>[
        Divider(),
        ListTile(
          onTap: onPressed,
          dense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 8),
          leading: Column(mainAxisAlignment: MainAxisAlignment.center, children: <Widget>[
            Text(DateFormat('d MMM').format(date).toUpperCase(), style: tsLeft),
            Text(DateFormat('yyyy').format(date), style: tsLeft),
          ]),
          title: Text(txid),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
            Text(outgoing ? '- ' : '+ ', style: tsRight),
            amountWidget, 
            Icon(icon, color: color, size: 14)]
          )
        ),
        Visibility(
          visible: last,
          child: Divider()
        )
      ]
    );
  }
}