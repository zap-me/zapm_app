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
import 'firebase.dart';
import 'ui_strings.dart';

class HiddenScreen extends StatefulWidget {
  final bool testnet;
  final FCM? fcm;
  final String? account;

  HiddenScreen(this.testnet, this.fcm, this.account) : super();

  @override
  _HiddenState createState() => _HiddenState();
}

class _HiddenState extends State<HiddenScreen> {
  _HiddenState();

  @override
  void initState() {
    super.initState();
  }

  void _copyFCMToken() {
    Clipboard.setData(ClipboardData(text: widget.fcm?.getToken()))
        .then((value) {
      flushbarMsg(context, 'copied FCM registration token to clipboard');
    });
  }

  void _registerPushNotifications() async {
    if (widget.fcm == null) {
      flushbarMsg(context, 'Firebase not available',
          category: MessageCategory.Warning);
      return;
    }
    showAlertDialog(context, 'getting location..');
    var loc = await widget.fcm!.getLocation();
    Navigator.pop(context);
    if (loc == null) {
      flushbarMsg(context, 'Location not available',
          category: MessageCategory.Warning);
      return;
    }
    var locString = await askString(context, 'Set location GPS coordinates',
        '${loc.latitude}, ${loc.longitude}');
    if (locString != null) {
      var parts = locString.split(',');
      var lat = double.parse(parts[0]);
      var long = double.parse(parts[1]);
      var result =
          await widget.fcm!.registerPushNotifications(lat: lat, long: long);
      if (!result)
        flushbarMsg(context, 'failed to re-register push noitifcations',
            category: MessageCategory.Warning);
    }
  }

  void _deleteMnemonicAndAccount() {
    Prefs.mnemonicSet('');
    Prefs.paydbApiKeySet('');
    Prefs.paydbApiSecretSet('');
  }

  void _deleteBronzeApiKey() {
    Prefs.bronzeApiKeySet(null);
    Prefs.bronzeApiSecretSet(null);
    Prefs.bronzeKycTokenSet(null);
    Prefs.bronzeBankAccountSet(null);
    Prefs.bronzeOrdersSet([]);
  }

  void _paydbIssue() async {
    assert(AppTokenType == TokenType.PayDB);
    if (widget.account == null) return;
    var result =
        await paydbTransactionCreate(ActionIssue, widget.account!, 10000, null);
    alert(context, 'Issue Result', '${result.error}');
  }

  @override
  Widget build(BuildContext context) {
    var ssc = ScreenSizeClass.calc(context);
    return Scaffold(
        appBar: AppBar(
          leading: backButton(context, color: ZapBlack),
          title: Text("Hidden"),
        ),
        body: Center(
          child: Column(
            children: [
              ListTile(
                  title: Text("Screen Size"),
                  subtitle: Text(
                      "width: ${ssc.width}, height: ${ssc.height}, pixWidth: ${ssc.pixWidth}, pixHeight: ${ssc.pixHeight}")),
              raisedButton(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (context) => TestsScreen())),
                  child: Text("Tests")),
              raisedButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => MultisigScreen())),
                  child: Text("Multisig")),
              ListTile(
                  title: Text("FCM Registration Token"),
                  subtitle: Text("${widget.fcm?.getToken()}")),
              raisedButton(
                  onPressed: _copyFCMToken,
                  child: Text("Copy FCM Registration Token")),
              raisedButton(
                  onPressed: _registerPushNotifications,
                  child: Text("Re-register push notifications")),
              raisedButton(
                  onPressed: _deleteMnemonicAndAccount,
                  child: Text("Delete Mnemonic/Account")),
              raisedButton(
                  onPressed: _deleteBronzeApiKey,
                  child: Text("Delete Bronze API KEY")),
              raisedButton(
                  onPressed: _paydbIssue,
                  child: Text("PayDb Issue 100 tokens")),
            ],
          ),
        ));
  }
}
