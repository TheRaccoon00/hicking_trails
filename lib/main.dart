import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';
import 'services/settings_service.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");
  await SettingsService.init();
  AppLocalizations.localeNotifier.value = SettingsService.language;
  runApp(const HikingApp());
}

class HikingApp extends StatelessWidget {
  const HikingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AppLocalizations.localeNotifier,
      builder: (context, lang, child) {
        return MaterialApp(
          title: 'Otavia trails',
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A2F25)),
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFF9FAFB),
            textTheme: GoogleFonts.outfitTextTheme(
               ThemeData.light().textTheme.apply(
                  bodyColor: const Color(0xFF111827),
                  displayColor: const Color(0xFF111827),
               ),
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1A2F25),
              foregroundColor: Colors.white,
            ),
            bottomNavigationBarTheme: const BottomNavigationBarThemeData(
              backgroundColor: Color(0xFFF9FAFB),
              selectedItemColor: Color(0xFF1A2F25),
              unselectedItemColor: Colors.grey,
            )
          ),
          home: const HomeScreen(),
          debugShowCheckedModeBanner: false,
        );
      }
    );
  }
}
