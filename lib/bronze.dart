import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:decimal/decimal.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:extended_masked_text/extended_masked_text.dart';

import 'package:zapdart/widgets.dart';
import 'package:zapdart/colors.dart';
import 'package:zapdart/utils.dart';
import 'package:zapdart/libzap.dart';
import 'package:zapdart/hmac.dart';

import 'prefs.dart';
import 'wallet_state.dart';
import 'send_receive.dart';
import 'bronze_order.dart';
import 'config.dart';

class BronzeRegister {
  final String? accountToken;
  final String? apikeyToken;
  BronzeRegister(this.accountToken, this.apikeyToken);

  bool empty() => accountToken == null && apikeyToken == null;
}

class BronzeApikeyResult {
  final bool completed;
  final String? key;
  final String? secret;
  BronzeApikeyResult(this.completed, this.key, this.secret);

  bool empty() => key == null || secret == null;
}

class BronzeApikey {
  final String key;
  final String secret;
  BronzeApikey(this.key, this.secret);
}

enum BronzeError { None, Auth, Network }

class BronzeApikeyValidateResult {
  final bool value;
  final BronzeError error;
  BronzeApikeyValidateResult(this.value, this.error);
}

class BronzeAccountKycResult {
  final String level;
  final Decimal withdrawalLimit;
  final String withdrawalAsset;
  final String withdrawalPeriod;
  final Decimal withdrawalTotal;
  final BronzeError error;
  BronzeAccountKycResult(this.level, this.withdrawalLimit, this.withdrawalAsset,
      this.withdrawalPeriod, this.withdrawalTotal, this.error);

  static BronzeAccountKycResult makeError(BronzeError error) =>
      BronzeAccountKycResult('', Decimal.zero, '', '', Decimal.zero, error);
}

class BronzeAccountKycUpgradeResult {
  final String token;
  final String serviceUrl;
  final String status;
  final BronzeError error;
  BronzeAccountKycUpgradeResult(
      this.token, this.serviceUrl, this.status, this.error);

  static BronzeAccountKycUpgradeResult makeError(BronzeError error) =>
      BronzeAccountKycUpgradeResult('', '', '', error);
}

enum BronzeSide { Buy, Sell }

const BronzeZapNzdMarket = 'ZAPNZD';

class BronzeQuote {
  final String market;
  final BronzeSide side;
  final Decimal amount;
  final bool amountAsQuoteCurrency;
  BronzeQuote(this.market, this.side, this.amount, this.amountAsQuoteCurrency);
}

class BronzeQuoteResult {
  final String assetSend;
  final Decimal amountSend;
  final String assetReceive;
  final Decimal amountReceive;
  final int timeLimit;
  final BronzeError error;
  final String? errorMessage;
  BronzeQuoteResult(this.assetSend, this.amountSend, this.assetReceive,
      this.amountReceive, this.timeLimit, this.error, this.errorMessage);

  static BronzeQuoteResult makeError(BronzeError error, String? msg) =>
      BronzeQuoteResult('', Decimal.zero, '', Decimal.zero, 0, error, msg);
}

class BronzeOrderResult {
  final BronzeOrder order;

  final BronzeError error;
  final String? errorMessage;
  BronzeOrderResult(this.order, this.error, this.errorMessage);

  static BronzeOrderResult makeError(BronzeError error, String? msg) =>
      BronzeOrderResult(BronzeOrder.makeEmpty(), error, msg);

  static BronzeOrderResult fromJson(String data) =>
      BronzeOrderResult(BronzeOrder.fromJson(data), BronzeError.None, null);
}

class Bronze {
  final bool _testnet;

  Bronze(this._testnet);

  String get baseUrl {
    return _testnet
        ? 'https://test.bronze.exchange/api/v1/'
        : 'https://bronze.exchange/api/v1/';
  }

  int _nonce() {
    return DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
  }

