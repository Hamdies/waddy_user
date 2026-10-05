import 'package:flutter/material.dart';
import 'package:waddy_app/common/widgets/custom_image.dart';
import 'package:waddy_app/common/widgets/pressable.dart';
import 'package:waddy_app/util/dimensions.dart';
import 'package:waddy_app/util/styles.dart';

/// One tile of [MintCategoryGrid]. A null entry in the list draws a skeleton.
class MintCategoryTile {
  final String name;
  final String imageUrl;
  final VoidCallback onTap;
  const MintCategoryTile({
    required this.name,
    required this.imageUrl,
    required this.onTap,
  });
}

/// The "Browse categories" grid from the Mart Search design: three-up mint
/// tiles with the photo contained, the name underneath on up to two lines.
///
/// Built as rows of [Expanded] cells rather than a `GridView`: a grid needs the
/// cell's height up front, and the label's real height (font metrics, the
/// viewer's text scale, one line or two) is not known up front — the first
/// version guessed it and clipped "Poultry, Meat & Fish" by four pixels. A row
/// takes the height its tallest label actually needs.
class MintCategoryGrid extends StatelessWidget {
  final List<MintCategoryTile?> tiles;

  static const int _columns = 3;
  static const Color _fill = Color(0xFFE6F4F3);
  static const Color _border = Color(0xFFB9ECDD);

  const MintCategoryGrid({super.key, required this.tiles});

  @override
  Widget build(BuildContext context) {
    final List<Widget> rows = <Widget>[];
    for (int start = 0; start < tiles.length; start += _columns) {
      final List<Widget> cells = <Widget>[];
      for (int i = start; i < start + _columns; i++) {
        if (i > start) {
          cells.add(const SizedBox(width: Dimensions.paddingSizeMedium - 2));
        }
        cells.add(
          Expanded(
            child: i < tiles.length ? _Cell(tile: tiles[i]) : const SizedBox(),
          ),
        );
      }
      if (start > 0) {
        rows.add(const SizedBox(height: Dimensions.paddingSizeMedium));
      }
      rows.add(
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: cells),
      );
    }
    return Column(children: rows);
  }
}

class _Cell extends StatelessWidget {
  final MintCategoryTile? tile;
  const _Cell({required this.tile});

  @override
  Widget build(BuildContext context) {
    final MintCategoryTile? t = tile;
    final Widget content = Column(
      children: [
        AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: MintCategoryGrid._fill,
              border: Border.all(color: MintCategoryGrid._border),
              borderRadius: BorderRadius.circular(Dimensions.radiusLarge),
            ),
            child:
                t == null
                    ? null
                    : ClipRRect(
                      borderRadius: BorderRadius.circular(
                        Dimensions.radiusLarge,
                      ),
                      child: CustomImage(
                        image: t.imageUrl,
                        fit: BoxFit.contain,
                        fallback: const SizedBox(),
                      ),
                    ),
          ),
        ),
        const SizedBox(height: Dimensions.paddingSizeSmall - 2),
        if (t == null)
          Container(
            width: 40,
            height: 9,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F4F3),
              borderRadius: BorderRadius.circular(Dimensions.radiusExtraSmall),
            ),
          )
        else
          Text(
            t.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: waddyMedium.copyWith(
              fontSize: Dimensions.fontSizeExtraSmall,
              height: 1.25,
              color: const Color(0xFF1A1F1E),
            ),
          ),
      ],
    );
    if (t == null) return content;
    return Pressable(scale: 0.96, onTap: t.onTap, child: content);
  }
}
