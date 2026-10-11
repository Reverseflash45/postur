import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'data/pengaturan.dart';
import 'layar/utama.dart';
import 'tema.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Pengaturan.muat();
  await initializeDateFormatting('id');
  runApp(const AplikasiPostur());
}

class AplikasiPostur extends StatelessWidget {
  const AplikasiPostur({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Postur',
      debugShowCheckedModeBanner: false,
      theme: buatTema(),
      themeMode: ThemeMode.dark,
      locale: const Locale('id'),
      supportedLocales: const [Locale('id'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const LayarUtama(),
    );
  }
}
