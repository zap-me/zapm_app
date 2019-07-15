import 'package:flutter/material.dart';

class NewMnemonicForm extends StatefulWidget {
  String _mnemonic;

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
        title: Text("New Mnemonic"),
      ),
      body: Center(
        child: Column(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.only(top: 18.0),
              child: ListTile(title: Text("New Mnemonic"), subtitle: Text("You need to take care of your mnemonic, if you lose it you could lose your ZAP")),
            ),
            Container(
              padding: const EdgeInsets.only(top: 18.0),
              child: ListTile(title: Text(widget._mnemonic)),
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
