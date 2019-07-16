import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';
import 'package:flushbar/flushbar.dart';

import 'send_form.dart';
import 'receive_form.dart';

class SendScreen extends StatelessWidget {
  SendScreen(this._testnet, this._seed, this._fee, this._recipientOrUri, this._max) : super();

  final bool _testnet;
  final String _seed;
  final Decimal _fee;
  final String _recipientOrUri;
  final Decimal _max;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Send"),
        ),
        body: new Container(
            padding: new EdgeInsets.all(20.0),
            child: SendForm(_testnet, _seed, _fee, _recipientOrUri, _max)
        )
    );
  }
}

class ReceiveScreen extends StatelessWidget {
  ReceiveScreen(this._testnet, this._address) : super();

  final bool _testnet;
  final String _address;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Recieve"),
        ),
        body: new Container(
            padding: new EdgeInsets.all(20.0),
            child: ReceiveForm(() {
              Navigator.pop(context);
            }, _testnet, _address)));
  }
}
