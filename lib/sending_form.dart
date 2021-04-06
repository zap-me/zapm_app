import 'package:flutter/material.dart';

import 'package:zapdart/libzap.dart';
import 'package:zapdart/widgets.dart';
import 'package:zapdart/colors.dart';

import 'merchant.dart';
import 'paydb.dart';

class WavesSendingForm extends StatefulWidget {
  final SpendTx _spendTx;

  WavesSendingForm(this._spendTx) : super();

  @override
  WavesSendingFormState createState() {
    return WavesSendingFormState();
  }
}

class WavesSendingFormState extends State<WavesSendingForm> {
  bool _sending = true;
  Tx _tx;

  void send() async {
    // broadcast tx
    var tx = await LibZap.transactionBroadcast(widget._spendTx);
    setState(() {
      _sending = false;
      _tx = tx;
    });
    try {
      // alert server to update merchant tx table
      merchantTx();
    } catch (_) {}
  }

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) => send());
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Padding(
        padding: EdgeInsets.all(15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Visibility(
              visible: _sending,
              child: CircularProgressIndicator(),
            ),
            Visibility(
                visible: _sending,
                child: Container(padding: const EdgeInsets.only(top: 20.0))),
            Visibility(
              visible: _sending,
              child: Text("broadcasting transaction..."),
            ),
            Visibility(
              visible: !_sending && _tx != null,
              child: Text("broadcast complete (${_tx?.id})",
                  style: TextStyle(color: ZapBlue)),
            ),
            Visibility(
              visible: !_sending && _tx == null,
              child: Text("broadcast failed :("),
            ),
            Visibility(
                visible: !_sending,
                child: Container(padding: const EdgeInsets.only(top: 20.0))),
            Visibility(
                visible: !_sending,
                child: RoundedButton(() => Navigator.pop(context, _tx), ZapBlue,
                    ZapWhite, 'close',
                    borderColor: ZapBlue)),
          ],
        ),
      ),
    );
  }
}

class PayDbSendingForm extends StatefulWidget {
  final String _recipient;
  final int _amount;
  final String _attachment;

  PayDbSendingForm(this._recipient, this._amount, this._attachment) : super();

  @override
  PayDbSendingFormState createState() {
    return PayDbSendingFormState();
  }
}

class PayDbSendingFormState extends State<PayDbSendingForm> {
  bool _sending = true;
  PayDbTx _tx;

  void send() async {
    var result = await paydbTransactionCreate(
        ActionTransfer, widget._recipient, widget._amount, widget._attachment);
    setState(() {
      _sending = false;
      _tx = result.tx;
    });
  }

  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((_) => send());
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: Padding(
        padding: EdgeInsets.all(15),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Visibility(
              visible: _sending,
              child: CircularProgressIndicator(),
            ),
            Visibility(
                visible: _sending,
                child: Container(padding: const EdgeInsets.only(top: 20.0))),
            Visibility(
              visible: _sending,
              child: Text("creating transaction..."),
            ),
            Visibility(
              visible: !_sending && _tx != null,
              child: Text("transaction complete (${_tx?.token})",
                  style: TextStyle(color: ZapBlue)),
            ),
            Visibility(
              visible: !_sending && _tx == null,
              child: Text("transaction failed :("),
            ),
            Visibility(
                visible: !_sending,
                child: Container(padding: const EdgeInsets.only(top: 20.0))),
            Visibility(
                visible: !_sending,
                child: RoundedButton(() => Navigator.pop(context, _tx), ZapBlue,
                    ZapWhite, 'close',
                    borderColor: ZapBlue)),
          ],
        ),
      ),
    );
  }
}
