import 'dart:convert';

import 'package:zapdart/libzap.dart';
import 'package:zapdart/prefhelper.dart';

import 'config.dart';
import 'paydb.dart';
import 'bronze_order.dart';

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
  final Iterable<PayDbRole> roles;

  PayDbAccount(
      this.email, this.photo, this.photoType, this.permissions, this.roles);
  PayDbAccount.empty()
      : email = '',
        photo = null,
        photoType = null,
        permissions = [],
        roles = [];
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

  static Future<String?> bronzeApiKeyGet() async {
    return await getStringNetworkSpecific("bronze_apikey", null);
  }

  static Future<bool> bronzeApiKeySet(String? value) async {
    await setStringNetworkSpecific("bronze_apikey", value);
    return true;
  }

  static Future<String?> bronzeApiSecretGet() async {
    return await getStringNetworkSpecific("bronze_apisecret", null);
  }

  static Future<bool> bronzeApiSecretSet(String? value) async {
    await setStringNetworkSpecific("bronze_apisecret", value);
    return true;
  }

  static Future<bool> hasBronzeApiKey() async {
    var apikey = await Prefs.bronzeApiKeyGet();
    if (apikey == null || apikey.isEmpty) return false;
    var apisecret = await Prefs.bronzeApiSecretGet();
    if (apisecret == null || apisecret.isEmpty) return false;
    return true;
  }

  static Future<String?> bronzeKycTokenGet() async {
    return await getStringNetworkSpecific("bronze_kyc_token", null);
  }

  static Future<bool> bronzeKycTokenSet(String? value) async {
    await setStringNetworkSpecific("bronze_kyc_token", value);
    return true;
  }

  static Future<String?> bronzeBankAccountGet() async {
    return await getStringNetworkSpecific("bronze_bank_account", null);
  }

  static Future<bool> bronzeBankAccountSet(String? value) async {
    await setStringNetworkSpecific("bronze_bank_account", value);
    return true;
  }

  static Future<List<BronzeOrder>> bronzeOrdersGet() async {
    var orders = <BronzeOrder>[];
    var data = await getStringNetworkSpecific("bronze_orders", null);
    if (data != null && data.isNotEmpty)
      for (var item in jsonDecode(data)) orders.add(BronzeOrder.fromJson(item));
    return orders;
  }

  static Future<bool> bronzeOrdersSet(List<BronzeOrder> orders) async {
    return await setStringNetworkSpecific("bronze_orders", jsonEncode(orders));
  }

  static Future<bool> bronzeOrderAdd(BronzeOrder order) async {
    var orders = await bronzeOrdersGet();
    orders.add(order);
    return await bronzeOrdersSet(orders);
  }

  static Future<List<BronzeOrder>> bronzeOrderUpdate(
      BronzeOrder updatedOrder) async {
    var orders = await bronzeOrdersGet();
    for (var order in orders)
      if (order.token == updatedOrder.token) order.status = updatedOrder.status;
    await bronzeOrdersSet(orders);
    return orders;
  }

  static Future<bool> nukeAll() async {
    return await PrefHelper().nukeAll();
  }
}
