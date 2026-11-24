import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:xterm/xterm.dart';

import '../servis/kopru_istemci.dart';

/// Bir proje klasöründe köprünün açtığı gerçek kabuk (PTY). Ekrandan
/// çıkılınca kapanmaz; Terminal sayfası yeniden açılınca kaldığı yerden
/// sürer. Köprü yeniden başlarsa yeni kabuk açılır.
class TerminalOturumu extends ChangeNotifier {
  TerminalOturumu(this.istemci, this.cwd) {
    terminal = Terminal(
      maxLines: 5000,
      platform: defaultTargetPlatform == TargetPlatform.android
          ? TerminalTargetPlatform.android
          : TerminalTargetPlatform.linux,
      onOutput: (v) => _gonder('terminal_yaz', {'veri': v}),
      onResize: (sutun, satir, _, _) {
        _sutun = sutun;
        _satir = satir;
        _gonder('terminal_boyut', {'sutun': sutun, 'satir': satir});
      },
    );
    _abone = istemci.olaylar.listen(_olay);
  }

  final KopruIstemci istemci;
  final String cwd;
  late final Terminal terminal;
  StreamSubscription? _abone;

  String? _tid;
  bool canli = false;
  bool aciliyor = false;
  String? hata;
  int _sutun = 80, _satir = 24;

  /// Kabuğu açar ya da köprüde hâlâ yaşıyorsa ona yeniden bağlanır.
  Future<void> baslat() async {
    if (aciliyor) return;
    aciliyor = true;
    hata = null;
    notifyListeners();
    try {
      if (_tid != null) {
        try {
          final g = await istemci.iste('terminal_gecmis', {'tid': _tid});
          if (g['canli'] == true) {
            // köprü aynı: ekran zaten güncel, yalnız boyutu bildir
            canli = true;
            _gonder('terminal_boyut', {'sutun': _sutun, 'satir': _satir});
            return;
          }
        } catch (_) {
          // köprü yeniden başlamış: terminal yok
        }
        terminal.write('\r\n\x1b[2m— yeni kabuk —\x1b[0m\r\n');
      }
      final r = await istemci.iste('terminal_ac', {
        'cwd': cwd,
        'sutun': _sutun,
        'satir': _satir,
      });
      _tid = r['tid'] as String?;
      canli = true;
    } catch (e) {
      hata = '$e';
    } finally {
      aciliyor = false;
      notifyListeners();
    }
  }

  void _gonder(String op, Map<String, dynamic> p) {
    final tid = _tid;
    if (tid == null || !canli) return;
    unawaited(istemci.iste(op, {'tid': tid, ...p}).catchError((_) => <String, dynamic>{}));
  }

  /// Klavyede olmayan tuşlar ve kısayollar için (araç çubuğu).
  void yaz(String veri) => _gonder('terminal_yaz', {'veri': veri});

  void _olay(Map<String, dynamic> e) {
    if (e['ev'] != 'terminal' || e['tid'] != _tid) return;
    if (e['tur'] == 'kapandi') {
      canli = false;
      terminal.write(
        '\r\n\x1b[2m— kabuk kapandı (${e['kod'] ?? '?'}) —\x1b[0m\r\n',
      );
      notifyListeners();
      return;
    }
    final v = e['veri'] as String?;
    if (v != null) terminal.write(v);
  }

  Future<void> kapat() async {
    final tid = _tid;
    _tid = null;
    canli = false;
    if (tid != null) {
      try {
        await istemci.iste('terminal_kapat', {'tid': tid});
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _abone?.cancel();
    super.dispose();
  }
}
