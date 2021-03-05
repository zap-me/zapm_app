import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:zapdart/utils.dart';

import 'package:zapdart/widgets.dart';
import 'package:zapdart/colors.dart';

import 'tests.dart';
import 'multisig.dart';
import 'prefs.dart';
import 'paydb.dart';
import 'config.dart';

class HiddenScreen extends StatefulWidget {
  final bool testnet;
  final String fcmRegistrationToken;
  final String account;
  
  HiddenScreen(this.testnet, this.fcmRegistrationToken, this.account) : super();

  @override
  _HiddenState createState() => _HiddenState();
}

class _HiddenState extends State<HiddenScreen> {
  
  _HiddenState();

  void _copyFCMToken() {
    Clipboard.setData(ClipboardData(text: widget.fcmRegistrationToken)).then((value) {
      flushbarMsg(context, 'copied FCM registration token to clipboard');
    });
  }

  void _deleteMnemonicAndAccount() {
    Prefs.mnemonicSet('');
    Prefs.paydbApiKeySet('');
    Prefs.paydbApiSecretSet('');
    exit(0);
  }

  void _paydbIssue() async {
    assert(AppTokenType == TokenType.PayDB);
    var result = await paydbTransactionCreate(ActionIssue, widget.account, 10000, null);
    alert(context, 'Issue Result', '${result.error}');
  }

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
            ListTile(title: Text("FCM Registration Token"), subtitle: Text("${widget.fcmRegistrationToken}")),
            RaisedButton(onPressed: _copyFCMToken, child: Text("Copy FCM Registration Token")),
            RaisedButton(onPressed: _deleteMnemonicAndAccount, child: Text("Delete Mnemonic/Account")),
            RaisedButton(onPressed: _paydbIssue, child: Text("PayDb Issue 100 tokens")),
          ],
        ),
      )
    );
  }
}