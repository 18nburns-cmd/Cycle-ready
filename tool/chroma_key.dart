import 'dart:io';

import 'package:image/image.dart' as img;

void main(List<String> arguments) {
  if (arguments.length != 2) {
    stderr.writeln('Usage: chroma_key.dart <input> <output>');
    exitCode = 64;
    return;
  }
  final source = img.decodeImage(File(arguments[0]).readAsBytesSync());
  if (source == null) throw StateError('Could not decode ${arguments[0]}');
  for (final pixel in source) {
    final red = pixel.r.toInt();
    final green = pixel.g.toInt();
    final blue = pixel.b.toInt();
    final dominance = green - (red > blue ? red : blue);
    if (green > 145 && dominance > 35) {
      pixel.a = (255 - (dominance - 35) * 4).clamp(0, 255);
      pixel.g = ((red + blue) ~/ 2 + 12).clamp(0, 255);
    }
  }
  File(arguments[1]).writeAsBytesSync(img.encodePng(source, level: 6));
}