  Future<http.Response?> _postAndCatch(String endpoint, String body,
      {Map<String, String>? extraHeaders}) async {
    var url = baseUrl + endpoint;
    try {
      return await httpPost(Uri.parse(url), body, extraHeaders: extraHeaders);
    } on SocketException catch (e) {
      print(e);
      return null;
    } on TimeoutException catch (e) {
      print(e);
      return null;
    } on http.ClientException catch (e) {
      print(e);
      return null;
    } on ArgumentError catch (e) {
      print(e);
      return null;
    } on HandshakeException catch (e) {
      print(e);
      return null;
    }
  }

  Future<BronzeRegister> register(String email, String deviceName) async {
    var body = jsonEncode({'email': email, 'deviceName': deviceName});
    String? accountToken;
    var response = await _postAndCatch('AccountCreate', body);
    if (response != null && response.statusCode == 200)
      try {
        var json = jsonDecode(response.body);
        accountToken = json['token'] as String;
      } catch (e) {}
    String? apikeyToken;
    response = await _postAndCatch('ApiKeyCreate', body);
    if (response != null && response.statusCode == 200)
      try {
        var json = jsonDecode(response.body);
        apikeyToken = json['token'] as String;
      } catch (e) {}
    return BronzeRegister(accountToken, apikeyToken);
  }

  Future<BronzeApikeyResult> _registrationCheck(
      String endpoint, String? token) async {
    var completed = false;
    String? key;
    String? secret;
    if (token != null) {
      var body = jsonEncode({'token': token});
      var response = await _postAndCatch(endpoint, body);
      if (response != null && response.statusCode == 200) {
        try {
          var json = jsonDecode(response.body);
          completed = json['completed'] as bool;
          key = json['key'] as String?;
          secret = json['secret'] as String?;
        } catch (e) {}
      }
    }
    return BronzeApikeyResult(completed, key, secret);
  }

  Future<BronzeApikeyResult> registrationCheck(
      BronzeRegister registration) async {
    var result = await _registrationCheck(
        'AccountCreateStatus', registration.accountToken);
    if (result.completed) return result;
    return await _registrationCheck(
        'ApiKeyCreateStatus', registration.apikeyToken);
  }

  Future<http.Response?> _privateRequest(BronzeApikey apikey, String endpoint,
      {Map<String, dynamic>? params}) async {
    if (params == null) params = {};
    params['key'] = apikey.key;
    params['nonce'] = _nonce();
    var body = jsonEncode(params);
    var sig = createHmacSig(apikey.secret, body);
    return await _postAndCatch(endpoint, body,
        extraHeaders: {'X-Signature': sig});
  }

  Future<BronzeApikeyValidateResult> apikeyValidate(BronzeApikey apikey) async {
    var response = await _privateRequest(apikey, 'ApiKeyValidate');
    if (response != null) {
      if (response.statusCode == 400)
        return BronzeApikeyValidateResult(false, BronzeError.Auth);
      if (response.statusCode == 200)
        return BronzeApikeyValidateResult(true, BronzeError.None);
    }
    return BronzeApikeyValidateResult(false, BronzeError.Network);
  }

