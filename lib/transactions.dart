import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';

import 'package:zapdart/libzap.dart';
import 'package:zapdart/utils.dart';
import 'package:zapdart/widgets.dart';
import 'package:zapdart/colors.dart';

import 'config.dart';
import 'merchant.dart';
import 'paydb.dart';

class GenTx {
  String id;
  String action;
  int timestamp;
  String sender;
  String recipient;
  String attachment;
  int amount;
  int fee;

  GenTx(this.id, this.action, this.timestamp, this.sender, this.recipient,
      this.attachment, this.amount, this.fee);
}

class TransactionsScreen extends StatefulWidget {
  final String _addrOrAccount;
  final bool _testnet;
  final String _deviceName;
  final Rates _merchantRates;

  TransactionsScreen(
      this._addrOrAccount, this._testnet, this._deviceName, this._merchantRates)
      : super();

  @override
  _TransactionsState createState() => new _TransactionsState();
}

enum LoadDirection { Next, Previous, Initial }

class Choice {
  const Choice({this.title, this.icon});

  final String title;
  final IconData icon;
}

const List<Choice> choices = const <Choice>[
  const Choice(title: "Export JSON", icon: Icons.save),
];

class DownloadResult {
  final int downloadCount;
  final int validCount;
  DownloadResult(this.downloadCount, this.validCount);
}

class _TransactionsState extends State<TransactionsScreen> {
  bool _loading = true;
  var _txsAll = List<GenTx>();
  var _txsFiltered = List<GenTx>();
  var _offset = 0;
  var _downloadCount = 100;
  var _displayCount = 10;
  String _lastTxId;
  var _more = false;
  var _less = false;
  var _foundEnd = false;

  @override
  void initState() {
    _loadTxs(LoadDirection.Initial);
    super.initState();
  }

  Future<DownloadResult> _downloadMoreTxs(int count) async {
    List<GenTx> txs;
    List<GenTx> txsFiltered;
    switch (AppTokenType) {
      case TokenType.Waves:
        var wavesTxs = await LibZap.addressTransactions(
            widget._addrOrAccount, count, _lastTxId);
        if (wavesTxs != null) {
          txs = List<GenTx>();
          txsFiltered = List<GenTx>();
          for (var tx in wavesTxs) {
            var genTx = GenTx(tx.id, ActionTransfer, tx.timestamp, tx.sender,
                tx.recipient, null, tx.amount, tx.fee);
            txs.add(genTx);
            // check asset id
            var assetId = widget._testnet
                ? (AssetIdTestnet != null
                    ? AssetIdTestnet
                    : LibZap.TESTNET_ASSET_ID)
                : (AssetIdMainnet != null
                    ? AssetIdMainnet
                    : LibZap.MAINNET_ASSET_ID);
            if (tx.assetId != assetId) continue;
            // decode attachment
            if (tx.attachment != null && tx.attachment.isNotEmpty)
              tx.attachment = base58decodeString(tx.attachment);
            genTx.attachment = tx.attachment;
            // check device name
            var deviceName = '';
            try {
              deviceName = json.decode(tx.attachment)['device_name'];
            } catch (_) {}
            if (widget._deviceName != null &&
                widget._deviceName.isNotEmpty &&
                widget._deviceName != deviceName) continue;
            txsFiltered.add(genTx);
          }
        }
        break;
      case TokenType.PayDB:
        var result = await paydbUserTransactions(_txsAll.length, count);
        if (result.error == PayDbError.None) {
          txs = List<GenTx>();
          txsFiltered = List<GenTx>();
          for (var tx in result.txs) {
            var genTx = GenTx(tx.token, tx.action, tx.timestamp * 1000,
                tx.sender, tx.recipient, tx.attachment, tx.amount, 0);
            txs.add(genTx);
            txsFiltered.add(genTx);
          }
        }
    }
    if (txs != null) {
      _txsAll += txs;
      _txsFiltered += txsFiltered;
      if (_txsAll.length > 0) _lastTxId = _txsAll[_txsAll.length - 1].id;
      if (txs.length < count) _foundEnd = true;
    } else
      return null;
    return DownloadResult(txs.length, txsFiltered.length);
  }

