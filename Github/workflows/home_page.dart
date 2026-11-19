import 'dart:async';
import 'dart:math';
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import '../../core/util.dart';
import '../../core/widgets.dart';
import '../ai/ai_summary_page.dart';
import '../connect/proxy_service.dart';
import '../games/game_center_page.dart';
import '../news/article_page.dart';
import '../news/news_models.dart';
import '../news/news_page.dart';
import '../news/news_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  final Set<String> _dismissed = {};

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  List<Article> get _notes => newsService.articles.where((a) => !a.read && !_dismissed.contains(a.id)).take(4).toList();

  void _go(Widget w) => Navigator.push(context, MaterialPageRoute(builder: (_) => w));

  @override
  Widget build(BuildContext context) {
    final bg = Theme.of(context).scaffoldBackgroundColor;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [bg, Color.lerp(bg, Colors.blueGrey, 0.22)!]),
        ),
        child: SafeArea(
          child: ListenableBuilder(
            listenable: newsService,
            builder: (context, _) => Column(
              children: [
                _adHeader(context),
                _notifications(context),
                Expanded(child: Center(child: ConnectButton(anim: _anim))),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      MetalCircle(icon: Icons.forum_rounded, label: 'MESSENGER', onTap: () => _go(const NewsPage())),
                      MetalCircle(icon: Icons.auto_fix_high, label: 'AI SUMMARY', onTap: () => _go(const AiSummaryPage())),
                      MetalCircle(icon: Icons.sports_esports, label: 'GAME CENTER', onTap: () => _go(const GameCenterPage())),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _adHeader(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      height: 50,
      alignment: Alignment.center,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: accent.withOpacity(0.35))),
      child: const Text('فضای تبلیغات', style: TextStyle(fontSize: 12, color: Colors.white54)),
    );
  }

  Widget _notifications(BuildContext context) {
    final notes = _notes;
    if (notes.isEmpty) {
      return const SizedBox(height: 56, child: Center(child: Text('اعلان جدیدی نیست', style: TextStyle(fontSize: 12, color: Colors.white38))));
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(child: Text('اعلان‌ها', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13))),
              TextButton(
                onPressed: () {
                  final ids = notes.map((e) => e.id).toList();
                  setState(() => _dismissed.addAll(ids));
                },
                child: const Text('پاک‌کردن همه'),
              ),
            ],
          ),
          for (var i = 0; i < notes.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Dismissible(
                key: ValueKey(notes[i].id),
                direction: DismissDirection.horizontal,
                onDismissed: (_) {
                  final id = notes[i].id;
                  setState(() => _dismissed.add(id));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text('اعلان حذف شد'),
                    action: SnackBarAction(label: 'بازگردانی', onPressed: () => setState(() => _dismissed.remove(id))),
                  ));
                },
                child: AnimatedBuilder(
                  animation: _anim,
                  builder: (c, child) => Transform.translate(offset: Offset(0, sin(_anim.value * 2 * pi + i) * 3), child: child),
                  child: GlassCapsule(
                    onTap: () => _go(ArticlePage(notes[i])),
                    child: Row(
                      children: [
                        Icon(Icons.bolt, size: 18, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(child: Text(notes[i].title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ConnectButton extends StatefulWidget {
  final Animation<double> anim;
  const ConnectButton({super.key, required this.anim});
  @override
  State<ConnectButton> createState() => _ConnectButtonState();
}

class _ConnectButtonState extends State<ConnectButton> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && proxyService.state == ConnState.connected) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _askSource() async {
    final c = TextEditingController();
    final v = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('منبع پروکسی'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('آدرس فایل متنی یا JSON (مثلاً raw گیت‌هاب) که لینک پروکسی‌های تلگرام را دارد وارد کنید.', style: TextStyle(fontSize: 12)),
            TextField(controller: c, textDirection: TextDirection.ltr, decoration: const InputDecoration(hintText: 'https://raw.githubusercontent.com/...')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('لغو')),
          FilledButton(onPressed: () => Navigator.pop(ctx, c.text), child: const Text('افزودن')),
        ],
      ),
    );
    if (v != null) await proxyService.addSource(v);
  }

  Future<void> _tap() async {
    if (proxyService.state == ConnState.connected) {
      proxyService.disconnect();
      return;
    }
    if (proxyService.state == ConnState.searching) return;
    if (proxyService.sources.isEmpty) {
      await _askSource();
      if (proxyService.sources.isEmpty) return;
    }
    await proxyService.connect();
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return ListenableBuilder(
      listenable: proxyService,
      builder: (context, _) {
        final connected = proxyService.state == ConnState.connected;
        final searching = proxyService.state == ConnState.searching;
        var elapsed = '00:00:00';
        if (connected && proxyService.connectedAt != null) {
          final d = DateTime.now().difference(proxyService.connectedAt!);
          elapsed = '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: widget.anim,
              builder: (c, _) {
                final p = connected ? widget.anim.value : 0.0;
                return SizedBox(
                  width: 240,
                  height: 240,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (connected)
                        Container(
                          width: 180 + p * 56,
                          height: 180 + p * 56,
                          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: accent.withOpacity((1 - p) * 0.6), width: 3)),
                        ),
                      GestureDetector(
                        onTap: _tap,
                        child: Container(
                          width: 176,
                          height: 176,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: connected
                                ? RadialGradient(center: const Alignment(-0.3, -0.4), colors: [accent.withOpacity(0.9), const Color(0xFF0B6B3A)])
                                : const RadialGradient(center: Alignment(-0.3, -0.4), colors: [Color(0xFFF1F3F5), Color(0xFF8E959B), Color(0xFF30353A)]),
                            border: Border.all(color: accent.withOpacity(connected ? 1 : 0.6), width: 3),
                            boxShadow: [BoxShadow(color: accent.withOpacity(connected ? 0.6 : 0.25), blurRadius: connected ? 36 : 18, spreadRadius: 2)],
                          ),
                          child: Center(
                            child: searching
                                ? const CircularProgressIndicator(color: Colors.black87)
                                : Text(connected ? 'CONNECTED' : 'CONNECT', style: TextStyle(fontSize: connected ? 17 : 24, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: connected ? Colors.white : const Color(0xFF1B1E21))),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(proxyService.status, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: Colors.white70)),
            ),
            const SizedBox(height: 4),
            Text(elapsed, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: connected ? accent : Colors.white38, fontFeatures: const [FontFeature.tabularFigures()])),
          ],
        );
      },
    );
  }
}
