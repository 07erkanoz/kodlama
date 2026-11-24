import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../model/calisma.dart';
import '../servis/apk_indir.dart';
import '../servis/termux.dart';

/// Git panelinin "Bulutta derleme" bölümü: Flutter APK'sı kullanıcının
/// GitHub Actions'ında derlenir (Atölye'nin iş akışı şablonu), Atölye
/// derlemeyi başlatır ya da ajanın başlattığını izler, bitince APK'yı indirip
/// Android'in yükleme ekranını açar.
class DerlemeBolumu extends StatefulWidget {
  const DerlemeBolumu({
    super.key,
    required this.calisma,
    required this.cwd,
    required this.degisti,
  });

  final Calisma calisma;
  final String cwd;

  /// İş akışı dosyası eklenince Git panelini yeniler.
  final VoidCallback degisti;

  @override
  State<DerlemeBolumu> createState() => _DerlemeBolumuState();
}

class _DerlemeBolumuState extends State<DerlemeBolumu> {
  Map<String, dynamic>? _d;
  String?
  _calisan; // 'sablon', 'imza', 'baslat', ya da indirilen çalışmanın kimliği
  double? _ilerleme;
  Timer? _izle;

  Calisma get c => widget.calisma;

  @override
  void initState() {
    super.initState();
    _yenile();
  }

  @override
  void didUpdateWidget(DerlemeBolumu old) {
    super.didUpdateWidget(old);
    if (old.cwd != widget.cwd) {
      _d = null;
      _yenile();
    }
  }

  @override
  void dispose() {
    _izle?.cancel();
    super.dispose();
  }

  List<Map> get _calismalar =>
      ((_d?['calismalar'] as List?) ?? const []).cast<Map>();

  Future<void> _yenile() async {
    try {
      final d = await c.istemci.iste('derleme_durum', {'cwd': widget.cwd});
      if (!mounted) return;
      setState(() => _d = d);
    } catch (_) {
      if (mounted) setState(() => _d = {'flutter': null});
    }
    // Süren bir derleme varsa 15 sn'de bir bak.
    _izle?.cancel();
    if (_calismalar.any((r) => r['status'] != 'completed')) {
      _izle = Timer(const Duration(seconds: 15), _yenile);
    }
  }

