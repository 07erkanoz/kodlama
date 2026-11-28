import 'package:flutter/material.dart';

import '../model/calisma.dart';
import 'ssh_hatasi.dart';

/// Kayıtlı bir SSH sunucusunda klasör seçtirir: klasörler SSH üzerinden
/// listelenir, dokunarak içine girilir, "Bu klasör" ile seçilir. Köprü
/// eskiyse ya da kullanıcı isterse yol elle de yazılabilir.
Future<String?> uzakKlasorSec(
  BuildContext context,
  Calisma c,
  Map<String, dynamic> sunucu,
  String baslangic,
) {
  if (!c.yetenek('uzak_klasor')) {
    return _elleYaz(context, sunucu['ad'] as String, baslangic);
  }
  return Navigator.of(context).push<String>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) =>
          _UzakKlasorSecici(calisma: c, sunucu: sunucu, baslangic: baslangic),
    ),
  );
}

Future<String?> _elleYaz(BuildContext context, String ad, String yol) async {
  final d = TextEditingController(text: yol);
  final v = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('$ad üzerinde klasör'),
      content: TextField(
        controller: d,
        autofocus: true,
        decoration: const InputDecoration(hintText: '/home/kullanici/proje'),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Vazgeç'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, d.text),
          child: const Text('Tamam'),
        ),
      ],
    ),
  );
  final t = v?.trim();
  return t == null || t.isEmpty ? null : t;
}

class _UzakKlasorSecici extends StatefulWidget {
  const _UzakKlasorSecici({
    required this.calisma,
    required this.sunucu,
    required this.baslangic,
  });

  final Calisma calisma;
  final Map<String, dynamic> sunucu;
  final String baslangic;

  @override
  State<_UzakKlasorSecici> createState() => _UzakKlasorSeciciState();
}

class _UzakKlasorSeciciState extends State<_UzakKlasorSecici> {
  String? _yol; // sunucunun bildirdiği tam yol
  bool _git = false;
  List<String> _klasorler = const [];
  String? _hata;
  Map<String, dynamic>? _sshHata;
  bool _yukleniyor = false;
  bool _gizliler = false;

  String get _ad => widget.sunucu['ad'] as String;

  @override
  void initState() {
    super.initState();
    _ac(widget.baslangic);
  }

