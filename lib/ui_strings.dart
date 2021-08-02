import 'package:flutter/material.dart';

import 'config.dart';

enum DimensionClass { Small, Med, Large }

class ScreenSizeClass {
  final DimensionClass width;
  final DimensionClass height;
  final double pixWidth;
  final double pixHeight;

  ScreenSizeClass(this.width, this.height, this.pixWidth, this.pixHeight);

  static ScreenSizeClass calc(BuildContext context) {
    var w = DimensionClass.Small;
    var h = DimensionClass.Small;
    var size = MediaQuery.of(context).size;
    if (size.width > 350) w = DimensionClass.Med;
    if (size.width > 400) w = DimensionClass.Large;
    if (size.height > 700) h = DimensionClass.Med;
    if (size.height > 800) h = DimensionClass.Large;
    return ScreenSizeClass(w, h, size.width, size.height);
  }
}

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
