import 'package:flutter/material.dart';
import 'package:package_info/package_info.dart';
import 'package:tuple/tuple.dart';

import 'libzap.dart';

class SettingsScreen extends StatefulWidget {

  @override
  _SettingsState createState() => new _SettingsState();
}

class _SettingsState extends State<SettingsScreen> {
  String _appVersion = null;
  String _buildNumber = null;
  int _libzapVersion = -1;

  _SettingsState() {
    _setAppVersion();
    _libzapVersion = _getLibZapVersion();
  }

  void _setAppVersion() {
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
              child: Text("version: $_appVersion, build: $_buildNumber"),
            ),
            Container(
              padding: const EdgeInsets.only(top: 18.0),
              child: Text("libzap version: $_libzapVersion"),
            ),
            Container(
              padding: const EdgeInsets.only(top: 18.0),
              child: RaisedButton(
                onPressed: () {
                  Navigator.pop(context, );
                },
                child: Text('Go back!'),
              ),
            ),
          ],
        )
      )
    );
  }
}