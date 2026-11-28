import 'package:flutter/material.dart';

import '../model/calisma.dart';
import '../arayuz/ssh_hatasi.dart';
import '../model/sohbet.dart';
import 'git_paneli.dart';
import 'onizleme.dart';

/// Çalışma klasörü: bu oturumda değişen dosyalar, klasör gezgini ve Git.
class DosyaPaneli extends StatefulWidget {
  const DosyaPaneli({
    super.key,
    required this.calisma,
    required this.sohbet,
    required this.ac,
  });

  final Calisma calisma;
  final Sohbet sohbet;
  final void Function(String yol) ac;

  @override
  State<DosyaPaneli> createState() => _DosyaPaneliState();
}

class _DosyaPaneliState extends State<DosyaPaneli>
    with SingleTickerProviderStateMixin {
  late String _klasor = widget.sohbet.panelKlasoru ?? _kok;
  bool _aciliyor = false;

  /// Uzak oturumda dosyalar SSH ile gezilir (köprü destekliyorsa).
  bool get _uzak => widget.sohbet.sunucu != null;
  bool get _uzakGezilir => _uzak && widget.calisma.yetenek('uzak_dosya');
  String get _kok =>
      _uzak ? (widget.sohbet.uzakKlasor ?? '~') : widget.sohbet.cwd;
  Future<Map<String, dynamic>>? _liste;
  late final TabController _sekme = TabController(
    length: 3,
    vsync: this,
    initialIndex: widget.sohbet.panelSekmesi.clamp(0, 2),
  )..addListener(() => widget.sohbet.panelSekmesi = _sekme.index);

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    _sekme.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(DosyaPaneli old) {
    super.didUpdateWidget(old);
    if (old.sohbet.id != widget.sohbet.id) {
      _klasor = widget.sohbet.panelKlasoru ?? _kok;
      _sekme.index = widget.sohbet.panelSekmesi.clamp(0, 2);
      _yukle();
    }
  }

  void _yukle() {
    if (_uzak && !_uzakGezilir) return;
    widget.sohbet.panelKlasoru = _klasor;
    setState(() {
      _liste = _uzak
          ? widget.calisma.istemci
                .iste('uzak_gez', {
                  'sunucu': widget.sohbet.sunucu,
                  'yol': _klasor,
                })
                .then((d) {
                  // "~" gibi yollar sunucuda açılmış haliyle sürsün
                  _klasor = d['yol'] as String? ?? _klasor;
                  widget.sohbet.panelKlasoru = _klasor;
                  return d;
                })
          : widget.calisma.istemci.iste('listele', {'yol': _klasor});
    });
  }

  /// Dosyayı aç: uzak oturumda önce bu cihaza indirilir.
  Future<void> _dosyaAc(String yol) async {
    if (!_uzak) {
      widget.ac(yol);
      return;
    }
    if (_aciliyor) return;
    final m = ScaffoldMessenger.of(context);
    setState(() => _aciliyor = true);
    try {
      final yerel = await widget.calisma.uzakYerel(widget.sohbet, yol);
      if (mounted) widget.ac(yerel);
    } catch (e) {
      m.showSnackBar(SnackBar(content: Text('Açılamadı: $e')));
    } finally {
      if (mounted) setState(() => _aciliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Material(
      color: t.colorScheme.surfaceContainerLow,
      child: SafeArea(
        left: false,
        child: Column(
          children: [
            if (_aciliyor) const LinearProgressIndicator(minHeight: 2),
            TabBar(
              controller: _sekme,
              tabs: const [
                Tab(text: 'Bu oturum'),
                Tab(text: 'Klasör'),
                Tab(text: 'Git'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _sekme,
                children: [
                  _oturumDosyalari(t),
                  _uzak && !_uzakGezilir ? _uzakBilgi(t) : _gezgin(t),
                  GitPaneli(calisma: widget.calisma, sohbet: widget.sohbet),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _uzakBilgi(ThemeData t) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        '${widget.sohbet.sunucu} sunucusundaki klasör (${widget.sohbet.uzakKlasor}) buradan gezilemiyor; '
        'köprüyü güncelleyince (Ayarlar › Köprü) gezilebilir.',
        textAlign: TextAlign.center,
        style: TextStyle(color: t.colorScheme.onSurfaceVariant),
      ),
    ),
  );

  Widget _oturumDosyalari(ThemeData t) {
    return ListenableBuilder(
      listenable: widget.sohbet,
      builder: (context, _) {
        final dosyalar = widget.sohbet.dosyalar;
        if (dosyalar.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Ajanın oluşturduğu ya da değiştirdiği dosyalar burada görünür.',
                textAlign: TextAlign.center,
                style: TextStyle(color: t.colorScheme.onSurfaceVariant),
              ),
            ),
          );
        }
        return ListView(
          children: [
            for (final d in dosyalar)
              ListTile(
                dense: true,
                leading: Icon(dosyaSimgesi(d.yol)),
                title: Text(d.goreli, overflow: TextOverflow.ellipsis),
                subtitle: Text(d.eylem == 'yeni' ? 'yeni' : 'değişti'),
                onTap: () => _dosyaAc(d.yol),
              ),
          ],
        );
      },
    );
  }

  Widget _gezgin(ThemeData t) {
    return FutureBuilder(
      future: _liste,
      builder: (context, snap) {
        if (snap.hasError) {
          final ssh = sshAyrintisi(snap.error!);
          if (ssh != null) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: SshHataKarti(
                calisma: widget.calisma,
                mesaj: '${snap.error}',
                ayrinti: ssh,
                cozuldu: _yukle,
              ),
            );
          }
          return Center(child: Text('${snap.error}'));
        }
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final d = snap.data!;
        final ogeler = (d['ogeler'] as List).cast<Map>();
        final ust = d['ust'] as String?;
        return RefreshIndicator(
          onRefresh: () async => _yukle(),
          child: ListView(
            children: [
              ListTile(
                dense: true,
                title: Text(
                  _klasor.split('/').last,
                  style: t.textTheme.titleSmall,
                ),
                trailing: IconButton(
                  tooltip: 'Yenile',
                  onPressed: _yukle,
                  icon: const Icon(Icons.refresh),
                ),
              ),
              if (ust != null && (_uzak || _klasor != widget.sohbet.cwd))
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.arrow_upward),
                  title: const Text('..'),
                  onTap: () {
                    _klasor = ust;
                    _yukle();
                  },
                ),
              for (final o in ogeler)
                if (!(o['ad'] as String).startsWith('.'))
                  ListTile(
                    dense: true,
                    leading: Icon(
                      o['klasor'] == true
                          ? Icons.folder_outlined
                          : dosyaSimgesi(o['yol'] as String),
                    ),
                    title: Text(
                      o['ad'] as String,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: o['klasor'] == true
                        ? null
                        : Text(_boyut(o['boyut'] as int)),
                    onTap: () {
                      if (o['klasor'] == true) {
                        _klasor = o['yol'] as String;
                        _yukle();
                      } else {
                        _dosyaAc(o['yol'] as String);
                      }
                    },
                  ),
            ],
          ),
        );
      },
    );
  }

  static String _boyut(int b) => b < 1024
      ? '$b B'
      : b < 1024 * 1024
      ? '${(b / 1024).toStringAsFixed(1)} KB'
      : '${(b / 1024 / 1024).toStringAsFixed(1)} MB';
}
