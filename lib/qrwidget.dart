import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class QrWidget extends StatefulWidget {
  QrWidget(this.data) : super();

  final String data;

  @override
  _QrWidgetState createState() => new _QrWidgetState();
}

class _QrWidgetState extends State<QrWidget> {
  String _inputErrorText;

  @override
  Widget build(BuildContext context) {
    if (_inputErrorText != null)
      return Text(_inputErrorText);
    return new QrImage(
        data: widget.data,
        size: 300.0,
        version: 10,
        errorCorrectionLevel: QrErrorCorrectLevel.H,
        onError: (ex) {
          print("[QR] ERROR - $ex");
          setState(() {
            _inputErrorText = "Error! Maybe your input value is too long?";
          });
        });
  }
}
