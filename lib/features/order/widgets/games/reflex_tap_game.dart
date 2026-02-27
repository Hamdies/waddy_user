import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sixam_mart/util/images.dart';

/// Reflex Tap Challenge — 4x4 grid, tiles light up, tap before they vanish.
/// Speed increases every 8 points. Miss 3 = game over. Combo streaks.
class ReflexTapGame extends StatefulWidget {
  final VoidCallback onBack;
  const ReflexTapGame({super.key, required this.onBack});

  @override
  State<ReflexTapGame> createState() => _ReflexTapGameState();
}

class _ReflexTapGameState extends State<ReflexTapGame> {
  static const Color _teal = Color(0xFF134E4A);
  static const Color _neon = Color(0xFF1EF2A0);
  static const Color _darkTile = Color(0xFF0D3D39);
  static const int _gridCols = 4;
  static const int _totalCells = 16;

  bool _gameStarted = false;
  bool _gameOver = false;
  int _score = 0;
  int _lives = 3;
  int _highScore = 0;
  int _combo = 0;
  int _level = 1;
  Timer? _gameTimer;
  final Random _rng = Random();

  final Map<int, int> _activeTiles = {};
  final Map<int, int> _flashTiles = {};
  final Map<int, int> _missFlashTiles = {};

  int get _tileLifeMs => max(600, 1400 - (_level - 1) * 100);
  int get _spawnIntervalMs => max(400, 900 - (_level - 1) * 60);
  int get _maxActive => min(6, 2 + (_level ~/ 3));

  @override
  void dispose() {
    _gameTimer?.cancel();
    super.dispose();
  }

