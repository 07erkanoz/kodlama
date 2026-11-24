import 'dart:async';

import 'package:flutter/material.dart';

import '../arayuz/ortak.dart';
import '../model/calisma.dart';
import '../servis/kopru_istemci.dart';
import '../servis/paylasim.dart';

/// Paylaş menüsünden Atölye'ye gelen metin ya da dosyalar için hedef sorar:
/// açık oturum, son oturumlardan biri ya da yeni oturum. Seçilen yerin yazma
/// kutusuna alınır (dosyalar ek olur); gönderme yine kullanıcıdadır.
class PaylasimYoneticisi {
  PaylasimYoneticisi(this.c, this.gezgin) {
    unawaited(_basla());
  }

  final Calisma c;
  final GlobalKey<NavigatorState> gezgin;

  Future<void> _basla() async {
    final ilk = await Paylasim.dinle(_geldi);
    if (ilk != null) await _geldi(ilk);
  }

  Future<void> _geldi(Paylasim p) async {
    // Arayüz ve köprü bağlantısı hazır olsun.
    for (var i = 0; i < 40; i++) {
      if (gezgin.currentState != null && c.baglanti == BaglantiDurumu.bagli) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 300));
    }
    final g = gezgin.currentState;
    if (g == null) return;
    g.popUntil((r) => r.isFirst);
    final baglam = g.overlay?.context;
    if (baglam == null || !baglam.mounted) return;
    final hedef = await showModalBottomSheet<String>(
      context: baglam,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => _HedefSecici(c: c, p: p),
    );
    if (hedef == null) return;
    if (hedef == '') {
      c.baslangica();
    } else if (c.secili?.id != hedef) {
      await c.oturumuAc(hedef);
    }
    c.paylasim.value = p;
  }
}

class _HedefSecici extends StatelessWidget {
  const _HedefSecici({required this.c, required this.p});
  final Calisma c;
  final Paylasim p;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    final secili = c.secili?.id;
    final oturumlar = [
      ...c.oturumlar.where((o) => o['id'] == secili),
      ...c.oturumlar.where((o) => o['id'] != secili).take(5),
    ];
    final ozet = [
      if (p.metin.trim().isNotEmpty) '"${kisalt(p.metin.trim(), 80)}"',
      if (p.dosyalar.isNotEmpty)
        p.dosyalar.length == 1
            ? p.dosyalar.single.ad
            : '${p.dosyalar.length} dosya',
    ].join(' · ');
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .7,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Text('Atölye\'ye gönder', style: t.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              ozet,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: t.textTheme.bodySmall?.copyWith(
                color: r.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.add_circle_outline),
              title: const Text('Yeni oturum'),
              subtitle: const Text('Proje ve ajanı seçip başlat'),
              onTap: () => Navigator.pop(context, ''),
            ),
            if (oturumlar.isNotEmpty) const Divider(),
            for (final o in oturumlar)
              ListTile(
                leading: Icon(
                  o['id'] == secili
                      ? Icons.chat_bubble
                      : Icons.chat_bubble_outline,
                ),
                title: Text(
                  (o['baslik'] as String?) ?? 'Oturum',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  [
                    ajanAdi(o['ajan'] as String? ?? ''),
                    (o['goreli'] as String?) ?? '',
                    if (o['id'] == secili) 'açık',
                  ].where((x) => x.isNotEmpty).join(' · '),
                ),
                onTap: () => Navigator.pop(context, o['id'] as String),
              ),
          ],
        ),
      ),
    );
  }
}

String kisalt(String s, int n) =>
    s.length <= n ? s : '${s.substring(0, n).trimRight()}…';
