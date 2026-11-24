import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';

/// Kurulum sırasında kur.sh ve köprü dosyasını telefonun kendi içinden
/// (127.0.0.1) sunar. Termux bunları buradan indirir; hiçbir dış sunucuya
/// gerek kalmaz. Adres tahmin edilemeyen bir yol içerir ve kurulum ekranı
/// kapanınca sunucu durur.
class KurulumSunucusu {
  HttpServer? _sunucu;
  final String _gizli = _rastgele();

  /// Betiğe gömülen kurulum bilgisi: köprünün erişim anahtarı ve seçilen
  /// ajanlar. Kullanıcıya uzun bir komut yapıştırtmak yerine betik bunları
  /// kendisi taşır.
  String token = '';
  List<String> ajanlar = const [];

  int? get port => _sunucu?.port;

  static String _rastgele() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(16).toRadixString(16)).join();
  }

  Future<void> baslat() async {
    if (_sunucu != null) return;
    final sunucu = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _sunucu = sunucu;
    sunucu.listen((istek) async {
      final yol = istek.uri.pathSegments;
      final cevap = istek.response;
      if (yol.length == 1 && yol[0] == _gizli) {
        // Kısa komutun indirdiği betik: ilk satırı kurulum bilgisini verir.
        final betik = await rootBundle.loadString('assets/kurulum/kur.sh');
        final k = 'http://127.0.0.1:$port/$_gizli';
        cevap.headers.contentType = ContentType.text;
        cevap.write(
          "set -- --asama onyukleme --kaynak '$k' --token '$token' "
          "--ajan '${ajanlar.join(',')}'\n$betik",
        );
      } else if (yol.length == 2 &&
          yol[0] == _gizli &&
          const {
            'kur.sh',
            'atolye_kopru.py',
            'termux_rehberi.md',
          }.contains(yol[1])) {
        final veri = await rootBundle.load('assets/kurulum/${yol[1]}');
        cevap.headers.contentType = ContentType.text;
        cevap.add(veri.buffer.asUint8List());
      } else {
        cevap.statusCode = HttpStatus.notFound;
      }
      await cevap.close();
    });
  }

  Future<void> durdur() async {
    await _sunucu?.close(force: true);
    _sunucu = null;
  }

  /// Yalnız köprüyü (ve ajan rehberini) yenileyip köprüyü yeniden başlatır;
  /// paket kurmaz, saniyeler sürer.
  ///
  /// Eski köprü süreci `^python .*atolye_kopru` ile bulunur: bu kalıp komutu
  /// çalıştıran kabuğun kendi satırına uymaz (o "bash" ile başlar).
  String guncellemeKomutu() {
    final k = 'http://127.0.0.1:$port/$_gizli';
    const d = r'$HOME/.atolye/kopru';
    return 'mkdir -p "$d" && '
        'curl -fsS $k/atolye_kopru.py -o "$d/yeni.py" && '
        'mv -f "$d/yeni.py" "$d/atolye_kopru.py" && '
        'curl -fsS $k/termux_rehberi.md -o "$d/termux_rehberi.md"; '
        "pkill -f '^python .*atolye_kopru'; sleep 1; exec atolye-kopru";
  }

  /// Kullanıcının Termux'a yapıştıracağı tek, kısa satır. İndirdiği betik
  /// depoları günceller, Python'u ve köprüyü kurup başlatır, izni açar ve
  /// Atölye'ye geri döner; geri kalan her şey uygulamanın içinde yapılır.
  String komut({required String token, required List<String> ajanlar}) {
    this.token = token;
    this.ajanlar = ajanlar;
    return 'curl -fsS http://127.0.0.1:$port/$_gizli | bash';
  }
}
