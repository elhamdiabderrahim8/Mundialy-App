import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'constants/app_colors.dart';
import 'screens/home_screen.dart';
import 'services/theme_provider.dart';
import 'widgets/animated_goal_overlay.dart';
import 'widgets/in_app_notification.dart';
import 'widgets/nation_flag_badge.dart';

final GlobalKey<NavigatorState> globalNavigatorKey =
    GlobalKey<NavigatorState>();
final StreamController<void> refreshStreamController =
    StreamController<void>.broadcast();

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Background message: ${message.notification?.title}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialisation de Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Demander les permissions (surtout pour iOS, sans effet bloquant sur Android)
    await FirebaseMessaging.instance.requestPermission();

    // S'abonner au topic "live_matches" correspondant au backend Python
    await FirebaseMessaging.instance.subscribeToTopic('live_matches');

    // Écouter les messages au premier plan (Foreground)
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('⚽ FCM Foreground Message: ${message.notification?.title}');

      final type = message.data['type'];
      final context = globalNavigatorKey.currentContext;

      if (context != null && context.mounted) {
        if (type == 'goal') {
          // Animation élégante "GOAL" avec drapeau
          showGoalOverlay(context, message.data);
        } else {
          // Alertes classiques (Mi-temps, match commencé, penalty)
          final title = message.notification?.title ?? "Alerte Match";
          final body = message.notification?.body ?? "";
          final homeTeam = message.data['homeTeamName'] ?? '';
          final awayTeam = message.data['awayTeamName'] ?? '';
          final minute = message.data['minute'] ?? '';

          if (homeTeam.isNotEmpty && awayTeam.isNotEmpty) {
            InAppNotification.show(
              context,
              homeTeam,
              awayTeam,
              minute,
              title,
              body,
              isGoal: false,
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '$title - $body',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                backgroundColor: AppColors.primary,
                duration: const Duration(seconds: 4),
              ),
            );
          }
        }
      }

      // Déclencher le rafraîchissement brusque de l'interface (tableaux et données)
      refreshStreamController.add(null);
    });
  } catch (e) {
    debugPrint("Firebase init error: $e");
  }

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
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.secondary,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface.withValues(alpha: 0.98),
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        elevation: 0,
        type: BottomNavigationBarType.fixed,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightGoldTint,
        selectedColor: AppColors.secondary.withValues(alpha: 0.24),
        labelStyle: const TextStyle(color: AppColors.textPrimary),
        secondaryLabelStyle: const TextStyle(color: AppColors.textPrimary),
        side: const BorderSide(color: AppColors.lightBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        labelStyle: const TextStyle(color: AppColors.textPrimary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: AppColors.secondary, width: 1.6),
        ),
      ),
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ).copyWith(
        bodySmall: ThemeData.light().textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
        labelMedium: ThemeData.light().textTheme.labelMedium?.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
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
      navigatorKey: globalNavigatorKey,
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

enum WidgetShape { compact, rectangle, square }

class _FloatingScoreOverlayState extends State<_FloatingScoreOverlay> {
  Map<String, dynamic>? _data;
  WidgetShape _shape = WidgetShape.rectangle;

  @override
  void initState() {
    super.initState();
    FlutterOverlayWindow.overlayListener.listen((event) {
      if (mounted) {
        setState(() {
          _data = event as Map<String, dynamic>?;
        });
      }
    });
  }

  void _cycleShape() {
    setState(() {
      if (_shape == WidgetShape.compact) {
        _shape = WidgetShape.rectangle;
        FlutterOverlayWindow.resizeOverlay(WindowSize.matchParent, 140, true);
      } else if (_shape == WidgetShape.rectangle) {
        _shape = WidgetShape.square;
        FlutterOverlayWindow.resizeOverlay(WindowSize.matchParent, 240, true);
      } else {
        _shape = WidgetShape.compact;
        FlutterOverlayWindow.resizeOverlay(WindowSize.matchParent, 70, true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final home = _data?['home'] ?? '...';
    final away = _data?['away'] ?? '...';
    final homeCode = _data?['homeCode'] ?? '';
    final awayCode = _data?['awayCode'] ?? '';
    final score = _data?['score'] ?? 'VS';
    final minute = _data?['minute'] ?? '';

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: const Color(0xFF162634),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.redAccent.withValues(alpha: 0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        // Wrap with SingleChildScrollView to prevent any RenderFlex overflow
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // HEADER (Close + Resize)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'EN DIRECT',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w900,
                          fontSize: 9,
                        ),
                      ),
                      if (minute.isNotEmpty &&
                          _shape != WidgetShape.compact) ...[
                        const SizedBox(width: 6),
                        Text(
                          "$minute'",
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: _cycleShape,
                        child: const Icon(
                          Icons.aspect_ratio,
                          color: Colors.white70,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => FlutterOverlayWindow.closeOverlay(),
                        child: const Icon(
                          Icons.close,
                          color: Colors.grey,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (_shape != WidgetShape.compact) const SizedBox(height: 8),

              // CONTENT
              if (_shape == WidgetShape.compact)
                // COMPACT MODE
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          home,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        score,
                        style: const TextStyle(
                          color: Color(0xFFD4AF37),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          away,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )
              else if (_shape == WidgetShape.rectangle)
                // RECTANGLE MODE (Standard)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          NationFlagBadge(countryCode: homeCode, size: 24),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              home,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        score,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Text(
                              away,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                              ),
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          NationFlagBadge(countryCode: awayCode, size: 24),
                        ],
                      ),
                    ),
                  ],
                )
              else
                // SQUARE MODE (Large)
                Column(
                  children: [
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            NationFlagBadge(countryCode: homeCode, size: 50),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: 80,
                              child: Text(
                                home,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        Column(
                          children: [
                            Text(
                              score,
                              style: const TextStyle(
                                color: Color(0xFFD4AF37),
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            if (minute.isNotEmpty)
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent.withValues(
                                    alpha: 0.2,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  "$minute'",
                                  style: const TextStyle(
                                    color: Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Column(
                          children: [
                            NationFlagBadge(countryCode: awayCode, size: 50),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: 80,
                              child: Text(
                                away,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
