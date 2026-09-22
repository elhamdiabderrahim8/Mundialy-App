import '../models/live_match.dart';

/// Résout l'identité d'une équipe nationale.
/// FAIT API (vérifié live) : les `competitor.id` 365Scores sont GLOBAUX et
/// stables entre compétitions (ex: Tunisie = 5104 en CDM comme en qualifs CAN).
/// La comparaison se fait donc sur l'ID D'ABORD, le nom normalisé n'est
/// qu'un repli (variantes : USA/United States, Côte d'Ivoire/Ivory Coast...).
class TeamResolver {
  TeamResolver._();

  static final Map<String, int> _nameToSofaId = {};

  static bool get hasNoData => _nameToSofaId.isEmpty;

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

  /// Vrai si les deux IDs désignent la même équipe (0/négatif = inconnu).
  static bool matchesId(int? a, int? b) =>
      a != null && b != null && a > 0 && b > 0 && a == b;

  static int resolve(String teamName, {int? hintId}) {
    final key = normalizeName(teamName);
    final mapped = key.isNotEmpty ? _nameToSofaId[key] : null;

    if (mapped != null && mapped > 0) return mapped;
    if (hintId != null && hintId > 0 && _isSofaScoreId(hintId)) return hintId;
    if (hintId != null && hintId > 0) return hintId;
    return mapped ?? hintId ?? 0;
  }

  static bool isSameTeam(String nameA, int? idA, String nameB, int? idB) {
    // 1) ID 365Scores global : fiable entre compétitions (ex: Tunisie 5104).
    if (matchesId(idA, idB)) return true;
    // 2) Noms normalisés (+ alias).
    if (normalizeName(nameA) == normalizeName(nameB) &&
        normalizeName(nameA).isNotEmpty) {
      return true;
    }
    // 3) Index des matchs déjà vus.
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
      // Variantes réellement croisées côté 365Scores / UI
      "Côte d'Ivoire": 'Ivory Coast',
      'Cote d’Ivoire': 'Ivory Coast',
      'Cote dIvoire': 'Ivory Coast',
      'Republic of Ireland': 'Ireland',
      'Bosnia & Herzegovina': 'Bosnia and Herzegovina',
      'Bosnia-Herzegovina': 'Bosnia and Herzegovina',
      'Cabo Verde Islands': 'Cape Verde',
      'Macedonia': 'North Macedonia',
      'FYR Macedonia': 'North Macedonia',
      'São Tomé and Príncipe': 'Sao Tome and Principe',
      'São Tomé': 'Sao Tome and Principe',
    };
    return nameMap[raw] ?? raw;
  }
}
