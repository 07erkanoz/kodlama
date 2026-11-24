import 'dart:convert';

import 'package:flutter/material.dart';

import 'tema.dart';

const monospace = TextStyle(
  fontFamily: 'monospace',
  fontFamilyFallback: ['JetBrains Mono', 'DejaVu Sans Mono', 'Roboto Mono'],
);

String ajanAdi(String ajan) => ajan == 'claude' ? 'Claude Code' : 'Codex';

/// Giriş penceresinde hesabın adı: ajanlar ve GitHub.
String girisAdi(String ad) => switch (ad) {
  'gh' => 'GitHub',
  _ => ajanAdi(ad),
};

/// "az önce", "5 dk", "3 sa", "dün", "12 Kas".
String goreliZaman(num? saniye) {
  if (saniye == null) return '';
  final t = DateTime.fromMillisecondsSinceEpoch((saniye * 1000).round());
  final fark = DateTime.now().difference(t);
  if (fark.inMinutes < 1) return 'az önce';
  if (fark.inMinutes < 60) return '${fark.inMinutes} dk';
  if (fark.inHours < 24) return '${fark.inHours} sa';
  if (fark.inDays == 1) return 'dün';
  if (fark.inDays < 7) return '${fark.inDays} gün';
  const aylar = [
    'Oca',
    'Şub',
    'Mar',
    'Nis',
    'May',
    'Haz',
    'Tem',
    'Ağu',
    'Eyl',
    'Eki',
    'Kas',
    'Ara',
  ];
  return '${t.day} ${aylar[t.month - 1]}';
}

/// Ajanın küçük kimlik rozeti: renkli harf, nötr zemin.
class AjanRozeti extends StatelessWidget {
  const AjanRozeti({
    super.key,
    required this.ajan,
    this.boyut = 28,
    this.calisiyor = false,
  });

  final String ajan;
  final double boyut;
  final bool calisiyor;

  @override
  Widget build(BuildContext context) {
    final r = Theme.of(context).colorScheme;
    final renk = Tema.ajanRengi(ajan);
    return SizedBox(
      width: boyut,
      height: boyut,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: boyut,
            height: boyut,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: renk.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(boyut * .3),
            ),
            child: Text(
              ajan == 'claude' ? 'C' : 'X',
              style: TextStyle(
                color: renk,
                fontWeight: FontWeight.w800,
                fontSize: boyut * .46,
              ),
            ),
          ),
          if (calisiyor)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: r.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: r.surfaceContainerLow, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Kaydırılabilir kod/çıktı kutusu.
class KodKutusu extends StatelessWidget {
  const KodKutusu({
    super.key,
    required this.metin,
    this.hata = false,
    this.enFazla = 260,
  });

  final String metin;
  final bool hata;
  final double enFazla;

