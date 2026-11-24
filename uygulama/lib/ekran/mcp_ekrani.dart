import 'package:flutter/material.dart';

import '../arayuz/ortak.dart';
import '../model/calisma.dart';

/// Ajanların MCP sunucuları: listele, ekle, sil. Her CLI'ın kendi
/// `mcp add/remove` komutu kullanılır; gizli değerler (ortam değişkenleri,
/// başlıklar) köprüden geri gelmez, yalnız adları görünür.
class McpEkrani extends StatefulWidget {
  const McpEkrani({super.key, required this.calisma});
  final Calisma calisma;

  @override
  State<McpEkrani> createState() => _McpEkraniState();
}

class _McpEkraniState extends State<McpEkrani> {
  Calisma get c => widget.calisma;
  final _listeler = <String, Future<List<Map>>>{};

  List<String> get _ajanlar => [
    for (final a in c.ajanlar)
      if (a['kurulu'] == true) a['ad'] as String,
  ];

  Future<List<Map>> _liste(String ajan) => _listeler[ajan] ??= c.istemci
      .iste('mcp_liste', {'ajan': ajan})
      .then((r) => ((r['sunucular'] as List?) ?? const []).cast<Map>());

  void _yenile(String ajan) => setState(() => _listeler.remove(ajan));

