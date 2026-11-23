import 'dart:io';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Dosya Termux'un klasöründedir; başka uygulamalar oraya erişemez. Bu yüzden
/// önce köprüden uygulamanın geçici klasörüne indirilir, sonra sistemin
/// "birlikte aç" ya da paylaş penceresiyle verilir.
Future<File> _indir(Uri adres, String ad) async {
  final klasor = Directory('${(await getTemporaryDirectory()).path}/atolye');
  await klasor.create(recursive: true);
  final hedef = File('${klasor.path}/$ad');
  final istemci = HttpClient();
  try {
    final yanit = await (await istemci.getUrl(adres)).close();
    if (yanit.statusCode != 200) {
      throw HttpException('dosya alınamadı (${yanit.statusCode})');
    }
    await yanit.pipe(hedef.openWrite());
  } finally {
    istemci.close();
  }
  return hedef;
}

Future<void> baskaUygulamadaAc(Uri adres, String ad) async {
  final f = await _indir(adres, ad);
  final r = await OpenFilex.open(f.path);
  if (r.type != ResultType.done) {
    throw Exception(
      r.message.isEmpty ? 'açacak uygulama bulunamadı' : r.message,
    );
  }
}

Future<void> paylas(Uri adres, String ad) async {
  final f = await _indir(adres, ad);
  await SharePlus.instance.share(ShareParams(files: [XFile(f.path)]));
}
