import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';
import 'package:flushbar/flushbar.dart';

import 'send_form.dart';

class QuickSendScreen extends StatelessWidget {
  QuickSendScreen(this._addr) : super();

  final String _addr;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Quick Send"),
        ),
        body: new Container(
            padding: new EdgeInsets.all(20.0),
            child: SendForm(() {
              Navigator.pop(context);
            }, () {
              Flushbar()
                ..title = "Sent"
                ..message = "Sent"
                ..duration = Duration(seconds: 1)
                ..show(context);
              Navigator.pop(context);
            }, _addr, Decimal.parse('10'))));
  }
}

class SendScreen extends StatelessWidget {
  final String _addr = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Send"),
        ),
        body: new Container(
            padding: new EdgeInsets.all(20.0),
            child: SendForm(() {
              Navigator.pop(context);
            }, () {
              Flushbar()
                ..title = "Sent"
                ..message = "Sent"
                ..duration = Duration(seconds: 1)
                ..show(context);
              Navigator.pop(context);
            }, _addr, Decimal.parse('10'))));
  }
}
