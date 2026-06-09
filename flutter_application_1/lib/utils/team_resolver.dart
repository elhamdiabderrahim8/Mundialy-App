import '../models/live_match.dart';

/// Résout les IDs SofaScore à partir des noms d'équipes.
/// Corrige l'incohérence entre les IDs api-sports (classements 2022)
/// et les IDs SofaScore (matchs / effectifs).
class TeamResolver {
  TeamResolver._();

  static final Map<String, int> _nameToSofaId = {};

  static String normalizeName(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    return _cleanName(raw).trim().toLowerCase();
  }

  static void indexMatches(Iterable<LiveMatch> matches) {
    for (final match in matches) {
      _register(match.homeTeam, match.homeTeamId);
      _register(match.awayTeam, match.awayTeamId);
    }
  }

  static void _register(String name, int? id) {
    if (id == null || id <= 0) return;
    final key = normalizeName(name);
    if (key.isEmpty) return;
    final existing = _nameToSofaId[key];
    if (existing == null || _isSofaScoreId(id)) {
      _nameToSofaId[key] = id;
    }
  }

  /// Les IDs SofaScore pour les sélections nationales sont généralement > 100.
  static bool _isSofaScoreId(int id) => id > 100;

  static int resolve(String teamName, {int? hintId}) {
    final key = normalizeName(teamName);
    final mapped = key.isNotEmpty ? _nameToSofaId[key] : null;

    if (mapped != null && mapped > 0) return mapped;
    if (hintId != null && hintId > 0 && _isSofaScoreId(hintId)) return hintId;
    if (hintId != null && hintId > 0) return hintId;
    return mapped ?? hintId ?? 0;
  }

  static bool isSameTeam(String nameA, int? idA, String nameB, int? idB) {
    if (normalizeName(nameA) == normalizeName(nameB)) return true;
    if (idA != null && idB != null && idA == idB && idA > 0) return true;
    final resolvedA = resolve(nameA, hintId: idA);
    final resolvedB = resolve(nameB, hintId: idB);
    return resolvedA > 0 && resolvedA == resolvedB;
  }

  static bool isTeamInMatch(LiveMatch match, int teamId, String teamName) {
    return isSameTeam(match.homeTeam, match.homeTeamId, teamName, teamId) ||
        isSameTeam(match.awayTeam, match.awayTeamId, teamName, teamId);
  }

  static String _cleanName(String raw) {
    const nameMap = {
      'USA': 'United States',
      'Korea Republic': 'South Korea',
      'Korea DPR': 'North Korea',
      'IR Iran': 'Iran',
      'Türkiye': 'Turkey',
      'Czechia': 'Czech Republic',
      'Cabo Verde': 'Cape Verde',
      'Chinese Taipei': 'Taiwan',
      'Congo DR': 'DR Congo',
      'Timor-Leste': 'Timor Leste',
      'Eswatini': 'Swaziland',
    };
    return nameMap[raw] ?? raw;
  }
}
