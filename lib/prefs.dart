import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'libzap.dart';

class Prefs {
  static Future<bool> TestnetGet() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool("testnet") ?? true;
  }

  static void TestnetSet(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setBool("testnet", value);

    // set libzap
    LibZap().testnetSet(value);
  }
}

class PrefsSecure {
  static Future<String> MnemonicGet() async {
    final storage = new FlutterSecureStorage();
    var mnemonic = await storage.read(key: "mnemonic");
    return mnemonic;
  }

  static Future<bool> MnemonicSet(String value) async {
    final storage = new FlutterSecureStorage();
    await storage.write(key: "mnemonic", value: value);
    return true;
  }
}