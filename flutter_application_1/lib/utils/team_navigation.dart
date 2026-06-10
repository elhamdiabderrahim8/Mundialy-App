import 'package:flutter/material.dart';

import '../screens/team_profile_screen.dart';
import 'team_resolver.dart';

void openTeamProfile(
  BuildContext context, {
  required String teamName,
  int? teamId,
  int year = 2026,
}) {
  final resolvedId = TeamResolver.resolve(teamName, hintId: teamId);
  if (resolvedId <= 0) return;

  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) =>
          TeamProfileScreen(teamId: resolvedId, teamName: teamName, year: year),
    ),
  );
}
