import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../arayuz/markdown.dart';
import '../arayuz/mesaj_kutusu.dart';
import '../arayuz/ortak.dart';
import '../model/calisma.dart';
import '../model/sohbet.dart';
import 'onizleme.dart';

/// Sohbetin ekrandaki birimi: tek tek öğeler değil, okunur gruplar.
sealed class _Blok {}

class _KullaniciBlok extends _Blok {
  _KullaniciBlok(this.oge);
  final KullaniciOge oge;
}

class _AjanBasligi extends _Blok {}

class _MetinBlok extends _Blok {
  _MetinBlok(this.oge);
  final MetinOge oge;
}

class _EtkinlikBlok extends _Blok {
  _EtkinlikBlok(this.araclar);
  final List<AracOge> araclar;
}

class _OnayBlok extends _Blok {
  _OnayBlok(this.oge);
  final OnayOge oge;
}

class _DosyaBlok extends _Blok {
  _DosyaBlok(this.dosyalar);
  final List<DosyaOge> dosyalar;
}

class _BittiBlok extends _Blok {
  _BittiBlok(this.oge);
  final BittiOge oge;
}

class _UyariBlok extends _Blok {
  _UyariBlok(this.metin);
  final String metin;
}

List<_Blok> _bloklar(List<Oge> ogeler) {
  final out = <_Blok>[];
  var turBasi = true;
  for (final o in ogeler) {
    if (o is! KullaniciOge && turBasi) {
      out.add(_AjanBasligi());
      turBasi = false;
    }
    switch (o) {
      case KullaniciOge():
        out.add(_KullaniciBlok(o));
        turBasi = true;
      case MetinOge():
        out.add(_MetinBlok(o));
      case AracOge():
        if (out.lastOrNull case _EtkinlikBlok(:final araclar)) {
          araclar.add(o);
        } else {
          out.add(_EtkinlikBlok([o]));
        }
      case OnayOge():
        out.add(_OnayBlok(o));
      case DosyaOge():
        if (out.lastOrNull case _DosyaBlok(:final dosyalar)) {
          dosyalar.removeWhere((d) => d.yol == o.yol);
          dosyalar.add(o);
        } else {
          out.add(_DosyaBlok([o]));
        }
      case BittiOge():
        out.add(_BittiBlok(o));
      case UyariOge():
        out.add(_UyariBlok(o.metin));
    }
  }
  return out;
}

/// Sohbet: ajanın yazdıkları zengin metin; araç adımları tek bir etkinlik
/// satırında; düzenlemeler ve onaylar diff olarak; üretilen dosyalar
/// önizlenebilir çipler olarak.
class SohbetGorunumu extends StatefulWidget {
  const SohbetGorunumu({
    super.key,
    required this.calisma,
    required this.sohbet,
    this.dosyaAc,
  });

  final Calisma calisma;
  final Sohbet sohbet;
  final void Function(String yol)? dosyaAc;

  @override
  State<SohbetGorunumu> createState() => _SohbetGorunumuState();
}

class _SohbetGorunumuState extends State<SohbetGorunumu> {
  final _yazi = TextEditingController();
  final _ekler = <String>[];
  bool _ekYukleniyor = false;

  Sohbet get s => widget.sohbet;

