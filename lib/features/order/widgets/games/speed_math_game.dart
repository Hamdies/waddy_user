import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Snake Game — swipe to change direction, eat food to grow.
/// Hit walls or yourself = game over. Classic hypercasual.
class SnakeGame extends StatefulWidget {
  final VoidCallback onBack;
  const SnakeGame({super.key, required this.onBack});

  @override
  State<SnakeGame> createState() => _SnakeGameState();
}

enum _Dir { up, down, left, right }

class _SnakeGameState extends State<SnakeGame> {
  static const Color _teal = Color(0xFF134E4A);
  static const Color _neon = Color(0xFF1EF2A0);

  static const int _gridW = 16;
  static const int _gridH = 16;

  final Random _rng = Random();
  Timer? _ticker;
  bool _gameStarted = false;
  bool _gameOver = false;
  int _score = 0;
  int _highScore = 0;

  List<Point<int>> _snake = [];
  Point<int> _food = const Point(0, 0);
  _Dir _dir = _Dir.right;
  _Dir _nextDir = _Dir.right;
  int _baseSpeedMs = 160;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startGame() {
    _ticker?.cancel();
    final int midX = _gridW ~/ 2;
    final int midY = _gridH ~/ 2;
    setState(() {
      _gameStarted = true;
      _gameOver = false;
      _score = 0;
      _dir = _Dir.right;
      _nextDir = _Dir.right;
      _baseSpeedMs = 160;
      _snake = [
        Point(midX - 2, midY),
        Point(midX - 1, midY),
        Point(midX, midY),
      ];
    });
    _spawnFood();
    _startTicker();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(Duration(milliseconds: _baseSpeedMs), (_) => _step());
  }

  void _spawnFood() {
    final Set<Point<int>> occupied = _snake.toSet();
    final List<Point<int>> free = [];
    for (int x = 0; x < _gridW; x++) {
      for (int y = 0; y < _gridH; y++) {
        final p = Point(x, y);
        if (!occupied.contains(p)) free.add(p);
      }
    }
    if (free.isEmpty) return;
    setState(() => _food = free[_rng.nextInt(free.length)]);
  }

  void _step() {
    if (!mounted || _gameOver) return;

    _dir = _nextDir;
    final head = _snake.last;
    Point<int> newHead;
    switch (_dir) {
      case _Dir.up:    newHead = Point(head.x, head.y - 1); break;
      case _Dir.down:  newHead = Point(head.x, head.y + 1); break;
      case _Dir.left:  newHead = Point(head.x - 1, head.y); break;
      case _Dir.right: newHead = Point(head.x + 1, head.y); break;
    }

    // Wall collision
    if (newHead.x < 0 || newHead.x >= _gridW || newHead.y < 0 || newHead.y >= _gridH) {
      _endGame();
      return;
    }
    // Self collision
    if (_snake.contains(newHead)) {
      _endGame();
      return;
    }

    setState(() {
      _snake.add(newHead);
      if (newHead == _food) {
        _score++;
        HapticFeedback.selectionClick();
        _spawnFood();
        // Speed up every 4 food
        if (_score % 4 == 0 && _baseSpeedMs > 80) {
          _baseSpeedMs -= 12;
          _startTicker();
        }
      } else {
        _snake.removeAt(0);
      }
    });
  }

  void _changeDir(_Dir newDir) {
    // Prevent 180° reversal
    if (_dir == _Dir.up && newDir == _Dir.down) return;
    if (_dir == _Dir.down && newDir == _Dir.up) return;
    if (_dir == _Dir.left && newDir == _Dir.right) return;
    if (_dir == _Dir.right && newDir == _Dir.left) return;
    _nextDir = newDir;
  }

