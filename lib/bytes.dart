import "dart:ffi";

/// Represents an array of bytes in C memory, managed by an [Arena].
class CBuffer extends Struct<CBuffer> {
  @Uint8()
  int byte;

  /// Allocate a [CBuffer] not managed in an [Arena].
  ///
  /// This [CBuffer] is not managed by an [Arena]. Please ensure to [free] the
  /// memory manually!
  static Pointer<CBuffer> allocate(int size) {
    Pointer<CBuffer> buf = Pointer.allocate(count: size);
    for (int i = 0; i < size; ++i) {
      buf.elementAt(i).load<CBuffer>().byte = 0;
    }
    return buf.cast();
  }

  /// Read the buffer for C memory into Dart.
  List<int> toIntList(int len) {
    final buf = addressOf;
    if (buf == nullptr) return null;
    List<int> units = List(len);
    for (int i = 0; i < len; ++i)
      units[i] = buf.elementAt(i).load<CBuffer>().byte;
    return units;
  }

  /// Copy a list of ints into the C memory
  void copyInto(int offset, Iterable<int> data) {
    final buf = addressOf;
    assert(buf != nullptr);
    var n = 0;
    for (byte in data)
      buf.elementAt(offset + n++).load<CBuffer>().byte = byte;
  }
}