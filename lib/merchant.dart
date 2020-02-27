import 'dart:math';
import 'dart:convert';
import "package:hex/hex.dart";
import 'package:decimal/decimal.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:socket_io_client/socket_io_client.dart';

import 'prefs.dart';

var baseUrl = "https://merchant-zap.herokuapp.com/";

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

class Rates {
  final Decimal merchantRate;
  final Decimal customerRate;
  final String settlementAddress;

  Rates({this.merchantRate, this.customerRate, this.settlementAddress});
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

Future<ClaimCode> merchantRegister(Decimal amount, int amountInt) async {
  var claimCode = ClaimCode.generate(amount);
  var url = baseUrl + "register";
  var apikey = await Prefs.apikeyGet();
  var apisecret = await Prefs.apisecretGet();
  var nonce = DateTime.now().toUtc().millisecondsSinceEpoch / 1000;
  var body = jsonEncode({"api_key": apikey, "nonce": nonce, "token": claimCode.token, "amount": amountInt});
  var sig = createHmacSig(apisecret, body);
  var response = await http.post(url, headers: {"X-Signature": sig, "Content-Type": "application/json"}, body: body);
  if (response.statusCode == 200) {
    return claimCode;
  }
  return null;
}

Future<String> merchantCheck(ClaimCode claimCode) async {
  var url = baseUrl + "check";
  var apikey = await Prefs.apikeyGet();
  var apisecret = await Prefs.apisecretGet();
  var nonce = DateTime.now().toUtc().millisecondsSinceEpoch / 1000;
  var body = jsonEncode({"api_key": apikey, "nonce": nonce, "token": claimCode.token});
  var sig = createHmacSig(apisecret, body);
  var response = await http.post(url, headers: {"X-Signature": sig, "Content-Type": "application/json"}, body: body);
  if (response.statusCode == 200) {
    return claimCode.getAddressIfJsonMatches(json.decode(response.body));
  }
  return null;
}

Future<bool> merchantClaim(ClaimCode claimCode, String address) async {
  var url = baseUrl + "claim";
  var body = jsonEncode({"token": claimCode.token, "secret": claimCode.secret, "address": address});
  var response = await http.post(url, headers: {"Content-Type": "application/json"}, body: body);
  if (response.statusCode == 200) {
    return true;
  }
  return false;
}

Future<bool> merchantWatch(String address) async {
  var url = baseUrl + "watch";
  var apikey = await Prefs.apikeyGet();
  var apisecret = await Prefs.apisecretGet();
  var nonce = DateTime.now().toUtc().millisecondsSinceEpoch / 1000;
  var body = jsonEncode({"api_key": apikey, "nonce": nonce, "address": address});
  var sig = createHmacSig(apisecret, body);
  var response = await http.post(url, headers: {"X-Signature": sig, "Content-Type": "application/json"}, body: body);
  if (response.statusCode == 200) {
    return true;
  }
  return false;
}

Future<Rates> merchantRates() async {
  var url = baseUrl + "rates";
  var apikey = await Prefs.apikeyGet();
  var apisecret = await Prefs.apisecretGet();
  var nonce = DateTime.now().toUtc().millisecondsSinceEpoch / 1000;
  var body = jsonEncode({"api_key": apikey, "nonce": nonce});
  var sig = createHmacSig(apisecret, body);
  var response = await http.post(url, headers: {"X-Signature": sig, "Content-Type": "application/json"}, body: body);
  if (response.statusCode == 200) {
    var jsnObj = json.decode(response.body);
    return Rates(customerRate: Decimal.parse(jsnObj["customer"]), merchantRate: Decimal.parse(jsnObj["merchant"]), settlementAddress: jsnObj["settlement_address"]);
  }
  return null;
}

Future<Settlement> merchantSettlement(Decimal amount, String bankAccount) async {
  var url = baseUrl + "settlement";
  var apikey = await Prefs.apikeyGet();
  var apisecret = await Prefs.apisecretGet();
  var nonce = DateTime.now().toUtc().millisecondsSinceEpoch / 1000;
  var d100 = Decimal.fromInt(100);
  var body = jsonEncode({"api_key": apikey, "nonce": nonce, "bank_account": bankAccount, "amount": (amount * d100).toInt()});
  var sig = createHmacSig(apisecret, body);
  var response = await http.post(url, headers: {"X-Signature": sig, "Content-Type": "application/json"}, body: body);
  if (response.statusCode == 200) {
    var jsnObj = json.decode(response.body);
    return Settlement(token: jsnObj["token"], amount: Decimal.fromInt(jsnObj["amount"]) / d100, amountReceive: Decimal.fromInt(jsnObj["amount_receive"]) / d100, bankAccount: jsnObj["bankAccount"], txid: jsnObj["txid"], status: jsnObj["status"]);
  }
  return null;
}

Future<Settlement> merchantSettlementUpdate(String token, String txid) async {
  var url = baseUrl + "settlement_set_txid";
  var apikey = await Prefs.apikeyGet();
  var apisecret = await Prefs.apisecretGet();
  var nonce = DateTime.now().toUtc().millisecondsSinceEpoch / 1000;
  var body = jsonEncode({"api_key": apikey, "nonce": nonce, "token": token, "txid": txid});
  var sig = createHmacSig(apisecret, body);
  var response = await http.post(url, headers: {"X-Signature": sig, "Content-Type": "application/json"}, body: body);
  if (response.statusCode == 200) {
    var jsnObj = json.decode(response.body);
    var d100 = Decimal.fromInt(100);
    return Settlement(token: jsnObj["token"], amount: Decimal.fromInt(jsnObj["amount"]) / d100, amountReceive: Decimal.fromInt(jsnObj["amount_receive"]) / d100, bankAccount: jsnObj["bankAccount"], txid: jsnObj["txid"], status: jsnObj["status"]);
  }
  return null;
}

typedef TxNotificationCallback = void Function(String, String, double);
Future<Socket> merchantSocket(TxNotificationCallback txNotificationCallback) async {
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
    txNotificationCallback(json["id"], json["recipient"], json["amount"].toDouble());
  });
  socket.on('disconnect', (_) {
    print('ws disconnect');
  });

  return socket;
}

Future<Decimal> equivalentCustomerZapForNzd(Decimal nzdReqOrProvided) async {
  var rates = await merchantRates();
  if (rates == null) {
    throw new Exception("could not get rates");
  }
  return nzdReqOrProvided * (Decimal.fromInt(1) + rates.customerRate);
}