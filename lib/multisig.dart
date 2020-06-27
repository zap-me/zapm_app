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
  final void Function(int) signatureSelected;
  final String fileData;
  final int signatureIndex;

  SignaturePicker(this.signatureSelected, this.fileData, this.signatureIndex) : super();

  @override
  Widget build(BuildContext context) {
    var sigButtons = <Widget>[];
    if (fileData != null) {
      var res = json.decode(fileData);
      for (var i = 0; i < res['proofs'].length; i++) {
        sigButtons.add(FlatButton(onPressed: () => signatureSelected(i), 
          child: Text(res['proofs'][i], style: i == signatureIndex ? TextStyle(color: Colors.red) : null)));
      }
    }
    return Column(
      children: sigButtons
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

  _MultisigState();

  void _signatureIndexSelected(int index) {
    setState(() {
      print(index);
      _signatureIndex = index;
    });
  }

  void _loadFile() async {
    _filePath = await FilePicker.getFilePath(type: FileType.custom, allowedExtensions: ['json']);
    if (_filePath == null) {
      return;
    }
    var file = File(_filePath);
    var fileData = await file.readAsString();
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
      _fileData = JsonEncoder.withIndent('    ').convert(res);
    });
  }

  String _saveFile() {
    var filePath = '${_filePath}_signed';
    var file = File(filePath);
    file.writeAsStringSync(_fileData);
    flushbarMsg(context, 'saved "$filePath');
    return filePath;
  }

  void _share() {
    var filePath = _saveFile();
    var fileName = path.basename(filePath);
    FlutterShare.shareFile(
      title: fileName,
      filePath: filePath,
    );
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
            SignaturePicker(_signatureIndexSelected, _fileData, _signatureIndex),
            RaisedButton(onPressed: _loadFile, child: Text("Load File")),
            RaisedButton(onPressed: _fileData != null && !_serializing ? _signFile : null, child: Text(_serializing ? "Serializing..." : "Sign")),
            // disabled util https://github.com/miguelpruivo/flutter_file_picker/issues/234 is resolved
            RaisedButton(/*onPressed: _fileData != null ? _saveFile : null,*/ child: Text("Save File")),
            RaisedButton(onPressed: _fileData != null ? _share : null, child: Text("Share File")),
          ],
        ),
      )
    );
  }
}