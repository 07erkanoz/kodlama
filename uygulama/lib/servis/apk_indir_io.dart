import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Köprünün indirdiği APK'yı (Termux'ta) köprünün dosya adresinden
/// uygulamanın önbelleğine alır; yükleyiciye buradan verilir (FileProvider
/// "derleme/" yolu). Eski indirilenler silinir.
Future<String> apkIndir(
  Uri adres,
  String ad, {
  void Function(double? oran)? ilerleme,
}) async {
  final klasor = Directory('${(await getTemporaryDirectory()).path}/derleme');
  if (await klasor.exists()) await klasor.delete(recursive: true);
  await klasor.create(recursive: true);
  final hedef = File(
    '${klasor.path}/${ad.replaceAll(RegExp(r'[^\w.\-]'), '_')}',
  );
  final h = HttpClient();
  try {
    final yanit = await (await h.getUrl(adres)).close();
    if (yanit.statusCode != 200) {
      throw HttpException('APK alınamadı (${yanit.statusCode})');
    }
    final toplam = yanit.contentLength;
    final yazici = hedef.openWrite();
    var gelen = 0;
    await for (final parca in yanit) {
      yazici.add(parca);
      gelen += parca.length;
      ilerleme?.call(toplam > 0 ? gelen / toplam : null);
    }
    await yazici.close();
    return hedef.path;
  } finally {
    h.close();
  }
}
