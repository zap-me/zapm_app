import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:ini/ini.dart';

import 'libzap.dart';

enum PrefType {
  Main, Secure,
}
class PrefHelper {
  PrefType _type;

  PrefHelper(this._type);

  static Future<Config> fromFile() async {
    var config = Config();
    var f = File("zap.ini");
    if (await f.exists()) {
      var data = await File("zap.ini").readAsLines();
      config = Config.fromStrings(data);
    }
    for (var type in PrefType.values)
      if (!config.hasSection(type.toString()))
        config.addSection(type.toString());
    return config;
  }

  Future<void> toFile(Config config) async {
    await File("zap.ini").writeAsString(config.toString());
  }

  Future<void> setBool(String key, bool value) async {
    if (Platform.isAndroid || Platform.isIOS) {
      if (_type == PrefType.Main) {
        final prefs = await SharedPreferences.getInstance();
        prefs.setBool(key, value);
      }
      else {
        final storage = new FlutterSecureStorage();
        await storage.write(key: key, value: value.toString());
      }
    }
    else {
      var config = await fromFile();
      config.set(_type.toString(), key, value.toString());
      await toFile(config);
    }
  }

  Future<bool> getBool(String key, bool default_) async {
    if (Platform.isAndroid || Platform.isIOS) {
      if (_type == PrefType.Main) {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getBool(key) ?? default_;
      }
      else {
        final storage = new FlutterSecureStorage();
        var value = await storage.read(key: key) ?? default_.toString();
        return value.toLowerCase() == 'true';
      }
    }
    else {
      var config = await fromFile();
      var value = config.get(_type.toString(), key) ?? default_.toString();
      return value.toLowerCase() == 'true';
    }  
  }

  Future<void> setString(String key, String value) async {
    if (Platform.isAndroid || Platform.isIOS) {
      if (_type == PrefType.Main) {
        final prefs = await SharedPreferences.getInstance();
        prefs.setString(key, value);
      }
      else {
        final storage = new FlutterSecureStorage();
        await storage.write(key: key, value: value);
      }
    }
    else {
      var config = await fromFile();
      config.set(_type.toString(), key, value);
      await toFile(config);
    }
  }

  Future<String> getString(String key, String default_) async {
    if (Platform.isAndroid || Platform.isIOS) {
      if (_type == PrefType.Main) {
        final prefs = await SharedPreferences.getInstance();
        return prefs.getBool(key) ?? default_;
      }
      else {
        final storage = new FlutterSecureStorage();
        return await storage.read(key: key) ?? default_;
      }
    }
    else {
      var config = await fromFile();
      return config.get(_type.toString(), key) ?? default_;
    }  
  }
}

class Prefs {
  static Future<bool> TestnetGet() async {
    final prefs = PrefHelper(PrefType.Main);
    return await prefs.getBool("testnet", true);
  }

  static void TestnetSet(bool value) async {
    final prefs = PrefHelper(PrefType.Main);
    await prefs.setBool("testnet", value);

    // set libzap
    LibZap().testnetSet(value);
  }
}

class PrefsSecure {
  static Future<String> MnemonicGet() async {
    final prefs = PrefHelper(PrefType.Secure);
    var mnemonic = await prefs.getString("mnemonic", null);
    return mnemonic;
  }

  static Future<bool> MnemonicSet(String value) async {
    final prefs = PrefHelper(PrefType.Secure);
    await prefs.setString("mnemonic", value);
    return true;
  }
}