import 'package:flutter/material.dart';

import '../../model/calisma.dart';
import '../../model/sesli_konusma.dart';
import '../../model/yanki_secimi.dart';
import '../ajan_ayarlari.dart';
import '../ayar_paneli.dart';
import 'yanki_figur.dart';

export '../../model/yanki_secimi.dart';

/// Yazma kutusundaki tek Yankı çipi: dokununca bütün rollerin paneli açılır.
Widget yankiCipi({
  required Calisma calisma,
  required YankiSecimi Function() secim,
  required Future<void> Function(YankiSecimi yeni) degisti,
  Listenable? dinle,
  bool etkin = true,
  String altBaslik = 'Bu sohbetin seçimleri; yeni oturumlar için de hatırlanır',
}) => Builder(
  builder: (context) => AracDugmesi(
    ipucu: 'Yankı: ses, ses ajanı, işi yapan, yazılı mesajlar',
    onTap: etkin
        ? () => yankiPaneliAc(
            context,
            calisma: calisma,
            secim: secim,
            degisti: degisti,
            dinle: dinle,
            altBaslik: altBaslik,
          )
        : null,
    cocuklar: [
      const Icon(Icons.graphic_eq_rounded),
      const SizedBox(width: 6),
      Flexible(child: Text(secim().ozet)),
      const SizedBox(width: 3),
      Icon(
        Icons.expand_more,
        size: 16,
        color: Theme.of(context).colorScheme.outline,
      ),
    ],
  ),
);

Future<void> yankiPaneliAc(
  BuildContext context, {
  required Calisma calisma,
  required YankiSecimi Function() secim,
  required Future<void> Function(YankiSecimi yeni) degisti,
  Listenable? dinle,
  String? altBaslik,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  backgroundColor: Theme.of(context).colorScheme.surface,
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
  ),
  builder: (context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .88,
    ),
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: YankiAyarlari(
        calisma: calisma,
        secim: secim,
        degisti: degisti,
        dinle: dinle,
        baslik: true,
        altBaslik: altBaslik,
      ),
    ),
  ),
);

/// Yankı ayarlarının gövdesi: alttan açılan panelde ve Ayarlar ekranında
/// aynısı. [secim] her değişiklikten sonra yeniden okunur.
class YankiAyarlari extends StatefulWidget {
  const YankiAyarlari({
    super.key,
    required this.calisma,
    required this.secim,
    required this.degisti,
    this.dinle,
    this.baslik = false,
    this.altBaslik,
  });

  final Calisma calisma;
  final YankiSecimi Function() secim;
  final Future<void> Function(YankiSecimi yeni) degisti;
  final Listenable? dinle;
  final bool baslik;
  final String? altBaslik;

  @override
  State<YankiAyarlari> createState() => _YankiAyarlariState();
}

class _YankiAyarlariState extends State<YankiAyarlari> {
  late final _sesModeli = TextEditingController(
    text: widget.calisma.ayarlar.sesModeli,
  );
  bool _yaziyor = false;

  @override
  void dispose() {
    _sesModeli.dispose();
    super.dispose();
  }

