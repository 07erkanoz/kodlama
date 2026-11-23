import 'package:url_launcher/url_launcher.dart';

/// Web: dosya köprünün adresinden yeni sekmede açılır.
Future<void> baskaUygulamadaAc(Uri adres, String ad) =>
    launchUrl(adres, mode: LaunchMode.externalApplication);

Future<void> paylas(Uri adres, String ad) =>
    launchUrl(adres, mode: LaunchMode.externalApplication);
