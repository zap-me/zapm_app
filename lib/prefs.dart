import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ini/ini.dart';

import 'libzap.dart';

class PrefHelper {
  static final _section = "main";

  PrefHelper();

  static Future<Config> fromFile() async {
    var config = Config();
    var f = File("zap.ini");
    if (await f.exists()) {
      var data = await File("zap.ini").readAsLines();
      config = Config.fromStrings(data);
    }
    if (!config.hasSection(_section))
      config.addSection(_section);
    return config;
  }

  Future<void> toFile(Config config) async {
    await File("zap.ini").writeAsString(config.toString());
  }

  Future<void> setBool(String key, bool value) async {
    if (Platform.isAndroid || Platform.isIOS) {
      final prefs = await SharedPreferences.getInstance();
      prefs.setBool(key, value);
    }
    else {
      var config = await fromFile();
      config.set(_section, key, value.toString());
      await toFile(config);
    }
  }

  Future<bool> getBool(String key, bool defaultValue) async {
    if (Platform.isAndroid || Platform.isIOS) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(key) ?? defaultValue;
    }
    else {
      var config = await fromFile();
      var value = config.get(_section, key) ?? defaultValue.toString();
      return value.toLowerCase() == 'true';
    }  
  }

  Future<void> setString(String key, String value) async {
    if (Platform.isAndroid || Platform.isIOS) {
      final prefs = await SharedPreferences.getInstance();
      prefs.setString(key, value);
    }
    else {
      var config = await fromFile();
      config.set(_section, key, value);
      await toFile(config);
    }
  }

  Future<String> getString(String key, String defaultValue) async {
    if (Platform.isAndroid || Platform.isIOS) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key) ?? defaultValue;
    }
    else {
      var config = await fromFile();
      return config.get(_section, key) ?? defaultValue;
    }  
  }
}

class Prefs {
  static Future<bool> testnetGet() async {
    final prefs = PrefHelper();
    return await prefs.getBool("testnet", true);
  }

  static void testnetSet(bool value) async {
    final prefs = PrefHelper();
    await prefs.setBool("testnet", value);

    // set libzap
    LibZap().testnetSet(value);
  }

  static Future<String> pinGet() async {
    final prefs = PrefHelper();
    return await prefs.getString("pin", null);
  }

  static Future<bool> pinSet(String value) async {
    final prefs = PrefHelper();
    await prefs.setString("pin", value);
    return true;
  }

  static Future<String> mnemonicGet() async {
    final prefs = PrefHelper();
    return await prefs.getString("mnemonic", null);
  }

  static Future<bool> mnemonicSet(String value) async {
    final prefs = PrefHelper();
    await prefs.setString("mnemonic", value);
    return true;
  }

  static Future<bool> mnemonicPasswordProtectedGet() async {
    var iv = await cryptoIVGet();
    return iv != null;
  }

  static Future<String> cryptoIVGet() async {
    final prefs = PrefHelper();
    return await prefs.getString("IV", null);
  }

  static Future<bool> cryptoIVSet(String value) async {
    final prefs = PrefHelper();
    await prefs.setString("IV", value);
    return true;
  }

  static Future<String> deviceNameGet() async {
    final prefs = PrefHelper();
    return await prefs.getString("deviceName", null);
  }

  static Future<bool> deviceNameSet(String value) async {
    final prefs = PrefHelper();
    await prefs.setString("deviceName", value);
    return true;
  }

  static Future<String> apikeyGet() async {
    final prefs = PrefHelper();
    return await prefs.getString("apikey", null);
  }

  static Future<bool> apikeySet(String value) async {
    final prefs = PrefHelper();
    await prefs.setString("apikey", value);
    return true;
  }

  static Future<String> apisecretGet() async {
    final prefs = PrefHelper();
    return await prefs.getString("apisecret", null);
  }

  static Future<bool> apisecretSet(String value) async {
    final prefs = PrefHelper();
    await prefs.setString("apisecret", value);
    return true;
  }
}