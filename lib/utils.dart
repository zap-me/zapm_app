import 'package:decimal/decimal.dart';
import 'package:tuple/tuple.dart';

const ASSET_ID = 'TEST_ASSET_ID';
const NO_ERROR = 0;
const INVALID_WAVES_URI = 1;
const INVALID_ASSET_ID = 2;

String buildUri(String address, Decimal amount) {
  var uri = 'waves:://$address';
  if (amount != null && amount > Decimal.fromInt(0))
    uri += '&amount=$amount';
  return uri;
}

String parseUriParameter(String input, String token) {
  token = token + '=';
  if (input.length > token.length && input.substring(0, token.length).toLowerCase() == token)
    return input.substring(token.length);
  return null;
}

Tuple5<String, String, Decimal, String, int> parseUri(String uri) {
  var address = '';
  var assetId = '';
  var amount = Decimal.fromInt(0);
  var attachment = '';
  int error = NO_ERROR;
  if (uri.length > 8 && uri.substring(0, 8).toLowerCase() == 'waves://') {
    var parts = uri.substring(8).split('&');
    address = parts[0];
    parts.removeAt(0);
    for (var part in parts) {
      var res = parseUriParameter(part, 'asset');
      if (res != null) assetId = res;
      res = parseUriParameter(part, 'amount');
      if (res != null) amount = Decimal.parse(res);
      res = parseUriParameter(part, attachment);
      if (res != null) attachment = res;
    }
    if (assetId != ASSET_ID) {
      address = '';
      error = INVALID_ASSET_ID;
    }
  }
  else
    error = INVALID_WAVES_URI;
  return Tuple5<String, String, Decimal, String, int>(address, assetId, amount, attachment, error);
}