import 'package:flutter/material.dart';
import 'package:edit_distance/edit_distance.dart';

import 'libzap.dart';

typedef WordsCallback = void Function(List<String>); 

extension ExtendedIterable<E> on Iterable<E> {
  /// Like Iterable<T>.map but callback have index as second argument
  Iterable<T> mapIndex<T>(T f(E e, int i)) {
    var i = 0;
    return this.map((e) => f(e, i++));
  }

  void forEachIndex(void f(E e, int i)) {
    var i = 0;
    this.forEach((e) => f(e, i++));
  }
}

class Bip39Widget extends StatefulWidget {
  Bip39Widget(this.onWordsUpdate) : super();

  WordsCallback onWordsUpdate;

  @override
  _Bip39WidgetState createState() => new _Bip39WidgetState();
}

class _Bip39WidgetState extends State<Bip39Widget> {
  var _textController = TextEditingController();
  var _levenshtein = Levenshtein();
  List<String> _wordlist = LibZap().mnemonicWordlist();
  List<String> _mnemonicWords = List<String>();
  var _candidate1 = '';
  var _candidate2 = '';
  var _candidate3 = '';
  var _validBip39 = false;

  void inputChanged(String value) {
    var c1 = '', c2 = '', c3 = '';
    var d1 = 1.0, d2 = 1.0, d3 = 1.0;
    for (var item in _wordlist) {
      if (value == item) {
        setState(() {
          _candidate1 = '';
          _candidate2 = '';
          _candidate3 = '';
          _mnemonicWords.add(value);
          updateWords();
          _textController.text = '';
        });
        return;
      }
      var dist = _levenshtein.normalizedDistance(value, item);
      if (dist > 0.4)
        continue;
      if (dist < d1) {
        d1 = dist;
        c1 = item;
      } else if (dist < d2) {
        d2 = dist;
        c2 = item;
      } else if (dist < d3) {
        d3 = dist;
        c3 = item;
      }
    }
    setState(() {
      _candidate1 = c1;
      _candidate2 = c2;
      _candidate3 = c3;      
    });
  }

  void wordRemove(int index) {
    setState(() {
      _mnemonicWords.removeAt(index);
      updateWords();
    });
  }

  void updateWords() {
    _validBip39 = LibZap().mnemonicCheck(_mnemonicWords.join(' '));
    widget.onWordsUpdate(_mnemonicWords);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        TextField(
          autofocus: true,
          controller: _textController,
          decoration: InputDecoration(labelText: "Mnemonic",),
          onChanged: inputChanged,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            ButtonTheme(minWidth: 40, height: 25, child: RaisedButton(child: Text(_candidate1), onPressed: () => inputChanged(_candidate1),)),
            ButtonTheme(minWidth: 40, height: 25, child: RaisedButton(child: Text(_candidate2), onPressed: () => inputChanged(_candidate2),)),
            ButtonTheme(minWidth: 40, height: 25, child: RaisedButton(child: Text(_candidate3), onPressed: () => inputChanged(_candidate3),)),
          ]),
        Wrap(
          children: _mnemonicWords.mapIndex((item, index) {
            return ButtonTheme(buttonColor: _validBip39 ? Colors.greenAccent : Colors.white, minWidth: 40, height: 30, child: RaisedButton(child: Text(item), onPressed: () => wordRemove(index), padding: EdgeInsets.all(4)));
          }).toList().cast<Widget>(),
        ),
      ],
    );
  }
}
