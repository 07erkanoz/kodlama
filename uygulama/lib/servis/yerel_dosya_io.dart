import 'dart:io';
import 'dart:typed_data';

/// Uygulamanın kendi önbelleğindeki bir dosya (paylaşılan, kameradan…).
Future<Uint8List> yerelDosyaOku(String yol) => File(yol).readAsBytes();
