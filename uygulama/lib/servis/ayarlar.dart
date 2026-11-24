import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Uygulamanın kendi ayarları: köprü erişim anahtarı, port, kurulumun durumu.
class Ayarlar {
  Ayarlar._(this._p);
  final SharedPreferences _p;

  static Future<Ayarlar> yukle() async =>
      Ayarlar._(await SharedPreferences.getInstance());

  /// Köprüye bağlanırken kullanılan anahtar. İlk açılışta üretilir ve
  /// kurulum komutuyla Termux'taki köprüye verilir.
  String get token {
    var t = _p.getString('token');
    if (t == null || t.isEmpty) {
      final r = Random.secure();
      const harfler =
          'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
      t = List.generate(32, (_) => harfler[r.nextInt(harfler.length)]).join();
      _p.setString('token', t);
    }
    return t;
  }

  set token(String v) => _p.setString('token', v);

  int get port => _p.getInt('port') ?? 8765;
  set port(int v) => _p.setInt('port', v);

  /// 'sistem', 'acik' ya da 'koyu'.
  String get tema => _p.getString('tema') ?? 'sistem';
  set tema(String v) => _p.setString('tema', v);

  /// Bildirim izni bir kez soruldu mu (Android 13+; reddedilirse tekrar sorulmaz).
  bool get bildirimIzniSoruldu => _p.getBool('bildirimIzniSoruldu') ?? false;
  set bildirimIzniSoruldu(bool v) => _p.setBool('bildirimIzniSoruldu', v);

  bool get kurulumBitti => _p.getBool('kurulumBitti') ?? false;
  set kurulumBitti(bool v) => _p.setBool('kurulumBitti', v);

  List<String> get ajanlar => _p.getStringList('ajanlar') ?? const ['claude'];
  set ajanlar(List<String> v) => _p.setStringList('ajanlar', v);
}
