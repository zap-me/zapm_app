import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ini/ini.dart';

import 'package:zapdart/libzap.dart';

import 'config.dart';
import 'paydb.dart';

class WavesWallet {
  final String mnemonic;
  final String address;

  WavesWallet.mnemonic(this.mnemonic, this.address);
  WavesWallet.justAddress(this.address) : mnemonic = '';
  WavesWallet.empty()
      : mnemonic = '',
        address = '';

  bool get isEmpty => mnemonic.isEmpty && address.isEmpty;
  bool get isMnemonic => mnemonic.isNotEmpty;
  bool get isAddress => !isMnemonic && address.isNotEmpty;
}

class PayDbAccount {
  final String email;
  final String? photo;
  final String? photoType;
  final Iterable<PayDbPermission> permissions;

  PayDbAccount(this.email, this.photo, this.photoType, this.permissions);
  PayDbAccount.empty()
      : email = '',
        photo = null,
        photoType = null,
        permissions = [];
}

class GenTx {
  String id;
  String action;
  int timestamp;
  String sender;
  String recipient;
  String? attachment;
  int amount;
  int fee;
  bool validForWallet;

  GenTx(this.id, this.action, this.timestamp, this.sender, this.recipient,
      this.attachment, this.amount, this.fee, this.validForWallet);

  Map toJson() => {
        'id': id,
        'action': action,
        'timestamp': timestamp,
        'sender': sender,
        'recipient': recipient,
        'attachment': attachment,
        'amount': amount,
        'fee': fee,
        'validForWallet': validForWallet
      };

  factory GenTx.fromJson(dynamic json) {
    return GenTx(
        json['id'] as String,
        json['action'] as String,
        json['timestamp'] as int,
        json['sender'] as String,
        json['recipient'] as String,
        json['attachment'] as String?,
        json['amount'] as int,
        json['fee'] as int,
        json['validForWallet'] as bool);
  }
}

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
    if (!config.hasSection(_section)) config.addSection(_section);
    return config;
  }

  Future<void> toFile(Config config) async {
    await File("zap.ini").writeAsString(config.toString());
  }

  Future<void> setBool(String key, bool value) async {
    if (Platform.isAndroid || Platform.isIOS) {
      final prefs = await SharedPreferences.getInstance();
      prefs.setBool(key, value);
    } else {
      var config = await fromFile();
      config.set(_section, key, value.toString());
      await toFile(config);
    }
  }

  Future<bool> getBool(String key, bool defaultValue) async {
    if (Platform.isAndroid || Platform.isIOS) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(key) ?? defaultValue;
    } else {
      var config = await fromFile();
      var value = config.get(_section, key) ?? defaultValue.toString();
      return value.toLowerCase() == 'true';
    }
  }

  Future<void> setString(String key, String? value) async {
    if (Platform.isAndroid || Platform.isIOS) {
      final prefs = await SharedPreferences.getInstance();
      if (value == null)
        prefs.remove(key);
      else
        prefs.setString(key, value);
    } else {
      var config = await fromFile();
      if (value == null)
        config.removeOption(_section, key);
      else
        config.set(_section, key, value);
      await toFile(config);
    }
  }

  Future<String?> getString(String key, String? defaultValue) async {
    if (Platform.isAndroid || Platform.isIOS) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key) ?? defaultValue;
    } else {
      var config = await fromFile();
      return config.get(_section, key) ?? defaultValue;
    }
  }
}

class Prefs {
  static Future<String> getKeyNetworkSpecific(String key) async {
    var testnet = await testnetGet();
    if (!testnet) key = '${key}_mainnet';
    return key;
  }

  static Future<String?> getStringNetworkSpecific(
      String key, String? defaultValue) async {
    final prefs = PrefHelper();
    return prefs.getString(await getKeyNetworkSpecific(key), defaultValue);
  }

  static Future<bool> setStringNetworkSpecific(
      String key, String? value) async {
    final prefs = PrefHelper();
    prefs.setString(await getKeyNetworkSpecific(key), value);
    return true;
  }

  static Future<bool> testnetGet() async {
    final prefs = PrefHelper();
    return await prefs.getBool("testnet", TestnetDefault);
  }

