import 'package:flutter/material.dart';

import 'bip39widget.dart';

class NewMnemonicForm extends StatefulWidget {
  final String _mnemonic;

  NewMnemonicForm(this._mnemonic) : super();

  @override
  NewMnemonicFormState createState() {
    return NewMnemonicFormState();
  }
}

class NewMnemonicFormState extends State<NewMnemonicForm> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("New recovery words"),
      ),
      body: Center(
        child: Column(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.only(top: 18.0),
              child: ListTile(title: Text("New recovery words"), subtitle: Text("You need to take care of your recovery words, if you lose them you could lose your ZAP")),
            ),
            Container(
              padding: const EdgeInsets.only(top: 18.0),
              child: ListTile(title: Bip39Words.fromString(widget._mnemonic)),
            ),
            Container(
                padding: const EdgeInsets.only(top: 18.0),
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
