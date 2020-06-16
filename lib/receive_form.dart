import 'dart:async';
import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';

import 'prefs.dart';
import 'qrwidget.dart';
import 'libzap.dart';
import 'merchant.dart';
import 'widgets.dart';

class ReceiveForm extends StatefulWidget {
  final bool _testnet;
  final String _address;
  
  ReceiveForm(this._testnet, this._address) : super();

  @override
  ReceiveFormState createState() {
    return ReceiveFormState();
  }
}

const String RATES_FAILED = 'rates failed';
const String NO_API_KEY = 'no API KEY';

class ReceiveFormState extends State<ReceiveForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _uriController = TextEditingController();
  String _uri;
  String _amountType = 'nzd';
  bool _validAmount = true;
  StreamSubscription<String> _uriSub;
  Rates _rates;

  Future<String> makeUri() async {
    if (_rates == null) {
      try {
        _rates = await merchantRates();
      } on NoApiKeyException {
        return NO_API_KEY;
      } 
    }
    if (_rates == null) {
      return RATES_FAILED;
    }
    var amount = Decimal.fromInt(0);
    try {
      amount = Decimal.parse(_amountController.text);
    }
    catch (e) {}
    if (_amountType == 'nzd') {
      amount = equivalentCustomerZapForNzd(amount, _rates);
    }
    var deviceName = await Prefs.deviceNameGet();
    return LibZap.paymentUriDec(widget._testnet, widget._address, amount, deviceName);
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
    return WillPopScope(child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Center(heightFactor: 5, child: Text('scan QR code', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
              Center(child: Card(
                margin: EdgeInsets.all(20),
                child: _uri != RATES_FAILED && _uri != NO_API_KEY && _validAmount ? QrWidget(_uri, size: 240, version: 10) : Container(width: 240, height: 240))
              ),
              TextFormField(
                controller: _uriController,
                enabled: false,
                decoration: InputDecoration(labelText: 'receive URI'),
                maxLines: 4,
                style: TextStyle(fontSize: 12),
              ),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(labelText: 'amount',
                  suffixIcon: FlatButton(
                    onPressed: () {
                      setState(() {
                        if (_amountType == 'zap')
                          _amountType = 'nzd';
                        else
                          _amountType = 'zap';                
                      });
                      updateUriUi();
                    },
                    child: Text(_amountType, style: TextStyle(color: zapgreen)))
                ),
                style: _validAmount ? null : TextStyle(color: Colors.red),
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
                onChanged: (value) {
                  if (value.isEmpty) {
                    setState(() {
                      _validAmount = true;
                    });
                  } else {
                    var valid = Decimal.tryParse(value) != null;
                    setState(() {
                      _validAmount = valid;
                    });
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.only(top: 24.0),
                child: RoundedButton(() => Navigator.pop(context), zapblue, Colors.white, 'cancel', borderColor: zapblue, minWidth: MediaQuery.of(context).size.width / 2),
              ),
            ],
          ),
        )
      ),
      onWillPop: canLeave,
    );
  }
}