  void _endGame() {
    _ticker?.cancel();
    HapticFeedback.heavyImpact();
    if (_score > _highScore) _highScore = _score;
    setState(() => _gameOver = true);
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
          color: Colors.green.withValues(alpha: 0.15),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3), width: 2),
        ),
        child: const Icon(Icons.pest_control, color: Colors.green, size: 28),
      ),
      const SizedBox(height: 12),
      const Text('Snake', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      Text('Swipe to move — eat to grow!', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
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
    return GestureDetector(
      onVerticalDragUpdate: (d) {
        if (d.delta.dy < -4) _changeDir(_Dir.up);
        if (d.delta.dy > 4) _changeDir(_Dir.down);
      },
      onHorizontalDragUpdate: (d) {
        if (d.delta.dx < -4) _changeDir(_Dir.left);
        if (d.delta.dx > 4) _changeDir(_Dir.right);
      },
      behavior: HitTestBehavior.opaque,
      child: Stack(children: [
        // Game grid
        Positioned.fill(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 28, 8, 8),
            child: CustomPaint(painter: _SnakePainter(
              snake: _snake, food: _food,
              gridW: _gridW, gridH: _gridH, neon: _neon,
            )),
          ),
        ),
        // HUD
        Positioned(
          top: 6, left: 14, right: 14,
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _neon.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
              child: Text('$_score', style: const TextStyle(color: _neon, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
            const Spacer(),
            Text('SWIPE', style: TextStyle(color: Colors.white.withValues(alpha: 0.25), fontSize: 11, fontWeight: FontWeight.bold)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildGameOver() {
    final bool isNewHigh = _score >= _highScore && _score > 0;
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(isNewHigh ? Icons.emoji_events : Icons.pest_control, color: isNewHigh ? Colors.amber : Colors.green, size: 38),
      const SizedBox(height: 8),
      Text(isNewHigh ? 'New Record!' : 'Game Over!', style: TextStyle(color: isNewHigh ? Colors.amber : Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      Text('$_score', style: const TextStyle(color: _neon, fontSize: 36, fontWeight: FontWeight.bold)),
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

class _SnakePainter extends CustomPainter {
  final List<Point<int>> snake;
  final Point<int> food;
  final int gridW, gridH;
  final Color neon;

  _SnakePainter({
    required this.snake, required this.food,
    required this.gridW, required this.gridH, required this.neon,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double cellW = size.width / gridW;
    final double cellH = size.height / gridH;
    final double cellSize = min(cellW, cellH);
    final double offsetX = (size.width - cellSize * gridW) / 2;
    final double offsetY = (size.height - cellSize * gridH) / 2;

    // Grid border
    final gridRect = Rect.fromLTWH(offsetX, offsetY, cellSize * gridW, cellSize * gridH);
    canvas.drawRRect(
      RRect.fromRectAndRadius(gridRect, const Radius.circular(6)),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.06)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Food glow + food
    final fx = offsetX + food.x * cellSize + cellSize / 2;
    final fy = offsetY + food.y * cellSize + cellSize / 2;
    canvas.drawCircle(Offset(fx, fy), cellSize * 0.8, Paint()..color = Colors.redAccent.withValues(alpha: 0.2));
    canvas.drawCircle(Offset(fx, fy), cellSize * 0.35, Paint()..color = Colors.redAccent);

    // Snake
    for (int i = 0; i < snake.length; i++) {
      final p = snake[i];
      final bool isHead = i == snake.length - 1;
      final double sx = offsetX + p.x * cellSize;
      final double sy = offsetY + p.y * cellSize;
      final double inset = cellSize * 0.08;
      final rect = Rect.fromLTWH(sx + inset, sy + inset, cellSize - inset * 2, cellSize - inset * 2);

      if (isHead) {
        // Head glow
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect.inflate(2), const Radius.circular(5)),
          Paint()..color = neon.withValues(alpha: 0.3),
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          Paint()..color = neon,
        );
      } else {
        final alpha = 0.4 + 0.5 * (i / snake.length);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)),
          Paint()..color = neon.withValues(alpha: alpha),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SnakePainter old) => true;
}
