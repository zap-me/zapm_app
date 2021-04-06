import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';

import 'package:zapdart/utils.dart';
import 'package:zapdart/libzap.dart';
import 'package:zapdart/widgets.dart';
import 'package:zapdart/colors.dart';

import 'send_receive.dart';
import 'config.dart';

const CENTRAPAY_QR_BASE_URI = 'https://app.centrapay.com/pay';
const CENTRAPAY_DEV_QR_BASE_URI = 'https://app.cp42.click/pay';
const CENTRAPAY_BASE_URL = 'https://service.centrapay.com';
const CENTRAPAY_DEV_BASE_URL = 'https://service.cp42.click';

const CentrapayRequestStatusNew = 'new';
const CentrapayPaymentMethodZapMain = 'zap.main';
const CentrapayPaymentMethodZapTest = 'zap.test'; // TODO: doesnt exist, yet?
const CentrapayPaymentMethodTestUplink = 'g.test.testUplink';

class CentrapayQr {
  final String reqId;
  final String baseUrl;

  CentrapayQr(this.reqId, this.baseUrl);
}

CentrapayQr centrapayParseQrcode(String data) {
  if (data != null && data.isNotEmpty) {
    if (data.indexOf(CENTRAPAY_QR_BASE_URI) == 0)
      // return requestId part of url
      return CentrapayQr(data.split('/').last, CENTRAPAY_BASE_URL);
    if (data.indexOf(CENTRAPAY_DEV_QR_BASE_URI) == 0)
      // return requestId part of url
      return CentrapayQr(data.split('/').last, CENTRAPAY_DEV_BASE_URL);
  }
  return null;
}

bool centrapayValidPaymentMethod(String method, bool testnet) {
  if (testnet && method == CentrapayPaymentMethodZapTest) return true;
  if (!testnet && method == CentrapayPaymentMethodZapMain) return true;
  if (method == CentrapayPaymentMethodTestUplink) return true;
  return false;
}

enum CentrapayError { None, Network, Auth }

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

  CentrapayRequest(
      this.id, this.asset, this.amount, this.status, this.payments);
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

Future<http.Response> postAndCatch(String url, Map<String, dynamic> params,
    {bool usePost = true}) async {
  assert(CentrapayApiKey != null);
  try {
    var headers = {'x-api-key': CentrapayApiKey};
    if (usePost) {
      print(':: centrapay endpoint: $url');
      print('   data: $params');
      return await post(url, params,
          contentType: 'application/x-www-form-urlencoded',
          extraHeaders: headers);
    } else {
      var queryString = Uri(queryParameters: params).query;
      url = url + '?' + queryString;
      print(':: centrapay endpoint: $url');
      return await get_(url, extraHeaders: headers);
    }
  } on SocketException catch (e) {
    print(e);
    return null;
  } on TimeoutException catch (e) {
    print(e);
    return null;
  }
}

Future<CentrapayRequestInfoResult> centrapayRequestInfo(CentrapayQr qr) async {
  var url = qr.baseUrl + "/payments/api/requests.info";
  var params = {"requestId": qr.reqId};
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
      var method = CentrapayPayment(
          item["ledger"], item["account"], item["amount"].toDouble());
      paymentMethods.add(method);
    }
    var req = CentrapayRequest(id, asset, amount, status, paymentMethods);
    return CentrapayRequestInfoResult(req, CentrapayError.None);
  } else if (response.statusCode == 400)
    return CentrapayRequestInfoResult(null, CentrapayError.Auth);
  print(response.statusCode);
  return CentrapayRequestInfoResult(null, CentrapayError.Network);
}

