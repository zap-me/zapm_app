import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:decimal/decimal.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:zapdart/utils.dart';
import 'package:zapdart/hmac.dart';
import 'package:zapdart/account_forms.dart';

import 'config.dart';
import 'prefs.dart';

Future<String?> _server() async {
  var testnet = await Prefs.testnetGet();
  return testnet ? PayDBServerTestnet : PayDBServerMainnet;
}

const ActionIssue = 'issue';
const ActionTransfer = 'transfer';
const ActionDestroy = 'destroy';

enum PayDbError { None, Network, Auth }

enum PayDbPermission { receive, balance, history, transfer, issue }
enum PayDbRole { admin, proposer, authorizer }

class PayDbUri {
  final String account;
  final Decimal amount;
  final String? attachment;

  PayDbUri(this.account, this.amount, this.attachment);

  String _addPart(String current, String part) {
    if (current.isEmpty) return '?$part';
    return '$current&$part';
  }

  String toUri() {
    var queryParts = '';
    if (amount > Decimal.zero) {
      var amountCents = amount * Decimal.fromInt(100);
      queryParts = _addPart(queryParts, 'amount=$amountCents');
    }
    if (attachment != null && attachment!.isNotEmpty)
      queryParts = _addPart(queryParts, 'attachment=$attachment');
    return '$PremioPayPrefix$account$queryParts';
  }

  static PayDbUri? parse(String uri) {
    //
    // <PremioPayScheme>://<email>?amount=<AMOUNT_CENTS>&attachment=<ATTACHMENT>
    //
    var account = '';
    var amount = Decimal.fromInt(0);
    var attachment = '';
    if (uri.length > PremioPayPrefix.length &&
        uri.substring(0, PremioPayPrefix.length).toLowerCase() ==
            PremioPayPrefix) {
      var parts = uri.substring(PremioPayPrefix.length).split('?');
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

class UserInfo {
  final String email;
  final int balance;
  final String? photo;
  final String? photoType;
  final Iterable<PayDbPermission> permissions;
  final Iterable<PayDbRole> roles;

  UserInfo(this.email, this.balance, this.photo, this.photoType,
      this.permissions, this.roles);
}

class UserInfoResult {
  final UserInfo? info;
  final PayDbError error;

  UserInfoResult(this.info, this.error);
}

class PayDbApiKey {
  final String token;
  final String secret;

  PayDbApiKey(this.token, this.secret);
}

class PayDbApiKeyResult {
  final PayDbApiKey? apikey;
  final PayDbError error;

  PayDbApiKeyResult(this.apikey, this.error);
}

class PayDbApiKeyRequestResult {
  final String? token;
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
  final String? attachment;

  PayDbTx(this.token, this.action, this.timestamp, this.sender, this.recipient,
      this.amount, this.attachment);
}

class PayDbUserTxsResult {
  final Iterable<PayDbTx>? txs;
  final PayDbError error;

  PayDbUserTxsResult(this.txs, this.error);
}

class PayDbTxResult {
  final PayDbTx? tx;
  final PayDbError error;

  PayDbTxResult(this.tx, this.error);
}

class PayDbRewardCategoriesResult {
  final List<String> categories;
  final PayDbError error;

  PayDbRewardCategoriesResult(this.categories, this.error);
}

Future<http.Response?> postAndCatch(String url, String body,
    {Map<String, String>? extraHeaders}) async {
  try {
    return await httpPost(Uri.parse(url), body, extraHeaders: extraHeaders);
  } on SocketException catch (e) {
    print(e);
    return null;
  } on TimeoutException catch (e) {
    print(e);
    return null;
  } on http.ClientException catch (e) {
    print(e);
    return null;
  } on ArgumentError catch (e) {
    print(e);
    return null;
  } on HandshakeException catch (e) {
    print(e);
    return null;
  }
}

Widget paydbAccountImage(String? imgString, String? imgType,
    {double size = 70,
    double borderRadius = 10,
    double dropShadowOffsetX = 0,
    double dropShadowOffsetY = 3,
    double dropShadowSpreadRadius = 5,
    double dropShadowBlurRadius = 7}) {
  if (imgString != null && imgString.isNotEmpty) {
    if (imgType == 'raster')
      // if image is raster then apply corner radius and drop shadow
      return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.5),
                spreadRadius: dropShadowSpreadRadius,
                blurRadius: dropShadowBlurRadius,
                offset: Offset(dropShadowOffsetX, dropShadowOffsetY),
              )
            ],
          ),
          child: ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              //TODO: BoxFit.cover should not be necesary if the crop aspect ratio is 1/1 (*shrug*)
              child: Image.memory(
                base64Decode(imgString),
                width: size,
                height: size,
                fit: BoxFit.cover,
              )));
    if (imgType == 'svg')
      return SvgPicture.string(imgString, width: size, height: size);
  }
  return SvgPicture.asset('assets/user.svg', width: size, height: size);
}

