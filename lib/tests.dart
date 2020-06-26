import 'dart:collection';
import 'dart:isolate';
import 'package:flutter/material.dart';

import 'widgets.dart';
import 'libzap.dart';

class WorkStatus extends StatefulWidget {
  final String workName;
  final void Function(SendPort) entryPoint;

  WorkStatus(this.workName, this.entryPoint) : super();

  @override _WorkStatusState createState() => _WorkStatusState();
}

class _WorkStatusState extends State<WorkStatus> {
  String _action = "";
  bool _running = false;
  String _output = "";
  ReceivePort _receivePort;
  Isolate _isolate;

  _WorkStatusState();

  @override
  void initState() {
    _action = "Start ${widget.workName}";
    super.initState();
  }

  void _start() async {
    if (!_running) {
      _action = "Stop ${widget.workName}";
      setState(() {
        _output = "...";
      });
      // start isolate
      _receivePort = ReceivePort();
      _isolate = await Isolate.spawn(widget.entryPoint, _receivePort.sendPort);
      _receivePort.listen(_handleMessage, onDone:() {
          print("done!");
      });
    } else {
      _action = "Start ${widget.workName}";
      // stop isolate
      if (_isolate != null) {
        _receivePort.close();
        _isolate.kill(priority: Isolate.immediate);
        _isolate = null;        
      }
    }
    setState(() {
      _action = _action;
      _running = !_running;
    });
  }

  void _handleMessage(dynamic data) {
    print('RECEIVED: ' + data);
    setState(() {      
      _output = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        RaisedButton(onPressed: _start, child: Text(_action)),
        Text(_output)
      ],
    );
  }
}

class TestsScreen extends StatefulWidget {
  
  TestsScreen() : super();

  @override
  _TestsState createState() => _TestsState();
}

class _TestsState extends State<TestsScreen> {
  
  _TestsState();

  static void _mnemonicTest(SendPort sendPort) async {
    var libzap = LibZap();
    var count = 0;
    var mnemonics = HashMap();
    while (true) {
      var mnemonic = libzap.mnemonicCreate();
      if (mnemonics.containsKey(mnemonic)) {
        sendPort.send("ERROR: $mnemonic already exists");
        break;
      } else {
        mnemonics[mnemonic] = 1;
      }
      if (count % 1000 == 0)
        sendPort.send("$count - '$mnemonic'");
      count += 1;
    }
  }

  static void _addrTest(SendPort sendPort) async {
    var libzap = LibZap();
    var count = 0;
    var addrs = HashMap();
    while (true) {
      var addr = libzap.seedAddress(count.toString());
      if (addrs.containsKey(addr)) {
        var originalSeed = addrs[addr];
        sendPort.send("ERROR: $originalSeed and $count make the same address ($addr)");
        break;
      } else {
        addrs[addr] = count;
      }
      if (count % 1000 == 0)
        sendPort.send("$count - $addr");
      count += 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: backButton(context, color: Colors.black),
        title: Text("Tests"),
      ),
      body: Center(
        child: Column( 
          children: <Widget>[
            WorkStatus("Mnemonic Test", _mnemonicTest),
            WorkStatus("Addr Test", _addrTest),
          ],
        ),
      )
    );
  }
}