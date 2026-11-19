import 'package:flutter/material.dart';
import '../../core/store.dart';
import 'hormoz_game.dart';
import 'shahed_game.dart';
import 'sudoku_page.dart';
import 'trivia_page.dart';

class GameCenterPage extends StatefulWidget {
  const GameCenterPage({super.key});
  @override
  State<GameCenterPage> createState() => _GameCenterPageState();
}

class _GameCenterPageState extends State<GameCenterPage> {
  Map<String, int> _rec = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = <String, int>{};
    for (final k in ['rec_hormoz', 'rec_shahed', 'sudoku_wins', 'trivia_score', 'coins']) {
      m[k] = await Prefs.getInt(k);
    }
    if (mounted) setState(() => _rec = m);
  }

  Future<void> _open(Widget w) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final games = [
      ('هرمزنامه', 'رستم، گرز و نبرد در سواحل هرمز', Icons.shield, 'بهترین امتیاز: ${_rec['rec_hormoz'] ?? 0}', const HormozPage()),
      ('شاهد', 'بقا و نبرد پیکسلی در آسمان خلیج فارس', Icons.flight, 'بهترین امتیاز: ${_rec['rec_shahed'] ?? 0}', const ShahedPage()),
      ('سودوکو', 'کلیدهای برجستهٔ پاستیلی، چند سطح', Icons.grid_on, 'پیروزی‌ها: ${_rec['sudoku_wins'] ?? 0}', const SudokuPage()),
      ('جدول اطلاعات عمومی', 'پرسش‌های متناسب با علاقهٔ شما', Icons.quiz, 'امتیاز کل: ${_rec['trivia_score'] ?? 0}', const TriviaPage()),
    ];
    return Scaffold(
      appBar: AppBar(
        title: const Text('GAME CENTER', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(children: [const Icon(Icons.monetization_on, color: Colors.amber, size: 18), const SizedBox(width: 4), Text('${_rec['coins'] ?? 0}')]),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('بازی کن، مهارتت را بسنج و قهرمان داستان خودت باش!', textAlign: TextAlign.center, style: TextStyle(color: Colors.white60)),
          ),
          for (final g in games)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _open(g.$5),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      CircleAvatar(radius: 28, backgroundColor: Theme.of(context).colorScheme.primary.withOpacity(0.2), child: Icon(g.$3, size: 28, color: Theme.of(context).colorScheme.primary)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(g.$1, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 2),
                            Text(g.$2, style: const TextStyle(fontSize: 12, color: Colors.white60)),
                            const SizedBox(height: 4),
                            Text(g.$4, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.primary)),
                          ],
                        ),
                      ),
                      const Icon(Icons.play_circle_fill, size: 34),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