  void _startGame() {
    _gameTimer?.cancel();
    setState(() {
      _gameStarted = true;
      _gameOver = false;
      _score = 0;
      _lives = 3;
      _combo = 0;
      _level = 1;
      _activeTiles.clear();
      _flashTiles.clear();
      _missFlashTiles.clear();
    });

    _gameTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted || _gameOver) return;
      final now = DateTime.now().millisecondsSinceEpoch;
      setState(() {
        final expired = <int>[];
        _activeTiles.forEach((idx, deadline) {
          if (now >= deadline) expired.add(idx);
        });
        for (final idx in expired) {
          _activeTiles.remove(idx);
          _missFlashTiles[idx] = now;
          _lives--;
          _combo = 0;
          HapticFeedback.heavyImpact();
          if (_lives <= 0) { _endGame(); return; }
        }
        if (_gameOver) return;
        _flashTiles.removeWhere((_, t) => now - t > 300);
        _missFlashTiles.removeWhere((_, t) => now - t > 400);
        if (_activeTiles.length < _maxActive &&
            _rng.nextInt(1000) < (1000 * 50 / _spawnIntervalMs).round()) {
          final available = List.generate(_totalCells, (i) => i)
            ..removeWhere((i) => _activeTiles.containsKey(i));
          if (available.isNotEmpty) {
            _activeTiles[available[_rng.nextInt(available.length)]] = now + _tileLifeMs;
          }
        }
        _level = 1 + _score ~/ 8;
      });
    });
  }

  void _tapTile(int index) {
    if (!_activeTiles.containsKey(index)) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    HapticFeedback.lightImpact();
    setState(() {
      _activeTiles.remove(index);
      _flashTiles[index] = now;
      _combo++;
      _score += 1 + (_combo ~/ 5);
    });
  }

  void _endGame() {
    _gameTimer?.cancel();
    if (_score > _highScore) _highScore = _score;
    setState(() {
      _gameOver = true;
      _activeTiles.clear();
      _flashTiles.clear();
      _missFlashTiles.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_gameStarted) return _buildStart();
    if (_gameOver) return _buildGameOver();
    return _buildGrid();
  }

  Widget _buildStart() {
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 52, height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _neon.withValues(alpha: 0.15),
          border: Border.all(color: _neon.withValues(alpha: 0.3), width: 2),
        ),
        child: const Icon(Icons.bolt, color: _neon, size: 28),
      ),
      const SizedBox(height: 12),
      const Text('Reflex Tap', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      Text('Tap lit tiles before they vanish!', style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 12)),
      const SizedBox(height: 2),
      Text('Speed increases every level', style: TextStyle(color: Colors.white.withValues(alpha: 0.35), fontSize: 11)),
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

  Widget _buildGrid() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(children: [
        // HUD
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            // Lives
            Row(mainAxisSize: MainAxisSize.min, children: List.generate(3, (i) => Padding(
              padding: const EdgeInsets.only(right: 3),
              child: Icon(i < _lives ? Icons.favorite : Icons.favorite_border,
                color: i < _lives ? Colors.redAccent : Colors.white24, size: 14),
            ))),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
              child: Text('LVL $_level', style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(width: 6),
            if (_combo >= 3)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.local_fire_department, color: Colors.orange, size: 12),
                  const SizedBox(width: 2),
                  Text('${_combo}x', style: const TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
                ]),
              ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _neon.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(6)),
              child: Text('$_score', style: const TextStyle(color: _neon, fontSize: 13, fontWeight: FontWeight.bold)),
            ),
          ]),
        ),
        // Level progress
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: LinearProgressIndicator(
            value: (_score % 8) / 8,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation<Color>(_neon.withValues(alpha: 0.5)),
            minHeight: 3,
          ),
        ),
        const SizedBox(height: 6),
        // Grid
        Expanded(child: GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: _gridCols, mainAxisSpacing: 6, crossAxisSpacing: 6,
          ),
          itemCount: _totalCells,
          itemBuilder: (context, index) {
            final bool isActive = _activeTiles.containsKey(index);
            final bool isFlash = _flashTiles.containsKey(index);
            final bool isMissFlash = _missFlashTiles.containsKey(index);
            double timeFraction = 1.0;
            if (isActive) {
              final remaining = _activeTiles[index]! - now;
              timeFraction = (remaining / _tileLifeMs).clamp(0.0, 1.0);
            }
            Color tileColor;
            if (isMissFlash) {
              tileColor = Colors.red.withValues(alpha: 0.5);
            } else if (isFlash) {
              tileColor = _neon.withValues(alpha: 0.4);
            } else if (isActive) {
              tileColor = timeFraction > 0.3
                  ? _neon.withValues(alpha: 0.2 + timeFraction * 0.5)
                  : Colors.orange.withValues(alpha: 0.4 + (1 - timeFraction) * 0.3);
            } else {
              tileColor = _darkTile;
            }
            return GestureDetector(
              onTap: isActive ? () => _tapTile(index) : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                decoration: BoxDecoration(
                  color: tileColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isActive
                        ? (timeFraction > 0.3 ? _neon.withValues(alpha: 0.6) : Colors.orange.withValues(alpha: 0.7))
                        : Colors.white.withValues(alpha: 0.05),
                    width: isActive ? 1.5 : 0.5,
                  ),
                  boxShadow: isActive
                      ? [BoxShadow(color: (timeFraction > 0.3 ? _neon : Colors.orange).withValues(alpha: 0.3), blurRadius: 8)]
                      : null,
                ),
                child: isActive
                    ? Center(child: Image.asset(Images.scratchCardLogo, width: 24, height: 24,
                        opacity: AlwaysStoppedAnimation(timeFraction.clamp(0.4, 1.0))))
                    : null,
              ),
            );
          },
        )),
      ]),
    );
  }

  Widget _buildGameOver() {
    final bool isNewHigh = _score >= _highScore && _score > 0;
    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(isNewHigh ? Icons.emoji_events : Icons.bolt, color: isNewHigh ? Colors.amber : _neon, size: 38),
      const SizedBox(height: 8),
      Text(isNewHigh ? 'New Record!' : 'Game Over!', style: TextStyle(color: isNewHigh ? Colors.amber : Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
      const SizedBox(height: 6),
      Text('$_score', style: const TextStyle(color: _neon, fontSize: 36, fontWeight: FontWeight.bold)),
      Text('Level $_level reached', style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
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
