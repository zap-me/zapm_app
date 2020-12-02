import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_icons/flutter_icons.dart';
import 'package:package_info/package_info.dart';
import 'package:yaml/yaml.dart';
import 'package:qrcode_reader/qrcode_reader.dart';

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

class SettingsScreen extends StatefulWidget {
  final bool _pinProtectedInitial;
  final String _mnemonic;

  SettingsScreen(this._pinProtectedInitial, this._mnemonic) : super();

  @override
  _SettingsState createState() => new _SettingsState(_pinProtectedInitial);
}

class _SettingsState extends State<SettingsScreen> {
  bool _secondary = true;
  bool _pinProtected;
  bool _showMnemonic = false;
  bool _mnemonicPasswordProtected = true;
  String _appVersion;
  String _buildNumber;
  int _libzapVersion = -1;
  bool _testnet = false;
  String _deviceName;
  String _apikey;
  String _apisecret;
  String _apiserver;
  int _titleTaps = 0;

  _SettingsState(this._pinProtected) {
    _initSettings();
    _libzapVersion = _getLibZapVersion();
  }

  void _initSettings() async {
    // app version
    if (!Platform.isAndroid && !Platform.isIOS) {
      var pubspec = await rootBundle.loadString('pubspec.yaml');
      var doc = loadYaml(pubspec);
      var version = doc["version"].toString().split("+");
      setState(() {
        _appVersion = version[0];
        _buildNumber = version[1];
      });
    }
    else {
      var packageInfo = await PackageInfo.fromPlatform();
      setState(() {
        _appVersion = packageInfo.version;
        _buildNumber = packageInfo.buildNumber;
      });
    }
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
    var apikey = await Prefs.apikeyGet();
    var apisecret = await Prefs.apisecretGet();
    var apiserver = await Prefs.apiserverGet();
    setState(() {
      _deviceName = deviceName;
      _apikey = apikey;
      _apisecret = apisecret;
      _apiserver = apiserver;
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
    _secondary = widget._mnemonic == null;
  }

  void _toggleTestnet() async {
    if (_secondary)
      return;
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
          builder: (context) => PinEntryScreen(null, 'Enter New Pin')),
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
    var password = await askSetMnemonicPassword(context);
    if (password != null) {
      var res = encryptMnemonic(widget._mnemonic, password);
      await Prefs.cryptoIVSet(res.iv);
      await Prefs.mnemonicSet(res.encryptedMnemonic);
      setState(() {
        _mnemonicPasswordProtected = true;
      });
    }
  }

  void _scanApikey() async {
    var value = await new QRCodeReader().scan();
    if (value != null) {
      var result = parseApiKeyUri(value);
      if (result.error == NO_ERROR) {
        await Prefs.deviceNameSet(result.deviceName);
        await Prefs.apikeySet(result.apikey);
        await Prefs.apisecretSet(result.apisecret);
        if (result.apiserver != null || result.apiserver.isNotEmpty)
          await Prefs.apiserverSet(result.apiserver);
        setState(() {
          _deviceName = result.deviceName;
          _apikey = result.apikey;
          _apisecret = result.apisecret;
          if (result.apiserver != null || result.apiserver.isNotEmpty)
            _apiserver = result.apiserver;
        });
        flushbarMsg(context, 'API KEY set');
        if (result.accountAdmin && result.walletAddress.isEmpty) {
          var address = _getWalletAddress(widget._mnemonic);
          var yes = await askYesNo(context, "Do you want to set the account wallet address ($address)?");
          if (yes) {
            var res = await merchantWalletAddress(address);
            if (res) {
              flushbarMsg(context, 'account wallet address set');
            } else {
              flushbarMsg(context, 'failed to set account wallet address', category: MessageCategory.Warning);
            }
          }
        }
      }
      else
        flushbarMsg(context, 'invalid QR code', category: MessageCategory.Warning);
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
      await Prefs.apikeySet(apikey);
      setState(() {
        _apikey = apikey;
      });
    }
  }

  void _editApisecret() async {
    var apisecret = await askString(context, "Set Api Secret", _apisecret);
    if (apisecret != null) {
      await Prefs.apisecretSet(apisecret);
      setState(() {
        _apisecret = apisecret;
      });
    }
  }

  void _editApiserver() async {
    var apiserver = await askString(context, "Set Api Server", _apiserver);
    if (apiserver != null) {
      await Prefs.apiserverSet(apiserver);
      setState(() {
        _apiserver = apiserver;
      });
    }
  }

  void _titleTap() {
    _titleTaps += 1;
    if (_titleTaps > 10) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => HiddenScreen(_testnet)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: backButton(context, color: ZapBlack),
        title: GestureDetector(onTap: _titleTap, child: Text("Settings")),
      ),
      body: Center(
        child: ListView( 
          children: <Widget>[
            ListTile(title: Text("Version: $_appVersion"), subtitle: Text("Build: $_buildNumber")),
            ListTile(title: Text("Libzap Version: $_libzapVersion")),
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
              child:  Column(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.only(top: 18.0),
                    child: ListTile(title: Text("Pin Protect Settings and Spending"), trailing: _pinProtected ? Icon(Icons.lock) : Icon(Icons.lock_open),),
                  ),
                  Visibility(
                    visible: !_pinProtected,
                    child: Container(
                      child: ListTile(
                        title: RaisedButton.icon(label: Text("Create Pin"), icon: Icon(Icons.lock), onPressed: _addPin),
                      ),
                    ),
                  ),
                  Visibility(
                    visible: _pinProtected,
                    child: Container(
                      child: ListTile(
                        title: RaisedButton.icon(label: Text("Change Pin"), icon: Icon(Icons.lock), onPressed: _changePin),
                      ),
                    ),
                  ),
                  Visibility(
                    visible: _pinProtected,
                    child: Container(
                      child: ListTile(
                        title: RaisedButton.icon(label: Text("Remove Pin"), icon: Icon(Icons.lock), onPressed: _removePin),
                      ),
                    ),
                  ),
                  Visibility(
                    visible: !_showMnemonic,
                    child: Container(
                      padding: const EdgeInsets.only(top: 18.0),
                      child: ListTile(
                        title: RaisedButton(child: Text("Show Recovery Words"), onPressed: () => setState(() => _showMnemonic = true)),
                      ),
                    ),
                  ),
                  Visibility(
                    visible: _showMnemonic,
                    child: Container(
                      padding: const EdgeInsets.only(top: 18.0),
                      child: ListTile(
                        title: Text("Recovery words"),
                        subtitle: !_secondary ? Bip39Words.fromString(widget._mnemonic) : Text('n/a'),
                        trailing: _mnemonicPasswordProtected ? Icon(Icons.lock) : Icon(Icons.lock_open),),
                    )
                  ),
                  Visibility(
                    visible: !_mnemonicPasswordProtected,
                    child: Container(
                      child: ListTile(
                        title: RaisedButton.icon(label: Text("Password Protect Recovery words"), icon: Icon(Icons.lock), onPressed: _addPasswordProtection),
                      ),
                    ),
                  ),
                ],
              )
            ),
            Visibility(
              visible: UseMerchantApi,
              child: Column(children: <Widget>[
                Container(
                  padding: const EdgeInsets.only(top: 18.0),
                  child: ListTile(
                    title: RaisedButton.icon(label: Text("Scan Api Key"), icon: Icon(MaterialCommunityIcons.qrcode_scan), onPressed: !_secondary ? _scanApikey : null),
                  ),
                ),
                ListTile(title: Text("Device Name"), subtitle: Text("$_deviceName"), trailing: RaisedButton.icon(label: Text("Edit"), icon: Icon(Icons.edit), onPressed: !_secondary ? _editDeviceName : null),),
                ListTile(title: Text("Api Key"), subtitle: Text("$_apikey"), trailing: RaisedButton.icon(label: Text("Edit"), icon: Icon(Icons.edit), onPressed: !_secondary ? _editApikey : null),),
                ListTile(title: Text("Api Secret"), subtitle: Text("$_apisecret"), trailing: RaisedButton.icon(label: Text("Edit"), icon: Icon(Icons.edit), onPressed: !_secondary ? _editApisecret : null),),
                ListTile(title: Text("Api Server"), subtitle: Text("$_apiserver"), trailing: RaisedButton.icon(label: Text("Edit"), icon: Icon(Icons.edit), onPressed: !_secondary ? _editApiserver : null),),
              ])
            )],
          ),
        )
    );
  }
}