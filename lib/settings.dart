import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_icons/flutter_icons.dart';
import 'package:package_info/package_info.dart';
import 'package:yaml/yaml.dart';

import 'package:zapdart/libzap.dart';
import 'package:zapdart/utils.dart';
import 'package:zapdart/pinentry.dart';
import 'package:zapdart/widgets.dart';
import 'package:zapdart/colors.dart';
import 'package:zapdart/bip39widget.dart';

import 'config.dart';
import 'merchant.dart';
import 'prefs.dart';
import 'hidden.dart';
import 'firebase.dart';
import 'paydb.dart';
import 'qrscan.dart';

class AppVersion {
  final String version;
  final String build;

  AppVersion(this.version, this.build);

  static Future<AppVersion> parsePubspec() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      var pubspec = await rootBundle.loadString('pubspec.yaml');
      var doc = loadYaml(pubspec);
      var version = doc["version"].toString().split("+");
      return AppVersion(version[0], version[1]);
    } else {
      var packageInfo = await PackageInfo.fromPlatform();
      return AppVersion(packageInfo.version, packageInfo.buildNumber);
    }
  }
}

class SettingsScreen extends StatefulWidget {
  final bool _pinProtectedInitial;
  final String? _mnemonicOrAccount;
  final FCM? _fcm;

  SettingsScreen(this._pinProtectedInitial, this._mnemonicOrAccount, this._fcm)
      : super();

  @override
  _SettingsState createState() => new _SettingsState(_pinProtectedInitial);
}

class _SettingsState extends State<SettingsScreen> {
  bool _secondary = true;
  bool _pinProtected = true;
  bool _showMnemonic = false;
  bool _mnemonicPasswordProtected = true;
  AppVersion? _appVersion;
  int _libzapVersion = -1;
  bool _testnet = false;
  String? _deviceName;
  String? _apikey;
  String? _apisecret;
  String? _apiserver;
  int _versionTaps = 0;
  String? _paydbServer;

  _SettingsState(this._pinProtected) {
    _initSettings();
    _libzapVersion = _getLibZapVersion();
  }

  void _initSettings() async {
    // app version
    var version = await AppVersion.parsePubspec();
    setState(() {
      _appVersion = version;
    });
    // wallet
    var mnemonicPasswordProtected = await Prefs.mnemonicPasswordProtectedGet();
    setState(() {
      _mnemonicPasswordProtected = mnemonicPasswordProtected;
    });
    // testnet
    var testnet = await Prefs.testnetGet();
    setState(() {
      _testnet = testnet;
    });
    // api key
    var deviceName = await Prefs.deviceNameGet();
    var apikey = await Prefs.merchantApiKeyGet();
    var apisecret = await Prefs.merchantApiSecretGet();
    var apiserver = await Prefs.merchantApiServerGet();
    // paydb server
    var paydbserver = await paydbServer();
    setState(() {
      _deviceName = deviceName;
      _apikey = apikey;
      _apisecret = apisecret;
      _apiserver = apiserver;
      _paydbServer = paydbserver;
    });
  }

  int _getLibZapVersion() {
    var libzap = LibZap();
    return libzap.version();
  }

  String _getWalletAddress(String _mnemonic) {
    var libzap = LibZap();
    return libzap.seedAddress(_mnemonic);
  }

  @override
  void initState() {
    super.initState();
    // set secondary
    _secondary = widget._mnemonicOrAccount == null;
  }

  void _toggleTestnet() async {
    if (_secondary) return;
    Prefs.testnetSet(!_testnet);
    setState(() {
      _testnet = !_testnet;
    });
    _initSettings();
  }

  void _addPin() async {
    var pin = await Navigator.push<String>(
      context,
      MaterialPageRoute(
          builder: (context) => PinEntryScreen('', 'Enter New Pin')),
    );
    if (pin != null) {
      var pin2 = await Navigator.push<String>(
        context,
        MaterialPageRoute(
            builder: (context) => PinEntryScreen(pin, 'Repeat New Pin')),
      );
      if (pin2 != null && pin == pin2) {
        await Prefs.pinSet(pin);
        flushbarMsg(context, 'pin set');
        setState(() {
          _pinProtected = true;
        });
      }
    }
  }

  void _changePin() async {
    var pin = await Prefs.pinGet();
    if (pin == null) return;
    var pin2 = await Navigator.push<String>(
      context,
      MaterialPageRoute(
          builder: (context) => PinEntryScreen(pin, 'Enter Current Pin')),
    );
    if (pin == pin2) {
      _addPin();
    }
  }

