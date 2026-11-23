import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../arayuz/markdown.dart';
import '../model/calisma.dart';
import '../model/sohbet.dart';
import 'onizleme.dart';

/// Sohbet: ajanın yazdıkları zengin metin olarak, araç çağrıları kart
/// olarak, onaylar düğmeli kart olarak, üretilen dosyalar önizlenebilir
/// çip olarak. Terminal görünmez.
class SohbetGorunumu extends StatefulWidget {
  const SohbetGorunumu({
    super.key,
    required this.calisma,
    required this.sohbet,
    this.dosyaAc,
  });

  final Calisma calisma;
  final Sohbet sohbet;

  /// Dosyaya basıldı: geniş ekranda yan panelde, dar ekranda tam sayfa.
  final void Function(String yol)? dosyaAc;

  @override
  State<SohbetGorunumu> createState() => _SohbetGorunumuState();
}

class _SohbetGorunumuState extends State<SohbetGorunumu> {
  final _yazi = TextEditingController();
  final _kaydirma = ScrollController();
  final _ekler = <String>[];
  bool _ekYukleniyor = false;

  Sohbet get s => widget.sohbet;

  void _dosyaAc(String yol) {
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
        final veri = await f.readAsBytes();
        final yol = await s.ekYukle(f.name, base64Encode(veri));
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
        final ogeler = s.ogeler;
        return Column(
          children: [
            Expanded(
              child: s.yukleniyor
                  ? const Center(child: CircularProgressIndicator())
                  : ogeler.isEmpty
                  ? _Bos(sohbet: s)
                  : ListView.builder(
                      controller: _kaydirma,
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      itemCount: ogeler.length + (s.calisiyor ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (s.calisiyor && i == 0) return const _Calisiyor();
                        final o =
                            ogeler[ogeler.length -
                                1 -
                                (i - (s.calisiyor ? 1 : 0))];
                        return Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 820),
                            child: _oge(o),
                          ),
                        );
                      },
                    ),
            ),
            _Yazici(
              denetleyici: _yazi,
              ekler: _ekler,
              ekYukleniyor: _ekYukleniyor,
              calisiyor: s.calisiyor,
              gonder: _gonder,
              durdur: s.durdur,
              ekSec: _ekSec,
              ekKaldir: (e) => setState(() => _ekler.remove(e)),
            ),
          ],
        );
      },
    );
  }

  Widget _oge(Oge o) => switch (o) {
    KullaniciOge() => _KullaniciBalonu(oge: o, dosyaAc: _dosyaAc),
    MetinOge() => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Markdown(o.metin, size: 15, onLink: _dosyaAc),
    ),
    AracOge() => _AracKarti(oge: o),
    OnayOge() => _OnayKarti(oge: o, karar: (k) => s.onayla(o, k)),
    DosyaOge() => _DosyaCipi(oge: o, ac: () => _dosyaAc(o.yol)),
    BittiOge() => _BittiSatiri(oge: o),
    UyariOge() => _UyariSatiri(metin: o.metin),
  };
}

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
            Icon(Icons.forum_outlined, size: 40, color: t.colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              '${sohbet.ajan == 'claude' ? 'Claude Code' : 'Codex'} · ${sohbet.cwd.split('/').last}',
              style: t.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Ne yapmak istediğini yaz. Değişiklikler ve komutlar için '
              'onayın istenir.',
              textAlign: TextAlign.center,
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

class _Calisiyor extends StatelessWidget {
  const _Calisiyor();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 10),
          Text('Çalışıyor…'),
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
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(top: 14, bottom: 6, left: 48),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: t.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (oge.metin.isNotEmpty)
              Text(
                oge.metin,
                style: TextStyle(
                  fontSize: 15,
                  color: t.colorScheme.onPrimaryContainer,
                ),
              ),
            for (final e in oge.ekler)
              ActionChip(
                avatar: const Icon(Icons.attach_file, size: 16),
                label: Text(e.split('/').last),
                onPressed: () => dosyaAc(e),
              ),
          ],
        ),
      ),
    );
  }
}

class _AracKarti extends StatefulWidget {
  const _AracKarti({required this.oge});
  final AracOge oge;

  @override
  State<_AracKarti> createState() => _AracKartiState();
}

class _AracKartiState extends State<_AracKarti> {
  bool _acik = false;

  static IconData _simge(String ad) => switch (ad) {
    'Bash' || 'Komut' => Icons.terminal,
    'Read' => Icons.visibility_outlined,
    'Write' || 'Edit' || 'MultiEdit' || 'Düzenle' => Icons.edit_outlined,
    'Glob' || 'Grep' => Icons.search,
    'WebSearch' || 'webSearch' || 'WebFetch' => Icons.public,
    'Task' || 'Agent' => Icons.account_tree_outlined,
    _ => Icons.build_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final o = widget.oge;
    final t = Theme.of(context);
    final renk = o.hata ? t.colorScheme.error : t.colorScheme.onSurfaceVariant;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        border: Border.all(color: t.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _acik = !_acik),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Icon(_simge(o.ad), size: 16, color: renk),
                  const SizedBox(width: 8),
                  Text(
                    o.ad,
                    style: t.textTheme.labelLarge?.copyWith(color: renk),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      o.ozet,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: t.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  if (!o.bitti)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(strokeWidth: 1.5),
                    )
                  else
                    Icon(
                      _acik ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: t.colorScheme.outline,
                    ),
                ],
              ),
            ),
          ),
          if (_acik)
            Container(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _KodKutusu(metin: o.girdi),
                  if ((o.cikti ?? '').isNotEmpty) ...[
                    const SizedBox(height: 6),
                    _KodKutusu(metin: o.cikti!, hata: o.hata),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _KodKutusu extends StatelessWidget {
  const _KodKutusu({required this.metin, this.hata = false});
  final String metin;
  final bool hata;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Container(
      constraints: const BoxConstraints(maxHeight: 280),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: hata
            ? t.colorScheme.errorContainer
            : t.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: SingleChildScrollView(
        child: Text(
          metin,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 12,
            color: hata ? t.colorScheme.onErrorContainer : null,
          ),
        ),
      ),
    );
  }
}

