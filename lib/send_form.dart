import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';
import 'package:qr_reader/qr_reader.dart';

class SendForm extends StatefulWidget {
  final VoidCallback onCancelled;
  final VoidCallback onSend;
  final String recipient;
  final Decimal max;

  SendForm(this.onCancelled, this.onSend, this.recipient, this.max) : super();

  @override
  SendFormState createState() {
    return SendFormState();
  }
}

class SendFormState extends State<SendForm> {
  final _formKey = GlobalKey<FormState>();
  final _controller = new TextEditingController();

  @protected
  @mustCallSuper
  void initState() {
    super.initState();
    _controller.text = widget.recipient;
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          new Stack(alignment: const Alignment(1.0, 1.0), children: <Widget>[
            new TextFormField(
              controller: _controller,
              keyboardType: TextInputType.text,
              decoration: new InputDecoration(labelText: 'Recipient Address'),
              validator: (value) {
                if (value.isEmpty) {
                  return 'Please enter a value';
                }
              },
            ),
            new FlatButton(
                onPressed: () {
                  var qrCode = new QRCodeReader().scan();
                  qrCode.then((value) {
                    if (value != null) _controller.text = value;
                  });
                },
                child: new Icon(Icons.center_focus_weak))
          ]),
          TextFormField(
            keyboardType: TextInputType.number,
            decoration: new InputDecoration(labelText: 'Amount'),
            validator: (value) {
              if (value.isEmpty) {
                return 'Please enter a value';
              }
              final dv = Decimal.parse(value);
              if (dv > widget.max) {
                return 'Max value is ${widget.max}';
              }
              if (dv <= Decimal.fromInt(0)) {
                return 'Please enter a value greater then zero';
              }
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: RaisedButton.icon(
                onPressed: () {
                  if (_formKey.currentState.validate()) {
                    widget.onSend();
                  }
                },
                icon: Icon(Icons.send),
                label: Text('Submit')),
          ),
          RaisedButton.icon(
              onPressed: widget.onCancelled,
              icon: Icon(Icons.cancel),
              label: Text('Cancel')),
        ],
      ),
    );
  }
}
