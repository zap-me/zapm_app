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

void main() => runApp(new MyApp());

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
  int _counter = 0;
  bool _newMnemonic = false;
  String _mnemonic = "";
  String _address = "";
  Decimal _balance = Decimal.fromInt(-1);
  String _balanceText = "...";

  _ZapHomePageState() {
  }

  void _setWalletDetails() async {
    setState(() {
      _balanceText = "...";
    });
    var libzap = LibZap();
    // get testnet value
    var testnet = await Prefs.TestnetGet();
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
    // get balance
    var balanceResult = await libzap.addrBalance(address);
    // update state
    setState(() {
      _newMnemonic = newMnemonic;
      _mnemonic = mnemonic;
      _address = address;
      if (balanceResult.success) {
        _balance = Decimal.fromInt(balanceResult.value) / Decimal.fromInt(100);
        _balanceText = "Balance: $_balance ZAP";
        if (testnet)
          _balanceText += " TESTNET";
      }
      else {
        _balance = Decimal.fromInt(-1);
        _balanceText = ":(";
      }
    });
    // show warning for new mnemonic
    if (newMnemonic)
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => NewMnemonicForm(mnemonic)),
    );
  }

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  void _scanQrCode() async {
    var value = await new QRCodeReader().scan();
    if (value != null) {
      var result = parseRecipientOrUri(value);
      if (result != null) {
        await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => SendScreen(_mnemonic, value, _balance)),
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
          builder: (context) => SendScreen(_mnemonic, '', _balance)),
    );
    _setWalletDetails();
  }

  void _receive() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ReceiveScreen(_address)),
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
            Container(
              padding: const EdgeInsets.only(top: 18.0),
              child: Text(_balanceText),
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
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  new Text(
                    'You have pushed the button this many times:',
                  ),
                  new Text(
                    '$_counter',
                    style: Theme.of(context).textTheme.display1,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: new FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: new Icon(Icons.add),
      ),
    );
  }
}
