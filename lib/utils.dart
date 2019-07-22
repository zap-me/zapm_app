import 'package:flutter/material.dart';
import 'package:decimal/decimal.dart';
import 'package:tuple/tuple.dart';

import 'libzap.dart';

//
// We do our own uri parsing until dart has better struct/fixed-size-array support in ffi
//

const NO_ERROR = 0;
const INVALID_WAVES_URI = 1;
const INVALID_ASSET_ID = 2;

String parseUriParameter(String input, String token) {
  token = token + '=';
  if (input.length > token.length && input.substring(0, token.length).toLowerCase() == token)
    return input.substring(token.length);
  return null;
}

Tuple5<String, String, Decimal, String, int> parseUri(bool testnet, String uri) {
  var address = '';
  var assetId = '';
  var amount = Decimal.fromInt(0);
  var attachment = '';
  int error = NO_ERROR;
  if (uri.length > 8 && uri.substring(0, 8).toLowerCase() == 'waves://') {
    var parts = uri.substring(8).split('?');
    if (parts.length == 2) {
      address = parts[0];
      parts = parts[1].split('&');
      for (var part in parts) {
        var res = parseUriParameter(part, 'asset');
        if (res != null) assetId = res;
        res = parseUriParameter(part, 'amount');
        if (res != null) amount = Decimal.parse(res) / Decimal.fromInt(100);
        res = parseUriParameter(part, attachment);
        if (res != null) attachment = res;
      }
    }
    var zapAssetId = testnet ? LibZap.TESTNET_ASSET_ID : LibZap.MAINNET_ASSET_ID;
    if (assetId != zapAssetId) {
      address = '';
      error = INVALID_ASSET_ID;
    }
  }
  else
    error = INVALID_WAVES_URI;
  return Tuple5<String, String, Decimal, String, int>(address, assetId, amount, attachment, error);
}

String parseRecipientOrUri(bool testnet, String data) {
  var libzap = LibZap();
  if (libzap.addressCheck(data))
    return data;                // return input, user can use this data as an address
  var result = parseUri(testnet, data);
  if (result.item5 == NO_ERROR)
    return result.item1;        // return address part of waves uri, user should call parseUri directly for extra details
  return null;                  // return null, data is not usable/valid
}

Future<void> alert(BuildContext context, String title, String msg) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: <Widget>[
          FlatButton(
            child: Text("Ok"),
            onPressed: () {
              Navigator.of(context).pop();
            },
          ),
        ],
      );
    },
  );
}