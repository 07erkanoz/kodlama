import 'package:flutter/material.dart';

import '../model/calisma.dart';
import 'mesaj_kutusu.dart';

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

/// Mesaj kutusunun altındaki ajan ayarları: model, düşünme gücü (effort) ve
/// çalışma biçimi. Boş seçim (null) CLI'ın kendi varsayılanı demektir.
List<Widget> ajanAyarCipleri({
  required Calisma calisma,
  required String ajan,
  required String? model,
  required String? effort,
  required String mod,
  required void Function(String? model) modelSec,
  required void Function(String? effort) effortSec,
  required void Function(String mod) modSec,
  bool etkin = true,
}) {
  var modeller = calisma.modeller[ajan] ?? const <Map<String, dynamic>>[];
  if (modeller.isEmpty) {
    calisma.modelleriYukle(ajan);
    modeller = _yedekModeller[ajan] ?? const [];
  }
  final seciliModel =
      modeller.where((m) => m['id'] == model).firstOrNull ??
      (model == null
          ? modeller.where((m) => m['varsayilan'] == true).firstOrNull
          : null);
  final effortlar =
      ((seciliModel ?? modeller.firstOrNull)?['effortlar'] as List?)
          ?.cast<String>() ??
      _yedekEffort;
  String effortAdi(String e) =>
      calisma.effortAdlari[e] ?? _effortAdlari[e] ?? e;

  return [
    SecimCipi<String>(
      simge: const Icon(Icons.auto_awesome_outlined),
      etiket: model == null
          ? (seciliModel != null ? '${seciliModel['ad']}' : 'Varsayılan model')
          : '${modeller.where((m) => m['id'] == model).firstOrNull?['ad'] ?? model}',
      ipucu: 'Model',
      etkin: etkin,
      secili: model ?? '',
      secenekler: [
        ('', 'Varsayılan', 'CLI\'ın ayarındaki model', true),
        for (final m in modeller)
          (
            m['id'] as String,
            '${m['ad']}${m['varsayilan'] == true ? ' · varsayılan' : ''}',
            (m['aciklama'] as String?)?.isNotEmpty == true
                ? m['aciklama'] as String
                : null,
            true,
          ),
      ],
      secildi: (v) => modelSec(v.isEmpty ? null : v),
    ),
    if (effortlar.isNotEmpty)
      SecimCipi<String>(
        simge: const Icon(Icons.psychology_outlined),
        etiket: effort == null
            ? 'Düşünme: varsayılan'
            : 'Düşünme: ${effortAdi(effort)}',
        ipucu: 'Düşünme gücü (effort)',
        etkin: etkin,
        secili: effort ?? '',
        secenekler: [
          (
            '',
            'Varsayılan',
            seciliModel?['varsayilan_effort'] != null
                ? 'Modelin varsayılanı: ${effortAdi(seciliModel!['varsayilan_effort'] as String)}'
                : 'CLI\'ın ayarı',
            true,
          ),
          for (final e in effortlar) (e, effortAdi(e), null, true),
        ],
        secildi: (v) => effortSec(v.isEmpty ? null : v),
      ),
    SecimCipi<String>(
      simge: Icon(bicim(mod).$4),
      etiket: bicim(mod).$2,
      ipucu: 'Çalışma biçimi',
      etkin: etkin,
      secili: mod,
      secenekler: [for (final b in calismaBicimleri) (b.$1, b.$2, b.$3, true)],
      secildi: modSec,
    ),
  ];
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
