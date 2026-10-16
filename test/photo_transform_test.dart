import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:nalaro_seller_center/ui/features/products/photo_review_screen.dart';

void main() {
  test('photo center crop preserves selected pixels and alpha', () {
    final source = img.Image(width: 4, height: 2, numChannels: 4);
    for (final p in source) {
      p.setRgba(p.x * 50, p.y * 100, 20, 120);
    }
    final output = transformProductPhoto((
      bytes: img.encodePng(source),
      turns: 0,
      ratio: 1,
    ));
    final cropped = img.decodePng(output)!;
    expect((cropped.width, cropped.height), (2, 2));
    expect(cropped.getPixel(0, 0).r, 50);
    expect(cropped.getPixel(1, 1).r, 100);
    expect(cropped.getPixel(1, 1).a, 120);
  });
  test('photo rotation changes orientation without modifying original', () {
    final source = img.Image(width: 4, height: 2, numChannels: 4);
    source.setPixelRgba(0, 1, 240, 20, 10, 255);
    final original = img.encodePng(source);
    final rotated = img.decodePng(
      transformProductPhoto((bytes: original, turns: 1, ratio: null)),
    )!;
    expect((rotated.width, rotated.height), (2, 4));
    expect(rotated.getPixel(0, 0).r, 240);
    expect(img.decodePng(original)!.width, 4);
    expect(
      identical(
        transformProductPhoto((bytes: original, turns: 0, ratio: null)),
        original,
      ),
      true,
    );
  });
}
