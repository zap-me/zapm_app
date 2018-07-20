import 'package:decimal/decimal.dart';
import 'package:tuple/tuple.dart';

String buildUri(String address, Decimal amount) {
  var uri = 'waves:://$address';
  if (amount != null && amount > Decimal.fromInt(0))
    uri += '&amount=$amount';
  return uri;
}

Tuple3<String, Decimal, String> parseUri(String uri) {
  var address = '';
  var amount = Decimal.fromInt(0);
  var attachment = '';
  if (uri.length > 8 && uri.substring(0, 8).toLowerCase() == 'waves://') {
    var parts = uri.substring(8).split('&');
    address = parts[0];
    parts.removeAt(0);
    for (var part in parts) {
      if (part.length > 7 && part.substring(0, 7).toLowerCase() == 'amount=')
        amount = Decimal.parse(part.substring(7));
      if (part.length > 11 && part.substring(0, 11).toLowerCase() == 'attachment=')
        attachment = part.substring(11);
    }
  }
  return Tuple3<String, Decimal, String>(address, amount, attachment);
}