Future<String?> paydbServer() async {
  return await _server();
}

String? paydbParseRecipient(String value) {
  if (EmailValidator.validate(value)) return value;
  return null;
}

bool paydbParseValid(String recipientOrUri) {
  return (paydbParseRecipient(recipientOrUri) != null ||
      PayDbUri.parse(recipientOrUri) != null);
}

Future<PayDbError> paydbUserRegister(AccountRegistration reg) async {
  var baseUrl = await _server();
  if (baseUrl == null) return PayDbError.Network;
  var url = baseUrl + "user_register";
  var body = jsonEncode({
    "first_name": reg.firstName,
    "last_name": reg.lastName,
    "email": reg.email,
    "mobile_number": reg.mobileNumber,
    "address": reg.address,
    "password": reg.newPassword,
    "photo": reg.photo,
    "photo_type": reg.photoType
  });
  var response = await postAndCatch(url, body);
  if (response == null) return PayDbError.Network;
  if (response.statusCode == 200) {
    return PayDbError.None;
  } else if (response.statusCode == 400) return PayDbError.Auth;
  print(response.statusCode);
  return PayDbError.Network;
}

Future<PayDbApiKeyResult> paydbApiKeyCreate(
    String email, String password, String deviceName) async {
  var baseUrl = await _server();
  if (baseUrl == null) return PayDbApiKeyResult(null, PayDbError.Network);
  var url = baseUrl + "api_key_create";
  var body = jsonEncode(
      {"email": email, "password": password, "device_name": deviceName});
  var response = await postAndCatch(url, body);
  if (response == null) return PayDbApiKeyResult(null, PayDbError.Network);
  if (response.statusCode == 200) {
    var jsnObj = json.decode(response.body);
    var info = PayDbApiKey(jsnObj["token"], jsnObj["secret"]);
    return PayDbApiKeyResult(info, PayDbError.None);
  } else if (response.statusCode == 400)
    return PayDbApiKeyResult(null, PayDbError.Auth);
  print(response.statusCode);
  return PayDbApiKeyResult(null, PayDbError.Network);
}

Future<PayDbApiKeyRequestResult> paydbApiKeyRequest(
    String email, String deviceName) async {
  var baseUrl = await _server();
  if (baseUrl == null)
    return PayDbApiKeyRequestResult(null, PayDbError.Network);
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
  if (baseUrl == null) return PayDbApiKeyResult(null, PayDbError.Network);
  var url = baseUrl + "api_key_claim";
  var body = jsonEncode({"token": token});
  var response = await postAndCatch(url, body);
  if (response == null) return PayDbApiKeyResult(null, PayDbError.Network);
  if (response.statusCode == 200) {
    var jsnObj = json.decode(response.body);
    var info = PayDbApiKey(jsnObj["token"], jsnObj["secret"]);
    return PayDbApiKeyResult(info, PayDbError.None);
  } else if (response.statusCode == 400)
    return PayDbApiKeyResult(null, PayDbError.Auth);
  print(response.statusCode);
  return PayDbApiKeyResult(null, PayDbError.Network);
}

Future<UserInfoResult> paydbUserInfo({String? email}) async {
  var baseUrl = await _server();
  if (baseUrl == null) return UserInfoResult(null, PayDbError.Network);
  var url = baseUrl + "user_info";
  var apikey = await Prefs.paydbApiKeyGet();
  var apisecret = await Prefs.paydbApiSecretGet();
  checkApiKey(apikey, apisecret);
  var nonce = DateTime.now().toUtc().millisecondsSinceEpoch;
  var body = jsonEncode({"api_key": apikey, "nonce": nonce, "email": email});
  var sig = createHmacSig(apisecret!, body);
  var response =
      await postAndCatch(url, body, extraHeaders: {"X-Signature": sig});
  if (response == null) return UserInfoResult(null, PayDbError.Network);
  if (response.statusCode == 200) {
    var jsnObj = json.decode(response.body);
    var perms = <PayDbPermission>[];
    for (var permName in jsnObj["permissions"])
      for (var perm in PayDbPermission.values)
        if (describeEnum(perm) == permName) perms.add(perm);
    var roles = <PayDbRole>[];
    for (var roleName in jsnObj["roles"])
      for (var role in PayDbRole.values)
        if (describeEnum(role) == roleName) roles.add(role);
    var info = UserInfo(jsnObj["email"], jsnObj["balance"], jsnObj["photo"],
        jsnObj["photo_type"], perms, roles);
    return UserInfoResult(info, PayDbError.None);
  } else if (response.statusCode == 400)
    return UserInfoResult(null, PayDbError.Auth);
  print(response.statusCode);
  return UserInfoResult(null, PayDbError.Network);
}

