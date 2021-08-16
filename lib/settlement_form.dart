import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';

import 'package:zapdart/libzap.dart';
import 'package:zapdart/utils.dart';
import 'package:zapdart/widgets.dart';
import 'package:zapdart/colors.dart';

import 'config.dart';
import 'merchant.dart';
import 'prefs.dart';

class SettlementForm extends StatefulWidget {
  final String _seed;
  final Decimal _fee;
  final Decimal _max;

  SettlementForm(this._seed, this._fee, this._max) : super();

  @override
  SettlementFormState createState() {
    return SettlementFormState();
  }
}

class SettlementFormState extends State<SettlementForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = new TextEditingController();
  Rates? _rates;
  List<Bank> _banks = [];
  String? _bankAccount;

  Future<bool> send(BuildContext context) async {
    if (_formKey.currentState == null || _rates == null) return false;
    if (_formKey.currentState!.validate()) {
      // send parameters
      var amountText = _amountController.text;
      var amountDec = Decimal.parse(amountText);
      var amount = (amountDec * Decimal.fromInt(100)).toInt();
      var fee = (widget._fee * Decimal.fromInt(100)).toInt();
      var lz = LibZap();
      if (!lz.addressCheck(_rates!.settlementAddress)) {
        flushbarMsg(context, 'unable to create settlement',
            category: MessageCategory.Warning);
        return false;
      }
      // get amount to receive
      showAlertDialog(context, 'calculating...');
      var calc = await merchantSettlementCalc(amountDec);
      Navigator.pop(context);
      if (calc.amountReceive == null) {
        flushbarMsg(context, 'unable to calculate settlement',
            category: MessageCategory.Warning);
        return false;
      }
      // double check with user
      var yesSend = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return SimpleDialog(
              title: Column(children: <Widget>[
                Text('confirm $AssetShortNameUpper settlement amount',
                    style: TextStyle(fontSize: 16)),
                Text(
                    'sending ${amountDec.toStringAsFixed(2)} $AssetShortNameUpper',
                    style: TextStyle(fontSize: 16, color: ZapYellow)),
                Text('receiving ${calc.amountReceive!.toStringAsFixed(2)} NZD',
                    style: TextStyle(fontSize: 16, color: ZapGreen)),
                Text(
                    'admin fee ${(calc.amountReceive! - amountDec).toStringAsFixed(2)} NZD',
                    style: TextStyle(fontSize: 16, color: ZapYellow)),
              ]),
              children: <Widget>[
                SimpleDialogOption(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: RoundedButton(
                      () => Navigator.pop(context, true),
                      ZapWhite,
                      ZapBlue,
                      ZapBlueGradient,
                      'yes send ${amountDec.toStringAsFixed(2)} $AssetShortNameLower',
                      width: MediaQuery.of(context).size.width / 2),
                ),
                SimpleDialogOption(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: RoundedButton(() => Navigator.pop(context, false),
                      ZapBlue, ZapWhite, null, 'cancel',
                      borderColor: ZapBlue,
                      width: MediaQuery.of(context).size.width / 2),
                )
              ],
            );
          });
      if (yesSend != null && yesSend) {
        // check pin
        if (!await pinCheck(context, await Prefs.pinGet())) {
          return false;
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
          flushbarMsg(context, 'failed to create settlement (${result.error})',
              category: MessageCategory.Warning);
          return false;
        }
        // send funds
        var libzap = LibZap();
        var deviceName = await Prefs.deviceNameGet();
        var attachment = formatAttachment(
            deviceName, result.settlement!.token, 'settlement');
        var spendTx = libzap.transactionCreate(
            widget._seed, _rates!.settlementAddress, amount, fee, attachment);
        if (!spendTx.success) {
          flushbarMsg(context, 'failed to create transaction',
              category: MessageCategory.Warning);
          return false;
        }
        showAlertDialog(context, 'sending settlement transaction...');
        var tx = await LibZap().transactionBroadcast(spendTx);
        if (tx == null) {
          flushbarMsg(context, 'failed to broadcast transaction',
              category: MessageCategory.Warning);
          Navigator.pop(context);
          return false;
        }
        Navigator.pop(context);
        showAlertDialog(context, 'updating settlement...');
        result =
            await merchantSettlementUpdate(result.settlement!.token, tx.id);
        if (result.settlement == null) {
          flushbarMsg(context, 'failed to update settlement (${result.error})',
              category: MessageCategory.Warning);
          Navigator.pop(context);
          return true;
        }
        Navigator.pop(context);
        // alert server to update merchant tx table
        merchantTx();
        return true;
      }
    } else
      flushbarMsg(context, 'validation failed',
          category: MessageCategory.Warning);
    return false;
  }

  @protected
  @mustCallSuper
  void initState() {
    super.initState();
    () async {
      if (!await Prefs.hasMerchantApiKey()) {
        flushbarMsg(context, 'no API KEY', category: MessageCategory.Warning);
        return;
      }
      // get rates
      showAlertDialog(context, 'getting rates...');
      var rates = await merchantRates();
      Navigator.pop(context);
      if (rates == null) {
        flushbarMsg(context, 'unable to get rates',
            category: MessageCategory.Warning);
        return;
      }
      // get banks
      showAlertDialog(context, 'getting banks...');
      var banks = await merchantBanks();
      Navigator.pop(context);
      if (banks == null) {
        flushbarMsg(context, 'unable to get bank accounts',
            category: MessageCategory.Warning);
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
        flushbarMsg(context, 'user has no bank accounts',
            category: MessageCategory.Warning);
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
          Center(
              heightFactor: 3,
              child: Text('make settlement\n  ',
                  style:
                      TextStyle(color: ZapWhite, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center)),
          TextFormField(
            controller: _amountController,
            keyboardType: TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
                labelText: '$AssetShortNameUpper amount',
                suffixIcon: flatButton(
                    onPressed: () =>
                        _amountController.text = '${widget._max - widget._fee}',
                    child: Text('max', style: TextStyle(color: ZapYellow)))),
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
          DropdownButton<String>(
            isExpanded: true,
            hint: Text('bank account'),
            value: _bankAccount,
            items: _banks
                .map((e) => DropdownMenuItem(
                      child: Text('${e.accountName} - ${e.accountNumber}'),
                      value: e.accountNumber,
                    ))
                .toList(),
            onChanged: (e) {
              setState(() {
                _bankAccount = e;
              });
            },
          ),
          Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: RoundedButton(() async {
                if (_bankAccount == null) return;
                if (await send(context)) {
                  Navigator.pop(context, true);
                  flushbarMsg(context, 'settlement created');
                }
              }, ZapWhite, ZapBlue, ZapBlueGradient, 'submit',
                  width: MediaQuery.of(context).size.width / 2,
                  holePunch: true)),
          RoundedButton(() => Navigator.pop(context, false), ZapBlue, ZapWhite,
              null, 'cancel',
              borderColor: ZapBlue,
              width: MediaQuery.of(context).size.width / 2),
        ],
      ),
    );
  }
}
