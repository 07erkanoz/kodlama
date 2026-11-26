import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import 'termux_indir_io.dart' show AccumulatorSink;

/// Deponun son sürümleri (GitHub API, giriş gerekmez).
Future<List<dynamic>> surumleriGetir(String depo) async {
  final h = HttpClient()..connectionTimeout = const Duration(seconds: 15);
  try {
    final istek = await h.getUrl(
      Uri.parse('https://api.github.com/repos/$depo/releases?per_page=10'),
    );
    istek.headers
      ..set(HttpHeaders.userAgentHeader, 'Atolye')
      ..set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
    final yanit = await istek.close();
    if (yanit.statusCode != 200) {
      throw HttpException('GitHub yanıtı ${yanit.statusCode}');
    }
    return jsonDecode(await yanit.transform(utf8.decoder).join())
        as List<dynamic>;
  } finally {
    h.close();
  }
}

/// APK'yı önbelleğe indirir (yükleyici FileProvider'ın "derleme/" yolundan
/// alır) ve [sha256] verildiyse doğrular; eşleşmezse siler ve hata verir.
Future<String> surumuIndir(
  Uri adres,
  String? sha256, {
  void Function(double? oran)? ilerleme,
}) async {
  final klasor = Directory('${(await getTemporaryDirectory()).path}/derleme');
  if (await klasor.exists()) await klasor.delete(recursive: true);
  await klasor.create(recursive: true);
  final hedef = File('${klasor.path}/atolye-guncelleme.apk');
  final h = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  try {
    final istek = await h.getUrl(adres);
    istek.headers.set(HttpHeaders.userAgentHeader, 'Atolye');
    final yanit = await istek.close();
    if (yanit.statusCode != 200) {
      throw HttpException('APK alınamadı (${yanit.statusCode})');
    }
    final toplam = yanit.contentLength;
    final yazici = hedef.openWrite();
    final ozet = AccumulatorSink<Digest>();
    final ozetci = _ozetci(ozet);
    var gelen = 0;
    await for (final parca in yanit) {
      yazici.add(parca);
      ozetci.add(parca);
      gelen += parca.length;
      ilerleme?.call(toplam > 0 ? gelen / toplam : null);
    }
    await yazici.close();
    ozetci.close();
    if (sha256 != null && ozet.events.single.toString() != sha256) {
      await hedef.delete();
      throw StateError('İndirilen APK doğrulanamadı (SHA-256 eşleşmedi)');
    }
    return hedef.path;
  } finally {
    h.close();
  }
}

ByteConversionSink _ozetci(Sink<Digest> hedef) =>
    sha256.startChunkedConversion(hedef);