  Future<BronzeAccountKycResult> accountKyc(BronzeApikey apikey) async {
    var response = await _privateRequest(apikey, 'AccountKyc');
    if (response != null) {
      if (response.statusCode == 400)
        return BronzeAccountKycResult.makeError(BronzeError.Auth);
      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);
        var level = json['level'];
        var withdrawalLimit = Decimal.parse(json['withdrawalLimit']);
        var withdrawalAsset = json['withdrawalAsset'];
        var withdrawalPeriod = json['withdrawalPeriod'];
        var withdrawalTotal = Decimal.parse(json['withdrawalTotal']);
        return BronzeAccountKycResult(level, withdrawalLimit, withdrawalAsset,
            withdrawalPeriod, withdrawalTotal, BronzeError.None);
      }
    }
    return BronzeAccountKycResult.makeError(BronzeError.Network);
  }

  Future<BronzeAccountKycUpgradeResult> accountKycUpgrade(
      BronzeApikey apikey) async {
    var response = await _privateRequest(apikey, 'AccountKycUpgrade');
    if (response != null) {
      if (response.statusCode == 400)
        return BronzeAccountKycUpgradeResult.makeError(BronzeError.Auth);
      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);
        var token = json['token'];
        var serviceUrl = json['serviceUrl'];
        var status = json['status'];
        return BronzeAccountKycUpgradeResult(
            token, serviceUrl, status, BronzeError.None);
      }
    }
    return BronzeAccountKycUpgradeResult.makeError(BronzeError.Network);
  }

  Future<BronzeAccountKycUpgradeResult> accountKycUpgradeStatus(
      BronzeApikey apikey, String token) async {
    var response = await _privateRequest(apikey, 'AccountKycUpgradeStatus',
        params: {'token': token});
    if (response != null) {
      if (response.statusCode == 400)
        return BronzeAccountKycUpgradeResult.makeError(BronzeError.Auth);
      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);
        var token = json['token'];
        var serviceUrl = json['serviceUrl'];
        var status = json['status'];
        return BronzeAccountKycUpgradeResult(
            token, serviceUrl, status, BronzeError.None);
      }
    }
    return BronzeAccountKycUpgradeResult.makeError(BronzeError.Network);
  }

  Future<BronzeQuoteResult> brokerQuote(
      BronzeApikey apikey, BronzeQuote quote) async {
    var params = {
      'market': quote.market,
      'side': describeEnum(quote.side).toLowerCase(),
      'amount': quote.amount.toString(),
      'amountAsQuoteCurrency': quote.amountAsQuoteCurrency,
    };
    var response = await _privateRequest(apikey, 'BrokerQuote', params: params);
    if (response != null) {
      if (response.statusCode == 400)
        return BronzeQuoteResult.makeError(BronzeError.Auth, response.body);
      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);
        var assetSend = json['assetSend'];
        var amountSend = Decimal.parse(json['amountSend']);
        var assetReceive = json['assetReceive'];
        var amountReceive = Decimal.parse(json['amountReceive']);
        var timeLimit = json['timeLimit'];
        return BronzeQuoteResult(assetSend, amountSend, assetReceive,
            amountReceive, timeLimit, BronzeError.None, null);
      }
    }
    return BronzeQuoteResult.makeError(BronzeError.Network, null);
  }

  Future<BronzeOrderResult> brokerCreate(
      BronzeApikey apikey, BronzeQuote quote, String recipient) async {
    var params = {
      'market': quote.market,
      'side': describeEnum(quote.side).toLowerCase(),
      'amount': quote.amount.toString(),
      'amountAsQuoteCurrency': quote.amountAsQuoteCurrency,
      'recipient': recipient,
    };
    var response =
        await _privateRequest(apikey, 'BrokerCreate', params: params);
    if (response != null) {
      if (response.statusCode == 400)
        return BronzeOrderResult.makeError(BronzeError.Auth, response.body);
      if (response.statusCode == 200)
        return BronzeOrderResult.fromJson(response.body);
    }
    return BronzeOrderResult.makeError(BronzeError.Network, null);
  }

  Future<BronzeOrderResult> brokerAccept(
      BronzeApikey apikey, String token) async {
    var response =
        await _privateRequest(apikey, 'BrokerAccept', params: {'token': token});
    if (response != null) {
      if (response.statusCode == 400)
        return BronzeOrderResult.makeError(BronzeError.Auth, response.body);
      if (response.statusCode == 200)
        return BronzeOrderResult.fromJson(response.body);
    }
    return BronzeOrderResult.makeError(BronzeError.Network, null);
  }

  Future<BronzeOrderResult> brokerStatus(
      BronzeApikey apikey, String token) async {
    var response =
        await _privateRequest(apikey, 'BrokerStatus', params: {'token': token});
    if (response != null) {
      if (response.statusCode == 400)
        return BronzeOrderResult.makeError(BronzeError.Auth, response.body);
      if (response.statusCode == 200)
        return BronzeOrderResult.fromJson(response.body);
    }
    return BronzeOrderResult.makeError(BronzeError.Network, null);
  }
}

