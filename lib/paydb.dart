import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:email_validator/email_validator.dart';

import 'hmac.dart';
import 'config.dart';
import 'prefs.dart';
import 'package:zapdart/utils.dart';

Future<String> _server() async {
  var testnet = await Prefs.testnetGet();
  return testnet ? PayDBServerTestnet : PayDBServerMainnet;
}

const ActionIssue = 'issue';
const ActionTransfer = 'transfer';
const ActionDestroy = 'destroy';

enum PayDbError {
  None, Network, Auth
}

class UserInfo {
  final String email;
  final int balance;
  final String photo;

  UserInfo(this.email, this.balance, this.photo);
}

class UserInfoResult {
  final UserInfo info;
  final PayDbError error;

  UserInfoResult(this.info, this.error);
}

class PayDbApiKey {
  final String token;
  final String secret;

  PayDbApiKey(this.token, this.secret);
}

class PayDbApiKeyResult {
  final PayDbApiKey apikey;
  final PayDbError error;

  PayDbApiKeyResult(this.apikey, this.error);
}

class PayDbTx {
  final String token;
  final String action;
  final int timestamp;
  final String sender;
  final String recipient;
  final int amount;
  final String attachment;

  PayDbTx(this.token, this.action, this.timestamp, this.sender, this.recipient, this.amount, this.attachment);
}

class PayDbUserTxsResult {
  final Iterable<PayDbTx> txs;
  final PayDbError error;

  PayDbUserTxsResult(this.txs, this.error);
}

class PayDbTxResult {
  final PayDbTx tx;
  final PayDbError error;

  PayDbTxResult(this.tx, this.error);
}

Future<http.Response> postAndCatch(String url, String body, {Map<String, String> extraHeaders}) async {
  try {
    return await post(url, body, extraHeaders: extraHeaders);
  } on SocketException catch(e) {
    print(e);
    return null;
  } on TimeoutException catch(e) {
    print(e);
    return null;
  }
}

Future<String> paydbServer() async {
  return await _server();
}

String paydbParseRecipient(String value) {
  if (EmailValidator.validate(value))
    return value;
  return null;
}

Future<PayDbApiKeyResult> paydbApiKeyCreate(String email, String password, String deviceName) async {
  var baseUrl = await _server();
  var url = baseUrl + "api_key_create";
  var body = jsonEncode({"email": email, "password": password, "device_name": deviceName});
  var response = await postAndCatch(url, body);
  if (response == null)
    return PayDbApiKeyResult(null, PayDbError.Network);
  if (response.statusCode == 200) {
    var jsnObj = json.decode(response.body);
    var info = PayDbApiKey(jsnObj["token"], jsnObj["secret"]);
    return PayDbApiKeyResult(info, PayDbError.None);
  } else if (response.statusCode == 400)
    return PayDbApiKeyResult(null, PayDbError.Auth);
  print(response.statusCode);
  return PayDbApiKeyResult(null, PayDbError.Network);
}

Future<UserInfoResult> paydbUserInfo() async {
  var baseUrl = await _server();
  var url = baseUrl + "user_info";
  var apikey = await Prefs.paydbApiKeyGet();
  var apisecret = await Prefs.paydbApiSecretGet();
  checkApiKey(apikey, apisecret);
  var nonce = DateTime.now().toUtc().millisecondsSinceEpoch / 1000;
  var body = jsonEncode({"api_key": apikey, "nonce": nonce, "email": null});
  var sig = createHmacSig(apisecret, body);
  var response = await postAndCatch(url, body, extraHeaders: {"X-Signature": sig});
  if (response == null)
    return UserInfoResult(null, PayDbError.Network);
  if (response.statusCode == 200) {
    var jsnObj = json.decode(response.body);
    var info = UserInfo(jsnObj["email"], jsnObj["balance"], jsnObj["photo"]);
    return UserInfoResult(info, PayDbError.None);
  } else if (response.statusCode == 400)
    return UserInfoResult(null, PayDbError.Auth);
  print(response.statusCode);
  return UserInfoResult(null, PayDbError.Network);
}

PayDbTx parseTx(dynamic jsn) {
  return PayDbTx(jsn["token"], jsn["action"], jsn["timestamp"], jsn["sender"], jsn["recipient"], jsn["amount"], jsn["attachment"]);
}

Future<PayDbUserTxsResult> paydbUserTransactions(int offset, int limit) async {
  var baseUrl = await _server();
  var url = baseUrl + "user_transactions";
  var apikey = await Prefs.paydbApiKeyGet();
  var apisecret = await Prefs.paydbApiSecretGet();
  checkApiKey(apikey, apisecret);
  var nonce = DateTime.now().toUtc().millisecondsSinceEpoch / 1000;
  var body = jsonEncode({"api_key": apikey, "nonce": nonce, "offset": offset, "limit": limit});
  var sig = createHmacSig(apisecret, body);
  var response = await postAndCatch(url, body, extraHeaders: {"X-Signature": sig});
  if (response == null)
    return PayDbUserTxsResult(null, PayDbError.Network);
  if (response.statusCode == 200) {
    var jsnObj = json.decode(response.body);
    var txs = List<PayDbTx>();
    for (var tx in jsnObj["txs"]) {
      txs.add(parseTx(tx));
    }
    return PayDbUserTxsResult(txs, PayDbError.None);
  } else if (response.statusCode == 400)
    return PayDbUserTxsResult(null, PayDbError.Auth);
  print(response.statusCode);
  return PayDbUserTxsResult(null, PayDbError.Network);
}

bool paydbRecipientCheck(String recipient) {
  // check valid email address (from https://stackoverflow.com/a/61512807/206529)
  return RegExp(
    r'^(([^<>()[\]\\.,;:\s@\"]+(\.[^<>()[\]\\.,;:\s@\"]+)*)|(\".+\"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$')
    .hasMatch(recipient);
}

Future<PayDbTxResult> paydbTransactionCreate(String action, String recipient, int amount, String attachment) async {
  var baseUrl = await _server();
  var url = baseUrl + "transaction_create";
  var apikey = await Prefs.paydbApiKeyGet();
  var apisecret = await Prefs.paydbApiSecretGet();
  checkApiKey(apikey, apisecret);
  var nonce = DateTime.now().toUtc().millisecondsSinceEpoch / 1000;
  var body = jsonEncode({"api_key": apikey, "nonce": nonce, "action": action, "recipient": recipient, "amount": amount, "attachment": attachment});
  var sig = createHmacSig(apisecret, body);
  var response = await postAndCatch(url, body, extraHeaders: {"X-Signature": sig});
  if (response == null)
    return PayDbTxResult(null, PayDbError.Network);
  if (response.statusCode == 200) {
    var jsnObj = json.decode(response.body);
    var tx = parseTx(jsnObj["tx"]);
    return PayDbTxResult(tx, PayDbError.None);
  } else if (response.statusCode == 400)
    return PayDbTxResult(null, PayDbError.Auth);
  print(response.statusCode);
  return PayDbTxResult(null, PayDbError.Network);
}
