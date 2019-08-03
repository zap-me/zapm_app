import 'dart:ffi';
import 'dart:typed_data';
import "dart:convert";
import 'package:flutter/foundation.dart';
import 'package:decimal/decimal.dart';

import 'dylib_utils.dart';
import 'utf8.dart';
import 'bytes.dart';

class IntResult {
  bool success;
  int value;
  IntResult(this.success, this.value);
}

class Tx {
  static final textFieldSize = 1024;
  static final int64FieldSize = 8;
  static final totalSize = int64FieldSize + textFieldSize * 6 + int64FieldSize * 3;

  int type;
  String id;
  String sender;
  String recipient;
  String assetId;
  String feeAsset;
  String attachment;
  int amount;
  int fee;
  int timestamp;

  Tx(this.type, this.id, this.sender, this.recipient, this.assetId, this.feeAsset, this.attachment, this.amount, this.fee, this.timestamp);

  Pointer<CBuffer> toBuffer() {
    var buf = CBuffer.allocate(totalSize);
    var offset = 0;

    // type field
    var intList = new Uint8List(int64FieldSize);
    var intByteData = new ByteData.view(intList.buffer);
    intByteData.setInt64(offset, type);
    offset += int64FieldSize;
    // id field
    buf.load().copyInto(offset, utf8.encode(id));
    offset += textFieldSize;
    // sender field
    buf.load().copyInto(offset, utf8.encode(sender));
    offset += textFieldSize;
    // recipient field
    buf.load().copyInto(offset, utf8.encode(recipient));
    offset += textFieldSize;
    // assetId field
    buf.load().copyInto(offset, utf8.encode(assetId));
    offset += textFieldSize;
    // feeAsset field
    buf.load().copyInto(offset, utf8.encode(feeAsset));
    offset += textFieldSize;
    // attachment field
    buf.load().copyInto(offset, utf8.encode(attachment));
    offset += textFieldSize;
    // amount field
    intByteData.setInt64(0, amount);
    buf.load().copyInto(offset, intList);
    offset += int64FieldSize;
    // amount field
    intByteData.setInt64(0, fee);
    buf.load().copyInto(offset, intList);
    offset += int64FieldSize;
    // amount field
    intByteData.setInt64(0, timestamp);
    buf.load().copyInto(offset, intList);
    offset += int64FieldSize;

    return buf;
  }

  static Tx fromCBuffer(CBuffer buf) {
    var ints = buf.toIntList(totalSize);
    int offset = 0;

    var type = Int8List.fromList(ints).buffer.asByteData().getInt64(offset, Endian.little);
    offset += 8;
    var id = intListToString(ints, offset, textFieldSize);
    offset += textFieldSize;
    var sender = intListToString(ints, offset, textFieldSize);
    offset += textFieldSize;
    var recipient = intListToString(ints, offset, textFieldSize);
    offset += textFieldSize;
    var assetId = intListToString(ints, offset, textFieldSize);
    offset += textFieldSize;
    var feeAsset = intListToString(ints, offset, textFieldSize);
    offset += textFieldSize;
    var attachment = intListToString(ints, offset, textFieldSize);
    offset += textFieldSize;
    var amount = Int8List.fromList(ints).buffer.asByteData().getInt64(offset, Endian.little);
    offset += 8;
    var fee = Int8List.fromList(ints).buffer.asByteData().getInt64(offset, Endian.little);
    offset += 8;
    var timestamp = Int8List.fromList(ints).buffer.asByteData().getInt64(offset, Endian.little);
    offset += 8;

    return Tx(type, id, sender, recipient, assetId, feeAsset, attachment, amount, fee, timestamp);
  }

  static Iterable<Tx> fromCBufferMulti(Pointer<CBuffer> buf, int count) {
    var res = List<Tx>();
    for (int i=0; i < count; i++) {
      var offset = i * totalSize;
      var tx = fromCBuffer(buf.elementAt(offset).load<CBuffer>());
      res.add(tx);
    }
    return res;
  }

  static Pointer<CBuffer> allocate({int count=1}) {
    return Pointer.allocate(count: totalSize * count);
  }

  Map<String, dynamic> toJson() =>
      {
        'type': type,
        'id': id,
        'sender': sender,
        'recipient': recipient,
        'assetId': assetId,
        'feeAsset': feeAsset,
        'attachment': attachment,
        'amount': amount,
        'fee': fee,
        'timestamp': timestamp
      };
}

class SpendTx {
  static final int32FieldSize = 4;
  static final dataFieldSize = 364;
  static final sigFieldSize = 64;
  static final totalSize = int32FieldSize + dataFieldSize + int32FieldSize + sigFieldSize;