Future<PayDbError> paydbUserResetPassword() async {
  var baseUrl = await _server();
  if (baseUrl == null) return PayDbError.Network;
  var url = baseUrl + "user_reset_password";
  var apikey = await Prefs.paydbApiKeyGet();
  var apisecret = await Prefs.paydbApiSecretGet();
  checkApiKey(apikey, apisecret);
  var nonce = DateTime.now().toUtc().millisecondsSinceEpoch;
  var body = jsonEncode({"api_key": apikey, "nonce": nonce});
  var sig = createHmacSig(apisecret!, body);
  var response =
      await postAndCatch(url, body, extraHeaders: {"X-Signature": sig});
  if (response == null) return PayDbError.Network;
  if (response.statusCode == 200) {
    return PayDbError.None;
  } else if (response.statusCode == 400) return PayDbError.Auth;
  print(response.statusCode);
  return PayDbError.Network;
}

Future<PayDbError> paydbUserUpdateEmail(String email) async {
  var baseUrl = await _server();
  if (baseUrl == null) return PayDbError.Network;
  var url = baseUrl + "user_update_email";
  var apikey = await Prefs.paydbApiKeyGet();
  var apisecret = await Prefs.paydbApiSecretGet();
  checkApiKey(apikey, apisecret);
  var nonce = DateTime.now().toUtc().millisecondsSinceEpoch;
  var body = jsonEncode({"api_key": apikey, "nonce": nonce, "email": email});
  var sig = createHmacSig(apisecret!, body);
  var response =
      await postAndCatch(url, body, extraHeaders: {"X-Signature": sig});
  if (response == null) return PayDbError.Network;
  if (response.statusCode == 200) {
    return PayDbError.None;
  } else if (response.statusCode == 400) return PayDbError.Auth;
  print(response.statusCode);
  return PayDbError.Network;
}

Future<PayDbError> paydbUserUpdatePassword(
    String currentPassword, String newPassword) async {
  var baseUrl = await _server();
  if (baseUrl == null) return PayDbError.Network;
  var url = baseUrl + "user_update_password";
  var apikey = await Prefs.paydbApiKeyGet();
  var apisecret = await Prefs.paydbApiSecretGet();
  checkApiKey(apikey, apisecret);
  var nonce = DateTime.now().toUtc().millisecondsSinceEpoch;
  var body = jsonEncode({
    "api_key": apikey,
    "nonce": nonce,
    "current_password": currentPassword,
    "new_password": newPassword
  });
  var sig = createHmacSig(apisecret!, body);
  var response =
      await postAndCatch(url, body, extraHeaders: {"X-Signature": sig});
  if (response == null) return PayDbError.Network;
  if (response.statusCode == 200) {
    return PayDbError.None;
  } else if (response.statusCode == 400) return PayDbError.Auth;
  print(response.statusCode);
  return PayDbError.Network;
}

Future<PayDbError> paydbUserUpdatePhoto(
    String? photo, String? photoType) async {
  var baseUrl = await _server();
  if (baseUrl == null) return PayDbError.Network;
  var url = baseUrl + "user_update_photo";
  var apikey = await Prefs.paydbApiKeyGet();
  var apisecret = await Prefs.paydbApiSecretGet();
  checkApiKey(apikey, apisecret);
  var nonce = DateTime.now().toUtc().millisecondsSinceEpoch;
  var body = jsonEncode({
    "api_key": apikey,
    "nonce": nonce,
    "photo": photo,
    "photo_type": photoType
  });
  var sig = createHmacSig(apisecret!, body);
  var response =
      await postAndCatch(url, body, extraHeaders: {"X-Signature": sig});
  if (response == null) return PayDbError.Network;
  if (response.statusCode == 200) {
    return PayDbError.None;
  } else if (response.statusCode == 400) return PayDbError.Auth;
  print(response.statusCode);
  return PayDbError.Network;
}

PayDbTx parseTx(dynamic jsn) {
  var timestamp = 0;
  if (jsn["timestamp"] != null) timestamp = jsn["timestamp"];
  var amount = 0;
  if (jsn["amount"] != null) amount = jsn["amount"];
  return PayDbTx(jsn["token"], jsn["action"], timestamp, jsn["sender"],
      jsn["recipient"], amount, jsn["attachment"]);
}

