import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';
import 'package:qr_reader/qr_reader.dart';
import 'package:flushbar/flushbar.dart';

import 'utils.dart';
import 'libzap.dart';

class SendForm extends StatefulWidget {
  final String _seed;
  final String _recipientOrUri;
  final Decimal _max;

  SendForm(this._seed, this._recipientOrUri, this._max) : super();

  @override
  SendFormState createState() {
    return SendFormState();
  }
}

class SendFormState extends State<SendForm> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = new TextEditingController();
  final _amountController = new TextEditingController();

  void setRecipientOrUri(String recipientOrUri) {
    var result = parseRecipientOrUri(recipientOrUri);
    if (result == recipientOrUri)
      _addressController.text = recipientOrUri;
    else if (result != null) {
      var parts = parseUri(recipientOrUri);
      _addressController.text = parts.item1;
      _amountController.text = parts.item3.toString();
    }
    else
      Flushbar(title: "Invalid QR Code", message: "Unable to decipher QR code data", duration: Duration(seconds: 2),)
        ..show(context);
  }

  void send() {
    if (_formKey.currentState.validate()) {
      var recipient = _addressController.text;
      var amount = (Decimal.parse(_amountController.text) * Decimal.fromInt(100)).toInt();
      var libzap = LibZap();
      //TODO: get fee from network
      // - allow to specify attachment
      // - update widget._max with network fee
      var spendTx = libzap.transactionCreate(widget._seed, recipient, amount, 1, "");

      Flushbar(title: "Tx", message: "${spendTx.success} ${spendTx.data.length}", duration: Duration(seconds: 2),)
        ..show(context);

      var tx = libzap.transactionBroadcast(spendTx);
      if (tx != null)
        Flushbar(title: "Tx Broadcast", message: "${tx.id}", duration: Duration(seconds: 2),)
          ..show(context);
      else
        Flushbar(title: "Tx Broadcast Failed", message: ":(", duration: Duration(seconds: 2),)
          ..show(context);

      //Navigator.pop(context);
    }
    else
      Flushbar(title: "Validation failed", message: "correct data please", duration: Duration(seconds: 2),)
        ..show(context);
  }

  @protected
  @mustCallSuper
  void initState() {
    super.initState();
    setRecipientOrUri(widget._recipientOrUri);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          new Stack(alignment: const Alignment(1.0, 1.0), children: <Widget>[
            new TextFormField(
              controller: _addressController,
              keyboardType: TextInputType.text,
              decoration: new InputDecoration(labelText: 'Recipient Address'),
              validator: (value) {
                if (value.isEmpty) {
                  return 'Please enter a value';
                }
                var libzap = new LibZap();
                var res = libzap.addressCheck(value);
                if (!res) {
                  return 'Invalid address';
                }
                return null;
              },
            ),
            new FlatButton(
                onPressed: () {
                  var qrCode = new QRCodeReader().scan();
                  qrCode.then((value) {
                    if (value != null)
                      setRecipientOrUri(value);
                  });
                },
                child: new Icon(Icons.center_focus_weak))
          ]),
          TextFormField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: new InputDecoration(labelText: 'Amount'),
            validator: (value) {
              if (value.isEmpty) {
                return 'Please enter a value';
              }
              final dv = Decimal.parse(value);
              if (dv > widget._max) {
                return 'Max value is ${widget._max}';
              }
              if (dv <= Decimal.fromInt(0)) {
                return 'Please enter a value greater then zero';
              }
              return null;
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: RaisedButton.icon(
                onPressed: send,
                icon: Icon(Icons.send),
                label: Text('Submit')),
          ),
          RaisedButton.icon(
              onPressed: () { Navigator.pop(context); },
              icon: Icon(Icons.cancel),
              label: Text('Cancel')),
        ],
      ),
    );
  }
}
