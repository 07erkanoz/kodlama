import 'dart:async';
import 'dart:io';

/// Geliştirme sunucularının sık kullandığı portlar (Vite, Next, Angular,
/// Flask, Django, Hugo, Expo, http.server…).
const yayginPortlar = [
  3000,
  3001,
  4000,
  4173,
  4200,
  4321,
  5000,
  5001,
  5173,
  5174,
  5500,
  8000,
  8001,
  8008,
  8080,
  8081,
  8100,
  8888,
  9000,
  1313,
  19006,
];

/// Bu cihazda (127.0.0.1) dinleyen geliştirme sunucuları. Android 10+ başka
/// uygulamaların soketlerini listelemeye izin vermez; bu yüzden yaygın
/// portlara kısa bağlantı denenir.
Future<List<int>> yerelSunuculariTara({Set<int> haric = const {}}) async {
  final sonuc = await Future.wait([
    for (final p in yayginPortlar)
      if (!haric.contains(p)) _dene(p),
  ]);
  return [for (final p in sonuc) ?p]..sort();
}

Future<int?> _dene(int port) async {
  try {
    final s = await Socket.connect(
      InternetAddress.loopbackIPv4,
      port,
      timeout: const Duration(milliseconds: 400),
    );
    s.destroy();
    return port;
  } catch (_) {
    return null;
  }
}
