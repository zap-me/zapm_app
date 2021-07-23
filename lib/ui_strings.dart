import 'config.dart';

extension CapExtension on String {
  String get capitalizeFirst =>
      this.length > 0 ? '${this[0].toUpperCase()}${this.substring(1)}' : '';
  String get capitalizeAll => this
      .replaceAll(RegExp(' +'), ' ')
      .split(' ')
      .map((str) => str.capitalizeFirst)
      .join(' ');
}

String capAll(String input) {
  if (!UseCapitalizeAllWords) return input;
  return input.capitalizeAll;
}

String capFirst(String input) {
  if (!UseCapitalizeFirstWord) return input;
  return input.capitalizeFirst;
}

String capAsset(String input) {
  if (!UseCapitalizeAsset) return input;
  return input.toUpperCase();
}
