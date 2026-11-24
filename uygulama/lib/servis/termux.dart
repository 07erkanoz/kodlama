import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Android tarafındaki Termux köprüsü (MainActivity.kt).
///
/// Termux ayrı bir uygulamadır; Atölye onu yalnızca bulur, açar ve
/// kullanıcının izin verdiği `RUN_COMMAND` ile içinde komut çalıştırır.
/// Android dışında (masaüstü, web) hepsi "yok" döner.
abstract final class Termux {
  static const _kanal = MethodChannel('atolye/termux');

  static const prefix = '/data/data/com.termux/files/usr';
  static const ev = '/data/data/com.termux/files/home';

  static const fdroidAdresi = 'https://f-droid.org/packages/com.termux/';
  static const githubAdresi =
      'https://github.com/termux/termux-app/releases/latest';

  /// Geliştirme: masaüstünde ya da web'de Termux'a özgü arayüzleri göstermek için
  /// `--dart-define=ATOLYE_TERMUX_DENE=true`. Android kanalı olmadığı için
  /// çağrılar sessizce "yok" döner; köprü işlemleri (kurulum, giriş) yine çalışır.
  static const _dene = bool.fromEnvironment('ATOLYE_TERMUX_DENE');

  static bool get destekleniyor =>
      _dene || (!kIsWeb && defaultTargetPlatform == TargetPlatform.android);

  /// Kanal çağrısı; kanal yoksa (Android dışı) null döner.
  static Future<T?> _cagir<T>(String yontem, [Object? args]) async {
    try {
      return await _kanal.invokeMethod<T>(yontem, args);
    } on MissingPluginException {
      return null;
    }
  }

  static Future<bool> kurulu() async {
    if (!destekleniyor) return false;
    return await _cagir<bool>('kurulu') ?? false;
  }

  /// Termux'u ön plana getirir.
  static Future<void> ac() async {
    if (destekleniyor) await _cagir<void>('ac');
  }

  static Future<bool> komutIzniVar() async {
    if (!destekleniyor) return false;
    return await _cagir<bool>('izinVar') ?? false;
  }

  static Future<bool> komutIzniIste() async {
    if (!destekleniyor) return false;
    return await _cagir<bool>('izinIste') ?? false;
  }

  /// Cihazın desteklediği işlemci mimarileri, en uygunu önce.
  static Future<List<String>> abiler() async {
    if (!destekleniyor) return const [];
    return ((await _cagir<List>('abiler')) ?? const []).cast<String>();
  }

  /// Atölye'nin başka uygulama kurdurma izni (Bilinmeyen uygulamalar) var mı.
  static Future<bool> kurulumIzniVar() async {
    if (!destekleniyor) return false;
    return await _cagir<bool>('kurulumIzniVar') ?? false;
  }

  /// Sistem ayarlarında bu izni verme ekranını açar.
  static Future<void> kurulumIzniAc() => _cagir<void>('kurulumIzniAc');

  /// Termux'un "Uygulama bilgisi" ekranını açar (pil kısıtlamasını kaldırmak için).
  static Future<void> termuxAyarlariniAc() async {
    if (destekleniyor) await _cagir<void>('termuxAyarlari');
  }

  /// İndirilmiş APK için Android'in yükleme ekranını açar.
  static Future<void> apkKur(String yol) =>
      _cagir<void>('apkKur', {'yol': yol});

  /// Termux'ta bir komut çalıştırır. [arkaPlan] ise terminal açılmaz;
  /// değilse Termux'ta yeni bir oturum açılır (giriş adımları için).
  static Future<void> calistir(
    String yol, {
    List<String> args = const [],
    bool arkaPlan = true,
    String? klasor,
  }) async {
    if (!destekleniyor) return;
    await _cagir<void>('calistir', {
      'yol': yol,
      'args': args,
      'arkaPlan': arkaPlan,
      'klasor': klasor ?? ev,
    });
  }

  /// Köprüyü arka planda başlatır (zaten çalışıyorsa bir şey yapmaz).
  static Future<void> kopruyuBaslat() => calistir('$prefix/bin/atolye-kopru');

  /// Komutu Termux'ta yeni bir terminal oturumunda çalıştırır ve Termux'u
  /// öne getirir. Android 10 ve sonrasında Termux arka plandan açılan oturumu
  /// kendisi ekrana getiremez (bunun için "diğer uygulamaların üzerinde
  /// göster" izni ister); bu yüzden Termux'u Atölye açar.
  ///
  /// Komut izni yoksa ya da gönderilemezse komutu panoya kopyalar, Termux'u
  /// açar ve false döner: kullanıcı yapıştırıp Enter'a basar.
  static Future<bool> terminaldeAc(String komut) async {
    // Termux, allow-external-apps kapalıysa komutu sessizce reddeder ve bunu
    // buradan anlayamayız: komut her durumda panoda da dursun.
    await Clipboard.setData(ClipboardData(text: komut));
    if (!destekleniyor) return false;
    if (await komutIzniVar()) {
      try {
        await calistir(
          '$prefix/bin/bash',
          args: [
            '-lc',
            '$komut; echo; read -p "Bitti. Atölye\'ye dönebilirsin. [Enter]"',
          ],
          arkaPlan: false,
        );
        await Future<void>.delayed(const Duration(milliseconds: 400));
        await ac();
        return true;
      } catch (_) {
        // aşağıda kopyala-yapıştır yoluna düş
      }
    }
    await ac();
    return false;
  }

  static String girisKomutu(String ajan) =>
      ajan == 'codex' ? 'codex login --device-auth' : 'claude';

  /// Bir ajanın kendi giriş akışını Termux'ta açar.
  static Future<bool> girisAc(String ajan) => terminaldeAc(girisKomutu(ajan));
}
