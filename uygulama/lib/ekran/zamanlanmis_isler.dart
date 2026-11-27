import 'package:flutter/material.dart';

import '../arayuz/ortak.dart';
import '../model/calisma.dart';

const _gunAdlari = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

/// Ayarlar › Zamanlanmış işler: köprü belirlenen saatte (seçilen günlerde)
/// yeni bir oturum açar ve istemi gönderir; sonuç sohbete ve bildirime düşer.
class ZamanlanmisIsler extends StatefulWidget {
  const ZamanlanmisIsler({super.key, required this.calisma});
  final Calisma calisma;

  @override
  State<ZamanlanmisIsler> createState() => _ZamanlanmisIslerState();
}

class _ZamanlanmisIslerState extends State<ZamanlanmisIsler> {
  Calisma get c => widget.calisma;
  List<Map<String, dynamic>>? _isler;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final r = await c.istemci.iste('zaman_liste');
      if (!mounted) return;
      setState(() {
        _isler = [
          for (final x in r['isler'] as List)
            (x as Map).cast<String, dynamic>(),
        ];
        _hata = null;
      });
    } catch (e) {
      if (mounted) setState(() => _hata = '$e');
    }
  }

  Future<void> _kaydet(Map<String, dynamic> is_) async {
    try {
      await c.istemci.iste('zaman_kaydet', {'is': is_});
      await _yukle();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Kaydedilemedi: $e')));
      }
    }
  }

  Future<void> _sil(String id) async {
    await c.istemci.iste('zaman_sil', {'id': id});
    await _yukle();
  }

  Future<void> _simdi(String id) async {
    final m = ScaffoldMessenger.of(context);
    try {
      await c.istemci.iste('zaman_calistir', {'id': id});
      m.showSnackBar(
        const SnackBar(content: Text('Başlatıldı; oturumlar listesinde.')),
      );
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text('Başlatılamadı: $e')));
    }
  }

  Future<void> _duzenle([Map<String, dynamic>? eski]) async {
    final sonuc = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _IsPenceresi(calisma: c, eski: eski),
    );
    if (sonuc != null) await _kaydet(sonuc);
  }

  String _gunler(List gunler) {
    if (gunler.length == 7) return 'her gün';
    if (gunler.length == 5 && !gunler.contains(5) && !gunler.contains(6)) {
      return 'hafta içi';
    }
    return [for (final g in gunler) _gunAdlari[g as int]].join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    if (!c.yetenek('zamanlanmis')) {
      return Text(
        'Köprüyü güncelleyince (aşağıda) kullanılabilir.',
        style: TextStyle(color: r.onSurfaceVariant),
      );
    }
    if (_hata != null) return Text(_hata!, style: TextStyle(color: r.error));
    final isler = _isler;
    if (isler == null) return const LinearProgressIndicator();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isler.isEmpty)
          Text(
            'Zamanlanmış iş yok. Ör. her sabah 9\'da sunucuların durumunu özetlet.',
            style: TextStyle(color: r.onSurfaceVariant),
          ),
        for (final x in isler)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Switch(
              value: x['acik'] != false,
              onChanged: (v) => _kaydet({...x, 'acik': v}),
            ),
            title: Text('${x['saat']} · ${x['ad']}'),
            subtitle: Text(
              '${_gunler(x['gunler'] as List)} · ${ajanAdi(x['ajan'] as String)}'
              ' · ${(x['sunucu'] as String?) ?? (x['cwd'] as String).split('/').last}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            onTap: () => _duzenle(x),
            trailing: PopupMenuButton<String>(
              onSelected: (s) => switch (s) {
                'simdi' => _simdi(x['id'] as String),
                'sil' => _sil(x['id'] as String),
                _ => null,
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'simdi', child: Text('Şimdi çalıştır')),
                PopupMenuItem(value: 'sil', child: Text('Sil')),
              ],
            ),
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _duzenle,
            icon: const Icon(Icons.add, size: 16),
            label: const Text('İş ekle'),
          ),
        ),
      ],
    );
  }
}

class _IsPenceresi extends StatefulWidget {
  const _IsPenceresi({required this.calisma, this.eski});
  final Calisma calisma;
  final Map<String, dynamic>? eski;

  @override
  State<_IsPenceresi> createState() => _IsPenceresiState();
}

