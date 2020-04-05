import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';

import 'merchant.dart';
import 'libzap.dart';
import 'utils.dart';
import 'widgets.dart';

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
        // check pin
        if (!await pinCheck(context)) {
          return;
        }
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
          flushbarMsg(context, 'failed to create settlement', category: MessageCategory.Warning);
          return;
        }
        // send funds
        var libzap = LibZap();
        var spendTx = libzap.transactionCreate(widget._seed, _rates.settlementAddress, amount, fee, settlement.token);
        if (!spendTx.success) {
          flushbarMsg(context, 'failed to create transaction', category: MessageCategory.Warning);
            return;
        }
        showAlertDialog(context, "Sending settlement transaction..");
        var tx = await LibZap.transactionBroadcast(spendTx);
        if (tx == null) {
          flushbarMsg(context, 'failed to create broadcast transaction', category: MessageCategory.Warning);
            Navigator.pop(context);
            return;
        }
        Navigator.pop(context);
        showAlertDialog(context, "Updating settlement..");
        var res = await merchantSettlementUpdate(settlement.token, tx.id);
        if (res == null) {
          flushbarMsg(context, 'failed to update settlement', category: MessageCategory.Warning);
            Navigator.pop(context);
            return;
        }
        Navigator.pop(context);
        flushbarMsg(context, 'settlement created');
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
      await Future.delayed(Duration.zero);
      // get rates
      showAlertDialog(context, "Getting rates..");
      var rates = await merchantRates();
      Navigator.pop(context);
      if (rates == null) {
        flushbarMsg(context, 'unable to get rates', category: MessageCategory.Warning);
        return;
      }
      // get banks
      showAlertDialog(context, "Getting banks..");
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