  Future<void> _ac(String yol, {String? yeni}) async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
      _sshHata = null;
    });
    try {
      final r = await widget.calisma.istemci.iste('sunucu_listele', {
        'ad': _ad,
        'yol': yol,
        'yeni': ?yeni,
      });
      if (!mounted) return;
      setState(() {
        _yol = r['yol'] as String;
        _git = r['git'] == true;
        _klasorler = ((r['klasorler'] as List?) ?? const []).cast<String>();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = '$e'.replaceFirst('Exception: ', '');
        _sshHata = sshAyrintisi(e);
      });
      // SSH'nin kendisi kurulamadıysa başka klasör denemenin anlamı yok.
      if (_sshHata != null) return;
      // Açılamayan yol ilk açılıştaysa ev klasörüne düş.
      if (_yol == null && yol != '~') {
        await _ac('~');
        if (mounted) {
          setState(() => _hata = '$yol açılamadı; ev klasörü açıldı.');
        }
      }
    } finally {
      if (mounted) setState(() => _yukleniyor = false);
    }
  }

  String _ust(String yol) {
    if (yol == '/' || !yol.contains('/')) return '/';
    final i = yol.lastIndexOf('/');
    return i <= 0 ? '/' : yol.substring(0, i);
  }

  String _alt(String ad) => _yol == '/' ? '/$ad' : '$_yol/$ad';

  Future<void> _yeniKlasor() async {
    final d = TextEditingController();
    final ad = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni klasör'),
        content: TextField(
          controller: d,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'proje-adi'),
          onSubmitted: (v) => Navigator.pop(context, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, d.text),
            child: const Text('Oluştur'),
          ),
        ],
      ),
    );
    if (ad == null || ad.trim().isEmpty || _yol == null) return;
    await _ac(_yol!, yeni: ad.trim());
  }

  Future<void> _elle() async {
    final v = await _elleYaz(context, _ad, _yol ?? widget.baslangic);
    if (v != null) await _ac(v);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    final yol = _yol;
    final gorunen = [
      for (final k in _klasorler)
        if (_gizliler || !k.startsWith('.')) k,
    ];
    final gizliSayisi = _klasorler.where((k) => k.startsWith('.')).length;
    return PopScope(
      // Geri tuşu önce bir üst klasöre çıkar; kökteyken kapatır.
      canPop: yol == null || yol == '/' || _yukleniyor,
      onPopInvokedWithResult: (bitti, _) {
        if (!bitti && yol != null) _ac(_ust(yol));
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Kapat',
            icon: const Icon(Icons.close_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text('$_ad · klasör seç'),
          actions: [
            IconButton(
              tooltip: 'Yolu yaz',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _yukleniyor ? null : _elle,
            ),
            IconButton(
              tooltip: 'Yeni klasör',
              icon: const Icon(Icons.create_new_folder_outlined),
              onPressed: _yukleniyor || yol == null ? null : _yeniKlasor,
            ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: r.surfaceContainerLow,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                child: Row(
                  children: [
                    IconButton(
                      tooltip: 'Üst klasör',
                      onPressed: yol == null || yol == '/' || _yukleniyor
                          ? null
                          : () => _ac(_ust(yol)),
                      icon: const Icon(Icons.arrow_upward_rounded),
                    ),
                    IconButton(
                      tooltip: 'Ev klasörü',
                      onPressed: _yukleniyor ? null : () => _ac('~'),
                      icon: const Icon(Icons.home_outlined),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        yol ?? '…',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: t.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    if (_git)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: r.secondaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'git',
                          style: t.textTheme.labelSmall?.copyWith(
                            color: r.onSecondaryContainer,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            if (_yukleniyor) const LinearProgressIndicator(minHeight: 2),
            if (_sshHata != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: SshHataKarti(
                  calisma: widget.calisma,
                  mesaj: _hata ?? '',
                  ayrinti: _sshHata!,
                  cozuldu: () => _ac(_yol ?? widget.baslangic),
                ),
              )
            else if (_hata != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: Text(_hata!, style: TextStyle(color: r.error)),
              ),
            Expanded(
              child: gorunen.isEmpty && !_yukleniyor
                  ? Center(
                      child: Text(
                        yol == null ? '' : 'Bu klasörde alt klasör yok.',
                        style: TextStyle(color: r.onSurfaceVariant),
                      ),
                    )
                  : ListView.builder(
                      itemCount: gorunen.length + (gizliSayisi > 0 ? 1 : 0),
                      itemBuilder: (context, i) {
                        if (i == gorunen.length) {
                          return TextButton(
                            onPressed: () =>
                                setState(() => _gizliler = !_gizliler),
                            child: Text(
                              _gizliler
                                  ? 'Gizli klasörleri sakla'
                                  : 'Gizli klasörleri göster ($gizliSayisi)',
                            ),
                          );
                        }
                        final k = gorunen[i];
                        return ListTile(
                          dense: true,
                          leading: Icon(
                            Icons.folder_outlined,
                            color: k.startsWith('.')
                                ? r.onSurfaceVariant
                                : r.primary,
                          ),
                          title: Text(k),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: _yukleniyor ? null : () => _ac(_alt(k)),
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  onPressed: yol == null || _yukleniyor
                      ? null
                      : () => Navigator.of(context).pop(yol),
                  icon: const Icon(Icons.check_rounded),
                  label: Text(
                    yol == null
                        ? 'Bu klasörde çalış'
                        : 'Bu klasörde çalış: ${yol.split('/').last.isEmpty ? '/' : yol.split('/').last}',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
