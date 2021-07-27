import 'dart:core';
import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_icons/flutter_icons.dart';

import 'package:zapdart/utils.dart';
import 'package:zapdart/libzap.dart';
import 'package:zapdart/widgets.dart';
import 'package:zapdart/colors.dart';

import 'config.dart';
import 'sending_form.dart';
import 'prefs.dart';
import 'paydb.dart';
import 'qrscan.dart';
import 'wallet_state.dart';
import 'ui_strings.dart';

class SendForm extends StatefulWidget {
  final WalletState _ws;
  final String _recipientOrUri;

  SendForm(this._ws, this._recipientOrUri) : super();

  @override
  SendFormState createState() {
    return SendFormState();
  }
}

class SendFormState extends State<SendForm> {
  final _formKey = GlobalKey<FormState>();
  final _recipientController = TextEditingController();
  final _amountController = TextEditingController();
  final _msgController = TextEditingController();
  String? _attachment = '';
  Widget? _recipientImage;

  bool setRecipientOrUri(String recipientOrUri) {
    switch (AppTokenType) {
      case TokenType.Waves:
        var result =
            parseRecipientOrWavesUri(widget._ws.testnet, recipientOrUri);
        if (result == recipientOrUri) {
          _recipientController.text = recipientOrUri;
          return true;
        } else if (result != null) {
          var parts = parseWavesUri(widget._ws.testnet, recipientOrUri);
          _recipientController.text = parts.address;
          updateRecipient(parts.address);
          _amountController.text = parts.amount.toString();
          _attachment = Uri.decodeFull(parts.attachment);
          _msgController.text = '';
          updateAttachment(null);
          return true;
        }
        return false;
      case TokenType.PayDB:
        var result = paydbParseRecipient(recipientOrUri);
        if (result == recipientOrUri) {
          _recipientController.text = recipientOrUri;
          updateRecipient(recipientOrUri);
          return true;
        }
        var parts = PayDbUri.parse(recipientOrUri);
        if (parts != null) {
          _recipientController.text = parts.account;
          updateRecipient(parts.account);
          _amountController.text = parts.amount.toString();
          if (parts.attachment != null)
            _attachment = Uri.decodeFull(parts.attachment!);
          _msgController.text = '';
          updateAttachment(null);
          return true;
        }
        return false;
    }
  }

  void updateRecipient(String recipient) async {
    if (AppTokenType == TokenType.PayDB) {
      var recipientImage;
      if (paydbRecipientCheck(recipient)) {
        var result = await paydbUserInfo(email: recipient);
        if (result.error == PayDbError.None && result.info != null)
          recipientImage =
              paydbAccountImage(result.info!.photo, result.info!.photoType);
      }
      setState(() {
        _recipientImage = recipientImage;
      });
    }
  }

  void updateAttachment(String? msg) async {
    var deviceName = await Prefs.deviceNameGet();
    setState(() {
      _attachment = formatAttachment(deviceName, msg, null,
          currentAttachment: _attachment);
    });
  }

