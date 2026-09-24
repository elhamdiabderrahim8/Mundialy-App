import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';
import 'services/api_service.dart';
import 'services/startapp_service.dart';
import 'services/theme_provider.dart';
import 'utils/app_globals.dart';
import 'utils/lang_utils.dart';
import 'widgets/animated_goal_overlay.dart';
import 'widgets/in_app_notification.dart';
import 'widgets/nation_flag_badge.dart';
import 'package:showcaseview/showcaseview.dart';
import 'l10n/app_localizations.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Background message: ${message.notification?.title}");

  // ★ MODE LECTURE EN DIRECT (background isolate)
  // isWatchingLive n'est pas accessible depuis un isolate séparé,
  // on lit donc la valeur persistée dans SharedPreferences.
  final watching = await isWatchingLivePersisted();
  if (watching) {
    debugPrint('[Notifications] Notification ignorée (background) — utilisateur en mode lecture');
    return;
  }
  
  final type = message.data['type'];
  final isGoal = type == 'goal' || type == 'GOAL';

  final homeTeam = message.data['homeTeamName'] ?? '';
  final awayTeam = message.data['awayTeamName'] ?? '';
  final title = message.notification?.title ?? (isGoal ? "BUT ! 🔥" : "Alerte Match");
  final body = message.notification?.body ?? "$homeTeam vs $awayTeam";

  if (message.notification == null) {
    await ApiService.initNotifications();
    await ApiService.showSystemNotification(title, body, isGoal: isGoal);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const MyApp(),
    ),
  );

  unawaited(_initializeStartupServices());
}

class _GlobalLiveScanner {
  static Timer? _timer;
  
  static void start() {
    _timer?.cancel();
    // Scan global toutes les 20 secondes, léger et asynchrone
    _timer = Timer.periodic(const Duration(seconds: 20), (timer) async {
      try {
        // Appelle le service de détection existant sans bloquer l'UI
        await ApiService.fetchLiveMatches();
      } catch (_) {
        // Échec silencieux (pas de réseau, etc.)
      }
    });
  }

  static void stop() {
    _timer?.cancel();
  }
}

Future<void> _initializeStartupServices() async {
  try {
    await ApiService.initNotifications();
  } catch (error, stackTrace) {
    debugPrint('Startup notifications init error: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  try {
    await StartAppService.initialize();
  } catch (error, stackTrace) {
    debugPrint('Startup StartApp init error: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    await FirebaseMessaging.instance.requestPermission();
    await FirebaseMessaging.instance.subscribeToTopic('live_matches');
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
  } catch (error, stackTrace) {
    debugPrint("Firebase init error: $error");
    debugPrintStack(stackTrace: stackTrace);
  }
}

void _handleForegroundMessage(RemoteMessage message) {
  debugPrint('FCM Foreground Message: ${message.notification?.title}');

  // ★ MODE LECTURE EN DIRECT : on ignore toute notification visuelle
  // pour éviter de gâcher l'expérience et spoiler des buts.
  if (isWatchingLive) {
    debugPrint('[Notifications] Notification ignorée — utilisateur en mode lecture');
    return;
  }

  final type = message.data['type'];
  final isGoal = type == 'goal' || type == 'GOAL';
  final context = globalNavigatorKey.currentContext;

  if (context != null && context.mounted) {
    if (isGoal) {
      showGoalOverlay(context, message.data);
      
      final homeTeam = message.data['homeTeamName'] ?? '';
      final awayTeam = message.data['awayTeamName'] ?? '';
      final minute = message.data['minute'] ?? '';
      InAppNotification.show(
        context,
        homeTeam,
        awayTeam,
        minute,
        "BUT ! 🔥",
        "$homeTeam vs $awayTeam",
        isGoal: true,
      );
    } 
    // Non-goal notifications don't show an in-app banner
  }

  refreshStreamController.add(null);
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

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    _listener = AppLifecycleListener(onStateChange: _onStateChanged);
    // Lance le scanner global dès l'ouverture de l'app
    _GlobalLiveScanner.start();
  }

  @override
  void dispose() {
    _GlobalLiveScanner.stop();
    _listener.dispose();
    super.dispose();
  }

  void _onStateChanged(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _GlobalLiveScanner.start();
    } else if (state == AppLifecycleState.paused) {
      _GlobalLiveScanner.stop();
    }
  }


  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      navigatorKey: globalNavigatorKey,
      title: 'Mundialy',
      themeMode: themeProvider.themeMode,
      // Thème consolidé (DS + guide UI/UX) : AppTheme réplique les
      // builders historiques à l'identique + ThemeExtension.
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      debugShowCheckedModeBanner: false,
      // Localization support: FR / EN / AR
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr'),
        Locale('en'),
        Locale('ar'),
      ],
      localeResolutionCallback: (deviceLocale, supportedLocales) {
        // Cache the language code for API calls
        if (deviceLocale != null) {
          LangUtils.setLocale(deviceLocale.languageCode);
        }
        for (final supported in supportedLocales) {
          if (deviceLocale?.languageCode == supported.languageCode) {
            return supported;
          }
        }
        // Default to French
        return const Locale('fr');
      },
      home: ShowCaseWidget(
        builder: (context) => const HomeScreen(),
      ),
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
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xE6000000), // Semi-transparent black
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
            color: Colors.white.withOpacity(0.15),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header & Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        minute.isNotEmpty ? "$minute'" : "LIVE",
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _cycleShape,
                        child: Icon(
                          _shape == WidgetShape.compact ? Icons.unfold_more : Icons.unfold_less,
                          color: Colors.white54,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => FlutterOverlayWindow.closeOverlay(),
                        child: const Icon(
                          Icons.close,
                          color: Colors.white54,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              if (_shape != WidgetShape.compact) const SizedBox(height: 12),
              
              // MAIN CONTENT
              if (_shape == WidgetShape.compact)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        homeCode,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        score,
                        style: const TextStyle(color: Color(0xFFE7C16A), fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        awayCode,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                )
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: Text(
                        home,
                        textAlign: TextAlign.right,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      score,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        away,
                        textAlign: TextAlign.left,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );

  }
}
