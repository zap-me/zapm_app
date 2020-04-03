import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';
import 'package:qrcode_reader/qrcode_reader.dart';
import 'package:flushbar/flushbar.dart';

import 'utils.dart';
import 'libzap.dart';
import 'sending_form.dart';
import 'widgets.dart';

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
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();
  final _attachmentController = TextEditingController();

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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Center(heightFactor: 5, child: Text('send zap', style: Theme.of(context).textTheme.subtitle2, textAlign: TextAlign.center)),
          TextFormField(
            controller: _addressController,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(labelText: 'recipient address',
              suffixIcon: FlatButton.icon(
                onPressed: () {
                  var qrCode = QRCodeReader().scan();
                  qrCode.then((value) {
                    if (value != null || !setRecipientOrUri(value))
                      Flushbar(title: "Invalid QR Code", message: "Unable to decipher QR code data", duration: Duration(seconds: 2),)
                        ..show(context);
                  });
                },
                icon: Image.asset('assets/icon-qr-yellow.png', height: 14),
                label: Text('scan', style: TextStyle(color: zapyellow))
              )
            ),
            validator: (value) {
              if (value.isEmpty) {
                return 'Please enter a value';
              }
              var libzap = LibZap();
              var res = libzap.addressCheck(value);
              if (!res) {
                return 'Invalid address';
              }
              return null;
            },
          ),
          TextFormField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'amount',
              suffixIcon: FlatButton(onPressed: () => _amountController.text = '${widget._max - widget._fee}', child: Text('max', style: TextStyle(color: zapyellow)))),
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
          TextFormField(
            controller: _attachmentController,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(labelText: 'attachment'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: RoundedButton(send, Colors.white, zapyellow, 'send zap')
          ),
          RoundedButton(() => Navigator.pop(context), zapblue, Colors.white, 'cancel', borderColor: zapblue),
        ],
      ),
    );
  }
}
