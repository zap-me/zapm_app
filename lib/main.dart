import 'package:flutter/material.dart';
import 'package:qr_reader/qr_reader.dart';
import 'package:decimal/decimal.dart';

import 'qrwidget.dart';
import 'send_receive.dart';
import 'settings.dart';

final balance = Decimal.fromInt(13);
final address = "abc123XXX";

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

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  void _scanQrCode() {
    var qrCode = new QRCodeReader().scan();
    qrCode.then((value) {
      if (value != null)
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => SendScreen(value, balance)),
        );
    });
  }

  void _send() {
    Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => SendScreen('', balance)),
    );
  }

  void _receive() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => ReceiveScreen(address)),
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
              child: QrWidget(address),
            ),
            Container(
              padding: const EdgeInsets.only(top: 18.0),
              child: Text("Balance: $balance ZAP"),
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
