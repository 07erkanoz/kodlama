import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android bildirimleri ve ajan çalışırken açık kalan ön plan servisi
/// (MainActivity.kt, Bildirimler.kt). Android dışında hepsi sessizce "yok" döner.
abstract final class Bildirim {
  static const _kanal = MethodChannel('atolye/bildirim');

  static bool get destekleniyor =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<T?> _cagir<T>(String yontem, [Object? args]) async {
    if (!destekleniyor) return null;
    try {
      return await _kanal.invokeMethod<T>(yontem, args);
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  static Future<bool> izinVar() async => await _cagir<bool>('izinVar') ?? false;

  /// Android 13+ bildirim iznini sorar (daha önce verildiyse sormaz).
  static Future<bool> izinIste() async =>
      await _cagir<bool>('izinIste') ?? false;

  /// Ajan çalışırken kalıcı "çalışıyor" bildirimi ve ön plan servisi; çalışan
  /// kalmayınca kapatılır.
  static Future<void> servis({
    required bool calisiyor,
    String baslik = '',
    String metin = '',
    String? oturum,
    bool ilerleme = true,
    bool ses = false,
  }) => _cagir<void>('servis', {
    'calisiyor': calisiyor,
    'baslik': baslik,
    'metin': metin,
    'oturum': oturum,
    'ilerleme': ilerleme,
    'ses': ses,
  });

  /// Atölye pil kısıtlamasından muaf mı (Android'in arka planda öldürmemesi için).
  static Future<bool?> pilMuaf() => _cagir<bool>('pilMuaf');

  /// Sistemin "pil kısıtlamasını kaldır" sorusunu açar.
  static Future<void> pilIzniIste() => _cagir<void>('pilIzniIste');

  /// Termux'un uygulama ayarlarını açar (pil kullanımı: Kısıtlamasız).
  static Future<void> termuxPilAyari() => _cagir<void>('termuxPilAyari');

  static Future<void> goster({
    required int kimlik,
    required String baslik,
    required String metin,
    String? oturum,
    bool onemli = false,
  }) => _cagir<void>('goster', {
    'kimlik': kimlik,
    'baslik': baslik,
    'metin': metin,
    'oturum': oturum,
    'onemli': onemli,
  });

  static Future<void> iptal(int kimlik) =>
      _cagir<void>('iptal', {'kimlik': kimlik});

  /// Uygulama bir bildirime dokunularak açıldıysa o oturum (bir kez).
  static Future<String?> acilisOturumu() => _cagir<String>('acilisOturumu');

  /// Uygulama açıkken bir bildirime dokunulunca çağrılır.
  static void acilinca(void Function(String oturum) geri) {
    if (!destekleniyor) return;
    _kanal.setMethodCallHandler((cagri) async {
      if (cagri.method == 'acildi' && cagri.arguments is String) {
        geri(cagri.arguments as String);
      }
    });
  }
}