  void _loadTxs(LoadDirection dir) async {
    var newOffset = _offset;
    if (dir == LoadDirection.Next) {
      newOffset += _displayCount;
      if (newOffset > _txsFiltered.length) newOffset = _txsFiltered.length;
    } else if (dir == LoadDirection.Previous) {
      newOffset -= _displayCount;
      if (newOffset < 0) newOffset = 0;
    }
    if (newOffset == _txsFiltered.length) {
      // set loading
      setState(() {
        _loading = true;
      });
      // load new txs
      var count = 0;
      var remaining = _displayCount;
      var failed = false;
      while (true) {
        var res = await _downloadMoreTxs(_downloadCount);
        if (res == null) {
          flushbarMsg(context, 'failed to load transactions',
              category: MessageCategory.Warning);
          failed = true;
          break;
        }
        count += res.validCount;
        if (count >= _displayCount || res.downloadCount < remaining) break;
        remaining = _displayCount - count;
      }
      setState(() {
        if (!failed) {
          _more = count >= _displayCount;
          _less = newOffset > 0;
          _offset = newOffset;
        }
        _loading = false;
      });
    } else {
      setState(() {
        _more = !_foundEnd || newOffset < _txsFiltered.length - _displayCount;
        _less = newOffset > 0;
        _offset = newOffset;
      });
    }
  }

