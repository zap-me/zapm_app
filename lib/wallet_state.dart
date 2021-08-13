import 'dart:io';
import 'package:mutex/mutex.dart';
import 'package:flutter/material.dart';
import 'package:device_info/device_info.dart';
import 'package:decimal/decimal.dart';
import 'package:socket_io_client/socket_io_client.dart';

import 'package:zapdart/libzap.dart';
import 'package:zapdart/widgets.dart';
import 'package:zapdart/utils.dart';

import 'recovery_form.dart';
import 'new_mnemonic_form.dart';
import 'account_forms.dart';
import 'config.dart';
import 'paydb.dart';
import 'prefs.dart';
import 'merchant.dart';
import 'qrscan.dart';
import 'old_settings.dart';

enum NoWalletAction {
  CreateMnemonic,
  RecoverMnemonic,
  RecoverRaw,
  ScanMerchantApiKey
}
enum NoAccountAction { Register, Login, RequestApiKey }
enum Capability { Receive, Balance, History, Spend }
enum InitTokenDetailsResult { None, NoData, Auth, Network }

class TxDownloadResult {
  final bool success;
  final int downloadCount;
  final int validCount;
  final bool end;
  final String? lastTxid;
  TxDownloadResult(this.success, this.downloadCount, this.validCount, this.end,
      this.lastTxid);
}

typedef WalletStateUpdateCallback = void Function(
    WalletState ws, bool updatingBalance, bool loading, bool inited);

class TxDownloader {
  TxDownloader(this._ws) {
    loadTxs();
  }

  final WalletState _ws;
  final m = Mutex();

  var _txsAll = <GenTx>[];
  var _txsFiltered = <GenTx>[];
  String? _lastTxId;
  var _foundEnd = false;

  List<GenTx> get txs {
    return _txsFiltered;
  }

  bool get foundEnd {
    return _foundEnd;
  }

  String _wavesAssetId() {
    return _ws.testnet
        ? (AssetIdTestnet != null ? AssetIdTestnet! : LibZap.TESTNET_ASSET_ID)
        : (AssetIdMainnet != null ? AssetIdMainnet! : LibZap.MAINNET_ASSET_ID);
  }

  String? _wavesAttachment(String? attachment) {
    if (attachment != null && attachment.isNotEmpty)
      return base58decodeString(attachment);
    return attachment;
  }

  List<GenTx> _wavesTxsConvert(String? deviceName, AddrTxsResult wavesTxs) {
    List<GenTx> txs = [];
    if (wavesTxs.success) {
      for (var tx in wavesTxs.txs) {
        var attachment = _wavesAttachment(tx.attachment);
        var validForWallet = tx.assetId == _wavesAssetId();
        /*TODO: revisit this merchant feature of hiding txs not for the current (non-spending) wallet
        if (validForWallet) {
          // check device name
          var txDeviceName = '';
          try {
            txDeviceName = json.decode(tx.attachment!)['device_name'];
          } catch (_) {}
          validForWallet = !_ws.haveCapabililty(Capability.Spend) &&
              deviceName!.isNotEmpty &&
              deviceName != txDeviceName;
        }
        */
        var genTx = GenTx(tx.id, ActionTransfer, tx.timestamp, tx.sender,
            tx.recipient, attachment, tx.amount, tx.fee, validForWallet);
        txs.add(genTx);
      }
    }
    return txs;
  }

  List<GenTx> _paydbTxsConvert(PayDbUserTxsResult paydbTxs) {
    List<GenTx> txs = [];
    if (paydbTxs.txs != null && paydbTxs.error == PayDbError.None) {
      for (var tx in paydbTxs.txs!) {
        var genTx = GenTx(tx.token, tx.action, tx.timestamp * 1000, tx.sender,
            tx.recipient, tx.attachment, tx.amount, 0, true);
        txs.add(genTx);
      }
    }
    return txs;
  }

  List<GenTx> _addMoreTxs(List<GenTx> txs) {
    List<GenTx> txsFiltered = [];
    for (var tx in txs) {
      if (!tx.validForWallet) continue;
      txsFiltered.add(tx);
    }
    _txsAll += txs;
    _txsFiltered += txsFiltered;
    if (_txsAll.length > 0) _lastTxId = _txsAll[_txsAll.length - 1].id;
    return txsFiltered;
  }

