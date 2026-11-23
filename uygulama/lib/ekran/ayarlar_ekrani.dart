import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../arayuz/ortak.dart';
import '../model/calisma.dart';
import '../servis/termux.dart';

/// Ayarlar: GitHub hesabı, SSH anahtarı, uzak sunucular, görünüm ve bağlantı.
/// Giriş işlemleri her aracın kendi akışıyla Termux'ta yapılır.
class AyarlarEkrani extends StatefulWidget {
  const AyarlarEkrani({super.key, required this.calisma});
  final Calisma calisma;

  @override
  State<AyarlarEkrani> createState() => _AyarlarEkraniState();
}

class _AyarlarEkraniState extends State<AyarlarEkrani> {
  Map<String, dynamic>? _gh;
  Map<String, dynamic>? _ssh;
  final _sinanan = <String, String>{}; // sunucu → test sonucu
  String? _calisan;

  Calisma get c => widget.calisma;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    try {
      final gh = await c.istemci.iste('gh_durum');
      final ssh = await c.istemci.iste('ssh_durum');
      if (mounted) {
        setState(() {
          _gh = gh;
          _ssh = ssh;
        });
      }
      await c.yenile();
    } catch (e) {
      _bildir('$e');
    }
  }

  void _bildir(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  Future<void> _yap(String ad, Future<void> Function() is_) async {
    setState(() => _calisan = ad);
    try {
      await is_();
    } catch (e) {
      _bildir('$e');
    } finally {
      if (mounted) setState(() => _calisan = null);
      await _yukle();
    }
  }

  /// Termux'ta bir komutu terminal açarak çalıştır; Android dışında komutu kopyala.
  Future<void> _terminalde(String komut, String aciklama) async {
    bool acildi;
    try {
      acildi = await Termux.terminaldeAc(komut);
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: komut));
      acildi = false;
    }
    _bildir(
      acildi
          ? '$aciklama Termux\'ta açılıyor. Açılmadıysa komut panoda: uzun bas → Paste → Enter.'
          : '$aciklama komutu kopyalandı: $komut'
                '${Termux.destekleniyor ? ' · Termux\'ta uzun bas → Paste → Enter.' : ''}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    final gh = _gh;
    final ssh = _ssh;
    final anahtar = ssh?['anahtar'] as String?;
    final sunucular = ((ssh?['sunucular'] as List?) ?? const []).cast<Map>();
    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Bolum(
                    simge: Icons.hub_outlined,
                    baslik: 'GitHub',
                    aciklama: 'Depoları klonlamak, push etmek ve PR açmak için GitHub CLI (gh).',
                    child: gh == null
                        ? const LinearProgressIndicator()
                        : gh['kurulu'] != true
                        ? _Satir(
                            metin: 'gh kurulu değil.',
                            dugme: FilledButton.tonal(
                              onPressed: () =>
                                  _terminalde('pkg install -y gh', 'Kurulum'),
                              child: const Text('Kur'),
                            ),
                          )
                        : gh['giris'] != true
                        ? _Satir(
                            metin: 'GitHub hesabına giriş yapılmamış.',
                            dugme: FilledButton(
                              onPressed: () => _terminalde(
                                'gh auth login -h github.com -p https -w && gh auth setup-git',
                                'Giriş',
                              ),
                              child: const Text('Giriş yap'),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _Satir(
                                simge: Icon(
                                  Icons.check_circle,
                                  color: const Color(0xFF22C55E),
                                  size: 18,
                                ),
                                metin: '@${gh['kullanici']} olarak bağlı',
                              ),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: OutlinedButton.icon(
                                  onPressed: anahtar == null || _calisan != null
                                      ? null
                                      : () => _yap('ghAnahtar', () async {
                                          await c.istemci.iste(
                                            'gh_anahtar_ekle',
                                          );
                                          _bildir(
                                            'SSH anahtarı GitHub hesabına eklendi.',
                                          );
                                        }),
                                  icon: const Icon(Icons.key, size: 16),
                                  label: const Text(
                                    'SSH anahtarını GitHub\'a ekle',
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                  _Bolum(
                    simge: Icons.key_outlined,
                    baslik: 'SSH anahtarı',
                    aciklama: 'Sunuculara ve GitHub\'a şifresiz bağlanmak için. Gizli anahtar telefondan çıkmaz.',
                    child: ssh == null
                        ? const LinearProgressIndicator()
                        : anahtar == null
                        ? _Satir(
                            metin: 'Henüz anahtar yok.',
                            dugme: FilledButton(
                              onPressed: _calisan != null
                                  ? null
                                  : () => _yap(
                                      'anahtar',
                                      () =>
                                          c.istemci.iste('ssh_anahtar_olustur'),
                                    ),
                              child: const Text('Anahtar oluştur'),
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              KodKutusu(metin: anahtar, enFazla: 90),
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: anahtar),
                                    );
                                    _bildir(
                                      'Açık anahtar kopyalandı. Sunucunun ~/.ssh/authorized_keys dosyasına ekle.',
                                    );
                                  },
                                  icon: const Icon(Icons.copy, size: 16),
                                  label: const Text('Açık anahtarı kopyala'),
                                ),
                              ),
                            ],
                          ),
                  ),
                  _Bolum(
                    simge: Icons.dns_outlined,
                    baslik: 'Sunucular',
                    aciklama: 'Ajanı SSH ile uzak bir makinede çalıştır. Orada claude ya da codex kurulu ve girişli olmalı.',
                    sag: TextButton.icon(
                      onPressed: () => _sunucuDuzenle(),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Ekle'),
                    ),
                    child: sunucular.isEmpty
                        ? Text(
                            'Kayıtlı sunucu yok.',
                            style: TextStyle(color: r.onSurfaceVariant),
                          )
                        : Column(
                            children: [
                              for (final s in sunucular)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.computer_outlined),
                                  title: Text(s['ad'] as String),
                                  subtitle: Text(
                                    '${s['kullanici'] != null ? '${s['kullanici']}@' : ''}${s['host']}:${s['port']}'
                                    '${_sinanan[s['ad']] != null ? '\n${_sinanan[s['ad']]}' : ''}',
                                  ),
                                  isThreeLine: _sinanan[s['ad']] != null,
                                  trailing: Wrap(
                                    children: [
                                      IconButton(
                                        tooltip: 'Bağlantıyı dene',
                                        onPressed: _calisan != null
                                            ? null
                                            : () => _yap('dene', () async {
                                                try {
                                                  final r = await c.istemci
                                                      .iste('sunucu_dene', {
                                                        'ad': s['ad'],
                                                      });
                                                  final araclar =
                                                      (r['araclar'] as List)
                                                          .join(', ');
                                                  _sinanan[s['ad'] as String] =
                                                      '✓ bağlandı · ${araclar.isEmpty ? 'ajan bulunamadı' : araclar}';
                                                } catch (e) {
                                                  _sinanan[s['ad'] as String] =
                                                      '✗ $e';
                                                }
                                              }),
                                        icon: _calisan == 'dene'
                                            ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Icon(Icons.network_check),
                                      ),
                                      IconButton(
                                        tooltip: 'Düzenle',
                                        onPressed: () => _sunucuDuzenle(
                                          s.cast<String, dynamic>(),
                                        ),
                                        icon: const Icon(Icons.edit_outlined),
                                      ),
                                      IconButton(
                                        tooltip: 'Sil',
                                        onPressed: () => _yap(
                                          'sil',
                                          () => c.istemci.iste('sunucu_sil', {
                                            'ad': s['ad'],
                                          }),
                                        ),
                                        icon: const Icon(Icons.delete_outline),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                  ),
                  _Bolum(
                    simge: Icons.palette_outlined,
                    baslik: 'Görünüm',
                    child: ListenableBuilder(
                      listenable: c,
                      builder: (context, _) => SegmentedButton<ThemeModeSecimi>(
                        segments: const [
                          ButtonSegment(
                            value: ThemeModeSecimi.acik,
                            label: Text('Açık'),
                            icon: Icon(Icons.light_mode_outlined),
                          ),
                          ButtonSegment(
                            value: ThemeModeSecimi.sistem,
                            label: Text('Sistem'),
                            icon: Icon(Icons.brightness_auto_outlined),
                          ),
                          ButtonSegment(
                            value: ThemeModeSecimi.koyu,
                            label: Text('Koyu'),
                            icon: Icon(Icons.dark_mode_outlined),
                          ),
                        ],
                        selected: {c.tema},
                        onSelectionChanged: (s) => c.temaDegistir(s.first),
                      ),
                    ),
                  ),
                  _Bolum(
                    simge: Icons.cable_outlined,
                    baslik: 'Köprü',
                    child: _Satir(
                      metin: '127.0.0.1:${c.ayarlar.port} · ${c.kok ?? ''}',
                      dugme: Termux.destekleniyor
                          ? OutlinedButton(
                              onPressed: Termux.kopruyuBaslat,
                              child: const Text('Yeniden başlat'),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sunucuDuzenle([Map<String, dynamic>? s]) async {
    final ad = TextEditingController(text: s?['ad'] as String? ?? '');
    final host = TextEditingController(text: s?['host'] as String? ?? '');
    final kullanici = TextEditingController(
      text: s?['kullanici'] as String? ?? '',
    );
    final port = TextEditingController(text: '${s?['port'] ?? 22}');
    final klasor = TextEditingController(text: s?['klasor'] as String? ?? '~');
    final kaydet = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s == null ? 'Sunucu ekle' : 'Sunucuyu düzenle'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ad,
                decoration: const InputDecoration(
                  labelText: 'Ad',
                  hintText: 'ev-sunucusu',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: host,
                decoration: const InputDecoration(
                  labelText: 'Adres',
                  hintText: '192.168.1.20 ya da alan adı',
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: kullanici,
                      decoration: const InputDecoration(labelText: 'Kullanıcı'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 90,
                    child: TextField(
                      controller: port,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Port'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: klasor,
                decoration: const InputDecoration(
                  labelText: 'Varsayılan klasör',
                  hintText: '/home/kullanici/projeler',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
    if (kaydet != true) return;
    await _yap('kaydet', () async {
      if (s != null && s['ad'] != ad.text.trim()) {
        await c.istemci.iste('sunucu_sil', {'ad': s['ad']});
      }
      await c.istemci.iste('sunucu_kaydet', {
        'ad': ad.text.trim(),
        'host': host.text.trim(),
        'kullanici': kullanici.text.trim(),
        'port': int.tryParse(port.text) ?? 22,
        'klasor': klasor.text.trim(),
      });
    });
  }
}

class _Bolum extends StatelessWidget {
  const _Bolum({
    required this.simge,
    required this.baslik,
    required this.child,
    this.aciklama,
    this.sag,
  });
  final IconData simge;
  final String baslik;
  final String? aciklama;
  final Widget child;
  final Widget? sag;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(simge, size: 20, color: r.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      baslik,
                      style: t.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  ?sag,
                ],
              ),
              if (aciklama != null) ...[
                const SizedBox(height: 4),
                Text(
                  aciklama!,
                  style: t.textTheme.bodySmall?.copyWith(
                    color: r.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _Satir extends StatelessWidget {
  const _Satir({required this.metin, this.dugme, this.simge});
  final String metin;
  final Widget? dugme;
  final Widget? simge;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (simge != null) ...[simge!, const SizedBox(width: 8)],
      Expanded(child: Text(metin)),
      ?dugme,
    ],
  );
}
