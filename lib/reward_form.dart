import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_icons/flutter_icons.dart';

import 'package:zapdart/utils.dart';
import 'package:zapdart/widgets.dart';

import 'config.dart';
import 'claiming_form.dart';
import 'prefs.dart';
import 'paydb.dart';
import 'qrscan.dart';

class RewardForm extends StatefulWidget {
  final String _seed;
  final Decimal _fee;
  final Decimal _max;

  RewardForm(this._seed, this._fee, this._max) : super();

  @override
  RewardFormState createState() {
    return RewardFormState();
  }
}

class RewardFormState extends State<RewardForm> {
  final _formKey = GlobalKey<FormState>();
  final _paydbRecipientController = TextEditingController();
  final _amountController = TextEditingController();
  final _msgController = TextEditingController();

  void scanRecipient() async {
    var data = await QrScan.scan(context);
    if (data != null) _paydbRecipientController.text = data;
  }

  void send() async {
    if (_formKey.currentState == null) return;
    if (_formKey.currentState!.validate()) {
      // send parameters
      var amountText = _amountController.text;
      var amountDec = Decimal.parse(amountText);
      var amount = (amountDec * Decimal.fromInt(100)).toInt();
      var fee = (widget._fee * Decimal.fromInt(100)).toInt();
      var msg = _msgController.text;
      // double check with user
      var yesSend = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return SimpleDialog(
              title: const Text("Confirm $AssetShortName Reward Amount"),
              children: <Widget>[
                SimpleDialogOption(
                  onPressed: () {
                    Navigator.pop(context, true);
                  },
                  child: Text("Yes send $amountText $AssetShortNameUpper"),
                ),
                SimpleDialogOption(
                  onPressed: () {
                    Navigator.pop(context, false);
                  },
                  child: const Text("Cancel"),
                ),
              ],
            );
          });
      if (yesSend != null && yesSend) {
        // check pin
        if (!await pinCheck(context, await Prefs.pinGet())) {
          return;
        }
        // start claim process
        switch (AppTokenType) {
          case TokenType.Waves:
            var sentFunds = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      ClaimingForm(amountDec, widget._seed, amount, fee, msg)),
            );
            if (sentFunds != null && sentFunds) Navigator.pop(context, true);
            break;
          case TokenType.PayDB:
            showAlertDialog(context, 'sending reward..');
            //TODO: get reason and category values to choose from from the server
            var reason = 'Customer reward';
            var category = 'marketing';
            var result = await paydbRewardCreate(reason, category,
                _paydbRecipientController.text, amount, _msgController.text);
            Navigator.pop(context);
            if (result != PayDbError.None)
              flushbarMsg(context, 'reward failed',
                  category: MessageCategory.Warning);
            else
              alert(context, 'Success', 'Reward successfully sent');
        }
      }
    } else
      flushbarMsg(context, 'validation failed',
          category: MessageCategory.Warning);
  }

  @protected
  @mustCallSuper
  void initState() {
    super.initState();
    _msgController.text = "Thank you for shopping at Qwik-e-mart!";
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppTokenType == TokenType.PayDB
              ? TextFormField(
                  controller: _paydbRecipientController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                      labelText: 'Recipient',
                      suffixIcon: IconButton(
                          icon: Icon(MaterialCommunityIcons.qrcode_scan),
                          onPressed: scanRecipient)),
                  validator: (value) {
                    if (value == null || value.isEmpty)
                      return 'Please enter a value';
                    if (!paydbRecipientCheck(_paydbRecipientController.text))
                      return 'Invalid recipient';
                    return null;
                  },
                )
              : SizedBox(),
          TextFormField(
            controller: _amountController,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: new InputDecoration(labelText: 'Amount'),
            validator: (value) {
              if (value == null || value.isEmpty) {
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
            controller: _msgController,
            keyboardType: TextInputType.text,
            decoration: new InputDecoration(labelText: 'Message'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: raisedButtonIcon(
                onPressed: send, icon: Icon(Icons.send), label: Text('Submit')),
          ),
          raisedButtonIcon(
              onPressed: () {
                Navigator.pop(context, false);
              },
              icon: Icon(Icons.cancel),
              label: Text('Cancel')),
        ],
      ),
    );
  }
}
