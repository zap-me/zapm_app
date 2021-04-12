import 'dart:io';
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';

import 'package:zapdart/widgets.dart';
import 'package:zapdart/colors.dart';

class QrScan extends StatefulWidget {
  QrScan() : super();

  @override
  _QrScanState createState() => _QrScanState();

  static Future<String?> scan(BuildContext context) async {
    return await Navigator.push<String>(
        context, MaterialPageRoute(builder: (context) => QrScan()));
  }
}

class _QrScanState extends State<QrScan> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;

  // In order to get hot reload to work we need to pause the camera if the platform
  // is android, or resume the camera if the platform is iOS.
  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller?.pauseCamera();
    } else if (Platform.isIOS) {
      controller?.resumeCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          leading: backButton(context, color: ZapBlack),
          title: Text("QR Code Scan"),
        ),
        body: Container(
          child: QRView(
            key: qrKey,
            formatsAllowed: [BarcodeFormat.qrcode],
            onQRViewCreated: _onQRViewCreated,
          ),
        ));
  }

  void _onQRViewCreated(QRViewController controller) {
    this.controller = controller;
    var stopped = false;
    controller.scannedDataStream.listen((scanData) {
      if (stopped) return;
      stopped = true;
      controller.stopCamera();
      Navigator.of(context).pop(scanData.code);
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}
