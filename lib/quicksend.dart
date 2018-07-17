import 'package:flutter/material.dart';

import 'qrwidget.dart';

class QuickSendScreen extends StatelessWidget {
  QuickSendScreen(this._addr) : super();

  final String _addr;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text("Quick Send"),
        ),
        body: Column(children: <Widget>[
          Container(
            padding: const EdgeInsets.only(top: 18.0),
            child: QrWidget(_addr),
          ),
          Container(
            padding: const EdgeInsets.only(top: 18.0),
            child: Text(_addr),
          ),
          Container(
            padding: const EdgeInsets.only(top: 18.0, left: 20.0, right: 20.0),
            child: TextField(
              decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Please enter the amount to send'),
            ),
          ),
          Container(
            padding: const EdgeInsets.only(top: 18.0),
            child: RaisedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Send'),
            ),
          ),
          Container(
            padding: const EdgeInsets.only(top: 18.0),
            child: RaisedButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text('Cancel'),
            ),
          ),
        ])
    );
  }
}