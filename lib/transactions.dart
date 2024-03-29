import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_icons/flutter_icons.dart';

import 'package:zapdart/widgets.dart';
import 'package:zapdart/colors.dart';

import 'config.dart';
import 'merchant.dart';
import 'wallet_state.dart';
import 'ui_strings.dart';

class TransactionsScreen extends StatefulWidget {
  final WalletState _ws;

  TransactionsScreen(this._ws) : super();

  @override
  _TransactionsState createState() => new _TransactionsState();
}

enum LoadDirection { Next, Previous, Initial }

enum TxDir { In, Out, Self }

Color txDirToColor(TxDir dir) {
  switch (dir) {
    case TxDir.In:
      return ZapIncomingFunds;
    case TxDir.Out:
      return ZapOutgoingFunds;
    case TxDir.Self:
      return ZapSelfFunds;
  }
}

IconData txDirToIcon(TxDir dir) {
  switch (dir) {
    case TxDir.In:
      return MaterialCommunityIcons.chevron_double_up;
    case TxDir.Out:
      return MaterialCommunityIcons.chevron_double_down;
    case TxDir.Self:
      return MaterialCommunityIcons.approximately_equal;
  }
}

String txDirToChar(TxDir dir) {
  switch (dir) {
    case TxDir.In:
      return '+';
    case TxDir.Out:
      return '-';
    case TxDir.Self:
      return ' ';
  }
}

class ListTx extends StatelessWidget {
  ListTx(this.onPressed, this.date, this.txid, this.amount, this.merchantRates,
      this.dir,
      {this.last = false})
      : super();

  final VoidCallback onPressed;
  final DateTime date;
  final String txid;
  final Decimal amount;
  final Rates? merchantRates;
  final TxDir dir;
  final bool last;

  @override
  Widget build(BuildContext context) {
    var color = txDirToColor(dir);
    var tsLeft = TextStyle(fontSize: 12, color: ZapBlackLight);
    var tsRight = TextStyle(fontSize: 12, color: color);
    var amountText = '${amount.toStringAsFixed(2)} $AssetShortNameUpper';
    Widget amountWidget = Text(amountText, style: tsRight);
    if (merchantRates != null) {
      var amountNZD = Text(toNZDAmount(amount, merchantRates!), style: tsRight);
      amountWidget = Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[amountWidget, amountNZD]);
    }
    var icon = txDirToIcon(dir);
    return Column(children: <Widget>[
      Divider(),
      ListTile(
          onTap: onPressed,
          dense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 8),
          leading: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(DateFormat('d MMM').format(date).toUpperCase(),
                    style: tsLeft),
                Text(DateFormat('yyyy').format(date), style: tsLeft),
              ]),
          title: Text(txid),
          trailing: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
            Text('${txDirToChar(dir)} ', style: tsRight),
            amountWidget,
            Icon(icon, color: color, size: 14)
          ])),
      Visibility(visible: last, child: Divider())
    ]);
  }
}

class _TransactionsState extends State<TransactionsScreen> {
  bool _loading = false;
  bool _loadingNewTxs = false;
  var _offset = 0;
  var _downloadCount = 100;
  var _displayCount = 10;
  var _more = false;
  var _less = false;

  @override
  void initState() {
    _loadTxs(LoadDirection.Initial);
    super.initState();
  }

  Future<void> _loadTxs(LoadDirection dir) async {
    var newOffset = _offset;
    if (dir == LoadDirection.Next) {
      newOffset += _displayCount;
      if (newOffset > widget._ws.txDownloader.txs.length)
        newOffset = widget._ws.txDownloader.txs.length;
    } else if (dir == LoadDirection.Previous) {
      newOffset -= _displayCount;
      if (newOffset < 0) newOffset = 0;
    }
    if (newOffset == widget._ws.txDownloader.txs.length) {
      // set loading
      setState(() {
        _loading = true;
      });
      // load new txs
      var count = 0;
      var remaining = _displayCount;
      var failed = false;
      while (true) {
        var res = await widget._ws.txDownloader.downloadMoreTxs(_downloadCount);
        if (!this
            .mounted) // check that the page has not been disposed while we were downloading
          return;
        if (!res.success) {
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
        _more = !widget._ws.txDownloader.foundEnd ||
            newOffset < widget._ws.txDownloader.txs.length - _displayCount;
        _less = newOffset > 0;
        _offset = newOffset;
      });
      if (dir == LoadDirection.Initial) {
        setState(() => _loadingNewTxs = true);
        var offset = 0;
        var newTxs = 0;
        String? lastTxid;
        while (true) {
          var res = await widget._ws.txDownloader
              .downloadNewTxs(_downloadCount, offset, lastTxid);
          if (!this
              .mounted) // check that the page has not been disposed while we were downloading
            return;
          newTxs += res.validCount;
          if (res.downloadCount == 0 || res.end) break;
          offset += res.downloadCount;
          lastTxid = res.lastTxid;
        }
        setState(() => _loadingNewTxs = false);
        if (newTxs > 0)
          flushbarMsg(
              context,
              newTxs > 1
                  ? '$newTxs new transactions'
                  : '$newTxs new transaction');
      }
    }
  }

  int _buildTxListMax() {
    return min(widget._ws.txDownloader.txs.length - _offset, _displayCount);
  }

  void _copyText(String text) {
    Clipboard.setData(ClipboardData(text: text));
    flushbarMsg(context, 'copied "$text" to clipboard');
  }

  Future<void> _refresh() async {
    await _loadTxs(LoadDirection.Initial);
  }