  bool success;
  Iterable<int> data;
  Iterable<int> signature;

  SpendTx(this.success, this.data, this.signature);

  Pointer<CBuffer> toBuffer() {
    var buf = CBuffer.allocate(totalSize);

    // success field
    var int32List = new Uint8List(int32FieldSize);
    var int32ByteData = new ByteData.view(int32List.buffer);
    int32ByteData.setInt32(0, 1);
    buf.load().copyInto(0, int32List);
    // data field
    buf.load().copyInto(int32FieldSize, data);
    // data_size field
    int32ByteData.setInt32(0, data.length);
    buf.load().copyInto(int32FieldSize + dataFieldSize, int32List);
    // signature field
    buf.load().copyInto(int32FieldSize + dataFieldSize + int32FieldSize, signature);

    return buf;
  }

  static SpendTx fromCBuffer(CBuffer buf) {
    var ints = buf.toIntList(totalSize);

    var success = Int8List.fromList(ints).buffer.asByteData().getInt32(0, Endian.little);
    var dataSize = Int8List.fromList(ints).buffer.asByteData().getInt32(int32FieldSize + dataFieldSize, Endian.little);
    assert(dataSize >= 0 && dataSize <= dataFieldSize);
    var data = ints.skip(int32FieldSize).take(dataSize);
    var sig = ints.skip(int32FieldSize + dataFieldSize + int32FieldSize).take(sigFieldSize);

    return SpendTx(success != 0, data, sig);
  }

  static Pointer<CBuffer> allocate() {
    return Pointer.allocate(count: totalSize);
  }
}

//
// native libzap definitions
//

class IntResultNative extends Struct<IntResultNative> {
  @Int32()
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
#define MAX_TXFIELD 1024
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
typedef lzap_network_set_native_t = Int8 Function(Int8 networkByte);
typedef lzap_network_set_t = int Function(int networkByte);

typedef lzap_mnemonic_create_native_t = Int8 Function(Pointer<Utf8> output, Int32 size);
typedef lzap_mnemonic_create_t = int Function(Pointer<Utf8> output, int size);

typedef lzap_mnemonic_check_native_t = Int8 Function(Pointer<Utf8> mnemonic);
typedef lzap_mnemonic_check_t = int Function(Pointer<Utf8> mnemonic);

//TODO: this function does not actually return anything, but dart:ffi does not seem to handle void functions yet
typedef lzap_seed_address_native_t = Int32 Function(Pointer<Utf8> seed, Pointer<Utf8> output);
typedef lzap_seed_address_t = int Function(Pointer<Utf8> seed, Pointer<Utf8> output);

typedef lzap_address_check_native_t = IntResult Function(Pointer<Utf8> address);
//TODO: ns version
typedef lzap_address_check_ns_native_t = Int8 Function(Pointer<Utf8> address);
typedef lzap_address_check_ns_t = int Function(Pointer<Utf8> address);

//TODO: ns version
typedef lzap_address_balance_ns_native_t = Int8 Function(Pointer<Utf8> address, Pointer<Int64> balanceOut);
typedef lzap_address_balance_ns_t = int Function(Pointer<Utf8> address, Pointer<Int64> balanceOut);

//TODO: ns version of transaction list
typedef lzap_address_transactions2_ns_native_t = Int8 Function(Pointer<Utf8> address, Pointer<CBuffer> txs, Int32 count, Pointer<Utf8> after, Pointer<Int64> countOut);
typedef lzap_address_transactions2_ns_t = int Function(Pointer<Utf8> address, Pointer<CBuffer> txs, int count, Pointer<Utf8> after, Pointer<Int64> countOut);

typedef lzap_transaction_fee_ns_native_t = Int8 Function(Pointer<Int64> feeOut);
typedef lzap_transaction_Fee_ns_t = int Function(Pointer<Int64> feeOut);

//TODO: this function does not actually return anything, but dart:ffi does not seem to handle void functions yet
typedef lzap_transaction_create_ns_native_t = Int32 Function(Pointer<Utf8> seed, Pointer<Utf8> recipient, Int64 amount, Int64 fee, Pointer<Utf8> attachment, Pointer<CBuffer> spendTxOut);
typedef lzap_transaction_create_ns_t = int Function(Pointer<Utf8> seed, Pointer<Utf8> recipient, int amount, int fee, Pointer<Utf8> attachment, Pointer<CBuffer> spendTxOut);

//TODO: ns version of transaction broadcast!!!
typedef lzap_transaction_broadcast_ns_native_t = Int32 Function(Pointer<CBuffer> spendTx, Pointer<CBuffer> broadcastTxOut);
typedef lzap_transaction_broadcast_ns_t = int Function(Pointer<CBuffer> spendTx, Pointer<CBuffer> broadcastTxOut);

//
// helper functions
//

String intListToString(Iterable<int> lst, int offset, int count) {
  lst = lst.skip(offset).take(count);
  int len = 0;
  while (lst.elementAt(len) != 0)
    len++;
  return Utf8Decoder().convert(lst.take(len).toList());
}

IntResult addressBalanceFromIsolate(String address) {
  // as we are running this in an isolate we need to reinit a LibZap instance
  // to get the function pointer as closures can not be passed to isolates
  var libzap = LibZap();

  var addrC = Utf8.allocate(address);
  var balanceP = Pointer<Int64>.allocate();
  var res = libzap.lzapAddressBalance(addrC, balanceP) != 0;
  int balance = balanceP.load();
  balanceP.free();
  addrC.free();
  return IntResult(res, balance);
}

class AddrTxsRequest {
  String address;
  int count;
  String after;
  AddrTxsRequest(this.address, this.count, this.after);
}
Iterable<Tx> addressTransactionsFromIsolate(AddrTxsRequest req) {
  // as we are running this in an isolate we need to reinit a LibZap instance
  // to get the function pointer as closures can not be passed to isolates
  var libzap = LibZap();

  var addrC = Utf8.allocate(req.address);
  var txsC = Tx.allocate(count: req.count);
  Pointer afterC = nullptr;
  if (req.after != null)
    afterC = Utf8.allocate(req.after);
  var countOutP = Pointer<Int64>.allocate();
  var res = libzap.lzapAddressTransactions(addrC, txsC, req.count, afterC.cast<Utf8>(), countOutP) != 0;
  Iterable<Tx> txs;
  if (res) {
    int count = countOutP.load();
    txs = Tx.fromCBufferMulti(txsC, count);
  }
  countOutP.free();
  afterC.free();
  txsC.free();
  addrC.free();
  return txs;
}

IntResult transactionFeeFromIsolate(int _dummy) {
  // as we are running this in an isolate we need to reinit a LibZap instance
  // to get the function pointer as closures can not be passed to isolates
  var libzap = LibZap();

  var feeP = Pointer<Int64>.allocate();
  var res = libzap.lzapTransactionFee(feeP) != 0;
  int fee = feeP.load();
  feeP.free();
  return IntResult(res, fee);
}

Tx transactionBroadcastFromIsolate(SpendTx spendTx) {
  // as we are running this in an isolate we need to reinit a LibZap instance
  // to get the function pointer as closures can not be passed to isolates
  var libzap = LibZap();

  var spendTxC = spendTx.toBuffer();
  var txC = Tx.allocate();
  var result = libzap.lzapTransactionBroadcast(spendTxC, txC);
  Tx tx;
  if (result != 0)
    tx = Tx.fromCBuffer(txC.load());
  txC.free();
  spendTxC.free();
  return tx;
}

//
// LibZap class
//

class LibZap {

