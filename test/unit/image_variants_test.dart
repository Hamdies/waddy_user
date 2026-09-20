import 'package:flutter_test/flutter_test.dart';
import 'package:waddy_app/common/models/image_variants.dart';

/// The variant ladder is the one piece of the image work with real branching,
/// and it is the piece that decides whether a customer downloads 1.4 KB or
/// 596 KB. Sizes here mirror `config/imagevariants.php` on the backend.
void main() {
  Map<String, dynamic> payload({
    bool webpThumb = true,
    bool webpCard = true,
    bool jpg = true,
    bool original = true,
  }) => <String, dynamic>{
    'webp': <String, dynamic>{
      if (webpThumb) 'thumb': 'https://w/store/variants/thumb/a.webp',
      if (webpCard) 'card': 'https://w/store/variants/card/a.webp',
    },
    'jpg': <String, dynamic>{
      if (jpg) 'thumb': 'https://w/store/variants/thumb/a.jpg',
      if (jpg) 'card': 'https://w/store/variants/card/a.jpg',
    },
    if (original) 'original': 'https://w/store/a.png',
  };

  group('fromJson', () {
    test('parses a full variant set', () {
      final ImageVariants? v = ImageVariants.fromJson(payload());
      expect(v, isNotNull);
      expect(v!.webp['thumb'], 'https://w/store/variants/thumb/a.webp');
      expect(v.original, 'https://w/store/a.png');
    });

    test(
      'returns null for the shapes an older or failing payload produces',
      () {
        // No variants key at all — an endpoint that has not been updated, or a
        // response cached before the header opt-in shipped.
        expect(ImageVariants.fromJson(null), isNull);
        // Wrong type entirely.
        expect(ImageVariants.fromJson('nope'), isNull);
        expect(ImageVariants.fromJson(<String, dynamic>{}), isNull);
        // Present but empty: generation failed for this image and the backend
        // still served the original. Must degrade, not throw.
        expect(
          ImageVariants.fromJson(<String, dynamic>{'webp': {}, 'jpg': {}}),
          isNull,
        );
      },
    );

    test(
      'drops null and empty URLs rather than serving them as image sources',
      () {
        final ImageVariants? v = ImageVariants.fromJson(<String, dynamic>{
          'webp': <String, dynamic>{'thumb': '', 'card': null},
          'jpg': <String, dynamic>{'thumb': 'https://w/a.jpg'},
        });
        expect(v, isNotNull);
        expect(v!.webp, isEmpty);
        expect(v.jpg['thumb'], 'https://w/a.jpg');
      },
    );
  });

  group('urlFor picks the smallest variant that still covers the request', () {
    final ImageVariants v = ImageVariants.fromJson(payload())!;

    test('a 40pt logo at 3x (120 physical px) takes the thumb', () {
      expect(v.urlFor(120), contains('/thumb/'));
      expect(v.urlFor(120), endsWith('.webp'));
    });

    test('exactly at a rung boundary still takes that rung, not the next', () {
      expect(v.urlFor(150), contains('/thumb/'));
      expect(v.urlFor(400), contains('/card/'));
    });

    test('one pixel over a rung moves up — never serve a soft image', () {
      expect(v.urlFor(151), contains('/card/'));
    });

    test('beyond the largest generated rung returns null so the caller '
        'falls back to the original', () {
      // hero (1200) is configured on the backend but not generated for these
      // directories, so a full-bleed request has nothing to match.
      expect(v.urlFor(1080), isNull);
    });

    test(
      'prefers WebP but falls back to JPEG when a size is missing from it',
      () {
        final ImageVariants noWebpCard =
            ImageVariants.fromJson(payload(webpCard: false))!;
        expect(noWebpCard.urlFor(300), contains('/card/'));
        expect(noWebpCard.urlFor(300), endsWith('.jpg'));
      },
    );
  });

  group('intrinsicWidthFor', () {
    final ImageVariants v = ImageVariants.fromJson(payload())!;

    test('reports the real file width so the decode is not upscaled', () {
      // A 44pt logo at 3x asks for 132 px, but the thumb file only holds 150 —
      // and asking the decoder for more than the file contains wastes memory.
      expect(v.intrinsicWidthFor(132), 150);
      expect(v.intrinsicWidthFor(300), 400);
    });

    test('agrees with urlFor about when nothing matches', () {
      expect(v.urlFor(1080), isNull);
      expect(v.intrinsicWidthFor(1080), isNull);
    });
  });

  test(
    'round-trips through toJson so the local cache does not lose variants',
    () {
      final ImageVariants v = ImageVariants.fromJson(payload())!;
      final ImageVariants? back = ImageVariants.fromJson(v.toJson());
      expect(back, isNotNull);
      expect(back!.urlFor(120), v.urlFor(120));
      expect(back.original, v.original);
    },
  );
}