class BronzeScreen extends StatelessWidget {
  BronzeScreen(this._ws, this._side) : super();

  final BronzeSide _side;
  final WalletState _ws;

  String _zapVerb() {
    return describeEnum(_side);
  }

  String _nzdVerb() {
    return _side == BronzeSide.Sell ? 'Receive' : 'Send';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            leading: backButton(context),
            title: Text('${_zapVerb()} Zap', style: TextStyle(color: ZapWhite)),
            backgroundColor: ZapBlue,
            flexibleSpace: ZapBlueGradient != null
                ? Container(
                    decoration: BoxDecoration(gradient: ZapBlueGradient))
                : null),
        body: CustomPaint(
            painter: CustomCurve(ZapBlue, ZapBlueGradient, 120, 200),
            child: Container(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                padding: EdgeInsets.all(20),
                child: BronzeForm(_ws, _side, _zapVerb, _nzdVerb))));
  }
}

class BronzeForm extends StatefulWidget {
  final WalletState _ws;
  final BronzeSide _side;
  final String Function() _zapVerb;
  final String Function() _nzdVerb;

  BronzeForm(this._ws, this._side, this._zapVerb, this._nzdVerb) : super();

  @override
  BronzeFormState createState() {
    return BronzeFormState();
  }
}

enum ProcessingQuote { None, NZD, ZAP }

class BronzeFormState extends State<BronzeForm> {
  final _formKey = GlobalKey<FormState>();
  final _amountZapController = TextEditingController();
  final _amountNzdController = TextEditingController();
  final _bankAccountController =
      MaskedTextController(mask: '00-0000-0000000-000');

  bool _amountNzdValid = true;
  bool _amountZapValid = true;
  bool _bankAccountValid = true;
  bool _apikeyValid = false;
  BronzeAccountKycResult? _accountKyc;
  BronzeAccountKycUpgradeResult? _accountKycUpgrade;
  bool _accountKycIncomplete = true;
  Timer? _amountTimer;
  ProcessingQuote _processingQuote = ProcessingQuote.None;

  @protected
  @mustCallSuper
  void initState() {
    super.initState();
    _initBronze();
  }

  @protected
  @mustCallSuper
  void dispose() {
    super.dispose();
    _amountTimer?.cancel();
  }

  Future<bool> _canLeave() {
    return Future<bool>.value(true);
  }

  Future<bool> _createApiKey(String email) async {
    var bronze = Bronze(widget._ws.testnet);
    showAlertDialog(context, 'registering...');
    var registration =
        await bronze.register(email, await deviceName());
    Navigator.pop(context);
    if (registration.empty()) {
      return false;
    }
    showAlertDialog(context, 'waiting for email confirmation...');
    BronzeApikeyResult result;
    while (true) {
      await Future.delayed(Duration(seconds: 5));
      result = await bronze.registrationCheck(registration);
      if (result.completed || !result.empty()) break;
    }
    Navigator.pop(context);
    if (result.empty()) {
      return false;
    }
    await Prefs.bronzeApiKeySet(result.key);
    await Prefs.bronzeApiSecretSet(result.secret);
    return true;
  }

  Future<bool> _initApiKey() async {
    var bronze = Bronze(widget._ws.testnet);
    while (true) {
      var createdKey = false;
      // create api key if none present
      if (!await Prefs.hasBronzeApiKey()) {
        var email =
            await askString(context, 'Enter email to connect to Bronze', null);
        if (email == null || email.isEmpty) {
          Navigator.pop(context);
          return false;
        }
        if (!await _createApiKey(email)) {
          await alert(context, 'Registration failed',
              'Unable to register with Bronze at this time');
          Navigator.pop(context);
          return false;
        } else
          createdKey = true;
      }
      // validate api key
      showAlertDialog(context, 'validating api key...');
      var validationResult = await bronze.apikeyValidate(await _apikey());
      Navigator.pop(context);
      if (!validationResult.value) {
        if (validationResult.error == BronzeError.Auth) {
          // exit if newly created key does not work
          if (createdKey) {
            await alert(context, 'Unable to connect',
                'Unable to connect to Bronze at this time');
            Navigator.pop(context);
            return false;
          }
          // delete existing non functional key
          await Prefs.bronzeApiKeySet(null);
          continue; // continue (to create a new key) if an old key has been revoked
        } else {
          await alert(context, 'Unable to connect',
              'Unable to connect to Bronze at this time');
          Navigator.pop(context);
          return false;
        }
      } else
        return true;
    }
  }