class _IsPenceresiState extends State<_IsPenceresi> {
  late final _ad = TextEditingController(text: widget.eski?['ad'] as String?);
  late final _metin = TextEditingController(
    text: widget.eski?['metin'] as String?,
  );
  late String _saat = widget.eski?['saat'] as String? ?? '09:00';
  late Set<int> _gunler = {
    ...((widget.eski?['gunler'] as List?)?.cast<int>() ?? [0, 1, 2, 3, 4]),
  };
  late String _ajan = widget.eski?['ajan'] as String? ?? 'claude';
  late String _mod = widget.eski?['mod'] as String? ?? 'otomatik';

  /// Hedef: `yerel:YOL` ya da `uzak:SUNUCU`.
  late String _hedef = widget.eski?['sunucu'] != null
      ? 'uzak:${widget.eski!['sunucu']}'
      : 'yerel:${widget.eski?['cwd'] ?? widget.calisma.kok ?? ''}';

  @override
  void dispose() {
    _ad.dispose();
    _metin.dispose();
    super.dispose();
  }

  Future<void> _saatSec() async {
    final p = _saat.split(':');
    final s = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1])),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (s != null) {
      setState(
        () => _saat =
            '${s.hour.toString().padLeft(2, '0')}:${s.minute.toString().padLeft(2, '0')}',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.calisma;
    final hedefler = <(String, String)>[
      if (c.kok != null) ('yerel:${c.kok}', 'Projeler klasörü'),
      for (final p in c.projeler) ('yerel:${p['yol']}', '${p['ad']}'),
      for (final s in c.sunucular)
        ('uzak:${s['ad']}', '${s['ad']} (SSH, ana klasör)'),
    ];
    if (!hedefler.any((h) => h.$1 == _hedef)) {
      hedefler.insert(0, (_hedef, _hedef.substring(_hedef.indexOf(':') + 1)));
    }
    return AlertDialog(
      title: Text(widget.eski == null ? 'Zamanlanmış iş' : 'İşi düzenle'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _ad,
                decoration: const InputDecoration(labelText: 'Ad'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: _saatSec,
                    icon: const Icon(Icons.schedule, size: 18),
                    label: Text(_saat),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _ajan,
                      decoration: const InputDecoration(labelText: 'Ajan'),
                      items: const [
                        DropdownMenuItem(
                          value: 'claude',
                          child: Text('Claude Code'),
                        ),
                        DropdownMenuItem(value: 'codex', child: Text('Codex')),
                      ],
                      onChanged: (v) => setState(() => _ajan = v ?? _ajan),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 4,
                children: [
                  for (var g = 0; g < 7; g++)
                    FilterChip(
                      label: Text(_gunAdlari[g]),
                      selected: _gunler.contains(g),
                      onSelected: (v) => setState(() {
                        _gunler = {..._gunler};
                        v ? _gunler.add(g) : _gunler.remove(g);
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _hedef,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Nerede'),
                items: [
                  for (final (d, ad) in hedefler)
                    DropdownMenuItem(
                      value: d,
                      child: Text(ad, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: (v) => setState(() => _hedef = v ?? _hedef),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _mod,
                decoration: const InputDecoration(
                  labelText: 'Çalışma biçimi',
                  helperText: 'Kimse ekranda değilken onay beklerse iş durur.',
                ),
                items: const [
                  DropdownMenuItem(value: 'otomatik', child: Text('Otomatik')),
                  DropdownMenuItem(value: 'sor', child: Text('Her adımda sor')),
                  DropdownMenuItem(
                    value: 'duzenle',
                    child: Text('Düzenlemeler serbest'),
                  ),
                  DropdownMenuItem(value: 'serbest', child: Text('Serbest')),
                ],
                onChanged: (v) => setState(() => _mod = v ?? _mod),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _metin,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(labelText: 'İstem'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () {
            final uzak = _hedef.startsWith('uzak:');
            final deger = _hedef.substring(_hedef.indexOf(':') + 1);
            Navigator.pop(context, {
              if (widget.eski != null) ...widget.eski!,
              'ad': _ad.text.trim(),
              'saat': _saat,
              'gunler': (_gunler.toList()..sort()),
              'ajan': _ajan,
              'mod': _mod,
              'metin': _metin.text.trim(),
              'sunucu': uzak ? deger : null,
              'cwd': uzak ? null : deger,
              'uzak_klasor': uzak ? '~' : null,
            });
          },
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}
