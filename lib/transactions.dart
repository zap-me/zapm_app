import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flushbar/flushbar.dart';
import 'package:path_provider/path_provider.dart';

import 'libzap.dart';
import 'utils.dart';

class TransactionsScreen extends StatefulWidget {
  final String _address;
  final bool _testnet;

  TransactionsScreen(this._address, this._testnet) : super();

  @override
  _TransactionsState createState() => new _TransactionsState();
}

enum LoadDirection {
  Next, Previous, Initial
}

class Choice {
  const Choice({this.title, this.icon});

  final String title;
  final IconData icon;
}

const List<Choice> choices = const <Choice>[
  const Choice(title: "Export JSON", icon: Icons.save),
];

class _TransactionsState extends State<TransactionsScreen> {
  bool _loading = true;
  List<Tx> _txs = List<Tx>();
  int _offset = 0;
  int _count = 10;
  String _after;
  bool _more = false;
  bool _less = false;
  bool _foundEnd = false;

  @override
  void initState() {
    _loadTxs(LoadDirection.Initial);
    super.initState();
  }

  Future<int> _downloadMoreTxs(int count) async {
    var txs = await LibZap.addressTransactions(widget._address, count, _after);
    if (txs != null) {
      _txs = _txs + txs;
      if (_txs.length > 0)
        _after = _txs[_txs.length - 1].id;
      if (txs.length < count)
        _foundEnd = true;
    }
    else
      return -1;
    return txs.length;
  }

  void _loadTxs(LoadDirection dir) async {
    var newOffset = _offset;
    if (dir == LoadDirection.Next) {
      newOffset += _count;
      if (newOffset > _txs.length)
        newOffset = _txs.length;
    }
    else if (dir == LoadDirection.Previous) {
      newOffset -= _count;
      if (newOffset < 0)
        newOffset = 0;
    }
    if (newOffset == _txs.length) {
      // set loading
      setState(() {
        _loading = true;
      });
      // load new txs
      var res = await _downloadMoreTxs(_count);
      setState(() {
        if (res != -1) {
          _more = res == _count;
          _less = newOffset > 0;
          _offset = newOffset;
        }
        else {
          Flushbar(title: "Failed to load transactions", message: "try again? :(", duration: Duration(seconds: 2),)
            ..show(context);
        }
        _loading = false;
      });
    }
    else {
      setState(() {
        _more = !_foundEnd || newOffset < _txs.length - _count;
        _less = newOffset > 0;
        _offset = newOffset;
      });
    }
  }

