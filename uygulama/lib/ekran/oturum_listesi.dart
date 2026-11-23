import 'package:flutter/material.dart';

import '../arayuz/ortak.dart';
import '../model/calisma.dart';
import '../servis/kopru_istemci.dart';
import 'ayarlar_ekrani.dart';

/// Kenar çubuğu: yeni oturum, gruplanmış oturumlar, kota ve tema.
/// Dar ekranda çekmecede açılır.
class OturumListesi extends StatelessWidget {
  const OturumListesi({super.key, required this.calisma, this.secildi});

  final Calisma calisma;

  /// Dar ekranda çekmeceyi kapatmak için.
  final VoidCallback? secildi;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    return ListenableBuilder(
      listenable: calisma,
      builder: (context, _) {
        final c = calisma;
        final bugun = DateTime.now();
        final gunBasi =
            DateTime(
              bugun.year,
              bugun.month,
              bugun.day,
            ).millisecondsSinceEpoch /
            1000;
        final bugunku = [
          for (final o in c.oturumlar)
            if ((o['guncelleme'] as num? ?? 0) >= gunBasi) o,
        ];
        final onceki = [
          for (final o in c.oturumlar)
            if ((o['guncelleme'] as num? ?? 0) < gunBasi) o,
        ];
        return Material(
          color: r.surfaceContainerLow,
          child: SafeArea(
            right: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: r.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.terminal_rounded,
                          size: 17,
                          color: r.onPrimary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Atölye',
                          style: t.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      _BaglantiIsareti(durum: c.baglanti),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: FilledButton.icon(
                    onPressed: c.baglanti == BaglantiDurumu.bagli
                        ? () {
                            c.baslangica();
                            secildi?.call();
                          }
                        : null,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Yeni oturum'),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: c.oturumlar.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              c.baglanti == BaglantiDurumu.bagli
                                  ? 'Henüz oturum yok.'
                                  : 'Köprü bekleniyor…',
                              style: t.textTheme.bodySmall?.copyWith(
                                color: r.onSurfaceVariant,
                              ),
                            ),
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          children: [
                            if (bugunku.isNotEmpty) ...[
                              const _Baslik('Bugün'),
                              for (final o in bugunku) _satir(context, o),
                            ],
                            if (onceki.isNotEmpty) ...[
                              const _Baslik('Önceki'),
                              for (final o in onceki) _satir(context, o),
                            ],
                          ],
                        ),
                ),
                Divider(height: 1, color: r.outlineVariant),
                if (c.kotalar.isNotEmpty) _Kotalar(kotalar: c.kotalar),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                  child: Row(
                    children: [
                      _TemaDugmesi(calisma: c),
                      const Spacer(),
                      IconButton(
                        tooltip: 'Ayarlar · GitHub · SSH',
                        onPressed: () {
                          secildi?.call();
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AyarlarEkrani(calisma: c),
                            ),
                          );
                        },
                        icon: const Icon(Icons.settings_outlined, size: 20),
                      ),
                      IconButton(
                        tooltip: 'Yenile',
                        onPressed: c.yenile,
                        icon: const Icon(Icons.refresh, size: 20),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _satir(BuildContext context, Map<String, dynamic> o) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    final secili = calisma.secili?.id == o['id'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: secili ? r.surfaceContainerHighest : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            calisma.sec(o);
            secildi?.call();
          },
          onLongPress: () => _sil(context, o),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                AjanRozeti(
                  ajan: o['ajan'] as String,
                  boyut: 26,
                  calisiyor: o['durum'] == 'calisiyor',
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        o['baslik'] as String? ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.textTheme.bodyMedium?.copyWith(
                          fontWeight: secili
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: r.onSurface,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '${(o['cwd'] as String? ?? '').split('/').last} · ${goreliZaman(o['guncelleme'] as num?)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.textTheme.bodySmall?.copyWith(
                          color: r.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _sil(BuildContext context, Map<String, dynamic> o) async {
    final evet = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Oturum silinsin mi?'),
        content: Text(
          '"${o['baslik']}" listeden ve Atölye kaydından silinir. '
          'Klasördeki dosyalara dokunulmaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (evet == true) await calisma.oturumSil(o['id'] as String);
  }
}

class _Baslik extends StatelessWidget {
  const _Baslik(this.metin);
  final String metin;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 6),
      child: Text(
        metin.toUpperCase(),
        style: t.textTheme.labelSmall?.copyWith(
          color: t.colorScheme.onSurfaceVariant,
          letterSpacing: .8,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BaglantiIsareti extends StatelessWidget {
  const _BaglantiIsareti({required this.durum});
  final BaglantiDurumu durum;

  @override
  Widget build(BuildContext context) {
    final (renk, metin) = switch (durum) {
      BaglantiDurumu.bagli => (const Color(0xFF22C55E), 'Bağlı'),
      BaglantiDurumu.baglaniyor => (const Color(0xFFF59E0B), 'Bağlanıyor'),
      BaglantiDurumu.yetkisiz => (const Color(0xFFEF4444), 'Anahtar yanlış'),
      BaglantiDurumu.kapali => (const Color(0xFF71717A), 'Kapalı'),
    };
    final t = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        color: renk.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: renk, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            metin,
            style: t.textTheme.labelSmall?.copyWith(
              color: renk,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Kotalar extends StatelessWidget {
  const _Kotalar({required this.kotalar});
  final Map<String, List<dynamic>> kotalar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final MapEntry(key: ajan, value: pencereler) in kotalar.entries)
            for (final p in pencereler.cast<Map>())
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${ajan == 'claude' ? 'Claude' : 'Codex'} · ${p['ad']}',
                          style: t.textTheme.labelSmall?.copyWith(
                            color: r.onSurfaceVariant,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '%${p['kullanim']}',
                          style: t.textTheme.labelSmall?.copyWith(
                            color: r.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ((p['kullanim'] as num?) ?? 0) / 100,
                        minHeight: 4,
                        backgroundColor: r.surfaceContainerHighest,
                        color: ((p['kullanim'] as num?) ?? 0) >= 90
                            ? r.error
                            : ((p['kullanim'] as num?) ?? 0) >= 70
                            ? const Color(0xFFF59E0B)
                            : r.primary,
                      ),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _TemaDugmesi extends StatelessWidget {
  const _TemaDugmesi({required this.calisma});
  final Calisma calisma;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<ThemeModeSecimi>(
      showSelectedIcon: false,
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      segments: const [
        ButtonSegment(
          value: ThemeModeSecimi.acik,
          icon: Icon(Icons.light_mode_outlined, size: 16),
          tooltip: 'Açık',
        ),
        ButtonSegment(
          value: ThemeModeSecimi.sistem,
          icon: Icon(Icons.brightness_auto_outlined, size: 16),
          tooltip: 'Sistem',
        ),
        ButtonSegment(
          value: ThemeModeSecimi.koyu,
          icon: Icon(Icons.dark_mode_outlined, size: 16),
          tooltip: 'Koyu',
        ),
      ],
      selected: {calisma.tema},
      onSelectionChanged: (s) => calisma.temaDegistir(s.first),
    );
  }
}
