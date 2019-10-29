import 'dart:math';
import 'package:decimal/decimal.dart';
import 'dart:convert' as convert;
import 'package:http/http.dart' as http;

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
      token: convert.base64Url.encode(secureRandom(count: 8)),
      secret: convert.base64Url.encode(secureRandom())
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

Future<ClaimCode> merchantRegister(Decimal amount) async {
  var claimCode = ClaimCode.generate(amount);
  var url = baseUrl + "register";
  var body = convert.jsonEncode({"token": claimCode.token});
  var response = await http.post(url, headers: {"Content-Type": "application/json"}, body: body);
  if (response.statusCode == 200) {
    return claimCode;
  }
  return null;
}

Future<String> merchantCheck(ClaimCode claimCode) async {
  var url = baseUrl + "check";
  var body = convert.jsonEncode({"token": claimCode.token});
  var response = await http.post(url, headers: {"Content-Type": "application/json"}, body: body);
  if (response.statusCode == 200) {
    return claimCode.getAddressIfJsonMatches(convert.json.decode(response.body));
  }
  return null;
}