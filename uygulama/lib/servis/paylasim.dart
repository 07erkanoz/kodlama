import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android'in paylaş menüsünden gelen: metin ve uygulamanın önbelleğine
/// kopyalanmış dosyalar (MainActivity › Paylasim.kt).
class Paylasim {
  const Paylasim(this.metin, this.dosyalar);
  final String metin;
  final List<({String ad, String yol, int boyut})> dosyalar;

  bool get bos => metin.trim().isEmpty && dosyalar.isEmpty;

  static Paylasim? _coz(Object? ham) {
    if (ham is! Map) return null;
    final p = Paylasim(
      (ham['metin'] as String?) ?? '',
      [
        for (final d in (ham['dosyalar'] as List?) ?? const [])
          if (d is Map)
            (
              ad: '${d['ad']}',
              yol: '${d['yol']}',
              boyut: (d['boyut'] as num?)?.toInt() ?? 0,
            ),
      ],
    );
    return p.bos ? null : p;
  }

  static const _kanal = MethodChannel('atolye/paylas');

  static bool get destekleniyor =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Uygulama bir paylaşımla açıldıysa onu (bir kez) döner; sonra gelenleri
  /// [gelince] ile bildirir.
  static Future<Paylasim?> dinle(void Function(Paylasim) gelince) async {
    if (!destekleniyor) return null;
    _kanal.setMethodCallHandler((c) async {
      if (c.method == 'paylasildi') {
        final p = _coz(c.arguments);
        if (p != null) gelince(p);
      }
    });
    try {
      return _coz(await _kanal.invokeMethod<Object?>('acilisPaylasimi'));
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
