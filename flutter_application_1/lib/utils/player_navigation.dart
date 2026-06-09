import 'package:flutter/material.dart';

import '../models/team_player.dart';
import '../screens/player_profile_screen.dart';

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
}) {
  if (playerId <= 0) return;

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PlayerProfileScreen(
        entity: TeamPlayer(
          id: playerId,
          name: playerName,
          position: position ?? '',
          shirtNumber: shirtNumber,
          photoUrl: photoUrl ??
              'https://api.sofascore.app/api/v1/player/$playerId/image',
          nationality: teamName ?? '',
          nationalityCode: teamCode ?? '',
          ageLabel: '',
        ),
        season: season,
      ),
    ),
  );
}
