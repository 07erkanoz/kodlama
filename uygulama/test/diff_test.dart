import 'package:atolye/arayuz/ortak.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('satır farkı yalnız değişen satırları işaretler', () {
    final f = satirFarki('a\nb\nc', 'a\nB\nc\nd');
    expect(f.map((s) => '${s.tur.name}:${s.metin}').toList(), [
      'ayni:a',
      'silindi:b',
      'eklendi:B',
      'ayni:c',
      'eklendi:d',
    ]);
  });

  test('Claude Edit girdisinden fark çıkar', () {
    final f = girdidenFark(
      '{"file_path":"/p/x.dart","old_string":"var a = 1;","new_string":"final a = 2;"}',
    )!;
    expect(f.single.$1, '/p/x.dart');
    expect(
      f.single.$2.where((s) => s.tur == SatirTuru.eklendi).single.metin,
      'final a = 2;',
    );
  });

  test('Codex birleşik diff satırlarını ayırır', () {
    final f = girdidenFark(
      '{"changes":[{"path":"a.txt","diff":"@@ -1 +1 @@\\n-eski\\n+yeni"}]}',
    )!;
    expect(f.single.$2.map((s) => s.tur).toList(), [
      SatirTuru.baslik,
      SatirTuru.silindi,
      SatirTuru.eklendi,
    ]);
  });

  test('komut girdisinde fark yok', () {
    expect(girdidenFark('{"command":"ls"}'), isNull);
  });

  test('git başlık satırları içerik sayılmaz', () {
    final f = birlesikFark(
      'diff --git a/x b/x\nnew file mode 100644\nindex 0000000..1\n--- /dev/null\n+++ b/x\n@@ -0,0 +1 @@\n+a',
    );
    expect(
      f.where((s) => s.tur != SatirTuru.baslik).map((s) => s.metin).toList(),
      ['a'],
    );
  });
}
