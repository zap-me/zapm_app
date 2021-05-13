import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:decimal/decimal.dart';
import 'package:http/http.dart' as http;

import 'package:zapdart/utils.dart';
import 'config.dart';

Future<http.Response?> _postAndCatch(String url, String body,
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

class RRClaimCode {
  final String code;
  final Decimal amount;

  RRClaimCode(this.code, this.amount);

  static Future<RRClaimCode?> parseDeepLink(
      String content, bool testnet) async {
    // Deep link format: https://www.redrat.co.nz/zap-rebate?i={i}&h={h}
    if (testnet &&
            content.startsWith('https://redrat.blackpepper.co.nz/zap-rebate') ||
        !testnet && content.startsWith('https://www.redrat.co.nz/zap-rebate')) {
      var uri = Uri.tryParse(content);
      if (uri != null) {
        if (uri.queryParameters.containsKey('i') &&
            uri.queryParameters.containsKey('h')) {
          var i = uri.queryParameters['i']!;
          var h = uri.queryParameters['h']!;
          // get claim code data from uri
          var body = jsonEncode({"i": i, "h": h, "app": true});
          var response = await _postAndCatch(content, body);
          if (response == null) return null;
          if (response.statusCode == 200) {
            var json = jsonDecode(response.body);
            var code = json.claimcode as String;
            var amount = Decimal.parse(json.amount as String);
            return RRClaimCode(code, amount);
          }
          print(response.statusCode);
        }
      }
    }
    return null;
  }

  static RRClaimCode? parseQrCode(String content) {
    // QRcode format -  zap://rebate?claimCode=EAMT3VSBQZMC&amount=0.5998
    if (content.startsWith('zap://rebate') && content.contains('claimCode')) {
      var uri = Uri.tryParse(content);
      if (uri != null) {
        if (uri.queryParameters.containsKey('claimCode') &&
            uri.queryParameters.containsKey('amount')) {
          var code = uri.queryParameters['claimCode']!;
          var amount = Decimal.parse(uri.queryParameters['amount']!);
          return RRClaimCode(code, amount);
        }
      }
    }
    return null;
  }
}

Future<bool> rrClaim(
    RRClaimCode claimCode, bool testnet, String claimAddress) async {
  var url = testnet
      ? "https://redrat.blackpepper.co.nz/process-zap-rebate"
      : "https://www.redrat.co.nz/process-zap-rebate";
  var body = jsonEncode({
    "k": "uLKVLVX9ESF5syFp9B4pQZPBU3F84qarGkTL",
    "w": claimAddress,
    "c": claimCode.code
  });
  var response = await _postAndCatch(url, body);
  if (response == null) return false;
  if (response.statusCode == 200) return true;
  print(response.statusCode);
  return false;
}
