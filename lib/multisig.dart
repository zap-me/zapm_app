import 'dart:convert';
import 'dart:io';
import 'package:ZapMerchant/utils.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_share/flutter_share.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;

import 'widgets.dart';
import 'libzap.dart';
import 'recovery_form.dart';

class SignaturePicker extends StatelessWidget {
  final void Function(int) signatureSelect;
  final void Function(int, int) signatureSwap;
  final void Function(int) signatureDelete;
  final String fileData;
  final int signatureIndex;

  SignaturePicker(this.signatureSelect, this.signatureSwap, this.signatureDelete, this.fileData, this.signatureIndex) : super();

  @override
  Widget build(BuildContext context) {
    var sigs = <Widget>[];
    if (fileData != null) {
      var res = json.decode(fileData);
      for (var i = 0; i < res['proofs'].length; i++) {
        var sig = FlatButton(onPressed: () => signatureSelect(i), 
          child: //Flexible(child:
            Text(res['proofs'][i], overflow: TextOverflow.ellipsis,
            style: i == signatureIndex ? TextStyle(color: Colors.red) : null)
          //)
        );
        var trail = Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
          DragTarget<int>(
            builder: (context, candidateData, rejectedData) {
              return Draggable(
                data: i,
                child: Icon(Icons.reorder),
                childWhenDragging: Icon(Icons.reorder, color: Colors.grey),
                feedback: Icon(Icons.reorder, color: Colors.red, size: 30),
              );
            },
            onWillAccept: (data) => true,
            onAccept: (data) => signatureSwap(data, i)),
          IconButton(onPressed: () => signatureDelete(i), icon: Icon(Icons.close))]
        );
        var tile = ListTile(key: Key('$i'),
          leading: Text('$i', style: TextStyle(color: Colors.grey, fontSize: 10)),
          title: sig,
          trailing: trail,
        );
        sigs.add(tile);
      }
    }
    return Column(
      children: sigs
    );
  }
}

class MultisigScreen extends StatefulWidget {
  final bool testnet;
  
  MultisigScreen(this.testnet) : super();

  @override
  _MultisigState createState() => _MultisigState();
}

class _MultisigState extends State<MultisigScreen> {
  String _filePath;
  String _fileData;
  int _signatureIndex;
  bool _serializing = false;
  String _broadcastResponse;

  _MultisigState();

  String jsonEncodePretty(Object obj) {
    return JsonEncoder.withIndent('    ').convert(obj);
  }

  void _signatureSelect(int index) {
    setState(() {
      _signatureIndex = index;
    });
  }

  void _signatureSwap(int index1, int index2) {
    var jsn = json.decode(_fileData);
    var proofs = jsn['proofs'] as List<dynamic>;
    var temp = proofs[index1];
    proofs[index1] = proofs[index2];
    proofs[index2] = temp;
    setState(() {
      _fileData = jsonEncodePretty(jsn);
    });
  }

  void _signatureDelete(int index) {
    var jsn = json.decode(_fileData);
    (jsn['proofs'] as List<dynamic>).removeAt(index);
    setState(() {
      _fileData = jsonEncodePretty(jsn);
    });
  }

  String _mergeData(String fileData, String fileDataToMerge) {
    var json1 = json.decode(fileData) as Map<String, dynamic>;
    var json2 = json.decode(fileDataToMerge) as Map<String, dynamic>;
    for (var key in json1.keys) {
      if (key == 'proofs')
        continue;
      if (json1[key] != json2[key]) {
        flushbarMsg(context, 'file did not match', category: MessageCategory.Warning);
        return fileData;
      }
    }
    var proofs1 = json1['proofs'] as List<dynamic>;
    var proofs2 = json2['proofs'] as List<dynamic>;
    for (var proof in proofs2)
      proofs1.add(proof);
    json1['proofs'] = proofs1;
    return jsonEncodePretty(json1);
  }

