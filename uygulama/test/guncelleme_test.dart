import 'package:atolye/servis/guncelleme.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> _surum(
  String etiket, {
  bool apk = true,
  bool taslak = false,
}) => {
  'tag_name': etiket,
  'name': 'Atölye APK ${etiket.split('-').last}',
  'draft': taslak,
  'published_at': '2026-11-25T07:17:23Z',
  'body': 'arm64',
  'assets': [
    if (apk)
      {
        'name': 'atolye-arm64.apk',
        'size': 108166984,
        'digest': 'sha256:ABCDEF',
        'browser_download_url':
            'https://github.com/o/r/releases/download/$etiket/atolye-arm64.apk',
      },
  ],
};

void main() {
  test('yalnız APK\'lı apk-N sürümleri, yeniden eskiye', () {
    final s = surumleriAyikla([
      _surum('apk-21'),
      _surum('apk-23'),
      _surum('v1.0'),
      _surum('apk-24', apk: false),
      _surum('apk-25', taslak: true),
      _surum('apk-22'),
    ]);
    expect(s.map((x) => x.numara), [23, 22, 21]);
    expect(s.first.kod, 123); // iş akışı: --build-number 100+N
    expect(s.first.sha256, 'abcdef');
    expect(s.first.ad, 'Atölye APK 23');
  });

  test('kurulu sürümden yeni olan bulunur', () {
    final s = surumleriAyikla([_surum('apk-23'), _surum('apk-22')]);
    expect(yeniSurumuBul(s, 122)?.numara, 23);
    expect(yeniSurumuBul(s, 123), isNull);
    expect(yeniSurumuBul(s, 200), isNull);
  });
}
