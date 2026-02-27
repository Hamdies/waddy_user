import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Balloon Pop — balloons float up from the bottom.
/// Tap to pop them before they escape off the top.
/// Miss 3 balloons = game over. Combo streaks, speed increases.
class BalloonPopGame extends StatefulWidget {
  final VoidCallback onBack;
  const BalloonPopGame({super.key, required this.onBack});

  @override
  State<BalloonPopGame> createState() => _BalloonPopGameState();
}

class _Balloon {
  double x; // 0-1 horizontal position
  double y; // 0-1 vertical (1 = bottom, 0 = top)
  double speed; // how fast it rises per tick
  Color color;
  double size; // radius multiplier 0.8-1.2
  bool popped;
  _Balloon({
    required this.x,
    required this.y,
    required this.speed,
    required this.color,
    required this.size,
  }) : popped = false;
}

class _PopEffect {
  double x, y;
  Color color;
  int ticksLeft;
  _PopEffect({required this.x, required this.y, required this.color}) : ticksLeft = 8;
}

class _BalloonPopGameState extends State<BalloonPopGame> {
  static const Color _teal = Color(0xFF134E4A);
  static const Color _neon = Color(0xFF1EF2A0);

  static const List<Color> _balloonColors = [
    Color(0xFFEF4444), // red
    Color(0xFF3B82F6), // blue
    Color(0xFFF59E0B), // amber
    Color(0xFF8B5CF6), // purple
    Color(0xFFEC4899), // pink
    Color(0xFF1EF2A0), // neon green
    Color(0xFFF97316), // orange
  ];

  final Random _rng = Random();
  Timer? _ticker;
  bool _gameStarted = false;
  bool _gameOver = false;
  int _score = 0;
  int _highScore = 0;
  int _missed = 0;
  int _combo = 0;
  int _bestCombo = 0;

  final List<_Balloon> _balloons = [];
  final List<_PopEffect> _pops = [];
  int _tickCount = 0;
  int _spawnInterval = 50; // ticks between spawns
  double _baseSpeed = 0.004;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startGame() {
    _ticker?.cancel();
    setState(() {
      _gameStarted = true;
      _gameOver = false;
      _score = 0;
      _missed = 0;
      _combo = 0;
      _bestCombo = 0;
      _tickCount = 0;
      _spawnInterval = 50;
      _baseSpeed = 0.004;
      _balloons.clear();
      _pops.clear();
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 16), (_) => _tick());
  }

  void _tick() {
    if (!mounted || _gameOver) return;
    _tickCount++;

    setState(() {
      // Move balloons up
      for (final b in _balloons) {
        if (!b.popped) b.y -= b.speed;
      }

      // Check escaped balloons (past top)
      _balloons.removeWhere((b) {
        if (!b.popped && b.y < -0.08) {
          _missed++;
          _combo = 0;
          HapticFeedback.lightImpact();
          if (_missed >= 3) _endGame();
          return true;
        }
        return false;
      });

      // Remove finished pop effects
      for (final p in _pops) {
        p.ticksLeft--;
      }
      _pops.removeWhere((p) => p.ticksLeft <= 0);

      // Remove popped balloons after brief delay
      _balloons.removeWhere((b) => b.popped);

      // Spawn new balloons
      if (_tickCount % _spawnInterval == 0) {
        _spawnBalloon();
      }

      // Difficulty ramp every 8 points
      if (_score > 0 && _score % 8 == 0 && _spawnInterval > 20) {
        _spawnInterval = max(20, _spawnInterval - 1);
        _baseSpeed = min(0.009, _baseSpeed + 0.0002);
      }
    });
  }

  void _spawnBalloon() {
    final color = _balloonColors[_rng.nextInt(_balloonColors.length)];
    _balloons.add(_Balloon(
      x: 0.1 + _rng.nextDouble() * 0.8,
      y: 1.1,
      speed: _baseSpeed + _rng.nextDouble() * 0.002,
      color: color,
      size: 0.85 + _rng.nextDouble() * 0.3,
    ));
  }

  void _onTapDown(TapDownDetails details, BoxConstraints constraints) {
    if (_gameOver) return;
    final dx = details.localPosition.dx / constraints.maxWidth;
    final dy = details.localPosition.dy / constraints.maxHeight;

    // Find nearest balloon within tap radius
    _Balloon? tapped;
    double bestDist = double.infinity;
    for (final b in _balloons) {
      if (b.popped) continue;
      final dist = sqrt(pow(dx - b.x, 2) + pow(dy - b.y, 2));
      final hitRadius = 0.07 * b.size;
      if (dist < hitRadius && dist < bestDist) {
        bestDist = dist;
        tapped = b;
      }
    }

    if (tapped != null) {
      HapticFeedback.lightImpact();
      tapped.popped = true;
      _pops.add(_PopEffect(x: tapped.x, y: tapped.y, color: tapped.color));
      setState(() {
        _score++;
        _combo++;
        if (_combo > _bestCombo) _bestCombo = _combo;
      });
    }
  }

  void _endGame() {
    _ticker?.cancel();
    HapticFeedback.heavyImpact();
    if (_score > _highScore) _highScore = _score;
    _gameOver = true;
  }

  @override
  Widget build(BuildContext context) {
    if (!_gameStarted) return _buildStart();
    if (_gameOver) return _buildGameOver();
    return _buildPlaying();
  }

