import 'package:flutter/foundation.dart';
import '../utils/country_flags.dart';

enum MatchDataSource { mock, fifa2022, footballData2026, wc2026api }

class LiveMatch {
  const LiveMatch({
    required this.id,
    required this.dateLabel,
    required this.localTime,
    required this.city,
    required this.homeTeam,
    required this.homeCode,
    this.homeTeamId,
    this.homeLogoUrl,
    required this.awayTeam,
    required this.awayCode,
    this.awayTeamId,
    this.awayLogoUrl,
    required this.phaseLabel,
    this.source = MatchDataSource.fifa2022,
    this.competitionId,
    this.seasonId,
    this.stageId,
    this.scoreHome,
    this.scoreAway,
    this.penaltyHome,
    this.penaltyAway,
    this.isLive = false,
    this.dateTime,
    this.streamUrl,
  });

  final String id;
  final String dateLabel;
  final String localTime;
  final String city;
  final String homeTeam;
  final String homeCode;
  final int? homeTeamId;
  final String? homeLogoUrl;
  final String awayTeam;
  final String awayCode;
  final int? awayTeamId;
  final String? awayLogoUrl;
  final String phaseLabel;
  final MatchDataSource source;
  final int? competitionId;
  final int? seasonId;
  final int? stageId;
  final int? scoreHome;
  final int? scoreAway;
  final int? penaltyHome;
  final int? penaltyAway;
  final bool isLive;
  final DateTime? dateTime;
  final String? streamUrl;

  factory LiveMatch.fromJson(Map<String, dynamic> json) {
    return LiveMatch(
      id: json['id'] as String,
      dateLabel: json['date_label'] as String,
      localTime: json['local_time'] as String,
      city: json['city'] as String,
      homeTeam: json['home_team'] as String,
      homeCode: json['home_code'] as String,
      homeTeamId: json['home_team_id'] as int?,
      homeLogoUrl: json['home_logo_url'] as String?,
      awayTeam: json['away_team'] as String,
      awayCode: json['away_code'] as String,
      awayTeamId: json['away_team_id'] as int?,
      awayLogoUrl: json['away_logo_url'] as String?,
      phaseLabel: json['phase_label'] as String,
      source: MatchDataSource.values.firstWhere(
        (value) => value.name == (json['source'] as String? ?? MatchDataSource.fifa2022.name),
        orElse: () => MatchDataSource.fifa2022,
      ),
      competitionId: json['competition_id'] as int?,
      seasonId: json['season_id'] as int?,
      stageId: json['stage_id'] as int?,
      scoreHome: json['score_home'] as int?,
      scoreAway: json['score_away'] as int?,
      penaltyHome: json['penalty_home'] as int?,
      penaltyAway: json['penalty_away'] as int?,
      isLive: json['is_live'] as bool? ?? false,
      dateTime: json['date_time'] != null ? DateTime.tryParse(json['date_time'] as String) : null,
      streamUrl: json['stream_url'] as String?,
    );
  }

  static String _dayName(int day) {
    return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day - 1];
  }

  static String _monthName(int month) {
    return ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][month - 1];
  }
}
