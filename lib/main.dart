import 'package:flutter/material.dart';
import 'package:qr_reader/qr_reader.dart';
import 'package:decimal/decimal.dart';
import 'package:flushbar/flushbar.dart';

import 'qrwidget.dart';
import 'send_receive.dart';
import 'settings.dart';
import 'utils.dart';
import 'libzap.dart';

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
  Decimal _balance = Decimal.fromInt(-1);

  _ZapHomePageState() {
    _balance = _getBalance();
  }

  String _getAddr() {
    var libzap = LibZap();
    return libzap.walletAddr();
  }

  Decimal _getBalance() {
    var libzap = LibZap();
    var res = libzap.addrBalance(libzap.walletAddr());
    if (res.success)
      return Decimal.fromInt(res.value) / Decimal.fromInt(100);
    return Decimal.fromInt(-1);
  }

  void _incrementCounter() {
    var libzap = LibZap();
    var version = libzap.version();
    Flushbar(title: "libzap version", message: "$version", duration: Duration(seconds: 2),)
      ..show(context);

    setState(() {
      _counter++;
    });
  }

  void _scanQrCode() {
    var qrCode = new QRCodeReader().scan();
    qrCode.then((value) {
      if (value != null) {
        var result = parseRecipientOrUri(value);
        if (result != null)
          Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => SendScreen(value, _balance)),
          );
        else
          Flushbar(title: "Invalid QR Code", message: "Unable to decipher QR code data", duration: Duration(seconds: 2),)
            ..show(context);
      }
    });
  }

  void _send() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => SendScreen('', _balance)),
    );
  }

  void _receive() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ReceiveScreen(LibZap.ADDR)),
    );
  }

  void _showSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SettingsScreen()),
    );
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
              child: QrWidget(_getAddr()),
            ),
            Container(
              padding: const EdgeInsets.only(top: 18.0),
              child: Text("Balance: $_balance ZAP"),
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