  void _removePin() async {
    var pin = await Prefs.pinGet();
    if (pin == null) return;
    var pin2 = await Navigator.push<String>(
      context,
      MaterialPageRoute(
          builder: (context) => PinEntryScreen(pin, 'Enter Current Pin')),
    );
    if (pin == pin2) {
      await Prefs.pinSet('');
      flushbarMsg(context, 'pin removed');
      setState(() {
        _pinProtected = false;
      });
    }
  }

  void _addPasswordProtection() async {
    assert(AppTokenType == TokenType.Waves);
    if (widget._mnemonicOrAccount == null) return;
    var password = await askSetMnemonicPassword(context);
    if (password != null) {
      var res = encryptMnemonic(widget._mnemonicOrAccount!, password);
      await Prefs.cryptoIVSet(res.iv);
      await Prefs.mnemonicSet(res.encryptedMnemonic);
      setState(() {
        _mnemonicPasswordProtected = true;
      });
    }
  }

  void _scanApikey() async {
    var value = await QrScan.scan(context);
    if (value != null) {
      var result = parseApiKeyUri(value);
      if (result.error == NO_ERROR) {
        await Prefs.deviceNameSet(result.deviceName);
        await Prefs.merchantApiKeySet(result.apikey);
        await Prefs.merchantApiSecretSet(result.apisecret);
        if (result.apiserver.isNotEmpty)
          await Prefs.merchantApiServerSet(result.apiserver);
        setState(() {
          _deviceName = result.deviceName;
          _apikey = result.apikey;
          _apisecret = result.apisecret;
          if (result.apiserver.isNotEmpty) _apiserver = result.apiserver;
        });
        flushbarMsg(context, 'API KEY set');
        if (result.accountAdmin &&
            result.walletAddress.isEmpty &&
            widget._mnemonicOrAccount != null) {
          var address = _getWalletAddress(widget._mnemonicOrAccount!);
          var yes = await askYesNo(context,
              "Do you want to set the account wallet address ($address)?");
          if (yes) {
            var res = await merchantWalletAddress(address);
            if (res) {
              flushbarMsg(context, 'account wallet address set');
            } else {
              flushbarMsg(context, 'failed to set account wallet address',
                  category: MessageCategory.Warning);
            }
          }
        }
      } else
        flushbarMsg(context, 'invalid QR code',
            category: MessageCategory.Warning);
    }
  }

  void _editDeviceName() async {
    var deviceName = await askString(context, "Set Device Name", _deviceName);
    if (deviceName != null) {
      await Prefs.deviceNameSet(deviceName);
      setState(() {
        _deviceName = deviceName;
      });
    }
  }

  void _editApikey() async {
    var apikey = await askString(context, "Set Api Key", _apikey);
    if (apikey != null) {
      await Prefs.merchantApiKeySet(apikey);
      setState(() {
        _apikey = apikey;
      });
    }
  }

  void _editApisecret() async {
    var apisecret = await askString(context, "Set Api Secret", _apisecret);
    if (apisecret != null) {
      await Prefs.merchantApiSecretSet(apisecret);
      setState(() {
        _apisecret = apisecret;
      });
    }
  }

  void _editApiserver() async {
    var apiserver = await askString(context, "Set Api Server", _apiserver);
    if (apiserver != null) {
      await Prefs.merchantApiServerSet(apiserver);
      setState(() {
        _apiserver = apiserver;
      });
    }
  }

