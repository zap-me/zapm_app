import 'package:flutter/material.dart';
import 'package:qr_reader/qr_reader.dart';

import 'qrwidget.dart';
import 'quicksend.dart';
import 'settings.dart';

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
          MaterialPageRoute(builder: (context) => QuickSendScreen(value)),
        );
    });
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
              child: QrWidget("test stringxxx"),
            ),
            Container(
              padding: const EdgeInsets.only(top: 18.0),
              child: Text("Balance: 10 ZAP"),
            ),
            Container(
              padding: const EdgeInsets.only(top: 18.0),
              child: RaisedButton(
                  onPressed: _scanQrCode, child: Text('Scan QR Code')),
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
