import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Panodaki resim (Android; MainActivity › Pano.kt). Flutter'ın kendi panosu
/// yalnızca metin okur.
abstract final class Pano {
  static const _kanal = MethodChannel('atolye/pano');

  static bool get destekleniyor =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Panoda resim varsa önbelleğe kopyalanmış hali; yoksa null.
  static Future<({String ad, String yol})?> resim() async {
    if (!destekleniyor) return null;
    try {
      final r = await _kanal.invokeMapMethod<String, Object?>('resim');
      if (r == null) return null;
      return (ad: '${r['ad']}', yol: '${r['yol']}');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}
