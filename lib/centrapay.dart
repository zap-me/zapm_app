import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';

import 'package:zapdart/utils.dart';
import 'package:zapdart/libzap.dart';

import 'send_receive.dart';
import 'config.dart';

const CENTRAPAY_PAY_BASE_URI = 'http://app.centrapay.com/pay';
const CENTRAPAY_BASE_URL = 'https://service.centrapay.com';

const CentrapayRequestStatusNew = 'new';
const CentrapayPaymentMethodZapMain = 'zap.main';
const CentrapayPaymentMethodZapTest = 'zap.test';
const CentrapayPaymentMethodTestUplink = 'g.test.testUplink';

String centrapayParseQrcode(String data) {
  if (data != null && data.isNotEmpty) {
    if (data.indexOf(CENTRAPAY_PAY_BASE_URI) == 0)
      // return requestId part of url
      return data.split('/').last;
  }
  return null;
}

bool centrapayValidPaymentMethod(String method, bool testnet) {
  if (testnet && method == CentrapayPaymentMethodZapTest)
    return true;
  if (!testnet && method == CentrapayPaymentMethodZapMain)
    return true;
  if (method == CentrapayPaymentMethodTestUplink)
    return true;
  return false;
}

enum CentrapayError {
  None, Network, Auth
}

class CentrapayPayment {
  final String ledger;
  final String account;
  final double amount;

  CentrapayPayment(this.ledger, this.account, this.amount);
}

class CentrapayRequest {
  final String id;
  final String asset;
  final int amount;
  final String status;
  final Iterable<CentrapayPayment> payments;

  CentrapayRequest(this.id, this.asset, this.amount, this.status, this.payments);
}

class CentrapayRequestInfoResult {
  final CentrapayRequest request;
  final CentrapayError error;

  CentrapayRequestInfoResult(this.request, this.error);
}

class CentrapayPaymentResult {
  final String id;
  final String status;

  CentrapayPaymentResult(this.id, this.status);
}

class CentrapayRequestPayResult {
  final CentrapayPaymentResult payment;
  final CentrapayError error;

  CentrapayRequestPayResult(this.payment, this.error);
}

class CentrapayZapResult {
  final bool zapRequired;
  final Tx zapTx;
  final CentrapayRequestPayResult centrapayResult;

  CentrapayZapResult(this.zapRequired, this.zapTx, this.centrapayResult);
}

Future<http.Response> postAndCatch(String url, Map<String, dynamic> params, {bool usePost = true}) async {
  assert(CentrapayApiKey != null);
  try {
    var headers = {'x-api-key': CentrapayApiKey};
    if (usePost) {
      var body = jsonEncode(params);
      return await post(url, body, extraHeaders: headers);
    }
    else {
      var queryString = Uri(queryParameters: params).query;
      url = url + '?' + queryString;
      return await get_(url, extraHeaders: headers);
    }
  } on SocketException catch(e) {
    print(e);
    return null;
  } on TimeoutException catch(e) {
    print(e);
    return null;
  }
}

Future<CentrapayRequestInfoResult> centrapayRequestInfo(String requestId) async {
  var url = CENTRAPAY_BASE_URL + "/payments/api/requests.info";
  var params = {"requestId": requestId};
  var response = await postAndCatch(url, params, usePost: false);
  if (response == null)
    return CentrapayRequestInfoResult(null, CentrapayError.Network);
  if (response.statusCode == 200) {
    var jsnObj = json.decode(response.body);
    var id = jsnObj["requestId"];
    var asset = jsnObj["denomination"]["asset"];
    var amount = jsnObj["denomination"]["amount"];
    var status = jsnObj["status"];
    var paymentMethods = List<CentrapayPayment>();
    for (var item in jsnObj["payments"]) {
      var method = CentrapayPayment(item["ledger"], item["account"], item["amount"].toDouble());
      paymentMethods.add(method);
    }
    var req = CentrapayRequest(id, asset, amount, status, paymentMethods);
    return CentrapayRequestInfoResult(req, CentrapayError.None);
  } else if (response.statusCode == 400)
    return CentrapayRequestInfoResult(null, CentrapayError.Auth);
  print(response.statusCode);
  return CentrapayRequestInfoResult(null, CentrapayError.Network);
}

Future<CentrapayRequestPayResult> centrapayRequestPay(CentrapayRequest req, CentrapayPayment payment, String authorization) async {
  var url = CENTRAPAY_BASE_URL + "/payments/api/requests.pay";
  //TODO: use ZAP in ledger param
  var params = {"requestId": req.id, "ledger": payment.ledger, "authorization": authorization};
  var response = await postAndCatch(url, params);
  if (response == null)
    return CentrapayRequestPayResult(null, CentrapayError.Network);
  if (response.statusCode == 200) {
    var jsnObj = json.decode(response.body);
    var id = jsnObj["reference"];
    var status = jsnObj["status"];
    var req = CentrapayPaymentResult(id, status);
    return CentrapayRequestPayResult(req, CentrapayError.None);
  } else if (response.statusCode == 400)
    return CentrapayRequestPayResult(null, CentrapayError.Auth);
  print(response.statusCode);
  return CentrapayRequestPayResult(null, CentrapayError.Network);
}

Future<CentrapayZapResult> centrapayPay(BuildContext context, bool testnet, String mnemonic, Decimal fee, Decimal balance, CentrapayRequest req, CentrapayPayment payment) async {
  switch (payment.ledger) {
    case CentrapayPaymentMethodTestUplink:
      var res = await centrapayRequestPay(req, payment, DateTime.now().millisecondsSinceEpoch.toString());
      return CentrapayZapResult(false, null, res);
    case CentrapayPaymentMethodZapMain:
    case CentrapayPaymentMethodZapTest:
      var amount = Decimal.parse(payment.amount.toString());
      var wr = WavesRequest(payment.account, testnet ? AssetIdTestnet : AssetIdMainnet, amount, 'centrapay:${req.id}', NO_ERROR);
      var recipientUri = wr.toUri();
      var tx = await Navigator.push<Tx>(
          context,
          MaterialPageRoute(
              builder: (context) => SendScreen(testnet, mnemonic, fee, recipientUri, balance)),
        );
      if (tx == null)
        return CentrapayZapResult(true, null, null);
      var res = await centrapayRequestPay(req, payment, tx.id);
      return CentrapayZapResult(true, tx, res);
  }
  return CentrapayZapResult(true, null, null);
}
