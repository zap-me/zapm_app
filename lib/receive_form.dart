import 'dart:async';
import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';

import 'package:zapdart/qrwidget.dart';
import 'package:zapdart/libzap.dart';
import 'package:zapdart/widgets.dart';
import 'package:zapdart/colors.dart';

import 'config.dart';
import 'prefs.dart';
import 'hmac.dart';
import 'merchant.dart';
import 'paydb.dart';

typedef TxNotificationCallback = void Function(String txid, String sender,
    String recipient, double amount, String? attachment);

class ReceiveForm extends StatefulWidget {
  final bool _testnet;
  final String _addressOrAccount;
  final TxNotificationCallback _txNotification;

  ReceiveForm(this._testnet, this._addressOrAccount, this._txNotification)
      : super();

  @override
  ReceiveFormState createState() {
    return ReceiveFormState();
  }
}

const String API_LOADING = '...';
const String API_FAILED = 'API failed';
const String NO_API_KEY = 'no API KEY';

class ReceiveFormState extends State<ReceiveForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _uriController = TextEditingController();
  String? _uri;
  String _amountType = UseMerchantApi ? 'nzd' : AssetShortNameLower;
  bool _validAmount = true;
  StreamSubscription<String>? _uriSub;
  List<String> _receivedTxs = <String>[];
  Timer? _checkReceivedTxTimer;
  final int _initialTimestamp =
      (DateTime.now().millisecondsSinceEpoch / 1000).round();

  bool validQrData() {
    return _uri != null &&
        _uri != API_LOADING &&
        _uri != API_FAILED &&
        _uri != NO_API_KEY;
  }

  Future<String> makeUri() async {
    var amount = Decimal.fromInt(0);
    try {
      amount = Decimal.parse(_amountController.text);
    } catch (e) {}
    if (_amountType == 'nzd') {
      ZapCalcResult res;
      try {
        res = await merchantZapCalc(amount);
      } on NoApiKeyException {
        return NO_API_KEY;
      }
      if (res.error != null) {
        return API_FAILED;
      }
      if (res.zap != null) amount = res.zap!;
    }
    switch (AppTokenType) {
      case TokenType.Waves:
        var deviceName = await Prefs.deviceNameGet();
        return LibZap.paymentUriDec(
            widget._testnet, widget._addressOrAccount, amount, deviceName);
      case TokenType.PayDB:
        return PayDbUri(widget._addressOrAccount, amount, null).toUri();
    }
  }

  void updateUriUi() {
    setState(() {
      _uri = API_LOADING;
      _uriController.text = _uri!;
    });

    _uriSub?.cancel();
    _uriSub = makeUri().asStream().listen((uri) {
      setState(() {
        _uri = uri;
        _uriController.text = uri;
      });
    });
  }

  void onAmountChanged() {
    updateUriUi();
  }

  Future<bool> canLeave() {
    _uriSub?.cancel();
    return Future<bool>.value(true);
  }

  void onCheckReceivedTxTimeout(Timer timer) async {
    switch (AppTokenType) {
      case TokenType.Waves:
        break;
      case TokenType.PayDB:
        var res = await paydbUserTransactions(0, 10);
        if (res.error == PayDbError.None && res.txs != null) {
          for (var tx in res.txs!) {
            if (_receivedTxs.contains(tx.token)) continue;
            if (tx.action != ActionTransfer) continue;
            if (tx.timestamp < _initialTimestamp) continue;
            widget._txNotification(tx.token, tx.sender, tx.recipient,
                tx.amount / 100.0, tx.attachment);
            _receivedTxs.add(tx.token);
          }
        }
        break;
    }
  }

  ReceiveFormState() : super() {
    _amountController.addListener(onAmountChanged);
  }

  @protected
  @mustCallSuper
  void initState() {
    super.initState();
    updateUriUi();
    _checkReceivedTxTimer =
        Timer.periodic(Duration(seconds: 2), onCheckReceivedTxTimeout);
  }

  @protected
  @mustCallSuper
  void dispose() {
    super.dispose();
    _checkReceivedTxTimer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      child: SingleChildScrollView(
          child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Center(
                heightFactor: 5,
                child: Text('scan QR code',
                    style:
                        TextStyle(color: ZapWhite, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center)),
            Center(
                child: Card(
                    margin: EdgeInsets.all(20),
                    child: validQrData() && _validAmount && _uri != null
                        ? QrWidget(_uri!, size: 240, version: 10)
                        : Container(
                            width: 240,
                            height: 240,
                            padding: EdgeInsets.all(100),
                            child: CircularProgressIndicator()))),
            TextFormField(
              controller: _uriController,
              enabled: false,
              decoration: InputDecoration(labelText: 'receive URI'),
              maxLines: 4,
              style: TextStyle(fontSize: 12),
            ),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                  labelText: 'amount',
                  suffixIcon: flatButton(
                      onPressed: () {
                        if (!UseMerchantApi) return;
                        setState(() {
                          if (_amountType == AssetShortNameLower)
                            _amountType = 'nzd';
                          else
                            _amountType = AssetShortNameLower;
                        });
                        updateUriUi();
                      },
                      child: Text(_amountType,
                          style: TextStyle(color: ZapGreen)))),
              style: _validAmount ? null : TextStyle(color: ZapRed),
              validator: (value) {
                if (value != null && value.isEmpty) {
                  return 'Please enter a value';
                }
                final dv = Decimal.parse(value!);
                if (dv <= Decimal.fromInt(0)) {
                  return 'Please enter a value greater then zero';
                }
                return null;
              },
              onChanged: (value) {
                if (value.isEmpty) {
                  setState(() {
                    _validAmount = true;
                  });
                } else {
                  var valid = Decimal.tryParse(value) != null;
                  setState(() {
                    _validAmount = valid;
                  });
                }
              },
            ),
            Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: RoundedButton(
                  () => Navigator.pop(context), ZapBlue, ZapWhite, 'cancel',
                  borderColor: ZapBlue,
                  minWidth: MediaQuery.of(context).size.width / 2),
            ),
          ],
        ),
      )),
      onWillPop: canLeave,
    );
  }
}
