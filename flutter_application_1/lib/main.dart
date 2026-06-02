import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'constants/app_colors.dart';
import 'screens/home_screen.dart';
import 'services/theme_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

// Point d'entrée pour l'Overlay (le mini-widget flottant)
@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _FloatingScoreOverlay(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  ThemeData _buildLightTheme() {
    const seed = AppColors.primary;
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      primary: seed,
      secondary: AppColors.secondary,
      surface: AppColors.surface,
    );

    return ThemeData(
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.primary,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface.withValues(alpha: 0.96),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      dividerColor: const Color(0xFFD8C8A8),
      iconTheme: const IconThemeData(color: AppColors.primary),
      textSelectionTheme: const TextSelectionThemeData(cursorColor: AppColors.secondary),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface.withValues(alpha: 0.95),
        selectedItemColor: AppColors.secondary,
        unselectedItemColor: const Color(0xFF5B6B79),
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      textTheme: ThemeData.light().textTheme.apply(
            bodyColor: AppColors.primary,
            displayColor: AppColors.primary,
          ),
    );
  }

  ThemeData _buildDarkTheme() {
    const seed = AppColors.primary;
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );

    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.ink,
      useMaterial3: true,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF162634),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      iconTheme: const IconThemeData(color: Colors.white),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        selectedItemColor: AppColors.secondary,
        unselectedItemColor: Colors.white54,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Z WordCup',
      themeMode: themeProvider.themeMode,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}

// Widget de l'Overlay Flottant (Style Premium)
class _FloatingScoreOverlay extends StatefulWidget {
  const _FloatingScoreOverlay();

  @override
  State<_FloatingScoreOverlay> createState() => _FloatingScoreOverlayState();
}

class _FloatingScoreOverlayState extends State<_FloatingScoreOverlay> {
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    // Ecouter les mises à jour envoyées par l'app principale
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (mounted) setState(() { _data = event as Map<String, dynamic>?; });
    });
  }

  @override
  Widget build(BuildContext context) {
    final home = _data?['home'] ?? '...';
    final away = _data?['away'] ?? '...';
    final score = _data?['score'] ?? '0 - 0';

    return Material(
      color: Colors.transparent,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2630), // Gris Ardoise Elite
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFD4AF37).withValues(alpha: 0.5), width: 1.5), // Or Elite
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 10)],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Expanded(child: Text(home, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: const Color(0xFFD4AF37), borderRadius: BorderRadius.circular(8)),
              child: Text(score, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 13)),
            ),
            Expanded(child: Text(away, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold), textAlign: TextAlign.center, overflow: TextOverflow.ellipsis)),
            GestureDetector(
              onTap: () => FlutterOverlayWindow.closeOverlay(),
              child: const Icon(Icons.close, color: Colors.white54, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}
