import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

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
  
  MultisigScreen() : super();

  @override
  _MultisigState createState() => _MultisigState();
}

class _MultisigState extends State<MultisigScreen> {
  String _filePath;
  String _fileData;
  int _signatureIndex;

  _MultisigState();

  void _signatureIndexSelected(int index) {
    setState(() {
      print(index);
      _signatureIndex = index;
    });
  }

  void _loadFile() async {
    _filePath = await FilePicker.getFilePath(type: FileType.custom, allowedExtensions: ['json']);
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
    // get mnemonic
    var libzap = LibZap();
    var mnemonic = await Navigator.push<String>(context,
      MaterialPageRoute(builder: (context) => RecoveryForm(instructions: "Enter your recovery words to sign the transaction")));
    if (mnemonic == null || !libzap.mnemonicCheck(mnemonic)) {
      flushbarMsg(context, 'recovery words not valid', category: MessageCategory.Warning);
      return;
    }
    //TODO: sign tx
    res['proofs'][_signatureIndex] = "XXX TODO XXX";
    setState(() {
      _fileData = json.encode(res);
    });
  }

  void _saveFile() {
    var filePath = '${_filePath}_signed';
    var file = File(filePath);
    file.writeAsStringSync(_fileData);
    flushbarMsg(context, 'saved "$filePath');
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
            RaisedButton(onPressed: _fileData != null ? _signFile : null, child: Text("Sign")),
            RaisedButton(onPressed: _fileData != null ? _saveFile : null, child: Text("Save File")),
          ],
        ),
      )
    );
  }
}