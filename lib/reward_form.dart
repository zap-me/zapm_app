import 'package:FlutterZap/merchant.dart';
import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';
import 'package:flushbar/flushbar.dart';

import 'utils.dart';
import 'libzap.dart';
import 'claiming_form.dart';

class RewardForm extends StatefulWidget {
  final bool _testnet;
  final String _seed;
  final Decimal _fee;
  final Decimal _max;

  RewardForm(this._testnet, this._seed, this._fee, this._max) : super();

  @override
  RewardFormState createState() {
    return RewardFormState();
  }
}

class RewardFormState extends State<RewardForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = new TextEditingController();
  final _attachmentController = new TextEditingController();

  void send() async {
    if (_formKey.currentState.validate()) {
      // send parameters
      var amountText = _amountController.text;
      var amountDec = Decimal.parse(amountText);
      var amount = (amountDec * Decimal.fromInt(100)).toInt();
      var fee = (widget._fee * Decimal.fromInt(100)).toInt();
      var attachment = _attachmentController.text;
      // double check with user
      if (await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return SimpleDialog(
              title: const Text("Confirm Zap Reward Amount"),
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
        var claimCode = await merchantRegister(amountDec);
        if (claimCode != null) {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ClaimingForm(claimCode, widget._seed, amount, fee, attachment)),
          );
        }
        else
          Flushbar(title: "Failed to create claim code", message: ":(", duration: Duration(seconds: 2),)
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
    _attachmentController.text = "Thank you for shopping at Qwik-e-mart!";
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
            controller: _attachmentController,
            keyboardType: TextInputType.text,
            decoration: new InputDecoration(labelText: 'Attachment'),
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
