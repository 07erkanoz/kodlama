import 'dart:math';

import 'package:flutter/material.dart';

import '../arayuz/ortak.dart';
import '../model/calisma.dart';
import 'oturum_listesi.dart' show KotaSatiri;

/// Kullanım: güncel kota pencereleri, son günlerin tur/jeton grafiği ve
/// toplamlar (oturum kayıtlarından; Claude'un maliyeti API karşılığıdır).
class KullanimEkrani extends StatefulWidget {
  const KullanimEkrani({super.key, required this.calisma});
  final Calisma calisma;

  @override
  State<KullanimEkrani> createState() => _KullanimEkraniState();
}

const _ajanlar = ['claude', 'codex'];

class _KullanimEkraniState extends State<KullanimEkrani> {
  late Future<Map<String, dynamic>> _veri = _yukle();
  String _olcu = 'jeton'; // jeton | tur | sure

  Future<Map<String, dynamic>> _yukle() =>
      widget.calisma.istemci.iste('kullanim', {'gun': 30});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kullanım'),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: () {
              widget.calisma.kotaYenile();
              setState(() => _veri = _yukle());
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder(
        future: _veri,
        builder: (context, snap) {
          if (snap.hasError) return Center(child: Text('${snap.error}'));
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final d = snap.data!;
          final gunler = [
            for (final g in d['gunler'] as List)
              (g as Map).cast<String, dynamic>(),
          ];
          final kotalar = (d['kotalar'] as Map? ?? {}).cast<String, dynamic>();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (kotalar.isNotEmpty) ...[
                Text('Kullanım sınırları', style: t.textTheme.titleSmall),
                const SizedBox(height: 8),
                for (final a in _ajanlar)
                  for (final p in (kotalar[a] as List? ?? const []).cast<Map>())
                    KotaSatiri(ajan: a, p: p),
                const SizedBox(height: 16),
              ],
              Row(
                children: [
                  Expanded(
                    child: Text('Son 14 gün', style: t.textTheme.titleSmall),
                  ),
                  SegmentedButton<String>(
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                    segments: const [
                      ButtonSegment(value: 'jeton', label: Text('Jeton')),
                      ButtonSegment(value: 'tur', label: Text('Tur')),
                      ButtonSegment(value: 'sure', label: Text('Süre')),
                    ],
                    selected: {_olcu},
                    onSelectionChanged: (s) => setState(() => _olcu = s.first),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _Grafik(gunler: gunler, olcu: _olcu),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final a in _ajanlar) ...[
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _renk(a, r),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(ajanAdi(a), style: t.textTheme.labelSmall),
                    const SizedBox(width: 12),
                  ],
                ],
              ),
              const SizedBox(height: 20),
              _Toplamlar(gunler: gunler),
            ],
          );
        },
      ),
    );
  }
}

Color _renk(String ajan, ColorScheme r) =>
    ajan == 'claude' ? const Color(0xFFD97757) : r.primary;

num _deger(Map? a, String olcu) => switch (olcu) {
  'tur' => (a?['tur'] as num?) ?? 0,
  'sure' => ((a?['sure'] as num?) ?? 0) / 60000, // dakika
  _ => (a?['jeton'] as num?) ?? 0,
};

String _kisaSayi(num n) => n >= 1e6
    ? '${(n / 1e6).toStringAsFixed(1)}M'
    : n >= 1e3
    ? '${(n / 1e3).toStringAsFixed(n >= 1e4 ? 0 : 1)}B'
    : n.toStringAsFixed(n is int || n >= 10 ? 0 : 1);

