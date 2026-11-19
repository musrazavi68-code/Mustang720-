import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../../core/store.dart';
import 'pixel_utils.dart';

class _Obs {
  final String type; // mine | ship | carrier | camel
  double x;
  final double w, h;
  bool dying = false;
  double flash = 0;
  bool dead = false;
  _Obs(this.type, this.x, this.w, this.h);
}

class _Coin {
  double x, y;
  _Coin(this.x, this.y);
}

class _Particle {
  double x, y, vx, vy, life;
  Color color;
  _Particle(this.x, this.y, this.vx, this.vy, this.life, this.color);
}

/// منطق بازی (مختصات مجازی؛ ارتفاع‌ها نسبت به زمین)
class HormozGame {
  final rnd = Random();
  double W = 400, H = 240;
  String state = 'play'; // play | over | won
  double time = 0, scroll = 0, dist = 0;
  double health = 100;
  int coinCount = 0;
  int level = 1;
  double px = 56, py = 0, vy = 0;
  double hurt = 0, attackT = 0, attackCd = 0, bubbleT = 0;
  String bubble = '';
  final List<_Obs> obs = [];
  final List<_Coin> coins = [];
  final List<_Particle> parts = [];
  double nextSpawn = 240;
  int spawnCount = 0;
  bool tutorialDone = false, showHint = false;

  int get score => (dist / 8).floor() + coinCount * 10;

  void reset() {
    state = 'play';
    time = 0;
    scroll = 0;
    dist = 0;
    health = 100;
    coinCount = 0;
    level = 1;
    py = 0;
    vy = 0;
    hurt = 0;
    attackT = 0;
    attackCd = 0;
    bubbleT = 0;
    obs.clear();
    coins.clear();
    parts.clear();
    nextSpawn = 240;
    spawnCount = 0;
    showHint = false;
  }

  void jump() {
    if (state == 'play' && py <= 0.01) vy = 430;
  }

  void attack() {
    if (state != 'play' || attackCd > 0) return;
    attackT = 0.28;
    attackCd = 0.45;
  }

  void _damage() {
    health -= 25;
    hurt = 1.2;
    bubble = 'این بار گرزِ رستم کم آورد!';
    bubbleT = 1.4;
    if (health <= 0) {
      health = 0;
      state = 'over';
      bubble = 'دریغا! این بار گرز هم یاری نکرد!';
      bubbleT = 3;
    }
  }

  void _spawn() {
    spawnCount++;
    String type;
    final r = rnd.nextDouble();
    if (!tutorialDone && spawnCount == 4) {
      type = 'ship';
    } else if (level < 3) {
      type = r < 0.8 ? 'mine' : 'ship';
    } else if (level < 8) {
      type = r < 0.5 ? 'mine' : (r < 0.8 ? 'ship' : 'camel');
    } else {
      type = r < 0.35 ? 'mine' : (r < 0.6 ? 'ship' : (r < 0.8 ? 'camel' : 'carrier'));
    }
    switch (type) {
      case 'mine':
        obs.add(_Obs(type, W + 30, 16, 16));
        break;
      case 'ship':
        obs.add(_Obs(type, W + 30, 58, 34));
        break;
      case 'carrier':
        obs.add(_Obs(type, W + 30, 92, 44));
        break;
      default:
        obs.add(_Obs(type, W + 30, 34, 44));
    }
  }

  void _explode(_Obs o) {
    final cx = o.x + o.w / 2;
    const cols = [Color(0xFFFFC107), Color(0xFFFF5722), Color(0xFFE53935), Color(0xFFFFFFFF)];
    for (var i = 0; i < 16; i++) {
      final a = rnd.nextDouble() * 2 * pi;
      final sp = 40 + rnd.nextDouble() * 120;
      parts.add(_Particle(cx, o.h / 2, cos(a) * sp, sin(a).abs() * sp, 0.5 + rnd.nextDouble() * 0.3, cols[rnd.nextInt(cols.length)]));
    }
    final n = o.type == 'camel' ? 2 : 1;
    for (var i = 0; i < n; i++) {
      coins.add(_Coin(cx + i * 18, 40 + i * 6));
    }
  }

