import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../model/calisma.dart';
import '../servis/port_tara.dart';

/// Uygulamanın içinde web görünümü yalnızca Android/iOS/macOS'ta var;
/// diğerlerinde sayfa tarayıcıda açılır.
bool get gomuluTarayiciVar =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS);

/// Bu cihazdaki bir adres mi (geliştirme sunucusu)?
bool yerelAdres(Uri u) =>
    (u.scheme == 'http' || u.scheme == 'https') &&
    const {
      'localhost',
      '127.0.0.1',
      '0.0.0.0',
      '[::1]',
      '::1',
    }.contains(u.host);

/// Bir yerel adresi (ya da köprünün sunduğu HTML sayfasını) açar: mümkünse
/// uygulamanın içinde, değilse tarayıcıda.
Future<void> onizlemeAc(BuildContext context, Calisma c, Uri adres) async {
  if (adres.host == '0.0.0.0') adres = adres.replace(host: '127.0.0.1');
  if (!gomuluTarayiciVar) {
    await launchUrl(adres, mode: LaunchMode.externalApplication);
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => CanliOnizleme(calisma: c, adres: adres),
    ),
  );
}

/// Ajanın başlattığı geliştirme sunucusunu (Vite, Flask, http.server…)
/// uygulamadan çıkmadan görmek için: adres verilmezse yerel sunucular taranır.
class CanliOnizleme extends StatefulWidget {
  const CanliOnizleme({super.key, required this.calisma, this.adres});

  final Calisma calisma;
  final Uri? adres;

  @override
  State<CanliOnizleme> createState() => _CanliOnizlemeState();
}

class _CanliOnizlemeState extends State<CanliOnizleme> {
  WebViewController? _w;
  Uri? _adres;
  String _baslik = '';
  int _yuzde = 100;
  String? _hata;
  bool _geri = false;
  final _alan = TextEditingController();
  List<int>? _sunucular;

  @override
  void initState() {
    super.initState();
    if (widget.adres != null) {
      _ac(widget.adres!);
    } else {
      _tara();
    }
  }

  @override
  void dispose() {
    _alan.dispose();
    super.dispose();
  }

  Future<void> _tara() async {
    setState(() => _sunucular = null);
    final p = await yerelSunuculariTara(haric: {widget.calisma.ayarlar.port});
    if (mounted) setState(() => _sunucular = p);
  }

  WebViewController _denetleyici() => WebViewController()
    ..setJavaScriptMode(JavaScriptMode.unrestricted)
    ..setNavigationDelegate(
      NavigationDelegate(
        onProgress: (y) {
          if (mounted) setState(() => _yuzde = y);
        },
        onPageStarted: (a) {
          if (!mounted) return;
          setState(() {
            _hata = null;
            _alan.text = _goster(Uri.tryParse(a));
          });
        },
        onPageFinished: (a) async {
          final w = _w;
          if (w == null || !mounted) return;
          final baslik = await w.getTitle() ?? '';
          final geri = await w.canGoBack();
          if (mounted) {
            setState(() {
              _baslik = baslik;
              _geri = geri;
              _alan.text = _goster(Uri.tryParse(a));
            });
          }
        },
        onWebResourceError: (e) {
          if (e.isForMainFrame == false || !mounted) return;
          setState(
            () => _hata =
                'Sayfa açılamadı (${e.description}). Sunucu çalışıyor mu? '
                'Ajandan sunucuyu başlatmasını isteyebilirsin.',
          );
        },
      ),
    );

  /// Köprünün dosya adresindeki erişim anahtarı adres çubuğunda görünmesin.
  String _goster(Uri? u) {
    if (u == null) return '';
    if (u.port == widget.calisma.ayarlar.port) return _baslik;
    return u.toString().replaceFirst(RegExp(r'^http://'), '');
  }

  void _ac(Uri adres) {
    _adres = adres;
    _hata = null;
    _alan.text = _goster(adres);
    if (gomuluTarayiciVar) {
      _w ??= _denetleyici();
      _w!.loadRequest(adres);
    }
    setState(() {});
  }

