import 'package:flutter/material.dart';

import '../model/calisma.dart';
import '../model/sohbet.dart';
import 'onizleme.dart';

/// Çalışma klasörü: bu oturumda değişen dosyalar ve klasör gezgini.
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

class _DosyaPaneliState extends State<DosyaPaneli> {
  late String _klasor = widget.sohbet.cwd;
  Future<Map<String, dynamic>>? _liste;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void didUpdateWidget(DosyaPaneli old) {
    super.didUpdateWidget(old);
    if (old.sohbet.id != widget.sohbet.id) {
      _klasor = widget.sohbet.cwd;
      _yukle();
    }
  }

  void _yukle() {
    setState(() {
      _liste = widget.calisma.istemci.iste('listele', {'yol': _klasor});
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return DefaultTabController(
      length: 2,
      child: Material(
        color: t.colorScheme.surfaceContainerLow,
        child: SafeArea(
          left: false,
          child: Column(
            children: [
              const TabBar(
                tabs: [
                  Tab(text: 'Bu oturum'),
                  Tab(text: 'Klasör'),
                ],
              ),
              Expanded(
                child: TabBarView(children: [_oturumDosyalari(t), _gezgin(t)]),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
                onTap: () => widget.ac(d.yol),
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
              if (ust != null && _klasor != widget.sohbet.cwd)
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
                        widget.ac(o['yol'] as String);
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
