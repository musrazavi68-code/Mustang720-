import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/store.dart';
import '../../core/widgets.dart';

class SudokuGen {
  static final _rnd = Random();

  static int _cands(List<int> g, int idx) {
    final r = idx ~/ 9, c = idx % 9;
    var used = 0;
    for (var i = 0; i < 9; i++) {
      used |= 1 << g[r * 9 + i];
      used |= 1 << g[i * 9 + c];
    }
    final br = r ~/ 3 * 3, bc = c ~/ 3 * 3;
    for (var i = 0; i < 3; i++) {
      for (var j = 0; j < 3; j++) {
        used |= 1 << g[(br + i) * 9 + bc + j];
      }
    }
    return ~used & 0x3FE;
  }

  static int _pop(int m) {
    var n = 0;
    while (m != 0) {
      n += m & 1;
      m >>= 1;
    }
    return n;
  }

  static int _search(List<int> g, int limit, bool randomize, List<int>? first) {
    var best = -1, bestCnt = 10, bestMask = 0;
    for (var i = 0; i < 81; i++) {
      if (g[i] != 0) continue;
      final m = _cands(g, i);
      final cnt = _pop(m);
      if (cnt == 0) return 0;
      if (cnt < bestCnt) {
        best = i;
        bestCnt = cnt;
        bestMask = m;
        if (cnt == 1) break;
      }
    }
    if (best == -1) {
      if (first != null && first.isEmpty) first.addAll(g);
      return 1;
    }
    final digits = [for (var d = 1; d <= 9; d++) if ((bestMask & (1 << d)) != 0) d];
    if (randomize) digits.shuffle(_rnd);
    var total = 0;
    for (final d in digits) {
      g[best] = d;
      total += _search(g, limit - total, randomize, first);
      if (total >= limit) {
        g[best] = 0;
        return total;
      }
    }
    g[best] = 0;
    return total;
  }

  /// پازل با جواب یکتا
  static (List<int>, List<int>) generate(int removeTarget) {
    final g = List<int>.filled(81, 0);
    final sol = <int>[];
    _search(g, 1, true, sol);
    final p = List<int>.of(sol);
    final order = List<int>.generate(81, (i) => i)..shuffle(_rnd);
    var removed = 0;
    for (final i in order) {
      final v = p[i];
      p[i] = 0;
      if (_search(List<int>.of(p), 2, false, null) != 1) {
        p[i] = v;
      } else {
        removed++;
        if (removed >= removeTarget) break;
      }
    }
    return (p, sol);
  }
}

class SudokuPage extends StatefulWidget {
  const SudokuPage({super.key});
  @override
  State<SudokuPage> createState() => _SudokuPageState();
}

class _SudokuPageState extends State<SudokuPage> {
  List<int> _puzzle = [], _solution = [], _board = [], _notes = List.filled(81, 0);
  int _sel = -1;
  bool _noteMode = false;
  bool _loading = true;
  String _diff = 'easy';

