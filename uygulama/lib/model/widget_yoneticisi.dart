import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../ekran/oturum_arama.dart';
import '../ekran/widget_ayarlari.dart';
import '../servis/bildirim.dart';
import '../servis/kopru_istemci.dart';
import 'bildirim_yoneticisi.dart';
import 'calisma.dart';

/// Ana ekran widget'ını besler: çalışan ajanlar, bekleyen onaylar, son
/// oturumlar ve kota. Durum değiştikçe (kısa bir bekleyişle) özet JSON'u
/// Android tarafına gönderir; widget onu saklayıp çizer (AtolyeWidget.kt).
/// Widget düğmelerinden gelen "yeni", "ara" ve "widgetAyar" da burada açılır.
class WidgetYoneticisi {
  WidgetYoneticisi(this.c, this.bildirim, this.gezgin) {
    ornek = this;
    c.addListener(guncelle);
    bildirim.onayDegisti.addListener(guncelle);
    bildirim.eylem = _eylem;
    guncelle();
    unawaited(_acilistaEylem());
  }

  static WidgetYoneticisi? ornek;

  final Calisma c;
  final BildirimYoneticisi bildirim;
  final GlobalKey<NavigatorState> gezgin;
  Timer? _zaman;
  String _son = '';

  /// En çok kaç oturum gönderilir (widget en çok 8 satır gösterir).
  static const _enCok = 8;

  /// Ayar ya da durum değişti: kısa süre içinde gelenler tek gönderimde birleşir.
  void guncelle() {
    if (!Bildirim.destekleniyor) return;
    _zaman?.cancel();
    _zaman = Timer(const Duration(milliseconds: 300), _gonder);
  }

  Future<void> _gonder() async {
    final json = jsonEncode(ozet(c, bildirim.onaylar));
    if (json == _son) return;
    _son = json;
    await Bildirim.widget(json);
  }

  static String _kisaAd(String ajan) => switch (ajan) {
    'claude' => 'Claude',
    'codex' => 'Codex',
    _ => ajan.isEmpty ? 'Ajan' : '${ajan[0].toUpperCase()}${ajan.substring(1)}',
  };

  static String _baslik(Map o) {
    final b = (o['baslik'] as String?)?.trim() ?? '';
    return b.isNotEmpty ? b : (o['goreli'] as String?) ?? '';
  }

  /// Widget'ın gösterdiği her şey (test edilebilsin diye ayrı).
  static Map<String, dynamic> ozet(
    Calisma c,
    Map<String, List<Map<String, dynamic>>> onaylar,
  ) {
    final oturumlar = [
      for (final o in c.oturumlar)
        if (o['asistan'] != true) o,
    ];
    final bekleyen = {
      for (final e in onaylar.entries)
        if (e.value.isNotEmpty) e.key,
    };
    num zaman(Map o) =>
        (o['guncelleme'] as num?) ?? (o['olusturma'] as num?) ?? 0;
    // Sıra: onay bekleyenler, çalışanlar, sonra en son güncellenen.
    int oncelik(Map o) => bekleyen.contains(o['id'])
        ? 0
        : o['durum'] == 'calisiyor'
        ? 1
        : 2;
    oturumlar.sort((a, b) {
      final p = oncelik(a).compareTo(oncelik(b));
      return p != 0 ? p : zaman(b).compareTo(zaman(a));
    });

    Map<String, dynamic>? onay;
    var onaySayisi = 0;
    for (final l in onaylar.values) {
      onaySayisi += l.length;
    }
    final ilkOturum = oturumlar
        .where((o) => bekleyen.contains(o['id']))
        .firstOrNull;
    final ilkId =
        (ilkOturum?['id'] as String?) ??
        onaylar.entries.where((e) => e.value.isNotEmpty).firstOrNull?.key;
    if (ilkId != null) {
      final e = onaylar[ilkId]!.first;
      final o = c.oturumlar.where((x) => x['id'] == ilkId).firstOrNull;
      onay = {
        'oturum': ilkId,
        'rid': e['rid'],
        'kimlik': BildirimYoneticisi.kimlik(ilkId),
        'ajanAdi': _kisaAd((o?['ajan'] as String?) ?? ''),
        'baslik': o == null ? 'Oturum' : _baslik(o),
        'metin': [
          if ((e['arac'] as String?)?.isNotEmpty == true) e['arac'],
          if ((e['ozet'] as String?)?.isNotEmpty == true) e['ozet'],
        ].join(': '),
      };
    }

    // Kota: her ajanın en dolu penceresi.
    final kota = <String, dynamic>{};
    for (final a in const ['claude', 'codex']) {
      Map? enDolu;
      for (final p in (c.kotalar[a] ?? const []).whereType<Map>()) {
        if (enDolu == null ||
            ((p['kullanim'] as num?) ?? 0) >
                ((enDolu['kullanim'] as num?) ?? 0)) {
          enDolu = p;
        }
      }
      if (enDolu != null) {
        kota[a] = {
          'yuzde': ((enDolu['kullanim'] as num?) ?? 0).round(),
          'sifirlanma': enDolu['sifirlanma'],
        };
      }
    }

    return {
      'bagli': c.baglanti == BaglantiDurumu.bagli,
      'calisan': oturumlar.where((o) => o['durum'] == 'calisiyor').length,
      'onay': onay,
      'onaySayisi': onaySayisi,
      'oturumlar': [
        for (final o in oturumlar.take(_enCok))
          {
            'id': o['id'],
            'ajan': o['ajan'],
            'ajanAdi': _kisaAd((o['ajan'] as String?) ?? ''),
            'baslik': _baslik(o),
            'yer': o['goreli'],
            'durum': o['durum'],
            'zaman': zaman(o),
            'onay': bekleyen.contains(o['id']),
          },
      ],
      'kota': kota.isEmpty ? null : kota,
      'ayar': c.ayarlar.widgetAyari,
    };
  }

  // --- widget düğmeleri

  Future<void> _acilistaEylem() async {
    final e = await Bildirim.acilisEylem();
    if (e != null) _eylem(e);
  }

  Future<void> _eylem(String e) async {
    if (e == 'widgetYenile') {
      _son = '';
      if (c.baglanti == BaglantiDurumu.bagli) {
        await c.yenile();
        unawaited(c.kotaYenile());
      }
      guncelle();
      return;
    }
    // Uygulama yeni açıldıysa gezgin hazır olana kadar bekle.
    for (var i = 0; i < 40 && gezgin.currentState == null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    final g = gezgin.currentState;
    if (g == null) return;
    switch (e) {
      case 'yeni':
        // Başlangıç ekranı yeni oturumun yeri.
        g.popUntil((r) => r.isFirst);
        c.baslangica();
      case 'ara':
        g.popUntil((r) => r.isFirst);
        if (!c.yetenek('ara')) {
          for (var i = 0; i < 40 && c.baglanti != BaglantiDurumu.bagli; i++) {
            await Future<void>.delayed(const Duration(milliseconds: 250));
          }
        }
        unawaited(
          g.push(MaterialPageRoute(builder: (_) => OturumArama(calisma: c))),
        );
      case 'widgetAyar':
        unawaited(
          g.push(MaterialPageRoute(builder: (_) => WidgetAyarlari(calisma: c))),
        );
    }
  }
}