  void _bildir(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _sil(String ajan, Map s) async {
    final evet = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${s['ad']} silinsin mi?'),
        content: Text(
          '${ajanAdi(ajan)} ayarlarından kaldırılır. Sunucunun kendisi ve '
          'dosyaları silinmez; istersen yeniden ekleyebilirsin.',
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
    if (evet != true) return;
    try {
      await c.istemci.iste('mcp_sil', {
        'ajan': ajan,
        'ad': s['ad'],
        if (ajan == 'claude') 'kapsam': s['kapsam'],
      });
      _bildir('${s['ad']} silindi.');
    } catch (e) {
      _bildir('Silinemedi: $e');
    }
    _yenile(ajan);
  }

  Future<void> _ekle(String ajan) async {
    final eklendi = await showDialog<bool>(
      context: context,
      builder: (_) => _EklePenceresi(calisma: c, ajan: ajan),
    );
    if (eklendi == true) _yenile(ajan);
  }

  @override
  Widget build(BuildContext context) {
    final ajanlar = _ajanlar;
    if (ajanlar.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('MCP sunucuları')),
        body: const Center(child: Text('Kurulu ajan yok.')),
      );
    }
    return DefaultTabController(
      length: ajanlar.length,
      child: Builder(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('MCP sunucuları'),
            bottom: TabBar(
              tabs: [for (final a in ajanlar) Tab(text: ajanAdi(a))],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () =>
                _ekle(ajanlar[DefaultTabController.of(context).index]),
            icon: const Icon(Icons.add),
            label: const Text('Sunucu ekle'),
          ),
          body: TabBarView(
            children: [for (final a in ajanlar) _ajanListesi(a)],
          ),
        ),
      ),
    );
  }

  Widget _ajanListesi(String ajan) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    return FutureBuilder(
      future: _liste(ajan),
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Liste alınamadı: ${snap.error}'),
            ),
          );
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final liste = snap.data!;
        return RefreshIndicator(
          onRefresh: () async => _yenile(ajan),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            children: [
              Text(
                'MCP sunucuları ajana yeni araçlar verir (dosya sistemi, '
                'veritabanı, tarayıcı, kendi servislerin…). Değişiklik ajanın '
                'bir sonraki oturumunda geçerli olur.',
                style: t.textTheme.bodySmall?.copyWith(
                  color: r.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              if (liste.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('Henüz MCP sunucusu yok.')),
                ),
              for (final s in liste)
                Card(
                  child: ListTile(
                    leading: Icon(
                      s['url'] != null ? Icons.public : Icons.terminal,
                    ),
                    title: Text('${s['ad']}'),
                    subtitle: Text(
                      [
                        if (s['url'] != null)
                          '${s['url']}'
                        else
                          [
                            s['komut'],
                            ...(s['argumanlar'] as List? ?? const []),
                          ].join(' '),
                        if ((s['ortam'] as List? ?? const []).isNotEmpty)
                          'ortam: ${(s['ortam'] as List).join(', ')}',
                        if ((s['basliklar'] as List? ?? const []).isNotEmpty)
                          'başlık: ${(s['basliklar'] as List).join(', ')}',
                        [
                          switch (s['kapsam']) {
                            'local' => 'bu proje (yerel)',
                            'project' => 'proje (.mcp.json)',
                            _ => 'tüm projeler',
                          },
                          if (s['etkin'] == false) 'kapalı',
                        ].join(' · '),
                      ].join('\n'),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                    isThreeLine: true,
                    trailing: s['kapsam'] == 'project'
                        ? null
                        : IconButton(
                            tooltip: 'Sil',
                            onPressed: () => _sil(ajan, s),
                            icon: const Icon(Icons.delete_outline),
                          ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// `npx -y "a b" c` → [npx, -y, a b, c]
List<String> komutuBol(String s) {
  final out = <String>[];
  final b = StringBuffer();
  String? tirnak;
  var var_ = false;
  for (final ch in s.runes.map(String.fromCharCode)) {
    if (tirnak != null) {
      if (ch == tirnak) {
        tirnak = null;
      } else {
        b.write(ch);
      }
    } else if (ch == '"' || ch == "'") {
      tirnak = ch;
      var_ = true;
    } else if (ch.trim().isEmpty) {
      if (var_ || b.isNotEmpty) out.add(b.toString());
      b.clear();
      var_ = false;
    } else {
      b.write(ch);
    }
  }
  if (var_ || b.isNotEmpty) out.add(b.toString());
  return out;
}

/// `ANAHTAR=değer` satırları (ortam) ya da `Ad: değer` (başlık).
Map<String, String> satirlariAyir(String s, String ayirici) => {
  for (final satir in s.split('\n'))
    if (satir.contains(ayirici))
      satir.substring(0, satir.indexOf(ayirici)).trim(): satir
          .substring(satir.indexOf(ayirici) + ayirici.length)
          .trim(),
};

class _EklePenceresi extends StatefulWidget {
  const _EklePenceresi({required this.calisma, required this.ajan});
  final Calisma calisma;
  final String ajan;

  @override
  State<_EklePenceresi> createState() => _EklePenceresiState();
}

class _EklePenceresiState extends State<_EklePenceresi> {
  final _ad = TextEditingController();
  final _komut = TextEditingController();
  final _url = TextEditingController();
  final _ortam = TextEditingController();
  final _baslik = TextEditingController();
  bool _uzak = false;
  bool _gonderiliyor = false;
  String? _hata;

  @override
  void dispose() {
    for (final d in [_ad, _komut, _url, _ortam, _baslik]) {
      d.dispose();
    }
    super.dispose();
  }

  Future<void> _kaydet() async {
    setState(() {
      _gonderiliyor = true;
      _hata = null;
    });
    try {
      await widget.calisma.istemci.iste('mcp_ekle', {
        'ajan': widget.ajan,
        'ad': _ad.text.trim(),
        if (_uzak) 'url': _url.text.trim() else 'komut': komutuBol(_komut.text),
        if (!_uzak) 'ortam': satirlariAyir(_ortam.text, '='),
        if (_uzak && widget.ajan == 'claude')
          'basliklar': satirlariAyir(_baslik.text, ':'),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _hata = '$e');
    } finally {
      if (mounted) setState(() => _gonderiliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${ajanAdi(widget.ajan)} için MCP sunucusu'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _ad,
                decoration: const InputDecoration(
                  labelText: 'Ad',
                  hintText: 'ör. dosyalar',
                ),
              ),
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    icon: Icon(Icons.terminal),
                    label: Text('Komut'),
                  ),
                  ButtonSegment(
                    value: true,
                    icon: Icon(Icons.public),
                    label: Text('Adres (HTTP)'),
                  ),
                ],
                selected: {_uzak},
                onSelectionChanged: (v) => setState(() => _uzak = v.first),
              ),
              const SizedBox(height: 12),
              if (!_uzak) ...[
                TextField(
                  controller: _komut,
                  style: monospace,
                  decoration: const InputDecoration(
                    labelText: 'Komut',
                    hintText: 'npx -y @modelcontextprotocol/server-filesystem ~/projeler',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _ortam,
                  style: monospace,
                  minLines: 1,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Ortam değişkenleri (isteğe bağlı)',
                    hintText: 'API_KEY=...',
                    helperText: 'Her satıra bir ANAHTAR=değer',
                  ),
                ),
              ] else ...[
                TextField(
                  controller: _url,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'Adres',
                    hintText: 'https://ornek.com/mcp',
                  ),
                ),
                if (widget.ajan == 'claude') ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _baslik,
                    style: monospace,
                    minLines: 1,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Başlıklar (isteğe bağlı)',
                      hintText: 'Authorization: Bearer ...',
                      helperText: 'Her satıra bir Ad: değer',
                    ),
                  ),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Giriş isteyen sunucularda sonra Terminal\'de '
                      '"codex mcp login <ad>" çalıştır.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
              ],
              if (_hata != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
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
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: _gonderiliyor ? null : _kaydet,
          child: _gonderiliyor
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Ekle'),
        ),
      ],
    );
  }
}