  Future<void> _saveTxs() async {
    await Prefs.transactionsSet(_txsAll);
  }

  Future<TxDownloadResult> downloadMoreTxs(int count) async {
    return await m.protect<TxDownloadResult>(() async {
      bool success;
      List<GenTx> txs;
      switch (AppTokenType) {
        case TokenType.Waves:
          var deviceName = await Prefs.deviceNameGet();
          var result = await LibZap().addressTransactions(
              _ws.addrOrAccountValue(), count, _lastTxId);
          success = result.success;
          txs = _wavesTxsConvert(deviceName, result);
          break;
        case TokenType.PayDB:
          var result = await paydbUserTransactions(_txsAll.length, count);
          success = result.error == PayDbError.None;
          txs = _paydbTxsConvert(result);
      }
      if (txs.length < count) _foundEnd = true;
      var txsFiltered = _addMoreTxs(txs);
      _saveTxs();
      return TxDownloadResult(
          success, txs.length, txsFiltered.length, _foundEnd, _lastTxId);
    });
  }

  bool _containsTx(List<GenTx> txs, String txid) {
    for (var tx in txs) if (tx.id == txid) return true;
    return false;
  }

  Future<TxDownloadResult> downloadNewTxs(
      int count, int offset, String? lastTxid) async {
    return await m.protect<TxDownloadResult>(() async {
      bool success;
      List<GenTx> txs;
      List<GenTx> txsFiltered = [];
      var newTxs = 0;
      switch (AppTokenType) {
        case TokenType.Waves:
          var deviceName = await Prefs.deviceNameGet();
          var result = await LibZap().addressTransactions(
              _ws.addrOrAccountValue(), count, lastTxid);
          success = result.success;
          txs = _wavesTxsConvert(deviceName, result);
          break;
        case TokenType.PayDB:
          var result = await paydbUserTransactions(offset, count);
          success = result.error == PayDbError.None;
          txs = _paydbTxsConvert(result);
      }
      for (var tx in txs) {
        if (!tx.validForWallet) continue;
        txsFiltered.add(tx);
      }
      var end = false;
      for (var i = txs.length - 1; i >= 0; i--) {
        if (_containsTx(_txsAll, txs[i].id))
          end = true;
        else
          _txsAll.insert(0, txs[i]);
      }
      for (var i = txsFiltered.length - 1; i >= 0; i--) {
        if (!_containsTx(_txsFiltered, txsFiltered[i].id)) {
          _txsFiltered.insert(0, txsFiltered[i]);
          newTxs++;
        }
      }
      var lastTxId = txs.length > 0 ? txs.last.id : null;
      if (end) await _saveTxs();
      return TxDownloadResult(success, txs.length, newTxs, end, lastTxId);
    });
  }

  void _clear() {
    _txsAll.clear();
    _txsFiltered.clear();
    _lastTxId = null;
    _foundEnd = false;
  }

  Future<void> loadTxs() async {
    await m.protect(() async {
      _clear();
      var txs = await Prefs.transactionsGet();
      _addMoreTxs(txs);
    });
  }

  Future<void> delTxs() async {
    await m.protect(() async {
      _clear();
      await Prefs.transactionsSet([]);
    });
  }
}

class WalletState {
  WalletState(this._txNotification, this._update) {
    _txDownloader = TxDownloader(this);
  }

  final TxNotificationCallback _txNotification;
  final WalletStateUpdateCallback _update;
  Socket? _merchantSocket; // merchant portal websocket

  bool _testnet = true;
  WavesWallet _wallet = WavesWallet.empty();
  PayDbAccount _account = PayDbAccount.empty();
  Decimal _fee = AppTokenType == TokenType.PayDB
      ? Decimal.fromInt(0)
      : Decimal.parse("0.01");
  Decimal _balance = Decimal.fromInt(-1);
  String _balanceText = "...";
  List<String> _alerts = <String>[];
  Rates? _merchantRates;

  late TxDownloader _txDownloader;

  bool get testnet {
    return _testnet;
  }

  Decimal get fee {
    return _fee;
  }

  Decimal get balance {
    return _balance;
  }

  String get balanceText {
    return _balanceText;
  }

