import 'package:atolye/arayuz/yanki/yanki_figur.dart';
import 'package:atolye/model/sesli_konusma.dart';
import 'package:atolye/servis/kopru_istemci.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final g in ['yanki', 'ag', 'dalga']) {
    testWidgets('$g figürü durumlarla çizilir', (t) async {
      final ses = SesliKonusma(
        KopruIstemci(port: 1, token: ''),
        'deneme',
        ajanCalisiyor: () => false,
      );
      await t.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 360,
            height: 140,
            child: YankiFiguru(ses: ses, gorunum: g),
          ),
        ),
      );
      for (final d in SesDurumu.values) {
        ses.durum = d;
        ses.seviye.value = d == SesDurumu.konusuyor ? .8 : .2;
        for (var i = 0; i < 5; i++) {
          await t.pump(const Duration(milliseconds: 16));
        }
      }
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  }
}
