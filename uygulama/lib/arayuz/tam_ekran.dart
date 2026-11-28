import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Uygulama genelinde tam ekran (Ayarlar › Görünüm): açıkken saat/bildirim ve
/// gezinme çubukları gizlenir, kenardan kaydırınca bir an görünür.
final tamEkran = ValueNotifier<bool>(false);

/// Sistem çubuklarını [tamEkran]'a göre ayarlar. Kendi tam ekranını açan
/// sayfalar (ör. Yankı) kapanırken bunu çağırıp kullanıcının seçimine döner.
Future<void> sistemCubuklariniUygula() => SystemChrome.setEnabledSystemUIMode(
  tamEkran.value ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
);

AppLifecycleListener? _dinleyici;

/// Açılışta bir kez: seçimi uygular; uygulamaya dönünce (Android bazen
/// çubukları geri getirir) yeniden uygular.
void tamEkranBaslat(bool acik) {
  tamEkran.value = acik;
  sistemCubuklariniUygula();
  _dinleyici ??= AppLifecycleListener(onResume: sistemCubuklariniUygula);
}