  void _initBronze() async {
    var bankAccount = await Prefs.bronzeBankAccountGet();
    if (bankAccount != null) _bankAccountController.text = bankAccount;
    if (!await _initApiKey()) return;
    setState(() => _apikeyValid = true);
    var apikey = await _apikey();
    var bronze = Bronze(widget._ws.testnet);
    // get withdrawal limit
    showAlertDialog(context, 'checking withdrawal limit...');
    var kycResult = await bronze.accountKyc(apikey);
    Navigator.pop(context);
    if (kycResult.error == BronzeError.None)
      setState(() => _accountKyc = kycResult);
    else
      return;
    // get kyc request status
    var kycStatus = await _kycStatus(apikey);
    setState(() => _accountKycUpgrade = kycStatus);
  }

  Future<BronzeApikey> _apikey() async {
    var key = await Prefs.bronzeApiKeyGet();
    var secret = await Prefs.bronzeApiSecretGet();
    return BronzeApikey(key!, secret!);
  }

  Future<BronzeAccountKycUpgradeResult?> _kycStatus(BronzeApikey apikey) async {
    var token = await Prefs.bronzeKycTokenGet();
    if (token != null) {
      var bronze = Bronze(widget._ws.testnet);
      showAlertDialog(context, 'checking kyc upgrade request...');
      var result = await bronze.accountKycUpgradeStatus(apikey, token);
      Navigator.pop(context);
      if (result.error == BronzeError.None) {
        setState(() => _accountKycIncomplete = result.status != 'completed');
        return result;
      }
    }
    return null;
  }

  void _upgradeKyc() async {
    if (_accountKycUpgrade == null) {
      var bronze = Bronze(widget._ws.testnet);
      var apikey = await _apikey();
      showAlertDialog(context, 'requesting kyc upgrade...');
      var result = await bronze.accountKycUpgrade(apikey);
      Navigator.pop(context);
      if (result.error != BronzeError.None) return;
      await Prefs.bronzeKycTokenSet(result.token);
      _accountKycUpgrade = result;
      setState(() => _accountKycUpgrade = result);
    }
    launch(_accountKycUpgrade!.serviceUrl);
  }

  void _updateQuote() async {
    dismissKeyboard(context);
    TextEditingController controllerAmount;
    TextEditingController controllerQuote;
    switch (_processingQuote) {
      case ProcessingQuote.None:
        return;
      case ProcessingQuote.NZD:
        controllerAmount = _amountZapController;
        controllerQuote = _amountNzdController;
        if (!_amountZapValid) {
          setState(() => _processingQuote = ProcessingQuote.None);
          controllerQuote.text = '';
          return;
        }
        break;
      case ProcessingQuote.ZAP:
        controllerAmount = _amountNzdController;
        controllerQuote = _amountZapController;
        if (!_amountNzdValid) {
          setState(() => _processingQuote = ProcessingQuote.None);
          controllerQuote.text = '';
          return;
        }
    }
    var amount = Decimal.tryParse(controllerAmount.text);
    if (amount == null) return;
    if (amount < Decimal.zero) return;
    var quote = BronzeQuote(BronzeZapNzdMarket, widget._side, amount,
        _processingQuote == ProcessingQuote.ZAP);
    var bronze = Bronze(widget._ws.testnet);
    var quoteResult = await bronze.brokerQuote(await _apikey(), quote);
    switch (quoteResult.error) {
      case BronzeError.None:
        var quoteAmountReceive = (widget._side == BronzeSide.Sell) ^
            (_processingQuote == ProcessingQuote.ZAP);
        controllerQuote.text = quoteAmountReceive
            ? quoteResult.amountReceive.toString()
            : quoteResult.amountSend.toString();
        break;
      case BronzeError.Network:
        flushbarMsg(context, 'Network error',
            category: MessageCategory.Warning);
        break;
      case BronzeError.Auth:
        if (quoteResult.errorMessage != null)
          flushbarMsg(context, quoteResult.errorMessage!,
              category: MessageCategory.Warning);
        break;
    }
    setState(() => _processingQuote = ProcessingQuote.None);
  }

