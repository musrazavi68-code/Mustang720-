String timeAgo(DateTime t) {
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return 'هم‌اکنون';
  if (d.inMinutes < 60) return '${d.inMinutes} دقیقه پیش';
  if (d.inHours < 24) return '${d.inHours} ساعت پیش';
  return '${d.inDays} روز پیش';
}

String two(int n) => n.toString().padLeft(2, '0');

String stripHtml(String s) {
  var t = s.replaceAll(RegExp(r'<(script|style)[^>]*>[\s\S]*?</\1>', caseSensitive: false), '');
  t = t.replaceAll(RegExp(r'<br\s*/?>|</p>|</div>|</li>', caseSensitive: false), '\n');
  t = t.replaceAll(RegExp(r'<[^>]+>'), '');
  t = t
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&hellip;', '…');
  t = t.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
    final code = int.tryParse(m.group(1)!);
    return code == null ? '' : String.fromCharCode(code);
  });
  t = t.replaceAll(RegExp(r'[ \t]+'), ' ').replaceAll(RegExp(r'\n\s*\n+'), '\n\n');
  return t.trim();
}

final _months = {
  'jan': 1, 'feb': 2, 'mar': 3, 'apr': 4, 'may': 5, 'jun': 6,
  'jul': 7, 'aug': 8, 'sep': 9, 'oct': 10, 'nov': 11, 'dec': 12,
};

/// تاریخ RFC-822 (pubDate در RSS) یا ISO-8601 (Atom)
DateTime? parseFeedDate(String? s) {
  if (s == null || s.trim().isEmpty) return null;
  final iso = DateTime.tryParse(s.trim());
  if (iso != null) return iso.toLocal();
  final m = RegExp(r'(\d{1,2})\s+([A-Za-z]{3})[a-z]*\s+(\d{4})\s+(\d{1,2}):(\d{2})(?::(\d{2}))?\s*([A-Za-z]+|[+-]\d{4})?')
      .firstMatch(s);
  if (m == null) return null;
  final mon = _months[m.group(2)!.toLowerCase()];
  if (mon == null) return null;
  var utc = DateTime.utc(int.parse(m.group(3)!), mon, int.parse(m.group(1)!), int.parse(m.group(4)!),
      int.parse(m.group(5)!), int.parse(m.group(6) ?? '0'));
  final z = m.group(7);
  if (z != null && RegExp(r'^[+-]\d{4}$').hasMatch(z)) {
    final sign = z.startsWith('-') ? -1 : 1;
    final hh = int.parse(z.substring(1, 3));
    final mm = int.parse(z.substring(3, 5));
    utc = utc.subtract(Duration(minutes: sign * (hh * 60 + mm)));
  }
  return utc.toLocal();
}
