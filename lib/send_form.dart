import 'dart:core';
import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:qrcode_reader/qrcode_reader.dart';

import 'config.dart';
import 'zapdart/utils.dart';
import 'zapdart/libzap.dart';
import 'sending_form.dart';
import 'zapdart/widgets.dart';
import 'zapdart/colors.dart';
import 'prefs.dart';

class SendForm extends StatefulWidget {
  final bool _testnet;
  final String _seed;
  final Decimal _fee;
  final String _recipientOrUri;
  final Decimal _max;

  SendForm(this._testnet, this._seed, this._fee, this._recipientOrUri, this._max) : super();

  @override
  SendFormState createState() {
    return SendFormState();
  }
}

class SendFormState extends State<SendForm> {
  final _formKey = GlobalKey<FormState>();
  final _addressController = TextEditingController();
  final _amountController = TextEditingController();
  final _msgController = TextEditingController();
  String _attachment;

  bool setRecipientOrUri(String recipientOrUri) {
    var result = parseRecipientOrWavesUri(widget._testnet, recipientOrUri);
    if (result == recipientOrUri) {
      _addressController.text = recipientOrUri;
      return true;
    }
    else if (result != null) {
      var parts = parseWavesUri(widget._testnet, recipientOrUri);
      _addressController.text = parts.address;
      _amountController.text = parts.amount.toString();
      _attachment = Uri.decodeFull(parts.attachment);
      _msgController.text = '';
      updateAttachment(null);
      return true;
    }
    return false;
  }

  void updateAttachment(String msg) async {
    var deviceName = await Prefs.deviceNameGet();
    setState(() {
      _attachment = formatAttachment(deviceName, msg, null, currentAttachment: _attachment);      
    });
  }

  void send() async {
    if (_formKey.currentState.validate()) {
      // send parameters
      var recipient = _addressController.text;
      var amountText = _amountController.text;
      var amountDec = Decimal.parse(amountText);
      var amount = (amountDec * Decimal.fromInt(100)).toInt();
      var fee = (widget._fee * Decimal.fromInt(100)).toInt();
      // double check with user
      if (await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return SimpleDialog(
              title: const Text('confirm send'),
              children: <Widget>[
                SimpleDialogOption(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: RoundedButton(() => Navigator.pop(context, true), ZapWhite, ZapYellow, 'yes send ${amountDec.toStringAsFixed(2)} $AssetShortNameLower'),
                ),
                SimpleDialogOption(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: RoundedButton(() => Navigator.pop(context, false), ZapBlue, ZapWhite, 'cancel', borderColor: ZapBlue),
                ),
              ],
            );
          }
      )) {
        // check pin
        if (!await pinCheck(context, await Prefs.pinGet())) {
          return;
        }
        // create tx
        var libzap = LibZap();
        var spendTx = libzap.transactionCreate(widget._seed, recipient, amount, fee, _attachment);
        if (spendTx.success) {
          var result = await Navigator.push<bool>(
            context,
            MaterialPageRoute(builder: (context) => SendingForm(spendTx)),
          );
          if (result)
            Navigator.pop(context, true);
        }
        else
          flushbarMsg(context, 'failed to create transaction', category: MessageCategory.Warning);
      }
    }
    else
      flushbarMsg(context, 'validation failed', category: MessageCategory.Warning);
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Center(heightFactor: 3, child: Text('send $AssetShortNameLower\n  ', style: TextStyle(color: ZapWhite, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
          TextFormField(
            controller: _addressController,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(labelText: 'recipient address',
              suffixIcon: FlatButton.icon(
                onPressed: () {
                  var qrCode = QRCodeReader().scan();
                  qrCode.then((value) {
                    if (value == null || !setRecipientOrUri(value))
                      flushbarMsg(context, 'invalid QR code', category: MessageCategory.Warning);
                  });
                },
                icon: Icon(MaterialCommunityIcons.qrcode_scan, size: 14, color: ZapYellow),
                label: Text('scan', style: TextStyle(color: ZapYellow))
              )
            ),
            validator: (value) {
              if (value.isEmpty) {
                return 'Please enter a value';
              }
              var libzap = LibZap();
              var res = libzap.addressCheck(value);
              if (!res) {
                return 'Invalid address';
              }
              return null;
            },
          ),
          TextFormField(
            controller: _amountController,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(labelText: '$AssetShortNameUpper amount',
              suffixIcon: FlatButton(onPressed: () => _amountController.text = '${widget._max - widget._fee}', child: Text('max', style: TextStyle(color: ZapYellow)))),
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
            controller: _msgController,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(labelText: 'message'),
            onChanged: updateAttachment,
          ),
          Text(_attachment != null ? _attachment : '', style: TextStyle(color: ZapBlackLight)),
          Padding(
            padding: const EdgeInsets.only(top: 24.0),
            child: RoundedButton(send, ZapWhite, ZapYellow, 'send $AssetShortNameLower', minWidth: MediaQuery.of(context).size.width / 2, holePunch: true),
          ),
          RoundedButton(() => Navigator.pop(context, false), ZapBlue, ZapWhite, 'cancel', borderColor: ZapBlue, minWidth: MediaQuery.of(context).size.width / 2),
        ],
      ),
    );
  }
}
