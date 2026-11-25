import 'package:flutter/material.dart';

import '../model/calisma.dart';
import 'ayar_paneli.dart';
import 'mesaj_kutusu.dart';
import 'ortak.dart';

/// Köprü model listesini veremezse (eski köprü, bağlantı yok) kullanılan
/// yerleşik liste. Claude CLI takma adları her zaman en güncel modele gider.
const _yedekModeller = <String, List<Map<String, dynamic>>>{
  'claude': [
    {
      'id': 'opus',
      'ad': 'Opus',
      'aciklama': 'En güçlü, karmaşık işler',
      'effortlar': _claudeEffort,
    },
    {
      'id': 'sonnet',
      'ad': 'Sonnet',
      'aciklama': 'Hızlı ve dengeli',
      'effortlar': _claudeEffort,
    },
    {
      'id': 'fable',
      'ad': 'Fable',
      'aciklama': 'Uzun ve derin işler',
      'effortlar': _claudeEffort,
    },
    {
      'id': 'haiku',
      'ad': 'Haiku',
      'aciklama': 'En hızlı, basit işler',
      'effortlar': _claudeEffort,
    },
  ],
};
const _claudeEffort = ['low', 'medium', 'high', 'xhigh', 'max'];
const _yedekEffort = ['low', 'medium', 'high', 'xhigh'];
const _effortAdlari = {
  'minimal': 'En az',
  'low': 'Düşük',
  'medium': 'Orta',
  'high': 'Yüksek',
  'xhigh': 'Çok yüksek',
  'max': 'En yüksek',
  'ultra': 'Ultra',
};

/// Bir ajanın o anki ayarları; panel her açılışta ve her seçimde güncel
/// değerleri okusun diye fonksiyon olarak verilir.
typedef AjanAyari = ({String ajan, String? model, String? effort, String mod});

/// Bir rolün (ör. Yankı'da ses ajanı, işi yapan, yazılı mesajlar) model ve
/// düşünme gücü çipi: sohbetteki model çipinin aynısı, onay biçimi olmadan.
/// [sec] her seçimde iki değeri birlikte verir.
Widget modelCipi({
  required Calisma calisma,
  required String ajan,
  required String? model,
  required String? effort,
  required void Function(String? model, String? effort) sec,
  String? altBaslik,
  bool rozet = true,
  bool etkin = true,
}) => Builder(
  builder: (context) {
    final b = _ajanBilgisi(calisma, ajan, model);
    final modelAdi = model == null
        ? (b.secili != null ? '${b.secili!['ad']}' : 'Varsayılan')
        : '${b.secili?['ad'] ?? model}';
    final sira = effort == null ? 0 : b.effortlar.indexOf(effort) + 1;
    void ac() {
      var m = model, e = effort;
      ayarPaneliAc(
        context,
        baslik: ajanAdi(ajan),
        altBaslik: altBaslik,
        onde: AjanRozeti(ajan: ajan, boyut: 32),
        dinle: calisma,
        bolumler: () => [
          for (final bolum in ajanAyarBolumleri(
            calisma: calisma,
            ajan: ajan,
            model: m,
            effort: e,
            mod: 'otomatik',
            modelSec: (v) {
              m = v;
              e = uygunEffort(calisma, ajan, v, e);
              sec(m, e);
            },
            effortSec: (v) {
              e = v;
              sec(m, e);
            },
            modSec: (_) {},
          ))
            if (bolum.baslik != 'Onay biçimi') bolum,
        ],
      );
    }

    return AracDugmesi(
      ipucu: '${ajanAdi(ajan)}: model ve düşünme gücü',
      onTap: etkin ? ac : null,
      cocuklar: [
        if (rozet) ...[
          AjanRozeti(ajan: ajan, boyut: 16),
          const SizedBox(width: 6),
        ],
        Flexible(child: Text(modelAdi)),
        const SizedBox(width: 7),
        EforCubugu(seviye: seviyeCubugu(sira, b.effortlar.length + 1)),
        const SizedBox(width: 3),
        Icon(
          Icons.expand_more,
          size: 16,
          color: Theme.of(context).colorScheme.outline,
        ),
      ],
    );
  },
);

/// Mesaj kutusunun araç satırındaki iki düğme: model + düşünme gücü
/// (`Sol ▂▄▆ ⌄`) ve onay biçimi (`Otomatik`). İkisi de aynı alt paneli açar.
({Widget model, Widget bicim}) ajanAraclari({
  required Calisma calisma,
  required AjanAyari Function() ayar,
  required void Function(String? model) modelSec,
  required void Function(String? effort) effortSec,
  required void Function(String mod) modSec,
  String altBaslik = 'Bu oturumun ayarları',
  Listenable? dinle,
  bool etkin = true,
}) {
  final a = ayar();
  final b = _ajanBilgisi(calisma, a.ajan, a.model);
  final modelAdi = a.model == null
      ? (b.secili != null ? '${b.secili!['ad']}' : 'Varsayılan model')
      : '${b.secili?['ad'] ?? a.model}';
  final sira = a.effort == null ? 0 : b.effortlar.indexOf(a.effort!) + 1;
  final bc = bicim(a.mod);

  void ac(BuildContext context) => ayarPaneliAc(
    context,
    baslik: ajanAdi(ayar().ajan),
    altBaslik: altBaslik,
    onde: AjanRozeti(ajan: ayar().ajan, boyut: 32),
    dinle: Listenable.merge([calisma, ?dinle]),
    bolumler: () {
      final g = ayar();
      return ajanAyarBolumleri(
        calisma: calisma,
        ajan: g.ajan,
        model: g.model,
        effort: g.effort,
        mod: g.mod,
        modelSec: modelSec,
        effortSec: effortSec,
        modSec: modSec,
      );
    },
  );

  return (
    model: Builder(
      builder: (context) => AracDugmesi(
        ipucu: 'Model ve düşünme gücü',
        onTap: etkin ? () => ac(context) : null,
        cocuklar: [
          Flexible(child: Text(modelAdi)),
          const SizedBox(width: 7),
          EforCubugu(seviye: seviyeCubugu(sira, b.effortlar.length + 1)),
          const SizedBox(width: 3),
          Icon(
            Icons.expand_more,
            size: 16,
            color: Theme.of(context).colorScheme.outline,
          ),
        ],
      ),
    ),
    bicim: Builder(
      builder: (context) {
        final r = Theme.of(context).colorScheme;
        return AracDugmesi(
          ipucu: 'Onay biçimi: ${bc.$2}',
          onTap: etkin ? () => ac(context) : null,
          renk: a.mod == 'serbest'
              ? (r.brightness == Brightness.dark
                    ? const Color(0xFFFBBF24)
                    : const Color(0xFFB45309))
              : r.onSurfaceVariant,
          // Telefonda yalnız simge: yazma kutusunun alt satırında model
          // çipine yer kalsın (iş sürerken Durdur düğmesi de eklenir).
          cocuklar: MediaQuery.sizeOf(context).width < 420
              ? [Icon(bc.$4)]
              : [Icon(bc.$4), const SizedBox(width: 6), Text(bc.$2)],
        );
      },
    ),
  );
}

