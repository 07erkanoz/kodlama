/// Web'de kurulum sunucusu yoktur: köprü elle başlatılır.
class KurulumSunucusu {
  Future<void> baslat() async {}
  Future<void> durdur() async {}
  int? get port => null;
  String token = '';
  List<String> ajanlar = const [];
  String komut({required String token, required List<String> ajanlar}) => '';
  String guncellemeKomutu() => '';
}
