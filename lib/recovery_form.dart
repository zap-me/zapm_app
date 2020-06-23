import 'package:flutter/material.dart';

import 'bip39widget.dart';


class RecoveryForm extends StatefulWidget {
  
  RecoveryForm() : super();

  @override
  RecoveryFormState createState() {
    return RecoveryFormState();
  }
}

class RecoveryFormState extends State<RecoveryForm> {
  String _mnemonic;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(child: Container(), preferredSize: Size(0, 0),),
      body: Container(padding: EdgeInsets.all(20), child: Center(child: Column(
        children: <Widget>[
          Text("Enter your recovery words to recover your account"),
          Bip39Entry((words) => _mnemonic = words.join(' ')),
          RaisedButton(
            child: Text("Ok"),
            onPressed: () {
              Navigator.of(context).pop(_mnemonic);
            },
          ),
        ],
      )))
    );
  }
}
