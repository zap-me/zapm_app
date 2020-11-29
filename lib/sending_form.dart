import 'package:flutter/material.dart';

import 'zapdart/libzap.dart';
import 'zapdart/widgets.dart';
import 'zapdart/colors.dart';
import 'merchant.dart';

class SendingForm extends StatefulWidget {
  final SpendTx _spendTx;

  SendingForm(this._spendTx) : super();

  @override
  SendingFormState createState() {
    return SendingFormState();
  }
}

class SendingFormState extends State<SendingForm> {
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
    } catch(_) {}
  }

  @override
  void initState() {
    WidgetsBinding.instance
        .addPostFrameCallback((_) => send());
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
          children:
            <Widget>[
              Visibility(
                visible: _sending,
                child: CircularProgressIndicator(),
              ),
              Visibility(visible: _sending, child: Container(padding: const EdgeInsets.only(top: 20.0))),
              Visibility(
                visible: _sending,
                child: Text("broadcasting transaction..."),
              ),
              Visibility(
                visible: !_sending && _tx != null,
                child: Text("broadcast complete (${_tx?.id})", style: TextStyle(color: ZapBlue)),
              ),
              Visibility(
                visible: !_sending && _tx == null,
                child: Text("broadcast failed :("),
              ),
              Visibility(visible: !_sending, child: Container(padding: const EdgeInsets.only(top: 20.0))),
              Visibility(
                  visible: !_sending,
                  child: RoundedButton(() => Navigator.pop(context, _tx != null), ZapBlue, ZapWhite, 'close', borderColor: ZapBlue)
              ),
          ],
        ),
      ),
    );
  }
}