const _effortAciklamalari = {
  'minimal': 'En kısa düşünme.',
  'low': 'Hızlı yanıt, az düşünme.',
  'medium': 'Çoğu iş için dengeli.',
  'high': 'Zor hatalar ve tasarım işleri için.',
  'xhigh': 'Çok kapsamlı düşünme; yavaş.',
  'max': 'En derin düşünme; en yavaş ve en pahalı.',
};

/// Ayar panelinin bölümleri: model, düşünme gücü ve onay biçimi.
/// Boş değer ('') CLI'ın kendi varsayılanı demektir.
List<AyarBolumu> ajanAyarBolumleri({
  required Calisma calisma,
  required String ajan,
  required String? model,
  required String? effort,
  required String mod,
  required void Function(String? model) modelSec,
  required void Function(String? effort) effortSec,
  required void Function(String mod) modSec,
}) {
  final b = _ajanBilgisi(calisma, ajan, model);
  String effortAdi(String e) =>
      calisma.effortAdlari[e] ?? _effortAdlari[e] ?? e;
  final varsayilanEffort = b.secili?['varsayilan_effort'] as String?;
  return [
    AyarBolumu(
      baslik: 'Model',
      secili: model ?? '',
      rozetler: {
        for (final m in b.modeller)
          if (m['varsayilan'] == true) m['id'] as String: 'varsayılan',
      },
      secenekler: [
        (
          '',
          'Varsayılan',
          ajan == 'claude'
              ? 'Claude ayarlarındaki model'
              : 'Codex ayarlarındaki model',
          true,
        ),
        for (final m in b.modeller)
          (
            m['id'] as String,
            '${m['ad']}',
            (m['aciklama'] as String?)?.isNotEmpty == true
                ? m['aciklama'] as String
                : null,
            true,
          ),
      ],
      secildi: (v) {
        modelSec(v.isEmpty ? null : v);
      },
    ),
    if (b.effortlar.isNotEmpty)
      AyarBolumu(
        baslik: 'Düşünme gücü',
        bicim: AyarBicimi.seviye,
        secili: effort ?? '',
        secenekler: [
          (
            '',
            'Varsayılan',
            varsayilanEffort != null
                ? 'Modelin varsayılanı kullanılır: ${effortAdi(varsayilanEffort)}.'
                : 'Modelin varsayılanı kullanılır.',
            true,
          ),
          for (final e in b.effortlar)
            (e, effortAdi(e), _effortAciklamalari[e], true),
        ],
        secildi: (v) => effortSec(v.isEmpty ? null : v),
      ),
    AyarBolumu(
      baslik: 'Onay biçimi',
      secili: mod,
      simgeler: {for (final c in calismaBicimleri) c.$1: c.$4},
      secenekler: [for (final c in calismaBicimleri) (c.$1, c.$2, c.$3, true)],
      secildi: modSec,
    ),
  ];
}

({
  List<Map<String, dynamic>> modeller,
  Map<String, dynamic>? secili,
  List<String> effortlar,
})
_ajanBilgisi(Calisma calisma, String ajan, String? model) {
  var modeller = calisma.modeller[ajan] ?? const <Map<String, dynamic>>[];
  if (modeller.isEmpty) {
    calisma.modelleriYukle(ajan);
    modeller = _yedekModeller[ajan] ?? const [];
  }
  final secili =
      modeller.where((m) => m['id'] == model).firstOrNull ??
      (model == null
          ? modeller.where((m) => m['varsayilan'] == true).firstOrNull
          : null);
  final effortlar =
      ((secili ?? modeller.firstOrNull)?['effortlar'] as List?)
          ?.cast<String>() ??
      _yedekEffort;
  return (modeller: modeller, secili: secili, effortlar: effortlar);
}

/// Model değişince, yeni modelin desteklemediği effort sıfırlanır.
String? uygunEffort(Calisma c, String ajan, String? model, String? effort) {
  if (effort == null) return null;
  final m = (c.modeller[ajan] ?? const [])
      .where((x) => x['id'] == model)
      .firstOrNull;
  final destek = (m?['effortlar'] as List?)?.cast<String>();
  return destek == null || destek.contains(effort) ? effort : null;
}
