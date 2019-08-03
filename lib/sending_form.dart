import 'package:flutter/material.dart';

import 'libzap.dart';

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
    var tx = await LibZap.transactionBroadcast(widget._spendTx);
    setState(() {
      _sending = false;
      _tx = tx;
    });
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
                child: Text("Broadcasting transaction..."),
              ),
              Visibility(
                visible: !_sending && _tx != null,
                child: Text("Broadcast complete (${_tx?.id})"),
              ),
              Visibility(
                visible: !_sending && _tx == null,
                child: Text("Broadcast failed :("),
              ),
              Visibility(visible: !_sending, child: Container(padding: const EdgeInsets.only(top: 20.0))),
              Visibility(
                  visible: !_sending,
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
