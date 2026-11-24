import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../arayuz/ajan_ayarlari.dart';
import '../arayuz/markdown.dart';
import '../arayuz/mesaj_kutusu.dart';
import '../arayuz/ortak.dart';
import '../model/calisma.dart';
import '../model/sesli_konusma.dart';
import '../model/sohbet.dart';
import '../servis/pano.dart';
import '../servis/yerel_dosya.dart';
import 'canli_onizleme.dart';
import 'onizleme.dart';

/// Sohbetin ekrandaki birimi: tek tek öğeler değil, okunur gruplar.
sealed class _Blok {}

class _KullaniciBlok extends _Blok {
  _KullaniciBlok(this.oge);
  final KullaniciOge oge;
}

class _AjanBasligi extends _Blok {}

class _MetinBlok extends _Blok {
  _MetinBlok(this.oge);
  final MetinOge oge;
}

class _DusunceBlok extends _Blok {
  _DusunceBlok(this.oge);
  final DusunceOge oge;
}

class _EtkinlikBlok extends _Blok {
  _EtkinlikBlok(this.araclar);
  final List<AracOge> araclar;
}

class _OnayBlok extends _Blok {
  _OnayBlok(this.oge);
  final OnayOge oge;
}

class _DosyaBlok extends _Blok {
  _DosyaBlok(this.dosyalar);
  final List<DosyaOge> dosyalar;
}

class _BittiBlok extends _Blok {
  _BittiBlok(this.oge);
  final BittiOge oge;
}

class _UyariBlok extends _Blok {
  _UyariBlok(this.metin);
  final String metin;
}

List<_Blok> _bloklar(List<Oge> ogeler) {
  final out = <_Blok>[];
  var turBasi = true;
  for (final o in ogeler) {
    if (o is! KullaniciOge && turBasi) {
      out.add(_AjanBasligi());
      turBasi = false;
    }
    switch (o) {
      case KullaniciOge():
        out.add(_KullaniciBlok(o));
        turBasi = true;
      case MetinOge():
        out.add(_MetinBlok(o));
      case DusunceOge():
        out.add(_DusunceBlok(o));
      case AracOge():
        if (out.lastOrNull case _EtkinlikBlok(:final araclar)) {
          araclar.add(o);
        } else {
          out.add(_EtkinlikBlok([o]));
        }
      case OnayOge():
        out.add(_OnayBlok(o));
      case DosyaOge():
        if (out.lastOrNull case _DosyaBlok(:final dosyalar)) {
          dosyalar.removeWhere((d) => d.yol == o.yol);
          dosyalar.add(o);
        } else {
          out.add(_DosyaBlok([o]));
        }
      case BittiOge():
        out.add(_BittiBlok(o));
      case UyariOge():
        out.add(_UyariBlok(o.metin));
    }
  }
  return out;
}

/// Sohbet: ajanın yazdıkları zengin metin; araç adımları tek bir etkinlik
/// satırında; düzenlemeler ve onaylar diff olarak; üretilen dosyalar
/// önizlenebilir çipler olarak.
class SohbetGorunumu extends StatefulWidget {
  const SohbetGorunumu({
    super.key,
    required this.calisma,
    required this.sohbet,
    this.dosyaAc,
  });

  final Calisma calisma;
  final Sohbet sohbet;
  final void Function(String yol)? dosyaAc;

  @override
  State<SohbetGorunumu> createState() => _SohbetGorunumuState();
}

class _SohbetGorunumuState extends State<SohbetGorunumu> {
  final _yazi = TextEditingController();
  final _ekler = <String>[];
  bool _ekYukleniyor = false;

  Sohbet get s => widget.sohbet;

  @override
  void initState() {
    super.initState();
    widget.calisma.paylasim.addListener(_paylasimiAl);
    WidgetsBinding.instance.addPostFrameCallback((_) => _paylasimiAl());
  }

