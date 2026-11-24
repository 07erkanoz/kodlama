import 'package:flutter/material.dart';

import '../arayuz/ortak.dart';
import '../model/calisma.dart';
import '../model/kurulum.dart';

/// Köprünün çalıştırdığı kurulumun canlı görünümü: sürmekte olan adım, biten
/// adımlar ve ayrıntılı çıktı. Kullanıcı Termux'u açmaz.
class KurulumPaneli extends StatelessWidget {
  const KurulumPaneli({super.key, required this.calisma, this.yenidenDene});

  final Calisma calisma;

  /// Kurulum başarısız olunca "Yeniden dene" düğmesinin yapacağı iş.
  final VoidCallback? yenidenDene;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    return ListenableBuilder(
      listenable: calisma.kurulum,
      builder: (context, _) {
        final k = calisma.kurulum;
        if (!k.basladi) {
          return Row(
            children: [
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Text('Kurulum başlatılıyor…', style: t.textTheme.bodyMedium),
            ],
          );
        }
        final (simge, baslik, renk) = k.calisiyor
            ? (null, 'Kuruluyor…', r.primary)
            : k.basarili
            ? (
                Icons.check_circle,
                'Kurulum tamamlandı',
                const Color(0xFF22C55E),
              )
            : (Icons.error_outline, 'Kurulum tamamlanamadı', r.error);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                simge == null
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : Icon(simge, color: renk, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    baslik,
                    style: t.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            if (k.calisiyor) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(minHeight: 4),
            ],
            const SizedBox(height: 12),
            for (final (i, a) in k.adimlar.indexed)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      child: i == k.adimlar.length - 1 && k.calisiyor
                          ? const SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.8,
                              ),
                            )
                          : Icon(
                              Icons.check,
                              size: 16,
                              color: i == k.adimlar.length - 1 && k.basarisiz
                                  ? r.error
                                  : const Color(0xFF22C55E),
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        a,
                        style: t.textTheme.bodyMedium?.copyWith(
                          color: i == k.adimlar.length - 1
                              ? r.onSurface
                              : r.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (k.basarisiz) ...[
              const SizedBox(height: 8),
              Text(
                _hataOzeti(k),
                style: t.textTheme.bodySmall?.copyWith(color: r.error),
              ),
            ],
            const SizedBox(height: 8),
            Theme(
              data: t.copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text('Ayrıntılar', style: t.textTheme.labelLarge),
                dense: true,
                children: [_Cikti(satirlar: k.satirlar)],
              ),
            ),
            if (k.calisiyor)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: calisma.kurulumuIptalEt,
                  child: const Text('İptal'),
                ),
              ),
            if (k.basarisiz && yenidenDene != null)
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  onPressed: yenidenDene,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Yeniden dene'),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Başarısız kurulumda en anlamlı satır: son uyarı ya da son çıktı satırı.
  static String _hataOzeti(KurulumDurumu k) {
    final uyari = k.satirlar.where((s) => s.tur == 'uyari').lastOrNull;
    final son = uyari ?? k.satirlar.lastOrNull;
    final metin = son?.metin ?? 'Çıkış kodu ${k.kod}.';
    return metin.length > 220 ? '${metin.substring(0, 220)}…' : metin;
  }
}

class _Cikti extends StatelessWidget {
  const _Cikti({required this.satirlar});
  final List<KurulumSatiri> satirlar;

  @override
  Widget build(BuildContext context) {
    final r = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      width: double.infinity,
      decoration: BoxDecoration(
        color: r.surfaceContainerLowest,
        border: Border.all(color: r.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        reverse: true,
        padding: const EdgeInsets.all(10),
        child: SelectableText(
          satirlar.map((s) => s.metin).join('\n'),
          style: monospace.copyWith(
            fontSize: 11.5,
            height: 1.5,
            color: r.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Kurulumu alttan açılan bir sayfada gösterir (Ayarlar, başlangıç ekranı).
Future<void> kurulumPaneliGoster(
  BuildContext context,
  Calisma c, {
  VoidCallback? yenidenDene,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        child: SingleChildScrollView(
          child: KurulumPaneli(calisma: c, yenidenDene: yenidenDene),
        ),
      ),
    ),
  );
}

/// Bir ajanı (ve gereken araçları) uygulamanın içinde kurar ya da günceller.
Future<void> ajanKur(BuildContext context, Calisma c, String ajan) =>
    kurulumuCalistir(context, c, [ajan]);

/// Araçları ve [ajanlar]ı uygulamanın içinde kurar: önce işi başlatır, sonra
/// canlı paneli açar. Köprü eskiyse Termux penceresine düşer ve ne yapılacağını
/// söyler.
Future<void> kurulumuCalistir(
  BuildContext context,
  Calisma c,
  List<String> ajanlar,
) async {
  final mesaj = ScaffoldMessenger.of(context);
  Future<void> calistir() async {
    try {
      final uygulamada = await c.kurulumuBaslat(ajanlar: ajanlar);
      if (!uygulamada) {
        mesaj.showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 7),
            content: Text(
              'Köprü eski; kurulum komutu kopyalandı. Termux\'ta uzun bas → '
              'Paste → Enter. Önce Ayarlar → Köprü → "Köprüyü güncelle" daha kolay.',
            ),
          ),
        );
      }
    } catch (e) {
      mesaj.showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  await calistir();
  if (c.yetenek('kur') && context.mounted) {
    await kurulumPaneliGoster(context, c, yenidenDene: calistir);
  }
}
