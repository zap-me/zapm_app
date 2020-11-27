import 'dart:async';
import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';

import 'zapdart/libzap.dart';
import 'zapdart/qrwidget.dart';
import 'merchant.dart';
import 'sending_form.dart';
import 'zapdart/widgets.dart';
import 'zapdart/utils.dart';
import 'prefs.dart';

class ClaimingForm extends StatefulWidget {
  final Decimal _amountDec;
  final String _seed;
  final int _amount;
  final int _fee;
  final String _msg;

  ClaimingForm(this._amountDec, this._seed, this._amount, this._fee, this._msg) : super();

  @override
  ClaimingFormState createState() {
    return ClaimingFormState();
  }
}

class ClaimingFormState extends State<ClaimingForm> {
  bool _init = false;
  bool _checking = true;
  bool _sentFunds = false;
  String _uri;
  Timer _timer;
  ClaimCode _claimCode = ClaimCode(amount: Decimal.fromInt(0), token: "", secret: "");

  Future check(Timer timer) async {
    if (!_checking || !_init)
      return;
    var addr = await merchantCheck(_claimCode);
    if (addr != null) {
      _timer.cancel();
      setState(() {
       _checking = false; 
      });
      var libzap = LibZap();
      var deviceName = await Prefs.deviceNameGet();
      var attachment = formatAttachment(deviceName, widget._msg, 'reward');
      var spendTx = libzap.transactionCreate(widget._seed, addr, widget._amount, widget._fee, attachment);
      if (spendTx.success) {
        _sentFunds = await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (context) => SendingForm(spendTx)),
        );
      }
      else
        flushbarMsg(context, 'failed to create transaction', category: MessageCategory.Warning);
    }
  }

  @override
  void initState() {
    super.initState();
    // create claim code
    merchantRegister(widget._amountDec, widget._amount).then((value) {
      _claimCode = value;
      if (_claimCode == null) {
        setState(() {
          _checking = false;
        });
        flushbarMsg(context, 'failed to create claim code', category: MessageCategory.Warning);
        return;
      }
      // create uri
      var uri = claimCodeUri(_claimCode);
      setState(() {
        _uri = uri;
        _init = true;
      });
      _timer = Timer.periodic(Duration(seconds: 1), check);
    });
  }

  @override
  Widget build(BuildContext context) {
  return Material(
      child: Padding(
        padding: EdgeInsets.all(15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children:
            <Widget>[
              Visibility(
                visible: _checking,
                child: CircularProgressIndicator(),
              ),
              Visibility(visible: _checking, child: Container(padding: const EdgeInsets.only(top: 20.0))),
              Visibility(
                visible: _init,
                child: Text(_claimCode.token),
              ),
              Visibility(
                visible: _init,
                child: QrWidget(_uri, size: 260, version: 6),
              ),
              Visibility(visible: _checking, child: Container(padding: const EdgeInsets.only(top: 20.0))),
              Visibility(
                visible: _checking && _init,
                child: Text("Waiting for customer confirmation..."),
              ),
              Visibility(visible: !_checking, child: Container(padding: const EdgeInsets.only(top: 20.0))),
              Visibility(
                  visible: !_checking,
                  child: RaisedButton.icon(
                      onPressed: () {
                        Navigator.pop(context, _sentFunds);
                      },
                      icon: Icon(Icons.close),
                      label: Text('Close'))
              ),
          ],
        ),
      ),
    );
  }
}
