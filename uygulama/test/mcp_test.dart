import 'package:atolye/ekran/mcp_ekrani.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('komut tırnaklara saygı göstererek bölünür', () {
    expect(komutuBol('npx -y "@a/b c" /tmp'), ['npx', '-y', '@a/b c', '/tmp']);
    expect(komutuBol("  uvx  'x y'  "), ['uvx', 'x y']);
    expect(komutuBol('a ""'), ['a', '']);
  });
  test('ortam ve başlık satırları ayrılır', () {
    expect(satirlariAyir('A=1\nB = x=y\n\nboş', '='), {'A': '1', 'B': 'x=y'});
    expect(satirlariAyir('Authorization: Bearer t:1', ':'), {
      'Authorization': 'Bearer t:1',
    });
  });
}
