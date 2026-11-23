/// Web'de kurulum sunucusu yoktur: köprü elle başlatılır.
class KurulumSunucusu {
  Future<void> baslat() async {}
  Future<void> durdur() async {}
  int? get port => null;
  String komut({required String token, required List<String> ajanlar}) => '';
  String guncellemeKomutu() => '';
}
