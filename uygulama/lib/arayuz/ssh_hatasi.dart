import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../ekran/ayarlar_ekrani.dart';
import '../model/calisma.dart';
import '../servis/kopru_istemci.dart';

/// Köprünün SSH hatası ayrıntısı (köprü 0.14+): `tur` anahtar_degisti, yetki,
/// reddedildi, adres, ag, zaman_asimi ya da kapandi; anahtar değiştiyse
/// `eski` ve `yeni` parmak izleri.
Map<String, dynamic>? sshAyrintisi(Object hata) =>
    hata is KopruHatasi ? hata.ayrinti : null;

/// SSH hatası: anlaşılır açıklama ve türüne göre çözüm düğmesi. Sorun
/// giderildiyse [cozuldu] çağrılır (ör. yeniden dene).
class SshHataKarti extends StatelessWidget {
  const SshHataKarti({
    super.key,
    required this.calisma,
    required this.mesaj,
    required this.ayrinti,
    this.cozuldu,
  });

  final Calisma calisma;
  final String mesaj;
  final Map<String, dynamic> ayrinti;
  final VoidCallback? cozuldu;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    final tur = ayrinti['tur'] as String?;
    final sunucu = ayrinti['sunucu'] as String? ?? ayrinti['host'] as String?;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: r.errorContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: r.error.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                tur == 'anahtar_degisti'
                    ? Icons.gpp_maybe_outlined
                    : Icons.cloud_off_outlined,
                color: r.error,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sunucu == null
                          ? 'SSH bağlantısı kurulamadı'
                          : '$sunucu: bağlantı kurulamadı',
                      style: t.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(mesaj, style: t.textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            alignment: WrapAlignment.end,
            children: [
              TextButton(
                onPressed: () => _ham(context),
                child: const Text('Ayrıntı'),
              ),
              if (tur == 'anahtar_degisti')
                FilledButton.tonalIcon(
                  onPressed: () async {
                    if (await anahtarDegistiDiyalogu(
                      context,
                      calisma,
                      ayrinti,
                    )) {
                      cozuldu?.call();
                    }
                  },
                  icon: const Icon(Icons.fingerprint, size: 18),
                  label: const Text('Anahtarı incele'),
                ),
              if (tur == 'yetki')
                FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AyarlarEkrani(calisma: calisma),
                    ),
                  ),
                  icon: const Icon(Icons.key_outlined, size: 18),
                  label: const Text('Anahtarı gönder'),
                ),
              if (tur != 'anahtar_degisti' && tur != 'yetki' && cozuldu != null)
                FilledButton.tonalIcon(
                  onPressed: cozuldu,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Yeniden dene'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _ham(BuildContext context) {
    final ham = ayrinti['ham'] as String? ?? '';
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('SSH çıktısı'),
        content: SingleChildScrollView(
          child: SelectableText(
            ham.isEmpty ? '(çıktı yok)' : ham,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
        ],
      ),
    );
  }
}

/// Sunucunun kimlik anahtarı değişti: eski ve yeni parmak izi gösterilir,
/// kullanıcı isterse yenisine güvenilir. Güvenildiyse true döner.
Future<bool> anahtarDegistiDiyalogu(
  BuildContext context,
  Calisma c,
  Map<String, dynamic> ayrinti,
) async {
  List<Map> liste(String k) =>
      ((ayrinti[k] as List?) ?? const []).whereType<Map>().toList();
  final yeniler = liste('yeni');
  final eskiler = liste('eski');
  // Önce ED25519: ssh'nin tercih ettiği ve sunucuda en kolay bakılan.
  final yeni =
      yeniler.where((x) => x['tur'] == 'ED25519').firstOrNull ??
      yeniler.firstOrNull;
  final tur = (yeni?['tur'] as String? ?? 'ed25519').toLowerCase();
  final denetim = 'ssh-keygen -lf /etc/ssh/ssh_host_${tur}_key.pub';
  var calisiyor = false;
  String? hata;

  final sonuc = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, yenile) {
        final t = Theme.of(context);
        final r = t.colorScheme;
        Widget parmak(String baslik, Map x, {bool vurgu = false}) => Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$baslik · ${x['tur']}',
                style: t.textTheme.labelMedium?.copyWith(
                  color: r.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              SelectableText(
                x['parmak'] as String? ?? '',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12.5,
                  fontWeight: vurgu ? FontWeight.w600 : null,
                ),
              ),
            ],
          ),
        );
        return AlertDialog(
          icon: Icon(Icons.gpp_maybe_outlined, color: r.error),
          title: const Text('Sunucunun anahtarı değişmiş'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${ayrinti['sunucu'] ?? ayrinti['host']} daha önce farklı bir '
                    'kimlik anahtarıyla bağlanıyordu. Sunucuyu yeniden kurduysan '
                    'ya da SSH anahtarlarını yenilediysen bu normal. Öyle bir şey '
                    'yapmadıysan güvenme: araya biri girmiş olabilir.',
                  ),
                  if (yeni == null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        'Sunucuya şu an ulaşılamadığı için yeni anahtar okunamadı. '
                        'Biraz sonra yeniden dene.',
                        style: TextStyle(color: r.error),
                      ),
                    )
                  else ...[
                    parmak('Sunucunun şimdiki anahtarı', yeni, vurgu: true),
                    for (final e in eskiler) parmak('Kayıtlı eski anahtar', e),
                    const SizedBox(height: 14),
                    const Text(
                      'Emin olmak için sunucuda şunu çalıştır; çıkan SHA256 '
                      'yukarıdakiyle aynı olmalı:',
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
                      decoration: BoxDecoration(
                        color: r.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              denetim,
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Kopyala',
                            iconSize: 18,
                            onPressed: () =>
                                Clipboard.setData(ClipboardData(text: denetim)),
                            icon: const Icon(Icons.copy),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (hata != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(hata!, style: TextStyle(color: r.error)),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: calisiyor ? null : () => Navigator.pop(context, false),
              child: const Text('Vazgeç'),
            ),
            if (yeni != null)
              FilledButton(
                onPressed: calisiyor
                    ? null
                    : () async {
                        yenile(() {
                          calisiyor = true;
                          hata = null;
                        });
                        try {
                          await c.istemci.iste('sunucu_anahtar_guven', {
                            'ad': ayrinti['sunucu'],
                            'parmak': yeni['parmak'],
                          });
                          if (context.mounted) Navigator.pop(context, true);
                        } catch (e) {
                          yenile(() {
                            calisiyor = false;
                            hata = '$e';
                          });
                        }
                      },
                child: calisiyor
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Yeni anahtara güven'),
              ),
          ],
        );
      },
    ),
  );
  if (sonuc == true && context.mounted) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(const SnackBar(content: Text('Yeni anahtar kaydedildi.')));
  }
  return sonuc == true;
}