  void send() async {
    if (_formKey.currentState == null) return;
    if (_formKey.currentState!.validate()) {
      // send parameters
      var recipient = _recipientController.text;
      var amountText = _amountController.text;
      var amountDec = Decimal.parse(amountText);
      var amount = (amountDec * Decimal.fromInt(100)).toInt();
      var fee = (widget._ws.fee * Decimal.fromInt(100)).toInt();
      // double check with user
      var yesSend = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return SimpleDialog(
              title: Text(capFirst('confirm send')),
              children: <Widget>[
                SimpleDialogOption(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: RoundedButton(
                      () => Navigator.pop(context, true),
                      ZapWhite,
                      ZapYellow,
                      capFirst(
                          'yes send ${amountDec.toStringAsFixed(2)} $AssetShortNameLower')),
                ),
                SimpleDialogOption(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: RoundedButton(() => Navigator.pop(context, false),
                      ZapBlue, ZapWhite, capFirst('cancel'),
                      borderColor: ZapBlue),
                ),
              ],
            );
          });
      if (yesSend != null && yesSend) {
        // check pin
        if (!await pinCheck(context, await Prefs.pinGet())) {
          return;
        }
        switch (AppTokenType) {
          case TokenType.Waves:
            // create tx
            var libzap = LibZap();
            var spendTx = libzap.transactionCreate(
                widget._ws.mnemonicOrAccount(),
                recipient,
                amount,
                fee,
                _attachment);
            if (spendTx.success) {
              var tx = await Navigator.push<Tx>(
                context,
                MaterialPageRoute(
                    builder: (context) => WavesSendingForm(spendTx)),
              );
              if (tx != null) Navigator.pop(context, tx);
            } else
              flushbarMsg(context, 'failed to create transaction',
                  category: MessageCategory.Warning);
            break;
          case TokenType.PayDB:
            var tx = await Navigator.push<PayDbTx>(
              context,
              MaterialPageRoute(
                  builder: (context) =>
                      PayDbSendingForm(recipient, amount, _attachment)),
            );
            if (tx != null) Navigator.pop(context, tx);
            break;
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
    setRecipientOrUri(widget._recipientOrUri);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
        child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Center(
                    heightFactor: 3,
                    child: Text(capFirst('send $AssetShortNameLower\n  '),
                        style: TextStyle(
                            color: ZapWhite, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center)),
                Visibility(
                    visible: _recipientImage != null,
                    child: Container(child: _recipientImage)),
                TextFormField(
                  controller: _recipientController,
                  keyboardType: AppTokenType == TokenType.PayDB
                      ? TextInputType.emailAddress
                      : TextInputType.text,
                  decoration: InputDecoration(
                      labelText: capFirst('recipient'),
                      suffixIcon: flatButtonIcon(
                          onPressed: () {
                            var qrCode = QrScan.scan(context);
                            qrCode.then((value) {
                              if (value == null || !setRecipientOrUri(value))
                                flushbarMsg(context, 'invalid QR code',
                                    category: MessageCategory.Warning);
                            });
                          },
                          icon: Icon(MaterialCommunityIcons.qrcode_scan,
                              size: 14, color: ZapYellow),
                          label: Text(capFirst('scan'),
                              style: TextStyle(color: ZapYellow)))),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a value';
                    }
                    switch (AppTokenType) {
                      case TokenType.Waves:
                        if (!LibZap().addressCheck(value)) {
                          return 'invalid recipient';
                        }
                        break;
                      case TokenType.PayDB:
                        if (!paydbRecipientCheck(value)) {
                          return 'invalid recipient';
                        }
                        break;
                    }
                    return null;
                  },
                  onChanged: updateRecipient,
                ),
                TextFormField(
                  controller: _amountController,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      labelText: '$AssetShortNameUpper amount',
                      suffixIcon: flatButton(
                          onPressed: () => _amountController.text =
                              '${widget._ws.balance - widget._ws.fee}',
                          child: Text(capFirst('max'),
                              style: TextStyle(color: ZapYellow)))),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter a value';
                    }
                    final dv = Decimal.parse(value);
                    if (dv > widget._ws.balance - widget._ws.fee) {
                      return 'Max available to send is ${widget._ws.balance - widget._ws.fee}';
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
                  decoration: InputDecoration(labelText: capFirst('message')),
                  onChanged: updateAttachment,
                ),
                Text(_attachment != null ? _attachment! : '',
                    style: TextStyle(color: ZapBlackLight)),
                Padding(
                  padding: const EdgeInsets.only(top: 24.0),
                  child: RoundedButton(send, ZapWhite, ZapYellow,
                      capFirst('send $AssetShortNameLower'),
                      minWidth: MediaQuery.of(context).size.width / 2,
                      holePunch: true),
                ),
                RoundedButton(() => Navigator.pop(context, null), ZapBlue,
                    ZapWhite, capFirst('cancel'),
                    borderColor: ZapBlue,
                    minWidth: MediaQuery.of(context).size.width / 2),
              ],
            )));
  }
}
