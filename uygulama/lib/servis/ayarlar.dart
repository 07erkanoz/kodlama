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

  /// Geniş ekranlarda (tablet, açık katlanır) yan panellerin açık/kapalı hali.
  bool get kenarCubugu => _p.getBool('kenarCubugu') ?? true;
  set kenarCubugu(bool v) => _p.setBool('kenarCubugu', v);
  bool get dosyaPaneli => _p.getBool('dosyaPaneli') ?? true;
  set dosyaPaneli(bool v) => _p.setBool('dosyaPaneli', v);

  /// Codex sesli konuşma: ses (boşsa Codex'in varsayılanı), dil ('tr', 'en'
  /// ya da '' = kullanıcının dili), realtime modeli (boşsa Codex'in ayarı).
  String get sesSesi => _p.getString('sesSesi') ?? '';
  set sesSesi(String v) => _p.setString('sesSesi', v);
  String get sesDili => _p.getString('sesDili') ?? 'tr';
  set sesDili(String v) => _p.setString('sesDili', v);

  /// Sesli konuşmanın görünümü: 'sade' ya da Yankı'nın figürleri
  /// ('yanki', 'ag', 'dalga').
  String get sesGorunumu => _p.getString('sesGorunumu') ?? 'yanki';
  set sesGorunumu(String v) => _p.setString('sesGorunumu', v);

  /// Yankı modu son seçimleri: yeni Yankı ve Asistan oturumları bunlarla
  /// başlar. İşi yapan 'claude' ya da 'codex'.
  bool get yanki => _p.getBool('yanki') ?? false;
  set yanki(bool v) => _p.setBool('yanki', v);
  String get yankiIsci => _p.getString('yankiIsci') ?? 'claude';
  set yankiIsci(String v) => _p.setString('yankiIsci', v);
  String? get yankiClaudeModel => _bos(_p.getString('yankiClaudeModel'));
  set yankiClaudeModel(String? v) => _p.setString('yankiClaudeModel', v ?? '');
  String? get yankiClaudeEffort => _bos(_p.getString('yankiClaudeEffort'));
  set yankiClaudeEffort(String? v) =>
      _p.setString('yankiClaudeEffort', v ?? '');
  String? get yankiCodexModel => _bos(_p.getString('yankiCodexModel'));
  set yankiCodexModel(String? v) => _p.setString('yankiCodexModel', v ?? '');
  String? get yankiCodexEffort => _bos(_p.getString('yankiCodexEffort'));
  set yankiCodexEffort(String? v) => _p.setString('yankiCodexEffort', v ?? '');

  /// Yazılı mesajları kim yanıtlar ('codex' ya da 'claude') ve modeli.
  String get yankiYazili => _p.getString('yankiYazili') ?? 'codex';
  set yankiYazili(String v) => _p.setString('yankiYazili', v);
  String? get yankiYaziliModel => _bos(_p.getString('yankiYaziliModel'));
  set yankiYaziliModel(String? v) => _p.setString('yankiYaziliModel', v ?? '');
  String? get yankiYaziliEffort => _bos(_p.getString('yankiYaziliEffort'));
  set yankiYaziliEffort(String? v) =>
      _p.setString('yankiYaziliEffort', v ?? '');

  /// Ses açıkken Claude'un durumu sese: 'kapali', 'onemli', 'hepsi'.
  String get yankiDurumNotu => _p.getString('yankiDurumNotu') ?? 'onemli';
  set yankiDurumNotu(String v) => _p.setString('yankiDurumNotu', v);

  /// Yankı ve Asistan'ın son seçilen cihazı (kayıtlı sunucu adı).
  String? get yankiCihaz => _bos(_p.getString('yankiCihaz'));
  set yankiCihaz(String? v) => _p.setString('yankiCihaz', v ?? '');

  /// Her sunucuda en son seçilen klasör (yeni oturumların varsayılanı).
  String? sonUzakKlasor(String sunucu) =>
      _bos(_p.getString('uzakKlasor:$sunucu'));
  void sonUzakKlasorYaz(String sunucu, String yol) =>
      _p.setString('uzakKlasor:$sunucu', yol);

  static String? _bos(String? v) => v == null || v.isEmpty ? null : v;

  /// Sesli konuşma (Yankı görünümünde) doğrudan tam ekran açılsın mı.
  bool get sesTamEkran => _p.getBool('sesTamEkran') ?? true;
  set sesTamEkran(bool v) => _p.setBool('sesTamEkran', v);

  String get sesModeli => _p.getString('sesModeli') ?? '';
  set sesModeli(String v) => _p.setString('sesModeli', v);

  bool get kurulumBitti => _p.getBool('kurulumBitti') ?? false;
  set kurulumBitti(bool v) => _p.setBool('kurulumBitti', v);

  List<String> get ajanlar => _p.getStringList('ajanlar') ?? const ['claude'];
  set ajanlar(List<String> v) => _p.setStringList('ajanlar', v);
}
