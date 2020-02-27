import 'dart:async';
import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';

import 'qrwidget.dart';
import 'libzap.dart';
import 'merchant.dart';

class ReceiveForm extends StatefulWidget {
  final VoidCallback onClosed;
  final bool _testnet;
  final String _address;
  
  ReceiveForm(this.onClosed, this._testnet, this._address) : super();

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
  String _amountType = "ZAP";
  StreamSubscription<String> _uriSub;

  Future<String> makeUri() async {
    var amount = Decimal.fromInt(0);
    try {
      amount = Decimal.parse(_amountController.text);
    }
    catch (e) {}
    if (_amountType == "NZD") {
      try {
        amount = await equivalentCustomerZapForNzd(amount);
      }
      catch (e) {
        return e.toString();
      }
    }
    return LibZap.paymentUriDec(widget._testnet, widget._address, amount);
  }

  void updateUriUi() {
    setState(() {
      _uri = "...";
      _uriController.text = _uri;
    });
    
    _uriSub?.cancel();
    _uriSub = makeUri().asStream().listen((uri) {
      setState(() {
        _uri = uri;
        _uriController.text = uri;
      });
    });
  }

  void onAmountChanged() {
    updateUriUi();
  }

  Future<bool> canLeave() {
    _uriSub?.cancel();
    return Future<bool>.value(true); 
  }

  ReceiveFormState() : super() {
    _amountController.addListener(onAmountChanged);
  }

  @protected
  @mustCallSuper
  void initState() {
    super.initState();
    updateUriUi();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Center(
              child: QrWidget(_uri, size: 260, version: 8)
            ),
            new TextFormField(
              controller: _uriController,
              enabled: false,
              decoration: new InputDecoration(labelText: 'Receive URI'),
              maxLines: 5,
            ),
            new Stack(alignment: const Alignment(1.0, 1.0), children: <Widget>[
              new TextFormField(
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
              new FlatButton(
                  onPressed: () {
                    setState(() {
                      if (_amountType == "ZAP")
                        _amountType = "NZD";
                      else
                        _amountType = "ZAP";                
                    });
                    updateUriUi();
                  },
                  child: new Text(_amountType))
            ]),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: RaisedButton.icon(
                  onPressed: widget.onClosed,
                  icon: Icon(Icons.close),
                  label: Text('Close')),
            ),
          ],
        ),
      ),
      onWillPop: canLeave,
    );
  }
}