  Widget _buildStart() {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.pink.withValues(alpha: 0.15),
          border: Border.all(color: Colors.pink.withValues(alpha: 0.3), width: 2),
        ),
        child: const Icon(Icons.bubble_chart, color: Colors.pink, size: 28),
      ),
      const SizedBox(height: 12),
      const Text('Balloon Pop', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      Text('Pop balloons before they escape!', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
      const SizedBox(height: 16),
      Row(mainAxisSize: MainAxisSize.min, children: [
        _actionButton('Start', _neon, _teal, _startGame),
        const SizedBox(width: 10),
        _actionButton('Back', Colors.transparent, Colors.white60, widget.onBack, border: true),
      ]),
      if (_highScore > 0) ...[
        const SizedBox(height: 10),
        Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.emoji_events, color: Colors.amber, size: 14),
          const SizedBox(width: 4),
          Text('Best: $_highScore', style: TextStyle(color: _neon.withValues(alpha: 0.6), fontSize: 11)),
        ]),
      ],
    ]));
  }

  Widget _buildPlaying() {
    return LayoutBuilder(builder: (context, constraints) {
      return GestureDetector(
        onTapDown: (d) => _onTapDown(d, constraints),
        behavior: HitTestBehavior.opaque,
        child: Stack(children: [
          // Balloons + pop effects
          Positioned.fill(
            child: CustomPaint(painter: _BalloonPainter(
              balloons: _balloons,
              pops: _pops,
            )),
          ),
          // HUD
          Positioned(
            top: 6, left: 14, right: 14,
            child: Row(children: [
              // Score
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: _neon.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                child: Text('$_score', style: const TextStyle(color: _neon, fontSize: 13, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 8),
              // Combo
              if (_combo > 1)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(6)),
                  child: Text('x$_combo', style: const TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              const Spacer(),
              // Missed (hearts)
              Row(children: List.generate(3, (i) => Padding(
                padding: const EdgeInsets.only(left: 3),
                child: Icon(
                  i < (3 - _missed) ? Icons.favorite : Icons.favorite_border,
                  color: i < (3 - _missed) ? Colors.redAccent : Colors.white24,
                  size: 16,
                ),
              ))),
            ]),
          ),
        ]),
      );
    });
  }

  Widget _buildGameOver() {
    final bool isNewHigh = _score >= _highScore && _score > 0;
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(isNewHigh ? Icons.emoji_events : Icons.bubble_chart, color: isNewHigh ? Colors.amber : Colors.pink, size: 38),
      const SizedBox(height: 8),
      Text(isNewHigh ? 'New Record!' : 'Game Over!', style: TextStyle(color: isNewHigh ? Colors.amber : Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      Text('$_score', style: const TextStyle(color: _neon, fontSize: 36, fontWeight: FontWeight.bold)),
      if (_bestCombo > 1) ...[
        const SizedBox(height: 4),
        Text('Best combo: x$_bestCombo', style: TextStyle(color: Colors.amber.withValues(alpha: 0.7), fontSize: 12)),
      ],
      const SizedBox(height: 16),
      Row(mainAxisSize: MainAxisSize.min, children: [
        _actionButton('Retry', _neon, _teal, _startGame),
        const SizedBox(width: 10),
        _actionButton('Back', Colors.transparent, Colors.white60, widget.onBack, border: true),
      ]),
    ]));
  }

  Widget _actionButton(String text, Color bg, Color fg, VoidCallback onTap, {bool border = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          border: border ? Border.all(color: Colors.white24) : null,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text, style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _BalloonPainter extends CustomPainter {
  final List<_Balloon> balloons;
  final List<_PopEffect> pops;

  _BalloonPainter({required this.balloons, required this.pops});

  @override
  void paint(Canvas canvas, Size size) {
    // Draw balloons
    for (final b in balloons) {
      if (b.popped) continue;
      final cx = b.x * size.width;
      final cy = b.y * size.height;
      final r = 18.0 * b.size;

      // Balloon body (oval)
      final balloonRect = Rect.fromCenter(center: Offset(cx, cy), width: r * 2, height: r * 2.4);
      final balloonRRect = RRect.fromRectAndRadius(balloonRect, Radius.circular(r));

      // Glow
      canvas.drawRRect(
        RRect.fromRectAndRadius(balloonRect.inflate(4), Radius.circular(r + 4)),
        Paint()..color = b.color.withValues(alpha: 0.2),
      );
      // Body
      canvas.drawRRect(balloonRRect, Paint()..color = b.color.withValues(alpha: 0.85));
      // Highlight
      canvas.drawOval(
        Rect.fromCenter(center: Offset(cx - r * 0.25, cy - r * 0.4), width: r * 0.6, height: r * 0.8),
        Paint()..color = Colors.white.withValues(alpha: 0.25),
      );
      // String
      final stringPath = Path()
        ..moveTo(cx, cy + r * 1.2)
        ..cubicTo(cx - 3, cy + r * 1.6, cx + 3, cy + r * 1.9, cx, cy + r * 2.2);
      canvas.drawPath(stringPath, Paint()
        ..color = Colors.white.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1);
      // Knot
      canvas.drawCircle(Offset(cx, cy + r * 1.2), 2, Paint()..color = b.color);
    }

    // Draw pop effects (expanding rings)
    for (final p in pops) {
      final cx = p.x * size.width;
      final cy = p.y * size.height;
      final progress = 1.0 - (p.ticksLeft / 8.0);
      final radius = 12.0 + progress * 30;
      final alpha = (1.0 - progress) * 0.6;
      canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()
          ..color = p.color.withValues(alpha: alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3 * (1.0 - progress),
      );
      // Sparkle dots
      for (int i = 0; i < 6; i++) {
        final angle = (i / 6) * 3.14159 * 2 + progress * 2;
        final sr = radius * 0.8;
        canvas.drawCircle(
          Offset(cx + cos(angle) * sr, cy + sin(angle) * sr),
          2 * (1.0 - progress),
          Paint()..color = p.color.withValues(alpha: alpha),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BalloonPainter old) => true;
}