  void _alandanAc(String metin) {
    var m = metin.trim();
    if (m.isEmpty) return;
    if (RegExp(r'^\d+$').hasMatch(m)) m = '127.0.0.1:$m';
    if (!m.contains('://')) m = 'http://$m';
    final u = Uri.tryParse(m);
    if (u != null) _ac(u);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    final w = _w;
    return PopScope(
      canPop: !_geri,
      onPopInvokedWithResult: (bitti, _) {
        if (!bitti) w?.goBack();
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: SizedBox(
            height: 40,
            child: TextField(
              controller: _alan,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.go,
              onSubmitted: _alandanAc,
              style: t.textTheme.bodyMedium,
              decoration: InputDecoration(
                hintText: 'Port ya da adres (ör. 5173)',
                isDense: true,
                filled: true,
                fillColor: r.surfaceContainerHighest,
                prefixIcon: const Icon(Icons.language, size: 18),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),
          actions: [
            if (w != null)
              IconButton(
                tooltip: 'Yenile',
                onPressed: w.reload,
                icon: const Icon(Icons.refresh),
              ),
            if (_adres != null)
              IconButton(
                tooltip: 'Tarayıcıda aç',
                onPressed: () async {
                  final a = await w?.currentUrl();
                  await launchUrl(
                    a != null ? Uri.parse(a) : _adres!,
                    mode: LaunchMode.externalApplication,
                  );
                },
                icon: const Icon(Icons.open_in_browser),
              ),
            if (_adres != null)
              IconButton(
                tooltip: 'Yerel sunucular',
                onPressed: () {
                  setState(() => _adres = null);
                  _tara();
                },
                icon: const Icon(Icons.dns_outlined),
              ),
          ],
          bottom: _yuzde < 100 && _adres != null
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(2),
                  child: LinearProgressIndicator(value: _yuzde / 100),
                )
              : null,
        ),
        body: _adres == null
            ? _sunucuListesi(context)
            : !gomuluTarayiciVar
            ? _Ortada(
                simge: Icons.open_in_browser,
                metin: 'Bu platformda sayfa tarayıcıda açılır.',
                dugme: FilledButton(
                  onPressed: () =>
                      launchUrl(_adres!, mode: LaunchMode.externalApplication),
                  child: const Text('Tarayıcıda aç'),
                ),
              )
            : Stack(
                children: [
                  WebViewWidget(controller: w!),
                  if (_hata != null)
                    Positioned.fill(
                      child: ColoredBox(
                        color: r.surface,
                        child: _Ortada(
                          simge: Icons.cloud_off_outlined,
                          metin: _hata!,
                          dugme: FilledButton.icon(
                            onPressed: () => _ac(_adres!),
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Yeniden dene'),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _sunucuListesi(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    final s = _sunucular;
    return RefreshIndicator(
      onRefresh: _tara,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Yerel sunucular', style: t.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Ajanın bu telefonda başlattığı geliştirme sunucuları (Vite, Flask, '
            'python -m http.server…). Listede yoksa üstteki alana port yaz.',
            style: t.textTheme.bodySmall?.copyWith(color: r.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          if (s == null)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (s.isEmpty)
            _Ortada(
              simge: Icons.dns_outlined,
              metin:
                  'Çalışan bir sunucu bulunamadı. Ajandan örneğin '
                  '"projeyi 5173 portunda çalıştır" diye isteyebilirsin.',
              dugme: OutlinedButton.icon(
                onPressed: _tara,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Yeniden tara'),
              ),
            )
          else
            for (final p in s)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.public),
                  title: Text('127.0.0.1:$p'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _ac(Uri.parse('http://127.0.0.1:$p/')),
                ),
              ),
        ],
      ),
    );
  }
}

class _Ortada extends StatelessWidget {
  const _Ortada({required this.simge, required this.metin, this.dugme});
  final IconData simge;
  final String metin;
  final Widget? dugme;

  @override
  Widget build(BuildContext context) {
    final r = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(simge, size: 40, color: r.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(metin, textAlign: TextAlign.center),
            if (dugme != null) ...[const SizedBox(height: 16), dugme!],
          ],
        ),
      ),
    );
  }
}