  void _bildir(String metin) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(metin)));
  }

  Future<void> _yap(String ad, Future<void> Function() is_) async {
    setState(() => _calisan = ad);
    try {
      await is_();
    } catch (e) {
      _bildir('$e'.replaceFirst(RegExp(r'^\w*(Hatasi|Exception|Error): '), ''));
    } finally {
      if (mounted) setState(() => _calisan = null);
      await _yenile();
    }
  }

  Future<void> _sablon() => _yap('sablon', () async {
    final r = await c.istemci.iste('derleme_sablon', {'cwd': widget.cwd});
    widget.degisti();
    _bildir(
      r['vardi'] == true
          ? 'İş akışı zaten vardı.'
          : 'İş akışı eklendi. Commit edip push edince derleme başlatılabilir.',
    );
  });

  Future<void> _imza() => _yap('imza', () async {
    final r = await c.istemci.iste('derleme_imza', {'cwd': widget.cwd});
    _bildir('İmza anahtarı GitHub\'a kondu. Yedeği: ${r['yedek']}');
  });

  Future<void> _baslat() => _yap('baslat', () async {
    await c.istemci.iste('derleme_baslat', {'cwd': widget.cwd});
    _bildir('Derleme başladı. Birkaç dakika sürer; bittiğinde burada görünür.');
    await Future<void>.delayed(const Duration(seconds: 4));
  });

  Future<void> _indirKur(Map r) async {
    final id = '${r['databaseId']}';
    setState(() {
      _calisan = id;
      _ilerleme = null;
    });
    try {
      final s = await c.istemci.iste('derleme_indir', {
        'cwd': widget.cwd,
        'calisma': r['databaseId'],
      });
      final apk = ((s['apkler'] as List).first as Map)['yol'] as String;
      if (!Termux.destekleniyor) {
        _bildir('APK indirildi: $apk');
        return;
      }
      if (!await Termux.kurulumIzniVar()) {
        _bildir('Önce Atölye\'ye "bilinmeyen uygulamaları yükle" izni ver.');
        await Termux.kurulumIzniAc();
        return;
      }
      final yerel = await apkIndir(
        c.istemci.dosyaAdresi(apk),
        apk.split('/').last,
        ilerleme: (o) {
          if (mounted) setState(() => _ilerleme = o);
        },
      );
      await Termux.apkKur(yerel);
    } catch (e) {
      _bildir('İndirilemedi: $e');
    } finally {
      if (mounted) {
        setState(() {
          _calisan = null;
          _ilerleme = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _d;
    if (d == null || d['flutter'] == null) return const SizedBox.shrink();
    final t = Theme.of(context);
    final r = t.colorScheme;
    final mesgul = _calisan != null;
    final akis = d['akis'] == true;
    final depo = d['depo'] as String?;
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cloud_outlined, size: 16, color: r.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Bulutta derleme (APK)',
                  style: t.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Yenile',
                visualDensity: VisualDensity.compact,
                onPressed: mesgul ? null : _yenile,
                icon: const Icon(Icons.refresh, size: 18),
              ),
            ],
          ),
          Text(
            depo == null
                ? 'Flutter uygulaması (${d['flutter']}) GitHub Actions\'ta derlenebilir; '
                      'bunun için depo GitHub\'da olmalı ve gh ile giriş yapılmalı.'
                : 'Telefonda Android SDK yok: APK $depo deposunun GitHub Actions\'ında '
                      'derlenir, buradan indirilip kurulur. Ajan da başlatabilir.',
            style: t.textTheme.bodySmall?.copyWith(color: r.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          if (depo != null && !akis)
            _Dugme(
              simge: Icons.add,
              ad: 'Derleme iş akışını ekle',
              calisiyor: _calisan == 'sablon',
              etkin: !mesgul,
              bas: _sablon,
            ),
          if (depo != null && akis) ...[
            if (d['imza'] != true)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: r.tertiaryContainer.withValues(alpha: .5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'İmza anahtarı yok: her derleme rastgele bir anahtarla imzalanır '
                      've telefondaki eski sürümün üstüne kurulamaz. Kalıcı bir anahtar '
                      'üretilip deponun gizli değişkenlerine konsun mu?',
                      style: t.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    _Dugme(
                      simge: Icons.key_outlined,
                      ad: 'İmza anahtarını kur',
                      calisiyor: _calisan == 'imza',
                      etkin: !mesgul,
                      bas: _imza,
                    ),
                  ],
                ),
              ),
            _Dugme(
              simge: Icons.play_arrow_rounded,
              ad: 'Derle',
              calisiyor: _calisan == 'baslat',
              etkin: !mesgul,
              bas: _baslat,
            ),
          ],
          if (d['uyari'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${d['uyari']}',
                style: t.textTheme.bodySmall?.copyWith(color: r.error),
              ),
            ),
          if (d['hata'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${d['hata']}',
                style: t.textTheme.bodySmall?.copyWith(color: r.error),
              ),
            ),
          const SizedBox(height: 6),
          for (final k in _calismalar) _satir(context, k, mesgul),
        ],
      ),
    );
  }

  Widget _satir(BuildContext context, Map k, bool mesgul) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    final bitti = k['status'] == 'completed';
    final basarili = k['conclusion'] == 'success';
    final indiriliyor = _calisan == '${k['databaseId']}';
    final zaman = DateTime.tryParse('${k['createdAt']}')?.toLocal();
    final Widget simge = !bitti
        ? const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(
            basarili ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 18,
            color: basarili ? const Color(0xFF16A34A) : r.error,
          );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          simge,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${k['displayTitle'] ?? 'Derleme'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.textTheme.bodyMedium,
                ),
                Text(
                  [
                    '${k['headBranch'] ?? ''}',
                    if (zaman != null) _once(zaman),
                    if (!bitti)
                      'sürüyor'
                    else if (!basarili)
                      k['conclusion'] == 'cancelled' ? 'iptal' : 'başarısız',
                  ].where((x) => x.isNotEmpty).join(' · '),
                  style: t.textTheme.bodySmall?.copyWith(
                    color: r.onSurfaceVariant,
                  ),
                ),
                if (indiriliyor)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: LinearProgressIndicator(value: _ilerleme),
                  ),
              ],
            ),
          ),
          if (bitti && basarili)
            TextButton.icon(
              onPressed: mesgul ? null : () => _indirKur(k),
              icon: const Icon(Icons.install_mobile_outlined, size: 18),
              label: Text(Termux.destekleniyor ? 'Kur' : 'İndir'),
            )
          else
            IconButton(
              tooltip: 'GitHub\'da aç',
              visualDensity: VisualDensity.compact,
              onPressed: () => launchUrl(
                Uri.parse('${k['url']}'),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new, size: 16),
            ),
        ],
      ),
    );
  }

  static String _once(DateTime z) {
    final f = DateTime.now().difference(z);
    if (f.inMinutes < 1) return 'az önce';
    if (f.inHours < 1) return '${f.inMinutes} dk önce';
    if (f.inDays < 1) return '${f.inHours} sa önce';
    return '${f.inDays} gün önce';
  }
}

class _Dugme extends StatelessWidget {
  const _Dugme({
    required this.simge,
    required this.ad,
    required this.calisiyor,
    required this.etkin,
    required this.bas,
  });

  final IconData simge;
  final String ad;
  final bool calisiyor, etkin;
  final VoidCallback bas;

  @override
  Widget build(BuildContext context) => FilledButton.tonalIcon(
    onPressed: etkin ? bas : null,
    icon: calisiyor
        ? const SizedBox.square(
            dimension: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(simge, size: 18),
    label: Text(ad),
  );
}
