import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:decimal/decimal.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:zapdart/widgets.dart';
import 'package:zapdart/colors.dart';
import 'package:zapdart/utils.dart';

import 'hmac.dart';
import 'prefs.dart';
import 'wallet_state.dart';

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

enum BronzeApiError { None, Auth, Network }

class BronzeApikeyValidateResult {
  final bool value;
  final BronzeApiError error;
  BronzeApikeyValidateResult(this.value, this.error);
}

enum BronzeApiSide { Buy, Sell }

const BronzeZapNzdMarket = 'ZAPNZD';

class BronzeApiQuote {
  final String market;
  final BronzeApiSide side;
  final Decimal amount;
  final bool amountAsQuoteCurrency;
  BronzeApiQuote(
      this.market, this.side, this.amount, this.amountAsQuoteCurrency);
}

class BronzeApiQuoteResult {
  final String assetSend;
  final Decimal amountSend;
  final String assetReceive;
  final Decimal amountReceive;
  final int timeLimit;
  final BronzeApiError error;
  final String? errorMessage;
  BronzeApiQuoteResult(this.assetSend, this.amountSend, this.assetReceive,
      this.amountReceive, this.timeLimit, this.error, this.errorMessage);

  static BronzeApiQuoteResult makeError(BronzeApiError error, String? msg) =>
      BronzeApiQuoteResult('', Decimal.zero, '', Decimal.zero, 0, error, msg);
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

  Future<BronzeApikeyValidateResult> apikeyValidate(BronzeApikey apikey) async {
    var body = jsonEncode({
      'key': apikey.key,
      'nonce': _nonce(),
    });
    var sig = createHmacSig(apikey.secret, body);
    var response = await _postAndCatch('ApiKeyValidate', body,
        extraHeaders: {'X-Signature': sig});
    if (response != null) {
      if (response.statusCode == 400)
        return BronzeApikeyValidateResult(false, BronzeApiError.Auth);
      if (response.statusCode == 200)
        return BronzeApikeyValidateResult(true, BronzeApiError.None);
    }
    return BronzeApikeyValidateResult(false, BronzeApiError.Network);
  }

  Future<BronzeApiQuoteResult> brokerQuote(
      BronzeApikey apikey, BronzeApiQuote quote) async {
    var body = jsonEncode({
      'key': apikey.key,
      'nonce': _nonce(),
      'market': quote.market,
      'side': describeEnum(quote.side).toLowerCase(),
      'amount': quote.amount.toString(),
      'amountAsQuoteCurrency': quote.amountAsQuoteCurrency,
    });
    var sig = createHmacSig(apikey.secret, body);
    var response = await _postAndCatch('BrokerQuote', body,
        extraHeaders: {'X-Signature': sig});
    if (response != null) {
      if (response.statusCode == 400)
        return BronzeApiQuoteResult.makeError(
            BronzeApiError.Auth, response.body);
      if (response.statusCode == 200) {
        var json = jsonDecode(response.body);
        var assetSend = json['assetSend'];
        var amountSend = Decimal.parse(json['amountSend']);
        var assetReceive = json['assetReceive'];
        var amountReceive = Decimal.parse(json['amountReceive']);
        var timeLimit = json['timeLimit'];
        return BronzeApiQuoteResult(assetSend, amountSend, assetReceive,
            amountReceive, timeLimit, BronzeApiError.None, null);
      }
    }
    return BronzeApiQuoteResult.makeError(BronzeApiError.Network, null);
  }
}

class BronzeScreen extends StatelessWidget {
  BronzeScreen(this._ws, this._side) : super();

  final BronzeApiSide _side;
  final WalletState _ws;

  String _zapVerb() {
    return describeEnum(_side);
  }

  String _nzdVerb() {
    return _side == BronzeApiSide.Sell ? 'Receive' : 'Send';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          leading: backButton(context),
          title: Text('${_zapVerb()} Zap', style: TextStyle(color: ZapWhite)),
          backgroundColor: ZapBlue,
        ),
        body: CustomPaint(
            painter: CustomCurve(ZapBlue, 120, 200),
            child: Container(
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height,
                padding: EdgeInsets.all(20),
                child: BronzeForm(_ws, _side, _zapVerb, _nzdVerb))));
  }
}

