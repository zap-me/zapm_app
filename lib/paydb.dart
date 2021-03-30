import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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

enum PayDbPermission {
  receive, balance, history, transfer, issue
}

class PayDbUri {
  final String account;
  final Decimal amount;
  final String attachment;

  PayDbUri(this.account, this.amount, this.attachment);

  String _addPart(String current, String part) {
    if (current.isEmpty)
      return '?$part';
    return '$current&$part';
  }

  String toUri() {
    var queryParts = '';
    if (amount > Decimal.zero) {
      var amountCents = amount * Decimal.fromInt(100);
      queryParts = _addPart(queryParts, 'amount=$amountCents');
    }
    if (attachment != null && attachment.isNotEmpty)
      queryParts = _addPart(queryParts, 'attachment=$attachment');
    return 'premiopay://$account$queryParts';
  }

  static PayDbUri parse(String uri) {
    //
    // premiopay://<email>?amount=<AMOUNT_CENTS>&attachment=<ATTACHMENT>
    //
    var account = '';
    var amount = Decimal.fromInt(0);
    var attachment = '';
    if (uri.length > 12 && uri.substring(0, 12).toLowerCase() == 'premiopay://') {
      var parts = uri.substring(12).split('?');
      if (parts.length == 1 || parts.length == 2) {
        account = parts[0];
        if (account.endsWith('/'))
          account = account.substring(0, account.length - 1);
      }
      if (parts.length == 2) {
        parts = parts[1].split('&');
        for (var part in parts) {
          var res = parseUriParameter(part, 'amount');
          if (res != null) amount = Decimal.parse(res) / Decimal.fromInt(100);
          res = parseUriParameter(part, 'attachment');
          if (res != null) attachment = res;
        }
      }
      return PayDbUri(account, amount, attachment);
    }
    return null;
  }
}

class AccountRegistration {
  final String firstName;
  final String lastName;
  final String email;
  final String password;
  final String photo;
  final String photoType;

  AccountRegistration(this.firstName, this.lastName, this.email, this.password, this.photo, this.photoType);
}

class AccountRequestApiKey {
  final String email;
  final String deviceName;

  AccountRequestApiKey(this.email, this.deviceName);
}

class UserInfo {
  final String email;
  final int balance;
  final String photo;
  final String photoType;
  final Iterable<PayDbPermission> permissions;

  UserInfo(this.email, this.balance, this.photo, this.photoType, this.permissions);
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

class PayDbApiKeyRequestResult {
  final String token;
  final PayDbError error;

  PayDbApiKeyRequestResult(this.token, this.error);
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
  } on http.ClientException catch(e) {
    print(e);
    return null;
  } on ArgumentError catch(e) {
    print(e);
    return null;
  }
}

Widget paydbAccountImage(String imgString, String imgType, {double size = 70, double borderRadius = 10,
double dropShadowOffsetX = 0, double dropShadowOffsetY = 3, double dropShadowSpreadRadius = 5, double dropShadowBlurRadius = 7}) {
  if (imgString != null && imgString.isNotEmpty) {
    if (imgType == 'raster')
      // if image is raster then apply corner radius and drop shadow
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius), 
          boxShadow: [BoxShadow(
            color: Colors.grey.withOpacity(0.5),
            spreadRadius: dropShadowSpreadRadius,
            blurRadius: dropShadowBlurRadius,
            offset: Offset(dropShadowOffsetX, dropShadowOffsetY),
          )],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          //TODO: BoxFit.cover should not be necesary if the crop aspect ratio is 1/1 (*shrug*)
          child: Image.memory(base64Decode(imgString), width: size, height: size, fit: BoxFit.cover,))
      );
    if (imgType == 'svg')
      return SvgPicture.string(imgString, width: size, height: size);
  }
  return SvgPicture.asset('assets/user.svg', width: size, height: size);
}

Future<String> paydbServer() async {
  return await _server();
}

String paydbParseRecipient(String value) {
  if (EmailValidator.validate(value))
    return value;
  return null;
}

bool paydbParseValid(String recipientOrUri) {
  return (paydbParseRecipient(recipientOrUri) != null || PayDbUri.parse(recipientOrUri) != null);
}

Future<PayDbError> paydbUserRegister(AccountRegistration reg) async {
  var baseUrl = await _server();
  var url = baseUrl + "user_register";
  var body = jsonEncode({"first_name": reg.firstName, "last_name": reg.lastName, "email": reg.email, "password": reg.password, "photo": reg.photo, "photo_type": reg.photoType});
  var response = await postAndCatch(url, body);
  if (response == null)
    return PayDbError.Network;
  if (response.statusCode == 200) {
    return PayDbError.None;
  } else if (response.statusCode == 400)
    return PayDbError.Auth;
  print(response.statusCode);
  return PayDbError.Network;
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

Future<PayDbApiKeyRequestResult> paydbApiKeyRequest(String email, String deviceName) async {
  var baseUrl = await _server();
  var url = baseUrl + "api_key_request";
  var body = jsonEncode({"email": email, "device_name": deviceName});
  var response = await postAndCatch(url, body);
  if (response == null)
    return PayDbApiKeyRequestResult(null, PayDbError.Network);
  if (response.statusCode == 200) {
    var jsnObj = json.decode(response.body);
    var token = jsnObj["token"];
    return PayDbApiKeyRequestResult(token, PayDbError.None);
  } else if (response.statusCode == 400)
    return PayDbApiKeyRequestResult(null, PayDbError.Auth);
  print(response.statusCode);
  return PayDbApiKeyRequestResult(null, PayDbError.Network);
}

Future<PayDbApiKeyResult> paydbApiKeyClaim(String token) async {
  var baseUrl = await _server();
  var url = baseUrl + "api_key_claim";
  var body = jsonEncode({"token": token});
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

Future<UserInfoResult> paydbUserInfo({String email}) async {
  var baseUrl = await _server();
  var url = baseUrl + "user_info";
  var apikey = await Prefs.paydbApiKeyGet();
  var apisecret = await Prefs.paydbApiSecretGet();
  checkApiKey(apikey, apisecret);
  var nonce = DateTime.now().toUtc().millisecondsSinceEpoch / 1000;
  var body = jsonEncode({"api_key": apikey, "nonce": nonce, "email": email});
  var sig = createHmacSig(apisecret, body);
  var response = await postAndCatch(url, body, extraHeaders: {"X-Signature": sig});
  if (response == null)
    return UserInfoResult(null, PayDbError.Network);
  if (response.statusCode == 200) {
    var jsnObj = json.decode(response.body);
    var perms = List<PayDbPermission>();
    for (var permName in jsnObj["permissions"])
      for (var perm in PayDbPermission.values)
        if (describeEnum(perm) == permName) 
          perms.add(perm);
    var info = UserInfo(jsnObj["email"], jsnObj["balance"], jsnObj["photo"], jsnObj["photo_type"], perms);
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
