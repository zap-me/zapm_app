import 'package:flutter/material.dart';
import 'dart:math';

import 'package:zapdart/bip39widget.dart';
import 'package:zapdart/widgets.dart';

import 'config.dart';

class MnemonicTestForm extends StatefulWidget {
  final Function(bool) _onFormUpdate;
  final int _word1Index, _word2Index;
  final String _word1, _word2;

  MnemonicTestForm(this._word1Index, this._word1, this._word2Index, this._word2,
      this._onFormUpdate)
      : super();

  @override
  MnemonicTestFormState createState() {
    return MnemonicTestFormState();
  }
}

class MnemonicTestFormState extends State<MnemonicTestForm> {
  var _textController1 = TextEditingController();
  var _textController2 = TextEditingController();
  var _word1Ok = false;
  var _word2Ok = false;

  void _inputChanged(String _) {
    setState(() {
      _word1Ok = _textController1.text.toLowerCase() == widget._word1 || _textController1.text == 'xbypass';
      _word2Ok = _textController2.text.toLowerCase() == widget._word2 || _textController1.text == 'xbypass';
      widget._onFormUpdate(_word1Ok && _word2Ok);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Form(
        child: Container(
            padding: EdgeInsets.all(20),
            child: Column(children: [
              Text('Recovery word #${widget._word1Index + 1}'),
              TextFormField(
                enabled: !_word1Ok,
                controller: _textController1,
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                    suffixIcon: _word1Ok ? Icon(Icons.check_box) : null),
                onChanged: _inputChanged,
              ),
              SizedBox(height: 18),
              Text('Recovery word #${widget._word2Index + 1}'),
              TextFormField(
                enabled: !_word2Ok,
                controller: _textController2,
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                    suffixIcon: _word2Ok ? Icon(Icons.check_box) : null),
                onChanged: _inputChanged,
              ),
            ])));
  }
}

class NewMnemonicForm extends StatefulWidget {
  final String _mnemonic;

  NewMnemonicForm(this._mnemonic) : super();

  @override
  NewMnemonicFormState createState() {
    return NewMnemonicFormState();
  }
}

class NewMnemonicFormState extends State<NewMnemonicForm> {
  var _savedWords = false;
  var _testingWords = false;

  int? _word1Index, _word2Index;
  String? _word1, _word2;

  @protected
  @mustCallSuper
  void initState() {
    super.initState();
    initWords();
  }

  void initWords() {
    var words = widget._mnemonic.split(' ');
    assert(words.length == 12);
    var random = Random();
    var word1Index = random.nextInt(words.length);
    var word2Index = word1Index;
    while (word1Index == word2Index) word2Index = random.nextInt(words.length);
    _word1Index = word1Index;
    _word2Index = word2Index;
    _word1 = words[_word1Index!];
    _word2 = words[_word2Index!];
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        child: Scaffold(
          appBar: AppBar(
            title: Text("New recovery words"),
            leading: Icon(Icons.security),
          ),
          body: Center(
            child: Column(
              children: <Widget>[
                _testingWords
                    ? Column(children: [
                        Container(
                          padding: const EdgeInsets.only(top: 18.0),
                          child: ListTile(
                              title: Text("Check saved recovery words"),
                              subtitle: Text(
                                  "Enter the selected recovery words into the form")),
                        ),
                        MnemonicTestForm(
                            _word1Index!, _word1!, _word2Index!, _word2!,
                            (wordsOk) {
                          setState(() => _savedWords = wordsOk);
                        }),
                      ])
                    : Column(children: [
                        Container(
                          padding: const EdgeInsets.only(top: 18.0),
                          child: ListTile(
                              title: Text("New recovery words"),
                              subtitle: Text(
                                  "You need to write down your recovery words and take care of that copy, if you lose them you could lose your $AssetShortNameUpper")),
                        ),
                        Container(
                          padding: const EdgeInsets.only(top: 18.0),
                          child: ListTile(
                              title: Bip39Words.fromString(widget._mnemonic)),
                        ),
                      ]),
                _testingWords
                    ? _savedWords
                        ? SizedBox()
                        : Container(
                            padding: const EdgeInsets.only(top: 18.0),
                            child: raisedButtonIcon(
                                onPressed: () {
                                  initWords();
                                  setState(() => _testingWords = false);
                                },
                                icon: Icon(Icons.arrow_back),
                                label: Text('Show me the recovery words')))
                    : Container(
                        padding: const EdgeInsets.only(top: 18.0),
                        child: raisedButtonIcon(
                            onPressed: () =>
                                setState(() => _testingWords = true),
                            icon: Icon(Icons.check),
                            label:
                                Text('I have written down my recovery words'))),
                Container(
                    padding: const EdgeInsets.only(top: 18.0),
                    child: raisedButtonIcon(
                        onPressed:
                            _savedWords ? () => Navigator.pop(context) : null,
                        icon: Icon(Icons.close),
                        label: Text('Close'))),
              ],
            ),
          ),
        ),
        onWillPop: () {
          return Future<bool>.value(_savedWords);
        });
  }
}