  LibZap() {
    libzap = dlopenPlatformSpecific("zap");
    lzapVersion = libzap
        .lookup<NativeFunction<lzap_version_native_t>>("lzap_version")
        .asFunction();
    lzapNetworkGet = libzap
        .lookup<NativeFunction<lzap_network_get_native_t>>("lzap_network_get")
        .asFunction();
    lzapNetworkSet = libzap
        .lookup<NativeFunction<lzap_network_set_native_t>>("lzap_network_set")
        .asFunction();
    lzapMnemonicCreate = libzap
        .lookup<NativeFunction<lzap_mnemonic_create_native_t>>("lzap_mnemonic_create")
        .asFunction();
    lzapMnemonicCheck = libzap
        .lookup<NativeFunction<lzap_mnemonic_check_native_t>>("lzap_mnemonic_check")
        .asFunction();
    lzapSeedAddress = libzap
        .lookup<NativeFunction<lzap_seed_address_native_t>>("lzap_seed_address")
        .asFunction();
    lzapAddressCheck = libzap
        .lookup<NativeFunction<lzap_address_check_ns_native_t>>("lzap_address_check_ns")
        .asFunction();
    lzapAddressBalance = libzap
        .lookup<NativeFunction<lzap_address_balance_ns_native_t>>("lzap_address_balance_ns")
        .asFunction();
    lzapAddressTransactions = libzap
        .lookup<NativeFunction<lzap_address_transactions2_ns_native_t>>("lzap_address_transactions2_ns")
        .asFunction();
    lzapTransactionFee = libzap
        .lookup<NativeFunction<lzap_transaction_fee_ns_native_t>>("lzap_transaction_fee_ns")
        .asFunction();
    lzapTransactionCreate = libzap
        .lookup<NativeFunction<lzap_transaction_create_ns_native_t>>("lzap_transaction_create_ns")
        .asFunction();
    lzapTransactionBroadcast = libzap
        .lookup<NativeFunction<lzap_transaction_broadcast_ns_native_t>>("lzap_transaction_broadcast_ns")
        .asFunction();
  }

