// Design System consolidé — extrait de l'ancien commit de référence 7166519
// (v2.0.5, 2026-07-02). Builders repris à l'identique de lib/main.dart de ce commit,
// enrichis des ThemeExtension du guide UI/UX (spacing, rayons, couleurs sémantiques
// sportives). Le rendu des builders est inchangé ; seules les extensions s'ajoutent.
// Usage : theme: AppTheme.light(), darkTheme: AppTheme.dark()
// Accès tokens : Theme.of(context).extension<AppSpacing>()!.md
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../constants/app_sizes.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() {
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
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.secondary,
        unselectedItemColor: const Color(0xFF5B6B79),
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
      ),
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: AppColors.primary,
        displayColor: AppColors.primary,
      ),
      extensions: const [AppSpacing(), AppRadii(), MatchColors.light()],
    );
  }

  static ThemeData dark() {
    const seed = AppColors.primary;
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
      secondary: AppColors.secondary, // or champagne, comme en clair (DS §1)
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
      dividerColor: Colors.white12,
      textTheme: ThemeData.dark().textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      extensions: const [AppSpacing(), AppRadii(), MatchColors.dark()],
    );
  }
}

/// Grille 8pt du guide UI/UX (ThemeExtension — accès via
/// `Theme.of(context).extension<AppSpacing>()!`).
/// Valeurs alignées sur AppSizes : 4 / 8 / 12 / 16 / 24 / 32.
@immutable
class AppSpacing extends ThemeExtension<AppSpacing> {
  const AppSpacing({
    this.xs = AppSizes.paddingXSmall,
    this.sm = AppSizes.paddingSmall,
    this.md = AppSizes.paddingMedium - 4, // 12
    this.lg = AppSizes.paddingMedium, // 16 — marge écran / padding carte
    this.xl = AppSizes.paddingLarge, // 24
    this.xxl = AppSizes.paddingXLarge, // 32
  });

  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xxl;

  @override
  AppSpacing copyWith({
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
    double? xxl,
  }) =>
      AppSpacing(
        xs: xs ?? this.xs,
        sm: sm ?? this.sm,
        md: md ?? this.md,
        lg: lg ?? this.lg,
        xl: xl ?? this.xl,
        xxl: xxl ?? this.xxl,
      );

  @override
  AppSpacing lerp(ThemeExtension<AppSpacing>? other, double t) {
    if (other is! AppSpacing) return this;
    double l(double a, double b) => a + (b - a) * t;
    return AppSpacing(
      xs: l(xs, other.xs),
      sm: l(sm, other.sm),
      md: l(md, other.md),
      lg: l(lg, other.lg),
      xl: l(xl, other.xl),
      xxl: l(xxl, other.xxl),
    );
  }
}

/// Rayons du guide UI/UX : sm 8, md 12, lg 16 (carte de match), full pill.
/// (Le radius 28 historique des CardTheme est conservé tel quel.)
@immutable
class AppRadii extends ThemeExtension<AppRadii> {
  const AppRadii({
    this.sm = AppSizes.radiusMedium, // 8
    this.md = AppSizes.radiusLarge, // 12
    this.lg = 16, // carte de match (guide §1.4)
    this.xl = 20,
    this.full = 999,
  });

  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double full;

  @override
  AppRadii copyWith({double? sm, double? md, double? lg, double? xl, double? full}) =>
      AppRadii(
        sm: sm ?? this.sm,
        md: md ?? this.md,
        lg: lg ?? this.lg,
        xl: xl ?? this.xl,
        full: full ?? this.full,
      );

  @override
  AppRadii lerp(ThemeExtension<AppRadii>? other, double t) {
    if (other is! AppRadii) return this;
    double l(double a, double b) => a + (b - a) * t;
    return AppRadii(
      sm: l(sm, other.sm),
      md: l(md, other.md),
      lg: l(lg, other.lg),
      xl: l(xl, other.xl),
      full: l(full, other.full),
    );
  }
}

/// Tokens sémantiques sportifs du guide UI/UX (§1.1) : le rouge live est
/// distinct du rouge d'erreur, le vert win/rouge loss n'existaient pas au DS.
@immutable
class MatchColors extends ThemeExtension<MatchColors> {
  const MatchColors({
    required this.liveIndicator,
    required this.win,
    required this.loss,
    required this.draw,
    required this.favorite,
    required this.rankSilver,
    required this.rankBronze,
  });

  const MatchColors.light()
      : liveIndicator = const Color(0xFFE53935),
        win = const Color(0xFF2ECC71),
        loss = const Color(0xFFE74C3C),
        draw = AppColors.secondary,
        favorite = AppColors.secondary,
        rankSilver = const Color(0xFFE0E0E0),
        rankBronze = const Color(0xFFCD7F32);

  const MatchColors.dark()
      : liveIndicator = const Color(0xFFE53935),
        win = const Color(0xFF2ECC71),
        loss = const Color(0xFFE74C3C),
        draw = AppColors.secondary,
        favorite = AppColors.secondary,
        rankSilver = const Color(0xFFE0E0E0),
        rankBronze = const Color(0xFFCD7F32);

  /// Rouge vif live — toujours accompagné d'un texte/icône (daltonisme, §4).
  final Color liveIndicator;

  /// Vert victoire / qualifié.
  final Color win;

  /// Rouge défaite / éliminé (distinct de AppColors.error).
  final Color loss;

  /// Match nul / en lice.
  final Color draw;

  /// Équipes suivies / favoris.
  final Color favorite;

  /// Médailles classement.
  final Color rankSilver;
  final Color rankBronze;

  @override
  MatchColors copyWith({
    Color? liveIndicator,
    Color? win,
    Color? loss,
    Color? draw,
    Color? favorite,
    Color? rankSilver,
    Color? rankBronze,
  }) =>
      MatchColors(
        liveIndicator: liveIndicator ?? this.liveIndicator,
        win: win ?? this.win,
        loss: loss ?? this.loss,
        draw: draw ?? this.draw,
        favorite: favorite ?? this.favorite,
        rankSilver: rankSilver ?? this.rankSilver,
        rankBronze: rankBronze ?? this.rankBronze,
      );

  @override
  MatchColors lerp(ThemeExtension<MatchColors>? other, double t) {
    if (other is! MatchColors) return this;
    Color? l(Color? a, Color? b) => Color.lerp(a, b, t);
    return MatchColors(
      liveIndicator: l(liveIndicator, other.liveIndicator) ?? liveIndicator,
      win: l(win, other.win) ?? win,
      loss: l(loss, other.loss) ?? loss,
      draw: l(draw, other.draw) ?? draw,
      favorite: l(favorite, other.favorite) ?? favorite,
      rankSilver: l(rankSilver, other.rankSilver) ?? rankSilver,
      rankBronze: l(rankBronze, other.rankBronze) ?? rankBronze,
    );
  }
}