  Widget _buildTxList(BuildContext context, int index) {
    var offsetIndex = _offset + index;
    if (offsetIndex >= _offset + _displayCount ||
        offsetIndex >= _txsFiltered.length) return null;
    var tx = _txsFiltered[offsetIndex];
    var outgoing = tx.sender == widget._addrOrAccount;
    var amount = Decimal.fromInt(tx.amount) / Decimal.fromInt(100);
    var amountText = "${amount.toStringAsFixed(2)} $AssetShortNameUpper";
    if (widget._merchantRates != null)
      amountText =
          "$amountText / ${toNZDAmount(amount, widget._merchantRates)}";
    amountText = outgoing ? '- $amountText' : '+ $amountText';
    var fee = Decimal.fromInt(tx.fee) / Decimal.fromInt(100);
    var feeText = fee.toStringAsFixed(2);
    var color = outgoing ? ZapYellow : ZapGreen;
    var date = new DateTime.fromMillisecondsSinceEpoch(tx.timestamp);
    var dateStrLong = DateFormat('yyyy-MM-dd HH:mm').format(date);
    String link;
    if (AppTokenType == TokenType.Waves)
      link = widget._testnet
          ? 'https://wavesexplorer.com/testnet/tx/${tx.id}'
          : 'https://wavesexplorer.com/tx/${tx.id}';
    return ListTx(() {
      Navigator.of(context).push(
          // We will now use PageRouteBuilder
          PageRouteBuilder(
              opaque: false,
              pageBuilder: (BuildContext context, __, ___) {
                return new Scaffold(
                    appBar: AppBar(
                      leading: backButton(context, color: ZapBlue),
                      title:
                          Text('transaction', style: TextStyle(color: ZapBlue)),
                    ),
                    body: Container(
                      color: ZapWhite,
                      child: Column(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.only(top: 5.0),
                            child: ListTile(
                              title: Text('transaction ID'),
                              subtitle: InkWell(
                                  child: Text(tx.id,
                                      style: new TextStyle(
                                          color: ZapBlue,
                                          decoration:
                                              TextDecoration.underline))),
                              onTap: () => link != null
                                  ? launch(link)
                                  : print('no link'),
                            ),
                          ),
                          ListTile(
                              title: Text('action'), subtitle: Text(tx.action)),
                          ListTile(
                              title: Text('date'), subtitle: Text(dateStrLong)),
                          ListTile(
                              title: Text('sender'), subtitle: Text(tx.sender)),
                          ListTile(
                              title: Text('recipient'),
                              subtitle: Text(tx.recipient)),
                          ListTile(
                              title: Text('amount'),
                              subtitle: Text(
                                amountText,
                                style: TextStyle(color: color),
                              )),
                          ListTile(
                              title: Text('fee'),
                              subtitle: Text(
                                '$feeText $AssetShortNameUpper',
                              )),
                          Visibility(
                            visible: tx.attachment != null &&
                                tx.attachment.isNotEmpty,
                            child: ListTile(
                                title: Text("attachment"),
                                subtitle: Text('${tx.attachment}')),
                          ),
                          Container(
                              padding: const EdgeInsets.only(top: 5.0),
                              child: RoundedButton(() => Navigator.pop(context),
                                  ZapBlue, ZapWhite, 'close',
                                  borderColor: ZapBlue)),
                        ],
                      ),
                    ));
              }));
    }, date, tx.id, amount, widget._merchantRates, outgoing);
  }

  void _select(Choice choice) async {
    switch (choice.title) {
      case "Export JSON":
        setState(() {
          _loading = true;
        });
        while (true) {
          var txs = await _downloadMoreTxs(_downloadCount);
          if (txs == null) {
            flushbarMsg(context, 'failed to load transactions',
                category: MessageCategory.Warning);
            setState(() {
              _loading = false;
            });
            return;
          } else if (_foundEnd) {
            var json = jsonEncode(_txsFiltered);
            var filename = "zap_txs.json";
            if (Platform.isAndroid || Platform.isIOS) {
              var dir = await getExternalStorageDirectory();
              filename = dir.path + "/" + filename;
            }
            await File(filename).writeAsString(json);
            alert(context, "Wrote JSON", filename);
            setState(() {
              _loading = false;
            });
            break;
          }
          flushbarMsg(context, 'loaded ${_txsFiltered.length} transactions');
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          leading: backButton(context, color: ZapBlue),
          title: Text("transactions", style: TextStyle(color: ZapBlue)),
          actions: <Widget>[
            PopupMenuButton<Choice>(
              icon: Icon(Icons.more_vert, color: ZapBlue),
              onSelected: _select,
              enabled: !_loading,
              itemBuilder: (BuildContext context) {
                return choices.map((Choice choice) {
                  return PopupMenuItem<Choice>(
                    value: choice,
                    child: Text(choice.title),
                  );
                }).toList();
              },
            ),
          ],
        ),
        body: Center(
          child: Column(
            mainAxisAlignment:
                _loading ? MainAxisAlignment.center : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Visibility(
                  visible: !_loading && _txsFiltered.length == 0,
                  child: Text("Nothing here..")),
              Visibility(
                  visible: !_loading,
                  child: Expanded(
                      child: new ListView.builder(
                    itemCount: _txsFiltered.length,
                    itemBuilder: (BuildContext context, int index) =>
                        _buildTxList(context, index),
                  ))),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Visibility(
                      visible: !_loading && _less,
                      child: Container(
                          padding: const EdgeInsets.all(5),
                          child: RoundedButton(
                              () => _loadTxs(LoadDirection.Previous),
                              ZapBlue,
                              ZapWhite,
                              'prev',
                              icon: Icons.navigate_before,
                              borderColor: ZapBlue))),
                  Visibility(
                      visible: !_loading && _more,
                      child: Container(
                          padding: const EdgeInsets.all(5),
                          child: RoundedButton(
                              () => _loadTxs(LoadDirection.Next),
                              ZapBlue,
                              ZapWhite,
                              'next',
                              icon: Icons.navigate_next,
                              borderColor: ZapBlue))),
                ],
              ),
              Visibility(
                visible: _loading,
                child: CircularProgressIndicator(),
              ),
            ],
          ),
        ));
  }
}
