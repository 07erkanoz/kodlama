import 'package:atolye/model/calisma.dart';
import 'package:atolye/model/widget_yoneticisi.dart';
import 'package:atolye/servis/ayarlar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Calisma c;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'widgetSaydamlik': 40,
      'widgetTema': 'duvar',
    });
    c = Calisma(await Ayarlar.yukle());
    c.oturumlar = [
      {
        'id': 'a',
        'ajan': 'claude',
        'baslik': 'Eski iş',
        'durum': 'bos',
        'guncelleme': 100,
      },
      {
        'id': 'b',
        'ajan': 'codex',
        'baslik': '',
        'goreli': 'Ofis:/srv',
        'durum': 'bos',
        'guncelleme': 300,
      },
      {
        'id': 'c',
        'ajan': 'claude',
        'baslik': 'Çalışan',
        'durum': 'calisiyor',
        'guncelleme': 50,
      },
      {
        'id': 'd',
        'ajan': 'claude',
        'baslik': 'Yankı',
        'durum': 'bos',
        'asistan': true,
        'guncelleme': 999,
      },
    ];
    c.kotalar = {
      'claude': [
        {'ad': '5 saat', 'kullanim': 30, 'sifirlanma': 1000},
        {'ad': 'Hafta', 'kullanim': 62, 'sifirlanma': 2000},
      ],
    };
  });

  test('sıralama: onay bekleyen, çalışan, sonra en yeni; asistan yok', () {
    final o = WidgetYoneticisi.ozet(c, {
      'a': [
        {'rid': 'r1', 'arac': 'Bash', 'ozet': 'npm install'},
        {'rid': 'r2'},
      ],
    });
    final ids = [for (final x in o['oturumlar'] as List) x['id']];
    expect(ids, ['a', 'c', 'b']);
    expect(o['calisan'], 1);
    expect(o['onaySayisi'], 2);
    final onay = o['onay'] as Map;
    expect(onay['oturum'], 'a');
    expect(onay['rid'], 'r1');
    expect(onay['metin'], 'Bash: npm install');
    expect(onay['ajanAdi'], 'Claude');
  });

  test('başlık boşsa konum; kota en dolu pencere; ayarlar gider', () {
    final o = WidgetYoneticisi.ozet(c, const {});
    final b = (o['oturumlar'] as List).firstWhere((x) => x['id'] == 'b');
    expect(b['baslik'], 'Ofis:/srv');
    expect(b['ajanAdi'], 'Codex');
    expect(o['onay'], isNull);
    expect((o['kota'] as Map)['claude'], {'yuzde': 62, 'sifirlanma': 2000});
    expect((o['kota'] as Map).containsKey('codex'), isFalse);
    final ayar = o['ayar'] as Map;
    expect(ayar['saydamlik'], 40);
    expect(ayar['tema'], 'duvar');
    expect(ayar['oturum'], 0);
    expect(o['bagli'], isFalse);
  });
}
