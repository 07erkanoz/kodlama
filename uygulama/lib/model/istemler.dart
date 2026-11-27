import 'dart:convert';

/// Yazma kutusunda "/" ile çağrılan hazır istem: `/ad` yazınca [metin] gelir.
class Istem {
  const Istem(this.ad, this.metin);
  final String ad;
  final String metin;

  Map<String, String> toJson() => {'ad': ad, 'metin': metin};
}

/// Kullanıcı hiç düzenlemediyse gelen istemler.
const varsayilanIstemler = [
  Istem(
    'test',
    'Projenin testlerini çalıştır. Başarısız olanları düzelt, yeniden çalıştır '
        've sonucu kısaca özetle.',
  ),
  Istem(
    'incele',
    'Son değişiklikleri hata, güvenlik ve okunabilirlik açısından incele. '
        'Bulguları önem sırasıyla, dosya ve satır vererek listele; henüz düzeltme.',
  ),
  Istem(
    'commit',
    'Değişiklikleri gözden geçir, anlamlı bir commit mesajıyla commit et ve '
        'gönder. Gizli bilgi içeren dosyaları ekleme.',
  ),
  Istem(
    'durum',
    'Projenin şu anki durumunu özetle: dal, bekleyen değişiklikler, son '
        'commitler ve yarım kalmış işler.',
  ),
  Istem(
    'acikla',
    'Bu projenin yapısını, ana bileşenlerini ve nasıl çalıştırıldığını kısaca açıkla.',
  ),
  Istem(
    'sunucu',
    'Sunucunun durumuna bak: disk, bellek, yük, çalışan servisler ve son '
        'hatalar. Bir sorun varsa nedenini ve çözümünü söyle; değişiklik yapmadan önce sor.',
  ),
];

/// Ayarlarda saklanan JSON → istemler; boş ya da bozuksa varsayılanlar.
List<Istem> istemleriCoz(String? json) {
  if (json == null || json.isEmpty) return varsayilanIstemler;
  try {
    return [
      for (final x in jsonDecode(json) as List)
        if (x is Map && x['ad'] is String && x['metin'] is String)
          Istem(x['ad'] as String, x['metin'] as String),
    ];
  } catch (_) {
    return varsayilanIstemler;
  }
}

String istemleriYaz(List<Istem> liste) =>
    jsonEncode([for (final i in liste) i.toJson()]);

/// Yazılan "/te" gibi bir başlangıca uyan istemler; "/" ile başlamıyorsa ya
/// da boşluk içeriyorsa boş.
List<Istem> istemAra(List<Istem> liste, String yazilan) {
  if (!yazilan.startsWith('/') || yazilan.contains(RegExp(r'\s'))) {
    return const [];
  }
  final aranan = yazilan.substring(1).toLowerCase();
  return [
    for (final i in liste)
      if (i.ad.toLowerCase().startsWith(aranan)) i,
    for (final i in liste)
      if (!i.ad.toLowerCase().startsWith(aranan) &&
          aranan.isNotEmpty &&
          (i.ad.toLowerCase().contains(aranan) ||
              i.metin.toLowerCase().contains(aranan)))
        i,
  ];
}