  void update(double dt) {
    if (state != 'play') return;
    time += dt;
    level = min(72, 1 + (time / 10).floor());
    if (time >= 71 * 10) {
      state = 'won';
      return;
    }
    final speed = 190 + level * 4.0;
    scroll += speed * dt;
    dist += speed * dt;

    // فیزیک پرش
    if (py > 0 || vy > 0) {
      py += vy * dt;
      vy -= 1500 * dt;
      if (py <= 0) {
        py = 0;
        vy = 0;
      }
    }
    if (attackT > 0) attackT -= dt;
    if (attackCd > 0) attackCd -= dt;
    if (hurt > 0) hurt -= dt;
    if (bubbleT > 0) bubbleT -= dt;

    // تولید مانع
    nextSpawn -= speed * dt;
    if (nextSpawn <= 0) {
      _spawn();
      final minGap = max(150.0, 250.0 - level * 1.6);
      nextSpawn = minGap + rnd.nextDouble() * 160;
    }

    for (final o in obs) {
      o.x -= speed * dt;
      if (o.dying) {
        o.flash -= dt;
        if (o.flash <= 0) {
          _explode(o);
          o.dead = true;
        }
        continue;
      }
      // ضربهٔ گرز
      if (attackT > 0 && o.type != 'mine') {
        if (o.x < px + 90 && o.x + o.w > px + 30) {
          o.dying = true;
          o.flash = 0.25;
          if (!tutorialDone) {
            tutorialDone = true;
            Prefs.setBool('hormoz_tut', true);
          }
          continue;
        }
      }
      // برخورد با رستم
      if (px + 40 > o.x + 2 && px + 8 < o.x + o.w - 2 && py < o.h - 2) {
        if (hurt <= 0) _damage();
        o.dead = true;
      }
      if (o.x + o.w < -20) o.dead = true;
    }
    obs.removeWhere((o) => o.dead);

    // سکه‌ها
    for (final c in coins) {
      c.x -= speed * dt;
      if ((c.x - (px + 24)).abs() < 28 && (c.y - (py + 24)).abs() < 40) {
        coinCount++;
        c.x = -999;
      }
    }
    coins.removeWhere((c) => c.x < -20);

    for (final p in parts) {
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.vy -= 300 * dt;
      p.life -= dt;
    }
    parts.removeWhere((p) => p.life <= 0);

    showHint = !tutorialDone && obs.any((o) => o.type == 'ship' && !o.dying && o.x < W - 20 && o.x > px + 30);
  }
}

class HormozPage extends StatefulWidget {
  const HormozPage({super.key});
  @override
  State<HormozPage> createState() => _HormozPageState();
}

class _HormozPageState extends State<HormozPage> with SingleTickerProviderStateMixin {
  final g = HormozGame();
  late final Ticker _ticker;
  final ValueNotifier<int> _frame = ValueNotifier(0);
  Duration _last = Duration.zero;
  String _lastState = 'play';
  bool _lastHint = false;

