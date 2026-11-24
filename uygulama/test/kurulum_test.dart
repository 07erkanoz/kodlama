import 'dart:io';

import 'package:atolye/model/kurulum.dart';
import 'package:atolye/servis/kurulum_sunucusu.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('kurulum olayları adımları ve sonucu biriktirir', () {
    final k = KurulumDurumu();
    k.isle({
      'tur': 'basladi',
      'ajanlar': ['claude'],
      'asama': 'paketler',
    });
    expect(k.calisiyor, isTrue);
    k.isle({'tur': 'adim', 'metin': 'Depo tazeleniyor'});
    k.isle({'tur': 'satir', 'metin': 'bir çıktı'});
    k.isle({'tur': 'adim', 'metin': 'Claude kuruluyor'});
    k.isle({'tur': 'uyari', 'metin': 'kurulamadı'});
    k.isle({'tur': 'bitti', 'kod': 3});
    expect(k.adimlar, ['Depo tazeleniyor', 'Claude kuruluyor']);
    expect(k.adim, 'Claude kuruluyor');
    expect(k.calisiyor, isFalse);
    expect(k.basarisiz, isTrue);
    expect(k.basarili, isFalse);
    expect(k.satirlar.last.tur, 'uyari');
  });

  test('kurulum yeniden başlayınca eski durum silinir; çıkış 0 başarıdır', () {
    final k = KurulumDurumu();
    k.isle({'tur': 'basladi', 'ajanlar': [], 'asama': 'paketler'});
    k.isle({'tur': 'adim', 'metin': 'a'});
    k.isle({'tur': 'bitti', 'kod': 1});
    k.isle({'tur': 'basladi', 'ajanlar': [], 'asama': 'paketler'});
    expect(k.adimlar, isEmpty);
    expect(k.bitti, isFalse);
    k.isle({'tur': 'bitti', 'kod': 0});
    expect(k.basarili, isTrue);
  });

  test('satır sayısı sınırlıdır', () {
    final k = KurulumDurumu();
    for (var i = 0; i < 1000; i++) {
      k.isle({'tur': 'satir', 'metin': 'satır $i'});
    }
    expect(k.satirlar.length, KurulumDurumu.enFazlaSatir);
    expect(k.satirlar.last.metin, 'satır 999');
  });

  test('kur_durum yanıtından yüklenir', () {
    final k = KurulumDurumu();
    k.yukle({
      'var': true,
      'calisiyor': true,
      'bitti': false,
      'adim': 'x',
      'adimlar': ['x'],
      'satirlar': [
        {'tur': 'adim', 'metin': 'x'},
      ],
      'ajanlar': ['codex'],
      'asama': 'paketler',
    });
    expect(k.calisiyor, isTrue);
    expect(k.satirlar.single.metin, 'x');
    final bos = KurulumDurumu()..yukle({'var': false});
    expect(bos.basladi, isFalse);
  });

  test('giriş olayları yalnız ilgili ajanı etkiler', () {
    final g = GirisDurumu()..baslat('codex');
    g.isle({'tur': 'url', 'ajan': 'claude', 'url': 'https://yanlis'});
    expect(g.url, isNull);
    g.isle({
      'tur': 'url',
      'ajan': 'codex',
      'url': 'https://auth.openai.com/codex/device',
    });
    g.isle({'tur': 'kod', 'ajan': 'codex', 'kod': '071R-GDGW1'});
    expect(g.url, contains('openai.com'));
    expect(g.kod, '071R-GDGW1');
    g.isle({'tur': 'bitti', 'ajan': 'codex', 'basarili': true});
    expect(g.basarili, isTrue);
    expect(g.calisiyor, isFalse);
  });

  test('başarısız giriş nedenini taşır', () {
    final g = GirisDurumu()..baslat('claude');
    g.isle({
      'tur': 'bitti',
      'ajan': 'claude',
      'basarili': false,
      'hata': 'Süre doldu.',
    });
    expect(g.basarili, isFalse);
    expect(g.hata, 'Süre doldu.');
  });

  test('kısa komut ve kişiselleştirilmiş betik', () async {
    HttpOverrides.global =
        null; // flutter test gerçek HTTP'yi varsayılan olarak engeller
    final s = KurulumSunucusu();
    await s.baslat();
    addTearDown(s.durdur);
    final komut = s.komut(token: 'TOK123', ajanlar: ['claude', 'codex']);
    final eslesme = RegExp(
      r'^curl -fsS (http://127\.0\.0\.1:\d+/[0-9a-f]{16}) \| bash$',
    ).firstMatch(komut);
    expect(eslesme, isNotNull, reason: komut);
    expect(komut.length, lessThan(70));

    final istemci = HttpClient();
    addTearDown(istemci.close);
    final yanit = await (await istemci.getUrl(Uri.parse(eslesme!.group(1)!)))
        .close();
    expect(yanit.statusCode, 200);
    final betik = await yanit.transform(const SystemEncoding().decoder).join();
    final ilkSatir = betik.split('\n').first;
    expect(
      ilkSatir,
      "set -- --asama onyukleme --kaynak '${eslesme.group(1)}' --token 'TOK123' --ajan 'claude,codex'",
    );
    expect(betik, contains('faz_onyukleme'));

    // Yanlış gizli yol 404 verir.
    final yanlis = await (await istemci.getUrl(
      Uri.parse('http://127.0.0.1:${s.port}/0000000000000000'),
    )).close();
    expect(yanlis.statusCode, 404);
  });
}
