import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';

import 'qrwidget.dart';
import 'libzap.dart';

class ReceiveForm extends StatefulWidget {
  final VoidCallback onClosed;
  final String _address;

  ReceiveForm(this.onClosed, this._address) : super();

  @override
  ReceiveFormState createState() {
    return ReceiveFormState();
  }
}

class ReceiveFormState extends State<ReceiveForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = new TextEditingController();
  final _uriController = new TextEditingController();
  String _uri;

  void makeUri() {
    var amount = Decimal.fromInt(0);
    try {
      amount = Decimal.parse(_amountController.text);
    }
    catch (e) {}
    _uri = LibZap.paymentUriDec(widget._address, amount);
    _uriController.text = _uri;
  }

  void onAmountChanged() {
    setState(() {
      makeUri();
    });
  }

  ReceiveFormState() : super() {
    _amountController.addListener(onAmountChanged);
  }

  @protected
  @mustCallSuper
  void initState() {
    super.initState();
    makeUri();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Center(
            child: QrWidget(_uri)
          ),
          new TextFormField(
            controller: _uriController,
            enabled: false,
            decoration: new InputDecoration(labelText: 'Receive URI'),
            maxLines: 5,
          ),
          TextFormField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: new InputDecoration(labelText: 'Amount'),
            validator: (value) {
              if (value.isEmpty) {
                return 'Please enter a value';
              }
              final dv = Decimal.parse(value);
              if (dv <= Decimal.fromInt(0)) {
                return 'Please enter a value greater then zero';
              }
              return null;
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: RaisedButton.icon(
                onPressed: widget.onClosed,
                icon: Icon(Icons.close),
                label: Text('Close')),
          ),
        ],
      ),
    );
  }
}
