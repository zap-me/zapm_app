import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:decimal/decimal.dart';
import 'package:flutter_icons/flutter_icons.dart';
import 'package:socket_io_client/socket_io_client.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:uni_links2/uni_links.dart';
import 'package:synchronized/synchronized.dart';
import 'package:device_info/device_info.dart';
import 'package:audioplayers/audio_cache.dart';

import 'package:zapdart/colors.dart';
import 'package:zapdart/qrwidget.dart';
import 'package:zapdart/widgets.dart';
import 'package:zapdart/utils.dart';
import 'package:zapdart/libzap.dart';

import 'config.dart';
import 'send_receive.dart';
import 'reward.dart';
import 'settlement.dart';
import 'settings.dart';
import 'prefs.dart';
import 'new_mnemonic_form.dart';
import 'account_forms.dart';
import 'transactions.dart';
import 'merchant.dart';
import 'recovery_form.dart';
import 'centrapay.dart';
import 'firebase.dart';
import 'paydb.dart';
import 'qrscan.dart';

void main() {
  // See https://github.com/flutter/flutter/wiki/Desktop-shells#target-platform-override
  _setTargetPlatformForDesktop();

  // print flutter errors to console
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
    const bool kReleaseMode =
        bool.fromEnvironment('dart.vm.product', defaultValue: false);
    if (kReleaseMode) exit(1);
  };

  // initialize any config functions
  initConfig();

  runApp(MyApp());
}

/// If the current platform is desktop, override the default platform to
/// a supported platform (iOS for macOS, Android for Linux and Windows).
/// Otherwise, do nothing.
void _setTargetPlatformForDesktop() {
  TargetPlatform? targetPlatform;
  if (Platform.isMacOS) {
    targetPlatform = TargetPlatform.iOS;
  } else if (Platform.isLinux || Platform.isWindows) {
    targetPlatform = TargetPlatform.android;
  }
  if (targetPlatform != null) {
    debugDefaultTargetPlatformOverride = targetPlatform;
  }
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
        onTap: () {
          // unfocus any text fields when touching non interactive part of app
          // this should hide any keyboards
          var currentFocus = FocusScope.of(context);
          if (!currentFocus.hasPrimaryFocus &&
              currentFocus.focusedChild != null) {
            FocusManager.instance.primaryFocus?.unfocus();
          }
        },
        child: MaterialApp(
          //debugShowCheckedModeBanner: false,
          title: AppTitle,
          theme: ThemeData(
            brightness: ZapBrightness,
            primaryColor: ZapWhite,
            accentColor: ZapBlue,
            textTheme: ZapTextThemer(Theme.of(context).textTheme),
            primaryTextTheme: ZapTextThemer(Theme.of(context).textTheme),
          ),
          home: ZapHomePage(AppTitle),
        ));
  }
}

class ZapHomePage extends StatefulWidget {
  ZapHomePage(this.title, {Key? key}) : super(key: key);

  final String title;

  @override
  _ZapHomePageState createState() => new _ZapHomePageState();
}

enum NoWalletAction {
  CreateMnemonic,
  RecoverMnemonic,
  RecoverRaw,
  ScanMerchantApiKey
}
enum NoAccountAction { Register, Login, RequestApiKey }
enum Capability { Receive, Balance, History, Spend }
enum InitTokenDetailsResult { None, NoData, Auth, Network }

class _ZapHomePageState extends State<ZapHomePage> with WidgetsBindingObserver {
  Socket? _merchantSocket; // merchant portal websocket
  StreamSubscription? _uniLinksSub; // uni links subscription

  bool _testnet = true;
  WavesWallet _wallet = WavesWallet.empty();
  PayDbAccount _account = PayDbAccount.empty();
  Decimal _fee = Decimal.parse("0.01");
  Decimal _balance = Decimal.fromInt(-1);
  String _balanceText = "...";
  bool _updatingBalance = true;
  bool _showAlerts = true;
  List<String> _alerts = <String>[];
  Rates? _merchantRates;
  Uri? _previousUniUri;
  final Lock _previousUniUriLock = Lock();
  FCM? _fcm;
  final audioPlayer = AudioCache();
  bool _walletOrAcctInited = false;
  bool _walletOrAcctLoading = false;
  AppVersion? _appVersion;

  _ZapHomePageState();

  @override
  void initState() {
    _init();
    // add WidgetsBindingObserver
    WidgetsBinding.instance?.addObserver(this);
    super.initState();
  }

  String _addrOrAccount() {
    switch (AppTokenType) {
      case TokenType.Waves:
        return 'wallet address';
      case TokenType.PayDB:
        return 'account';
    }
  }

  String _addrOrAccountValue() {
    switch (AppTokenType) {
      case TokenType.Waves:
        if (_wallet.address.isNotEmpty) return _wallet.address;
        break;
      case TokenType.PayDB:
        if (_account.email.isNotEmpty) return _account.email;
        break;
    }
    return '...';
  }

  String _mnemonicOrAccount() {
    switch (AppTokenType) {
      case TokenType.Waves:
        if (_wallet.isMnemonic) return _wallet.mnemonic;
        break;
      case TokenType.PayDB:
        if (_account.email.isNotEmpty) return _account.email;
        break;
    }
    return '...';
  }