  @override
  void initState() {
    super.initState();
    Prefs.getBool('hormoz_tut').then((v) => g.tutorialDone = v);
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _tick(Duration d) {
    final dt = min(0.033, (d - _last).inMicroseconds / 1e6);
    _last = d;
    g.update(dt);
    _frame.value++;
    if (g.state != _lastState || g.showHint != _lastHint) {
      _lastState = g.state;
      _lastHint = g.showHint;
      setState(() {});
      if (g.state != 'play') _finish();
    }
  }

  Future<void> _finish() async {
    _ticker.stop();
    final best = await Prefs.getInt('rec_hormoz');
    if (g.score > best) await Prefs.setInt('rec_hormoz', g.score);
    await Prefs.setInt('coins', await Prefs.getInt('coins') + g.coinCount);
    final bl = await Prefs.getInt('hormoz_best_level');
    if (g.level > bl) await Prefs.setInt('hormoz_best_level', g.level);
  }

  void _restart() {
    g.reset();
    _last = Duration.zero;
    _lastState = 'play';
    _lastHint = false;
    _ticker.start();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => g.jump(),
              child: CustomPaint(painter: HormozPainter(g, _frame)),
            ),
          ),
          Positioned(
            left: 8,
            bottom: 8,
            child: SafeArea(child: IconButton(icon: const Icon(Icons.close, color: Colors.white70), onPressed: () => Navigator.pop(context))),
          ),
          Positioned(
            right: 22,
            bottom: 22,
            child: SafeArea(
              child: GestureDetector(
                onTapDown: (_) => g.attack(),
                child: Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(colors: [Color(0xFFFFE082), Color(0xFFFF8F00)]),
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                  child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.gavel, size: 32, color: Color(0xFF3E2723)),
                    Text('گرز', style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF3E2723))),
                  ]),
                ),
              ),
            ),
          ),
          if (g.showHint)
            Positioned(
              right: 14,
              bottom: 124,
              child: SafeArea(
                child: Container(
                  width: 190,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                  child: const Column(mainAxisSize: MainAxisSize.min, children: [
                    Text('برای نابودی ناو، به‌موقع دکمه گرز را لمس کن!', textAlign: TextAlign.center, style: TextStyle(color: Colors.black, fontWeight: FontWeight.w800, fontSize: 13)),
                    Icon(Icons.touch_app, color: Colors.deepOrange, size: 30),
                  ]),
                ),
              ),
            ),
          if (g.state == 'over') _overlay('بازی تمام شد', 'دریغا! این بار گرز هم یاری نکرد!', 'مرحله ${g.level} • امتیاز ${g.score} • سکه ${g.coinCount}'),
          if (g.state == 'won') _overlay('چو ایران نباشد تن من مباد', 'در این بوم و بر زنده یک تن مباد', 'پایان هرمزنامه\nامتیاز ${g.score}'),
        ],
      ),
    );
  }

  Widget _overlay(String title, String sub, String info) {
    return Positioned.fill(
      child: Container(
        color: Colors.black87,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.amber)),
              const SizedBox(height: 8),
              Text(sub, style: const TextStyle(color: Colors.white70, fontSize: 15)),
              const SizedBox(height: 16),
              Text(info, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16, height: 1.8)),
              const SizedBox(height: 20),
              FilledButton(onPressed: _restart, child: const Text('شروع دوباره')),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('خروج')),
            ],
          ),
        ),
      ),
    );
  }
}

class HormozPainter extends CustomPainter {
  final HormozGame g;
  HormozPainter(this.g, Listenable repaint) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    final s = min(size.width / 400, size.height / 240);
    g.W = size.width / s;
    g.H = size.height / s;
    final W = g.W, H = g.H;
    final gy = H * 0.79; // خط زمین
    canvas.save();
    canvas.scale(s);
    final p = Paint()..isAntiAlias = false;
    void r(double x, double y, double w, double h, Color c) {
      p.color = c;
      canvas.drawRect(Rect.fromLTWH(x, y, w, h), p);
    }

    // آسمان، دریا، ساحل
    r(0, 0, W, H * 0.46, const Color(0xFF40C8D8));
    r(0, H * 0.46, W, H * 0.165, const Color(0xFF1FB5A5));
    r(0, H * 0.625, W, gy - H * 0.625, const Color(0xFFF2C14E));
    r(0, gy - (gy - H * 0.625) * 0.35, W, (gy - H * 0.625) * 0.35, const Color(0xFFF08A4B));
    r(0, gy, W, H - gy, const Color(0xFFC8553D));

