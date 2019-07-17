import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';
import 'package:intl/intl.dart';

import 'libzap.dart';

class TransactionsScreen extends StatefulWidget {
  String _address = null;

  TransactionsScreen(this._address) : super();

  @override
  _TransactionsState createState() => new _TransactionsState();
}

class _TransactionsState extends State<TransactionsScreen> {
  bool _loading = true;
  List<Tx> _txs = List<Tx>();
  String _after = null;
  bool _more = false;
  int _count = 20;

  @override
  void initState() {
    _loadTxs();
    super.initState();
  }

  void _loadTxs() async {
    setState(() {
      _loading = true;
    });
    var libzap = LibZap();
    var txs = await LibZap.addressTransactions(widget._address, _count, _after);
    setState(() {
      if (txs != null && txs.length > 0) {
        _txs = txs;
        var lastTx = _txs[txs.length-1];
        _after = lastTx.id;
        _more = txs.length == _count;
      }
      else {
        _more = true;
        _txs.clear();
      }
      _loading = false;
    });
  }

  Widget _buildTxList(BuildContext context, int index) {
    var tx = _txs[index];
    var outgoing = tx.sender == widget._address;
    var icon = outgoing ? Icons.remove_circle : Icons.add_circle;
    var amount = Decimal.fromInt(tx.amount) / Decimal.fromInt(100);
    var amountText = outgoing ? "-$amount" : "+$amount";
    var color = outgoing ? Colors.red : Colors.green;
    var date = new DateTime.fromMillisecondsSinceEpoch(tx.timestamp);
    var dateStr = DateFormat("yyyyMMdd").format(date);
    var dateStrLong = DateFormat("yyyy-MM-dd HH:mm").format(date);
    var to = outgoing ? "Recipient: ${tx.recipient}" : "Sender: ${tx.sender}";
    var subtitle = "$dateStr: $to";
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
                            padding: const EdgeInsets.only(top: 18.0),
                            child: ListTile(title: Text(tx.id)),
                          ),
                          Container(
                            padding: const EdgeInsets.only(top: 18.0),
                            child: ListTile(title: Text(dateStrLong)),
                          ),
                          Container(
                            padding: const EdgeInsets.only(top: 10.0),
                            child: ListTile(title: Text(to)),
                          ),
                          Container(
                            padding: const EdgeInsets.only(top: 10.0),
                            child: ListTile(title: Text("$amountText ZAP", style: TextStyle(color: color),)),
                          ),
                          Container(
                            padding: const EdgeInsets.only(top: 18.0),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Transactions"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: _loading ? MainAxisAlignment.center : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Visibility(
              visible: !_loading,
              child:Expanded(
                child: new ListView.builder
                (
                  itemCount: _txs.length,
                  itemBuilder: (BuildContext context, int index) => _buildTxList(context, index),
                ))),
            Visibility(
              visible: !_loading && _more,
              child: Container(
                padding: const EdgeInsets.only(top: 18.0),
                child: RaisedButton.icon(
                    onPressed: () {
                      _loadTxs();
                    },
                    icon: Icon(Icons.navigate_next),
                    label: Text('More'))
                )),
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