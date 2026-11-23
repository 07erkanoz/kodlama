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
      if (yol.length == 2 &&
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

  /// Kullanıcının Termux'a yapıştıracağı tek satır.
  ///
  /// Yeni kurulmuş Termux'ta paket listesi eskidir: önce depo güncellenir ve
  /// paketler yükseltilir, yoksa `pkg install` hata verir. Yükseltme sırasında
  /// dpkg'nin "yapılandırma dosyası değişti" sorusunda takılmaması için
  /// sorusuz kip ve `--force-confnew` kullanılır.
  String komut({required String token, required List<String> ajanlar}) {
    final kaynak = 'http://127.0.0.1:$port/$_gizli';
    return 'export DEBIAN_FRONTEND=noninteractive; '
        'pkg update -y && '
        'apt-get -y -o Dpkg::Options::=--force-confnew full-upgrade && '
        'apt-get -y install curl && '
        'curl -fsS $kaynak/kur.sh | '
        'bash -s -- --kaynak $kaynak --token $token --ajan ${ajanlar.join(',')}';
  }
}