  void _versionTap() {
    _versionTaps += 1;
    if (_versionTaps > 10) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => HiddenScreen(
                _testnet, widget._fcm?.getToken(), widget._mnemonicOrAccount)),
      );
    }
  }

  Widget _recoveryWords() {
    if (!_secondary && widget._mnemonicOrAccount != null)
      return Bip39Words.fromString(widget._mnemonicOrAccount!);
    return Text('n/a');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          leading: backButton(context, color: ZapBlack),
          title: Text("Settings"),
        ),
        body: Center(
          child: ListView(
            children: <Widget>[
              GestureDetector(
                onTap: _versionTap,
                child: ListTile(
                    title: Text("Version: ${_appVersion?.version}"),
                    subtitle: Text("Build: ${_appVersion?.build}")),
              ),
              Visibility(
                visible: AppTokenType == TokenType.Waves,
                child: ListTile(title: Text("Libzap Version: $_libzapVersion")),
              ),
              Visibility(
                visible: AppTokenType == TokenType.PayDB,
                child: ListTile(title: Text("Server: $_paydbServer")),
              ),
              Container(
                padding: const EdgeInsets.only(top: 18.0),
                child: SwitchListTile(
                  value: _testnet,
                  title: Text("Testnet"),
                  onChanged: (value) async {
                    _toggleTestnet();
                  },
                ),
              ),
              Visibility(
                  visible: !_secondary,
                  child: Column(
                    children: <Widget>[
                      Container(
                        padding: const EdgeInsets.only(top: 18.0),
                        child: ListTile(
                          title: Text("Pin Protect Settings and Spending"),
                          trailing: _pinProtected
                              ? Icon(Icons.lock)
                              : Icon(Icons.lock_open),
                        ),
                      ),
                      Visibility(
                        visible: !_pinProtected,
                        child: Container(
                          child: ListTile(
                            title: raisedButtonIcon(
                                label: Text("Create Pin"),
                                icon: Icon(Icons.lock),
                                onPressed: _addPin),
                          ),
                        ),
                      ),
                      Visibility(
                        visible: _pinProtected,
                        child: Container(
                          child: ListTile(
                            title: raisedButtonIcon(
                                label: Text("Change Pin"),
                                icon: Icon(Icons.lock),
                                onPressed: _changePin),
                          ),
                        ),
                      ),
                      Visibility(
                        visible: _pinProtected,
                        child: Container(
                          child: ListTile(
                            title: raisedButtonIcon(
                                label: Text("Remove Pin"),
                                icon: Icon(Icons.lock),
                                onPressed: _removePin),
                          ),
                        ),
                      ),
                      Visibility(
                        visible:
                            !_showMnemonic && AppTokenType == TokenType.Waves,
                        child: Container(
                          padding: const EdgeInsets.only(top: 18.0),
                          child: ListTile(
                            title: raisedButton(
                                child: Text("Show Recovery Words"),
                                onPressed: () =>
                                    setState(() => _showMnemonic = true)),
                          ),
                        ),
                      ),
                      Visibility(
                          visible:
                              _showMnemonic && AppTokenType == TokenType.Waves,
                          child: Container(
                            padding: const EdgeInsets.only(top: 18.0),
                            child: ListTile(
                              title: Text("Recovery words"),
                              subtitle: _recoveryWords(),
                              trailing: _mnemonicPasswordProtected
                                  ? Icon(Icons.lock)
                                  : Icon(Icons.lock_open),
                            ),
                          )),
                      Visibility(
                        visible: !_mnemonicPasswordProtected &&
                            AppTokenType == TokenType.Waves,
                        child: Container(
                          child: ListTile(
                            title: raisedButtonIcon(
                                label: Text("Password Protect Recovery words"),
                                icon: Icon(Icons.lock),
                                onPressed: _addPasswordProtection),
                          ),
                        ),
                      ),
                    ],
                  )),
              Visibility(
                  visible: UseMerchantApi,
                  child: Column(children: <Widget>[
                    Container(
                      padding: const EdgeInsets.only(top: 18.0),
                      child: ListTile(
                        title: raisedButtonIcon(
                            label: Text("Scan Api Key"),
                            icon: Icon(MaterialCommunityIcons.qrcode_scan),
                            onPressed: !_secondary ? _scanApikey : null),
                      ),
                    ),
                    ListTile(
                      title: Text("Device Name"),
                      subtitle: Text("$_deviceName"),
                      trailing: raisedButtonIcon(
                          label: Text("Edit"),
                          icon: Icon(Icons.edit),
                          onPressed: !_secondary ? _editDeviceName : null),
                    ),
                    ListTile(
                      title: Text("Api Key"),
                      subtitle: Text("$_apikey"),
                      trailing: raisedButtonIcon(
                          label: Text("Edit"),
                          icon: Icon(Icons.edit),
                          onPressed: !_secondary ? _editApikey : null),
                    ),
                    ListTile(
                      title: Text("Api Secret"),
                      subtitle: Text("$_apisecret"),
                      trailing: raisedButtonIcon(
                          label: Text("Edit"),
                          icon: Icon(Icons.edit),
                          onPressed: !_secondary ? _editApisecret : null),
                    ),
                    ListTile(
                      title: Text("Api Server"),
                      subtitle: Text("$_apiserver"),
                      trailing: raisedButtonIcon(
                          label: Text("Edit"),
                          icon: Icon(Icons.edit),
                          onPressed: !_secondary ? _editApiserver : null),
                    ),
                  ]))
            ],
          ),
        ));
  }
}
