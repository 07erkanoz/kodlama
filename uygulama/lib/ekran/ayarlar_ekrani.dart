import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../arayuz/ortak.dart';
import '../model/calisma.dart';
import '../model/sesli_konusma.dart';
import '../servis/termux.dart';
import 'giris_penceresi.dart';
import 'kurulum_paneli.dart';

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
  Map<String, dynamic>? _araclar;
  final _sinanan = <String, String>{}; // sunucu → test sonucu
  final _hatalar = <String, String>{}; // işlem → yüklenemediyse neden
  String? _calisan;

  Calisma get c => widget.calisma;

  @override
  void initState() {
    super.initState();
    c.addListener(_ciz);
    _yukle();
  }

  void _ciz() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    c.removeListener(_ciz);
    _sesModeli.dispose();
    super.dispose();
  }

  /// Her bölüm ayrı yüklenir: biri yüklenemezse (ör. eski köprü bir işlemi
  /// tanımıyor) ötekiler yine görünür ve neden yüklenemediği yazılır.
  Future<void> _yukle() async {
    Future<Map<String, dynamic>?> al(String op) async {
      try {
        final r = await c.istemci.iste(op);
        _hatalar.remove(op);
        return r;
      } catch (e) {
        final m = '$e';
        _hatalar[op] = m.contains('bilinmeyen işlem')
            ? 'Telefondaki köprü bu özelliği bilmiyor; aşağıdaki Köprü bölümünden güncelle.'
            : m;
        return null;
      }
    }

    final sonuc = await Future.wait([
      al('gh_durum'),
      al('ssh_durum'),
      al('araclar'),
    ]);
    if (mounted) {
      setState(() {
        _gh = sonuc[0] ?? _gh;
        _ssh = sonuc[1] ?? _ssh;
        _araclar = sonuc[2] ?? _araclar;
      });
    }
    await c.yenile();
    if (mounted) setState(() {});
  }

  /// Yüklenirken ilerleme, yüklenemediyse nedeni.
  Widget _bekle(String op) {
    final hata = _hatalar[op];
    if (hata == null) return const LinearProgressIndicator();
    return Text(
      hata,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    );
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
                  _ajanlarBolumu(t),
                  _sesBolumu(t),
                  _termuxBolumu(t),
                  _Bolum(
                    simge: Icons.hub_outlined,
                    baslik: 'GitHub',
                    aciklama: 'Depoları klonlamak, push etmek ve PR açmak için GitHub CLI (gh).',
                    child: gh == null
                        ? _bekle('gh_durum')
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
                              onPressed: () async {
                                await girisPenceresi(context, c, 'gh');
                                if (mounted) await _yukle();
                              },
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
                        ? _bekle('ssh_durum')
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
                  _kopruBolumu(t),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _ajanlarBolumu(ThemeData t) {
    final r = t.colorScheme;
    final termux = Termux.destekleniyor;
    final ajanlar = c.ajanlar.isNotEmpty
        ? c.ajanlar
        : const [
            {'ad': 'claude', 'kurulu': false},
            {'ad': 'codex', 'kurulu': false},
          ];
    return _Bolum(
      simge: Icons.smart_toy_outlined,
      baslik: 'Ajanlar',
      aciklama: 'Kurulu olmayan ajanı buradan kurabilir, kurulu olanı güncelleyebilir ya da hesabına giriş yapabilirsin.',
      child: Column(
        children: [
          for (final a in ajanlar)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  AjanRozeti(ajan: a['ad'] as String, boyut: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ajanAdi(a['ad'] as String),
                          style: t.textTheme.titleSmall,
                        ),
                        Text(
                          a['kurulu'] == true
                              ? (a['surum'] as String? ?? 'kurulu')
                              : 'kurulu değil',
                          style: t.textTheme.bodySmall?.copyWith(
                            color: a['kurulu'] == true
                                ? r.onSurfaceVariant
                                : r.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Giriş köprünün çalıştığı her yerde anlamlı; kurulum betiği yalnız Termux'a özgü.
                  if (a['kurulu'] == true)
                    TextButton(
                      onPressed: () =>
                          girisPenceresi(context, c, a['ad'] as String),
                      child: const Text('Giriş yap'),
                    ),
                  if (termux) ...[
                    const SizedBox(width: 4),
                    (a['kurulu'] == true
                        ? OutlinedButton.new
                        : FilledButton.new)(
                      onPressed: () => ajanKur(context, c, a['ad'] as String),
                      child: Text(a['kurulu'] == true ? 'Güncelle' : 'Kur'),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  late final _sesModeli = TextEditingController(text: c.ayarlar.sesModeli);

  Widget _sesBolumu(ThemeData t) {
    final a = c.ayarlar;
    final r = t.colorScheme;
    String etiket((String, String) v) =>
        v.$2.isEmpty ? v.$1 : '${v.$1} · ${v.$2}';
    return _Bolum(
      simge: Icons.record_voice_over_outlined,
      baslik: 'Sesli konuşma (Codex)',
      aciklama:
          'Sohbetteki mikrofonla açılan Codex sesinin ayarları; bir sonraki '
          'konuşmada geçerli olur.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: a.sesSesi,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Ses'),
            items: [
              const DropdownMenuItem(
                value: '',
                child: Text('Codex\'in varsayılanı'),
              ),
              for (final v in codexSesleri)
                DropdownMenuItem(value: v.$1, child: Text(etiket(v))),
            ],
            onChanged: (v) => setState(() => a.sesSesi = v ?? ''),
          ),
          const SizedBox(height: 4),
          Text(
            'Cinsiyet yalnızca OpenAI\'nin tanıttığı seslerde yazılı; diğerleri '
            'yeni çok dilli sesler, deneyerek seç.',
            style: t.textTheme.bodySmall?.copyWith(color: r.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
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
          const SizedBox(height: 14),
          TextField(
            controller: _sesModeli,
            decoration: const InputDecoration(
              labelText: 'Ses modeli',
              hintText: 'Boş: Codex\'in ayarı (config.toml)',
              helperText:
                  'Yalnız ses için, ör. gpt-realtime. İşi yapan model sohbetin modelidir.',
            ),
            onChanged: (v) => a.sesModeli = v.trim(),
          ),
        ],
      ),
    );
  }

  Widget _kopruBolumu(ThemeData t) {
    final r = t.colorScheme;
    final surum = c.kopruSurumu;
    final eski = c.kopruEski;
    return _Bolum(
      simge: Icons.cable_outlined,
      baslik: 'Köprü',
      aciklama: 'Termux\'ta çalışan ve ajanları süren küçük servis.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Sürüm ${surum ?? '?'}'
            '${eski ? ' · güncel değil (en az ${Calisma.gerekenKopruSurumu} gerekiyor)' : ''}'
            ' · 127.0.0.1:${c.ayarlar.port}',
            style: t.textTheme.bodyMedium?.copyWith(
              color: eski ? r.error : null,
            ),
          ),
          if (c.kok != null)
            Text(
              c.kok!,
              style: t.textTheme.bodySmall?.copyWith(color: r.onSurfaceVariant),
            ),
          if (Termux.destekleniyor) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                (eski ? FilledButton.icon : OutlinedButton.icon)(
                  onPressed: c.kopruGuncelleniyor
                      ? null
                      : () async {
                          final tamam = await c.kopruyuGuncelle();
                          _bildir(
                            tamam ? 'Köprü güncellendi.' : 'Köprü güncellenemedi; "Araçları yeniden kur"u dene.',
                          );
                          await _yukle();
                        },
                  icon: c.kopruGuncelleniyor
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.system_update, size: 18),
                  label: const Text('Köprüyü güncelle'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      kurulumuCalistir(context, c, c.ayarlar.ajanlar),
                  icon: const Icon(Icons.restart_alt, size: 18),
                  label: const Text('Araçları yeniden kur'),
                ),
                TextButton(
                  onPressed: Termux.kopruyuBaslat,
                  child: const Text('Yeniden başlat'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _termuxBolumu(ThemeData t) {
    final r = t.colorScheme;
    final d = _araclar;
    final araclar = ((d?['araclar'] as List?) ?? const []).cast<Map>();
    final termux = Termux.destekleniyor;
    String gb(num? b) => b == null ? '?' : '${(b / 1e9).toStringAsFixed(1)} GB';
    return _Bolum(
      simge: Icons.terminal,
      baslik: 'Termux ve geliştirme araçları',
      aciklama:
          'Ajanlar eksik araçları kendileri kurar: "Rust kur ve bir proje başlat" demen yeterli. '
          'İstersen buradan da kurabilirsin.',
      sag: IconButton(
        tooltip: 'Yenile',
        onPressed: _yukle,
        icon: const Icon(Icons.refresh, size: 18),
      ),
      child: d == null
          ? _bekle('araclar')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final a in araclar)
                      Tooltip(
                        message: a['surum'] as String? ?? 'kurulu değil',
                        child: Chip(
                          visualDensity: VisualDensity.compact,
                          avatar: Icon(
                            a['surum'] != null
                                ? Icons.check_circle
                                : Icons.circle_outlined,
                            size: 15,
                            color: a['surum'] != null
                                ? const Color(0xFF22C55E)
                                : r.outline,
                          ),
                          label: Text(
                            a['ad'] as String,
                            style: TextStyle(
                              color: a['surum'] != null
                                  ? r.onSurface
                                  : r.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  'Boş alan: ${gb(d['disk_bos'] as num?)} / ${gb(d['disk_toplam'] as num?)}'
                  '${termux ? (d['depolama'] == true ? ' · paylaşılan depolama bağlı' : ' · paylaşılan depolama bağlı değil') : ''}',
                  style: t.textTheme.bodySmall?.copyWith(
                    color: r.onSurfaceVariant,
                  ),
                ),
                if (termux) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: _paketKur,
                        icon: const Icon(Icons.add_box_outlined, size: 18),
                        label: const Text('Paket kur'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            _terminalde('pkg upgrade -y', 'Güncelleme'),
                        icon: const Icon(Icons.system_update_alt, size: 18),
                        label: const Text('Tümünü güncelle'),
                      ),
                      if (d['depolama'] != true)
                        OutlinedButton.icon(
                          onPressed: () => _terminalde(
                            'termux-setup-storage',
                            'Depolama izni',
                          ),
                          icon: const Icon(Icons.sd_storage_outlined, size: 18),
                          label: const Text('Depolama erişimi ver'),
                        ),
                      OutlinedButton.icon(
                        onPressed: () => _terminalde(
                          'pkg install -y proot-distro && proot-distro install ubuntu',
                          'Ubuntu kurulumu',
                        ),
                        icon: const Icon(Icons.layers_outlined, size: 18),
                        label: const Text('Ubuntu (proot) kur'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }

  Future<void> _paketKur() async {
    final ad = TextEditingController();
    final paket = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Termux paketi kur'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: ad,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'ör. rust golang openjdk-21 dart',
                ),
                onSubmitted: (v) => Navigator.pop(context, v),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final p in const [
                    'nodejs-lts',
                    'python',
                    'rust',
                    'golang',
                    'openjdk-21',
                    'dart',
                    'clang',
                    'php',
                  ])
                    ActionChip(
                      label: Text(p),
                      onPressed: () => ad.text = '${ad.text} $p'.trim(),
                    ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, ad.text),
            child: const Text('Kur'),
          ),
        ],
      ),
    );
    final temiz = (paket ?? '')
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => RegExp(r'^[a-z0-9][a-z0-9+.\-]*$').hasMatch(p))
        .join(' ');
    if (temiz.isEmpty) return;
    await _terminalde('pkg install -y $temiz', 'Kurulum');
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
