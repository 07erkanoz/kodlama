import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'termux.dart';

/// Termux'un resmi GitHub sürümünden cihazın mimarisine uygun APK'yı
/// indirir ve sürümle yayımlanan SHA-256 özetiyle doğrular. Kurulumu Android'in
/// kendi yükleme ekranı yapar; kullanıcı orada onaylar.
///
/// Not: GitHub ve F-Droid sürümleri farklı anahtarlarla imzalıdır; Termux
/// eklentileri (Termux:API gibi) aynı kaynaktan kurulmalıdır.
class TermuxIndirici {
  static const _surumAdresi =
      'https://api.github.com/repos/termux/termux-app/releases/latest';

  /// 0–1 arası indirme oranı; bilinmiyorsa ya da başlamadıysa null.
  final ilerleme = ValueNotifier<double?>(null);
  final durum = ValueNotifier<String>('');

  Future<Map<String, dynamic>> _json(HttpClient h, String adres) async {
    final istek = await h.getUrl(Uri.parse(adres));
    istek.headers
      ..set(HttpHeaders.userAgentHeader, 'Atolye')
      ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
    final yanit = await istek.close();
    if (yanit.statusCode != 200) {
      throw HttpException('GitHub yanıtı ${yanit.statusCode}');
    }
    return jsonDecode(await yanit.transform(utf8.decoder).join())
        as Map<String, dynamic>;
  }

  Future<String> _metin(HttpClient h, String adres) async {
    final istek = await h.getUrl(Uri.parse(adres));
    istek.headers.set(HttpHeaders.userAgentHeader, 'Atolye');
    final yanit = await istek.close();
    if (yanit.statusCode != 200) {
      throw HttpException('indirilemedi (${yanit.statusCode})');
    }
    return yanit.transform(utf8.decoder).join();
  }

  /// İndirir, doğrular ve APK'nın yolunu döndürür.
  Future<String> indir() async {
    final h = HttpClient()..connectionTimeout = const Duration(seconds: 20);
    try {
      durum.value = 'Sürüm bilgisi alınıyor…';
      ilerleme.value = null;
      final surum = await _json(h, _surumAdresi);
      final varliklar = (surum['assets'] as List).cast<Map<String, dynamic>>();

      final abiler = await Termux.abiler();
      Map<String, dynamic>? apk;
      for (final abi in abiler) {
        apk = varliklar
            .where((v) => (v['name'] as String).endsWith('_$abi.apk'))
            .firstOrNull;
        if (apk != null) break;
      }
      apk ??= varliklar
          .where((v) => (v['name'] as String).endsWith('_universal.apk'))
          .firstOrNull;
      if (apk == null) throw StateError('bu cihaza uygun Termux APK\'sı yok');
      final ad = apk['name'] as String;

      // sürümle yayımlanan özet dosyası: "<sha256>  <dosya adı>"
      String? beklenen;
      final ozet = varliklar
          .where((v) => (v['name'] as String).endsWith('_sha256sums'))
          .firstOrNull;
      if (ozet != null) {
        final satirlar = await _metin(
          h,
          ozet['browser_download_url'] as String,
        );
        for (final s in const LineSplitter().convert(satirlar)) {
          final p = s.trim().split(RegExp(r'\s+'));
          if (p.length == 2 && p[1].replaceFirst('*', '') == ad) {
            beklenen = p[0];
          }
        }
      }

      final klasor = Directory(
        '${(await getTemporaryDirectory()).path}/termux',
      );
      await klasor.create(recursive: true);
      final hedef = File('${klasor.path}/$ad');

      durum.value = '${surum['tag_name']} indiriliyor…';
      final istek = await h.getUrl(
        Uri.parse(apk['browser_download_url'] as String),
      );
      istek.headers.set(HttpHeaders.userAgentHeader, 'Atolye');
      final yanit = await istek.close();
      if (yanit.statusCode != 200) {
        throw HttpException('indirilemedi (${yanit.statusCode})');
      }
      final toplam = yanit.contentLength > 0
          ? yanit.contentLength
          : (apk['size'] as int? ?? 0);
      final yazici = hedef.openWrite();
      final ozetci = AccumulatorSink<Digest>();
      final sha = sha256.startChunkedConversion(ozetci);
      var gelen = 0;
      await for (final parca in yanit) {
        yazici.add(parca);
        sha.add(parca);
        gelen += parca.length;
        if (toplam > 0) ilerleme.value = gelen / toplam;
      }
      await yazici.close();
      sha.close();

      final bulunan = ozetci.events.single.toString();
      if (beklenen != null && bulunan != beklenen) {
        await hedef.delete();
        throw StateError('indirilen dosya doğrulanamadı (SHA-256 eşleşmedi)');
      }
      durum.value = beklenen != null
          ? 'İndirildi ve doğrulandı.'
          : 'İndirildi.';
      ilerleme.value = 1;
      return hedef.path;
    } finally {
      h.close();
    }
  }
}

/// crypto paketinin özet toplayıcısı (convert'in AccumulatorSink'i yerine
/// bağımlılık eklememek için küçük bir eşdeğer).
class AccumulatorSink<T> implements Sink<T> {
  final events = <T>[];
  @override
  void add(T event) => events.add(event);
  @override
  void close() {}
}
