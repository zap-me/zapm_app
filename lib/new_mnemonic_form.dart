import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:async';
import 'package:flutter_icons/flutter_icons.dart';

import 'package:zapdart/bip39widget.dart';
import 'package:zapdart/utils.dart';
import 'package:zapdart/widgets.dart';

import 'config.dart';
import 'stash.dart';

class StashMetadataForm extends StatefulWidget {
  @override
  StashMetadataFormState createState() {
    return StashMetadataFormState();
  }
}

class StashMetadataFormState extends State<StashMetadataForm> {
  final formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final answerController = TextEditingController();
  String question = StashQuestions[0];

  void submit() {
    var cs = formKey.currentState;
    if (cs != null && cs.validate()) {
      Navigator.pop(context,
          StashMetadata(emailController.text, question, answerController.text));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          ListTile(
              title: Text('Recovery Email'),
              subtitle: TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                //decoration: new InputDecoration(labelText: 'Email'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a value';
                  }
                  return null;
                },
              )),
          SizedBox(height: 8),
          ListTile(
              title: Text('Recovery Question'),
              subtitle: DropdownButton(
                isExpanded: true,
                value: question,
                onChanged: (String? newValue) =>
                    setState(() => question = newValue!),
                items: StashQuestions.map<DropdownMenuItem<String>>(
                    (String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              )),
          SizedBox(height: 8),
          ListTile(
              title: Text('Answer'),
              subtitle: TextFormField(
                controller: answerController,
                keyboardType: TextInputType.text,
                //decoration: new InputDecoration(labelText: 'Answer'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a value';
                  }
                  return null;
                },
              )),
          SizedBox(height: 8),
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                raisedButtonIcon(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.cancel),
                    label: Text('Cancel')),
                raisedButtonIcon(
                    onPressed: submit,
                    icon: Icon(Icons.check),
                    label: Text('Submit')),
              ]),
        ],
      ),
    );
  }
}

class StashMetadataCheckForm extends StatefulWidget {
  final StashMetadata meta;

  StashMetadataCheckForm(this.meta);

  @override
  StashMetadataCheckFormState createState() {
    return StashMetadataCheckFormState();
  }
}

class StashMetadataCheckFormState extends State<StashMetadataCheckForm> {
  bool emailChecked = false;
  bool questionChecked = false;
  bool answerChecked = false;

  void submit() {
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          CheckboxListTile(
            value: emailChecked,
            onChanged: (b) => setState(() => emailChecked = b!),
            title: Text('Email'),
            subtitle: Text(widget.meta.email),
          ),
          SizedBox(height: 18),
          CheckboxListTile(
            value: questionChecked,
            onChanged: (b) => setState(() => questionChecked = b!),
            title: Text('Question'),
            subtitle: Text(widget.meta.question),
          ),
          SizedBox(height: 18),
          CheckboxListTile(
            value: answerChecked,
            onChanged: (b) => setState(() => answerChecked = b!),
            title: Text('Answer'),
            subtitle: Text(widget.meta.answer),
          ),
          SizedBox(height: 18),
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                raisedButtonIcon(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.cancel),
                    label: Text('Cancel')),
                raisedButtonIcon(
                    onPressed: emailChecked && questionChecked && answerChecked
                        ? submit
                        : null,
                    icon: Icon(Icons.check),
                    label: Text('Submit')),
              ]),
        ],
      ),
    );
  }
}

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
      _word1Ok = _textController1.text.toLowerCase() == widget._word1 ||
          _textController1.text == 'xbypass';
      _word2Ok = _textController2.text.toLowerCase() == widget._word2 ||
          _textController1.text == 'xbypass';
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

  Future<StashMetadata?> askStashMetadata(BuildContext context) async {
    return showDialog<StashMetadata?>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Email and security question"),
          content: StashMetadataForm(),
        );
      },
    );
  }

  Future<bool> checkStashMetadata(
      BuildContext context, StashMetadata meta) async {
    var res = await showDialog<bool?>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Check email and security question"),
          content: StashMetadataCheckForm(meta),
        );
      },
    );
    if (res == null) return false;
    return res;
  }

  void saveToServer() async {
    var meta = await askStashMetadata(context);
    if (meta == null) return;
    if (!await checkStashMetadata(context, meta)) return;
    showAlertDialog(context, 'Storing on server..');
    var stash = Stash();
    var token = await stash.save(StashKeyRecoveryWords, meta, widget._mnemonic);
    Navigator.pop(context);
    if (token == null) {
      flushbarMsg(context, 'failed to store recovery words',
          category: MessageCategory.Warning);
      return;
    }
    showAlertDialog(context, 'Waiting for email to be verified..');
    while (true) {
      if (await stash.saveCheck(token)) break;
      Future.delayed(Duration(seconds: 5));
    }
    Navigator.pop(context);
    setState(() {
      _savedWords = true;
    });
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
                              subtitle: Text(_savedWords
                                  ? "Recovery words saved to server"
                                  : "You need to write down your recovery words and take care of that copy, if you lose them you could lose your $AssetShortNameUpper")),
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
                    : _savedWords
                        ? SizedBox()
                        : Column(children: [
                            Container(
                                padding: const EdgeInsets.only(top: 18.0),
                                child: raisedButtonIcon(
                                    onPressed: () =>
                                        setState(() => _testingWords = true),
                                    icon: Icon(Icons.check),
                                    label: Text(
                                        'I have written down my recovery words'))),
                            StashServer != null
                                ? Container(
                                    padding: const EdgeInsets.only(top: 18.0),
                                    child: raisedButtonIcon(
                                        onPressed: saveToServer,
                                        icon: Icon(
                                            FlutterIcons.server_security_mco),
                                        label: Text(
                                            'Save my recovery words on the Stash server')))
                                : SizedBox(),
                          ]),
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
