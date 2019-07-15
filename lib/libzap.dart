import 'dart:ffi';
import 'package:flutter/foundation.dart';
import 'package:decimal/decimal.dart';

import 'dylib_utils.dart';
import 'utf8.dart';

class IntResult {
  bool success;
  int value;
  IntResult(this.success, this.value);
}

//
// native libzap definitions
//

class IntResultNative extends Struct<IntResultNative> {
  @Int8()
  int success;

  @Int64()
  int value;

  factory IntResultNative.allocate(bool success, int value) {
    return Pointer<IntResultNative>.allocate().load<IntResultNative>()
      ..success = (success ? 1 : 0)
      ..value = value;
  }
}

/* c def
struct waves_payment_request_t
{
  char address[MAX_TXFIELD];
  char asset_id[MAX_TXFIELD];
  char attachment[MAX_TXFIELD];
  uint64_t amount;
};
*/
class WavesPaymentRequest extends Struct<WavesPaymentRequest> {
  //TODO
}

typedef lzap_version_native_t = Int32 Function();
typedef lzap_version_t = int Function();

typedef lzap_network_get_native_t = Int8 Function();
typedef lzap_network_get_t = int Function();
typedef lzap_network_set_native_t = Int32 Function(Int8 network_byte);
typedef lzap_network_set_t = int Function(int network_byte);

typedef lzap_address_check_native_t = IntResult Function(Pointer<Utf8> address);
typedef lzap_address_check_ns_native_t = Int8 Function(Pointer<Utf8> address);
typedef lzap_address_check_ns_t = int Function(Pointer<Utf8> address);

typedef lzap_address_balance_ns_native_t = Int8 Function(Pointer<Utf8> address, Pointer<Int64> balance_out);
typedef lzap_address_balance_ns_t = int Function(Pointer<Utf8> address, Pointer<Int64> balance_out);

//
// helper functions
//

IntResult addressBalanceFromIsolate(String address) {
  // as we are running this in an isolate we need to reinit a LibZap instance
  // to get the function pointer as closures can not be passed to isolates
  var libzap = LibZap();

  var addrC = Utf8.allocate(address);
  var balanceP = Pointer<Int64>.allocate();
  var res = libzap.lzap_address_balance(addrC, balanceP) != 0;
  int balance = balanceP.load();
  balanceP.free();
  addrC.free();
return IntResult(res != 0, balance);
}

//
// LibZap class
//

class LibZap {

  LibZap() {
    libzap = dlopenPlatformSpecific("zap");
    lzap_version = libzap
        .lookup<NativeFunction<lzap_version_native_t>>("lzap_version")
        .asFunction();
    lzap_network_get = libzap
        .lookup<NativeFunction<lzap_network_get_native_t>>("lzap_network_get")
        .asFunction();
    lzap_network_set = libzap
        .lookup<NativeFunction<lzap_network_set_native_t>>("lzap_network_set")
        .asFunction();
    lzap_version = libzap
        .lookup<NativeFunction<lzap_version_native_t>>("lzap_version")
        .asFunction();
    lzap_address_check = libzap
        .lookup<NativeFunction<lzap_address_check_ns_native_t>>("lzap_address_check_ns")
        .asFunction();
    lzap_address_balance = libzap
        .lookup<NativeFunction<lzap_address_balance_ns_native_t>>("lzap_address_balance_ns")
        .asFunction();
  }

  static const String ADDR = "3MzXK4jd8t7SniG6EPuw3qo7dST36TEawB9";
  static const String ASSET_ID = "CgUrFtinLXEbJwJVjwwcppk4Vpz1nMmR3H5cQaDcUcfe";

  DynamicLibrary libzap;
  lzap_version_t lzap_version;
  lzap_network_get_t lzap_network_get;
  lzap_network_set_t lzap_network_set;
  lzap_address_check_ns_t lzap_address_check;
  lzap_address_balance_ns_t lzap_address_balance;

  String walletAddr() {
    return ADDR;
  }

  static String paymentUri(String address, int amount) {
    var uri = "waves://$address?asset=$ASSET_ID";
    if (amount != null)
      uri += "&amount=$amount";
    return uri;
  }

  static String paymentUriDec(String address, Decimal amount) {
    if (amount != null && amount > Decimal.fromInt(0)) {
      amount = amount * Decimal.fromInt(100);
      var amountInt = amount.toInt();
      return paymentUri(address, amountInt);
    }
    return paymentUri(address, null);
  }

  //
  // native libzap wrapper functions
  //

  int version() {
    return lzap_version();
  }

  bool testnetGet() {
    var networkByte = String.fromCharCode(lzap_network_get());
    if (networkByte == 'T')
      return true;
    else if (networkByte == 'W')
      return false;
    else
      throw new FormatException("network byte not recognised");
  }

  bool testnetSet(bool value) {
    String networkByte;
    if (value)
      networkByte = 'T';
    else
      networkByte = 'W';
    int char = networkByte.codeUnitAt(0);
    return lzap_network_set(char) != 0;
  }

  bool addressCheck(String address) {
    var addrC = Utf8.allocate(address);
    var res = lzap_address_check(addrC) != 0;
    addrC.free();
    return res;
  }

  Future<IntResult> addrBalance(String address) async {
    return compute(addressBalanceFromIsolate, address);
  }
}