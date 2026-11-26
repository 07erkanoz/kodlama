import 'package:flutter/foundation.dart';

import 'guncelleme_stub.dart' if (dart.library.io) 'guncelleme_io.dart' as ag;
import 'termux.dart';

/// Atölye'nin yayımlandığı depo. `.github/workflows/apk.yml` main'e her
/// gönderimde `apk-<N>` etiketiyle bir sürüm açar ve APK'yı
/// `--build-number 100+N` ile derler: sürüm kodu etiketten çıkar.
const guncellemeDeposu = '07erkanoz/kodlama';
const _kodFarki = 100;

/// GitHub'daki bir Atölye sürümü.
class Surum {
  const Surum({
    required this.numara,
    required this.ad,
    required this.apk,
    required this.boyut,
    this.tarih,
    this.sha256,
    this.notlar = '',
  });

  /// `apk-<numara>` etiketindeki sayı.
  final int numara;
  final String ad;
  final Uri apk;
  final int boyut;
  final DateTime? tarih;

  /// GitHub'ın varlık için verdiği özet (yoksa null: doğrulanmadan kurulur).
  final String? sha256;
  final String notlar;

  /// APK'nın Android sürüm kodu (versionCode).
  int get kod => numara + _kodFarki;
}

final _etiket = RegExp(r'^apk-(\d+)$');

/// GitHub `releases` yanıtından APK'sı olan Atölye sürümleri, yeniden eskiye.
List<Surum> surumleriAyikla(List<dynamic> yanit) {
  final out = <Surum>[];
  for (final r in yanit.whereType<Map>()) {
    if (r['draft'] == true) continue;
    final m = _etiket.firstMatch(r['tag_name'] as String? ?? '');
    if (m == null) continue;
    final varlik = ((r['assets'] as List?) ?? const [])
        .whereType<Map>()
        .where((a) => (a['name'] as String? ?? '').endsWith('.apk'))
        .firstOrNull;
    final adres = varlik?['browser_download_url'] as String?;
    if (adres == null) continue;
    final ozet = varlik!['digest'] as String?;
    out.add(
      Surum(
        numara: int.parse(m[1]!),
        ad: (r['name'] as String?)?.trim().isNotEmpty == true
            ? r['name'] as String
            : r['tag_name'] as String,
        apk: Uri.parse(adres),
        boyut: (varlik['size'] as num?)?.toInt() ?? 0,
        tarih: DateTime.tryParse(r['published_at'] as String? ?? ''),
        sha256: ozet != null && ozet.startsWith('sha256:')
            ? ozet.substring(7).toLowerCase()
            : null,
        notlar: r['body'] as String? ?? '',
      ),
    );
  }
  out.sort((a, b) => b.numara.compareTo(a.numara));
  return out;
}

/// [surumler] içinde [mevcutKod]'dan yeni olanların en yenisi.
Surum? yeniSurumuBul(List<Surum> surumler, int mevcutKod) {
  for (final s in surumler) {
    if (s.kod > mevcutKod) return s;
  }
  return null;
}

/// Bulunan yeni sürüm (ana ekran ve Ayarlar dinler); yoksa null.
final yeniSurum = ValueNotifier<Surum?>(null);

/// GitHub'da yeni sürüm arar. Kurulu sürüm Android'den okunur; Android
/// dışında null döner. Ağ hatası fırlatılır.
Future<Surum?> guncellemeDenetle() async {
  final mevcut = await Termux.surum();
  if (mevcut == null) return null;
  final surumler = surumleriAyikla(await ag.surumleriGetir(guncellemeDeposu));
  return yeniSurum.value = yeniSurumuBul(surumler, mevcut.kod);
}

/// İndirir, SHA-256 ile doğrular ve Android'in yükleme ekranını açar.
/// Kurulum izni yoksa izin ekranını açar ve false döner.
Future<bool> guncellemeyiKur(
  Surum s, {
  void Function(double? oran)? ilerleme,
}) async {
  if (!await Termux.kurulumIzniVar()) {
    await Termux.kurulumIzniAc();
    return false;
  }
  final yol = await ag.surumuIndir(s.apk, s.sha256, ilerleme: ilerleme);
  await Termux.apkKur(yol);
  return true;
}