  String get walletMnemonic {
    return _wallet.mnemonic;
  }

  Rates? get rates {
    return _merchantRates;
  }

  List<String> get alerts {
    return _alerts;
  }

  TxDownloader get txDownloader {
    return _txDownloader;
  }

  String? get accountPhoto {
    return _account.photo;
  }

  String? get accountPhotoType {
    return _account.photoType;
  }

  void accountInfoUpdate() async {
    var result = await paydbUserInfo();
    if (result.error == PayDbError.None) {
      assert(result.info != null);
      _account = PayDbAccount(result.info!.email, result.info!.photo,
          result.info!.photoType, result.info!.permissions, result.info!.roles);
    }
  }

  AccountRegistration accountRegistration() {
    return AccountRegistration('', '', _account.email, '', '', '', '',
        _account.photo, _account.photoType);
  }

  String walletOrAccount() {
    switch (AppTokenType) {
      case TokenType.Waves:
        return 'wallet';
      case TokenType.PayDB:
        return 'account';
    }
  }

  String addrOrAccount() {
    switch (AppTokenType) {
      case TokenType.Waves:
        return 'wallet address';
      case TokenType.PayDB:
        return 'account';
    }
  }

  String addrOrAccountValue() {
    switch (AppTokenType) {
      case TokenType.Waves:
        if (_wallet.address.isNotEmpty) return _wallet.address;
        break;
      case TokenType.PayDB:
        if (_account.email.isNotEmpty) return _account.email;
        break;
    }
    return '...';
  }

  String mnemonicOrAccount() {
    switch (AppTokenType) {
      case TokenType.Waves:
        if (_wallet.isMnemonic) return _wallet.mnemonic;
        break;
      case TokenType.PayDB:
        if (_account.email.isNotEmpty) return _account.email;
        break;
    }
    return '...';
  }

  Widget profileImage() {
    switch (AppTokenType) {
      case TokenType.Waves:
        return SizedBox();
      case TokenType.PayDB:
        return Padding(
            child: paydbAccountImage(_account.photo, _account.photoType),
            padding: EdgeInsets.only(right: 20));
    }
  }

  Future<void> init(BuildContext context) async {
    // init _testnet var: _setTestnet sets libzap to initial testnet value so we can devrive address from mnemonic
    _testnet = await _setTestnet();
    // init wallet
    var tokenDetailsResult = InitTokenDetailsResult.NoData;
    while (tokenDetailsResult != InitTokenDetailsResult.None) {
      tokenDetailsResult = await initTokenDetails(context);
      if (tokenDetailsResult == InitTokenDetailsResult.NoData) {
        switch (AppTokenType) {
          case TokenType.Waves:
            var zapuser = await extractZapUserFromOldAppDb();
            if (zapuser != null) {
              await Prefs.mnemonicSet(zapuser.recoveryWords);
              await Prefs.pinSet(zapuser.pin);
              if (zapuser.bronzeApiKey != null &&
                  zapuser.bronzeApiSecret != null) {
                await Prefs.bronzeApiKeySet(zapuser.bronzeApiKey);
                await Prefs.bronzeApiSecretSet(zapuser.bronzeApiSecret);
              }
            } else
              await _noWallet(context);
            break;
          case TokenType.PayDB:
            await _noAccount(context);
            break;
        }
      }
    }
  }

