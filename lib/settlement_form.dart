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
  final _bankAccountController = new TextEditingController();

  void send() async {
    if (_formKey.currentState.validate()) {
      // send parameters
      var amountText = _amountController.text;
      var amountDec = Decimal.parse(amountText);
      var amount = (amountDec * Decimal.fromInt(100)).toInt();
      var fee = (widget._fee * Decimal.fromInt(100)).toInt();
      var bankAccount = _bankAccountController.text;
      // get rates
      showAlertDialog(context, "Getting rates..");
      var rates = await merchantRates();
      Navigator.pop(context);
      if (rates == null) {
        Flushbar(title: "Unable to create settlement", message: "Could not get rates", duration: Duration(seconds: 2),)
        ..show(context);
        return;
      }
      var lz = LibZap();
      if (!lz.addressCheck(rates.settlementAddress)) {
        Flushbar(title: "Unable to create settlement", message: "Settlement address is invalid", duration: Duration(seconds: 2),)
        ..show(context);
        return;
      }
      // get amount to receive
      var amountReceive = amountDec * (Decimal.fromInt(1) - rates.merchantRate);
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
        var settlement = await merchantSettlement(amountDec, bankAccount);
        Navigator.pop(context);
        if (settlement == null) {
          Flushbar(title: "Failed to create settlement", message: ":(", duration: Duration(seconds: 2),)
            ..show(context);
          return;
        }
        // send funds
        var libzap = LibZap();
        var spendTx = libzap.transactionCreate(widget._seed, rates.settlementAddress, amount, fee, settlement.token);
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
          TextFormField(
            controller: _bankAccountController,
            keyboardType: TextInputType.text,
            decoration: new InputDecoration(labelText: 'Bank Account'),
            validator: (value) {
              if (value.isEmpty) {
                return 'Please enter a value';
              }
              //TODO: validate bank account more!!
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