  @override
  void dispose() {
    widget.calisma.paylasim.removeListener(_paylasimiAl);
    _yazi.dispose();
    super.dispose();
  }

  /// Paylaş menüsünden bu sohbete gönderilen: metin yazma kutusuna, dosyalar ek olur.
  Future<void> _paylasimiAl() async {
    final p = widget.calisma.paylasim.value;
    if (p == null || !mounted || widget.calisma.secili?.id != s.id) return;
    widget.calisma.paylasim.value = null;
    if (p.metin.trim().isNotEmpty) {
      final once = _yazi.text.trim();
      _yazi.text = once.isEmpty ? p.metin.trim() : '$once\n\n${p.metin.trim()}';
    }
    await _yukle([
      for (final d in p.dosyalar) (ad: d.ad, oku: () => yerelDosyaOku(d.yol)),
    ]);
  }

  /// Mesajdaki bir bağlantıya ya da dosya yoluna dokunuldu. Web adresleri
  /// tarayıcıda; HTML sayfaları göreli dosyalarıyla tarayıcıda; diğer
  /// dosyalar (resim, PDF, kod…) uygulamanın önizlemesinde açılır.
  void _dosyaAc(String hedef) {
    var yol = hedef.trim();
    final adres = Uri.tryParse(yol);
    if (adres != null && yerelAdres(adres)) {
      // ajanın başlattığı geliştirme sunucusu: uygulamanın içinde aç
      onizlemeAc(context, widget.calisma, adres);
      return;
    }
    if (adres != null && (adres.scheme == 'http' || adres.scheme == 'https')) {
      launchUrl(adres, mode: LaunchMode.externalApplication);
      return;
    }
    if (yol.startsWith('file://')) yol = Uri.decodeComponent(yol.substring(7));
    // `a.dart:42`, `a.dart:42:7`, `a.dart#L42` gibi satır ekleri
    yol = yol.replaceFirst(RegExp(r'(#L\d+(-L?\d+)?|(:\d+){1,2})$'), '');
    if (s.sunucu != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '$yol ${s.sunucu} sunucusunda; uzak dosyalar henüz önizlenemiyor.',
          ),
        ),
      );
      return;
    }
    final tam = yol.startsWith('/')
        ? yol
        : yol.startsWith('~/')
        ? '${_ev(s.cwd)}${yol.substring(1)}'
        : '${s.cwd}/${yol.replaceFirst(RegExp(r'^\./'), '')}';
    final u = tam.split('.').last.toLowerCase();
    if ((u == 'html' || u == 'htm') && !widget.calisma.kopruEski) {
      onizlemeAc(context, widget.calisma, widget.calisma.istemci.sayfaAdresi(tam));
      return;
    }
    if (widget.dosyaAc != null) {
      widget.dosyaAc!(tam);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OnizlemeSayfasi(calisma: widget.calisma, yol: tam),
        ),
      );
    }
  }

  /// Termux'ta ev klasörü: `/data/data/com.termux/files/home`.
  static String _ev(String cwd) {
    final i = cwd.indexOf('/files/home');
    return i < 0 ? cwd : cwd.substring(0, i + '/files/home'.length);
  }

  bool get _sesVar =>
      s.sesDestekleniyor && widget.calisma.yetenek('ses');

  void _sesDegistir() {
    final ses = s.ses;
    if (ses.acik) {
      ses.bitir();
    } else {
      ses.baslat();
    }
  }

  Future<void> _gonder() async {
    final metin = _yazi.text.trim();
    if (metin.isEmpty && _ekler.isEmpty) return;
    final ekler = List<String>.of(_ekler);
    _yazi.clear();
    setState(_ekler.clear);
    try {
      await s.gonder(metin, ekler: ekler);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Gönderilemedi: $e')));
      }
    }
  }

  /// Ekleri köprüye yükler (oturum klasörüne) ve yazma kutusuna ekler.
  Future<void> _yukle(
    List<({String ad, Future<Uint8List> Function() oku})> dosyalar,
  ) async {
    if (dosyalar.isEmpty) return;
    setState(() => _ekYukleniyor = true);
    try {
      for (final f in dosyalar) {
        final yol = await s.ekYukle(f.ad, base64Encode(await f.oku()));
        if (mounted) setState(() => _ekler.add(yol));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Ek yüklenemedi: $e')));
      }
    } finally {
      if (mounted) setState(() => _ekYukleniyor = false);
    }
  }

  Future<void> _dosyaSec() async {
    final secilen = await FilePicker.pickFiles();
    await _yukle([for (final f in secilen) (ad: f.name, oku: f.readAsBytes)]);
  }

  Future<void> _resimSec(ImageSource kaynak) async {
    final secici = ImagePicker();
    final resimler = kaynak == ImageSource.camera
        ? [?await secici.pickImage(source: kaynak, imageQuality: 85)]
        : await secici.pickMultiImage(imageQuality: 85);
    await _yukle([for (final r in resimler) (ad: r.name, oku: r.readAsBytes)]);
  }

  Future<void> _panodanResim() async {
    final r = await Pano.resim();
    if (r == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Panoda resim yok.')),
        );
      }
      return;
    }
    await _yukle([(ad: r.ad, oku: () => yerelDosyaOku(r.yol))]);
  }

  /// Android'de: dosya, kamera, galeri, pano; diğerlerinde dosya seçici.
  Future<void> _ekSec() async {
    if (!Pano.destekleniyor) return _dosyaSec();
    final secim = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, simge, ad) in const [
              (0, Icons.photo_camera_outlined, 'Fotoğraf çek'),
              (1, Icons.photo_library_outlined, 'Galeriden resim'),
              (2, Icons.content_paste, 'Panodaki resim'),
              (3, Icons.attach_file, 'Dosya'),
            ])
              ListTile(
                leading: Icon(simge),
                title: Text(ad),
                onTap: () => Navigator.pop(context, i),
              ),
          ],
        ),
      ),
    );
    switch (secim) {
      case 0:
        await _resimSec(ImageSource.camera);
      case 1:
        await _resimSec(ImageSource.gallery);
      case 2:
        await _panodanResim();
      case 3:
        await _dosyaSec();
    }
  }


  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final bloklar = _bloklar(s.ogeler);
        final araclar = ajanAraclari(
          calisma: widget.calisma,
          dinle: s,
          etkin: !s.calisiyor,
          ayar: () =>
              (ajan: s.ajan, model: s.model, effort: s.effort, mod: s.mod),
          modelSec: (v) => s.ayarla({
            'model': v,
            'effort': uygunEffort(widget.calisma, s.ajan, v, s.effort),
          }),
          effortSec: (v) => s.ayarla({'effort': v}),
          modSec: s.modDegistir,
        );
        final say = bloklar.length + (s.calisiyor ? 1 : 0);
        return Column(
          children: [
            Expanded(
              child: s.yukleniyor
                  ? const Center(child: CircularProgressIndicator())
                  : bloklar.isEmpty
                  ? _Bos(sohbet: s)
                  : ListView.builder(
                      reverse: true,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                      itemCount: say,
                      itemBuilder: (context, i) {
                        if (s.calisiyor && i == 0) {
                          return _sar(_Calisiyor(sohbet: s));
                        }
                        final b =
                            bloklar[bloklar.length -
                                1 -
                                (i - (s.calisiyor ? 1 : 0))];
                        return _sar(_blok(b));
                      },
                    ),
            ),
            if (_sesVar)
              ListenableBuilder(
                listenable: s.ses,
                builder: (context, _) => s.ses.acik || s.ses.hata != null
                    ? _sar(
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                          child: _SesPaneli(ses: s.ses),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SafeArea(
                top: false,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 780),
                    child: MesajKutusu(
                      enAzSatir: 2,
                      denetleyici: _yazi,
                      gonder: _gonder,
                      durdur: s.durdur,
                      calisiyor: s.calisiyor,
                      ekle: _ekSec,
                      ekler: _ekler,
                      ekYukleniyor: _ekYukleniyor,
                      ekKaldir: (e) => setState(() => _ekler.remove(e)),
                      icerikEklendi: (ad, veri) =>
                          _yukle([(ad: ad, oku: () async => veri)]),
                      ipucu: s.calisiyor
                          ? 'Araya yaz — çalışan işe eklenir'
                          : 'Devam et…',
                      cipler: [araclar.model],
                      sagda: [
                        if (_sesVar)
                          ListenableBuilder(
                            listenable: s.ses,
                            builder: (context, _) => IconButton(
                              tooltip: s.ses.acik
                                  ? 'Sesli konuşmayı bitir'
                                  : 'Codex ile sesli konuş',
                              isSelected: s.ses.acik,
                              icon: const Icon(Icons.mic_none_rounded),
                              selectedIcon: const Icon(Icons.mic_rounded),
                              onPressed: _sesDegistir,
                            ),
                          ),
                        araclar.bicim,
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _sar(Widget w) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 780),
      child: SizedBox(width: double.infinity, child: w),
    ),
  );

  Widget _blok(_Blok b) => switch (b) {
    _KullaniciBlok(:final oge) => _KullaniciBalonu(oge: oge, dosyaAc: _dosyaAc),
    _AjanBasligi() => _AjanSatiri(ajan: s.ajan),
    _MetinBlok(:final oge) => Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Markdown(oge.metin, size: 15, onLink: _dosyaAc),
    ),
    _DusunceBlok(:final oge) => _Dusunce(oge: oge),
    _EtkinlikBlok(:final araclar) => _Etkinlik(araclar: araclar),
    _OnayBlok(:final oge) => _OnayKarti(
      oge: oge,
      ajan: s.ajan,
      karar: (k) => s.onayla(oge, k),
    ),
    _DosyaBlok(:final dosyalar) => _Dosyalar(dosyalar: dosyalar, ac: _dosyaAc),
    _BittiBlok(:final oge) => _BittiSatiri(oge: oge),
    _UyariBlok(:final metin) => _UyariSatiri(metin: metin),
  };
}

// ---------------------------------------------------------------- parçalar

class _Bos extends StatelessWidget {
  const _Bos({required this.sohbet});
  final Sohbet sohbet;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AjanRozeti(ajan: sohbet.ajan, boyut: 44),
            const SizedBox(height: 14),
            Text(
              '${ajanAdi(sohbet.ajan)} · ${sohbet.cwd.split('/').last}',
              style: t.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Ne yapmak istediğini yaz.',
              style: t.textTheme.bodyMedium?.copyWith(
                color: t.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AjanSatiri extends StatelessWidget {
  const _AjanSatiri({required this.ajan});
  final String ajan;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Row(
        children: [
          AjanRozeti(ajan: ajan, boyut: 22),
          const SizedBox(width: 8),
          Text(
            ajanAdi(ajan),
            style: t.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Çalışırken en altta duran canlı durum: ne yaptığı, neyle uğraştığı ve
/// ne kadar süredir çalıştığı.
class _Calisiyor extends StatefulWidget {
  const _Calisiyor({required this.sohbet});
  final Sohbet sohbet;

  @override
  State<_Calisiyor> createState() => _CalisiyorState();
}

class _CalisiyorState extends State<_Calisiyor> {
  late final Timer _saat;

  @override
  void initState() {
    super.initState();
    _saat = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() {}),
    );
  }

  @override
  void dispose() {
    _saat.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    final e = widget.sohbet.etkinlik;
    if (e == null) return const SizedBox.shrink();
    final bas = widget.sohbet.turBasi;
    final sure = bas == null ? null : DateTime.now().difference(bas);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: e.onay
                ? Icon(Icons.pause_circle_outline, size: 14, color: r.primary)
                : CircularProgressIndicator(strokeWidth: 2, color: r.primary),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: e.metin,
                    style: TextStyle(
                      color: r.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (e.ayrinti?.isNotEmpty == true)
                    TextSpan(
                      text: '  ${e.ayrinti}',
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.textTheme.bodySmall?.copyWith(
                color: r.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ),
          if (sure != null) ...[
            const SizedBox(width: 8),
            Text(
              sureYazisi(sure),
              style: t.textTheme.bodySmall?.copyWith(
                color: r.outline,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

String sureYazisi(Duration d) {
  final sn = d.inSeconds;
  if (sn < 60) return '$sn sn';
  final dk = sn ~/ 60;
  if (dk < 60) return '$dk dk ${sn % 60} sn';
  return '${dk ~/ 60} sa ${dk % 60} dk';
}

/// Modelin düşünmesi: düşünürken son satırları canlı gösterir, bitince
/// "Düşündü · 8 sn" başlığına katlanır; dokununca açılır.
class _Dusunce extends StatefulWidget {
  const _Dusunce({required this.oge});
  final DusunceOge oge;

  @override
  State<_Dusunce> createState() => _DusunceState();
}

class _DusunceState extends State<_Dusunce> {
  bool _acik = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    final o = widget.oge;
    final sure = o.bitis?.difference(o.baslangic);
    final metin = o.metin.trim();
    final stil = t.textTheme.bodySmall?.copyWith(
      color: r.onSurfaceVariant,
      fontSize: 13.5,
      height: 1.5,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: metin.isEmpty ? null : () => setState(() => _acik = !_acik),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.psychology_outlined,
                    size: 16,
                    color: o.akiyor ? r.primary : r.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    o.akiyor
                        ? 'Düşünüyor…'
                        : sure != null && sure.inSeconds > 0
                        ? 'Düşündü · ${sureYazisi(sure)}'
                        : 'Düşünce',
                    style: t.textTheme.labelLarge?.copyWith(
                      color: r.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (metin.isNotEmpty) ...[
                    const SizedBox(width: 2),
                    Icon(
                      _acik ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: r.outline,
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_acik && metin.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(left: 7, top: 2, bottom: 6),
              padding: const EdgeInsets.only(left: 14),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: r.outlineVariant, width: 2),
                ),
              ),
              child: SelectableText(metin, style: stil),
            )
          else if (o.akiyor && metin.isNotEmpty)
            // canlı önizleme: son üç satır, üstü solarak
            Container(
              margin: const EdgeInsets.only(left: 7, bottom: 4),
              padding: const EdgeInsets.only(left: 14),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: r.outlineVariant, width: 2),
                ),
              ),
              child: ShaderMask(
                shaderCallback: (b) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black],
                  stops: [0, .45],
                ).createShader(b),
                blendMode: BlendMode.dstIn,
                child: Text(
                  _sonSatirlar(metin, 3),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: stil,
                ),
              ),
            ),
        ],
      ),
    );
  }

  static String _sonSatirlar(String s, int n) {
    final satirlar = s
        .split('\n')
        .where((x) => x.trim().isNotEmpty)
        .toList();
    return satirlar
        .sublist(satirlar.length > n ? satirlar.length - n : 0)
        .join('\n');
  }
}

class _KullaniciBalonu extends StatelessWidget {
  const _KullaniciBalonu({required this.oge, required this.dosyaAc});
  final KullaniciOge oge;
  final void Function(String) dosyaAc;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(top: 18, bottom: 4, left: 56),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: r.surfaceContainerHigh,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(6),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (oge.metin.isNotEmpty)
              SelectableText(
                oge.metin,
                style: t.textTheme.bodyLarge?.copyWith(
                  fontSize: 15,
                  height: 1.45,
                ),
              ),
            if (oge.ekler.isNotEmpty) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final e in oge.ekler)
                    ActionChip(
                      avatar: Icon(dosyaSimgesi(e), size: 14),
                      label: Text(
                        e.split('/').last.replaceFirst(RegExp(r'^\d+_'), ''),
                      ),
                      onPressed: () => dosyaAc(e),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Aracın insanca adı ve simgesi.
(String, IconData) aracGorunumu(String ad) => switch (ad) {
  'Bash' || 'Komut' => ('Komut', Icons.terminal_rounded),
  'Read' => ('Okudu', Icons.visibility_outlined),
  'Write' => ('Yazdı', Icons.note_add_outlined),
  'Edit' || 'MultiEdit' || 'Düzenle' => ('Düzenledi', Icons.edit_outlined),
  'NotebookEdit' => ('Defter', Icons.edit_note),
  'Glob' => ('Dosya aradı', Icons.manage_search),
  'Grep' => ('İçerik aradı', Icons.search),
  'WebSearch' || 'webSearch' => ('Web\'de aradı', Icons.travel_explore),
  'WebFetch' => ('Sayfa okudu', Icons.public),
  'Task' || 'Agent' => ('Alt görev', Icons.account_tree_outlined),
  'TodoWrite' => ('Plan', Icons.checklist),
  'Dosya değişikliği' => ('Değişiklik', Icons.edit_outlined),
  _ => (ad, Icons.extension_outlined),
};

class _Etkinlik extends StatefulWidget {
  const _Etkinlik({required this.araclar});
  final List<AracOge> araclar;

  @override
  State<_Etkinlik> createState() => _EtkinlikState();
}

class _EtkinlikState extends State<_Etkinlik> {
  bool _acik = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    final a = widget.araclar;
    final suruyor = a.any((x) => !x.bitti);
    final hata = a.where((x) => x.hata).length;
    final son = a.last;
    final (sonAd, sonSimge) = aracGorunumu(son.ad);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: r.surfaceContainerLow,
        border: Border.all(color: r.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => setState(() => _acik = !_acik),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: suruyor
                        ? const CircularProgressIndicator(strokeWidth: 1.8)
                        : Icon(
                            hata > 0
                                ? Icons.error_outline
                                : Icons.check_circle_outline,
                            size: 16,
                            color: hata > 0 ? r.error : r.onSurfaceVariant,
                          ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '${a.length} adım',
                    style: t.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(sonSimge, size: 14, color: r.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$sonAd  ${son.ozet}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.textTheme.bodySmall?.copyWith(
                        color: r.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Icon(
                    _acik ? Icons.expand_less : Icons.expand_more,
                    size: 18,
                    color: r.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_acik)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [for (final x in a) _AracSatiri(oge: x)],
              ),
            ),
        ],
      ),
    );
  }
}

class _AracSatiri extends StatefulWidget {
  const _AracSatiri({required this.oge});
  final AracOge oge;

  @override
  State<_AracSatiri> createState() => _AracSatiriState();
}

class _AracSatiriState extends State<_AracSatiri> {
  bool _acik = false;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    final o = widget.oge;
    final (ad, simge) = aracGorunumu(o.ad);
    final fark = _acik ? girdidenFark(o.girdi) : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _acik = !_acik),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            child: Row(
              children: [
                Icon(
                  simge,
                  size: 15,
                  color: o.hata ? r.error : r.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 92,
                  child: Text(
                    ad,
                    style: t.textTheme.labelMedium?.copyWith(
                      color: o.hata ? r.error : r.onSurface,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    o.ozet,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: monospace.copyWith(
                      fontSize: 12,
                      color: r.onSurfaceVariant,
                    ),
                  ),
                ),
                if (!o.bitti)
                  const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
              ],
            ),
          ),
        ),
        if (_acik)
          Padding(
            padding: const EdgeInsets.fromLTRB(29, 2, 4, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (fark != null)
                  for (final (yol, satirlar) in fark)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: DiffGorunumu(
                        yol: yol,
                        satirlar: satirlar,
                        enFazla: 300,
                      ),
                    )
                else
                  KodKutusu(metin: _girdiMetni(o.girdi), enFazla: 160),
                if ((o.cikti ?? '').trim().isNotEmpty && fark == null) ...[
                  const SizedBox(height: 6),
                  KodKutusu(metin: o.cikti!, hata: o.hata),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

String _girdiMetni(String girdi) {
  try {
    final j = jsonDecode(girdi);
    if (j is Map && j['command'] != null) return '\$ ${j['command']}';
    if (j is Map) return const JsonEncoder.withIndent('  ').convert(j);
  } catch (_) {}
  return girdi;
}

class _OnayKarti extends StatelessWidget {
  const _OnayKarti({
    required this.oge,
    required this.ajan,
    required this.karar,
  });

  final OnayOge oge;
  final String ajan;
  final void Function(String) karar;

  String get _baslik {
    final yol = oge.ozet.split('/').last;
    return switch (oge.arac) {
      'Bash' || 'Komut' => 'Komut çalıştırmak istiyor',
      'Write' => 'Dosya oluşturmak istiyor: $yol',
      'Edit' || 'MultiEdit' => 'Dosyayı düzenlemek istiyor: $yol',
      'Dosya değişikliği' => 'Dosyaları değiştirmek istiyor',
      'WebFetch' => 'Bir sayfayı okumak istiyor',
      'WebSearch' => 'Web\'de aramak istiyor',
      _ => '${oge.arac} kullanmak istiyor',
    };
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    if (oge.kapandi) {
      final (simge, metin, renk) = switch (oge.karar) {
        'red' => (Icons.block, 'Reddedildi', r.error),
        'hep' => (Icons.done_all, 'Bu oturumda hep izinli', r.onSurfaceVariant),
        _ => (Icons.check, 'İzin verildi', r.onSurfaceVariant),
      };
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(simge, size: 15, color: renk),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$metin · ${oge.ozet}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: t.textTheme.bodySmall?.copyWith(color: renk),
              ),
            ),
          ],
        ),
      );
    }
    final fark = girdidenFark(oge.girdi);
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: r.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: r.primary.withValues(alpha: .55), width: 1.3),
        boxShadow: [
          BoxShadow(color: r.primary.withValues(alpha: .10), blurRadius: 18),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: r.primary.withValues(alpha: .14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  aracGorunumu(oge.arac).$2,
                  size: 16,
                  color: r.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${ajanAdi(ajan)} izin istiyor',
                      style: t.textTheme.labelSmall?.copyWith(
                        color: r.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _baslik,
                      style: t.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (oge.neden.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              oge.neden,
              style: t.textTheme.bodySmall?.copyWith(color: r.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 12),
          if (fark != null)
            for (final (yol, satirlar) in fark)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: DiffGorunumu(yol: yol, satirlar: satirlar),
              )
          else
            KodKutusu(metin: _girdiMetni(oge.girdi), enFazla: 200),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => karar('red'),
                child: const Text('Reddet'),
              ),
              OutlinedButton(
                onPressed: () => karar('hep'),
                child: const Text('Bu oturumda hep'),
              ),
              FilledButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  karar('izin');
                },
                icon: const Icon(Icons.check, size: 18),
                label: const Text('İzin ver'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Dosyalar extends StatelessWidget {
  const _Dosyalar({required this.dosyalar, required this.ac});
  final List<DosyaOge> dosyalar;
  final void Function(String) ac;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final d in dosyalar)
            ActionChip(
              avatar: Icon(dosyaSimgesi(d.yol), size: 15),
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(d.goreli),
                  const SizedBox(width: 6),
                  Text(
                    switch (d.eylem) {
                      'yeni' => 'yeni',
                      'silindi' => 'silindi',
                      _ => 'değişti',
                    },
                    style: t.textTheme.labelSmall?.copyWith(
                      color: d.eylem == 'yeni'
                          ? const Color(0xFF22C55E)
                          : d.eylem == 'silindi'
                          ? r.error
                          : r.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              onPressed: d.eylem == 'silindi' ? null : () => ac(d.yol),
            ),
        ],
      ),
    );
  }
}

