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

  static bool get destekleniyor =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<bool> kurulu() async {
    if (!destekleniyor) return false;
    return await _kanal.invokeMethod<bool>('kurulu') ?? false;
  }

  /// Termux'u ön plana getirir.
  static Future<void> ac() async {
    if (destekleniyor) await _kanal.invokeMethod('ac');
  }

  static Future<bool> komutIzniVar() async {
    if (!destekleniyor) return false;
    return await _kanal.invokeMethod<bool>('izinVar') ?? false;
  }

  static Future<bool> komutIzniIste() async {
    if (!destekleniyor) return false;
    return await _kanal.invokeMethod<bool>('izinIste') ?? false;
  }

  /// Cihazın desteklediği işlemci mimarileri, en uygunu önce.
  static Future<List<String>> abiler() async {
    if (!destekleniyor) return const [];
    return ((await _kanal.invokeMethod<List>('abiler')) ?? const [])
        .cast<String>();
  }

  /// Atölye'nin başka uygulama kurdurma izni (Bilinmeyen uygulamalar) var mı.
  static Future<bool> kurulumIzniVar() async {
    if (!destekleniyor) return false;
    return await _kanal.invokeMethod<bool>('kurulumIzniVar') ?? false;
  }

  /// Sistem ayarlarında bu izni verme ekranını açar.
  static Future<void> kurulumIzniAc() => _kanal.invokeMethod('kurulumIzniAc');

  /// İndirilmiş APK için Android'in yükleme ekranını açar.
  static Future<void> apkKur(String yol) =>
      _kanal.invokeMethod('apkKur', {'yol': yol});

  /// Termux'ta bir komut çalıştırır. [arkaPlan] ise terminal açılmaz;
  /// değilse Termux'ta yeni bir oturum açılır (giriş adımları için).
  static Future<void> calistir(
    String yol, {
    List<String> args = const [],
    bool arkaPlan = true,
    String? klasor,
  }) async {
    if (!destekleniyor) return;
    await _kanal.invokeMethod('calistir', {
      'yol': yol,
      'args': args,
      'arkaPlan': arkaPlan,
      'klasor': klasor ?? ev,
    });
  }

  /// Köprüyü arka planda başlatır (zaten çalışıyorsa bir şey yapmaz).
  static Future<void> kopruyuBaslat() => calistir('$prefix/bin/atolye-kopru');

  /// Bir ajanın kendi giriş akışını Termux'ta açar.
  static Future<void> girisAc(String ajan) => calistir(
    '$prefix/bin/bash',
    args: [
      '-lc',
      ajan == 'codex'
          ? 'codex login; echo; read -p "Bitti. Atölye\'ye dönebilirsiniz. [Enter]"'
          : 'claude; echo; read -p "Bitti. Atölye\'ye dönebilirsiniz. [Enter]"',
    ],
    arkaPlan: false,
  );
}