  Widget _profileImage() {
    switch (AppTokenType) {
      case TokenType.Waves:
        return SizedBox();
      case TokenType.PayDB:
        return Padding(
            child: paydbAccountImage(_account.photo, _account.photoType),
            padding: EdgeInsets.only(right: 20));
    }
  }

  Future<bool> processUri(Uri uri) async {
    print('$uri');

    switch (AppTokenType) {
      case TokenType.Waves:
        // process waves links
        //
        // waves://<addr>...
        //
        var result = parseWavesUri(_testnet, uri.toString());
        if (result.error == NO_ERROR) {
          var tx = await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => SendScreen(_testnet, _wallet.mnemonic,
                    _fee, uri.toString(), _balance)),
          );
          if (tx != null) _updateBalance();
          return true;
        }
        break;
      case TokenType.PayDB:
        // process paydb links
        //
        // premiopay://<acct>...
        //
        if (PayDbUri.parse(uri.toString()) != null) {
          var tx = await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => SendScreen(
                    _testnet, _account.email, _fee, uri.toString(), _balance)),
          );
          if (tx != null) _updateBalance();
          return true;
        }
        break;
    }

    // process premio stage links (scheme parameter is optional - default to 'https')
    //
    // premiostagelink://<HOST>/claim_payment/<CLAIM_CODE>[?scheme=<SCHEME>]
    //
    if (uri.isScheme('premiostagelink')) {
      if (uri.pathSegments.length == 2 &&
          uri.pathSegments[0] == 'claim_payment') {
        var scheme = 'https';
        if (uri.queryParameters.containsKey('scheme'))
          scheme = uri.queryParameters['scheme']!;
        var url = uri.replace(scheme: scheme);
        var body = {};
        var recipient;
        switch (AppTokenType) {
          case TokenType.Waves:
            if (_wallet.address.isNotEmpty)
              throw FormatException(
                  'wallet address must be valid to claim payment');
            recipient = _wallet.address;
            body = {'recipient': recipient, 'asset_id': LibZap().assetIdGet()};
            break;
          case TokenType.PayDB:
            if (_account.email.isNotEmpty)
              throw FormatException(
                  'account email must be valid to claim payment');
            recipient = _account.email;
            body = {'recipient': recipient};
            break;
        }
        var resultText = '';
        var failed = false;
        showAlertDialog(context, 'claiming payment..');
        try {
          var response = await httpPost(url, body);
          if (response.statusCode == 200)
            resultText = 'claimed funds to $recipient';
          else {
            resultText =
                'claim link failed: ${response.statusCode} - ${response.body}';
            failed = true;
          }
        } catch (e) {
          resultText = 'claim link failed: $e';
          failed = true;
        }
        Navigator.pop(context);
        flushbarMsg(context, resultText,
            category: failed ? MessageCategory.Warning : MessageCategory.Info);
        return true;
      }
    }

    // process centrapay links
    //
    // http://app.centrapay.com/pay/<REQUEST_ID>
    //
    if (CentrapayApiKey != null) {
      var qr = centrapayParseQrcode(uri.toString());
      if (qr != null) {
        var tx = await Navigator.push<Tx>(
          context,
          MaterialPageRoute(
              builder: (context) => CentrapayScreen(
                  _testnet, _wallet.mnemonic, _fee, _balance, qr)),
        );
        if (tx != null) _updateBalance();
        return true;
      }
    }

    // did not recognize uri
    return false;
  }

  Future<Null> initUniLinks() async {
    // Check if the app was started with a link
    try {
      var initialUri = await getInitialUri();
      if (initialUri != null) {
        if (!await processUri(initialUri))
          flushbarMsg(context, 'invalid URL',
              category: MessageCategory.Warning);
      }
    } on FormatException {
      print('intial uri format exception!');
    } on PlatformException {
      print('intial uri platform exception!');
    } catch (e) {
      print('intial uri exception: $e');
    }

    // Attach a listener to catch any links when app is running in the background
    _uniLinksSub = uriLinkStream.listen((Uri? uri) async {
      await _previousUniUriLock.synchronized(() async {
        if (_previousUniUri != uri) {
          // this seems to be invoked twice so ignore the second one
          if (uri != null && !await processUri(uri))
            flushbarMsg(context, 'invalid URL',
                category: MessageCategory.Warning);
          _previousUniUri = uri;
        }
      });
      // clear the uri here so the user can manually invoke twice
      Future.delayed(const Duration(seconds: 2), () => _previousUniUri = null);
    }, onError: (err) {
      print('uri stream error: $err');
    });
  }

  @override
  void dispose() {
    // remove WidgetsBindingObserver
    WidgetsBinding.instance?.removeObserver(this);
    // close socket
    _merchantSocket?.close();
    // close uni links subscription
    _uniLinksSub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print("App lifestyle state changed: $state");
    if (state == AppLifecycleState.resumed) if (AppTokenType == TokenType.Waves)
      _watchAddress();
  }

  void _txNotification(String txid, String sender, String recipient,
      double amount, String? attachment) {
    var amountString = "${amount.toStringAsFixed(2)} $AssetShortNameUpper";
    // convert amount to NZD
    if (_merchantRates != null) {
      var amountDec = Decimal.parse(amount.toString());
      amountString += " / ${toNZDAmount(amountDec, _merchantRates!)}";
    }
    // decode attachment
    if (attachment != null && attachment.isNotEmpty)
      try {
        attachment = base58decodeString(attachment);
      } catch (_) {}
    // play audio file
    audioPlayer.play('chaching.mp3');
    // show user overview of new tx
    showDialog(
        context: context,
        barrierDismissible:
            false, // dialog is dismissible with a tap on the barrier
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text("received $amountString"),
            content: Container(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: <Widget>[
                  ListTile(title: Text("TXID"), subtitle: Text(txid)),
                  ListTile(
                    title: Text("sender"),
                    subtitle: Text(sender),
                  ),
                  ListTile(title: Text("amount"), subtitle: Text(amountString)),
                  ListTile(
                      title: Text(attachment != null && attachment.isNotEmpty
                          ? "attachment"
                          : ""),
                      subtitle: Text(attachment != null && attachment.isNotEmpty
                          ? attachment
                          : "")),
                ],
              ),
            ),
            actions: <Widget>[
              RoundedButton(
                  () => Navigator.pop(context), ZapBlue, ZapWhite, 'ok',
                  borderColor: ZapBlue),
            ],
          );
        });
    if (UseMerchantApi)
      // alert server to update merchant tx table
      merchantTx();
    // update balance
    _updateBalance();
  }

  void _watchAddress() async {
    assert(AppTokenType == TokenType.Waves);
    // do nothing if the address, apikey or apisecret is not set
    if (_wallet.address.isEmpty) return;
    if (!await Prefs.hasMerchantApiKey()) return;
    // register to watch our address
    if (!await merchantWatch(_wallet.address)) {
      flushbarMsg(context, 'failed to register address',
          category: MessageCategory.Warning);
      return;
    }
    // create socket to receive tx alerts
    _merchantSocket?.close();
    _merchantSocket = await merchantSocket(_txNotification);
  }

  Future<NoWalletAction> _noWalletDialog(BuildContext context) async {
    assert(AppTokenType == TokenType.Waves);
    var res = await showDialog<NoWalletAction>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return SimpleDialog(
            title: const Text(UseMerchantApi
                ? "You do not have recovery words or an address saved, what would you like to do?"
                : "You do not have recovery words saved, what would you like to do?"),
            children: <Widget>[
              SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(context, NoWalletAction.CreateMnemonic);
                },
                child: const Text("Create new recovery words"),
              ),
              SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(context, NoWalletAction.RecoverMnemonic);
                },
                child: const Text("Recover using your recovery words"),
              ),
              SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(context, NoWalletAction.RecoverRaw);
                },
                child: const Text(
                    "Recover using a raw seed string (advanced use only)"),
              ),
              Visibility(
                  visible: UseMerchantApi,
                  child: SimpleDialogOption(
                      onPressed: () {
                        Navigator.pop(
                            context, NoWalletAction.ScanMerchantApiKey);
                      },
                      child: const Text("Scan retailer api key"))),
            ],
          );
        });
    if (res != null) return res;
    return NoWalletAction.RecoverMnemonic;
  }

  Future<bool> _directLoginAccountDialog(BuildContext context) async {
    assert(AppTokenType == TokenType.PayDB);
    var res = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return SimpleDialog(
            title: const Text("User registration in process"),
            children: <Widget>[
              Center(
                  child: const Text("Complete by confirming your email",
                      style: TextStyle(fontSize: 10))),
              SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(context, true);
                },
                child: const Text("I have confirmed my email (login now)"),
              ),
              SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(context, false);
                },
                child: const Text("I will confirm my email later"),
              ),
            ],
          );
        });
    return res != null && res;
  }

  Future<bool> _waitApiKeyAccountDialog(BuildContext context) async {
    assert(AppTokenType == TokenType.PayDB);
    var res = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return SimpleDialog(
            title: const Text("API KEY request in process"),
            children: <Widget>[
              Center(
                  child: const Text("Complete by confirming your email",
                      style: TextStyle(fontSize: 10))),
              SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(context, true);
                },
                child:
                    const Text("I have confirmed my email (claim API KEY now)"),
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
    return res != null && res;
  }

  Future<NoAccountAction> _noAccountDialog(BuildContext context) async {
    assert(AppTokenType == TokenType.PayDB);
    var server = await paydbServer();
    var res = await showDialog<NoAccountAction>(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return SimpleDialog(
            title: const Text("Register or Login"),
            children: <Widget>[
              Center(
                  child:
                      Text("Server: $server", style: TextStyle(fontSize: 10))),
              SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(context, NoAccountAction.Register);
                },
                child: const Text("Register a new account"),
              ),
              SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(context, NoAccountAction.Login);
                },
                child: const Text("Login to your account"),
              ),
              SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(context, NoAccountAction.RequestApiKey);
                },
                child: const Text("Request API KEY from your account"),
              ),
            ],
          );
        });
    if (res != null) return res;
    return NoAccountAction.Login;
  }

  Future<String?> _recoverMnemonic(BuildContext context) {
    return Navigator.push<String>(
        context, MaterialPageRoute(builder: (context) => RecoveryForm()));
  }

  Future<String?> _recoverSeed(BuildContext context) async {
    String seed = "";
    return showDialog<String>(
      context: context,
      barrierDismissible:
          false, // dialog is dismissible with a tap on the barrier
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Enter your raw seed string to recover your account"),
          content: Row(
            children: <Widget>[
              Expanded(
                  child: Container(
                      constraints: BoxConstraints(maxWidth: 300),
                      child: TextField(
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: "Seed",
                        ),
                        onChanged: (value) {
                          seed = value;
                        },
                      )))
            ],
          ),
          actions: <Widget>[
            FlatButton(
              child: Text("Ok"),
              onPressed: () {
                Navigator.of(context).pop(seed);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _noWallet() async {
    assert(AppTokenType == TokenType.Waves);
    var libzap = LibZap();
    while (true) {
      String? mnemonic;
      String? address;
      setState(() => _walletOrAcctLoading = false);
      var action = await _noWalletDialog(context);
      setState(() => _walletOrAcctLoading = true);
      switch (action) {
        case NoWalletAction.CreateMnemonic:
          mnemonic = libzap.mnemonicCreate();
          if (mnemonic != null)
            // show warning for new mnemonic
            await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => NewMnemonicForm(mnemonic!)),
            );
          break;
        case NoWalletAction.RecoverMnemonic:
          // recover mnemonic
          mnemonic = await _recoverMnemonic(context);
          if (mnemonic != null) {
            mnemonic = mnemonic.trim();
            mnemonic = mnemonic.replaceAll(RegExp(r"\s+"), " ");
            mnemonic = mnemonic.toLowerCase();
            if (!libzap.mnemonicCheck(mnemonic)) {
              mnemonic = null;
            }
          }
          if (mnemonic == null)
            await alert(context, "Recovery words not valid",
                "The recovery words you entered are not valid");
          break;
        case NoWalletAction.RecoverRaw:
          // recover raw seed string
          mnemonic = await _recoverSeed(context);
          break;
        case NoWalletAction.ScanMerchantApiKey:
          var value = await QrScan.scan(context);
          if (value != null) {
            var result = parseApiKeyUri(value);
            if (result.error == NO_ERROR) {
              if (result.walletAddress.isEmpty) {
                flushbarMsg(context, 'wallet address not present',
                    category: MessageCategory.Warning);
                break;
              }
              await Prefs.addressSet(result.walletAddress);
              await Prefs.deviceNameSet(result.deviceName);
              await Prefs.merchantApiKeySet(result.apikey);
              await Prefs.merchantApiSecretSet(result.apisecret);
              if (result.apiserver.isNotEmpty)
                await Prefs.merchantApiServerSet(result.apiserver);
              flushbarMsg(context, 'API KEY set');
              address = result.walletAddress;
            } else
              flushbarMsg(context, 'invalid QR code',
                  category: MessageCategory.Warning);
          }
          break;
      }
      if (mnemonic != null && mnemonic.isNotEmpty) {
        await Prefs.mnemonicSet(mnemonic);
        await alert(context, "Recovery words saved", ":)");
        break;
      }
      if (address != null && address.isNotEmpty) {
        await Prefs.addressSet(address);
        await alert(context, "Address saved", ":)");
        break;
      }
    }
  }

  Future<String> _deviceName() async {
    var device = 'app';
    if (Platform.isAndroid)
      device = (await DeviceInfoPlugin().androidInfo).model;
    if (Platform.isIOS)
      device = (await DeviceInfoPlugin().iosInfo).utsname.machine;
    var date = DateTime.now().toIso8601String().split('T').first;
    return '$device - $date';
  }

  Future<String?> _paydbLogin(AccountLogin login) async {
    var deviceName = await _deviceName();
    var result =
        await paydbApiKeyCreate(login.email, login.password, deviceName);
    switch (result.error) {
      case PayDbError.Auth:
        await alert(context, "Authentication not valid",
            "The login details you entered are not valid");
        break;
      case PayDbError.Network:
        await alert(context, "Network error",
            "A network error occured when trying to login");
        break;
      case PayDbError.None:
        // write api key
        if (result.apikey != null) {
          await Prefs.paydbApiKeySet(result.apikey!.token);
          await Prefs.paydbApiSecretSet(result.apikey!.secret);
        }
        return login.email;
    }
    return null;
  }

  Future<String?> _paydbApiKeyClaim(
      AccountRequestApiKey req, String token) async {
    var result = await paydbApiKeyClaim(token);
    switch (result.error) {
      case PayDbError.Auth:
        await alert(context, "Authentication not valid",
            "The login details you entered are not valid");
        break;
      case PayDbError.Network:
        await alert(context, "Network error",
            "A network error occured when trying to login");
        break;
      case PayDbError.None:
        // write api key
        if (result.apikey != null) {
          await Prefs.paydbApiKeySet(result.apikey!.token);
          await Prefs.paydbApiSecretSet(result.apikey!.secret);
        }
        return req.email;
    }
    return null;
  }

  Future<void> _noAccount() async {
    assert(AppTokenType == TokenType.PayDB);
    if (await paydbServer() == null) {
      Prefs.testnetSet(!_testnet);
      await _updateTestnet();
    }
    assert(await paydbServer() != null);
    while (true) {
      String? accountEmail;
      setState(() => _walletOrAcctLoading = false);
      var action = await _noAccountDialog(context);
      setState(() => _walletOrAcctLoading = true);
      switch (action) {
        case NoAccountAction.Register:
          AccountRegistration? registration;
          while (accountEmail == null) {
            // show register form
            registration = await Navigator.push<AccountRegistration>(
              context,
              MaterialPageRoute(
                  builder: (context) => AccountRegisterForm(registration)),
            );
            if (registration == null) break;
            var result = await paydbUserRegister(registration);
            switch (result) {
              case PayDbError.Auth:
              case PayDbError.Network:
                await alert(context, "Network error",
                    "A network error occured when trying to login");
                break;
              case PayDbError.None:
                if (await _directLoginAccountDialog(context))
                  // save account if login successful
                  accountEmail = await _paydbLogin(
                      AccountLogin(registration.email, registration.password));
                break;
            }
          }
          break;
        case NoAccountAction.Login:
          AccountLogin? login;
          while (accountEmail == null) {
            // login form
            login = await Navigator.push<AccountLogin>(
              context,
              MaterialPageRoute(builder: (context) => AccountLoginForm(login)),
            );
            if (login == null) break;
            // save account if login successful
            accountEmail = await _paydbLogin(login);
          }
          break;
        case NoAccountAction.RequestApiKey:
          // request api key form
          var deviceName = await _deviceName();
          var req = await Navigator.push<AccountRequestApiKey>(
            context,
            MaterialPageRoute(
                builder: (context) => AccountRequestApiKeyForm(deviceName)),
          );
          if (req == null) break;
          var result = await paydbApiKeyRequest(req.email, req.deviceName);
          switch (result.error) {
            case PayDbError.Auth:
            case PayDbError.Network:
              await alert(context, "Network error",
                  "A network error occured when trying to login");
              break;
            case PayDbError.None:
              assert(result.token != null);
              while (await _waitApiKeyAccountDialog(context)) {
                // claim api key
                accountEmail = await _paydbApiKeyClaim(req, result.token!);
                if (accountEmail != null) break;
              }
              break;
          }
          break;
      }
      if (accountEmail != null && accountEmail.isNotEmpty) {
        _account = PayDbAccount(accountEmail, '', '', []);
        await alert(context, "Login successful", ":)");
        break;
      }
    }
  }

  Future<bool> _updateTestnet() async {
    // update testnet
    _testnet = await _setTestnet();
    setState(() {
      var testnetText = 'Testnet!';
      if (_testnet && !_alerts.contains(testnetText)) _alerts.add(testnetText);
      if (!_testnet && _alerts.contains(testnetText))
        _alerts.remove(testnetText);
    });
    return true;
  }

  Future<bool> _updateBalance() async {
    setState(() {
      // start updating balance spinner
      _updatingBalance = true;
      // update state
      _wallet = _wallet;
      _account = _account;
    });
    var balance = Decimal.fromInt(-1);
    var balanceText = ":(";
    switch (AppTokenType) {
      case TokenType.Waves:
        // get fee
        var feeResult = await LibZap.transactionFee();
        if (feeResult.success)
          _fee = Decimal.fromInt(feeResult.value) / Decimal.fromInt(100);
        // get balance
        var balanceResult = await LibZap.addressBalance(_wallet.address);
        if (balanceResult.success) {
          balance = Decimal.fromInt(balanceResult.value) / Decimal.fromInt(100);
          balanceText = _balance.toStringAsFixed(2);
        }
        break;
      case TokenType.PayDB:
        var result = await paydbUserInfo();
        switch (result.error) {
          case PayDbError.Auth:
          case PayDbError.Network:
            break;
          case PayDbError.None:
            assert(result.info != null);
            balance =
                Decimal.fromInt(result.info!.balance) / Decimal.fromInt(100);
            balanceText = balance.toStringAsFixed(2);
            break;
        }
        break;
    }
    setState(() {
      _balance = balance;
      _balanceText = balanceText;
      // stop updating balance spinner
      _updatingBalance = false;
    });
    return true;
  }

  Future<InitTokenDetailsResult> _initTokenDetails() async {
    _alerts.clear();
    // check apikey
    if (UseMerchantApi && !await Prefs.hasMerchantApiKey())
      setState(() => _alerts.add('No Retailer API KEY set'));
    switch (AppTokenType) {
      case TokenType.Waves:
        // check mnemonic
        if (_wallet.isEmpty) {
          var libzap = LibZap();
          var mnemonic = await Prefs.mnemonicGet();
          if (mnemonic != null && mnemonic.isNotEmpty) {
            var mnemonicPasswordProtected =
                await Prefs.mnemonicPasswordProtectedGet();
            if (mnemonicPasswordProtected) {
              while (true) {
                var password = await askMnemonicPassword(context);
                if (password == null || password.isEmpty) {
                  continue;
                }
                var iv = await Prefs.cryptoIVGet();
                var decryptedMnemonic =
                    decryptMnemonic(mnemonic!, iv!, password);
                if (decryptedMnemonic == null) {
                  await alert(context, "Could not decrypt recovery words",
                      "the password entered is probably wrong");
                  continue;
                }
                if (!libzap.mnemonicCheck(decryptedMnemonic)) {
                  var yes = await askYesNo(
                      context, 'The recovery words are not valid, is this ok?');
                  if (!yes) continue;
                }
                mnemonic = decryptedMnemonic;
                break;
              }
            }
            var address = libzap.seedAddress(mnemonic);
            _wallet = WavesWallet.mnemonic(mnemonic, address);
          } else {
            var address = await Prefs.addressGet();
            if (address != null && address.isNotEmpty) {
              _wallet = WavesWallet.justAddress(address);
            } else {
              return InitTokenDetailsResult.NoData;
            }
          }
        } else if (_wallet.isMnemonic) {
          // reinitialize wallet address (we might have toggled testnet)
          var address = LibZap().seedAddress(_wallet.mnemonic);
          _wallet = WavesWallet.mnemonic(_wallet.mnemonic, address);
        }
        break;
      case TokenType.PayDB:
        // check apikey
        if (!await Prefs.hasPaydbApiKey()) return InitTokenDetailsResult.NoData;
        var result = await paydbUserInfo();
        switch (result.error) {
          case PayDbError.None:
            assert(result.info != null);
            _account = PayDbAccount(result.info!.email, result.info!.photo,
                result.info!.photoType, result.info!.permissions);
            break;
          case PayDbError.Auth:
            var yes = await askYesNo(
                context, 'Authentication failed, delete credentials?');
            if (yes) {
              await Prefs.paydbApiKeySet(null);
              await Prefs.paydbApiKeySet(null);
            }
            return InitTokenDetailsResult.Auth;
          case PayDbError.Network:
            await alert(context, "Network error",
                "check your network settings before continuing");
            return InitTokenDetailsResult.Network;
        }
        break;
    }
    // update testnet and balance
    _updateTestnet();
    _updateBalance();
    // watch wallet address
    if (AppTokenType == TokenType.Waves) _watchAddress();
    // update merchant rates
    if (UseMerchantApi && await Prefs.hasMerchantApiKey())
      merchantRates().then((value) => _merchantRates = value);
    return InitTokenDetailsResult.None;
  }

  void _showQrCode() {
    showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return Align(
            alignment: Alignment.center,
            child: Card(
                child: InkWell(
                    child: Container(
                        width: 300,
                        height: 300,
                        child: QrWidget(_addrOrAccountValue(), size: 300)),
                    onTap: () => Navigator.pop(context))));
      },
    );
  }

  void _copyAddrOrAccount() {
    Clipboard.setData(ClipboardData(text: _addrOrAccountValue())).then((value) {
      flushbarMsg(context, 'copied ${_addrOrAccount()} to clipboard');
    });
  }

  void _scanQrCode() async {
    var value = await QrScan.scan(context);
    if (value == null) return;

    switch (AppTokenType) {
      case TokenType.Waves:
        // waves address or uri
        var result = parseRecipientOrWavesUri(_testnet, value);
        if (result != null) {
          var tx = await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => SendScreen(
                    _testnet, _wallet.mnemonic, _fee, value, _balance)),
          );
          if (tx != null) _updateBalance();
          return;
        }
        // merchant claim code
        var ccresult = parseClaimCodeUri(value);
        if (ccresult.error == NO_ERROR) {
          if (await merchantClaim(ccresult.code, _wallet.address))
            flushbarMsg(context, 'claim succeded');
          else
            flushbarMsg(context, 'claim failed',
                category: MessageCategory.Warning);
          return;
        }
        break;
      case TokenType.PayDB:
        // paydb recipient or uri
        if (paydbParseValid(value)) {
          var tx = await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (context) => SendScreen(
                    _testnet, _account.email, _fee, value, _balance)),
          );
          if (tx != null) _updateBalance();
          return;
        }
        break;
    }
    // other uris we support
    try {
      var uri = Uri.parse(value);
      if (!await processUri(uri))
        flushbarMsg(context, 'invalid QR code',
            category: MessageCategory.Warning);
    } on FormatException {
      flushbarMsg(context, 'invalid QR code',
          category: MessageCategory.Warning);
    }
  }

  void _send() async {
    var tx = await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => SendScreen(
              _testnet,
              _mnemonicOrAccount(),
              AppTokenType == TokenType.Waves ? _fee : Decimal.fromInt(0),
              '',
              _balance)),
    );
    if (tx != null) _updateBalance();
  }

  void _receive() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) =>
              ReceiveScreen(_testnet, _addrOrAccountValue(), _txNotification)),
    );
  }

  void _transactions() async {
    var deviceName = await Prefs.deviceNameGet();
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) => TransactionsScreen(
              _addrOrAccountValue(),
              _testnet,
              _haveCapabililty(Capability.Spend) ? null : deviceName,
              _merchantRates)),
    );
  }

  void _showSettings() async {
    var _pinExists = await Prefs.pinExists();
    if (!await pinCheck(context, await Prefs.pinGet())) {
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (context) =>
              SettingsScreen(_pinExists, _mnemonicOrAccount(), _fcm)),
    );
    _initTokenDetails();
  }

  void _zapReward() async {
    var sentFunds = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (context) => RewardScreen(_wallet.mnemonic, _fee, _balance)),
    );
    if (sentFunds == true) _updateBalance();
  }

  void _settlement() async {
    var sentFunds = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (context) =>
              SettlementScreen(_wallet.mnemonic, _fee, _balance)),
    );
    if (sentFunds == true) _updateBalance();
  }

  void _showWallet() {
    Navigator.pop(context);
  }

  void _showHomepage() {
    if (WebviewURL != null) {
      var webview = WebView(
        initialUrl: WebviewURL,
        javascriptMode: JavascriptMode.unrestricted,
        gestureNavigationEnabled: true,
      );
      Navigator.push<bool>(
          context,
          MaterialPageRoute(
              builder: (context) => _appScaffold(webview, isHomepage: true)));
    }
  }

  bool _haveCapabililty(Capability cap) {
    switch (AppTokenType) {
      case TokenType.Waves:
        switch (cap) {
          case Capability.Receive:
            return _wallet.address.isNotEmpty;
          case Capability.Balance:
          case Capability.History:
          case Capability.Spend:
            return _wallet.isMnemonic;
        }
      case TokenType.PayDB:
        switch (cap) {
          case Capability.Receive:
            return _account.permissions.contains(PayDbPermission.receive);
          case Capability.Balance:
            return _account.permissions.contains(PayDbPermission.balance);
          case Capability.History:
            return _account.permissions.contains(PayDbPermission.history);
          case Capability.Spend:
            return _account.permissions.contains(PayDbPermission.transfer);
        }
    }
  }

  Future<bool> _setTestnet() async {
    var testnet = await Prefs.testnetGet();
    if (AppTokenType == TokenType.Waves) {
      var libzap = LibZap();
      libzap.networkParamsSet(AssetIdMainnet, AssetIdTestnet, NodeUrlMainnet,
          NodeUrlTestnet, testnet);
      if (!_wallet.isMnemonic) {
        if (!libzap.addressCheck(_wallet.address)) {
          testnet = !testnet;
          libzap.networkParamsSet(AssetIdMainnet, AssetIdTestnet,
              NodeUrlMainnet, NodeUrlTestnet, testnet);
          await Prefs.testnetSet(testnet);
        }
      }
    }
    return testnet;
  }

  void _toggleAlerts() {
    setState(() => _showAlerts = !_showAlerts);
  }

  void _init() async {
    // init _testnet var
    _testnet = await _setTestnet();
    // get app version
    _appVersion = await AppVersion.parsePubspec();
    setState(() {
      _appVersion = _appVersion;
    });
    // set libzap to initial testnet value so we can devrive address from mnemonic
    var testnet = await Prefs.testnetGet();
    LibZap().networkParamsSet(AssetIdMainnet, AssetIdTestnet, NodeUrlMainnet,
        NodeUrlTestnet, testnet);
    // init wallet
    var tokenDetailsResult = InitTokenDetailsResult.NoData;
    while (tokenDetailsResult != InitTokenDetailsResult.None) {
      tokenDetailsResult = await _initTokenDetails();
      if (tokenDetailsResult == InitTokenDetailsResult.NoData) {
        switch (AppTokenType) {
          case TokenType.Waves:
            await _noWallet();
            break;
          case TokenType.PayDB:
            await _noAccount();
            break;
        }
      }
    }
    // wallet/account now initialized
    _walletOrAcctInited = true;
    // webview
    _showHomepage();
    // init firebase push notifications
    _fcm = FCM(context, PremioStageIndexUrl, PremioStageName);
    // init uni links
    initUniLinks();
  }

  Widget _appScaffold(Widget body, {bool isHomepage = false}) {
    return Scaffold(
        appBar: AppBar(
          leading: Visibility(
            child: IconButton(
                onPressed: _toggleAlerts,
                icon: Icon(Icons.warning,
                    color: _showAlerts ? ZapGrey : ZapWarning)),
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            visible: _alerts.length > 0 && !isHomepage,
          ),
          title: Center(
              child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                WebviewURL != null
                    ? IconButton(
                        icon: Icon(
                            isHomepage ? Icons.home : Icons.home_outlined,
                            color: ZapBlue),
                        onPressed: isHomepage ? null : _showHomepage)
                    : Spacer(),
                Image.asset(AssetHeaderIconPng, height: 30),
                WebviewURL != null
                    ? IconButton(
                        icon: Icon(
                            isHomepage
                                ? Icons.account_balance_wallet_outlined
                                : Icons.account_balance_wallet,
                            color: ZapBlue),
                        onPressed: isHomepage ? _showWallet : null)
                    : Spacer()
              ])),
          actions: <Widget>[
            IconButton(
                icon: Icon(Icons.settings_outlined, color: ZapBlue),
                onPressed: _showSettings),
          ],
        ),
        body: body);
  }

  @override
  Widget build(BuildContext context) {
    if (!_walletOrAcctInited)
      return Scaffold(
          body: Column(children: [
        SizedBox(height: 100),
        Center(child: Image.asset(AssetHeaderIconPng, height: 30)),
        Visibility(
            visible: _appVersion != null,
            child: Center(
                child: Text("${_appVersion?.version}+${_appVersion?.build}",
                    style: TextStyle(fontSize: 10)))),
        SizedBox(height: 50),
        Visibility(
            visible: _walletOrAcctLoading,
            child: SizedBox(
                child: CircularProgressIndicator(), height: 28.0, width: 28.0))
      ]));

    return _appScaffold(
      RefreshIndicator(
        onRefresh: _updateBalance,
        child: ListView(
          children: <Widget>[
            Visibility(
                visible: _showAlerts && _alerts.length > 0,
                child: AlertDrawer(_toggleAlerts, _alerts)),
            Visibility(
                visible: _haveCapabililty(Capability.Balance),
                child: Column(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.only(top: 28.0),
                      child: Text(
                        'my balance:',
                        style: TextStyle(
                            color: ZapBlackMed, fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Container(
                      height: 100,
                      width: MediaQuery.of(context).size.width,
                      child: Card(
                        child: Align(
                            alignment: Alignment.center,
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: <Widget>[
                                  Visibility(
                                      visible: _updatingBalance,
                                      child: SizedBox(
                                        child: CircularProgressIndicator(),
                                        height: 28.0,
                                        width: 28.0,
                                      )),
                                  Visibility(
                                      visible: !_updatingBalance,
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: <Widget>[
                                          Text(_balanceText,
                                              style: TextStyle(
                                                  color: ZapBlue,
                                                  fontSize: 28)),
                                          SizedBox.fromSize(size: Size(4, 1)),
                                          SvgPicture.asset(AssetBalanceIconSvg,
                                              height: 20)
                                        ],
                                      ))
                                ])),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0),
                        ),
                        margin: EdgeInsets.all(10),
                      ),
                    ),
                  ],
                )),
            Visibility(
                visible: _haveCapabililty(Capability.Receive),
                child: Column(children: <Widget>[
                  Container(
                    padding: const EdgeInsets.only(top: 28.0),
                    child: Text('${_addrOrAccount()}:',
                        style: TextStyle(
                            color: ZapBlackMed, fontWeight: FontWeight.w700),
                        textAlign: TextAlign.center),
                  ),
                  Container(
                      padding: const EdgeInsets.only(top: 18.0),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _profileImage(),
                            Text(_addrOrAccountValue(),
                                style: TextStyle(color: ZapBlackLight),
                                textAlign: TextAlign.center),
                          ])),
                  Divider(),
                  Container(
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                        RoundedButton(
                            _showQrCode, ZapBlue, ZapWhite, 'view QR code',
                            icon: MaterialCommunityIcons.qrcode_scan,
                            minWidth:
                                MediaQuery.of(context).size.width / 2 - 20),
                        RoundedButton(_copyAddrOrAccount, ZapWhite, ZapBlue,
                            'copy ${_addrOrAccount()}',
                            minWidth:
                                MediaQuery.of(context).size.width / 2 - 20),
                      ]))
                ])),
            Container(
                //height: 300, ???
                margin: const EdgeInsets.only(top: 40),
                padding: const EdgeInsets.only(top: 20),
                color: ZapWhite,
                child: Column(
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget?>[
                        _haveCapabililty(Capability.Spend)
                            ? SquareButton(
                                _send,
                                MaterialCommunityIcons.chevron_double_up,
                                ZapYellow,
                                'SEND $AssetShortNameUpper')
                            : null,
                        _haveCapabililty(Capability.Spend)
                            ? SquareButton(
                                _scanQrCode,
                                MaterialCommunityIcons.qrcode_scan,
                                ZapBlue,
                                'SCAN QR CODE')
                            : null,
                        SquareButton(
                            _receive,
                            MaterialCommunityIcons.chevron_double_down,
                            ZapGreen,
                            'RECEIVE $AssetShortNameUpper'),
                      ].where((child) => child != null).toList().cast<Widget>(),
                    ),
                    SizedBox.fromSize(size: Size(1, 10)),
                    Visibility(
                      visible: _haveCapabililty(Capability.History),
                      child: ListButton(_transactions, 'transactions'),
                    ),
                    Visibility(
                      visible: _haveCapabililty(Capability.Spend) && UseReward,
                      child: ListButton(
                          _zapReward, '$AssetShortNameLower rewards'),
                    ),
                    Visibility(
                      visible:
                          _haveCapabililty(Capability.Spend) && UseSettlement,
                      child: ListButton(_settlement, 'make settlement'),
                    ),
                    ListButtonEnd(),
                    Center(
                        child: Text(
                            "${_appVersion?.version}+${_appVersion?.build}",
                            style: TextStyle(fontSize: 10))),
                  ],
                )),
          ],
        ),
      ),
    );
  }
}
