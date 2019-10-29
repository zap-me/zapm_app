import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flushbar/flushbar.dart';

import 'libzap.dart';
import 'qrwidget.dart';
import 'merchant.dart';
import 'sending_form.dart';

class ClaimingForm extends StatefulWidget {
  final ClaimCode _claimCode;
  final String _seed;
  final int _amount;
  final int _fee;
  final String _attachment;

  ClaimingForm(this._claimCode, this._seed, this._amount, this._fee, this._attachment) : super();

  @override
  ClaimingFormState createState() {
    return ClaimingFormState();
  }
}

class ClaimingFormState extends State<ClaimingForm> {
  bool _checking = true;
  String _uri;
  Timer _timer;
  SpendTx _spendTx;

  Future check(Timer timer) async {
    if (!_checking)
      return;
    var addr = await merchantCheck(widget._claimCode);
    if (addr != null) {
      _timer.cancel();
      setState(() {
       _checking = false; 
      });
      var libzap = LibZap();
      _spendTx = libzap.transactionCreate(widget._seed, addr, widget._amount, widget._fee, widget._attachment);
      if (_spendTx.success) {
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => SendingForm(_spendTx)),
        );
      }
      else
        Flushbar(title: "Failed to create Tx", message: ":(", duration: Duration(seconds: 2),)
          ..show(context);
    }
  }

  @override
  void initState() {
    super.initState();
    var uri = claimCodeUri(widget._claimCode);
    setState(() {
      _uri = uri;
    });
    _timer = Timer.periodic(Duration(seconds: 1), check);
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
                visible: _checking,
                child: Text(widget._claimCode.token),
              ),
              Visibility(
                visible: _checking,
                child: QrWidget(_uri),
              ),
              Visibility(visible: _checking, child: Container(padding: const EdgeInsets.only(top: 20.0))),
              Visibility(
                visible: _checking,
                child: Text("Waiting for customer confirmation..."),
              ),
              Visibility(
                visible: !_checking && _spendTx != null,
                child: Text("Send failed :("),
              ),
              Visibility(visible: !_checking, child: Container(padding: const EdgeInsets.only(top: 20.0))),
              Visibility(
                  visible: !_checking,
                  child: RaisedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
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
