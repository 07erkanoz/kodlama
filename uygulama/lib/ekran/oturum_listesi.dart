import 'package:flutter/material.dart';

import '../model/calisma.dart';
import '../servis/kopru_istemci.dart';

/// Sol panel: oturumlar ve yeni oturum. Dar ekranda çekmecede açılır.
class OturumListesi extends StatelessWidget {
  const OturumListesi({super.key, required this.calisma, this.secildi});

  final Calisma calisma;

  /// Dar ekranda çekmeceyi kapatmak için.
  final VoidCallback? secildi;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return ListenableBuilder(
      listenable: calisma,
      builder: (context, _) {
        final c = calisma;
        return Material(
          color: t.colorScheme.surfaceContainerLow,
          child: SafeArea(
            right: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('Atölye', style: t.textTheme.titleLarge),
                      ),
                      _BaglantiIsareti(durum: c.baglanti),
                      IconButton(
                        tooltip: 'Yenile',
                        onPressed: c.yenile,
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: FilledButton.icon(
                    onPressed: c.baglanti == BaglantiDurumu.bagli
                        ? () => _yeni(context)
                        : null,
                    icon: const Icon(Icons.add),
                    label: const Text('Yeni oturum'),
                  ),
                ),
                if (c.kotalar.isNotEmpty) _Kotalar(kotalar: c.kotalar),
                const SizedBox(height: 4),
                Expanded(
                  child: c.oturumlar.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              c.baglanti == BaglantiDurumu.bagli
                                  ? 'Henüz oturum yok.'
                                  : 'Köprü bekleniyor…',
                              style: t.textTheme.bodyMedium?.copyWith(
                                color: t.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: c.oturumlar.length,
                          itemBuilder: (context, i) {
                            final o = c.oturumlar[i];
                            final secili = c.secili?.id == o['id'];
                            return ListTile(
                              selected: secili,
                              leading: _AjanRozeti(
                                ajan: o['ajan'] as String,
                                calisiyor: o['durum'] == 'calisiyor',
                              ),
                              title: Text(
                                o['baslik'] as String? ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                o['goreli'] as String? ?? '',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () {
                                c.sec(o);
                                secildi?.call();
                              },
                              onLongPress: () => _sil(context, o),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
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

  Future<void> _yeni(BuildContext context) async {
    final sonuc = await showDialog<(String, String, String)>(
      context: context,
      builder: (context) => _YeniOturum(calisma: calisma),
    );
    if (sonuc == null) return;
    final (ajan, cwd, mod) = sonuc;
    try {
      await calisma.yeniOturum(ajan: ajan, cwd: cwd, mod: mod);
      secildi?.call();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Açılamadı: $e')));
      }
    }
  }
}

class _BaglantiIsareti extends StatelessWidget {
  const _BaglantiIsareti({required this.durum});
  final BaglantiDurumu durum;

  @override
  Widget build(BuildContext context) {
    final (renk, metin) = switch (durum) {
      BaglantiDurumu.bagli => (Colors.green, 'Köprü bağlı'),
      BaglantiDurumu.baglaniyor => (Colors.amber, 'Bağlanıyor'),
      BaglantiDurumu.yetkisiz => (Colors.red, 'Anahtar eşleşmedi'),
      BaglantiDurumu.kapali => (Colors.grey, 'Köprü kapalı'),
    };
    return Tooltip(
      message: metin,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: renk, shape: BoxShape.circle),
      ),
    );
  }
}

class _AjanRozeti extends StatelessWidget {
  const _AjanRozeti({required this.ajan, required this.calisiyor});
  final String ajan;
  final bool calisiyor;

  @override
  Widget build(BuildContext context) {
    final renk = Theme.of(context).colorScheme;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: ajan == 'claude'
              ? renk.tertiaryContainer
              : renk.secondaryContainer,
          child: Text(
            ajan == 'claude' ? 'C' : 'X',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        if (calisiyor)
          const Positioned(
            right: -2,
            bottom: -2,
            child: SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }
}

class _Kotalar extends StatelessWidget {
  const _Kotalar({required this.kotalar});
  final Map<String, List<dynamic>> kotalar;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final MapEntry(key: ajan, value: pencereler) in kotalar.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '${ajan == 'claude' ? 'Claude' : 'Codex'}: '
                '${[for (final p in pencereler.cast<Map>()) '${p['ad']} %${p['kullanim']}'].join(' · ')}',
                style: t.textTheme.bodySmall?.copyWith(
                  color: t.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Yeni oturum: ajan, proje klasörü (var olan ya da yeni), çalışma biçimi.
class _YeniOturum extends StatefulWidget {
  const _YeniOturum({required this.calisma});
  final Calisma calisma;

  @override
  State<_YeniOturum> createState() => _YeniOturumState();
}

class _YeniOturumState extends State<_YeniOturum> {
  String? _ajan;
  String _mod = 'sor';
  String? _klasor;
  List<Map<String, dynamic>> _projeler = [];
  final _yeniAd = TextEditingController();
  String? _hata;

  @override
  void initState() {
    super.initState();
    final kurulu = widget.calisma.ajanlar
        .where((a) => a['kurulu'] == true)
        .map((a) => a['ad'] as String)
        .toList();
    _ajan = kurulu.isNotEmpty ? kurulu.first : null;
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final r = await widget.calisma.istemci.iste('projeler');
      setState(() {
        _projeler = ((r['projeler'] as List?) ?? const [])
            .cast<Map>()
            .map((m) => m.cast<String, dynamic>())
            .toList();
        _klasor ??= _projeler.isNotEmpty
            ? _projeler.first['yol'] as String
            : null;
      });
    } catch (e) {
      setState(() => _hata = '$e');
    }
  }

  Future<void> _projeAc() async {
    final ad = _yeniAd.text.trim();
    if (ad.isEmpty) return;
    try {
      final r = await widget.calisma.istemci.iste('proje_ac', {'ad': ad});
      _yeniAd.clear();
      _klasor = r['yol'] as String;
      await _yukle();
    } catch (e) {
      setState(() => _hata = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ajanlar = widget.calisma.ajanlar;
    return AlertDialog(
      title: const Text('Yeni oturum'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<String>(
                segments: [
                  for (final a in ajanlar)
                    ButtonSegment(
                      value: a['ad'] as String,
                      enabled: a['kurulu'] == true,
                      label: Text(a['ad'] == 'claude' ? 'Claude' : 'Codex'),
                    ),
                ],
                selected: {?_ajan},
                emptySelectionAllowed: true,
                onSelectionChanged: (s) =>
                    setState(() => _ajan = s.firstOrNull),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _klasor,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Proje klasörü'),
                items: [
                  for (final p in _projeler)
                    DropdownMenuItem(
                      value: p['yol'] as String,
                      child: Text(p['ad'] as String),
                    ),
                ],
                onChanged: (v) => setState(() => _klasor = v),
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _yeniAd,
                      decoration: const InputDecoration(
                        hintText: 'ya da yeni proje adı',
                      ),
                      onSubmitted: (_) => _projeAc(),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Klasörü oluştur',
                    onPressed: _projeAc,
                    icon: const Icon(Icons.create_new_folder_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _mod,
                decoration: const InputDecoration(labelText: 'Çalışma biçimi'),
                items: const [
                  DropdownMenuItem(
                    value: 'sor',
                    child: Text('Her değişiklikte sor'),
                  ),
                  DropdownMenuItem(
                    value: 'duzenle',
                    child: Text('Düzenlemeler serbest, komutlarda sor'),
                  ),
                  DropdownMenuItem(
                    value: 'plan',
                    child: Text('Yalnız plan (değiştirmez)'),
                  ),
                  DropdownMenuItem(
                    value: 'serbest',
                    child: Text('Sormadan çalış'),
                  ),
                ],
                onChanged: (v) => setState(() => _mod = v ?? 'sor'),
              ),
              if (_hata != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _hata!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
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
          onPressed: _ajan == null || _klasor == null
              ? null
              : () => Navigator.pop(context, (_ajan!, _klasor!, _mod)),
          child: const Text('Başlat'),
        ),
      ],
    );
  }
}
