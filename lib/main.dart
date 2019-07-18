import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:qr_reader/qr_reader.dart';
import 'package:decimal/decimal.dart';
import 'package:flushbar/flushbar.dart';

import 'qrwidget.dart';
import 'send_receive.dart';
import 'settings.dart';
import 'utils.dart';
import 'libzap.dart';
import 'prefs.dart';
import 'new_mnemonic_form.dart';
import 'transactions.dart';

void main() {
  // See https://github.com/flutter/flutter/wiki/Desktop-shells#target-platform-override
  _setTargetPlatformForDesktop();  

  runApp(new MyApp());
}

/// If the current platform is desktop, override the default platform to
/// a supported platform (iOS for macOS, Android for Linux and Windows).
/// Otherwise, do nothing.
void _setTargetPlatformForDesktop() {
  TargetPlatform targetPlatform;
  if (Platform.isMacOS) {
    targetPlatform = TargetPlatform.iOS;
  } else if (Platform.isLinux || Platform.isWindows) {
    targetPlatform = TargetPlatform.android;
  }
  if (targetPlatform != null) {
    debugDefaultTargetPlatformOverride = targetPlatform;
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new MaterialApp(
      title: 'Zap',
      theme: new ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: new ZapHomePage(title: 'Zap'),
    );
  }
}

class ZapHomePage extends StatefulWidget {
  ZapHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _ZapHomePageState createState() => new _ZapHomePageState();
}

class _ZapHomePageState extends State<ZapHomePage> {
  bool _testnet = true;
  String _mnemonic = "";
  String _address = "";
  Decimal _fee = Decimal.parse("0.01");
  Decimal _balance = Decimal.fromInt(-1);
  String _balanceText = "...";
  bool _updatingBalance = true;

  _ZapHomePageState() {
  }

  void _setWalletDetails() async {
    setState(() {
      _updatingBalance = true;
    });
    var libzap = LibZap();
    // get testnet value
    _testnet = await Prefs.TestnetGet();
    // check mnemonic
    var newMnemonic = false;
    var mnemonic = await PrefsSecure.MnemonicGet();
    if (mnemonic == null || mnemonic == "") {
      mnemonic = libzap.mnemonicCreate();
      newMnemonic = true;
      await PrefsSecure.MnemonicSet(mnemonic);
    }
    // create address
    var address = libzap.seedAddress(mnemonic);
    // update state
    setState(() {
      _mnemonic = mnemonic;
      _address = address;
    });
    // get fee
    var feeResult = await LibZap.transactionFee();
    // get balance
    var balanceResult = await LibZap.addressBalance(address);
    // update state
    setState(() {
      if (feeResult.success)
        _fee = Decimal.fromInt(feeResult.value) / Decimal.fromInt(100);
      if (balanceResult.success) {
        _balance = Decimal.fromInt(balanceResult.value) / Decimal.fromInt(100);
        _balanceText = "Balance: $_balance ZAP";
        if (_testnet)
          _balanceText += " TESTNET";
      }
      else {
        _balance = Decimal.fromInt(-1);
        _balanceText = ":(";
      }
      _updatingBalance = false;
    });
    // show warning for new mnemonic
    if (newMnemonic)
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NewMnemonicForm(mnemonic)),
    );
  }

  void _scanQrCode() async {
    var value = await new QRCodeReader().scan();
    if (value != null) {
      var result = parseRecipientOrUri(_testnet, value);
      if (result != null) {
        await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => SendScreen(_testnet, _mnemonic, _fee, value, _balance)),
        );
        _setWalletDetails();
      }
      else
        Flushbar(title: "Invalid QR Code", message: "Unable to decipher QR code data", duration: Duration(seconds: 2),)
          ..show(context);
    }
  }

  void _send() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => SendScreen(_testnet, _mnemonic, _fee, '', _balance)),
    );
    _setWalletDetails();
  }

  void _receive() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ReceiveScreen(_testnet, _address)),
    );
    _setWalletDetails();
  }

  void _transactions() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => TransactionsScreen(_address)),
    );
    _setWalletDetails();
  }

  void _showSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SettingsScreen(_mnemonic)),
    );
    _setWalletDetails();
  }

  @override
  void initState() {
    Prefs.TestnetGet().then((testnet) {
      // set libzap testnet
      LibZap().testnetSet(testnet);
      // init wallet details
      _setWalletDetails();
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      appBar: new AppBar(
        title: new Text(widget.title),
        actions: <Widget>[
          IconButton(icon: Icon(Icons.settings), onPressed: _showSettings),
        ],
      ),
      body: new Center(
        child: Column(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.only(top: 18.0),
              child: QrWidget(_address),
            ),
            Container(
              padding: const EdgeInsets.only(top: 0.0),
              child: Text(_address),
            ),
            Visibility(
              visible: _updatingBalance,
              child: Container(
                padding: const EdgeInsets.only(top: 18.0),
                child: SizedBox(child: CircularProgressIndicator(), height: 16.0, width: 16.0,),
              ),
            ),
            Visibility(
              visible: !_updatingBalance,
              child: Container(
                padding: const EdgeInsets.only(top: 18.0),
                child: Text(_balanceText),
              ),
            ),
            Container(
              padding: const EdgeInsets.only(top: 18.0),
              child: RaisedButton.icon(
                onPressed: _scanQrCode, icon: Icon(Icons.center_focus_weak), label:  Text("Scan")
                ),
            ),
            Container(
              padding: const EdgeInsets.only(top: 18.0),
              child: RaisedButton.icon(
                  onPressed: _send, icon: Icon(Icons.arrow_drop_up), label:  Text("Send")
              ),
            ),
            Container(
              padding: const EdgeInsets.only(top: 18.0),
              child: RaisedButton.icon(
                  onPressed: _receive, icon: Icon(Icons.arrow_drop_down), label:  Text("Recieve")
              ),
            ),
            Container(
              padding: const EdgeInsets.only(top: 18.0),
              child: RaisedButton.icon(
                  onPressed: _transactions, icon: Icon(Icons.list), label:  Text("Transactions")
              ),
            ),
          ],
        ),
      ),
    );
  }
}
