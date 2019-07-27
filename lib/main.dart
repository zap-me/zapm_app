import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:qr_reader/qr_reader.dart';
import 'package:decimal/decimal.dart';
import 'package:flushbar/flushbar.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:clipboard_manager/clipboard_manager.dart';

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

enum NoMnemonicAction { CreateNew, Recover }

class _ZapHomePageState extends State<ZapHomePage> {
  bool _testnet = true;
  String _mnemonic = "";
  bool _mnemonicPasswordProtected = false;
  bool _mnemonicDecrypted = false;
  String _address = "";
  Decimal _fee = Decimal.parse("0.01");
  Decimal _balance = Decimal.fromInt(-1);
  String _balanceText = "...";
  bool _updatingBalance = true;

  _ZapHomePageState();

  Future<NoMnemonicAction> _noMnemonicDialog(BuildContext context) async {
    return await showDialog<NoMnemonicAction>(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return SimpleDialog(
            title: const Text("You do not have a mnemonic saved, what would you like to do?"),
            children: <Widget>[
              SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(context, NoMnemonicAction.CreateNew);
                },
                child: const Text("Create a new mnemonic"),
              ),
              SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(context, NoMnemonicAction.Recover);
                },
                child: const Text("Recover using your mnemonic"),
              ),
            ],
          );
        });
  }

  Future<String> _recoverMnemonic(BuildContext context) async {
    String mnemonic = "";
    return showDialog<String>(
      context: context,
      barrierDismissible: false, // dialog is dismissible with a tap on the barrier
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Enter your mnemonic to recover your account"),
          content: new Row(
            children: <Widget>[
              new Expanded(
                  child: new TextField(
                    autofocus: true,
                    decoration: new InputDecoration(
                        labelText: "Mnemonic",),
                    onChanged: (value) {
                      mnemonic = value;
                    },
                  ))
            ],
          ),
          actions: <Widget>[
            FlatButton(
              child: Text("Ok"),
              onPressed: () {
                Navigator.of(context).pop(mnemonic);
              },
            ),
          ],
        );
      },
    );
  }

  void _noMnemonic() async {
    var libzap = LibZap();
    while (true) {
      String mnemonic;
      var action = await _noMnemonicDialog(context);
      switch (action) {
        case NoMnemonicAction.CreateNew:
          mnemonic = libzap.mnemonicCreate();
          // show warning for new mnemonic
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => NewMnemonicForm(mnemonic)),
          );
          break;
        case NoMnemonicAction.Recover:
        // recover mnemonic
          mnemonic = await _recoverMnemonic(context);
          mnemonic = mnemonic.trim();
          mnemonic = mnemonic.replaceAll(RegExp(r"\s+"), " ");
          mnemonic = mnemonic.toLowerCase();
          if (!libzap.mnemonicCheck(mnemonic)) {
            mnemonic = null;
            await alert(context, "Mnemonic not valid", "The mnemonic you entered is not valid");
          }
          break;
      }
      if (mnemonic != null) {
        await Prefs.mnemonicSet(mnemonic);
        await alert(context, "Mnemonic saved", ":)");
        // update wallet details now we have a mnemonic
        _setWalletDetails();
        break;        
      }
    }
  }

  Future<bool> _setWalletDetails() async {
    setState(() {
      _updatingBalance = true;
    });
    var libzap = LibZap();
    // get testnet value
    _testnet = await Prefs.testnetGet();
    // check mnemonic
    if (_mnemonic == null || _mnemonic == "") {
      var mnemonic = await Prefs.mnemonicGet();
      if (mnemonic == null || mnemonic == "") {
        return false;
      }
      _mnemonicPasswordProtected = await Prefs.mnemonicPasswordProtectedGet();
      if (_mnemonicPasswordProtected && !_mnemonicDecrypted) {
        while (true) {
          var password = await askMnemonicPassword(context);
          if (password == null || password == "") {
            continue;
          }
          var iv = await Prefs.cryptoIVGet();
          var decryptedMnemonic = decryptMnemonic(mnemonic, iv, password);
          if (decryptedMnemonic == null) {
            await alert(context, "Could not decrypt mnemonic", "probably wrong password :(");
            continue;
          }
          if (!libzap.mnemonicCheck(decryptedMnemonic)) {
            await alert(context, "Decrypted mnemonic invalid", "not sure what happened :(");
            continue;
          }
          mnemonic = decryptedMnemonic;
          _mnemonicDecrypted = true;
          break;
        }
      }
      _mnemonic = mnemonic;
    }
    // create address
    var address = libzap.seedAddress(_mnemonic);
    // update state
    setState(() {
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
    return true;
  }

  void _showQrCode() {
    showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          content: InkWell(child: Container(width: 300, child: QrWidget(_address, size: 300)),
            onTap: () => Navigator.pop(context)),
        );
      },
    );
  }

  void _copyAddress() {
    ClipboardManager.copyToClipBoard(_address).then((result) {
      Flushbar(title: "Copied address to clipboard", message: _address, duration: Duration(seconds: 2),)
        ..show(context);
    });
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
      MaterialPageRoute(builder: (context) => TransactionsScreen(_address, _testnet)),
    );
    _setWalletDetails();
  }

  void _showSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SettingsScreen(_mnemonic, _mnemonicPasswordProtected)),
    );
    _setWalletDetails();
  }

  @override
  void initState() {
    Prefs.testnetGet().then((testnet) {
      // set libzap testnet
      LibZap().testnetSet(testnet);
      // init wallet details
      _setWalletDetails().then((hasMnemonic) {
        if (!hasMnemonic) {
          _noMnemonic();
          _setWalletDetails();
        }
      });
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.only(top: 18.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(icon: Icon(FontAwesomeIcons.qrcode), onPressed: _showQrCode),
                  Text(_address),
                  IconButton(onPressed: _copyAddress, icon: Icon(Icons.content_copy)),
                ]
              )
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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  RaisedButton.icon(onPressed: _send, icon: Icon(Icons.send), label: Text("Send")),
                  RaisedButton.icon(onPressed: _scanQrCode, icon: Icon(Icons.center_focus_weak), label: Text("Scan")),
                  RaisedButton.icon(onPressed: _receive, icon: Icon(Icons.account_balance_wallet), label: Text("Recieve")),
                ]
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
