import 'dart:async';

import 'package:flutter/material.dart';

import '../arayuz/ortak.dart';
import '../model/calisma.dart';

/// Bütün oturumlarda arama: kullanıcı mesajları ve ajan yanıtları. Sonuca
/// dokununca o oturum açılır.
class OturumArama extends StatefulWidget {
  const OturumArama({super.key, required this.calisma});
  final Calisma calisma;

  @override
  State<OturumArama> createState() => _OturumAramaState();
}

class _OturumAramaState extends State<OturumArama> {
  final _sorgu = TextEditingController();
  Timer? _bekle;
  List<Map<String, dynamic>> _sonuclar = [];
  bool _araniyor = false;
  String? _hata;
  String _son = '';

  @override
  void dispose() {
    _bekle?.cancel();
    _sorgu.dispose();
    super.dispose();
  }

  void _degisti(String v) {
    _bekle?.cancel();
    _bekle = Timer(const Duration(milliseconds: 350), () => _ara(v.trim()));
  }

  Future<void> _ara(String q) async {
    if (q == _son) return;
    _son = q;
    if (q.length < 2) {
      setState(() => _sonuclar = []);
      return;
    }
    setState(() => _araniyor = true);
    try {
      final r = await widget.calisma.istemci.iste('ara', {'sorgu': q});
      if (!mounted || q != _son) return;
      setState(() {
        _sonuclar = [
          for (final x in r['sonuclar'] as List)
            (x as Map).cast<String, dynamic>(),
        ];
        _hata = null;
      });
    } catch (e) {
      if (mounted) setState(() => _hata = '$e');
    } finally {
      if (mounted) setState(() => _araniyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _sorgu,
          autofocus: true,
          onChanged: _degisti,
          onSubmitted: (v) => _ara(v.trim()),
          decoration: const InputDecoration(
            hintText: 'Oturumlarda ara',
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            filled: false,
          ),
        ),
        bottom: _araniyor
            ? const PreferredSize(
                preferredSize: Size.fromHeight(2),
                child: LinearProgressIndicator(minHeight: 2),
              )
            : null,
      ),
      body: _hata != null
          ? Center(child: Text(_hata!))
          : _sonuclar.isEmpty
          ? Center(
              child: Text(
                _son.length < 2 ? 'En az iki harf yaz.' : 'Sonuç yok.',
                style: TextStyle(color: r.onSurfaceVariant),
              ),
            )
          : ListView.separated(
              itemCount: _sonuclar.length,
              separatorBuilder: (_, _) =>
                  Divider(height: 1, color: r.outlineVariant),
              itemBuilder: (context, i) {
                final x = _sonuclar[i];
                final parca = x['parca'] as String? ?? '';
                final konum = (x['konum'] as num?)?.toInt() ?? 0;
                final uzun = _son.length;
                final vurgu = konum >= 0 && konum + uzun <= parca.length;
                return ListTile(
                  leading: AjanRozeti(ajan: x['ajan'] as String, boyut: 26),
                  title: Text(
                    x['baslik'] as String? ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: x['ev'] == 'kullanici' ? 'Sen: ' : '',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (vurgu) ...[
                          TextSpan(text: parca.substring(0, konum)),
                          TextSpan(
                            text: parca.substring(konum, konum + uzun),
                            style: TextStyle(
                              backgroundColor: r.primaryContainer,
                              color: r.onPrimaryContainer,
                            ),
                          ),
                          TextSpan(text: parca.substring(konum + uzun)),
                        ] else
                          TextSpan(text: parca),
                      ],
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: Text(
                    goreliZaman(x['zaman'] as num?),
                    style: t.textTheme.labelSmall?.copyWith(color: r.outline),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    widget.calisma.oturumuAc(x['oturum'] as String);
                  },
                );
              },
            ),
    );
  }
}
