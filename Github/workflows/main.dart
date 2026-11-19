import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/theme.dart';
import 'features/connect/proxy_service.dart';
import 'features/home/home_page.dart';
import 'features/news/news_service.dart';
import 'features/telegram/telegram_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await themeController.load();
  await newsService.load();
  await telegramService.load();
  await proxyService.load();
  runApp(const Mustang720App());
}

class Mustang720App extends StatelessWidget {
  const Mustang720App({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: themeController,
      builder: (context, _) => MaterialApp(
        title: 'mustang720',
        debugShowCheckedModeBanner: false,
        locale: const Locale('fa', 'IR'),
        supportedLocales: const [Locale('fa', 'IR'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: themeController.themeData,
        home: const HomePage(),
      ),
    );
  }
}
