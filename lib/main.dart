import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/config.dart';
import 'core/router.dart';
import 'core/session_controller.dart';
import 'core/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AppConfig.assertValid(); // env.json okunmadıysa anlaşılır bir hata verir
  await initializeDateFormatting('tr_TR'); // Türkçe tarih biçimleri (intl)

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    publishableKey: AppConfig.supabaseKey,
  );

  final session = SessionController();
  await session.init(); // açık oturum varsa profili yükler

  runApp(AyirtApp(session: session));
}

class AyirtApp extends StatefulWidget {
  const AyirtApp({super.key, required this.session});
  final SessionController session;

  @override
  State<AyirtApp> createState() => _AyirtAppState();
}

class _AyirtAppState extends State<AyirtApp> {
  // Router bir kez oluşturulur; oturum değişince kendini yeniler (refreshListenable)
  late final GoRouter _router = buildRouter(widget.session);

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      controller: widget.session,
      child: MaterialApp.router(
        title: 'Ayırt',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        routerConfig: _router,
        locale: const Locale('tr', 'TR'),
        supportedLocales: const [Locale('tr', 'TR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );
  }
}
