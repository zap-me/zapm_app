import 'package:flutter/material.dart';

import 'package:zapdart/widgets.dart';
import 'package:zapdart/colors.dart';

import 'config.dart';
import 'send_form.dart';
import 'receive_form.dart';
import 'wallet_state.dart';
import 'merchant.dart';
import 'ui_strings.dart';

class SendScreen extends StatelessWidget {
  SendScreen(this._ws, this._recipientOrUri) : super();

  final WalletState _ws;
  final String _recipientOrUri;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          leading: backButton(context),
          title: Text(capFirst('send $AssetShortNameLower'),
              style: TextStyle(color: ZapWhite)),
          backgroundColor: ZapYellow,
        ),
        body: CustomPaint(
            painter: CustomCurve(ZapYellow, 110, 170),
            child: Container(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                padding: EdgeInsets.all(20),
                child: SendForm(_ws, _recipientOrUri))));
  }
}

class ReceiveScreen extends StatelessWidget {
  ReceiveScreen(this._testnet, this._addressOrAccount, this._txNotification)
      : super();

  final bool _testnet;
  final String _addressOrAccount;
  final TxNotificationCallback _txNotification;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          leading: backButton(context),
          title: Text(capFirst('receive $AssetShortNameLower'),
              style: TextStyle(color: ZapWhite)),
          backgroundColor: ZapGreen,
        ),
        body: CustomPaint(
            painter: CustomCurve(ZapGreen, 150, 250),
            child: Container(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                padding: EdgeInsets.all(20),
                child: ReceiveForm(
                    _testnet, _addressOrAccount, _txNotification))));
  }
}
