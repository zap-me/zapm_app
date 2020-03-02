import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';
import 'package:flushbar/flushbar.dart';

import 'merchant.dart';
import 'libzap.dart';
import 'utils.dart';

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

  void send() async {
    if (_formKey.currentState.validate()) {
      // send parameters
      var amountText = _amountController.text;
      var amountDec = Decimal.parse(amountText);
      var amount = (amountDec * Decimal.fromInt(100)).toInt();
      var fee = (widget._fee * Decimal.fromInt(100)).toInt();
      var lz = LibZap();
      if (!lz.addressCheck(_rates.settlementAddress)) {
        Flushbar(title: "Unable to create settlement", message: "Settlement address is invalid", duration: Duration(seconds: 2),)
        ..show(context);
        return;
      }
      // get amount to receive
      var amountReceive = amountDec * (Decimal.fromInt(1) - _rates.merchantRate);
      // double check with user
      if (await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return SimpleDialog(
              title: Text("Confirm Zap Settlement Amount (receiving $amountReceive NZD)"),
              children: <Widget>[
                SimpleDialogOption(
                  onPressed: () { Navigator.pop(context, true); },
                  child: Text("Yes send $amountText ZAP"),
                ),
                SimpleDialogOption(
                  onPressed: () { Navigator.pop(context, false); },
                  child: const Text("Cancel"),
                ),
              ],
            );
          }
      )) {
        // create settlement
        showAlertDialog(context, "Creating settlement..");
        var bankToken = "";
        for (var bank in _banks) {
          if (bank.accountNumber == _bankAccount) {
            bankToken = bank.token;
          }
        }
        var settlement = await merchantSettlement(amountDec, bankToken);
        Navigator.pop(context);
        if (settlement == null) {
          Flushbar(title: "Failed to create settlement", message: ":(", duration: Duration(seconds: 2),)
            ..show(context);
          return;
        }
        // send funds
        var libzap = LibZap();
        var spendTx = libzap.transactionCreate(widget._seed, _rates.settlementAddress, amount, fee, settlement.token);
        if (!spendTx.success) {
          Flushbar(title: "Failed to create Tx", message: ":(", duration: Duration(seconds: 2),)
            ..show(context);
            return;
        }
        showAlertDialog(context, "Sending settlement transaction..");
        var tx = await LibZap.transactionBroadcast(spendTx);
        if (tx == null) {
          Flushbar(title: "Failed to create broadcast Tx", message: ":(", duration: Duration(seconds: 2),)
            ..show(context);
            Navigator.pop(context);
            return;
        }
        Navigator.pop(context);
        showAlertDialog(context, "Updating settlement..");
        var res = await merchantSettlementUpdate(settlement.token, tx.id);
        if (res == null) {
          Flushbar(title: "Failed to update settlement", message: ":(", duration: Duration(seconds: 2),)
            ..show(context);
            Navigator.pop(context);
            return;
        }
        Navigator.pop(context);
        Flushbar(title: "Settlement created", message: settlement.token, duration: Duration(seconds: 2),)
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
    () async {
      await Future.delayed(Duration.zero);
      // get rates
      showAlertDialog(context, "Getting rates..");
      var rates = await merchantRates();
      Navigator.pop(context);
      if (rates == null) {
        Flushbar(title: "Unable to get rates", message: "Could not get rates", duration: Duration(seconds: 2),)
        ..show(context);
        return;
      }
      // get banks
      showAlertDialog(context, "Getting banks..");
      var banks = await merchantBanks();
      Navigator.pop(context);
      if (banks == null) {
        Flushbar(title: "Unable to get bank accounts", message: "Could not get bank accounts", duration: Duration(seconds: 2),)
        ..show(context);
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
        Flushbar(title: "User has no bank accounts", message: "Set up a bank account in the web interface", duration: Duration(seconds: 2),)
        ..show(context);
        return;
      } 
    }();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
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
          DropdownButton<String>(
            hint: Text('Bank Account'),
            value: _bankAccount,
            items: _banks == null ? null : _banks.map((e) => DropdownMenuItem(child: Text(e.accountNumber), value: e.accountNumber,)).toList(),
            onChanged: (e) {
              setState(() {
                _bankAccount = e;
              });
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: RaisedButton.icon(
                onPressed: _bankAccount == null ? null : send,   
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