Future<CentrapayRequestPayResult> centrapayRequestPay(
    CentrapayQr qr,
    CentrapayRequest req,
    CentrapayPayment payment,
    String authorization) async {
  var url = qr.baseUrl + "/payments/api/requests.pay";
  var params = {
    "requestId": req.id,
    "ledger": payment.ledger,
    "authorization": authorization
  };
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

class CentrapayScreen extends StatefulWidget {
  final bool _testnet;
  final String _seed;
  final Decimal _fee;
  final Decimal _max;
  final CentrapayQr _qr;

  CentrapayScreen(this._testnet, this._seed, this._fee, this._max, this._qr)
      : super();

  @override
  CentrapayScreenState createState() {
    return CentrapayScreenState();
  }
}

class CentrapayScreenState extends State<CentrapayScreen> {
  bool _loading = false;
  String _msg;
  CentrapayRequest _req;
  CentrapayPayment _payment;
  Tx _zapTx;
  bool _confirmed = false;

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) => start());
    super.initState();
  }

  void start() async {
    setState(() {
      _loading = true;
      _msg = 'getting centrapay request details..';
    });
    var result = await centrapayRequestInfo(widget._qr);
    _msg = '';
    if (result.error == CentrapayError.None) {
      if (result.request.status == CentrapayRequestStatusNew) {
        _req = result.request;
        for (var item in result.request.payments)
          if (centrapayValidPaymentMethod(item.ledger, widget._testnet)) {
            setState(() {
              _loading = false;
              _payment = item;
            });
            return;
          }
        _msg = 'no compatible centrapay payment method found';
        flushbarMsg(context, _msg, category: MessageCategory.Warning);
      } else {
        _msg = 'centrapay request status: ${result.request.status}';
        flushbarMsg(context, _msg, category: MessageCategory.Warning);
      }
    } else {
      _msg = 'centrapay request info failed';
      flushbarMsg(context, _msg, category: MessageCategory.Warning);
    }
    setState(() {
      _loading = false;
    });
  }

  String paymentAmount(CentrapayPayment payment) {
    if (payment == null) return '0';
    return (payment.amount / 100).toStringAsFixed(2);
  }

  String paymentUnit(CentrapayPayment payment) {
    switch (payment?.ledger) {
      case CentrapayPaymentMethodZapMain:
      case CentrapayPaymentMethodZapTest:
        return 'ZAP';
      case CentrapayPaymentMethodTestUplink:
        return 'TestUplink';
    }
    return 'UNKNOWN';
  }

  Future<CentrapayZapResult> payZapAndConfirm(
      CentrapayRequest req, CentrapayPayment payment) async {
    switch (payment.ledger) {
      case CentrapayPaymentMethodTestUplink:
        var res = await centrapayRequestPay(widget._qr, req, payment,
            DateTime.now().millisecondsSinceEpoch.toString());
        return CentrapayZapResult(false, null, res);
      case CentrapayPaymentMethodZapMain:
      case CentrapayPaymentMethodZapTest:
        var amount = Decimal.parse(payment.amount.toString());
        var wr = WavesRequest(payment.account, LibZap().assetIdGet(), amount,
            '{"centrapay":"${req.id}"}', NO_ERROR);
        var recipientUri = wr.toUri();
        var tx = await Navigator.push<Tx>(
          context,
          MaterialPageRoute(
              builder: (context) => SendScreen(widget._testnet, widget._seed,
                  widget._fee, recipientUri, widget._max)),
        );
        if (tx == null) return CentrapayZapResult(true, null, null);
        var res = await centrapayRequestPay(widget._qr, req, payment, tx.id);
        return CentrapayZapResult(true, tx, res);
    }
    return CentrapayZapResult(
        true, null, CentrapayRequestPayResult(null, CentrapayError.None));
  }

  void payConfirm() async {
    setState(() {
      _loading = true;
      _msg = 'confirming payment..';
    });
    var res = await centrapayRequestPay(widget._qr, _req, _payment, _zapTx.id);
    switch (res.error) {
      case CentrapayError.None:
        _msg = 'completed centrapay payment';
        _confirmed = true;
        flushbarMsg(context, _msg);
        break;
      case CentrapayError.Auth:
      case CentrapayError.Network:
        _msg = 'failed to update centrapay payment';
        flushbarMsg(context, _msg, category: MessageCategory.Warning);
        break;
    }
    setState(() {
      _loading = false;
    });
  }

  void pay() async {
    setState(() {
      _loading = true;
      _msg = 'paying request..';
    });
    var res = await payZapAndConfirm(_req, _payment);
    _msg = '';
    if (res.zapRequired && res.zapTx == null) {
      _msg = 'failed to send zap';
      flushbarMsg(context, _msg, category: MessageCategory.Warning);
    } else
      _zapTx = res.zapTx;
    switch (res.centrapayResult.error) {
      case CentrapayError.None:
        _msg = 'completed centrapay payment';
        _confirmed = true;
        flushbarMsg(context, _msg);
        break;
      case CentrapayError.Auth:
      case CentrapayError.Network:
        _msg = 'failed to update centrapay payment';
        flushbarMsg(context, _msg, category: MessageCategory.Warning);
        break;
    }
    setState(() {
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          leading: backButton(context),
          title: Text('centrapay request', style: TextStyle(color: ZapWhite)),
          backgroundColor: ZapYellow,
        ),
        body: CustomPaint(
            painter: CustomCurve(ZapYellow, 110, 170),
            child: Container(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                padding: EdgeInsets.all(20),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Visibility(
                        visible: _loading,
                        child: CircularProgressIndicator(),
                      ),
                      Visibility(
                          visible: _loading,
                          child: Container(
                              padding: const EdgeInsets.only(top: 20.0))),
                      Visibility(
                        visible: _msg != null && _msg.isNotEmpty,
                        child: Text("$_msg"),
                      ),
                      Visibility(
                        visible: _payment != null,
                        child: Text(
                            "${paymentAmount(_payment)} ${paymentUnit(_payment)}",
                            style: TextStyle(color: ZapBlue)),
                      ),
                      Visibility(
                        visible: !_loading &&
                            !_confirmed &&
                            _payment != null &&
                            _zapTx == null,
                        child: RoundedButton(pay, ZapWhite, ZapYellow, 'pay',
                            minWidth: MediaQuery.of(context).size.width / 2,
                            holePunch: true),
                      ),
                      Visibility(
                        visible: !_loading && !_confirmed && _zapTx != null,
                        child: RoundedButton(payConfirm, ZapWhite, ZapYellow,
                            'reconfirm payment',
                            minWidth: MediaQuery.of(context).size.width / 2,
                            holePunch: true),
                      ),
                      Visibility(
                          visible: !_loading,
                          child: RoundedButton(
                              () => Navigator.pop(context, _zapTx),
                              ZapBlue,
                              ZapWhite,
                              'close',
                              borderColor: ZapBlue,
                              minWidth: MediaQuery.of(context).size.width / 2)),
                    ]))));
  }
}