Future<PayDbUserTxsResult> paydbUserTransactions(int offset, int limit) async {
  var baseUrl = await _server();
  if (baseUrl == null) return PayDbUserTxsResult(null, PayDbError.Network);
  var url = baseUrl + "user_transactions";
  var apikey = await Prefs.paydbApiKeyGet();
  var apisecret = await Prefs.paydbApiSecretGet();
  checkApiKey(apikey, apisecret);
  var nonce = DateTime.now().toUtc().millisecondsSinceEpoch;
  var body = jsonEncode(
      {"api_key": apikey, "nonce": nonce, "offset": offset, "limit": limit});
  var sig = createHmacSig(apisecret!, body);
  var response =
      await postAndCatch(url, body, extraHeaders: {"X-Signature": sig});
  if (response == null) return PayDbUserTxsResult(null, PayDbError.Network);
  if (response.statusCode == 200) {
    var jsnObj = json.decode(response.body);
    var txs = <PayDbTx>[];
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

Future<PayDbTxResult> paydbTransactionCreate(
    String action, String recipient, int amount, String? attachment) async {
  var baseUrl = await _server();
  if (baseUrl == null) return PayDbTxResult(null, PayDbError.Network);
  var url = baseUrl + "transaction_create";
  var apikey = await Prefs.paydbApiKeyGet();
  var apisecret = await Prefs.paydbApiSecretGet();
  checkApiKey(apikey, apisecret);
  var nonce = DateTime.now().toUtc().millisecondsSinceEpoch;
  var body = jsonEncode({
    "api_key": apikey,
    "nonce": nonce,
    "action": action,
    "recipient": recipient,
    "amount": amount,
    "attachment": attachment
  });
  var sig = createHmacSig(apisecret!, body);
  var response =
      await postAndCatch(url, body, extraHeaders: {"X-Signature": sig});
  if (response == null) return PayDbTxResult(null, PayDbError.Network);
  if (response.statusCode == 200) {
    var jsnObj = json.decode(response.body);
    var tx = parseTx(jsnObj["tx"]);
    return PayDbTxResult(tx, PayDbError.None);
  } else if (response.statusCode == 400)
    return PayDbTxResult(null, PayDbError.Auth);
  print(response.statusCode);
  return PayDbTxResult(null, PayDbError.Network);
}

Future<PayDbRewardCategoriesResult> paydbRewardCategories() async {
  var categories = <String>[];
  var baseUrl = await _server();
  if (baseUrl == null)
    return PayDbRewardCategoriesResult(categories, PayDbError.Network);
  var url = baseUrl.replaceFirst('/paydb/', '/reward/') +
      'reward_categories'; //TODO: hacky url fiddling
  var apikey = await Prefs.paydbApiKeyGet();
  var apisecret = await Prefs.paydbApiSecretGet();
  checkApiKey(apikey, apisecret);
  var nonce = DateTime.now().toUtc().millisecondsSinceEpoch;
  var body = jsonEncode({
    "api_key": apikey,
    "nonce": nonce,
  });
  var sig = createHmacSig(apisecret!, body);
  var response =
      await postAndCatch(url, body, extraHeaders: {"X-Signature": sig});
  if (response == null)
    return PayDbRewardCategoriesResult(categories, PayDbError.Network);
  if (response.statusCode == 200) {
    var jsnObj = json.decode(response.body);
    categories = jsnObj["categories"].map<String>((e) => e as String).toList();
    return PayDbRewardCategoriesResult(categories, PayDbError.None);
  } else if (response.statusCode == 400)
    return PayDbRewardCategoriesResult(categories, PayDbError.Auth);
  print(response.statusCode);
  return PayDbRewardCategoriesResult(categories, PayDbError.Network);
}

Future<PayDbError> paydbRewardCreate(String reason, String category,
    String recipient, int amount, String? message) async {
  var baseUrl = await _server();
  if (baseUrl == null) return PayDbError.Network;
  var url = baseUrl.replaceFirst('/paydb/', '/reward/') +
      'reward_create'; //TODO: hacky url fiddling
  var apikey = await Prefs.paydbApiKeyGet();
  var apisecret = await Prefs.paydbApiSecretGet();
  checkApiKey(apikey, apisecret);
  var nonce = DateTime.now().toUtc().millisecondsSinceEpoch;
  var body = jsonEncode({
    "api_key": apikey,
    "nonce": nonce,
    "reason": reason,
    "category": category,
    "recipient": recipient,
    "amount": amount,
    "message": message
  });
  var sig = createHmacSig(apisecret!, body);
  var response =
      await postAndCatch(url, body, extraHeaders: {"X-Signature": sig});
  if (response == null) return PayDbError.Network;
  if (response.statusCode == 200) {
    return PayDbError.None;
  } else if (response.statusCode == 400) return PayDbError.Auth;
  print(response.statusCode);
  return PayDbError.Network;
}
