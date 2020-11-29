import 'package:flutter/material.dart';

import 'zapdart/widgets.dart';
import 'zapdart/colors.dart';
import 'tests.dart';
import 'multisig.dart';

class HiddenScreen extends StatefulWidget {
  final bool testnet;
  
  HiddenScreen(this.testnet) : super();

  @override
  _HiddenState createState() => _HiddenState();
}

class _HiddenState extends State<HiddenScreen> {
  
  _HiddenState();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: backButton(context, color: ZapBlack),
        title: Text("Hidden"),
      ),
      body: Center(
        child: Column( 
          children: <Widget>[
            RaisedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TestsScreen())),
              child: Text("Tests")),
            RaisedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => MultisigScreen())),
              child: Text("Multisig")),
          ],
        ),
      )
    );
  }
}