class _BittiSatiri extends StatelessWidget {
  const _BittiSatiri({required this.oge});
  final BittiOge oge;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);
    final r = t.colorScheme;
    if (oge.hata != null) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: r.errorContainer,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, size: 16, color: r.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                oge.hata!,
                style: t.textTheme.bodySmall?.copyWith(
                  color: r.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      );
    }
    if (oge.maliyet == null) return const SizedBox(height: 4);
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 6),
      child: Text(
        '\$${oge.maliyet!.toStringAsFixed(3)}',
        style: t.textTheme.labelSmall?.copyWith(color: r.outline),
      ),
    );
  }
}

class _UyariSatiri extends StatelessWidget {
  const _UyariSatiri({required this.metin});
  final String metin;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: KodKutusu(metin: metin, hata: true, enFazla: 140),
  );
}

/// Sesli konuşma sürerken yazma kutusunun üstünde: durum, son söylenenler,
/// sessize al ve bitir.
class _SesPaneli extends StatelessWidget {
  const _SesPaneli({required this.ses});
  final SesliKonusma ses;

  @override
  Widget build(BuildContext context) {
    final r = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    final (durum, renk) = switch (ses.durum) {
      SesDurumu.kapali => ('Kapalı', r.outline),
      SesDurumu.baglaniyor => ('Bağlanıyor…', r.tertiary),
      SesDurumu.dinliyor => (ses.sessiz ? 'Sessizde' : 'Dinliyor', r.primary),
      SesDurumu.konusuyor => ('Konuşuyor', r.secondary),
      SesDurumu.calisiyor => ('Codex çalışıyor', r.tertiary),
    };
    final son = ses.satirlar.length > 4
        ? ses.satirlar.sublist(ses.satirlar.length - 4)
        : ses.satirlar;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: r.primaryContainer.withValues(alpha: .35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: renk.withValues(alpha: .4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (ses.durum == SesDurumu.baglaniyor ||
                  ses.durum == SesDurumu.calisiyor)
                SizedBox.square(
                  dimension: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: renk),
                )
              else
                Icon(
                  ses.acik ? Icons.graphic_eq_rounded : Icons.mic_off_rounded,
                  size: 18,
                  color: renk,
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  ses.acik ? 'Sesli konuşma · $durum' : 'Sesli konuşma',
                  style: t.labelLarge?.copyWith(color: renk),
                ),
              ),
              if (ses.acik)
                IconButton(
                  tooltip: ses.sessiz ? 'Mikrofonu aç' : 'Sessize al',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    ses.sessiz ? Icons.mic_off_rounded : Icons.mic_rounded,
                    size: 20,
                  ),
                  onPressed: ses.sessizeAl,
                ),
              IconButton(
                tooltip: ses.acik ? 'Bitir' : 'Kapat',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () {
                  if (ses.acik) {
                    ses.bitir();
                  } else {
                    ses.hatayiKapat();
                  }
                },
              ),
            ],
          ),
          if (ses.hata != null)
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 8),
              child: Text(
                ses.hata!,
                style: t.bodySmall?.copyWith(color: r.error),
              ),
            ),
          for (final satir in son)
            if (satir.metin.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, right: 8),
                child: Text(
                  satir.metin.trim(),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: t.bodyMedium?.copyWith(
                    color: satir.kullanici ? r.onSurfaceVariant : r.onSurface,
                    fontStyle: satir.kullanici ? FontStyle.italic : null,
                  ),
                ),
              ),
          if (ses.acik && son.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Konuşabilirsin. "Kapat" deyince biter; onayları ekrandan verirsin.',
                style: t.bodySmall?.copyWith(color: r.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}