/// Günlük yığılmış çubuklar (Claude + Codex).
class _Grafik extends StatelessWidget {
  const _Grafik({required this.gunler, required this.olcu});
  final List<Map<String, dynamic>> gunler;
  final String olcu;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    final bugun = DateTime.now();
    final gunListesi = [
      for (var i = 13; i >= 0; i--)
        DateTime(bugun.year, bugun.month, bugun.day - i),
    ];
    String anahtar(DateTime g) =>
        '${g.year}-${g.month.toString().padLeft(2, '0')}-${g.day.toString().padLeft(2, '0')}';
    final bul = {for (final g in gunler) g['gun'] as String: g};
    final degerler = [
      for (final g in gunListesi)
        [for (final a in _ajanlar) _deger(bul[anahtar(g)]?[a] as Map?, olcu)],
    ];
    final enBuyuk = degerler
        .map((x) => x.fold<num>(0, (a, b) => a + b))
        .fold<num>(0, max);
    const yukseklik = 140.0;
    return SizedBox(
      height: yukseklik + 34,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < gunListesi.length; i++)
            Expanded(
              child: Tooltip(
                message:
                    '${gunListesi[i].day}.${gunListesi[i].month} · '
                    '${[for (var j = 0; j < _ajanlar.length; j++) '${ajanAdi(_ajanlar[j])}: ${_kisaSayi(degerler[i][j])}'].join(' · ')}',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      for (var j = _ajanlar.length - 1; j >= 0; j--)
                        Container(
                          height: enBuyuk == 0
                              ? 0
                              : yukseklik * degerler[i][j] / enBuyuk,
                          decoration: BoxDecoration(
                            color: _renk(_ajanlar[j], r),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      if (enBuyuk == 0 || degerler[i].every((x) => x == 0))
                        Container(height: 2, color: r.surfaceContainerHighest),
                      const SizedBox(height: 4),
                      Text(
                        '${gunListesi[i].day}',
                        style: t.textTheme.labelSmall?.copyWith(
                          color: r.onSurfaceVariant,
                          fontSize: 10,
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Toplamlar extends StatelessWidget {
  const _Toplamlar({required this.gunler});
  final List<Map<String, dynamic>> gunler;

  Map<String, num> _topla(String ajan, int gun) {
    final sinir = DateTime.now().subtract(Duration(days: gun));
    final out = <String, num>{'tur': 0, 'jeton': 0, 'sure': 0, 'maliyet': 0};
    for (final g in gunler) {
      final tarih = DateTime.tryParse(g['gun'] as String? ?? '');
      if (tarih == null || tarih.isBefore(sinir)) continue;
      final a = g[ajan] as Map?;
      if (a == null) continue;
      for (final k in out.keys.toList()) {
        out[k] = out[k]! + ((a[k] as num?) ?? 0);
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    final baslik = t.textTheme.labelSmall?.copyWith(
      color: r.onSurfaceVariant,
      fontWeight: FontWeight.w600,
    );
    Widget hucre(String s, {TextStyle? stil}) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Text(s, style: stil ?? t.textTheme.bodySmall),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Toplamlar', style: t.textTheme.titleSmall),
        const SizedBox(height: 8),
        Table(
          columnWidths: const {0: FlexColumnWidth(1.6)},
          border: TableBorder(
            horizontalInside: BorderSide(color: r.outlineVariant),
          ),
          children: [
            TableRow(
              children: [
                hucre('', stil: baslik),
                hucre('Tur', stil: baslik),
                hucre('Jeton', stil: baslik),
                hucre('Süre', stil: baslik),
                hucre('Maliyet', stil: baslik),
              ],
            ),
            for (final gun in [7, 30])
              for (final a in _ajanlar)
                () {
                  final x = _topla(a, gun);
                  final dk = (x['sure']! / 60000).round();
                  return TableRow(
                    children: [
                      hucre('${ajanAdi(a)} · $gun gün'),
                      hucre('${x['tur']}'),
                      hucre(_kisaSayi(x['jeton']!)),
                      hucre(
                        dk >= 60 ? '${dk ~/ 60} sa ${dk % 60} dk' : '$dk dk',
                      ),
                      hucre(
                        x['maliyet']! > 0
                            ? '\$${x['maliyet']!.toStringAsFixed(2)}'
                            : '—',
                      ),
                    ],
                  );
                }(),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Claude\'un maliyeti API fiyatıyla karşılığıdır; abonelikte ayrıca ödenmez. '
          'Codex jeton sayar, maliyet bildirmez. Yankı\'da Claude\'a verilen işler sayılmaz.',
          style: t.textTheme.bodySmall?.copyWith(color: r.onSurfaceVariant),
        ),
      ],
    );
  }
}
