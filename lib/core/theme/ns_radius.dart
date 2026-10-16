import 'package:flutter/material.dart';

/// Token radius sudut komponen sesuai `desain.md` Bab 3.2.
abstract final class NsRadius {
  static const double chipValue = 10.0;
  static const double controlValue = 11.0;
  static const double cardValue = 15.0;
  static const double sheetValue = 22.0;

  static const BorderRadius chip = BorderRadius.all(Radius.circular(chipValue));
  static const BorderRadius control = BorderRadius.all(Radius.circular(controlValue));
  static const BorderRadius card = BorderRadius.all(Radius.circular(cardValue));
  static const BorderRadius sheetTop = BorderRadius.vertical(
    top: Radius.circular(sheetValue),
  );
}