  static Future<void> testnetSet(bool value) async {
    final prefs = PrefHelper();
    await prefs.setBool("testnet", value);

    // set libzap
    LibZap().networkParamsSet(
        AssetIdMainnet, AssetIdTestnet, NodeUrlMainnet, NodeUrlTestnet, value);
  }

  static Future<String?> pinGet() async {
    final prefs = PrefHelper();
    return await prefs.getString("pin", null);
  }

  static Future<bool> pinSet(String? value) async {
    final prefs = PrefHelper();
    await prefs.setString("pin", value);
    return true;
  }

  static Future<bool> pinExists() async {
    var pin = await Prefs.pinGet();
    return pin != null && pin != '';
  }

  static Future<String?> addressGet() async {
    return await getStringNetworkSpecific("address", null);
  }

  static Future<bool> addressSet(String? value) async {
    await setStringNetworkSpecific("address", value);
    return true;
  }

  static Future<String?> mnemonicGet() async {
    final prefs = PrefHelper();
    return await prefs.getString("mnemonic", null);
  }

  static Future<bool> mnemonicSet(String? value) async {
    final prefs = PrefHelper();
    await prefs.setString("mnemonic", value);
    return true;
  }

  static Future<bool> mnemonicPasswordProtectedGet() async {
    var iv = await cryptoIVGet();
    return iv != null && iv.isNotEmpty;
  }

  static Future<String?> cryptoIVGet() async {
    final prefs = PrefHelper();
    return await prefs.getString("IV", null);
  }

  static Future<bool> cryptoIVSet(String? value) async {
    final prefs = PrefHelper();
    await prefs.setString("IV", value);
    return true;
  }

  static Future<String?> deviceNameGet() async {
    return await getStringNetworkSpecific("deviceName", null);
  }

  static Future<bool> deviceNameSet(String? value) async {
    await setStringNetworkSpecific("deviceName", value);
    return true;
  }

  static Future<String?> merchantApiKeyGet() async {
    return await getStringNetworkSpecific("apikey", null);
  }

  static Future<bool> merchantApiKeySet(String? value) async {
    await setStringNetworkSpecific("apikey", value);
    return true;
  }

  static Future<String?> merchantApiSecretGet() async {
    return await getStringNetworkSpecific("apisecret", null);
  }

  static Future<bool> merchantApiSecretSet(String? value) async {
    await setStringNetworkSpecific("apisecret", value);
    return true;
  }

  static Future<String> merchantApiServerGet() async {
    var server = await getStringNetworkSpecific("apiserver", null);
    if (server == null || server.isEmpty) server = "https://retail.zap.me/";
    return server;
  }

  static Future<bool> merchantApiServerSet(String? value) async {
    await setStringNetworkSpecific("apiserver", value);
    return true;
  }

  static Future<bool> hasMerchantApiKey() async {
    var apikey = await merchantApiKeyGet();
    if (apikey == null || apikey.isEmpty) return false;
    var apisecret = await merchantApiSecretGet();
    if (apisecret == null || apisecret.isEmpty) return false;
    return true;
  }

  static Future<String?> paydbApiKeyGet() async {
    return await getStringNetworkSpecific("paydb_apikey", null);
  }

  static Future<bool> paydbApiKeySet(String? value) async {
    await setStringNetworkSpecific("paydb_apikey", value);
    return true;
  }

  static Future<String?> paydbApiSecretGet() async {
    return await getStringNetworkSpecific("paydb_apisecret", null);
  }

  static Future<bool> paydbApiSecretSet(String? value) async {
    await setStringNetworkSpecific("paydb_apisecret", value);
    return true;
  }

  static Future<bool> hasPaydbApiKey() async {
    var apikey = await Prefs.paydbApiKeyGet();
    if (apikey == null || apikey.isEmpty) return false;
    var apisecret = await Prefs.paydbApiSecretGet();
    if (apisecret == null || apisecret.isEmpty) return false;
    return true;
  }

  static Future<List<GenTx>> transactionsGet() async {
    var txs = <GenTx>[];
    var data = await getStringNetworkSpecific("transactions", null);
    if (data != null) {
      var list = jsonDecode(data) as List<dynamic>;
      for (var item in list) txs.add(GenTx.fromJson(item));
    }
    return txs;
  }

  static Future<bool> transactionsSet(List<GenTx> txs) async {
    return await setStringNetworkSpecific("transactions", jsonEncode(txs));
  }
}