  Future<NoWalletAction> _noWalletDialog(BuildContext context) async {
    assert(AppTokenType == TokenType.Waves);
    var res = await showDialog<NoWalletAction>(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return SimpleDialog(
            title: const Text(UseMerchantApi
                ? "You do not have recovery words or an address saved, what would you like to do?"
                : "You do not have recovery words saved, what would you like to do?"),
            children: <Widget>[
              SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(context, NoWalletAction.CreateMnemonic);
                },
                child: const Text("Create new recovery words"),
              ),
              SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(context, NoWalletAction.RecoverMnemonic);
                },
                child: const Text("Recover using your recovery words"),
              ),
              SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(context, NoWalletAction.RecoverRaw);
                },
                child: const Text(
                    "Recover using a raw seed string (advanced use only)"),
              ),
              Visibility(
                  visible: UseMerchantApi,
                  child: SimpleDialogOption(
                      onPressed: () {
                        Navigator.pop(
                            context, NoWalletAction.ScanMerchantApiKey);
                      },
                      child: const Text("Scan retailer api key"))),
            ],
          );
        });
    if (res != null) return res;
    return NoWalletAction.RecoverMnemonic;
  }

  Future<NoAccountAction> _noAccountDialog(BuildContext context) async {
    assert(AppTokenType == TokenType.PayDB);
    var server = await paydbServer();
    var res = await showDialog<NoAccountAction>(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return SimpleDialog(
            title: const Text("Register or Login"),
            children: <Widget>[
              Center(
                  child:
                      Text("Server: $server", style: TextStyle(fontSize: 10))),
              SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(context, NoAccountAction.Register);
                },
                child: const Text("Register a new account"),
              ),
              SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(context, NoAccountAction.Login);
                },
                child: const Text("Login to your account"),
              ),
              SimpleDialogOption(
                onPressed: () {
                  Navigator.pop(context, NoAccountAction.RequestApiKey);
                },
                child: const Text("Login using email link (forgot password)"),
              ),
            ],
          );
        });
    if (res != null) return res;
    return NoAccountAction.Login;
  }

  Future<String?> _recoverMnemonic(BuildContext context) {
    return Navigator.push<String>(
        context, MaterialPageRoute(builder: (context) => RecoveryForm()));
  }

  Future<String?> _recoverSeed(BuildContext context) async {
    String seed = "";
    return showDialog<String>(
      context: context,
      barrierDismissible:
          false, // dialog is dismissible with a tap on the barrier
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Enter your raw seed string to recover your account"),
          content: Row(
            children: <Widget>[
              Expanded(
                  child: Container(
                      constraints: BoxConstraints(maxWidth: 300),
                      child: TextField(
                        autofocus: true,
                        decoration: InputDecoration(
                          labelText: "Seed",
                        ),
                        onChanged: (value) {
                          seed = value;
                        },
                      )))
            ],
          ),
          actions: <Widget>[
            raisedButton(
                child: Text("Ok"),
                onPressed: () => Navigator.of(context).pop(seed)),
          ],
        );
      },
    );
  }

  Future<void> _noWallet(BuildContext context) async {
    assert(AppTokenType == TokenType.Waves);
    var libzap = LibZap();
    while (true) {
      String? mnemonic;
      String? address;
      _update(this, false, false, false);
      var action = await _noWalletDialog(context);
      _update(this, false, true, false);
      switch (action) {
        case NoWalletAction.CreateMnemonic:
          mnemonic = libzap.mnemonicCreate();
          if (mnemonic != null)
            // show warning for new mnemonic
            await Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => NewMnemonicForm(mnemonic!)),
            );
          break;
        case NoWalletAction.RecoverMnemonic:
          // recover mnemonic
          mnemonic = await _recoverMnemonic(context);
          if (mnemonic != null && mnemonic.isNotEmpty) {
            mnemonic = mnemonic.trim();
            mnemonic = mnemonic.replaceAll(RegExp(r"\s+"), " ");
            mnemonic = mnemonic.toLowerCase();
            if (!libzap.mnemonicCheck(mnemonic)) {
              mnemonic = null;
              await alert(context, "Recovery words not valid",
                  "The recovery words you entered are not valid");
            }
          }
          break;
        case NoWalletAction.RecoverRaw:
          // recover raw seed string
          mnemonic = await _recoverSeed(context);
          break;
        case NoWalletAction.ScanMerchantApiKey:
          var value = await QrScan.scan(context);
          if (value != null) {
            var result = parseApiKeyUri(value);
            if (result.error == NO_ERROR) {
              if (result.walletAddress.isEmpty) {
                flushbarMsg(context, 'wallet address not present',
                    category: MessageCategory.Warning);
                break;
              }
              await Prefs.addressSet(result.walletAddress);
              await Prefs.deviceNameSet(result.deviceName);
              await Prefs.merchantApiKeySet(result.apikey);
              await Prefs.merchantApiSecretSet(result.apisecret);
              if (result.apiserver.isNotEmpty)
                await Prefs.merchantApiServerSet(result.apiserver);
              flushbarMsg(context, 'API KEY set');
              address = result.walletAddress;
            } else
              flushbarMsg(context, 'invalid QR code',
                  category: MessageCategory.Warning);
          }
          break;
      }
      if (mnemonic != null && mnemonic.isNotEmpty) {
        await Prefs.mnemonicSet(mnemonic);
        await alert(context, "Recovery words saved", ":)");
        break;
      }
      if (address != null && address.isNotEmpty) {
        await Prefs.addressSet(address);
        await alert(context, "Address saved", ":)");
        break;
      }
    }
  }

  Future<String> deviceName() async {
    var device = 'app';
    if (Platform.isAndroid)
      device = (await DeviceInfoPlugin().androidInfo).model;
    if (Platform.isIOS)
      device = (await DeviceInfoPlugin().iosInfo).utsname.machine;
    var date = DateTime.now().toIso8601String().split('T').first;
    return '$device - $date';
  }

  Future<String?> _paydbLogin(BuildContext context, AccountLogin login,
      {bool silent: false}) async {
    var devName = await deviceName();
    var result = await paydbApiKeyCreate(login.email, login.password, devName);
    switch (result.error) {
      case PayDbError.Auth:
        if (!silent)
          await alert(context, "Authentication not valid",
              "The login details you entered are not valid");
        break;
      case PayDbError.Network:
        if (!silent)
          await alert(context, "Network error",
              "A network error occured when trying to login");
        break;
      case PayDbError.None:
        // write api key
        if (result.apikey != null) {
          await Prefs.paydbApiKeySet(result.apikey!.token);
          await Prefs.paydbApiSecretSet(result.apikey!.secret);
        }
        return login.email;
    }
    return null;
  }

  Future<String?> _paydbApiKeyClaim(
      BuildContext context, AccountRequestApiKey req, String token,
      {silent: false}) async {
    var result = await paydbApiKeyClaim(token);
    switch (result.error) {
      case PayDbError.Auth:
        if (!silent)
          await alert(context, "Authentication not valid",
              "The login details you entered are not valid");
        break;
      case PayDbError.Network:
        if (!silent)
          await alert(context, "Network error",
              "A network error occured when trying to login");
        break;
      case PayDbError.None:
        // write api key
        if (result.apikey != null) {
          await Prefs.paydbApiKeySet(result.apikey!.token);
          await Prefs.paydbApiSecretSet(result.apikey!.secret);
        }
        return req.email;
    }
    return null;
  }

  Future<void> _noAccount(BuildContext context) async {
    assert(AppTokenType == TokenType.PayDB);
    if (await paydbServer() == null) {
      Prefs.testnetSet(!_testnet);
      await _updateTestnet();
    }
    assert(await paydbServer() != null);
    while (true) {
      String? accountEmail;
      _update(this, false, false, false);
      var action = await _noAccountDialog(context);
      _update(this, false, true, false);
      switch (action) {
        case NoAccountAction.Register:
          AccountRegistration? registration;
          while (accountEmail == null) {
            // show register form
            registration = await Navigator.push<AccountRegistration>(
              context,
              MaterialPageRoute(
                  builder: (context) => AccountRegisterForm(registration,
                      showMobileNumber: RequireMobileNumber,
                      showAddress: RequireAddress)),
            );
            if (registration == null) break;
            var result = await paydbUserRegister(registration);
            switch (result) {
              case PayDbError.Auth:
                await alert(context, "Authorisation error",
                    "An authorisation error occured when trying to register (user may already exist)");
                break;
              case PayDbError.Network:
                await alert(context, "Network error",
                    "A network error occured when trying to register");
                break;
              case PayDbError.None:
                var cancelled = false;
                showAlertDialog(
                    context, 'waiting for you to confirm the email...',
                    showCancel: true, onCancel: () => cancelled = true);
                while (accountEmail == null && !cancelled) {
                  await Future.delayed(Duration(seconds: 5));
                  // save account if login successful
                  accountEmail = await _paydbLogin(
                      context,
                      AccountLogin(
                          registration.email, registration.newPassword),
                      silent: true);
                }
                Navigator.pop(context);
                break;
            }
          }
          break;
        case NoAccountAction.Login:
          AccountLogin? login;
          while (accountEmail == null) {
            // login form
            login = await Navigator.push<AccountLogin>(
              context,
              MaterialPageRoute(builder: (context) => AccountLoginForm(login)),
            );
            if (login == null) break;
            // save account if login successful
            accountEmail = await _paydbLogin(context, login);
          }
          break;
        case NoAccountAction.RequestApiKey:
          // request api key form
          var devName = await deviceName();
          var req = await Navigator.push<AccountRequestApiKey>(
            context,
            MaterialPageRoute(
                builder: (context) => AccountRequestApiKeyForm(devName)),
          );
          if (req == null) break;
          var result = await paydbApiKeyRequest(req.email, req.deviceName);
          switch (result.error) {
            case PayDbError.Auth:
            case PayDbError.Network:
              await alert(context, "Network error",
                  "A network error occured when trying to login");
              break;
            case PayDbError.None:
              assert(result.token != null);
              var cancelled = false;
              showAlertDialog(
                  context, 'waiting for you to confirm the email...',
                  showCancel: true, onCancel: () => cancelled = true);
              while (accountEmail == null && !cancelled) {
                await Future.delayed(Duration(seconds: 5));
                // claim api key
                accountEmail = await _paydbApiKeyClaim(
                    context, req, result.token!,
                    silent: true);
              }
              Navigator.pop(context);
              break;
          }
          break;
      }
      if (accountEmail != null && accountEmail.isNotEmpty) {
        _account = PayDbAccount(accountEmail, '', '', [], []);
        await alert(context, "Login successful", ":)");
        break;
      }
    }
  }

  Future<bool> _updateTestnet() async {
    // update testnet
    _testnet = await _setTestnet();
    var testnetText = 'Testnet!';
    if (_testnet && !_alerts.contains(testnetText)) _alerts.add(testnetText);
    if (!_testnet && _alerts.contains(testnetText)) _alerts.remove(testnetText);
    return true;
  }

  Future<bool> updateBalance() async {
    _update(this, true, false, true);
    _balance = Decimal.fromInt(-1);
    _balanceText = ":(";
    switch (AppTokenType) {
      case TokenType.Waves:
        // get fee
        //var feeResult = await LibZap().transactionFee();
        //if (feeResult.success)
        //  _fee = Decimal.fromInt(feeResult.value) / Decimal.fromInt(100);
        // get balance
        var balanceResult = await LibZap().addressBalance(_wallet.address);
        if (balanceResult.success) {
          _balance =
              Decimal.fromInt(balanceResult.value) / Decimal.fromInt(100);
        }
        break;
      case TokenType.PayDB:
        var result = await paydbUserInfo();
        switch (result.error) {
          case PayDbError.Auth:
          case PayDbError.Network:
            break;
          case PayDbError.None:
            assert(result.info != null);
            _balance =
                Decimal.fromInt(result.info!.balance) / Decimal.fromInt(100);
            break;
        }
        break;
    }
    _balanceText = balance.toStringAsFixed(2);
    _update(this, false, false, true);
    return true;
  }

  Future<InitTokenDetailsResult> initTokenDetails(BuildContext context) async {
    _alerts.clear();
    // check apikey
    if (UseMerchantApi && !await Prefs.hasMerchantApiKey())
      _alerts.add('No Retailer API KEY set');
    switch (AppTokenType) {
      case TokenType.Waves:
        // check mnemonic
        if (_wallet.isEmpty) {
          var libzap = LibZap();
          var mnemonic = await Prefs.mnemonicGet();
          if (mnemonic != null && mnemonic.isNotEmpty) {
            var mnemonicPasswordProtected =
                await Prefs.mnemonicPasswordProtectedGet();
            if (mnemonicPasswordProtected) {
              while (true) {
                var password = await askMnemonicPassword(context);
                if (password == null || password.isEmpty) {
                  continue;
                }
                var iv = await Prefs.cryptoIVGet();
                var decryptedMnemonic =
                    decryptMnemonic(mnemonic!, iv!, password);
                if (decryptedMnemonic == null) {
                  await alert(context, "Could not decrypt recovery words",
                      "the password entered is probably wrong");
                  continue;
                }
                if (!libzap.mnemonicCheck(decryptedMnemonic)) {
                  var yes = await askYesNo(
                      context, 'The recovery words are not valid, is this ok?');
                  if (!yes) continue;
                }
                mnemonic = decryptedMnemonic;
                break;
              }
            }
            var address = libzap.seedAddress(mnemonic);
            _wallet = WavesWallet.mnemonic(mnemonic, address);
          } else {
            var address = await Prefs.addressGet();
            if (address != null && address.isNotEmpty) {
              _wallet = WavesWallet.justAddress(address);
            } else {
              return InitTokenDetailsResult.NoData;
            }
          }
        } else if (_wallet.isMnemonic) {
          // reinitialize wallet address (we might have toggled testnet)
          var address = LibZap().seedAddress(_wallet.mnemonic);
          _wallet = WavesWallet.mnemonic(_wallet.mnemonic, address);
        }
        break;
      case TokenType.PayDB:
        // check apikey
        if (!await Prefs.hasPaydbApiKey()) return InitTokenDetailsResult.NoData;
        var result = await paydbUserInfo();
        switch (result.error) {
          case PayDbError.None:
            assert(result.info != null);
            _account = PayDbAccount(
                result.info!.email,
                result.info!.photo,
                result.info!.photoType,
                result.info!.permissions,
                result.info!.roles);
            break;
          case PayDbError.Auth:
            var yes = await askYesNo(
                context, 'Authentication failed, delete credentials?');
            if (yes) {
              await Prefs.paydbApiKeySet(null);
              await Prefs.paydbApiKeySet(null);
              await txDownloader.delTxs();
            }
            return InitTokenDetailsResult.Auth;
          case PayDbError.Network:
            await alert(context, "Network error",
                "check your network settings before continuing");
            return InitTokenDetailsResult.Network;
        }
        break;
    }
    // update testnet and balance
    await _updateTestnet();
    await updateBalance();
    // watch wallet address
    if (AppTokenType == TokenType.Waves) watchAddress(context);
    // update merchant rates
    if (UseMerchantApi && await Prefs.hasMerchantApiKey())
      merchantRates().then((value) => _merchantRates = value);
    return InitTokenDetailsResult.None;
  }

  void watchAddress(BuildContext context) async {
    assert(AppTokenType == TokenType.Waves);
    // do nothing if the address, apikey or apisecret is not set
    var addr = addrOrAccountValue();
    if (addr.isEmpty) return;
    if (!await Prefs.hasMerchantApiKey()) return;
    // register to watch our address
    if (!await merchantWatch(addr)) {
      flushbarMsg(context, 'failed to register address',
          category: MessageCategory.Warning);
      return;
    }
    // create socket to receive tx alerts
    _merchantSocket?.close();
    _merchantSocket = await merchantSocket(_txNotification);
  }

  void dispose() {
    // close socket
    _merchantSocket?.close();
  }

  bool haveCapabililty(Capability cap) {
    switch (AppTokenType) {
      case TokenType.Waves:
        switch (cap) {
          case Capability.Receive:
            return _wallet.address.isNotEmpty;
          case Capability.Balance:
          case Capability.History:
          case Capability.Spend:
            return _wallet.isMnemonic;
        }
      case TokenType.PayDB:
        switch (cap) {
          case Capability.Receive:
            return _account.permissions.contains(PayDbPermission.receive);
          case Capability.Balance:
            return _account.permissions.contains(PayDbPermission.balance);
          case Capability.History:
            return _account.permissions.contains(PayDbPermission.history);
          case Capability.Spend:
            return _account.permissions.contains(PayDbPermission.transfer);
        }
    }
  }

  bool haveRole(PayDbRole role) {
    assert(AppTokenType == TokenType.PayDB);
    return _account.roles.contains(role);
  }

  Future<bool> _setTestnet() async {
    var testnet = await Prefs.testnetGet();
    if (AppTokenType == TokenType.Waves) {
      var libzap = LibZap();
      libzap.networkParamsSet(AssetIdMainnet, AssetIdTestnet, NodeUrlMainnet,
          NodeUrlTestnet, testnet);
      if (!_wallet.isEmpty && !_wallet.isMnemonic) {
        if (!libzap.addressCheck(_wallet.address)) {
          testnet = !testnet;
          await Prefs.testnetSet(testnet);
        }
      }
    }
    return testnet;
  }
}
