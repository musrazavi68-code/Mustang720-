/// خلاصه‌ساز استخراجی روی دستگاه (بدون نیاز به اینترنت یا API).
/// برای کیفیت بالاتر می‌توان بعداً یک LLM API را به همین رابط وصل کرد.
class SumItem {
  final String title;
  final String text;
  final String category;
  final String source;
  final DateTime time;
  SumItem(this.title, this.text, this.category, this.source, this.time);
}

enum SumStyle { short, medium, analytical }

class Summarizer {
  static final _split = RegExp(r'[\s\u200c.,،؛:!?؟()«»\-–"\[\]/|]+');
  static const _stop = {
    'این', 'آن', 'که', 'را', 'با', 'برای', 'از', 'به', 'در', 'تا', 'یا', 'هم', 'هر', 'بر', 'شد', 'شده',
    'است', 'بود', 'می', 'های', 'ها', 'کرد', 'کنند', 'کند', 'خود', 'نیز', 'ولی', 'اما', 'پس', 'بعد',
    'the', 'and', 'for', 'with', 'that', 'this', 'from',
  };

  static List<String> tokens(String s) =>
      s.toLowerCase().split(_split).where((w) => w.length > 2 && !_stop.contains(w)).toList();

  static Map<String, int> _freq(Iterable<String> texts) {
    final m = <String, int>{};
    for (final t in texts) {
      for (final w in tokens(t)) {
        m[w] = (m[w] ?? 0) + 1;
      }
    }
    return m;
  }

  static List<String> keywords(List<SumItem> items, {int n = 8}) {
    final f = _freq(items.map((e) => '${e.title} ${e.text}'));
    final l = f.entries.where((e) => e.value > 1).toList()..sort((a, b) => b.value.compareTo(a.value));
    return l.take(n).map((e) => e.key).toList();
  }

  static double _score(String s, Map<String, int> f) {
    final t = tokens(s);
    if (t.isEmpty) return 0;
    var sum = 0;
    for (final w in t) {
      sum += f[w] ?? 0;
    }
    return sum / t.length;
  }

  static String _bestSentence(SumItem it, Map<String, int> f) {
    final parts = it.text.split(RegExp(r'(?<=[.!؟?])\s+|\n+')).map((e) => e.trim()).where((e) => e.length > 25).toList();
    if (parts.isEmpty) return '';
    parts.sort((a, b) => _score(b, f).compareTo(_score(a, f)));
    final s = parts.first;
    return s.length > 160 ? '${s.substring(0, 160)}…' : s;
  }

  static String summarize(List<SumItem> items, SumStyle style) {
    if (items.isEmpty) return 'در این بازه محتوایی برای خلاصه‌سازی وجود ندارد.';
    final f = _freq(items.map((e) => '${e.title} ${e.text}'));
    final byCat = <String, List<SumItem>>{};
    for (final it in items) {
      byCat.putIfAbsent(it.category, () => []).add(it);
    }
    final b = StringBuffer();
    if (style == SumStyle.analytical) {
      final kw = keywords(items);
      b.writeln('تعداد مطالب: ${items.length} در ${byCat.length} دسته');
      if (kw.isNotEmpty) b.writeln('موضوعات پربسامد: ${kw.join('، ')}');
      b.writeln();
    }
    final perCat = {SumStyle.short: 2, SumStyle.medium: 3, SumStyle.analytical: 3}[style]!;
    final cats = byCat.entries.toList()..sort((a, b) => b.value.length.compareTo(a.value.length));
    for (final c in cats) {
      final list = c.value..sort((a, b) => _score(b.title, f).compareTo(_score(a.title, f)));
      b.writeln('■ ${c.key} (${list.length})');
      for (final it in list.take(perCat)) {
        b.writeln('• ${it.title}');
        if (style != SumStyle.short) {
          final s = _bestSentence(it, f);
          if (s.isNotEmpty && s != it.title) b.writeln('   $s');
        }
      }
      b.writeln();
    }
    return b.toString().trim();
  }

  /// جست‌وجوی هوشمند (کلیدواژه‌ای) در آرشیو آفلاین
  static List<SumItem> search(List<SumItem> items, String q, {int n = 6}) {
    final qt = tokens(q);
    if (qt.isEmpty) return [];
    final scored = <MapEntry<SumItem, int>>[];
    for (final it in items) {
      final hay = '${it.title} ${it.text}'.toLowerCase();
      var s = 0;
      for (final w in qt) {
        if (it.title.toLowerCase().contains(w)) s += 3;
        if (hay.contains(w)) s += 1;
      }
      if (s > 0) scored.add(MapEntry(it, s));
    }
    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(n).map((e) => e.key).toList();
  }
}
