/// Web'de APK indirilip kurulamaz.
Future<String> apkIndir(
  Uri adres,
  String ad, {
  void Function(double? oran)? ilerleme,
}) => throw UnsupportedError('APK yalnızca Android\'de kurulabilir');