  @override
  Widget build(BuildContext context) {
    final r = Theme.of(context).colorScheme;
    return Container(
      constraints: BoxConstraints(maxHeight: enFazla),
      width: double.infinity,
      decoration: BoxDecoration(
        color: hata ? r.errorContainer : r.surfaceContainerLowest,
        border: Border.all(color: r.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(10),
        child: SelectableText(
          metin.trimRight(),
          style: monospace.copyWith(
            fontSize: 12,
            height: 1.5,
            color: hata ? r.onErrorContainer : r.onSurface,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- diff

enum SatirTuru { ayni, eklendi, silindi, baslik }

class DiffSatiri {
  const DiffSatiri(this.tur, this.metin);
  final SatirTuru tur;
  final String metin;
}

/// İki metin arasındaki satır farkı (LCS). Büyük metinlerde basitçe
/// tamamı silindi/eklendi gösterilir.
List<DiffSatiri> satirFarki(String eski, String yeni) {
  final a = eski.split('\n');
  final b = yeni.split('\n');
  if (a.length * b.length > 250000) {
    return [
      for (final s in a) DiffSatiri(SatirTuru.silindi, s),
      for (final s in b) DiffSatiri(SatirTuru.eklendi, s),
    ];
  }
  final n = a.length, m = b.length;
  final l = List.generate(n + 1, (_) => List<int>.filled(m + 1, 0));
  for (var i = n - 1; i >= 0; i--) {
    for (var j = m - 1; j >= 0; j--) {
      l[i][j] = a[i] == b[j]
          ? l[i + 1][j + 1] + 1
          : (l[i + 1][j] > l[i][j + 1] ? l[i + 1][j] : l[i][j + 1]);
    }
  }
  final out = <DiffSatiri>[];
  var i = 0, j = 0;
  while (i < n && j < m) {
    if (a[i] == b[j]) {
      out.add(DiffSatiri(SatirTuru.ayni, a[i]));
      i++;
      j++;
    } else if (l[i + 1][j] >= l[i][j + 1]) {
      out.add(DiffSatiri(SatirTuru.silindi, a[i++]));
    } else {
      out.add(DiffSatiri(SatirTuru.eklendi, b[j++]));
    }
  }
  while (i < n) {
    out.add(DiffSatiri(SatirTuru.silindi, a[i++]));
  }
  while (j < m) {
    out.add(DiffSatiri(SatirTuru.eklendi, b[j++]));
  }
  return out;
}

/// Birleşik (unified) diff metnini satırlara ayırır.
List<DiffSatiri> birlesikFark(String diff) => [
  for (final s in diff.split('\n'))
    if (s.startsWith('+++') ||
        s.startsWith('---') ||
        s.startsWith('diff --git') ||
        s.startsWith('index ') ||
        s.startsWith('new file mode') ||
        s.startsWith('deleted file mode') ||
        s.startsWith('similarity index') ||
        s.startsWith('rename ') ||
        s.startsWith('\\ No newline'))
      DiffSatiri(SatirTuru.baslik, s)
    else if (s.startsWith('@@'))
      DiffSatiri(SatirTuru.baslik, s)
    else if (s.startsWith('+'))
      DiffSatiri(SatirTuru.eklendi, s.substring(1))
    else if (s.startsWith('-'))
      DiffSatiri(SatirTuru.silindi, s.substring(1))
    else
      DiffSatiri(SatirTuru.ayni, s.startsWith(' ') ? s.substring(1) : s),
];

/// Bir aracın girdisinden gösterilecek değişiklik: dosya yolu ve satırlar.
/// Değişiklik içermeyen girdilerde null döner.
List<(String yol, List<DiffSatiri> satirlar)>? girdidenFark(String girdi) {
  Object? j;
  try {
    j = jsonDecode(girdi);
  } catch (_) {
    return null;
  }
  if (j is! Map) return null;
  final yol = (j['file_path'] ?? j['notebook_path'] ?? j['path'] ?? '')
      .toString();
  if (j['old_string'] != null && j['new_string'] != null) {
    return [(yol, satirFarki('${j['old_string']}', '${j['new_string']}'))];
  }
  if (j['edits'] is List) {
    return [
      for (final e in (j['edits'] as List).cast<Map>())
        (yol, satirFarki('${e['old_string']}', '${e['new_string']}')),
    ];
  }
  if (j['content'] != null && yol.isNotEmpty) {
    return [
      (
        yol,
        [
          for (final s in '${j['content']}'.split('\n'))
            DiffSatiri(SatirTuru.eklendi, s),
        ],
      ),
    ];
  }
  if (j['changes'] is List) {
    return [
      for (final c in (j['changes'] as List).cast<Map>())
        ('${c['path'] ?? ''}', birlesikFark('${c['diff'] ?? ''}')),
    ];
  }
  return null;
}

class DiffGorunumu extends StatelessWidget {
  const DiffGorunumu({
    super.key,
    required this.yol,
    required this.satirlar,
    this.enFazla = 360,
  });

  final String yol;
  final List<DiffSatiri> satirlar;
  final double enFazla;

  @override
  Widget build(BuildContext context) {
    final r = Theme.of(context).colorScheme;
    final koyu = r.brightness == Brightness.dark;
    final yesil = koyu ? const Color(0xFF4ADE80) : const Color(0xFF15803D);
    final kirmizi = koyu ? const Color(0xFFF87171) : const Color(0xFFB91C1C);
    final eklenen = satirlar.where((s) => s.tur == SatirTuru.eklendi).length;
    final silinen = satirlar.where((s) => s.tur == SatirTuru.silindi).length;
    return Container(
      decoration: BoxDecoration(
        color: r.surfaceContainerLowest,
        border: Border.all(color: r.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (yol.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              color: r.surfaceContainer,
              child: Row(
                children: [
                  Icon(
                    Icons.description_outlined,
                    size: 14,
                    color: r.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      yol.split('/').last,
                      overflow: TextOverflow.ellipsis,
                      style: monospace.copyWith(
                        fontSize: 12,
                        color: r.onSurface,
                      ),
                    ),
                  ),
                  if (eklenen > 0)
                    Text(
                      '+$eklenen ',
                      style: TextStyle(
                        color: yesil,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  if (silinen > 0)
                    Text(
                      '−$silinen',
                      style: TextStyle(
                        color: kirmizi,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
            ),
          ConstrainedBox(
            constraints: BoxConstraints(maxHeight: enFazla),
            child: LayoutBuilder(
              builder: (context, kisit) => SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: kisit.maxWidth),
                    child: IntrinsicWidth(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final s in satirlar)
                            Container(
                              color: switch (s.tur) {
                                SatirTuru.eklendi => yesil.withValues(
                                  alpha: .12,
                                ),
                                SatirTuru.silindi => kirmizi.withValues(
                                  alpha: .12,
                                ),
                                SatirTuru.baslik => r.surfaceContainer,
                                SatirTuru.ayni => null,
                              },
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 1,
                              ),
                              child: Text(
                                '${switch (s.tur) {
                                  SatirTuru.eklendi => '+',
                                  SatirTuru.silindi => '−',
                                  SatirTuru.baslik => ' ',
                                  SatirTuru.ayni => ' ',
                                }} ${s.metin}',
                                style: monospace.copyWith(
                                  fontSize: 12,
                                  height: 1.5,
                                  color: switch (s.tur) {
                                    SatirTuru.eklendi => yesil,
                                    SatirTuru.silindi => kirmizi,
                                    SatirTuru.baslik => r.onSurfaceVariant,
                                    SatirTuru.ayni => r.onSurface,
                                  },
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