  bool _validBankAccount(String? value) {
    if (value == null) return false;
    value = value.replaceAll('-', '');
    if (value.length == 15 || value.length == 16)
      return int.tryParse(value) != null;
    return false;
  }

  Future<BronzeOrder?> _createAndConfirmOrder(
      BronzeQuote quote, String recipient) async {
    var bronze = Bronze(widget._ws.testnet);
    var apikey = await _apikey();
    showAlertDialog(context, 'creating order...');
    var result = await bronze.brokerCreate(apikey, quote, recipient);
    Navigator.pop(context);
    if (result.error != BronzeError.None) {
      flushbarMsg(context, 'failed to create order - ${result.errorMessage}',
          category: MessageCategory.Warning);
      return null;
    }
    var order = result.order;
    var yes = await askYesNo(context,
        'Would you like to confirm your order to send ${order.amountSend} ${order.assetSend} and receive ${order.amountReceive} ${order.assetReceive}?');
    if (!yes) return null;
    showAlertDialog(context, 'confirming order...');
    result = await bronze.brokerAccept(apikey, order.token);
    Navigator.pop(context);
    order = result.order;
    if (result.error != BronzeError.None ||
        order.status.toLowerCase() != 'ready') {
      flushbarMsg(context, 'failed to confirm order - ${result.errorMessage}',
          category: MessageCategory.Warning);
      return null;
    }
    await Prefs.bronzeOrderAdd(order);
    return order;
  }

