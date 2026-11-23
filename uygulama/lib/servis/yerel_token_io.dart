import 'dart:io';

/// Masaüstünde köprü aynı bilgisayarda çalışıyorsa anahtarını
/// (~/.atolye/token) okur; geliştirirken elle yazmaya gerek kalmaz.
String? yerelKopruAnahtari() {
  final ev = Platform.environment['HOME'];
  if (ev == null) return null;
  final dosya = File('$ev/.atolye/token');
  try {
    return dosya.existsSync() ? dosya.readAsStringSync().trim() : null;
  } catch (_) {
    return null;
  }
}