class BronzeForm extends StatefulWidget {
  final WalletState _ws;
  final BronzeApiSide _side;
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

  bool _amountNzdValid = true;
  bool _amountZapValid = true;
  bool _apikeyValid = false;
  Timer? _amountTimer;
  ProcessingQuote _processingQuote = ProcessingQuote.None;

  @protected
  @mustCallSuper
  void initState() {
    super.initState();
    _initApiKey();
  }

  @protected
  @mustCallSuper
  void dispose() {
    super.dispose();
    _amountTimer?.cancel();
  }

  Future<bool> _createApiKey(String email) async {
    var bronze = Bronze(widget._ws.testnet);
    showAlertDialog(context, 'registering...');
    var registration =
        await bronze.register(email, await widget._ws.deviceName());
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

  void _initApiKey() async {
    while (true) {
      var bronze = Bronze(widget._ws.testnet);
      // create api key if none present
      if (!await Prefs.hasBronzeApiKey()) {
        var email =
            await askString(context, 'Enter email to connect to Bronze', null);
        if (email == null || email.isEmpty) {
          Navigator.pop(context);
          return;
        }
        if (!await _createApiKey(email)) {
          await alert(context, 'Registration failed',
              'Unable to register with Bronze at this time');
          Navigator.pop(context);
          return;
        }
      }
      // validate api key
      showAlertDialog(context, 'validating api key...');
      var validationResult = await bronze.apikeyValidate(await _apikey());
      Navigator.pop(context);
      if (!validationResult.value) {
        // reset key and create again
        if (validationResult.error == BronzeApiError.Auth) {
          await Prefs.bronzeApiKeySet(null);
        } else {
          await alert(context, 'Unable to connect',
              'Unable to connect to Bronze at this time');
          Navigator.pop(context);
          break;
        }
      } else {
        setState(() => _apikeyValid = true);
        break;
      }
    }
  }

  Future<BronzeApikey> _apikey() async {
    var key = await Prefs.bronzeApiKeyGet();
    var secret = await Prefs.bronzeApiSecretGet();
    return BronzeApikey(key!, secret!);
  }

  Future<bool> _canLeave() {
    return Future<bool>.value(true);
  }

  void _updateQuote() async {
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
    var quote = BronzeApiQuote(BronzeZapNzdMarket, widget._side, amount,
        _processingQuote == ProcessingQuote.ZAP);
    var bronze = Bronze(widget._ws.testnet);
    var quoteResult = await bronze.brokerQuote(await _apikey(), quote);
    switch (quoteResult.error) {
      case BronzeApiError.None:
        var quoteAmountReceive = (widget._side == BronzeApiSide.Sell) ^
            (_processingQuote == ProcessingQuote.ZAP);
        controllerQuote.text = quoteAmountReceive
            ? quoteResult.amountReceive.toString()
            : quoteResult.amountSend.toString();
        break;
      case BronzeApiError.Network:
        flushbarMsg(context, 'Network error',
            category: MessageCategory.Warning);
        break;
      case BronzeApiError.Auth:
        if (quoteResult.errorMessage != null)
          flushbarMsg(context, quoteResult.errorMessage!,
              category: MessageCategory.Warning);
        break;
    }
    setState(() => _processingQuote = ProcessingQuote.None);
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
                child: Text('${widget._zapVerb().toLowerCase()} zap',
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
            Padding(
              padding: const EdgeInsets.only(top: 24.0),
              child: RoundedButton(
                  () => Navigator.pop(context), ZapBlue, ZapWhite, 'cancel',
                  borderColor: ZapBlue,
                  minWidth: MediaQuery.of(context).size.width / 2),
            ),
          ],
        ),
      )),
      onWillPop: _canLeave,
    );
  }
}
