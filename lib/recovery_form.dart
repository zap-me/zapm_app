import 'package:flutter/material.dart';
import 'package:zap_merchant/config.dart';

import 'package:zapdart/bip39widget.dart';
import 'package:zapdart/widgets.dart';
import 'package:zapdart/utils.dart';

import 'stash.dart';

class RecoveryForm extends StatefulWidget {
  final String? instructions;

  RecoveryForm({this.instructions}) : super();

  @override
  RecoveryFormState createState() {
    return RecoveryFormState();
  }
}

class RecoveryFormState extends State<RecoveryForm> {
  String? _mnemonic;
  final _emailController = TextEditingController();

  void _loadStash() async {
    var email = _emailController.text;
    showAlertDialog(context, 'Loading from server..');
    var stash = Stash();
    var token = await stash.load(StashKeyRecoveryWords, email);
    Navigator.pop(context);
    if (token == null) {
      flushbarMsg(context, 'failed to load recovery words',
          category: MessageCategory.Warning);
      return;
    }
    StashData? stashData;
    showAlertDialog(context, 'Waiting for email to be verified..');
    while (true) {
      stashData = await stash.loadCheck(token);
      if (stashData != null) {
        break;
      }
      Future.delayed(Duration(seconds: 5));
    }
    Navigator.pop(context);
    var answer = await askString(context, stashData.question, null);
    if (answer != null) {
      var mnemonic = stash.decrypt(stashData, email, answer);
      if (mnemonic != null)
        Navigator.of(context).pop(mnemonic);
      else
        flushbarMsg(context, 'failed to decrypt recovery words',
            category: MessageCategory.Warning);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          title: Text('Recover your account'),
        ),
        body: Container(
            padding: EdgeInsets.all(20),
            child: Center(
                child: Column(children: <Widget>[
              Text(widget.instructions == null
                  ? "Enter your recovery words to recover your account"
                  : widget.instructions!),
              Bip39Entry((words) => _mnemonic = words.join(' ')),
              raisedButton(
                child: Text("Recover"),
                onPressed: () {
                  Navigator.of(context).pop(_mnemonic);
                },
              ),
              StashServer != null
                  ? Column(children: [
                      Divider(thickness: 3, height: 25),
                      Text(
                          "Load your recovery words from the Stash server to recover your account"),
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration:
                            InputDecoration(labelText: 'Recovery Email'),
                      ),
                      raisedButton(child: Text("Load"), onPressed: _loadStash),
                    ])
                  : SizedBox()
            ]))));
  }
}
