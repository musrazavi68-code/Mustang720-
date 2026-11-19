import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import '../../core/store.dart';

/// کانال‌های پیش‌فرض (نام کاربری بدون @). اینجا اضافه کنید یا در برنامه با «+».
const List<String> kDefaultChannels = <String>[];

class TgMessage {
  final String id; // لینک پست
  final String channel;
  final String text;
  final String? image;
  final DateTime time;
  TgMessage(this.id, this.channel, this.text, this.image, this.time);

  Map<String, dynamic> toJson() => {'id': id, 'c': channel, 't': text, 'i': image, 'p': time.millisecondsSinceEpoch};
  static TgMessage fromJson(Map<String, dynamic> j) =>
      TgMessage(j['id'], j['c'], j['t'], j['i'], DateTime.fromMillisecondsSinceEpoch(j['p']));
}

final telegramService = TelegramService();

class TelegramService extends ChangeNotifier {
  List<String> channels = [];
  List<TgMessage> messages = [];
  bool refreshing = false;
  final _store = JsonStore('telegram.json');

  Future<void> load() async {
    final d = await _store.read();
    if (d is Map) {
      channels = List<String>.from(d['channels'] ?? []);
      messages = [for (final m in (d['messages'] as List? ?? [])) TgMessage.fromJson(Map<String, dynamic>.from(m))];
    }
    if (channels.isEmpty) channels = List<String>.of(kDefaultChannels);
  }

  Future<void> _save() => _store.write({
        'channels': channels,
        'messages': messages.map((e) => e.toJson()).toList(),
      });

  String _clean(String u) =>
      u.trim().replaceAll('https://t.me/s/', '').replaceAll('https://t.me/', '').replaceAll('@', '').split('/').first;

  Future<void> addChannel(String input) async {
    final c = _clean(input);
    if (c.isEmpty || channels.contains(c)) return;
    channels.add(c);
    notifyListeners();
    await _save();
    await refresh();
  }

  Future<void> removeChannel(String c) async {
    channels.remove(c);
    messages.removeWhere((m) => m.channel == c);
    notifyListeners();
    await _save();
  }

  /// فقط کانال‌های عمومی از طریق پیش‌نمایش وب t.me/s (فقط‌خواندنی)
  Future<void> refresh() async {
    if (refreshing) return;
    refreshing = true;
    notifyListeners();
    try {
      final known = {for (final m in messages) m.id: m};
      for (final ch in channels) {
        try {
          final r = await http.get(Uri.parse('https://t.me/s/$ch')).timeout(const Duration(seconds: 20));
          if (r.statusCode != 200) continue;
          final doc = html_parser.parse(r.body);
          for (final w in doc.querySelectorAll('.tgme_widget_message_wrap')) {
            final link = w.querySelector('a.tgme_widget_message_date')?.attributes['href'];
            if (link == null) continue;
            final text = w.querySelector('.tgme_widget_message_text')?.text.trim() ?? '';
            final style = w.querySelector('.tgme_widget_message_photo_wrap')?.attributes['style'] ?? '';
            final img = RegExp(r"url\('([^']+)'\)").firstMatch(style)?.group(1);
            if (text.isEmpty && img == null) continue;
            final t = DateTime.tryParse(w.querySelector('time')?.attributes['datetime'] ?? '')?.toLocal() ?? DateTime.now();
            known[link] = TgMessage(link, ch, text, img, t);
          }
        } catch (_) {}
      }
      messages = known.values.toList()..sort((a, b) => b.time.compareTo(a.time));
      if (messages.length > 1500) messages = messages.take(1500).toList();
    } finally {
      refreshing = false;
      notifyListeners();
      await _save();
    }
  }
}
