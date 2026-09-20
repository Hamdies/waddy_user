// import 'package:flutter/material.dart';
// import 'package:flutter_test/flutter_test.dart';

// void main() {
//   testWidgets('marks and stickers render without overflow', (tester) async {
//     await tester.pumpWidget(
//       MaterialApp(
//         home: Scaffold(
//           backgroundColor: Spots.canvas,
//           body: Center(
//             child: Column(
//               mainAxisSize: MainAxisSize.min,
//               children: [
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: const [
//                     SpotsGlyph(SpotsMark.crown, size: 40),
//                     SizedBox(width: 12),
//                     SpotsGlyph(SpotsMark.flame, size: 40),
//                     SizedBox(width: 12),
//                     SpotsGlyph(SpotsMark.trophy, size: 40),
//                     SizedBox(width: 12),
//                     SpotsGlyph(SpotsMark.bolt, size: 40),
//                     SizedBox(width: 12),
//                     SpotsGlyph(SpotsMark.pin, size: 40),
//                     SizedBox(width: 12),
//                     SpotsGlyph(SpotsMark.star, size: 40),
//                     SizedBox(width: 12),
//                     SpotsGlyph(SpotsMark.rising, size: 40),
//                   ],
//                 ),
//                 const SizedBox(height: 24),
//                 const SpotsSticker(
//                   label: 'LIVE LEADER',
//                   mark: SpotsMark.flame,
//                   live: true,
//                 ),
//                 const SizedBox(height: 20),
//                 const SpotsSticker(
//                   label: 'CURRENT CHAMPION',
//                   mark: SpotsMark.trophy,
//                   fill: Spots.teal,
//                   fg: Spots.mint,
//                 ),
//               ],
//             ),
//           ),
//         ),
//       ),
//     );
//     await tester.pump(const Duration(milliseconds: 300));
//     expect(tester.takeException(), isNull);
//     await expectLater(
//       find.byType(Scaffold),
//       matchesGoldenFile('spots_marks.png'),
//     );
//   });
// }
