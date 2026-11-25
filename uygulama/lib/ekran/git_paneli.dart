import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../arayuz/ortak.dart';
import '../model/calisma.dart';
import '../model/sohbet.dart';
import 'derleme_bolumu.dart';

/// Oturumun klasöründeki Git deposu: dal, değişiklikler (diff), commit,
/// push/pull ve GitHub'da PR. Ajanın bir turu bitince kendiliğinden yenilenir.
class GitPaneli extends StatefulWidget {
  const GitPaneli({super.key, required this.calisma, required this.sohbet});

  final Calisma calisma;
  final Sohbet sohbet;

  @override
  State<GitPaneli> createState() => _GitPaneliState();
}

class _GitPaneliState extends State<GitPaneli> {
  Map<String, dynamic>? _durum;
  Map<String, dynamic>? _gh;
  String? _hata;
  String? _calisan; // sürmekte olan işlem: 'commit', 'push', 'pull'…
  final _mesaj = TextEditingController();
  StreamSubscription? _abone;

  Calisma get c => widget.calisma;
  String get cwd => widget.sohbet.cwd;

  @override
  void initState() {
    super.initState();
    _yenile();
    _abone = c.istemci.olaylar.listen((e) {
      if (e['oturum'] == widget.sohbet.id && e['ev'] == 'bitti') _yenile();
    });
  }

  @override
  void didUpdateWidget(GitPaneli old) {
    super.didUpdateWidget(old);
    if (old.sohbet.id != widget.sohbet.id) _yenile();
  }

  @override
  void dispose() {
    _abone?.cancel();
    _mesaj.dispose();
    super.dispose();
  }

