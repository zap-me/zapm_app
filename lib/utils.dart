import 'package:decimal/decimal.dart';

String buildUri(String address, Decimal amount) {
  var uri = 'waves:://$address';
  if (amount != null && amount > Decimal.fromInt(0))
    uri += '&amount=$amount';
  return uri;
}