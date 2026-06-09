import '../models/live_match.dart';

/// Utilities to keep one logical team identity across screens even when
/// different data providers use different ids for the same national team.
class TeamIdentity {
  const TeamIdentity._();

  static String normalizeName(String? name) {
    final raw = (name ?? '').trim().toLowerCase();
    if (raw.isEmpty) return '';

    return raw
        .replaceAll(RegExp(r'\b(national|football|team|men|women)\b'), '')
        .replaceAll(RegExp(r'\b(fc|cf|sc)\b'), '')
        .replaceAll('united states of america', 'usa')
        .replaceAll('united states', 'usa')
        .replaceAll('south korea', 'korea republic')
        .replaceAll('korea republic', 'korea republic')
        .replaceAll('côte d’ivoire', 'ivory coast')
        .replaceAll("cote d'ivoire", 'ivory coast')
        .replaceAll('cote divoire', 'ivory coast')
        .replaceAll('tunisie', 'tunisia')
        .replaceAll('danemark', 'denmark')
        .replaceAll('angleterre', 'england')
        .replaceAll('allemagne', 'germany')
        .replaceAll('espagne', 'spain')
        .replaceAll('pays-bas', 'netherlands')
        .replaceAll('etats-unis', 'usa')
        .replaceAll('états-unis', 'usa')
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool sameTeam({int? idA, String? nameA, int? idB, String? nameB}) {
    if (idA != null && idB != null && idA == idB) return true;
    final normalizedA = normalizeName(nameA);
    final normalizedB = normalizeName(nameB);
    return normalizedA.isNotEmpty && normalizedA == normalizedB;
  }

  static int? findSofaTeamId(
    Iterable<LiveMatch> matches, {
    required int? teamId,
    required String? teamName,
  }) {
    final normalizedName = normalizeName(teamName);
    for (final match in matches) {
      if (teamId != null && match.homeTeamId == teamId) return match.homeTeamId;
      if (teamId != null && match.awayTeamId == teamId) return match.awayTeamId;
    }
    if (normalizedName.isEmpty) return teamId;
    for (final match in matches) {
      if (normalizeName(match.homeTeam) == normalizedName) return match.homeTeamId;
      if (normalizeName(match.awayTeam) == normalizedName) return match.awayTeamId;
    }
    return teamId;
  }
}