  Future<void> _yenile() async {
    if (widget.sohbet.sunucu != null) return;
    try {
      final d = await c.istemci.iste('git_durum', {'cwd': cwd});
      Map<String, dynamic>? gh = _gh;
      if (gh == null && d['repo'] == true) {
        try {
          gh = await c.istemci.iste('gh_durum');
        } catch (_) {}
      }
      if (mounted) {
        setState(() {
          _durum = d;
          _gh = gh;
          _hata = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _hata = '$e');
    }
  }

  Future<void> _yap(String ad, Future<String?> Function() is_) async {
    setState(() => _calisan = ad);
    try {
      final sonuc = await is_();
      if (mounted && sonuc != null && sonuc.isNotEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(sonuc)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), duration: const Duration(seconds: 6)),
        );
      }
    } finally {
      if (mounted) setState(() => _calisan = null);
      await _yenile();
    }
  }

  Future<String?> _istek(String op, [Map<String, dynamic> p = const {}]) async {
    final r = await c.istemci.iste(op, {'cwd': cwd, ...p});
    final cikti = (r['cikti'] as String? ?? '').trim().split('\n').last;
    return cikti;
  }

  void _farkiAc(Map f) async {
    final ekran = MediaQuery.sizeOf(context);
    final icerik = _FarkGorunumu(calisma: c, cwd: cwd, yol: f['yol'] as String);
    if (ekran.width >= 840) {
      await showDialog(
        context: context,
        builder: (context) => Dialog(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 960,
              maxHeight: ekran.height * .85,
            ),
            child: icerik,
          ),
        ),
      );
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => Scaffold(body: SafeArea(child: icerik)),
        ),
      );
    }
  }

  Future<void> _prAc() async {
    final baslik = TextEditingController(text: widget.sohbet.baslik);
    final govde = TextEditingController();
    final evet = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pull request aç'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: baslik,
                decoration: const InputDecoration(labelText: 'Başlık'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: govde,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(labelText: 'Açıklama'),
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
            child: const Text('Aç'),
          ),
        ],
      ),
    );
    if (evet != true) return;
    await _yap('pr', () async {
      await c.istemci.iste('git_push', {'cwd': cwd});
      final r = await c.istemci.iste('gh_pr', {
        'cwd': cwd,
        'baslik': baslik.text,
        'govde': govde.text,
      });
      final url = r['url'] as String? ?? '';
      if (url.startsWith('http')) {
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
      return 'PR açıldı';
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    if (widget.sohbet.sunucu != null) {
      return _Bos(
        simge: Icons.dns_outlined,
        metin:
            'Bu oturum ${widget.sohbet.sunucu} sunucusunda. Git işlemlerini ajandan isteyebilirsin.',
      );
    }
    if (_hata != null) return _Bos(simge: Icons.error_outline, metin: _hata!);
    final d = _durum;
    if (d == null) return const Center(child: CircularProgressIndicator());
    if (d['repo'] != true) {
      return _Bos(
        simge: Icons.account_tree_outlined,
        metin: 'Bu klasör bir Git deposu değil.',
        dugme: FilledButton.icon(
          onPressed: _calisan != null
              ? null
              : () => _yap('init', () => _istek('git_init')),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Git deposu başlat'),
        ),
      );
    }
    final dosyalar = (d['dosyalar'] as List).cast<Map>();
    final commitler = (d['commitler'] as List).cast<Map>();
    final uzak = d['uzak'] as String?;
    final github = uzak != null && uzak.contains('github.com');
    final ghGiris = _gh?['giris'] == true;
    final mesgul = _calisan != null;
    return RefreshIndicator(
      onRefresh: _yenile,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          Row(
            children: [
              Icon(Icons.call_split, size: 16, color: r.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  d['dal'] as String? ?? '?',
                  overflow: TextOverflow.ellipsis,
                  style: t.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if ((d['ileri'] as int? ?? 0) > 0)
                _Rozet('↑${d['ileri']}', r.primary),
              if ((d['geri'] as int? ?? 0) > 0)
                _Rozet('↓${d['geri']}', const Color(0xFFF59E0B)),
              IconButton(
                tooltip: 'Yenile',
                onPressed: _yenile,
                icon: const Icon(Icons.refresh, size: 18),
              ),
            ],
          ),
          if (uzak != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                uzak.replaceFirst(RegExp(r'^https://|^git@'), ''),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.textTheme.bodySmall?.copyWith(
                  color: r.onSurfaceVariant,
                ),
              ),
            ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (uzak != null) ...[
                _IsDugmesi(
                  simge: Icons.download_outlined,
                  ad: 'Pull',
                  calisiyor: _calisan == 'pull',
                  etkin: !mesgul,
                  bas: () => _yap('pull', () => _istek('git_pull')),
                ),
                _IsDugmesi(
                  simge: Icons.upload_outlined,
                  ad: 'Push',
                  calisiyor: _calisan == 'push',
                  etkin: !mesgul,
                  bas: () => _yap('push', () => _istek('git_push')),
                ),
              ],
              if (github && ghGiris)
                _IsDugmesi(
                  simge: Icons.merge_type,
                  ad: 'PR aç',
                  calisiyor: _calisan == 'pr',
                  etkin:
                      !mesgul && (d['dal'] != 'main' && d['dal'] != 'master'),
                  bas: _prAc,
                ),
            ],
          ),
          if (github && ghGiris && c.yetenek('derleme'))
            DerlemeBolumu(calisma: c, cwd: cwd, degisti: _yenile),
          const SizedBox(height: 16),
          Text(
            dosyalar.isEmpty
                ? 'Değişiklik yok'
                : '${dosyalar.length} değişiklik',
            style: t.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          for (final f in dosyalar.take(200))
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _farkiAc(f),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                child: Row(
                  children: [
                    _DurumHarfi(tur: f['tur'] as String),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        f['yol'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: monospace.copyWith(
                          fontSize: 12.5,
                          color: r.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (dosyalar.isNotEmpty) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _mesaj,
              onChanged: (_) => setState(() {}),
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(hintText: 'Commit mesajı'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: mesgul || _mesaj.text.trim().isEmpty
                        ? null
                        : () => _yap('commit', () async {
                            final sonuc = await _istek('git_commit', {
                              'mesaj': _mesaj.text,
                            });
                            _mesaj.clear();
                            return sonuc;
                          }),
                    icon: _calisan == 'commit'
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check, size: 18),
                    label: const Text('Commit'),
                  ),
                ),
                const SizedBox(width: 8),
                Tooltip(
                  message: 'Değişiklikleri ajana inceletip commit ettir',
                  child: OutlinedButton.icon(
                    onPressed: widget.sohbet.calisiyor
                        ? null
                        : () => widget.sohbet.gonder(
                            'Çalışma klasöründeki git değişikliklerini incele, mantıklı gruplar halinde '
                            'açıklayıcı mesajlarla commit et. Push yapma.',
                          ),
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text('Ajana yaptır'),
                  ),
                ),
              ],
            ),
          ],
          if (commitler.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Son commitler',
              style: t.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            for (final k in commitler)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      k['kisa'] as String,
                      style: monospace.copyWith(fontSize: 12, color: r.primary),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            k['mesaj'] as String,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: t.textTheme.bodySmall,
                          ),
                          Text(
                            '${k['yazar']} · ${k['zaman']}',
                            style: t.textTheme.labelSmall?.copyWith(
                              color: r.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (uzak == null) ...[
            const SizedBox(height: 20),
            Text(
              'Uzak depo bağlı değil. Ajandan "GitHub\'da depo oluştur ve bağla" diyebilirsin.',
              style: t.textTheme.bodySmall?.copyWith(color: r.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _FarkGorunumu extends StatelessWidget {
  const _FarkGorunumu({
    required this.calisma,
    required this.cwd,
    required this.yol,
  });
  final Calisma calisma;
  final String cwd;
  final String yol;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  yol,
                  overflow: TextOverflow.ellipsis,
                  style: t.textTheme.titleSmall,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder(
            future: calisma.istemci.iste('git_fark', {'cwd': cwd, 'yol': yol}),
            builder: (context, snap) {
              if (snap.hasError) return Center(child: Text('${snap.error}'));
              if (!snap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final fark = snap.data!['fark'] as String? ?? '';
              if (fark.trim().isEmpty) {
                return const Center(
                  child: Text('Fark yok (ikili dosya olabilir).'),
                );
              }
              final satirlar = birlesikFark(fark)
                  .where(
                    (s) =>
                        !(s.tur == SatirTuru.baslik &&
                            !s.metin.startsWith('@@')),
                  )
                  .toList();
              return Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: DiffGorunumu(yol: '', satirlar: satirlar, enFazla: 4000),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DurumHarfi extends StatelessWidget {
  const _DurumHarfi({required this.tur});
  final String tur;

  @override
  Widget build(BuildContext context) {
    final r = Theme.of(context).colorScheme;
    final (harf, renk) = switch (tur) {
      'yeni' => ('U', const Color(0xFF22C55E)),
      'eklendi' => ('A', const Color(0xFF22C55E)),
      'silindi' => ('D', r.error),
      'ad' => ('R', r.primary),
      _ => ('M', const Color(0xFFF59E0B)),
    };
    return Container(
      width: 20,
      height: 20,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: renk.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        harf,
        style: TextStyle(
          color: renk,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Rozet extends StatelessWidget {
  const _Rozet(this.metin, this.renk);
  final String metin;
  final Color renk;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(left: 4),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: renk.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      metin,
      style: TextStyle(color: renk, fontSize: 11, fontWeight: FontWeight.w700),
    ),
  );
}

class _IsDugmesi extends StatelessWidget {
  const _IsDugmesi({
    required this.simge,
    required this.ad,
    required this.bas,
    this.calisiyor = false,
    this.etkin = true,
  });

  final IconData simge;
  final String ad;
  final VoidCallback bas;
  final bool calisiyor;
  final bool etkin;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    style: OutlinedButton.styleFrom(
      minimumSize: const Size(0, 34),
      padding: const EdgeInsets.symmetric(horizontal: 12),
    ),
    onPressed: etkin ? bas : null,
    icon: calisiyor
        ? const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Icon(simge, size: 16),
    label: Text(ad),
  );
}

class _Bos extends StatelessWidget {
  const _Bos({required this.simge, required this.metin, this.dugme});
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
            Icon(simge, size: 36, color: r.outline),
            const SizedBox(height: 10),
            Text(
              metin,
              textAlign: TextAlign.center,
              style: TextStyle(color: r.onSurfaceVariant),
            ),
            if (dugme != null) ...[const SizedBox(height: 14), dugme!],
          ],
        ),
      ),
    );
  }
}
