import 'package:flutter/material.dart';

import '../models/match_details.dart';
import '../models/team_player.dart';
import '../screens/player_profile_screen.dart';
import 'country_flags.dart';

/// Saison du Mondial correspondant à la date du match.
int resolveWorldCupSeason(DateTime? matchDate) {
  if (matchDate == null) return 2026;
  final year = matchDate.year;
  if (year >= 2026) return 2026;
  return 2022;
}

String _normalizePlayerName(String name) {
  return name
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .replaceAll('.', '');
}

String _lastName(String name) {
  final parts = _normalizePlayerName(name).split(' ');
  return parts.isEmpty ? '' : parts.last;
}

/// Retrouve l'ID SofaScore d'un joueur à partir des compositions du match.
int? resolvePlayerIdByName(String? name, List<TeamLineup>? lineups) {
  if (name == null || name.isEmpty || lineups == null) return null;

  final target = _normalizePlayerName(name);
  final targetLast = _lastName(name);

  for (final lineup in lineups) {
    for (final player in [...lineup.players, ...lineup.bench]) {
      if (player.id <= 0) continue;
      final playerNorm = _normalizePlayerName(player.name);
      if (playerNorm == target) return player.id;
      if (targetLast.isNotEmpty && _lastName(player.name) == targetLast) {
        return player.id;
      }
    }
  }
  return null;
}

/// Ouvre le profil joueur avec un ID SofaScore fiable (évite les confusions de noms).
void openPlayerProfile(
  BuildContext context, {
  required int playerId,
  required String playerName,
  String? teamName,
  String? teamCode,
  int season = 2026,
  int? shirtNumber,
  String? photoUrl,
  String? position,
  List<TeamLineup>? lineups,
}) {
  var effectiveId = playerId;
  if (effectiveId <= 0) {
    effectiveId = resolvePlayerIdByName(playerName, lineups) ?? 0;
  }
  if (effectiveId <= 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profil joueur indisponible pour le moment.'),
      ),
    );
    return;
  }

  final resolvedCode = (teamCode != null && teamCode.isNotEmpty)
      ? teamCode
      : resolveCountryCode(teamName);

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PlayerProfileScreen(
        entity: TeamPlayer(
          id: effectiveId,
          name: playerName,
          position: position ?? '',
          shirtNumber: shirtNumber,
          photoUrl:
              photoUrl ??
              'https://imagecache.365scores.com/image/upload/f_auto,q_auto,w_120,h_120,c_limit/Athletes/$effectiveId',
          nationality: teamName ?? '',
          nationalityCode: resolvedCode,
          ageLabel: '',
        ),
        season: season,
      ),
    ),
  );
}
