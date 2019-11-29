import 'dart:math';
import 'package:decimal/decimal.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';

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
      token: base64Url.encode(secureRandom(count: 8)),
      secret: base64Url.encode(secureRandom())
    );
  }
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

Future<ClaimCode> merchantRegister(Decimal amount) async {
  var claimCode = ClaimCode.generate(amount);
  var url = baseUrl + "register";
  var apikey = await Prefs.apikeyGet();
  var apisecret = await Prefs.apisecretGet();
  var nonce = DateTime.now().toUtc().millisecondsSinceEpoch / 1000;
  var body = jsonEncode({"api_key": apikey, "nonce": nonce, "token": claimCode.token});
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