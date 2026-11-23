import 'package:flutter/foundation.dart';

/// Web'de Termux indirilemez.
class TermuxIndirici {
  final ilerleme = ValueNotifier<double?>(null);
  final durum = ValueNotifier<String>('');
  Future<String> indir() async => throw UnsupportedError('yalnız Android');
}