  void _loadFile() async {
    _filePath = await FilePicker.getFilePath(type: FileType.custom, allowedExtensions: ['json', 'json_signed']);
    if (_filePath == null) {
      return;
    }
    var file = File(_filePath);
    var fileData = await file.readAsString();
    if (_fileData != null)
      fileData = _mergeData(fileData, _fileData);
    setState(() {
      _fileData = fileData;
      _signatureIndex = null;
    });
    flushbarMsg(context, 'loaded "$_filePath');
  }

  void _signFile() async {
    // parse tx
    var res = json.decode(_fileData);
    if (_signatureIndex == null || _signatureIndex < 0 || _signatureIndex >= res['proofs'].length) {
      flushbarMsg(context, 'signature index not chosen', category: MessageCategory.Warning);
      return;
    }
    // serialize tx
    setState(() {
      _serializing = true;
    });
    var url = "https://zap-asset.herokuapp.com/tx_serialize";
    var body = jsonEncode({"testnet": widget.testnet, "tx": _fileData});
    var response = await http.post(url, headers: {"Content-Type": "application/json"}, body: body);
    if (response.statusCode != 200) {
      setState(() {
        _serializing = false;
      });
      flushbarMsg(context, 'failed request to "$url"', category: MessageCategory.Warning);
      return;
    }
    var jsnObj = json.decode(response.body);
    var txNonWitnessBytes = base64.decode(jsnObj['bytes']);
    setState(() {
      _serializing = false;
    });
    // get mnemonic
    var libzap = LibZap();
    var mnemonic = await Navigator.push<String>(context,
      MaterialPageRoute(builder: (context) => RecoveryForm(instructions: "Enter your recovery words to sign the transaction")));
    if (mnemonic == null || !libzap.mnemonicCheck(mnemonic)) {
      flushbarMsg(context, 'recovery words not valid', category: MessageCategory.Warning);
      return;
    }
    //sign tx
    var sig = libzap.messageSign(mnemonic, txNonWitnessBytes);
    if (!sig.success) {
      flushbarMsg(context, 'transaction signing failed', category: MessageCategory.Warning);
      return;
    }
    res['proofs'][_signatureIndex] = base58encode(sig.signature.toList());
    setState(() {
      _fileData = jsonEncodePretty(res);
    });
  }

  String _saveFile() {
    var filePath = '${_filePath}_signed';
    var file = File(filePath);
    file.writeAsStringSync(_fileData);
    flushbarMsg(context, 'saved "$filePath');
    return filePath;
  }

  void _shareFile() {
    var filePath = _saveFile();
    var fileName = path.basename(filePath);
    FlutterShare.shareFile(
      title: fileName,
      text: _fileData,
      filePath: filePath,
    );
  }

  void _broadcastFile() async {
    var node = LibZap().nodeGet();
    var url = '$node/transactions/broadcast';
    var response = await http.post(url, headers: {"Content-Type": "application/json"}, body: _fileData);
    if (response.statusCode != 200)
      flushbarMsg(context, 'failed request to "$url"', category: MessageCategory.Warning);
    else
      flushbarMsg(context, 'successful request to "$url"');
    setState(() {
      _broadcastResponse = response.body;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: backButton(context, color: Colors.black),
        title: Text("Multisig"),
      ),
      body: Center(
        child: Column( 
          children: <Widget>[
            SignaturePicker(_signatureSelect, _signatureSwap, _signatureDelete, _fileData, _signatureIndex),
            RaisedButton(onPressed: _loadFile, child: Text("Load File")),
            RaisedButton(onPressed: _fileData != null && !_serializing ? _signFile : null, child: Text(_serializing ? "Serializing..." : "Sign")),
            // disabled util https://github.com/miguelpruivo/flutter_file_picker/issues/234 is resolved
            RaisedButton(/*onPressed: _fileData != null ? _saveFile : null,*/ child: Text("Save File")),
            RaisedButton(onPressed: _fileData != null ? _shareFile : null, child: Text("Share File")),
            RaisedButton(onPressed: _fileData != null ? _broadcastFile : null, child: Text("Broadcast File")),
            Text(_broadcastResponse != null ? _broadcastResponse : '')
          ],
        ),
      )
    );
  }
}