import 'dart:io';

import 'package:atolye/arayuz/yerlesim.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ekran sınıfları Material 3 kırılımlarına göre', () {
    expect(ekranSinifi(390), EkranSinifi.dar); // telefon
    expect(ekranSinifi(673), EkranSinifi.orta); // açık katlanır telefon
    expect(ekranSinifi(800), EkranSinifi.orta); // küçük tablet dikey
    expect(ekranSinifi(1280), EkranSinifi.genis); // tablet yatay
  });

  test('uygulamadaki kurulum dosyaları köprü kaynağıyla aynı', () {
    for (final ad in ['kur.sh', 'atolye_kopru.py']) {
      expect(
        File('assets/kurulum/$ad').readAsStringSync(),
        File('../kopru/$ad').readAsStringSync(),
        reason: '$ad eşitlenmemiş: tool/esitle.sh çalıştır',
      );
    }
  });
}