class _OnayKarti extends StatelessWidget {
  const _OnayKarti({required this.oge, required this.karar});
  final OnayOge oge;
  final void Function(String) karar;

  String _okunur() {
    try {
      final j = jsonDecode(oge.girdi);
      if (j is Map) {
        if (j['command'] != null) return j['command'].toString();
        if (j['content'] != null) {
          return '${j['file_path'] ?? ''}\n\n${j['content']}';
        }
        if (j['old_string'] != null) {
          return '${j['file_path'] ?? ''}\n\n− ${j['old_string']}\n+ ${j['new_string']}';
        }
        if (j['changes'] is List) {
          return [
            for (final c in (j['changes'] as List).cast<Map>())
              '${c['path']}\n${c['diff'] ?? ''}',
          ].join('\n\n');
        }
      }
    } catch (_) {}
    return oge.girdi;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final kapali = oge.kapandi;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      color: kapali ? null : t.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  kapali ? Icons.check_circle_outline : Icons.help_outline,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    kapali
                        ? '${oge.arac}: ${switch (oge.karar) {
                            'izin' => 'izin verildi',
                            'hep' => 'bu oturumda hep izinli',
                            'red' => 'reddedildi',
                            _ => 'kapandı',
                          }}'
                        : '${oge.arac} için onay gerekiyor',
                    style: t.textTheme.titleSmall,
                  ),
                ),
              ],
            ),
            if (oge.neden.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(oge.neden, style: t.textTheme.bodySmall),
            ],
            if (!kapali) ...[
              const SizedBox(height: 8),
              _KodKutusu(metin: _okunur()),
              const SizedBox(height: 10),
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
                  FilledButton(
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      karar('izin');
                    },
                    child: const Text('İzin ver'),
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

class _DosyaCipi extends StatelessWidget {
  const _DosyaCipi({required this.oge, required this.ac});
  final DosyaOge oge;
  final VoidCallback ac;

  @override
  Widget build(BuildContext context) {
    final silindi = oge.eylem == 'silindi';
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: ActionChip(
          avatar: Icon(dosyaSimgesi(oge.yol), size: 16),
          label: Text(
            '${switch (oge.eylem) {
              'yeni' => 'Yeni',
              'silindi' => 'Silindi',
              _ => 'Değişti',
            }}: ${oge.goreli}',
          ),
          onPressed: silindi ? null : ac,
        ),
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
    if (oge.hata == null && oge.maliyet == null) {
      return const SizedBox(height: 6);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        oge.hata ??
            (oge.maliyet != null
                ? 'Tur bitti · \$${oge.maliyet!.toStringAsFixed(3)}'
                : ''),
        style: t.textTheme.bodySmall?.copyWith(
          color: oge.hata != null
              ? t.colorScheme.error
              : t.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _UyariSatiri extends StatelessWidget {
  const _UyariSatiri({required this.metin});
  final String metin;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        metin,
        style: t.textTheme.bodySmall?.copyWith(
          color: t.colorScheme.error,
          fontFamily: 'monospace',
        ),
      ),
    );
  }
}

class _Yazici extends StatelessWidget {
  const _Yazici({
    required this.denetleyici,
    required this.ekler,
    required this.ekYukleniyor,
    required this.calisiyor,
    required this.gonder,
    required this.durdur,
    required this.ekSec,
    required this.ekKaldir,
  });

  final TextEditingController denetleyici;
  final List<String> ekler;
  final bool ekYukleniyor;
  final bool calisiyor;
  final VoidCallback gonder;
  final VoidCallback durdur;
  final VoidCallback ekSec;
  final void Function(String) ekKaldir;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Material(
      color: t.colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (ekler.isNotEmpty || ekYukleniyor)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 6,
                        children: [
                          for (final e in ekler)
                            InputChip(
                              label: Text(e.split('/').last),
                              onDeleted: () => ekKaldir(e),
                            ),
                          if (ekYukleniyor)
                            const Padding(
                              padding: EdgeInsets.all(8),
                              child: SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        tooltip: 'Dosya ekle',
                        onPressed: ekSec,
                        icon: const Icon(Icons.attach_file),
                      ),
                      Expanded(
                        child: CallbackShortcuts(
                          bindings: {
                            const SingleActivator(
                              LogicalKeyboardKey.enter,
                              control: true,
                            ): gonder,
                          },
                          child: TextField(
                            controller: denetleyici,
                            minLines: 1,
                            maxLines: 6,
                            textInputAction: TextInputAction.newline,
                            decoration: InputDecoration(
                              hintText: calisiyor
                                  ? 'Araya yaz — çalışan işe eklenir'
                                  : 'Mesaj yaz',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (calisiyor)
                        IconButton.filledTonal(
                          tooltip: 'Durdur',
                          onPressed: durdur,
                          icon: const Icon(Icons.stop),
                        ),
                      IconButton.filled(
                        tooltip: 'Gönder',
                        onPressed: gonder,
                        icon: const Icon(Icons.arrow_upward),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
