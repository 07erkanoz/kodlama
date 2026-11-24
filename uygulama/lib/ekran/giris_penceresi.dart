import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../arayuz/ortak.dart';
import '../model/calisma.dart';
import '../servis/termux.dart';

/// Ajanın hesabına giriş: Termux açılmaz. Köprü CLI'ın giriş komutunu çalıştırır;
/// adres (ve Codex'te cihaz kodu) burada gösterilir, hesap girişi tarayıcıda
/// yapılır. Atölye hiçbir kimlik bilgisi görmez ya da saklamaz.
///
/// Köprü eskiyse (`giris` yeteneği yok) eski yola düşer: Termux'ta giriş açılır.
Future<void> girisPenceresi(
  BuildContext context,
  Calisma c,
  String ajan,
) async {
  if (!c.yetenek('giris')) {
    final mesaj = ScaffoldMessenger.of(context);
    bool acildi;
    try {
      acildi = await Termux.girisAc(ajan);
    } catch (_) {
      acildi = false;
    }
    mesaj.showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 7),
        content: Text(
          acildi
              ? 'Köprü eski; giriş Termux\'ta açılıyor. Önce Ayarlar → Köprü → '
                    '"Köprüyü güncelle" ile uygulama içinde girebilirsin.'
              : 'Köprü eski; giriş komutu kopyalandı: Termux\'ta uzun bas → Paste → Enter.',
        ),
      ),
    );
    return;
  }
  await c.girisBaslat(ajan);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _GirisPenceresi(calisma: c, ajan: ajan),
  );
}

class _GirisPenceresi extends StatefulWidget {
  const _GirisPenceresi({required this.calisma, required this.ajan});
  final Calisma calisma;
  final String ajan;

  @override
  State<_GirisPenceresi> createState() => _GirisPenceresiState();
}

class _GirisPenceresiState extends State<_GirisPenceresi> {
  final _kod = TextEditingController();
  bool _acildi = false;
  bool _kapaniyor = false;

  Calisma get c => widget.calisma;

  @override
  void initState() {
    super.initState();
    c.giris.addListener(_degisti);
    _degisti();
  }

  @override
  void dispose() {
    c.giris.removeListener(_degisti);
    _kod.dispose();
    super.dispose();
  }

  void _degisti() {
    final g = c.giris;
    // Başarılıysa kısa bir "tamam" gösterip kapat.
    if (g.basarili == true && !_kapaniyor) {
      _kapaniyor = true;
      Future<void>.delayed(const Duration(milliseconds: 1400), () {
        if (mounted) Navigator.of(context).pop();
      });
    }
    // Adres (Codex'te kod da) gelince tarayıcıyı bir kez kendiliğinden aç;
    // yalnız telefonda (masaüstünde istenmeyen pencere açmasın).
    final hazir = g.url != null && (widget.ajan == 'claude' || g.kod != null);
    if (hazir && !_acildi && Termux.destekleniyor) {
      _acildi = true;
      if (g.kod != null) Clipboard.setData(ClipboardData(text: g.kod!));
      Future<void>.delayed(const Duration(milliseconds: 900), _tarayiciAc);
    }
    if (mounted) setState(() {});
  }

  Future<void> _tarayiciAc() async {
    final adres = Uri.tryParse(c.giris.url ?? '');
    if (adres == null || adres.scheme != 'https') return;
    await launchUrl(adres, mode: LaunchMode.externalApplication);
  }

  Future<void> _iptalEt() async {
    await c.girisIptalEt();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    final g = c.giris;
    final ad = girisAdi(widget.ajan);
    final bitti = !g.calisiyor && g.basarili != null;

    Widget icerik;
    if (g.basarili == true) {
      icerik = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, size: 48, color: Color(0xFF22C55E)),
          const SizedBox(height: 12),
          Text('$ad hesabına giriş yapıldı.', style: t.textTheme.titleSmall),
        ],
      );
    } else if (bitti) {
      icerik = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.error_outline, size: 40, color: r.error),
          const SizedBox(height: 12),
          Text(
            g.hata ?? 'Giriş tamamlanamadı.',
            textAlign: TextAlign.center,
            style: TextStyle(color: r.onSurfaceVariant),
          ),
        ],
      );
    } else if (g.url == null) {
      icerik = const Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 14),
          Expanded(child: Text('Giriş başlatılıyor…')),
        ],
      );
    } else {
      icerik = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(switch (widget.ajan) {
            'codex' => '1. Tarayıcıda ChatGPT hesabınla giriş yap.',
            'gh' => '1. Tarayıcıda GitHub hesabınla giriş yap.',
            _ => '1. Tarayıcıda Claude hesabınla giriş yap ve izin ver.',
          }, style: t.textTheme.bodyMedium),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _tarayiciAc,
            icon: const Icon(Icons.open_in_browser, size: 18),
            label: const Text('Tarayıcıda aç'),
          ),
          if (g.kod != null) ...[
            const SizedBox(height: 18),
            Text(
              widget.ajan == 'gh'
                  ? '2. GitHub bu kodu isteyecek:'
                  : '2. İstenirse bu kodu gir:',
              style: t.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: r.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SelectableText(
                    g.kod!,
                    style: monospace.copyWith(
                      fontSize: 26,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Kopyala',
                    onPressed: () =>
                        Clipboard.setData(ClipboardData(text: g.kod!)),
                    icon: const Icon(Icons.copy, size: 18),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.ajan == 'gh'
                  ? 'Kod panoya da kopyalandı.'
                  : 'Kod panoya da kopyalandı; 15 dakika geçerli.',
              style: t.textTheme.bodySmall?.copyWith(color: r.onSurfaceVariant),
            ),
          ],
          if (widget.ajan == 'claude') ...[
            const SizedBox(height: 18),
            Text(
              '2. Sayfa bir kod gösterirse buraya yapıştır:',
              style: t.textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _kod,
                    decoration: const InputDecoration(hintText: 'Kod'),
                    onSubmitted: (_) => _kodGonder(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _kodGonder,
                  child: const Text('Gönder'),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Giriş tamamlanınca burası kendiliğinden kapanır.',
                  style: t.textTheme.bodySmall?.copyWith(
                    color: r.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return AlertDialog(
      title: Text('$ad girişi'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(child: icerik),
      ),
      actions: [
        if (bitti && g.basarili != true)
          TextButton(
            onPressed: () async {
              _acildi = false;
              _kapaniyor = false;
              await c.girisBaslat(widget.ajan);
            },
            child: const Text('Yeniden dene'),
          ),
        if (g.basarili != true)
          TextButton(
            onPressed: bitti ? () => Navigator.of(context).pop() : _iptalEt,
            child: Text(bitti ? 'Kapat' : 'İptal'),
          ),
      ],
    );
  }

  Future<void> _kodGonder() async {
    final kod = _kod.text.trim();
    if (kod.isEmpty) return;
    _kod.clear();
    await c.girisKodGonder(kod);
  }
}