  void _dosyaAc(String yol) {
    if (s.sunucu != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$yol ${s.sunucu} sunucusunda; uzak dosyalar henüz önizlenemiyor.',
          ),
        ),
      );
      return;
    }
    final tam = yol.startsWith('/') ? yol : '${s.cwd}/$yol';
    if (widget.dosyaAc != null) {
      widget.dosyaAc!(tam);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OnizlemeSayfasi(calisma: widget.calisma, yol: tam),
        ),
      );
    }
  }

  Future<void> _gonder() async {
    final metin = _yazi.text.trim();
    if (metin.isEmpty && _ekler.isEmpty) return;
    final ekler = List<String>.of(_ekler);
    _yazi.clear();
    setState(_ekler.clear);
    try {
      await s.gonder(metin, ekler: ekler);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gönderilemedi: $e')));
      }
    }
  }

  Future<void> _ekSec() async {
    final secilen = await FilePicker.pickFiles();
    if (secilen.isEmpty) return;
    setState(() => _ekYukleniyor = true);
    try {
      for (final f in secilen) {
        final yol = await s.ekYukle(
          f.name,
          base64Encode(await f.readAsBytes()),
        );
        setState(() => _ekler.add(yol));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ek yüklenemedi: $e')));
      }
    } finally {
      if (mounted) setState(() => _ekYukleniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final bloklar = _bloklar(s.ogeler);
        final say = bloklar.length + (s.calisiyor ? 1 : 0);
        return Column(
          children: [
            Expanded(
              child: s.yukleniyor
                  ? const Center(child: CircularProgressIndicator())
                  : bloklar.isEmpty
                  ? _Bos(sohbet: s)
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      itemCount: say,
                      itemBuilder: (context, i) {
                        if (s.calisiyor && i == 0) {
                          return _sar(_Calisiyor(sohbet: s));
                        }
                        final b =
                            bloklar[bloklar.length -
                                1 -
                                (i - (s.calisiyor ? 1 : 0))];
                        return _sar(_blok(b));
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SafeArea(
                top: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 780),
                    child: MesajKutusu(
                      denetleyici: _yazi,
                      gonder: _gonder,
                      durdur: s.durdur,
                      calisiyor: s.calisiyor,
                      ekle: _ekSec,
                      ekler: _ekler,
                      ekYukleniyor: _ekYukleniyor,
                      ekKaldir: (e) => setState(() => _ekler.remove(e)),
                      ipucu: s.calisiyor
                          ? 'Araya yaz — çalışan işe eklenir'
                          : 'Devam et…',
                      cipler: [
                        SecimCipi<String>(
                          simge: Icon(bicim(s.mod).$4),
                          etiket: bicim(s.mod).$2,
                          ipucu: 'Çalışma biçimi',
                          etkin: !s.calisiyor,
                          secili: s.mod,
                          secenekler: [
                            for (final b in calismaBicimleri)
                              (b.$1, b.$2, b.$3, true),
                          ],
                          secildi: s.modDegistir,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _sar(Widget w) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 780),
      child: SizedBox(width: double.infinity, child: w),
    ),
  );

  Widget _blok(_Blok b) => switch (b) {
    _KullaniciBlok(:final oge) => _KullaniciBalonu(oge: oge, dosyaAc: _dosyaAc),
    _AjanBasligi() => _AjanSatiri(ajan: s.ajan),
    _MetinBlok(:final oge) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Markdown(oge.metin, size: 15, onLink: _dosyaAc),
    ),
    _EtkinlikBlok(:final araclar) => _Etkinlik(araclar: araclar),
    _OnayBlok(:final oge) => _OnayKarti(
      oge: oge,
      ajan: s.ajan,
      karar: (k) => s.onayla(oge, k),
    ),
    _DosyaBlok(:final dosyalar) => _Dosyalar(dosyalar: dosyalar, ac: _dosyaAc),
    _BittiBlok(:final oge) => _BittiSatiri(oge: oge),
    _UyariBlok(:final metin) => _UyariSatiri(metin: metin),
  };
}

// ---------------------------------------------------------------- parçalar

class _Bos extends StatelessWidget {
  const _Bos({required this.sohbet});
  final Sohbet sohbet;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AjanRozeti(ajan: sohbet.ajan, boyut: 44),
            const SizedBox(height: 14),
            Text(
              '${ajanAdi(sohbet.ajan)} · ${sohbet.cwd.split('/').last}',
              style: t.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ne yapmak istediğini yaz.',
              style: t.textTheme.bodyMedium?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AjanSatiri extends StatelessWidget {
  const _AjanSatiri({required this.ajan});
  final String ajan;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Row(
        children: [
          AjanRozeti(ajan: ajan, boyut: 22),
          const SizedBox(width: 8),
          Text(
            ajanAdi(ajan),
            style: t.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _Calisiyor extends StatelessWidget {
  const _Calisiyor({required this.sohbet});
  final Sohbet sohbet;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final bekleyen = sohbet.ogeler.whereType<OnayOge>().any((o) => !o.kapandi);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: bekleyen
                ? Icon(
                    Icons.pause_circle_outline,
                    size: 14,
                    color: t.colorScheme.primary,
                  )
                : const CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(
            bekleyen ? 'Onayın bekleniyor' : 'Çalışıyor…',
            style: t.textTheme.bodySmall?.copyWith(
              color: t.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _KullaniciBalonu extends StatelessWidget {
  const _KullaniciBalonu({required this.oge, required this.dosyaAc});
  final KullaniciOge oge;
  final void Function(String) dosyaAc;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(top: 18, bottom: 4, left: 56),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: r.surfaceContainerHigh,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(6),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (oge.metin.isNotEmpty)
              SelectableText(
                oge.metin,
                style: t.textTheme.bodyLarge?.copyWith(
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
            if (oge.ekler.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final e in oge.ekler)
                    ActionChip(
                      avatar: Icon(dosyaSimgesi(e), size: 14),
                      label: Text(
                        e.split('/').last.replaceFirst(RegExp(r'^\d+_'), ''),
                      ),
                      onPressed: () => dosyaAc(e),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Aracın insanca adı ve simgesi.
(String, IconData) aracGorunumu(String ad) => switch (ad) {
  'Bash' || 'Komut' => ('Komut', Icons.terminal_rounded),
  'Read' => ('Okudu', Icons.visibility_outlined),
  'Write' => ('Yazdı', Icons.note_add_outlined),
  'Edit' || 'MultiEdit' || 'Düzenle' => ('Düzenledi', Icons.edit_outlined),
  'NotebookEdit' => ('Defter', Icons.edit_note),
  'Glob' => ('Dosya aradı', Icons.manage_search),
  'Grep' => ('İçerik aradı', Icons.search),
  'WebSearch' || 'webSearch' => ('Web\'de aradı', Icons.travel_explore),
  'WebFetch' => ('Sayfa okudu', Icons.public),
  'Task' || 'Agent' => ('Alt görev', Icons.account_tree_outlined),
  'TodoWrite' => ('Plan', Icons.checklist),
  'Dosya değişikliği' => ('Değişiklik', Icons.edit_outlined),
  _ => (ad, Icons.extension_outlined),
};

class _Etkinlik extends StatefulWidget {
  const _Etkinlik({required this.araclar});
  final List<AracOge> araclar;

  @override
  State<_Etkinlik> createState() => _EtkinlikState();
}

class _EtkinlikState extends State<_Etkinlik> {
  bool _acik = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    final a = widget.araclar;
    final suruyor = a.any((x) => !x.bitti);
    final hata = a.where((x) => x.hata).length;
    final son = a.last;
    final (sonAd, sonSimge) = aracGorunumu(son.ad);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: r.surfaceContainerLow,
        border: Border.all(color: r.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _acik = !_acik),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: suruyor
                        ? const CircularProgressIndicator(strokeWidth: 1.8)
                        : Icon(
                            hata > 0
                                ? Icons.error_outline
                                : Icons.check_circle_outline,
                            size: 16,
                            color: hata > 0 ? r.error : r.onSurfaceVariant,
                          ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${a.length} adım',
                    style: t.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(sonSimge, size: 14, color: r.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$sonAd  ${son.ozet}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.bodySmall?.copyWith(
                        color: r.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Icon(
                    _acik ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: r.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_acik)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (final x in a) _AracSatiri(oge: x)],
              ),
            ),
        ],
      ),
    );
  }
}

class _AracSatiri extends StatefulWidget {
  const _AracSatiri({required this.oge});
  final AracOge oge;

  @override
  State<_AracSatiri> createState() => _AracSatiriState();
}

class _AracSatiriState extends State<_AracSatiri> {
  bool _acik = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    final o = widget.oge;
    final (ad, simge) = aracGorunumu(o.ad);
    final fark = _acik ? girdidenFark(o.girdi) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _acik = !_acik),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              children: [
                Icon(
                  simge,
                  size: 15,
                  color: o.hata ? r.error : r.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 92,
                  child: Text(
                    ad,
                    style: t.textTheme.labelMedium?.copyWith(
                      color: o.hata ? r.error : r.onSurface,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    o.ozet,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: monospace.copyWith(
                      fontSize: 12,
                      color: r.onSurfaceVariant,
                    ),
                  ),
                ),
                if (!o.bitti)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
              ],
            ),
          ),
        ),
        if (_acik)
          Padding(
            padding: const EdgeInsets.fromLTRB(29, 2, 4, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (fark != null)
                  for (final (yol, satirlar) in fark)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: DiffGorunumu(
                        yol: yol,
                        satirlar: satirlar,
                        enFazla: 300,
                      ),
                    )
                else
                  KodKutusu(metin: _girdiMetni(o.girdi), enFazla: 160),
                if ((o.cikti ?? '').trim().isNotEmpty && fark == null) ...[
                  const SizedBox(height: 6),
                  KodKutusu(metin: o.cikti!, hata: o.hata),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

String _girdiMetni(String girdi) {
  try {
    final j = jsonDecode(girdi);
    if (j is Map && j['command'] != null) return '\$ ${j['command']}';
    if (j is Map) return const JsonEncoder.withIndent('  ').convert(j);
  } catch (_) {}
  return girdi;
}

class _OnayKarti extends StatelessWidget {
  const _OnayKarti({
    required this.oge,
    required this.ajan,
    required this.karar,
  });

  final OnayOge oge;
  final String ajan;
  final void Function(String) karar;

  String get _baslik {
    final yol = oge.ozet.split('/').last;
    return switch (oge.arac) {
      'Bash' || 'Komut' => 'Komut çalıştırmak istiyor',
      'Write' => 'Dosya oluşturmak istiyor: $yol',
      'Edit' || 'MultiEdit' => 'Dosyayı düzenlemek istiyor: $yol',
      'Dosya değişikliği' => 'Dosyaları değiştirmek istiyor',
      'WebFetch' => 'Bir sayfayı okumak istiyor',
      'WebSearch' => 'Web\'de aramak istiyor',
      _ => '${oge.arac} kullanmak istiyor',
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    if (oge.kapandi) {
      final (simge, metin, renk) = switch (oge.karar) {
        'red' => (Icons.block, 'Reddedildi', r.error),
        'hep' => (Icons.done_all, 'Bu oturumda hep izinli', r.onSurfaceVariant),
        _ => (Icons.check, 'İzin verildi', r.onSurfaceVariant),
      };
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(simge, size: 15, color: renk),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$metin · ${oge.ozet}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.textTheme.bodySmall?.copyWith(color: renk),
              ),
            ),
          ],
        ),
      );
    }
    final fark = girdidenFark(oge.girdi);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: r.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: r.primary.withValues(alpha: .55), width: 1.3),
        boxShadow: [
          BoxShadow(color: r.primary.withValues(alpha: .10), blurRadius: 18),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: r.primary.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  aracGorunumu(oge.arac).$2,
                  size: 16,
                  color: r.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${ajanAdi(ajan)} izin istiyor',
                      style: t.textTheme.labelSmall?.copyWith(
                        color: r.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _baslik,
                      style: t.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (oge.neden.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              oge.neden,
              style: t.textTheme.bodySmall?.copyWith(color: r.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 12),
          if (fark != null)
            for (final (yol, satirlar) in fark)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: DiffGorunumu(yol: yol, satirlar: satirlar),
              )
          else
            KodKutusu(metin: _girdiMetni(oge.girdi), enFazla: 200),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => karar('red'),
                child: const Text('Reddet'),
              ),
              OutlinedButton(
                onPressed: () => karar('hep'),
                child: const Text('Bu oturumda hep'),
              ),
              FilledButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  karar('izin');
                },
                icon: const Icon(Icons.check, size: 18),
                label: const Text('İzin ver'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Dosyalar extends StatelessWidget {
  const _Dosyalar({required this.dosyalar, required this.ac});
  final List<DosyaOge> dosyalar;
  final void Function(String) ac;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final d in dosyalar)
            ActionChip(
              avatar: Icon(dosyaSimgesi(d.yol), size: 15),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(d.goreli),
                  const SizedBox(width: 6),
                  Text(
                    switch (d.eylem) {
                      'yeni' => 'yeni',
                      'silindi' => 'silindi',
                      _ => 'değişti',
                    },
                    style: t.textTheme.labelSmall?.copyWith(
                      color: d.eylem == 'yeni'
                          ? const Color(0xFF22C55E)
                          : d.eylem == 'silindi'
                          ? r.error
                          : r.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              onPressed: d.eylem == 'silindi' ? null : () => ac(d.yol),
            ),
        ],
      ),
    );
  }
}

class _BittiSatiri extends StatelessWidget {
  const _BittiSatiri({required this.oge});
  final BittiOge oge;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    if (oge.hata != null) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: r.errorContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, size: 16, color: r.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                oge.hata!,
                style: t.textTheme.bodySmall?.copyWith(
                  color: r.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (oge.maliyet == null) return const SizedBox(height: 4);
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 6),
      child: Text(
        '\$${oge.maliyet!.toStringAsFixed(3)}',
        style: t.textTheme.labelSmall?.copyWith(color: r.outline),
      ),
    );
  }
}

class _UyariSatiri extends StatelessWidget {
  const _UyariSatiri({required this.metin});
  final String metin;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: KodKutusu(metin: metin, hata: true, enFazla: 140),
  );
}
