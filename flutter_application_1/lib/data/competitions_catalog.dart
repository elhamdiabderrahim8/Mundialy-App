// lib/data/competitions_catalog.dart
// Catalogue statique de toutes les compétitions nationales MASCULINES de football
// IDs découverts via scan de l'API 365scores (appTypeId=5)

import '../models/competition.dart';

class CompetitionsCatalog {
  CompetitionsCatalog._();

  /// Toutes les compétitions nationales masculines disponibles sur 365scores
  static const List<Competition> all = [
    // ──────────────────────────────────────────────────────────
    // FIFA — MONDIALES
    // ──────────────────────────────────────────────────────────
    Competition(
      id: 5930,
      name: 'FIFA World Cup',
      shortName: 'World Cup',
      nameForUrl: 'fifa-world-cup',
      confederation: Confederation.fifa,
      category: CompetitionCategory.worldCup,
      hasStandings: true,
      hasBrackets: true,
      hasStats: true,
      isActive: false,
      flagEmoji: '🌍',
    ),
    Competition(
      id: 5788,
      name: 'World Cup Playoff Tournament',
      shortName: 'WC Playoff',
      nameForUrl: 'wc-qual-inter-confederation-playoffs',
      confederation: Confederation.fifa,
      category: CompetitionCategory.worldCup,
      hasStandings: false,
      hasBrackets: true,
      hasStats: false,
      isActive: false,
      flagEmoji: '🌍',
    ),
    Competition(
      id: 5525,
      name: 'U20 World Cup',
      shortName: 'U20 WC',
      nameForUrl: 'u20-world-cup',
      confederation: Confederation.fifa,
      category: CompetitionCategory.worldCup,
      hasStandings: true,
      hasBrackets: true,
      hasStats: true,
      isActive: false,
      flagEmoji: '🌍',
    ),
    Competition(
      id: 5582,
      name: 'U17 World Cup',
      shortName: 'U17 WC',
      nameForUrl: 'u17-world-cup',
      confederation: Confederation.fifa,
      category: CompetitionCategory.worldCup,
      hasStandings: true,
      hasBrackets: true,
      hasStats: false,
      isActive: false,
      flagEmoji: '🌍',
    ),

    // ──────────────────────────────────────────────────────────
    // QUALIFICATIONS COUPE DU MONDE
    // ──────────────────────────────────────────────────────────
    Competition(
      id: 5421,
      name: 'UEFA WC Qualification',
      shortName: 'UEFA Qual. WC',
      nameForUrl: 'uefa-wc-qualification',
      confederation: Confederation.uefa,
      category: CompetitionCategory.wcQualification,
      hasStandings: true,
      hasBrackets: false,
      hasStats: false,
      isActive: false,
      flagEmoji: '🇪🇺',
    ),
    Competition(
      id: 645,
      name: 'CAF WC Qualification',
      shortName: 'CAF Qual. WC',
      nameForUrl: 'caf-wc-qualification',
      confederation: Confederation.caf,
      category: CompetitionCategory.wcQualification,
      hasStandings: true,
      hasBrackets: false,
      hasStats: false,
      isActive: false,
      flagEmoji: '🌍',
    ),
    Competition(
      id: 605,
      name: 'AFC WC Qualification',
      shortName: 'AFC Qual. WC',
      nameForUrl: 'afc-wc-qualification',
      confederation: Confederation.afc,
      category: CompetitionCategory.wcQualification,
      hasStandings: true,
      hasBrackets: false,
      hasStats: false,
      isActive: false,
      flagEmoji: '🌏',
    ),
    Competition(
      id: 611,
      name: 'CONCACAF WC Qualification',
      shortName: 'CONCACAF Qual.',
      nameForUrl: 'concacaf-world-cup-qualification',
      confederation: Confederation.concacaf,
      category: CompetitionCategory.wcQualification,
      hasStandings: true,
      hasBrackets: false,
      hasStats: false,
      isActive: false,
      flagEmoji: '🌎',
    ),
    Competition(
      id: 613,
      name: 'CONMEBOL WC Qualification',
      shortName: 'CONMEBOL Qual.',
      nameForUrl: 'conmebol-wc-qualification',
      confederation: Confederation.conmebol,
      category: CompetitionCategory.wcQualification,
      hasStandings: true,
      hasBrackets: false,
      hasStats: false,
      isActive: false,
      flagEmoji: '🌎',
    ),
    Competition(
      id: 646,
      name: 'OFC WC Qualification',
      shortName: 'OFC Qual. WC',
      nameForUrl: 'world-cup-qualification-oceania',
      confederation: Confederation.ofc,
      category: CompetitionCategory.wcQualification,
      hasStandings: true,
      hasBrackets: false,
      hasStats: false,
      isActive: false,
      flagEmoji: '🌊',
    ),

    // ──────────────────────────────────────────────────────────
    // CAF — AFRIQUE
    // ──────────────────────────────────────────────────────────
    Competition(
      id: 588,
      name: 'Africa Cup of Nations Qualification',
      shortName: 'AFCON Qual.',
      nameForUrl: 'africa-cup-of-nations-qualification',
      confederation: Confederation.caf,
      category: CompetitionCategory.continentalQualification,
      hasStandings: true,
      hasBrackets: false,
      hasStats: true,
      isActive: true,  // ✅ Actif
      flagEmoji: '🌍',
    ),

    // ──────────────────────────────────────────────────────────
    // UEFA — EUROPE
    // ──────────────────────────────────────────────────────────
    Competition(
      id: 6071,
      name: 'European Qualifiers',
      shortName: 'Euro Qualifs',
      nameForUrl: 'european-qualifiers',
      confederation: Confederation.uefa,
      category: CompetitionCategory.continentalQualification,
      hasStandings: true,
      hasBrackets: false,
      hasStats: false,
      isActive: false,
      flagEmoji: '🇪🇺',
    ),
    Competition(
      id: 322,
      name: 'Euro U21 Qualification',
      shortName: 'Euro U21 Qual.',
      nameForUrl: 'euro-u21-qualification',
      confederation: Confederation.uefa,
      category: CompetitionCategory.youth,
      hasStandings: true,
      hasBrackets: false,
      hasStats: false,
      isActive: true,  // ✅ Actif
      flagEmoji: '🇪🇺',
    ),
    Competition(
      id: 591,
      name: 'Euro U21',
      shortName: 'Euro U21',
      nameForUrl: 'euro-u21',
      confederation: Confederation.uefa,
      category: CompetitionCategory.youth,
      hasStandings: true,
      hasBrackets: true,
      hasStats: true,
      isActive: false,
      flagEmoji: '🇪🇺',
    ),
    Competition(
      id: 323,
      name: 'Euro U17 Qualification',
      shortName: 'Euro U17 Qual.',
      nameForUrl: 'euro-u17-qualification',
      confederation: Confederation.uefa,
      category: CompetitionCategory.youth,
      hasStandings: true,
      hasBrackets: false,
      hasStats: false,
      isActive: true,  // ✅ Actif
      flagEmoji: '🇪🇺',
    ),
    Competition(
      id: 328,
      name: 'Euro U17',
      shortName: 'Euro U17',
      nameForUrl: 'euro-u17',
      confederation: Confederation.uefa,
      category: CompetitionCategory.youth,
      hasStandings: true,
      hasBrackets: true,
      hasStats: false,
      isActive: false,
      flagEmoji: '🇪🇺',
    ),
    Competition(
      id: 467,
      name: 'Euro U19',
      shortName: 'Euro U19',
      nameForUrl: 'euro-u19',
      confederation: Confederation.uefa,
      category: CompetitionCategory.youth,
      hasStandings: true,
      hasBrackets: true,
      hasStats: false,
      isActive: true,  // ✅ Actif
      flagEmoji: '🇪🇺',
    ),

    // ──────────────────────────────────────────────────────────
    // CONMEBOL — AMÉRIQUE DU SUD
    // ──────────────────────────────────────────────────────────
    Competition(
      id: 595,
      name: 'Copa América',
      shortName: 'Copa América',
      nameForUrl: 'copa-america',
      confederation: Confederation.conmebol,
      category: CompetitionCategory.continental,
      hasStandings: true,
      hasBrackets: true,
      hasStats: true,
      isActive: false,
      flagEmoji: '🌎',
    ),
    Competition(
      id: 5453,
      name: 'Sudamericano U20',
      shortName: 'Sudamericano U20',
      nameForUrl: 'sudamericano-u20',
      confederation: Confederation.conmebol,
      category: CompetitionCategory.youth,
      hasStandings: true,
      hasBrackets: true,
      hasStats: false,
      isActive: false,
      flagEmoji: '🌎',
    ),
    Competition(
      id: 5483,
      name: 'Sudamericano U17',
      shortName: 'Sudamericano U17',
      nameForUrl: 'sudamericano-u17',
      confederation: Confederation.conmebol,
      category: CompetitionCategory.youth,
      hasStandings: true,
      hasBrackets: false,
      hasStats: false,
      isActive: false,
      flagEmoji: '🌎',
    ),

    // ──────────────────────────────────────────────────────────
    // CONCACAF — AMÉRIQUE DU NORD / CENTRALE / CARAÏBES
    // ──────────────────────────────────────────────────────────
    Competition(
      id: 589,
      name: 'CONCACAF Gold Cup',
      shortName: 'Gold Cup',
      nameForUrl: 'concacaf-gold-cup',
      confederation: Confederation.concacaf,
      category: CompetitionCategory.continental,
      hasStandings: true,
      hasBrackets: true,
      hasStats: true,
      isActive: false,
      flagEmoji: '🌎',
    ),
    Competition(
      id: 5471,
      name: 'Copa Centroamericana',
      shortName: 'Copa Centro.',
      nameForUrl: 'copa-centroamericana',
      confederation: Confederation.concacaf,
      category: CompetitionCategory.continental,
      hasStandings: true,
      hasBrackets: true,
      hasStats: false,
      isActive: false,
      flagEmoji: '🌎',
    ),
    Competition(
      id: 5485,
      name: 'U20 CONCACAF Championship',
      shortName: 'CONCACAF U20',
      nameForUrl: 'u20-concacaf-championship',
      confederation: Confederation.concacaf,
      category: CompetitionCategory.youth,
      hasStandings: true,
      hasBrackets: true,
      hasStats: false,
      isActive: false,
      flagEmoji: '🌎',
    ),

    // ──────────────────────────────────────────────────────────
    // AFC — ASIE
    // ──────────────────────────────────────────────────────────
    Competition(
      id: 6196,
      name: 'Asian Cup',
      shortName: 'Asian Cup',
      nameForUrl: 'asian-cup',
      confederation: Confederation.afc,
      category: CompetitionCategory.continental,
      hasStandings: true,
      hasBrackets: true,
      hasStats: true,
      isActive: false,
      flagEmoji: '🌏',
    ),
    Competition(
      id: 5472,
      name: 'Asian Cup Qualification',
      shortName: 'Asian Cup Qual.',
      nameForUrl: 'asian-cup-qualification',
      confederation: Confederation.afc,
      category: CompetitionCategory.continentalQualification,
      hasStandings: true,
      hasBrackets: false,
      hasStats: false,
      isActive: false,
      flagEmoji: '🌏',
    ),
    Competition(
      id: 6332,
      name: 'AFC U23 Asian Cup',
      shortName: 'AFC U23 Cup',
      nameForUrl: 'afc-u23-asian-cup',
      confederation: Confederation.afc,
      category: CompetitionCategory.youth,
      hasStandings: true,
      hasBrackets: true,
      hasStats: false,
      isActive: false,
      flagEmoji: '🌏',
    ),
    Competition(
      id: 7960,
      name: 'AFC U17 Asian Cup',
      shortName: 'AFC U17 Cup',
      nameForUrl: 'afc-u17-asian-cup',
      confederation: Confederation.afc,
      category: CompetitionCategory.youth,
      hasStandings: true,
      hasBrackets: true,
      hasStats: false,
      isActive: false,
      flagEmoji: '🌏',
    ),
    Competition(
      id: 7957,
      name: 'WAFF Championship U23',
      shortName: 'WAFF U23',
      nameForUrl: 'waff-championship-u23',
      confederation: Confederation.afc,
      category: CompetitionCategory.youth,
      hasStandings: true,
      hasBrackets: false,
      hasStats: false,
      isActive: false,
      flagEmoji: '🌏',
    ),

    // ──────────────────────────────────────────────────────────
    // MONDE ARABE / GOLFE
    // ──────────────────────────────────────────────────────────
    Competition(
      id: 7674,
      name: 'FIFA Arab Cup',
      shortName: 'Arab Cup',
      nameForUrl: 'fifa-arab-cup',
      confederation: Confederation.fifa,
      category: CompetitionCategory.continental,
      hasStandings: true,
      hasBrackets: true,
      hasStats: true,
      isActive: false,
      flagEmoji: '🌙',
    ),
    Competition(
      id: 7691,
      name: 'Arab Nations Cup',
      shortName: 'Arab Nations',
      nameForUrl: 'arab-nations-cup',
      confederation: Confederation.fifa,
      category: CompetitionCategory.continental,
      hasStandings: true,
      hasBrackets: true,
      hasStats: false,
      isActive: false,
      flagEmoji: '🌙',
    ),
    Competition(
      id: 5452,
      name: 'Arabian Gulf Cup',
      shortName: 'Gulf Cup',
      nameForUrl: 'arabian-gulf-cup',
      confederation: Confederation.afc,
      category: CompetitionCategory.continental,
      hasStandings: true,
      hasBrackets: true,
      hasStats: false,
      isActive: false,
      flagEmoji: '🌙',
    ),
    Competition(
      id: 8814,
      name: 'AGCFF Gulf Cup U20',
      shortName: 'Gulf Cup U20',
      nameForUrl: 'agcff-gulf-cup-u20',
      confederation: Confederation.afc,
      category: CompetitionCategory.youth,
      hasStandings: true,
      hasBrackets: true,
      hasStats: false,
      isActive: false,
      flagEmoji: '🌙',
    ),
    Competition(
      id: 8950,
      name: 'AGCFF U-23 Gulf Cup',
      shortName: 'Gulf Cup U23',
      nameForUrl: 'agcff-u-23-gulf-cup',
      confederation: Confederation.afc,
      category: CompetitionCategory.youth,
      hasStandings: true,
      hasBrackets: true,
      hasStats: false,
      isActive: false,
      flagEmoji: '🌙',
    ),

    // ──────────────────────────────────────────────────────────
    // OLYMPIQUES
    // ──────────────────────────────────────────────────────────
    Competition(
      id: 6370,
      name: 'Olympics Football Men',
      shortName: 'JO Football',
      nameForUrl: 'olympics-football-men',
      confederation: Confederation.fifa,
      category: CompetitionCategory.olympic,
      hasStandings: true,
      hasBrackets: true,
      hasStats: false,
      isActive: false,
      flagEmoji: '🏅',
    ),
    Competition(
      id: 6302,
      name: 'Olympic Qualifiers',
      shortName: 'JO Qualifs',
      nameForUrl: 'olympic-qualifiers',
      confederation: Confederation.concacaf,
      category: CompetitionCategory.olympic,
      hasStandings: true,
      hasBrackets: false,
      hasStats: false,
      isActive: false,
      flagEmoji: '🏅',
    ),
    Competition(
      id: 6354,
      name: 'Olympic Playoffs',
      shortName: 'JO Playoffs',
      nameForUrl: 'olympic-playoffs',
      confederation: Confederation.fifa,
      category: CompetitionCategory.olympic,
      hasStandings: false,
      hasBrackets: true,
      hasStats: false,
      isActive: false,
      flagEmoji: '🏅',
    ),

    // ──────────────────────────────────────────────────────────
    // MATCHS AMICAUX
    // ──────────────────────────────────────────────────────────
    Competition(
      id: 570,
      name: 'Friendly International',
      shortName: 'Amicaux',
      nameForUrl: 'friendly-international',
      confederation: Confederation.fifa,
      category: CompetitionCategory.friendly,
      hasStandings: false,
      hasBrackets: false,
      hasStats: false,
      isActive: false,
      flagEmoji: '🤝',
    ),
    Competition(
      id: 571,
      name: 'U21 Friendly International',
      shortName: 'Amicaux U21',
      nameForUrl: 'u21-friendly-international',
      confederation: Confederation.fifa,
      category: CompetitionCategory.friendly,
      hasStandings: false,
      hasBrackets: false,
      hasStats: false,
      isActive: false,
      flagEmoji: '🤝',
    ),
    Competition(
      id: 5422,
      name: 'U19 Friendly International',
      shortName: 'Amicaux U19',
      nameForUrl: 'u19-friendly-international',
      confederation: Confederation.fifa,
      category: CompetitionCategory.friendly,
      hasStandings: false,
      hasBrackets: false,
      hasStats: false,
      isActive: false,
      flagEmoji: '🤝',
    ),
    Competition(
      id: 5509,
      name: 'U17 Friendly International',
      shortName: 'Amicaux U17',
      nameForUrl: 'u17-friendly-international',
      confederation: Confederation.fifa,
      category: CompetitionCategory.friendly,
      hasStandings: false,
      hasBrackets: false,
      hasStats: false,
      isActive: false,
      flagEmoji: '🤝',
    ),
    Competition(
      id: 5560,
      name: 'U20 Friendly International',
      shortName: 'Amicaux U20',
      nameForUrl: 'u20-friendly-international',
      confederation: Confederation.fifa,
      category: CompetitionCategory.friendly,
      hasStandings: false,
      hasBrackets: false,
      hasStats: false,
      isActive: false,
      flagEmoji: '🤝',
    ),
  ];

  /// Compétitions actuellement actives (saison en cours)
  static List<Competition> get active =>
      all.where((c) => c.isActive).toList();

  /// Compétitions par confédération
  static List<Competition> byConfederation(Confederation conf) =>
      all.where((c) => c.confederation == conf).toList();

  /// Compétitions par catégorie
  static List<Competition> byCategory(CompetitionCategory cat) =>
      all.where((c) => c.category == cat).toList();

  /// Trouver une compétition par ID
  static Competition? findById(int id) {
    try {
      return all.firstWhere((c) => c.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Compétitions groupées par confédération (pour affichage UI)
  static Map<String, List<Competition>> get groupedByConfederation {
    final map = <String, List<Competition>>{};
    for (final c in all) {
      final label = c.confederationLabel;
      map.putIfAbsent(label, () => []).add(c);
    }
    return map;
  }
}
