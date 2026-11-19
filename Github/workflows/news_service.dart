import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import '../../core/store.dart';
import '../../core/util.dart';
import 'news_models.dart';

enum SortMode { unreadFirst, readFirst, dateAsc, dateDesc, fetchAsc, fetchDesc, title }

enum LayoutMode { grid3, grid2, list }

/// منابع پیش‌فرض (RSS). آدرس‌ها ممکن است تغییر کرده باشند؛ از تنظیمات قابل ویرایش‌اند.
const List<Feed> kDefaultFeeds = <Feed>[
  Feed('zoomit', 'زومیت', 'https://www.zoomit.ir/feed/', 'فناوری'),
  Feed('digiato', 'دیجیاتو', 'https://digiato.com/feed', 'فناوری'),
  Feed('digikalamag', 'دیجی‌کالا مگ', 'https://www.digikala.com/mag/feed/', 'فناوری'),
  Feed('varzesh3', 'ورزش سه', 'https://www.varzesh3.com/rss/all', 'ورزشی'),
  Feed('isna', 'ایسنا', 'https://www.isna.ir/rss', 'اجتماعی'),
  Feed('irna', 'ایرنا', 'https://www.irna.ir/rss', 'سیاسی'),
  Feed('khabaronline', 'خبرآنلاین', 'https://www.khabaronline.ir/rss', 'سیاسی'),
  Feed('hamshahri', 'همشهری', 'https://www.hamshahrionline.ir/rss', 'اجتماعی'),
];

final newsService = NewsService();

class NewsService extends ChangeNotifier {
  List<Feed> feeds = [];
  List<Article> articles = [];
  bool refreshing = false;
  DateTime? lastUpdate;
  SortMode sort = SortMode.dateDesc;
  LayoutMode layout = LayoutMode.grid3;
  bool hideRead = false;
  final _store = JsonStore('news.json');

  Future<void> load() async {
    final d = await _store.read();
    if (d is Map) {
      feeds = [for (final f in (d['feeds'] as List? ?? [])) Feed.fromJson(Map<String, dynamic>.from(f))];
      articles = [for (final a in (d['articles'] as List? ?? [])) Article.fromJson(Map<String, dynamic>.from(a))];
      if (d['last'] != null) lastUpdate = DateTime.fromMillisecondsSinceEpoch(d['last']);
      sort = SortMode.values[(d['sort'] ?? SortMode.dateDesc.index) % SortMode.values.length];
      layout = LayoutMode.values[(d['layout'] ?? 0) % LayoutMode.values.length];
      hideRead = d['hide'] ?? false;
    }
    if (feeds.isEmpty) feeds = List<Feed>.of(kDefaultFeeds);
  }

  Future<void> save() => _store.write({
        'feeds': feeds.map((e) => e.toJson()).toList(),
        'articles': articles.map((e) => e.toJson()).toList(),
        'last': lastUpdate?.millisecondsSinceEpoch,
        'sort': sort.index,
        'layout': layout.index,
        'hide': hideRead,
      });

  // ---------- شمارنده‌ها ----------
  int get unread => articles.where((a) => !a.read).length;
  int get starredCount => articles.where((a) => a.starred).length;
  int get last24 => articles.where((a) => DateTime.now().difference(a.published).inHours < 24).length;
  int unreadFor(String feedId) => articles.where((a) => a.feedId == feedId && !a.read).length;
  List<String> get categories => feeds.map((f) => f.category).toSet().toList();

  // ---------- عملیات ----------
  Future<void> markRead(Article a, [bool v = true]) async {
    a.read = v;
    notifyListeners();
    await save();
  }

  Future<void> toggleStar(Article a) async {
    a.starred = !a.starred;
    notifyListeners();
    await save();
  }

  Future<void> markAllRead([Iterable<Article>? list]) async {
    for (final a in (list ?? articles)) {
      a.read = true;
    }
    notifyListeners();
    await save();
  }

  Future<void> deleteWhere(bool Function(Article) test) async {
    articles.removeWhere((a) => !a.starred && test(a));
    notifyListeners();
    await save();
  }

  Future<void> setSort(SortMode m) async {
    sort = m;
    notifyListeners();
    await save();
  }

  Future<void> cycleLayout() async {
    layout = LayoutMode.values[(layout.index + 1) % LayoutMode.values.length];
    notifyListeners();
    await save();
  }

  Future<void> toggleHideRead() async {
    hideRead = !hideRead;
    notifyListeners();
    await save();
  }

  Future<void> addFeed(Feed f) async {
    if (feeds.any((e) => e.url == f.url)) return;
    feeds.add(f);
    notifyListeners();
    await save();
  }