  void _execute() async {
    if (_formKey.currentState == null) return;
    if (_formKey.currentState!.validate()) {
      var amount = Decimal.parse(_amountZapController.text);
      var quote = BronzeQuote(BronzeZapNzdMarket, widget._side, amount, false);
      switch (widget._side) {
        case BronzeSide.Buy:
          var order = await _createAndConfirmOrder(
              quote, widget._ws.addrOrAccountValue());
          if (order == null) break;
          if (order.paymentUrl == null) {
            flushbarMsg(context, 'invalid order',
                category: MessageCategory.Warning);
            break;
          }
          launch(order.paymentUrl!);
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => BronzeOrdersScreen()),
          );
          Navigator.pop(context);
          break;
        case BronzeSide.Sell:
          Prefs.bronzeBankAccountSet(_bankAccountController.text);
          var order =
              await _createAndConfirmOrder(quote, _bankAccountController.text);
          if (order == null) break;
          if (order.invoiceId == null || order.paymentAddress == null) {
            flushbarMsg(context, 'invalid order',
                category: MessageCategory.Warning);
            break;
          }
          var addr = order.paymentAddress!;
          var assetId = LibZap().assetIdGet();
          var attachment = jsonEncode({'invoiceId': order.invoiceId});
          var uri = WavesRequest(
                  addr, assetId, amount * Decimal.fromInt(100), attachment, 0)
              .toUri();
          var tx = await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => SendScreen(widget._ws, uri)),
          );
          if (tx != null) {
            widget._ws.updateBalance();
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => BronzeOrdersScreen()),
            );
            Navigator.pop(context);
          } else
            flushbarMsg(context, 'failed to send transaction',
                category: MessageCategory.Warning);
          break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      child: SingleChildScrollView(
          child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Center(
                heightFactor: 5,
                child: Text(
                    DontRepeatTitles
                        ? ''
                        : '${widget._zapVerb().toLowerCase()} zap',
                    style:
                        TextStyle(color: ZapWhite, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center)),
            Center(
                child: Card(
              margin: EdgeInsets.all(20),
            )),
            TextFormField(
              controller: _amountZapController,
              enabled: _apikeyValid && _processingQuote != ProcessingQuote.ZAP,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
              ],
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                  labelText: 'amount ${widget._zapVerb().toLowerCase()}',
                  prefixIcon: _processingQuote == ProcessingQuote.ZAP
                      ? Padding(
                          padding: EdgeInsets.all(15),
                          child: SizedBox(
                              child: CircularProgressIndicator(strokeWidth: 2),
                              width: 18,
                              height: 18))
                      : null,
                  suffixIcon: Padding(
                      padding: EdgeInsets.all(15),
                      child: Text('zap', style: TextStyle(color: ZapBlue)))),
              style: _amountZapValid ? null : TextStyle(color: ZapRed),
              validator: (value) {
                if (value != null && value.isEmpty) {
                  return 'Please enter a value';
                }
                final dv = Decimal.parse(value!);
                if (dv <= Decimal.zero) {
                  return 'Please enter a value greater then zero';
                }
                return null;
              },
              onChanged: (value) {
                if (value.isEmpty)
                  _amountZapValid = false;
                else
                  _amountZapValid = Decimal.tryParse(value) != null;
                setState(() => _amountZapValid = _amountZapValid);
                _processingQuote = ProcessingQuote.NZD;
                _amountNzdController.text = '';
                _amountNzdValid = true;
                _amountTimer?.cancel();
                _amountTimer = Timer(Duration(seconds: 2), _updateQuote);
                setState(() => _processingQuote = _processingQuote);
              },
            ),
            TextFormField(
              controller: _amountNzdController,
              enabled: _apikeyValid && _processingQuote != ProcessingQuote.NZD,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
              ],
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                  labelText: 'amount ${widget._nzdVerb().toLowerCase()}',
                  prefixIcon: _processingQuote == ProcessingQuote.NZD
                      ? Padding(
                          padding: EdgeInsets.all(15),
                          child: SizedBox(
                              child: CircularProgressIndicator(strokeWidth: 2),
                              width: 18,
                              height: 18))
                      : null,
                  suffixIcon: Padding(
                      padding: EdgeInsets.all(15),
                      child: Text('nzd', style: TextStyle(color: ZapBlue)))),
              style: _amountNzdValid ? null : TextStyle(color: ZapRed),
              validator: (value) {
                if (value != null && value.isEmpty) {
                  return 'Please enter a value';
                }
                final dv = Decimal.parse(value!);
                if (dv <= Decimal.zero) {
                  return 'Please enter a value greater then zero';
                }
                return null;
              },
              onChanged: (value) {
                if (value.isEmpty)
                  _amountNzdValid = false;
                else
                  _amountNzdValid = Decimal.tryParse(value) != null;
                setState(() => _amountNzdValid = _amountNzdValid);
                _processingQuote = ProcessingQuote.ZAP;
                _amountZapController.text = '';
                _amountZapValid = true;
                _amountTimer?.cancel();
                _amountTimer = Timer(Duration(seconds: 2), _updateQuote);
                setState(() => _processingQuote = _processingQuote);
              },
            ),
            _accountKyc != null
                ? Column(children: [
                    Padding(
                        padding: const EdgeInsets.only(top: 24.0),
                        child: Text(
                            'Bronze ${_accountKyc!.withdrawalPeriod.toLowerCase()} withdrawal limit is ${_accountKyc!.withdrawalLimit} ${_accountKyc!.withdrawalAsset}')),
                    _accountKycIncomplete
                        ? Padding(
                            padding: const EdgeInsets.only(top: 24.0),
                            child: RoundedButton(
                                _upgradeKyc,
                                ZapBlue,
                                ZapWhite,
                                null,
                                _accountKycUpgrade == null
                                    ? 'Increase withdrawal limit'
                                    : 'Complete KYC (${_accountKycUpgrade?.status})',
                                borderColor: ZapBlue,
                                width:
                                    MediaQuery.of(context).size.width * 2 / 3))
                        : SizedBox(),
                  ])
                : SizedBox(),
            widget._side == BronzeSide.Sell
                ? Padding(
                    padding: const EdgeInsets.only(top: 24.0),
                    child: TextFormField(
                      controller: _bankAccountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: 'bank account'),
                      style:
                          _bankAccountValid ? null : TextStyle(color: ZapRed),
                      validator: (value) {
                        if (value != null && value.isEmpty)
                          return 'Please enter a value';
                        if (!_validBankAccount(value))
                          return 'Invalid bank account';
                        return null;
                      },
                      onChanged: (value) {
                        // hack to get around MaskedTextController not stopping the input before it hits this event
                        _bankAccountController.updateText(value);
                        value = _bankAccountController.text;

                        if (value.isEmpty)
                          _bankAccountValid = false;
                        else
                          _bankAccountValid = _validBankAccount(value);
                        setState(() => _bankAccountValid = _bankAccountValid);
                      },
                    ),
                  )
                : SizedBox(),
            Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: RoundedButton(_execute, ZapWhite, ZapBlue, ZapBlueGradient,
                  '${widget._zapVerb().toLowerCase()}',
                  width: MediaQuery.of(context).size.width / 2,
                  holePunch: true),
            ),
            RoundedButton(
                () => Navigator.pop(context), ZapBlue, ZapWhite, null, 'cancel',
                borderColor: ZapBlue,
                width: MediaQuery.of(context).size.width / 2),
          ],
        ),
      )),
      onWillPop: _canLeave,
    );
  }
}

class BronzeOrdersScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          leading: backButton(context),
          title: Text('Bronze Orders', style: TextStyle(color: ZapWhite)),
          backgroundColor: ZapBlue,
        ),
        body: BronzeOrdersList());
  }
}

class BronzeOrdersList extends StatefulWidget {
  @override
  _BronzeOrdersListState createState() => _BronzeOrdersListState();
}

class _BronzeOrdersListState extends State<BronzeOrdersList> {
  List<BronzeOrder> _orders = [];
  String? _updatingToken;

  @protected
  @mustCallSuper
  void initState() {
    super.initState();
    () async {
      _orders = await Prefs.bronzeOrdersGet();
      setState(() => _orders = _orders);
      // update orders
      if (!await Prefs.hasBronzeApiKey()) return;
      var bronze = Bronze(await Prefs.testnetGet());
      var apikey = await _apikey();
      for (var order in _orders) {
        if (order.status == 'Expired' || order.status == 'Confirmed') continue;
        setState(() => _updatingToken = order.token);
        var result = await bronze.brokerStatus(apikey, order.token);
        if (result.error != BronzeError.None) return;
        var updatedOrder = result.order;
        _orders = await Prefs.bronzeOrderUpdate(updatedOrder);
        if (!this
            .mounted) // check that the page has not been disposed while we were updating
          return;
        setState(() {
          _orders = _orders;
          _updatingToken = null;
        });
      }
    }();
  }

  Future<BronzeApikey> _apikey() async {
    var key = await Prefs.bronzeApiKeyGet();
    var secret = await Prefs.bronzeApiSecretGet();
    return BronzeApikey(key!, secret!);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
        child: ListView.builder(
            itemCount: _orders.length,
            itemBuilder: (context, index) {
              var o = _orders[index];
              return ListTile(
                title: _updatingToken == o.token
                    ? SizedBox(
                        child: Center(child: CircularProgressIndicator()),
                        width: 28,
                        height: 28)
                    : Text('${o.token}: ${o.status}'),
                subtitle: _updatingToken == o.token
                    ? null
                    : Text(
                        'Receive ${o.amountReceive} ${o.assetReceive}, Send ${o.amountSend} ${o.assetSend}'),
                /*onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => BronzeOrderScreen(_orders[index])),
            );
          },*/
              );
            }));
  }
}