    // ابرها (لایهٔ دور)
    for (var k = 0; k < 5; k++) {
      final x = (k * 150.0 - g.scroll * 0.05) % (W + 100) - 50;
      final y = H * 0.08 + (k % 3) * 16.0;
      r(x, y + 6, 44, 8, Colors.white);
      r(x + 8, y, 26, 8, Colors.white);
    }
    // امواج
    for (var row = 0; row < 3; row++) {
      for (var k = 0; k < 7; k++) {
        final x = (k * 70.0 - g.scroll * 0.3 + row * 23) % (W + 60) - 30;
        r(x, H * 0.49 + row * 12.0, 18, 2, const Color(0xFF8FE9DD));
      }
    }
    // صخره‌ها
    for (var k = 0; k < 4; k++) {
      final x = (k * 210.0 - g.scroll * 0.6) % (W + 100) - 50;
      r(x, H * 0.625 - 8, 28, 10, const Color(0xFF7B5E57));
      r(x + 5, H * 0.625 - 14, 16, 8, const Color(0xFF8D6E63));
    }
    // نخل‌ها
    for (var k = 0; k < 3; k++) {
      final x = (k * 260.0 + 40 - g.scroll * 0.8) % (W + 120) - 60;
      final top = H * 0.625 - 52;
      r(x + 10, top + 8, 6, 52, const Color(0xFF8B5A2B));
      r(x - 10, top + 2, 38, 6, const Color(0xFF2E7D32));
      r(x - 2, top - 4, 22, 6, const Color(0xFF388E3C));
    }
    // خطوط زمین
    for (var k = 0; k < 12; k++) {
      final x = (k * 46.0 - g.scroll) % (W + 40) - 20;
      r(x, gy + 10, 16, 3, const Color(0xFFA83F2D));
      r(x + 20, gy + 26, 12, 3, const Color(0xFFA83F2D));
    }

    // مانع‌ها
    for (final o in g.obs) {
      final blink = o.dying && (g.time * 24).floor() % 2 == 0;
      Color c(Color base) => blink ? const Color(0xFFE53935) : base;
      final x = o.x;
      switch (o.type) {
        case 'mine':
          r(x + 2, gy - 12, 12, 10, c(const Color(0xFF263238)));
          r(x, gy - 8, 16, 2, c(const Color(0xFF263238)));
          r(x + 6, gy - 16, 4, 4, c(const Color(0xFF263238)));
          r(x + 6, gy - 9, 4, 3, const Color(0xFFE53935));
          break;
        case 'ship':
          r(x, gy - 14, o.w, 14, c(const Color(0xFF78909C)));
          r(x + 8, gy - 24, o.w - 24, 10, c(const Color(0xFFB0BEC5)));
          r(x + o.w * 0.4, gy - 34, 14, 10, c(Colors.white));
          r(x + o.w * 0.4 + 6, gy - 44, 2, 10, c(const Color(0xFF546E7A)));
          r(x + o.w - 14, gy - 22, 12, 3, c(const Color(0xFF37474F)));
          break;
        case 'carrier':
          r(x, gy - 16, o.w, 16, c(const Color(0xFF607D8B)));
          r(x - 4, gy - 24, o.w + 8, 8, c(const Color(0xFF455A64)));
          r(x + 8, gy - 21, o.w - 16, 1, c(Colors.white));
          r(x + o.w * 0.65, gy - 42, 16, 18, c(const Color(0xFF90A4AE)));
          r(x + 10, gy - 30, 12, 3, c(const Color(0xFFCFD8DC)));
          break;
        default: // شترسوار
          r(x + 4, gy - 26, 26, 12, c(const Color(0xFFC9A66B)));
          r(x + 10, gy - 32, 8, 6, c(const Color(0xFFC9A66B)));
          r(x + 26, gy - 38, 5, 14, c(const Color(0xFFC9A66B)));
          r(x + 28, gy - 42, 10, 6, c(const Color(0xFFC9A66B)));
          for (final lx in [6.0, 14.0, 22.0, 28.0]) {
            r(x + lx, gy - 14, 3, 14, c(const Color(0xFFB08D57)));
          }
          r(x + 12, gy - 44, 8, 12, c(const Color(0xFF5D4037)));
          r(x + 13, gy - 50, 6, 6, c(const Color(0xFFF2C29B)));
          r(x + 2, gy - 56, 3, 14, c(const Color(0xFF8D6E63)));
      }
    }

