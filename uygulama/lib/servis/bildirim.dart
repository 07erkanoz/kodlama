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

    /// Verilirse bildirimde "İzin ver / Bu oturumda hep / Reddet" düğmeleri olur.
    String? rid,
  }) => _cagir<void>('goster', {
    'kimlik': kimlik,
    'baslik': baslik,
    'metin': metin,
    'oturum': oturum,
    'onemli': onemli,
    'rid': rid,
  });

  static Future<void> iptal(int kimlik) =>
      _cagir<void>('iptal', {'kimlik': kimlik});

  /// Uygulama "Konuş" kısayoluyla açıldıysa true (bir kez).
  static Future<bool> acilisSes() async =>
      await _cagir<bool>('acilisSes') ?? false;

  /// Uygulama bir bildirime dokunularak açıldıysa o oturum (bir kez).
  static Future<String?> acilisOturumu() => _cagir<String>('acilisOturumu');

  /// Uygulama bir widget düğmesiyle açıldıysa: 'yeni', 'ara' ya da
  /// 'widgetAyar' (bir kez).
  static Future<String?> acilisEylem() => _cagir<String>('acilisEylem');

  /// Ana ekran widget'ının göstereceği anlık durum (AtolyeWidget.kt okur).
  static Future<void> widget(String json) =>
      _cagir<void>('widget', {'json': json});

  /// Ana ekranda en az bir Atölye widget'ı var mı.
  static Future<bool> widgetVar() async =>
      await _cagir<bool>('widgetVar') ?? false;

  /// Başlatıcının "ana ekrana ekle" sorusunu açar; desteklenmiyorsa false.
  static Future<bool> widgetEkle({bool buyuk = false}) async =>
      await _cagir<bool>('widgetEkle', {'buyuk': buyuk}) ?? false;

  /// Uygulama açıkken bir bildirime dokunulunca [acildi], onay bildirimindeki
  /// bir düğmeye basılınca [karar], widget düğmelerinde [eylem] ('yeni',
  /// 'ara', 'widgetAyar', 'widgetYenile') çağrılır.
  static void dinle({
    required void Function(String oturum) acildi,
    required void Function(String oturum, String rid, String karar) karar,
    required void Function() ses,
    required void Function(String eylem) eylem,
  }) {
    if (!destekleniyor) return;
    _kanal.setMethodCallHandler((cagri) async {
      final a = cagri.arguments;
      if (cagri.method == 'acildi' && a is String) {
        acildi(a);
      } else if (cagri.method == 'karar' && a is Map) {
        karar('${a['oturum']}', '${a['rid']}', '${a['karar']}');
      } else if (cagri.method == 'ses') {
        ses();
      } else if (cagri.method == 'eylem' && a is String) {
        eylem(a);
      } else if (cagri.method == 'widgetYenile') {
        eylem('widgetYenile');
      }
    });
  }
}
