import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';

import 'send_form.dart';
import 'receive_form.dart';
import 'widgets.dart';

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
          leading: backButton(context),
          title: Text('send zap', style: Theme.of(context).textTheme.subtitle2, textAlign: TextAlign.center),
          backgroundColor: zapyellow,
        ),
        body: Column(children: <Widget>[
          CustomPaint(
            painter: CustomWave(zapyellow),
            child: Container(
              padding: EdgeInsets.all(50),
              width: MediaQuery.of(context).size.width, 
              height: 200,
              child: Text('send zap', style: Theme.of(context).textTheme.subtitle2, textAlign: TextAlign.center)
            ) 
          ),
          Container(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: SendForm(_testnet, _seed, _fee, _recipientOrUri, _max)
          )
        ])
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
          leading: backButton(context),
          title: Text("recieve zap", style: Theme.of(context).textTheme.subtitle2, textAlign: TextAlign.center),
          backgroundColor: zapgreen,
        ),
        body: Column(children: <Widget>[
          CustomPaint(
            painter: CustomWave(zapgreen),
            size: Size(MediaQuery.of(context).size.width, 100)
          ),
          Container(
            padding: new EdgeInsets.all(20.0),
            child: ReceiveForm(() {
              Navigator.pop(context);
            }, _testnet, _address)
          )
        ]
      )
    );
  }
}
