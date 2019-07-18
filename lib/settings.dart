import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:package_info/package_info.dart';

import 'libzap.dart';
import 'prefs.dart';

class SettingsScreen extends StatefulWidget {
  String _mnemonic = null;

  SettingsScreen(this._mnemonic) : super();

  @override
  _SettingsState createState() => new _SettingsState();
}

class _SettingsState extends State<SettingsScreen> {
  String _appVersion = null;
  String _buildNumber = null;
  int _libzapVersion = -1;
  bool _testnet = false;

  _SettingsState() {
    _initAppVersion();
    _libzapVersion = _getLibZapVersion();
    _initTestnet();
  }

  void _initAppVersion() {
    if (!Platform.isAndroid && !Platform.isIOS) {
      _appVersion = "Unknown ('package_info' not supported on ${Platform.operatingSystem})";
      _buildNumber = "N/A";
      return;
    }
    PackageInfo.fromPlatform().then((PackageInfo packageInfo) {
      setState(() {
        _appVersion = packageInfo.version;
        _buildNumber = packageInfo.buildNumber;
      });
    });
  }

  int _getLibZapVersion() {
    var libzap = LibZap();
    return libzap.version();
  }

  void _initTestnet() async {
    var testnet = await Prefs.TestnetGet();
    setState(() {
      _testnet = testnet;
    });
  }

  void _toggleTestnet() async {
    await Prefs.TestnetSet(!_testnet);
    setState(() {
      _testnet = !_testnet;
    });
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
                  await _toggleTestnet();
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.only(top: 18.0),
              child: ListTile(title: Text("Mnemonic"), subtitle: Text(widget._mnemonic)),
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