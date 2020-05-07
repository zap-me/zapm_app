import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';

import 'merchant.dart';
import 'libzap.dart';
import 'utils.dart';
import 'widgets.dart';
import 'prefs.dart';

class SettlementForm extends StatefulWidget {
  final bool _testnet;
  final String _seed;
  final Decimal _fee;
  final Decimal _max;

  SettlementForm(this._testnet, this._seed, this._fee, this._max) : super();

  @override
  SettlementFormState createState() {
    return SettlementFormState();
  }
}

class SettlementFormState extends State<SettlementForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = new TextEditingController();
  Rates _rates;
  List<Bank> _banks;
  String _bankAccount;

  void send(BuildContext context) async {
    if (_formKey.currentState.validate()) {
      // send parameters
      var amountText = _amountController.text;
      var amountDec = Decimal.parse(amountText);
      var amount = (amountDec * Decimal.fromInt(100)).toInt();
      var fee = (widget._fee * Decimal.fromInt(100)).toInt();
      var lz = LibZap();
      if (!lz.addressCheck(_rates.settlementAddress)) {
        flushbarMsg(context, 'unable to create settlement', category: MessageCategory.Warning);
        return;
      }
      // get amount to receive
      var amountReceive = amountDec / (Decimal.fromInt(1) + _rates.merchantRate);
      // double check with user
      if (await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return SimpleDialog(
              title: Column(children: <Widget>[
                Text('confirm ZAP settlement amount', style: TextStyle(fontSize: 16)),
                Text('receiving ${amountReceive.toStringAsFixed(2)} NZD', style: TextStyle(fontSize: 16, color: zapblue))
              ]),
              children: <Widget>[
                SimpleDialogOption(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: RoundedButton(() => Navigator.pop(context, true), Colors.white, zapblue, 'yes send ${amountDec.toStringAsFixed(2)} zap'),
                ),
                SimpleDialogOption(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: RoundedButton(() => Navigator.pop(context, false), zapblue, Colors.white, 'cancel', borderColor: zapblue),
                )
              ],
            );
          }
      )) {
        // check pin
        if (!await pinCheck(context)) {
          return;
        }
        // create settlement
        showAlertDialog(context, 'creating settlement...');
        var bankToken = '';
        for (var bank in _banks) {
          if (bank.accountNumber == _bankAccount) {
            bankToken = bank.token;
          }
        }
        var result = await merchantSettlement(amountDec, bankToken);
        Navigator.pop(context);
        if (result.settlement == null) {
          flushbarMsg(context, 'failed to create settlement (${result.error})', category: MessageCategory.Warning);
          return;
        }
        // send funds
        var libzap = LibZap();
        var deviceName = await Prefs.deviceNameGet();
        var attachment = formatAttachment(deviceName, result.settlement.token, 'settlement');
        var spendTx = libzap.transactionCreate(widget._seed, _rates.settlementAddress, amount, fee, attachment);
        if (!spendTx.success) {
          flushbarMsg(context, 'failed to create transaction', category: MessageCategory.Warning);
            return;
        }
        showAlertDialog(context, 'sending settlement transaction...');
        var tx = await LibZap.transactionBroadcast(spendTx);
        if (tx == null) {
          flushbarMsg(context, 'failed to broadcast transaction', category: MessageCategory.Warning);
            Navigator.pop(context);
            return;
        }
        Navigator.pop(context);
        showAlertDialog(context, 'updating settlement...');
        result = await merchantSettlementUpdate(result.settlement.token, tx.id);
        if (result.settlement == null) {
          flushbarMsg(context, 'failed to update settlement (${result.error})', category: MessageCategory.Warning);
            Navigator.pop(context);
            return;
        }
        Navigator.pop(context);
        showAlertDialog(context, 'completed');
        Future.delayed(Duration(milliseconds: 500), () {
          Navigator.pop(context);
          Navigator.pop(context); // close settlement form
          flushbarMsg(context, 'settlement created');
        });
        // alert server to update merchant tx table
        merchantTx();
        return;
      }
    }
    else
      flushbarMsg(context, 'validation failed', category: MessageCategory.Warning);
  }

  @protected
  @mustCallSuper
  void initState() {
    super.initState();
    () async {
      if (!await hasApiKey()) {
        flushbarMsg(context, 'no API KEY', category: MessageCategory.Warning);
        return;
      }
      // get rates
      showAlertDialog(context, 'getting rates...');
      var rates = await merchantRates();
      Navigator.pop(context);
      if (rates == null) {
        flushbarMsg(context, 'unable to get rates', category: MessageCategory.Warning);
        return;
      }
      // get banks
      showAlertDialog(context, 'getting banks...');
      var banks = await merchantBanks();
      Navigator.pop(context);
      if (banks == null) {
        flushbarMsg(context, 'unable to get bank accounts', category: MessageCategory.Warning);
        return;
      }
      if (banks.length > 0) {
        setState(() {
          _rates = rates;
          _banks = banks;
          for (var bank in banks) {
            if (_bankAccount == null || bank.defaultAccount) {
              _bankAccount = bank.accountNumber;
            }
          }
        });
      } else {
        flushbarMsg(context, 'user has no bank accounts', category: MessageCategory.Warning);
        return;
      } 
    }();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Center(heightFactor: 3, child: Text('make settlement\n  ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
          TextFormField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            decoration: new InputDecoration(labelText: 'amount'),
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
          DropdownButton<String>(
            hint: Text('bank account'),
            value: _bankAccount,
            items: _banks == null ? null : _banks.map((e) => DropdownMenuItem(child: Text(e.accountNumber), value: e.accountNumber,)).toList(),
            onChanged: (e) {
              setState(() {
                _bankAccount = e;
              });
            },
          ),
          Padding(
            padding: const EdgeInsets.only(top: 24.0),
            child: RoundedButton(() {
              if (_bankAccount == null)
                return;
              send(context);
            }, Colors.white, zapblue, 'submit', minWidth: MediaQuery.of(context).size.width / 2, holePunch: true)
          ),
          RoundedButton(() => Navigator.pop(context), zapblue, Colors.white, 'cancel', borderColor: zapblue, minWidth: MediaQuery.of(context).size.width / 2),
        ],
      ),
    );
  }
}
