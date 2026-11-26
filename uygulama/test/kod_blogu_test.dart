import 'package:atolye/arayuz/kod_blogu.dart';
import 'package:atolye/arayuz/markdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dil etiketleri ve uzantılar aynı kurala gider', () {
    expect(kodDili('python')?.$1, 'python');
    expect(kodDili('py')?.$1, 'python');
    expect(kodDili('Shell')?.$1, 'bash');
    expect(kodDili('tsx')?.$1, 'typescript');
    expect(kodDili('bilinmeyen'), isNull);
    expect(kodDili(''), isNull);
  });

  test('bilinen dil renklendirilir, bilinmeyen düz kalır', () {
    const taban = TextStyle(fontSize: 12);
    final span = kodRenklendir(
      'def f():\n    return 1',
      'python',
      taban,
      koyu: false,
    );
    expect(span, isNotNull);
    expect(span!.toPlainText(), 'def f():\n    return 1');
    expect(kodRenklendir('x', 'yok', taban, koyu: false), isNull);
  });

  testWidgets('Markdown kod bloğu başlık ve Kopyala ile çizilir', (
    tester,
  ) async {
    String? pano;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          pano = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Markdown('Örnek:\n\n```dart\nvoid main() => print(1);\n```\n'),
        ),
      ),
    );
    expect(find.byType(KodBlogu), findsOneWidget);
    expect(find.text('dart'), findsOneWidget);
    await tester.tap(find.text('Kopyala'));
    await tester.pump();
    expect(pano, 'void main() => print(1);');
    expect(find.text('Kopyalandı'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Kopyala'), findsOneWidget);
  });
}