  static const _levels = {'easy': ('آسان', 38), 'medium': ('متوسط', 47), 'hard': ('سخت', 53)};

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final s = await Prefs.getString('sudoku_state');
    if (s != null && s.length > 10) {
      try {
        final j = jsonDecode(s) as Map<String, dynamic>;
        _puzzle = List<int>.from(j['p']);
        _solution = List<int>.from(j['s']);
        _board = List<int>.from(j['b']);
        _notes = List<int>.from(j['n']);
        _diff = j['d'] ?? 'easy';
        if (_puzzle.length == 81 && _board.length == 81) {
          setState(() => _loading = false);
          return;
        }
      } catch (_) {}
    }
    await _newGame(_diff);
  }

  Future<void> _newGame(String diff) async {
    setState(() {
      _loading = true;
      _diff = diff;
    });
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final (p, s) = SudokuGen.generate(_levels[diff]!.$2);
    _puzzle = p;
    _solution = s;
    _board = List<int>.of(p);
    _notes = List<int>.filled(81, 0);
    _sel = -1;
    await _save();
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() => Prefs.setString('sudoku_state', jsonEncode({'p': _puzzle, 's': _solution, 'b': _board, 'n': _notes, 'd': _diff}));

  void _enter(int d) {
    if (_sel < 0 || _puzzle[_sel] != 0) return;
    setState(() {
      if (_noteMode) {
        if (d == 0) {
          _notes[_sel] = 0;
        } else {
          _notes[_sel] ^= 1 << d;
        }
      } else {
        _board[_sel] = d;
        _notes[_sel] = 0;
      }
    });
    _save();
    if (_listEq(_board, _solution)) _won();
  }

  bool _listEq(List<int> a, List<int> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Future<void> _won() async {
    await Prefs.setInt('sudoku_wins', await Prefs.getInt('sudoku_wins') + 1);
    await Prefs.setInt('coins', await Prefs.getInt('coins') + 10);
    await Prefs.setString('sudoku_state', '');
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('آفرین! 🎉'),
        content: const Text('سودوکو را حل کردید و ۱۰ سکه گرفتید.'),
        actions: [TextButton(onPressed: () { Navigator.pop(ctx); _newGame(_diff); }, child: const Text('بازی جدید'))],
      ),
    );
  }

  void _hint() {
    if (_sel < 0 || _puzzle[_sel] != 0) return;
    setState(() {
      _board[_sel] = _solution[_sel];
      _notes[_sel] = 0;
    });
    _save();
    if (_listEq(_board, _solution)) _won();
  }

  Widget _cell(int i) {
    final given = _puzzle[i] != 0;
    final v = _board[i];
    final selected = i == _sel;
    final sameNum = _sel >= 0 && v != 0 && _board[_sel] == v;
    final wrong = !given && v != 0 && v != _solution[i];
    final r = i ~/ 9, c = i % 9;
    final related = _sel >= 0 && (_sel ~/ 9 == r || _sel % 9 == c || (_sel ~/ 27 == r ~/ 3 && (_sel % 9) ~/ 3 == c ~/ 3));
    Color color = given ? const Color(0xFFBFD7FF) : const Color(0xFFFFD9E2);
    if (related) color = Color.lerp(color, Colors.white, 0.35)!;
    if (sameNum) color = const Color(0xFFFFF0A8);
    if (selected) color = const Color(0xFFA8F5C8);
    if (wrong) color = const Color(0xFFFF8A8A);
    Widget content;
    if (v != 0) {
      content = FittedBox(child: Padding(padding: const EdgeInsets.all(4), child: Text('$v', style: TextStyle(fontSize: 24, fontWeight: given ? FontWeight.w900 : FontWeight.w600, color: const Color(0xFF23262B)))));
    } else if (_notes[i] != 0) {
      content = Column(children: [
        for (var rr = 0; rr < 3; rr++)
          Expanded(child: Row(children: [
            for (var cc = 0; cc < 3; cc++)
              Expanded(child: Center(child: Text((_notes[i] & (1 << (rr * 3 + cc + 1))) != 0 ? '${rr * 3 + cc + 1}' : '', style: const TextStyle(fontSize: 8, color: Colors.black54)))),
          ])),
      ]);
    } else {
      content = const SizedBox();
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(1.5, 1.5, c % 3 == 2 && c != 8 ? 5 : 1.5, r % 3 == 2 && r != 8 ? 6 : 3),
      child: Key3D(color: color, radius: 6, onTap: () => setState(() => _sel = i), child: content),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سودوکو'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.add_box_outlined),
            tooltip: 'بازی جدید',
            onSelected: _newGame,
            itemBuilder: (c) => [for (final e in _levels.entries) PopupMenuItem(value: e.key, child: Text('بازی جدید — ${e.value.$1}'))],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: AspectRatio(
                          aspectRatio: 1,
                          child: Column(children: [
                            for (var r = 0; r < 9; r++)
                              Expanded(child: Row(children: [for (var c = 0; c < 9; c++) Expanded(child: _cell(r * 9 + c))])),
                          ]),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          FilterChip(label: const Text('یادداشت'), avatar: const Icon(Icons.edit, size: 16), selected: _noteMode, onSelected: (v) => setState(() => _noteMode = v)),
                          ActionChip(label: const Text('راهنما'), avatar: const Icon(Icons.lightbulb_outline, size: 16), onPressed: _hint),
                          ActionChip(label: const Text('پاک'), avatar: const Icon(Icons.backspace_outlined, size: 16), onPressed: () => _enter(0)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: SizedBox(
                        height: 56,
                        child: Row(children: [
                          for (var d = 1; d <= 9; d++)
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                                child: Key3D(color: const Color(0xFFC9B8FF), onTap: () => _enter(d), child: Text('$d', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFF23262B)))),
                              ),
                            ),
                        ]),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
