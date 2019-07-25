import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:package_info/package_info.dart';
import 'package:yaml/yaml.dart';

import 'libzap.dart';
import 'prefs.dart';
import 'utils.dart';

class SettingsScreen extends StatefulWidget {
  String _mnemonic;
  bool _mnemonicPasswordProtected;

  SettingsScreen(this._mnemonic, this._mnemonicPasswordProtected) : super();

  @override
  _SettingsState createState() => new _SettingsState();
}

class _SettingsState extends State<SettingsScreen> {
  String _appVersion;
  String _buildNumber;
  int _libzapVersion = -1;
  bool _testnet = false;

  _SettingsState() {
    _initAppVersion();
    _libzapVersion = _getLibZapVersion();
    _initTestnet();
  }

  void _initAppVersion() async {
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
  }

  int _getLibZapVersion() {
    var libzap = LibZap();
    return libzap.version();
  }

  void _initTestnet() async {
    var testnet = await Prefs.testnetGet();
    setState(() {
      _testnet = testnet;
    });
  }

  void _toggleTestnet() async {
    await Prefs.testnetSet(!_testnet);
    setState(() {
      _testnet = !_testnet;
    });
  }

  void _addPasswordProtection() async {
    var password = await askSetMnemonicPassword(context);
    if (password != null) {
      var res = encryptMnemonic(widget._mnemonic, password);
      await Prefs.cryptoIVSet(res.iv);
      await Prefs.mnemonicSet(res.encryptedMnemonic);
      setState(() {
        widget._mnemonicPasswordProtected = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Settings"),
      ),
      body: Center(
        child: Column(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.only(top: 18.0),
              child: ListTile(title: Text("Version: $_appVersion"), subtitle: Text("Build: $_buildNumber")),
            ),
            Container(
              padding: const EdgeInsets.only(top: 18.0),
              child: ListTile(title: Text("Libzap Version: $_libzapVersion")),
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
            Container(
              padding: const EdgeInsets.only(top: 18.0),
              child: ListTile(title: Text("Mnemonic"), subtitle: Text(widget._mnemonic), trailing: widget._mnemonicPasswordProtected ? Icon(Icons.lock) : Icon(Icons.lock_open),),
            ),
            Visibility(
              visible: !widget._mnemonicPasswordProtected,
              child: Container(
                child: ListTile(
                  title: RaisedButton.icon(label: Text("Password Protect Mnemonic"), icon: Icon(Icons.lock), onPressed: () { _addPasswordProtection(); }),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.only(top: 18.0),
              child: RaisedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: Icon(Icons.close),
                  label: Text('Close'))
              ),
            ],
          ),
        )
    );
  }
}