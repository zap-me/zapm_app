import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';
import 'package:qrcode_reader/qrcode_reader.dart';
import 'package:flushbar/flushbar.dart';

import 'utils.dart';
import 'libzap.dart';
import 'sending_form.dart';

class SendForm extends StatefulWidget {
  final bool _testnet;
  final String _seed;
  final Decimal _fee;
  final String _recipientOrUri;
  final Decimal _max;

  SendForm(this._testnet, this._seed, this._fee, this._recipientOrUri, this._max) : super();

  @override
  SendFormState createState() {
    return SendFormState();
  }
}

class SendFormState extends State<SendForm> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = new TextEditingController();
  final _amountController = new TextEditingController();
  final _attachmentController = new TextEditingController();

  bool setRecipientOrUri(String recipientOrUri) {
    var result = parseRecipientOrWavesUri(widget._testnet, recipientOrUri);
    if (result == recipientOrUri) {
      _addressController.text = recipientOrUri;
      return true;
    }
    else if (result != null) {
      var parts = parseWavesUri(widget._testnet, recipientOrUri);
      _addressController.text = parts.address;
      _amountController.text = parts.amount.toString();
      _attachmentController.text = parts.attachment;
      return true;
    }
    return false;
  }

  void send() async {
    if (_formKey.currentState.validate()) {
      // send parameters
      var recipient = _addressController.text;
      var amountText = _amountController.text;
      var amount = (Decimal.parse(amountText) * Decimal.fromInt(100)).toInt();
      var fee = (widget._fee * Decimal.fromInt(100)).toInt();
      var attachment = _attachmentController.text;
      // double check with user
      if (await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return SimpleDialog(
              title: const Text("Confirm Send"),
              children: <Widget>[
                SimpleDialogOption(
                  onPressed: () { Navigator.pop(context, true); },
                  child: Text("Yes send $amountText ZAP to $recipient"),
                ),
                SimpleDialogOption(
                  onPressed: () { Navigator.pop(context, false); },
                  child: const Text("Cancel"),
                ),
              ],
            );
          }
      )) {
        // check pin
        if (!await pinCheck(context)) {
          return;
        }
        // create tx
        var libzap = LibZap();
        var spendTx = libzap.transactionCreate(widget._seed, recipient, amount, fee, attachment);
        if (spendTx.success) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => SendingForm(spendTx)),
          );
        }
        else
          Flushbar(title: "Failed to create Tx", message: ":(", duration: Duration(seconds: 2),)
            ..show(context);
      }
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
                    if (!setRecipientOrUri(value))
                      Flushbar(title: "Invalid QR Code", message: "Unable to decipher QR code data", duration: Duration(seconds: 2),)
                        ..show(context);
                  });
                },
                child: new Icon(Icons.center_focus_weak))
          ]),
          new Stack(alignment: const Alignment(1.0, 1.0), children: <Widget>[
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: new InputDecoration(labelText: 'Amount'),
              validator: (value) {
                if (value.isEmpty) {
                  return 'Please enter a value';
                }
                final dv = Decimal.parse(value);
                if (dv > widget._max - widget._fee) {
                  return 'Max available to send is ${widget._max - widget._fee}';
                }
                if (dv <= Decimal.fromInt(0)) {
                  return 'Please enter a value greater then zero';
                }
                return null;
              },
            ),
            new FlatButton(
                onPressed: () {
                  _amountController.text = "${widget._max - widget._fee}";
                },
                child: new Icon(Icons.arrow_upward))
          ]),
          TextFormField(
            controller: _attachmentController,
            keyboardType: TextInputType.text,
            decoration: new InputDecoration(labelText: 'Attachment'),
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
