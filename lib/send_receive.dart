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
          title: Text('send zap', style: TextStyle(color: Colors.white)),
          backgroundColor: zapyellow,
        ),
        body: CustomPaint(
          painter: CustomCurve(zapyellow, 90, 140),
          child: Container(
            width: MediaQuery.of(context).size.width, 
            height: MediaQuery.of(context).size.height,
            padding: EdgeInsets.all(20),
            child: SendForm(_testnet, _seed, _fee, _recipientOrUri, _max)
          ) 
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
          leading: backButton(context),
          title: Text("recieve zap", style: TextStyle(color: Colors.white)),
          backgroundColor: zapgreen,
        ),
        body: CustomPaint(
          painter: CustomCurve(zapgreen, 150, 250),
          child: Container(
            width: MediaQuery.of(context).size.width, 
            height: MediaQuery.of(context).size.height,
            padding: EdgeInsets.all(20),
            child: ReceiveForm(_testnet, _address)
          )
        )
    );
  }
}