  static const String TESTNET_ASSET_ID = "CgUrFtinLXEbJwJVjwwcppk4Vpz1nMmR3H5cQaDcUcfe";
  static const String MAINNET_ASSET_ID = "9R3iLi4qGLVWKc16Tg98gmRvgg1usGEYd7SgC1W5D6HB";

  DynamicLibrary libzap;
  lzap_version_t lzapVersion;
  lzap_network_get_t lzapNetworkGet;
  lzap_network_set_t lzapNetworkSet;
  lzap_mnemonic_create_t lzapMnemonicCreate;
  lzap_mnemonic_check_t lzapMnemonicCheck;
  lzap_seed_address_t lzapSeedAddress;
  lzap_address_check_ns_t lzapAddressCheck;
  lzap_address_balance_ns_t lzapAddressBalance;
  lzap_address_transactions2_ns_t lzapAddressTransactions;
  lzap_transaction_Fee_ns_t lzapTransactionFee;
  lzap_transaction_create_ns_t lzapTransactionCreate;
  lzap_transaction_broadcast_ns_t lzapTransactionBroadcast;

  static String paymentUri(bool testnet, String address, int amount) {
    var uri = "waves://$address?asset=${testnet ? TESTNET_ASSET_ID : MAINNET_ASSET_ID}";
    if (amount != null)
      uri += "&amount=$amount";
    return uri;
  }

  static String paymentUriDec(bool testnet, String address, Decimal amount) {
    if (amount != null && amount > Decimal.fromInt(0)) {
      amount = amount * Decimal.fromInt(100);
      var amountInt = amount.toInt();
      return paymentUri(testnet, address, amountInt);
    }
    return paymentUri(testnet, address, null);
  }

  //
  // native libzap wrapper functions
  //

  int version() {
    return lzapVersion();
  }

  bool testnetGet() {
    var networkByte = String.fromCharCode(lzapNetworkGet());
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
    return lzapNetworkSet(char) != 0;
  }

  String mnemonicCreate() {
    var mem = "0" * 1024;
    var outputC = Utf8.allocate(mem);
    var res = lzapMnemonicCreate(outputC, 1024);
    var mnemonic = outputC.load().toString();
    outputC.free();
    if (res != 0)
      return mnemonic;
    return null;
  }

  bool mnemonicCheck(String mnemonic) {
    var mnemonicC = Utf8.allocate(mnemonic);
    var res = lzapMnemonicCheck(mnemonicC) != 0;
    mnemonicC.free();
    return res;
  }

  String seedAddress(String seed) {
    var seedC = Utf8.allocate(seed);
    var mem = "0" * 1024;
    var outputC = Utf8.allocate(mem);
    lzapSeedAddress(seedC, outputC);
    var address = outputC.load().toString();
    outputC.free();
    seedC.free();
    return address;
  }

  bool addressCheck(String address) {
    var addrC = Utf8.allocate(address);
    var res = lzapAddressCheck(addrC) != 0;
    addrC.free();
    return res;
  }

  static Future<IntResult> addressBalance(String address) async {
    return compute(addressBalanceFromIsolate, address);
  }

  static Future<Iterable<Tx>> addressTransactions(String address, int count, String after) async {
    return compute(addressTransactionsFromIsolate, AddrTxsRequest(address, count, after));
  }

  static Future<IntResult> transactionFee() async {
    return compute(transactionFeeFromIsolate, null);
  }

  SpendTx transactionCreate(String seed, String recipient, int amount, int fee, String attachment) {
    var seedC = Utf8.allocate(seed);
    var recipientC = Utf8.allocate(recipient);
    Pointer<Utf8> attachmentC = Utf8.allocate("");
    if (attachment != null)
      attachmentC = Utf8.allocate(attachment);
    var outputC = SpendTx.allocate();
    lzapTransactionCreate(seedC, recipientC, amount, fee, attachmentC, outputC);
    var spendTx = SpendTx.fromCBuffer(outputC.load());
    outputC.free();
    attachmentC.free();
    recipientC.free();
    seedC.free();
    return spendTx;
  }

  static Future<Tx> transactionBroadcast(SpendTx spendTx) {
    return compute(transactionBroadcastFromIsolate, spendTx);
  }
}