  Future<void> removeFeed(Feed f) async {
    feeds.removeWhere((e) => e.id == f.id);
    articles.removeWhere((a) => a.feedId == f.id && !a.starred);
    notifyListeners();
    await save();
  }

  List<Article> sorted(List<Article> l) {
    final c = List<Article>.of(l);
    c.sort((a, b) {
      switch (sort) {
        case SortMode.unreadFirst:
          if (a.read != b.read) return a.read ? 1 : -1;
          return b.published.compareTo(a.published);
        case SortMode.readFirst:
          if (a.read != b.read) return a.read ? -1 : 1;
          return b.published.compareTo(a.published);
        case SortMode.dateAsc:
          return a.published.compareTo(b.published);
        case SortMode.dateDesc:
          return b.published.compareTo(a.published);
        case SortMode.fetchAsc:
          return a.fetched.compareTo(b.fetched);
        case SortMode.fetchDesc:
          return b.fetched.compareTo(a.fetched);
        case SortMode.title:
          return a.title.compareTo(b.title);
      }
    });
    return c;
  }

  // ---------- دریافت ----------
  Future<int> refresh() async {
    if (refreshing) return 0;
    refreshing = true;
    notifyListeners();
    var added = 0;
    try {
      final results = await Future.wait(feeds.map(_fetchFeed));
      final known = {for (final a in articles) a.id: a};
      final seenTitles = {for (final a in articles) a.title};
      for (final list in results) {
        for (final a in list) {
          if (known.containsKey(a.id) || seenTitles.contains(a.title)) continue; // حذف تکراری
          known[a.id] = a;
          seenTitles.add(a.title);
          added++;
        }
      }
      var all = known.values.toList()..sort((a, b) => b.published.compareTo(a.published));
      final keep = all.where((a) => a.starred).toList();
      final rest = all.where((a) => !a.starred).take(700).toList();
      articles = [...keep, ...rest]..sort((a, b) => b.published.compareTo(a.published));
      lastUpdate = DateTime.now();
    } finally {
      refreshing = false;
      notifyListeners();
      await save();
    }
    return added;
  }

  XmlElement? _child(XmlElement e, String local) {
    for (final c in e.childElements) {
      if (c.name.local == local) return c;
    }
    return null;
  }

  String? _text(XmlElement e, String local) {
    final t = _child(e, local)?.innerText.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  String? _image(XmlElement item, String content) {
    for (final c in item.childElements) {
      final q = c.name.qualified;
      if ((q == 'media:content' || q == 'media:thumbnail') && c.getAttribute('url') != null) {
        return c.getAttribute('url');
      }
      if (q == 'enclosure' && (c.getAttribute('type') ?? '').startsWith('image')) {
        return c.getAttribute('url');
      }
    }
    final m = RegExp(r'''<img[^>]+src=["']([^"']+)["']''', caseSensitive: false).firstMatch(content);
    return m?.group(1);
  }

  Future<List<Article>> _fetchFeed(Feed f) async {
    try {
      final r = await http.get(Uri.parse(f.url), headers: {'User-Agent': 'mustang720/0.1'}).timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) return [];
      final doc = XmlDocument.parse(r.body);
      final out = <Article>[];
      final now = DateTime.now();
      final items = doc.findAllElements('item').toList();
      final entries = doc.findAllElements('entry').toList();
      for (final it in items) {
        final title = _text(it, 'title');
        final link = _text(it, 'link');
        if (title == null || link == null) continue;
        final content = _text(it, 'encoded') ?? _text(it, 'description') ?? '';
        out.add(Article(
          id: link,
          feedId: f.id,
          feedTitle: f.title,
          category: f.category,
          title: stripHtml(title),
          link: link,
          content: content,
          image: _image(it, content),
          published: parseFeedDate(_text(it, 'pubDate') ?? _text(it, 'date')) ?? now,
          fetched: now,
        ));
      }
      for (final it in entries) {
        final title = _text(it, 'title');
        String? link;
        for (final c in it.childElements) {
          if (c.name.local == 'link' && c.getAttribute('href') != null) {
            if (link == null || c.getAttribute('rel') == 'alternate') link = c.getAttribute('href');
          }
        }
        if (title == null || link == null) continue;
        final content = _text(it, 'content') ?? _text(it, 'summary') ?? '';
        out.add(Article(
          id: link,
          feedId: f.id,
          feedTitle: f.title,
          category: f.category,
          title: stripHtml(title),
          link: link,
          content: content,
          image: _image(it, content),
          published: parseFeedDate(_text(it, 'published') ?? _text(it, 'updated')) ?? now,
          fetched: now,
        ));
      }
      return out;
    } catch (_) {
      return [];
    }
  }
}
