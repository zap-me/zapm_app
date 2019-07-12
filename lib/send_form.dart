import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';
import 'package:qr_reader/qr_reader.dart';
import 'package:flushbar/flushbar.dart';

import 'utils.dart';

class SendForm extends StatefulWidget {
  final VoidCallback _onCancelled;
  final VoidCallback _onSend;
  final String _recipientOrUri;
  final Decimal _max;

  SendForm(this._onCancelled, this._onSend, this._recipientOrUri, this._max) : super();

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
    var parts = parseUri(recipientOrUri);
    if (parts.item5 == INVALID_WAVES_URI)
      _addressController.text = recipientOrUri;
    else {
      _addressController.text = parts.item1;
      _amountController.text = parts.item3.toString();
    }
    if (parts.item5 == INVALID_ASSET_ID)
      Flushbar(title: "Invalid URI", message: "The asset id does not match ZAP", duration: Duration(seconds: 1),)
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
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: RaisedButton.icon(
                onPressed: () {
                  if (_formKey.currentState.validate()) {
                    widget._onSend();
                  }
                },
                icon: Icon(Icons.send),
                label: Text('Submit')),
          ),
          RaisedButton.icon(
              onPressed: widget._onCancelled,
              icon: Icon(Icons.cancel),
              label: Text('Cancel')),
        ],
      ),
    );
  }
}
