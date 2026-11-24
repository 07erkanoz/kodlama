import 'package:atolye/model/sesli_konusma.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('kısa kapatma sözleri konuşmayı bitirir', () {
    for (final s in ['Kapat', 'tamam kapatabilirsin', 'Yeter!', 'Görüşürüz', 'sus artık', 'Dur.']) {
      expect(durdurmaSozu(s), isTrue, reason: s);
    }
  });
  test('uzun cümleler ve benzer kelimeler bitirmez', () {
    for (final s in [
      'projenin durumu ne',
      'şu dosyayı kapatmadan önce testleri çalıştır ve sonucu bana söyle lütfen',
      'merhaba',
      '',
    ]) {
      expect(durdurmaSozu(s), isFalse, reason: s);
    }
  });
}
