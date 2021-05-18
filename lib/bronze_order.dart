import 'dart:convert';
import 'package:decimal/decimal.dart';

class BronzeOrder {
  final String assetSend;
  final Decimal amountSend;
  final String assetReceive;
  final Decimal amountReceive;
  final int expiry;
  final String token;
  final String? invoiceId;
  final String? paymentAddress;
  final String? paymentUrl;
  final String? txIdPayment;
  final String recipient;
  final String? txIdRecipient;
  String status;

  BronzeOrder(
      this.assetSend,
      this.amountSend,
      this.assetReceive,
      this.amountReceive,
      this.expiry,
      this.token,
      this.invoiceId,
      this.paymentAddress,
      this.paymentUrl,
      this.txIdPayment,
      this.recipient,
      this.txIdRecipient,
      this.status);

  String toJson() {
    return jsonEncode({
      'assetSend': assetSend,
      'amountSend': amountSend.toString(),
      'assetReceive': assetReceive,
      'amountReceive': amountReceive.toString(),
      'expiry': expiry,
      'token': token,
      'invoiceId': invoiceId,
      'paymentAddress': paymentAddress,
      'paymentUrl': paymentUrl,
      'txIdPayment': txIdPayment,
      'recipient': recipient,
      'txIdRecipient': txIdRecipient,
      'status': status,
    });
  }

  static BronzeOrder makeEmpty() => BronzeOrder('', Decimal.zero, '',
      Decimal.zero, 0, '', null, null, null, null, '', null, '');

  static BronzeOrder fromJson(String data) {
    var json = jsonDecode(data);
    var assetSend = json['assetSend'];
    var amountSend = Decimal.parse(json['amountSend']);
    var assetReceive = json['assetReceive'];
    var amountReceive = Decimal.parse(json['amountReceive']);
    var expiry = json['expiry'];
    var token = json['token'];
    var invoiceId = json['invoiceId'];
    var paymentAddress = json['paymentAddress'];
    var paymentUrl = json['paymentUrl'];
    var txIdPayment = json['txIdPayment'];
    var recipient = json['recipient'];
    var txIdRecipient = json['txIdRecipient'];
    var status = json['status'];
    return BronzeOrder(
        assetSend,
        amountSend,
        assetReceive,
        amountReceive,
        expiry,
        token,
        invoiceId,
        paymentAddress,
        paymentUrl,
        txIdPayment,
        recipient,
        txIdRecipient,
        status);
  }
}
