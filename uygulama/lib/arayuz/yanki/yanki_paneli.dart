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

  Widget _govde(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    final c = widget.calisma;
    final a = c.ayarlar;
    final s = widget.secim();
    final kucuk = t.textTheme.bodySmall?.copyWith(color: r.onSurfaceVariant);

    Widget bolum(String ad, String? aciklama, List<Widget> icerik) => Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ad,
            style: t.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (aciklama != null) ...[
            const SizedBox(height: 2),
            Text(aciklama, style: kucuk),
          ],
          const SizedBox(height: 8),
          ...icerik,
        ],
      ),
    );

    Widget ajanSecici(String deger, void Function(String) sec) =>
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 'codex', label: Text('Codex')),
            ButtonSegment(value: 'claude', label: Text('Claude')),
          ],
          selected: {deger},
          onSelectionChanged: _yaziyor ? null : (v) => sec(v.first),
        );

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
        bolum(
          'Ses ajanı',
          'Sesin işi devrettiği Codex. Ses Codex\'in realtime sesidir; '
              'aradaki ajan için düşük güç çoğu zaman yeter.',
          [
            Align(
              alignment: Alignment.centerLeft,
              child: modelCipi(
                calisma: c,
                ajan: 'codex',
                model: s.ajanModel,
                effort: s.ajanEffort,
                altBaslik: 'Yankı · ses ajanı',
                etkin: !_yaziyor,
                sec: (m, e) =>
                    _degis(s.kopya(ajanModel: () => m, ajanEffort: () => e)),
              ),
            ),
          ],
        ),
        bolum(
          'Sesle istenen işi yapan',
          s.isci == 'claude'
              ? 'Ses ajanı işi claude_sor aracıyla Claude\'a verir, sonucu sese aktarır.'
              : 'Ses ajanı işi kendisi yapar; Claude çalışmaz.',
          [
            ajanSecici(s.isci, (v) => _degis(s.kopya(isci: v))),
            if (s.isci == 'claude') ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: modelCipi(
                  calisma: c,
                  ajan: 'claude',
                  model: s.claudeModel ?? 'opus',
                  effort: s.claudeEffort,
                  altBaslik: 'Yankı · işi yapan',
                  etkin: !_yaziyor,
                  sec: (m, e) => _degis(
                    s.kopya(claudeModel: () => m, claudeEffort: () => e),
                  ),
                ),
              ),
            ],
          ],
        ),
        bolum(
          'Yazılı mesajlar',
          s.yazili == 'claude'
              ? 'Yazdıkların Codex\'e uğramadan Claude\'a gider; Claude sesle verilen işlerle aynı sohbeti sürdürür.'
              : 'Yazdıklarını Codex yanıtlar (ses ajanıyla aynı konuşma).',
          [
            ajanSecici(
              s.yazili,
              // ajan değişince model adları değişir: model ve güç sıfırlanır
              (v) => _degis(
                s.kopya(
                  yazili: v,
                  yaziliModel: () => null,
                  yaziliEffort: () => null,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: modelCipi(
                calisma: c,
                ajan: s.yazili,
                model: s.yaziliModel,
                effort: s.yaziliEffort,
                altBaslik: s.yazili == 'claude'
                    ? 'Varsayılan: işi yapan Claude\'unki'
                    : 'Varsayılan: ses ajanınınki',
                etkin: !_yaziyor,
                sec: (m, e) => _degis(
                  s.kopya(yaziliModel: () => m, yaziliEffort: () => e),
                ),
              ),
            ),
          ],
        ),
        bolum(
          'Sese durum bildirimi',
          'Ses açıkken Claude\'un ne yaptığı sese iletilsin mi. Her adım, konuşmayı bölebilir.',
          [
            SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: 'kapali', label: Text('Kapalı')),
                ButtonSegment(value: 'onemli', label: Text('Önemli anlar')),
                ButtonSegment(value: 'hepsi', label: Text('Her adım')),
              ],
              selected: {s.durumNotu},
              onSelectionChanged: _yaziyor
                  ? null
                  : (v) => _degis(s.kopya(durumNotu: v.first)),
            ),
            const SizedBox(height: 4),
            Text(
              'Önemli anlar: Claude onay beklediğinde ve yazılı bir işi bitirdiğinde.',
              style: kucuk,
            ),
          ],
        ),
        bolum('Ses', 'Bütün sesli konuşmalarda geçerli.', [
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
          const SizedBox(height: 12),
          TextField(
            controller: _sesModeli,
            decoration: const InputDecoration(
              labelText: 'Ses modeli',
              hintText: 'Boş: Codex\'in ayarı (config.toml)',
              helperText: 'Yalnız ses için, ör. gpt-realtime.',
            ),
            onChanged: (v) => a.sesModeli = v.trim(),
          ),
        ]),
      ],
    );
  }
}
