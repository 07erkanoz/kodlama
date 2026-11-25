import 'package:flutter/material.dart';

import '../arayuz/ortak.dart';
import '../model/calisma.dart';

/// GitHub'daki depolardan birini (gh ile) ya da herhangi bir adresi klonlar.
/// Başarılı olursa klonlanan klasörün yolunu döndürür.
Future<String?> klonlaPenceresi(BuildContext context, Calisma c) =>
    showDialog<String>(
      context: context,
      builder: (context) => _Klonla(calisma: c),
    );

class _Klonla extends StatefulWidget {
  const _Klonla({required this.calisma});
  final Calisma calisma;

  @override
  State<_Klonla> createState() => _KlonlaState();
}

class _KlonlaState extends State<_Klonla> {
  final _adres = TextEditingController();
  final _ara = TextEditingController();
  List<Map>? _repolar;
  String? _repoHata;
  bool _klonlaniyor = false;
  String? _hata;

  @override
  void initState() {
    super.initState();
    _ara.addListener(() => setState(() {}));
    widget.calisma.istemci
        .iste('gh_repolar')
        .then((r) {
          if (mounted) {
            setState(() => _repolar = (r['repolar'] as List).cast<Map>());
          }
        })
        .catchError((Object e) {
          if (mounted) setState(() => _repoHata = '$e');
        });
  }

  Future<void> _klonla(String url) async {
    setState(() {
      _klonlaniyor = true;
      _hata = null;
    });
    try {
      final r = await widget.calisma.istemci.iste('git_klonla', {'url': url});
      await widget.calisma.yenile();
      if (mounted) Navigator.pop(context, r['yol'] as String);
    } catch (e) {
      if (mounted) {
        setState(() {
          _klonlaniyor = false;
          _hata = '$e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    final q = _ara.text.toLowerCase();
    final liste = (_repolar ?? const [])
        .where(
          (x) =>
              q.isEmpty ||
              '${x['nameWithOwner']} ${x['description'] ?? ''}'
                  .toLowerCase()
                  .contains(q),
        )
        .toList();
    return AlertDialog(
      title: const Text('Depo klonla'),
      content: SizedBox(
        width: 520,
        // Klavye açılınca taşmasın: yükseklik ekrana göre kısalır.
        height:
            (MediaQuery.sizeOf(context).height -
                    MediaQuery.viewInsetsOf(context).bottom -
                    220)
                .clamp(200.0, 480.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _adres,
                    decoration: const InputDecoration(
                      hintText: 'https://github.com/kullanici/depo.git',
                    ),
                    onSubmitted: (v) =>
                        v.trim().isEmpty ? null : _klonla(v.trim()),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _klonlaniyor
                      ? null
                      : () => _adres.text.trim().isEmpty
                            ? null
                            : _klonla(_adres.text.trim()),
                  child: const Text('Klonla'),
                ),
              ],
            ),
            if (_klonlaniyor)
              const Padding(
                padding: EdgeInsets.only(top: 10),
                child: LinearProgressIndicator(),
              ),
            if (_hata != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_hata!, style: TextStyle(color: r.error)),
              ),
            const SizedBox(height: 16),
            Text(
              'GitHub depoların',
              style: t.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _ara,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search, size: 18),
                hintText: 'Ara',
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _repoHata != null
                  ? Center(
                      child: Text(
                        'GitHub depoları alınamadı. Ayarlar → GitHub\'dan giriş yap.\n$_repoHata',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: r.onSurfaceVariant),
                      ),
                    )
                  : _repolar == null
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      itemCount: liste.length,
                      itemBuilder: (context, i) {
                        final x = liste[i];
                        return ListTile(
                          dense: true,
                          enabled: !_klonlaniyor,
                          leading: Icon(
                            x['isPrivate'] == true
                                ? Icons.lock_outline
                                : Icons.public,
                            size: 18,
                          ),
                          title: Text(x['nameWithOwner'] as String),
                          subtitle: Text(
                            [
                              if ((x['description'] as String?)?.isNotEmpty ==
                                  true)
                                x['description'],
                              goreliZaman(
                                DateTime.tryParse(
                                  x['updatedAt'] as String? ?? '',
                                )?.millisecondsSinceEpoch.let((m) => m / 1000),
                              ),
                            ].join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _klonla(x['url'] as String),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Kapat'),
        ),
      ],
    );
  }
}

extension<T> on T {
  R let<R>(R Function(T) f) => f(this);
}
