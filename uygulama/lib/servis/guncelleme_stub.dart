/// Web'de güncelleme denetlenmez ve kurulmaz.
Future<List<dynamic>> surumleriGetir(String depo) async => const [];

Future<String> surumuIndir(
  Uri adres,
  String? sha256, {
  void Function(double? oran)? ilerleme,
}) => throw UnsupportedError('Güncelleme yalnızca Android\'de kurulabilir');
