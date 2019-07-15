import 'package:shared_preferences/shared_preferences.dart';

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