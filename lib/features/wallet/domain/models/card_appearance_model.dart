import 'package:flutter/material.dart';

class CardAppearance {
  final String name;
  final Color cardColor;
  final Color textColor;
  final Color brandColor;

  const CardAppearance({
    required this.name,
    required this.cardColor,
    required this.textColor,
    required this.brandColor,
  });
}

class CardAppearances {
  static const List<CardAppearance> options = [
    // Row 1: Light Green, Dark Green, Yellow/Gold
    CardAppearance(
      name: 'Lime',
      cardColor: Color(0xFFD4F57A),
      textColor: Color(0xFF2D4A0E),
      brandColor: Color(0xFF2D4A0E),
    ),
    CardAppearance(
      name: 'Forest',
      cardColor: Color(0xFF1B4332),
      textColor: Colors.white,
      brandColor: Color(0xFF52B788),
    ),
    CardAppearance(
      name: 'Gold',
      cardColor: Color(0xFFF5C542),
      textColor: Color(0xFF8B4513),
      brandColor: Color(0xFFD4380D),
    ),
    // Row 2: Red/Orange, Light Gray, Light Blue
    CardAppearance(
      name: 'Ember',
      cardColor: Color(0xFFE84D25),
      textColor: Colors.white,
      brandColor: Colors.white,
    ),
    CardAppearance(
      name: 'Silver',
      cardColor: Color(0xFFE8E8E8),
      textColor: Color(0xFF333333),
      brandColor: Color(0xFF555555),
    ),
    CardAppearance(
      name: 'Ice',
      cardColor: Color(0xFFD6E4F0),
      textColor: Color(0xFF2C3E6B),
      brandColor: Color(0xFF3B5998),
    ),
    // Row 3: Charcoal, Blue, Pink/Rose
    CardAppearance(
      name: 'Charcoal',
      cardColor: Color(0xFF3D3D3D),
      textColor: Colors.white,
      brandColor: Color(0xFFAAAAAA),
    ),
    CardAppearance(
      name: 'Ocean',
      cardColor: Color(0xFF1565C0),
      textColor: Colors.white,
      brandColor: Colors.white,
    ),
    CardAppearance(
      name: 'Rose',
      cardColor: Color(0xFFF5C6C6),
      textColor: Color(0xFF8B3A3A),
      brandColor: Color(0xFFD4380D),
    ),
  ];
}