  Future<void> _degis(YankiSecimi yeni) async {
    setState(() => _yaziyor = true);
    try {
      await widget.degisti(yeni);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Değiştirilemedi: $e')));
      }
    } finally {
      if (mounted) setState(() => _yaziyor = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([widget.calisma, ?widget.dinle]),
    builder: (context, _) => _govde(context),
  );

  bool _gelismis = false;

  Widget _govde(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    final c = widget.calisma;
    final a = c.ayarlar;
    final s = widget.secim();
    final kucuk = t.textTheme.bodySmall?.copyWith(color: r.onSurfaceVariant);
    final etkin = !_yaziyor;

    // Üç düzen: hepsi Codex, Codex konuşur Claude çalışır, ya da karışık.
    final duzen = s.isci == 'codex' && s.yazili == 'codex'
        ? 'codex'
        : s.isci == 'claude' && s.yazili == 'claude'
        ? 'claude'
        : 'karisik';
    final claudeVar = s.isci == 'claude' || s.yazili == 'claude';

    Widget baslik(String ad) => Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 8),
      child: Text(
        ad,
        style: t.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    );

    Widget kart(
      String deger,
      IconData simge,
      String ad,
      String aciklama,
      VoidCallback sec,
    ) {
      final secili = duzen == deger;
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          color: secili ? r.secondaryContainer : r.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: etkin ? sec : null,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              child: Row(
                children: [
                  Icon(
                    simge,
                    color: secili ? r.onSecondaryContainer : r.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ad,
                          style: t.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(aciklama, style: kucuk),
                      ],
                    ),
                  ),
                  Icon(
                    secili
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    color: secili ? r.primary : r.outline,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    Widget modelSatiri(String ad, String ne, Widget cip) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ad, style: t.textTheme.bodyLarge),
                Text(ne, style: kucuk),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Flexible(child: cip),
        ],
      ),
    );

    Widget ikili(String deger, void Function(String) sec) =>
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 'codex', label: Text('Codex')),
            ButtonSegment(value: 'claude', label: Text('Claude')),
          ],
          selected: {deger},
          onSelectionChanged: etkin ? (v) => sec(v.first) : null,
        );

    final akis = switch (duzen) {
      'codex' => 'Sen konuşursun → Codex dinler, işi yapar, söyler.',
      'claude' => 'Sen konuşursun → Codex dinler → Claude yapar → Codex söyler. Yazdıkların doğrudan Claude\'a gider.',
      _ =>
        'Sesle istenen işi ${s.isci == 'claude' ? 'Claude' : 'Codex'}, yazdıklarını ${s.yazili == 'claude' ? 'Claude' : 'Codex'} yapar.',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.baslik) ...[
          Row(
            children: [
              const Icon(Icons.graphic_eq_rounded),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Yankı',
                  style: t.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (_yaziyor)
                const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          if (widget.altBaslik != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(widget.altBaslik!, style: kucuk),
            ),
        ],
        baslik('Kim ne yapsın'),
        kart(
          'codex',
          Icons.record_voice_over_outlined,
          'Hepsi Codex',
          'Codex hem konuşur hem işi yapar. En az kota.',
          () => _degis(
            s.kopya(
              isci: 'codex',
              yazili: 'codex',
              yaziliModel: () => null,
              yaziliEffort: () => null,
            ),
          ),
        ),
        kart(
          'claude',
          Icons.engineering_outlined,
          'Codex konuşur, Claude çalışır',
          'Sesle ve yazıyla istediğin işi Claude yapar.',
          () => _degis(
            s.kopya(
              isci: 'claude',
              yazili: 'claude',
              yaziliModel: () => null,
              yaziliEffort: () => null,
            ),
          ),
        ),
        if (duzen == 'karisik')
          kart(
            'karisik',
            Icons.tune_rounded,
            'Karışık',
            'Ayrıntısı Gelişmiş\'te.',
            () => setState(() => _gelismis = true),
          ),
        Text(akis, style: kucuk),
        baslik('Modeller'),
        modelSatiri(
          'Codex',
          duzen == 'codex'
              ? 'Dinler, konuşur ve işi yapar'
              : 'Dinler ve işi Claude\'a anlatır; düşük güç yeter',
          modelCipi(
            calisma: c,
            ajan: 'codex',
            model: s.ajanModel,
            effort: s.ajanEffort,
            altBaslik: 'Yankı · Codex',
            etkin: etkin,
            sec: (m, e) =>
                _degis(s.kopya(ajanModel: () => m, ajanEffort: () => e)),
          ),
        ),
        if (claudeVar)
          modelSatiri(
            'Claude',
            'İşi yapar: düzenler, üretir, araştırır',
            modelCipi(
              calisma: c,
              ajan: 'claude',
              model: s.claudeModel ?? 'opus',
              effort: s.claudeEffort,
              altBaslik: 'Yankı · Claude',
              etkin: etkin,
              sec: (m, e) =>
                  _degis(s.kopya(claudeModel: () => m, claudeEffort: () => e)),
            ),
          ),
        baslik('Ses ve görünüm'),
        DropdownButtonFormField<String>(
          initialValue: gecerliSes(a.sesSesi) ?? '',
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Ses'),
          items: [
            const DropdownMenuItem(
              value: '',
              child: Text('Codex\'in varsayılanı'),
            ),
            for (final v in codexSesleri)
              DropdownMenuItem(
                value: v.$1,
                child: Text(v.$2.isEmpty ? v.$1 : '${v.$1} · ${v.$2}'),
              ),
          ],
          onChanged: (v) => setState(() => a.sesSesi = v ?? ''),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: a.sesDili,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Konuşma dili'),
          items: const [
            DropdownMenuItem(value: 'tr', child: Text('Türkçe')),
            DropdownMenuItem(value: 'en', child: Text('English')),
            DropdownMenuItem(value: '', child: Text('Benim konuştuğum dil')),
          ],
          onChanged: (v) => setState(() => a.sesDili = v ?? 'tr'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: a.sesGorunumu,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Görünüm'),
          items: [
            for (final (d, ad, aciklama) in sesGorunumleri)
              DropdownMenuItem(value: d, child: Text('$ad · $aciklama')),
          ],
          onChanged: (v) => setState(() => a.sesGorunumu = v ?? 'yanki'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Konuşmada tam ekran'),
          subtitle: const Text(
            'Mikrofona basınca Yankı ekranı açılır; saat ve gezinme çubukları gizlenir.',
          ),
          value: a.sesTamEkran,
          onChanged: a.sesGorunumu == 'sade'
              ? null
              : (v) => setState(() => a.sesTamEkran = v),
        ),
        const SizedBox(height: 8),
        Theme(
          data: t.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: ValueKey(_gelismis),
            initiallyExpanded: _gelismis,
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(bottom: 8),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            title: const Text('Gelişmiş'),
            subtitle: Text(
              'Rolleri ayrı ayrı seç, sese durum bildirimi, ses modeli',
              style: kucuk,
            ),
            children: [
              const SizedBox(height: 4),
              Text(
                'Sesle istediğin işi kim yapsın',
                style: t.textTheme.bodyMedium,
              ),
              const SizedBox(height: 6),
              ikili(s.isci, (v) => _degis(s.kopya(isci: v))),
              const SizedBox(height: 16),
              Text(
                'Yazdıklarını kim yanıtlasın',
                style: t.textTheme.bodyMedium,
              ),
              const SizedBox(height: 6),
              ikili(
                s.yazili,
                (v) => _degis(
                  s.kopya(
                    yazili: v,
                    yaziliModel: () => null,
                    yaziliEffort: () => null,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              modelSatiri(
                'Yazılı mesaj modeli',
                'Boş bırakırsan yukarıdaki ${s.yazili == 'claude' ? 'Claude' : 'Codex'} modeli',
                modelCipi(
                  calisma: c,
                  ajan: s.yazili,
                  model: s.yaziliModel,
                  effort: s.yaziliEffort,
                  altBaslik: 'Yankı · yazılı mesajlar',
                  etkin: etkin,
                  sec: (m, e) => _degis(
                    s.kopya(yaziliModel: () => m, yaziliEffort: () => e),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ses açıkken Claude\'un durumunu söylesin',
                style: t.textTheme.bodyMedium,
              ),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: 'kapali', label: Text('Hayır')),
                  ButtonSegment(value: 'onemli', label: Text('Önemli anlar')),
                  ButtonSegment(value: 'hepsi', label: Text('Her adım')),
                ],
                selected: {s.durumNotu},
                onSelectionChanged: etkin
                    ? (v) => _degis(s.kopya(durumNotu: v.first))
                    : null,
              ),
              const SizedBox(height: 4),
              Text(
                'Önemli anlar: onay beklerken ve yazılı iş bitince. Her adım konuşmayı bölebilir.',
                style: kucuk,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _sesModeli,
                decoration: const InputDecoration(
                  labelText: 'Ses modeli',
                  hintText: 'Boş: Codex\'in ayarı',
                  helperText: 'Yalnız ses için, ör. gpt-realtime.',
                ),
                onChanged: (v) => a.sesModeli = v.trim(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