  Widget _buildTxList(BuildContext context, int index) {
    var offsetIndex = _offset + index;
    if (offsetIndex >= _offset + _count || offsetIndex >= _txs.length)
      return null;
    var tx = _txs[offsetIndex];
    var zapAssetId = widget._testnet ? LibZap.TESTNET_ASSET_ID : LibZap.MAINNET_ASSET_ID;
    if (tx.assetId != zapAssetId)
      return SizedBox.shrink();
    var outgoing = tx.sender == widget._address;
    var icon = outgoing ? Icons.remove_circle : Icons.add_circle;
    var amount = Decimal.fromInt(tx.amount) / Decimal.fromInt(100);
    var amountText = amount.toStringAsFixed(2);
    var fee = Decimal.fromInt(tx.fee) / Decimal.fromInt(100);
    var feeText = fee.toStringAsFixed(2);
    amountText = outgoing ? "-$amountText" : "+$amountText";
    var color = outgoing ? Colors.red : Colors.green;
    var date = new DateTime.fromMillisecondsSinceEpoch(tx.timestamp);
    var dateStr = DateFormat("yyyyMMdd").format(date);
    var dateStrLong = DateFormat("yyyy-MM-dd HH:mm").format(date);
    var tofrom = outgoing ? "Recipient: ${tx.recipient}" : "Sender: ${tx.sender}";
    var subtitle = "$dateStr: $tofrom";
    var link = widget._testnet ? "https://wavesexplorer.com/testnet/tx/${tx.id}" : "https://wavesexplorer.com/tx/${tx.id}";
    var attachment = tx.attachment;
    if (tx.attachment != null && tx.attachment != "")
      attachment = base58decode(tx.attachment);
    return Card(
      child: ListTile(
        leading: Icon(icon, color: color,),
        title: Text("${tx.id}", maxLines: 1, overflow: TextOverflow.ellipsis,),
        subtitle: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,),
        trailing: Text(amountText, style: TextStyle(color: color),),
        onTap: () {
          Navigator.of(context).push(
            // We will now use PageRouteBuilder
            PageRouteBuilder(
                opaque: false,
                pageBuilder: (BuildContext context, __, ___) {
                  return new Scaffold(
                    backgroundColor: Colors.black45,
                    body: Container(
                      color: Colors.white,
                      child: Column(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.only(top: 5.0),
                            child: ListTile(title: Text("Transaction ID"),
                                subtitle: InkWell(
                                  child: Text(tx.id, style: new TextStyle(color: Colors.blue, decoration: TextDecoration.underline))),
                                  onTap: () => launch(link),
                                ),

                          ),
                          ListTile(title: Text("Date"), subtitle: Text(dateStrLong)),
                          ListTile(title: Text("Sender"), subtitle: Text(tx.sender)),
                          ListTile(title: Text("Recipient"), subtitle: Text(tx.recipient)),
                          ListTile(title: Text("Amount"), subtitle: Text("$amountText ZAP", style: TextStyle(color: color),)),
                          ListTile(title: Text("Fee"), subtitle: Text("$feeText ZAP",)),
                          Visibility(
                            visible: attachment != null && attachment != "",
                            child:
                              ListTile(title: Text("Attachment"), subtitle: Text(attachment)),
                          ),
                          Container(
                            padding: const EdgeInsets.only(top: 5.0),
                            child: RaisedButton.icon(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                icon: Icon(Icons.close),
                                label: Text('Close'))
                          ),
                        ],
                      ),
                    )
                  ); // Scaffold
                })
            );
          }
        ),
      );
  }

  void _select(Choice choice) async {
    switch (choice.title) {
      case "Export JSON":
        setState(() {
          _loading = true;
        });
        while (true) {
          var txs = await _downloadMoreTxs(100);
          if (txs == -1) {
            Flushbar(title: "Failed to load transactions", message: "try again? :(", duration: Duration(seconds: 2),)
              ..show(context);
            setState(() {
              _loading = false;
            });
            return;
          }
          else if (_foundEnd) {
            var json = jsonEncode(_txs);
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
          Flushbar(title: "Loaded ${_txs.length} transactions", message: "...", duration: Duration(seconds: 2),)
            ..show(context);
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Transactions"),
        actions: <Widget>[
          PopupMenuButton<Choice>(
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
          mainAxisAlignment: _loading ? MainAxisAlignment.center : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Visibility(
                visible: !_loading && _txs.length == 0,
                child: Text("Nothing here..")),
            Visibility(
              visible: !_loading,
              child: Expanded(
                child: new ListView.builder(
                  itemCount: _txs.length,
                  itemBuilder: (BuildContext context, int index) => _buildTxList(context, index),
                ))),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Visibility(
                    visible: !_loading && _less,
                    child: Container(
                        padding: const EdgeInsets.only(top: 18.0),
                        child: RaisedButton.icon(
                            onPressed: () => _loadTxs(LoadDirection.Previous),
                            icon: Icon(Icons.navigate_before),
                            label: Text('Prev'))
                    )),
                Visibility(
                    visible: !_loading && _more,
                    child: Container(
                        padding: const EdgeInsets.only(top: 18.0),
                        child: RaisedButton.icon(
                            onPressed: () => _loadTxs(LoadDirection.Next),
                            icon: Icon(Icons.navigate_next),
                            label: Text('Next'))
                    )),

              ],
            ),
            Visibility(
                visible: _loading,
                child: CircularProgressIndicator(),
            ),
          ],
        ),
      )
    );
  }
}