  Widget _buildTxList(BuildContext context, int index) {
    var offsetIndex = _offset + index;
    var tx = widget._ws.txDownloader.txs[offsetIndex];
    var dir = TxDir.Out;
    if (tx.recipient == widget._ws.addrOrAccountValue()) {
      dir = TxDir.In;
      if (tx.sender == widget._ws.addrOrAccountValue()) dir = TxDir.Self;
    }
    var amount = Decimal.fromInt(tx.amount) / Decimal.fromInt(100);
    var amountText = "${amount.toStringAsFixed(2)} $AssetShortNameUpper";
    if (widget._ws.rates != null)
      amountText = "$amountText / ${toNZDAmount(amount, widget._ws.rates!)}";
    amountText = '${txDirToChar(dir)} $amountText';
    var fee = Decimal.fromInt(tx.fee) / Decimal.fromInt(100);
    var feeText = fee.toStringAsFixed(2);
    var color = txDirToColor(dir);
    var date = new DateTime.fromMillisecondsSinceEpoch(tx.timestamp);
    var dateStrLong = DateFormat('yyyy-MM-dd HH:mm').format(date);
    String? link;
    if (AppTokenType == TokenType.Waves)
      link = widget._ws.testnet
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
                      title: Text(capFirst('transaction'),
                          style: TextStyle(color: ZapBlue)),
                    ),
                    body: SingleChildScrollView(
                        child: Container(
                      color: ZapWhite,
                      child: Column(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.only(top: 5.0),
                            child: ListTile(
                              title: Text(capFirst('transaction ID')),
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
                              title: Text(capFirst('action')),
                              subtitle: Text(tx.action)),
                          ListTile(
                              title: Text(capFirst('date')),
                              subtitle: Text(dateStrLong)),
                          ListTile(
                              title: Text(capFirst('sender')),
                              subtitle: Text(tx.sender),
                              onTap: () => _copyText(tx.sender)),
                          ListTile(
                              title: Text(capFirst('recipient')),
                              subtitle: Text(tx.recipient),
                              onTap: () => _copyText(tx.recipient)),
                          ListTile(
                              title: Text(capFirst('amount')),
                              subtitle: Text(
                                amountText,
                                style: TextStyle(color: color),
                              )),
                          ListTile(
                              title: Text(capFirst('fee')),
                              subtitle: Text(
                                '$feeText $AssetShortNameUpper',
                              )),
                          Visibility(
                            visible: tx.attachment != null &&
                                tx.attachment!.isNotEmpty,
                            child: ListTile(
                                title: Text(capFirst('attachment')),
                                subtitle: Text('${tx.attachment}')),
                          ),
                          Container(
                              padding: const EdgeInsets.only(top: 5.0),
                              child: RoundedButton(() => Navigator.pop(context),
                                  ZapBlue, ZapWhite, null, capFirst('close'),
                                  borderColor: ZapBlue)),
                        ],
                      ),
                    )));
              }));
    }, date, tx.id, amount, widget._ws.rates, dir);
  }

  Future<void> _exportJson() async {
    setState(() {
      _loading = true;
    });
    while (true) {
      var txs = await widget._ws.txDownloader.downloadMoreTxs(_downloadCount);
      if (!txs.success) {
        flushbarMsg(context, 'failed to load transactions',
            category: MessageCategory.Warning);
        setState(() {
          _loading = false;
        });
        return;
      } else if (widget._ws.txDownloader.foundEnd) {
        var json = jsonEncode(widget._ws.txDownloader.txs);
        var filename = 'transaction_history.json';
        if (Platform.isAndroid || Platform.isIOS) {
          var dir = await getApplicationSupportDirectory();
          filename = dir.path + '/' + filename;
        }
        await File(filename).writeAsString(json);
        await Share.shareFiles([filename],
            mimeTypes: ['json'], subject: 'transaction history');
        setState(() {
          _loading = false;
        });
        break;
      }
      flushbarMsg(
          context, 'loaded ${widget._ws.txDownloader.txs.length} transactions');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Center(
      child: Column(
        mainAxisAlignment:
            _loading ? MainAxisAlignment.center : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Visibility(
              visible: !_loading && widget._ws.txDownloader.txs.length == 0,
              child: Text('No history yet..')),
          Visibility(
              visible: !_loading,
              child: Expanded(
                  child: RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView.builder(
                        itemCount: _buildTxListMax(),
                        itemBuilder: (BuildContext context, int index) =>
                            _buildTxList(context, index),
                      )))),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Visibility(
                  maintainSize: true,
                  maintainState: true,
                  maintainAnimation: true,
                  visible: !_loading && _less,
                  child: Container(
                      padding: const EdgeInsets.all(5),
                      child: RoundedButton(
                          () => _loadTxs(LoadDirection.Previous),
                          ZapBlue,
                          ZapWhite,
                          null,
                          capFirst('prev'),
                          icon: Icons.navigate_before,
                          borderColor: ZapBlue))),
              _loadingNewTxs
                  ? CircularProgressIndicator()
                  : Visibility(
                      visible: !_loading && !_loadingNewTxs,
                      child: Container(
                          padding: const EdgeInsets.all(5),
                          child: IconButton(
                              onPressed: _exportJson,
                              icon: Icon(Icons.share, color: ZapBlue)))),
              Visibility(
                  maintainSize: true,
                  maintainState: true,
                  maintainAnimation: true,
                  visible: !_loading && _more,
                  child: Container(
                      padding: const EdgeInsets.all(5),
                      child: RoundedButton(() => _loadTxs(LoadDirection.Next),
                          ZapBlue, ZapWhite, null, capFirst('next'),
                          icon: Icons.navigate_next, borderColor: ZapBlue))),
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