    // سکه‌ها
    for (final cn in g.coins) {
      final bob = sin(g.time * 6 + cn.x * 0.05) * 3;
      final w = 6 + 4 * (0.5 + 0.5 * sin(g.time * 8)).abs();
      r(cn.x - w / 2, gy - cn.y - 6 + bob, w, 12, const Color(0xFFFFC107));
      r(cn.x - w / 2 + 1, gy - cn.y - 4 + bob, max(1.0, w - 2), 8, const Color(0xFFFFE082));
    }

    // رستم و اسب
    final by = gy - g.py;
    final blinkHide = g.hurt > 0 && (g.time * 20).floor() % 2 == 0;
    if (!blinkHide) {
      final px = g.px;
      const brown = Color(0xFF8B5A2B), dark = Color(0xFF4E3318);
      final frame = g.py > 0 ? 2 : (g.time * 10).floor() % 2;
      r(px, by - 30, 36, 14, brown);
      r(px + 30, by - 42, 8, 14, brown);
      r(px + 34, by - 44, 12, 8, brown);
      r(px + 28, by - 42, 3, 12, dark);
      r(px - 6, by - 30, 6, 4, dark);
      r(px - 8, by - 26, 4, 8, dark);
      for (final lx in [2.0, 8.0, 26.0, 32.0]) {
        if (frame == 2) {
          r(px + lx, by - 16, 4, 8, dark);
        } else {
          final sh = (frame == 0 ? 1 : -1) * (lx < 15 ? -3 : 3);
          r(px + lx + sh, by - 16, 4, 16, dark);
        }
      }
      final falling = g.hurt > 0.6;
      if (!falling) {
        r(px + 12, by - 50, 10, 14, const Color(0xFFC62828));
        r(px + 13, by - 60, 8, 8, const Color(0xFFF2C29B));
        r(px + 12, by - 63, 10, 4, const Color(0xFFFFC107));
        r(px + 20, by - 48, 10, 4, const Color(0xFFC62828));
        if (g.attackT > 0) {
          r(px + 28, by - 50, 22, 3, const Color(0xFF9E9E9E));
          r(px + 48, by - 56, 10, 12, const Color(0xFF616161));
        } else {
          r(px + 24, by - 70, 3, 22, const Color(0xFF9E9E9E));
          r(px + 21, by - 76, 9, 9, const Color(0xFF616161));
        }
      } else {
        r(px - 14, by - 12, 22, 8, const Color(0xFFC62828));
        r(px + 8, by - 14, 8, 8, const Color(0xFFF2C29B));
      }
      if (g.bubbleT > 0) drawBubble(canvas, g.bubble, Offset(px + 20, by - 90), 11);
    }

    // ذرات انفجار
    for (final q in g.parts) {
      r(q.x, gy - q.y, 4, 4, q.color);
    }

    // HUD
    r(10, 8, 104, 12, Colors.black54);
    final hc = g.health > 50 ? const Color(0xFF43A047) : (g.health > 25 ? const Color(0xFFFFA000) : const Color(0xFFE53935));
    r(12, 10, g.health, 8, hc);
    drawText(canvas, 'جان', const Offset(118, 6), 11, Colors.white);
    drawText(canvas, 'مرحله ${g.level}', Offset(W / 2, 6), 13, Colors.white, align: TextAlign.center);
    drawText(canvas, 'امتیاز ${g.score}', Offset(W - 10, 6), 12, Colors.white, align: TextAlign.right);
    drawText(canvas, 'سکه ${g.coinCount}', Offset(W - 10, 22), 12, const Color(0xFFFFE082), align: TextAlign.right);

    if (g.hurt > 0) {
      r(0, 0, W, H, Colors.red.withOpacity(0.22 * (g.hurt / 1.2)));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant HormozPainter old) => true;
}
