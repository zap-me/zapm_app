import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';

import 'settlement_form.dart';
import 'widgets.dart';

class SettlementScreen extends StatelessWidget {
  SettlementScreen(this._seed, this._fee, this._max) : super();

  final String _seed;
  final Decimal _fee;
  final Decimal _max;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          leading: backButton(context),
          title: Text('settlement', style: TextStyle(color: Colors.white)),
          backgroundColor: zapblue,

        ),
        body: CustomPaint(
          painter: CustomCurve(zapblue, 110, 170),
          child: Container(
            width: MediaQuery.of(context).size.width, 
            height: MediaQuery.of(context).size.height,
            padding: EdgeInsets.all(20),
            child: SettlementForm(_seed, _fee, _max)
          ) 
        )
    );
  }
}
