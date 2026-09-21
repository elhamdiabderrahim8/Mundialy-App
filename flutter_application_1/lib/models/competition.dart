// lib/models/competition.dart
// Modèle pour une compétition nationale de football masculin

enum Confederation { fifa, uefa, caf, afc, concacaf, conmebol, ofc }

enum CompetitionCategory {
  worldCup,
  wcQualification,
  continental,
  continentalQualification,
  youth,
  friendly,
  olympic,
}

class Competition {
  final int id;
  final String name;
  final String shortName;
  final String nameForUrl;
  final Confederation confederation;
  final CompetitionCategory category;
  final bool hasStandings;
  final bool hasBrackets;
  final bool hasStats;
  final bool isActive;
  final String? flagEmoji; // emoji drapeau ou symbole de la confédération

  const Competition({
    required this.id,
    required this.name,
    required this.shortName,
    required this.nameForUrl,
    required this.confederation,
    required this.category,
    this.hasStandings = true,
    this.hasBrackets = false,
    this.hasStats = true,
    this.isActive = false,
    this.flagEmoji,
  });

  /// Nom affiché court pour les chips et headers
  String get displayName => shortName.isNotEmpty ? shortName : name;

  /// Couleur associée à la confédération
  String get confederationLabel {
    switch (confederation) {
      case Confederation.fifa:
        return 'FIFA';
      case Confederation.uefa:
        return 'UEFA';
      case Confederation.caf:
        return 'CAF';
      case Confederation.afc:
        return 'AFC';
      case Confederation.concacaf:
        return 'CONCACAF';
      case Confederation.conmebol:
        return 'CONMEBOL';
      case Confederation.ofc:
        return 'OFC';
    }
  }
}
