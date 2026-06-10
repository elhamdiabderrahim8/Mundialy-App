import 'package:flutter/foundation.dart';

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
    this.statusShort,
    this.statusLong,
    this.matchMinute,
    this.periodStart,
    this.periodBaseMinute,
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
  final String? statusShort; // 'NS', 'LIVE', 'FT', '1H', '2H', 'HT', 'ET', 'P'
  final String? statusLong; // e.g. "1st Half", "Halftime", "Ended"
  final String? matchMinute; // e.g. "45'" for the 45th minute
  final DateTime? periodStart;
  final int? periodBaseMinute;

  /// True if the match is finished
  bool get isFinished =>
      statusShort == 'FT' ||
      statusShort == 'AET' ||
      statusShort == 'PEN' ||
      statusShort?.toLowerCase() == 'finished';

  /// True if the match hasn't started yet
  bool get isNotStarted =>
      statusShort == 'NS' ||
      statusShort == null ||
      statusShort?.toLowerCase() == 'notstarted';

  /// Display label for the match status area
  String get statusDisplay {
    String? currentMin = matchMinute;
    final bool isHalftime =
        statusShort == 'HT' || statusShort?.toUpperCase() == 'HALFTIME';

    if (periodStart != null && periodBaseMinute != null && !isHalftime) {
      int diff = DateTime.now().difference(periodStart!).inMinutes;
      currentMin = '${periodBaseMinute! + diff}';
    }

    if (isLive) {
      final String? status = currentMin ?? statusShort;
      if (status != null) {
        if (status == 'HT' || status.toUpperCase() == 'HALFTIME') return 'HT';
        if (status.endsWith("'")) return status;
        if (int.tryParse(status) != null) return "$status'";
        return status;
      }
      return statusLong ?? 'EN DIRECT';
    }
    if (isFinished) return 'Terminé';
    return localTime;
  }

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
        (value) =>
            value.name ==
            (json['source'] as String? ?? MatchDataSource.fifa2022.name),
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
      dateTime: json['date_time'] != null
          ? DateTime.tryParse(json['date_time'] as String)?.toLocal()
          : null,
      streamUrl: json['stream_url'] as String?,
      statusShort: json['status_short'] as String?,
      statusLong: json['status_long'] as String?,
      matchMinute: json['match_minute']?.toString(),
    );
  }

  factory LiveMatch.fromApiFootball(Map<String, dynamic> json) {
    try {
      final fixture = json['fixture'] ?? {};
      final teams = json['teams'] ?? {};
      final goals = json['goals'] ?? {};
      final status = fixture['status'] ?? {};
      final dateStr = fixture['date'] ?? '';
      final date = DateTime.tryParse(dateStr)?.toLocal() ?? DateTime.now();

      final timeObj = json['time'] ?? fixture['time'] ?? status['time'] ?? {};
      final startTsRaw =
          timeObj['currentPeriodStartTimestamp'] ??
          json['currentPeriodStartTimestamp'] ??
          fixture['currentPeriodStartTimestamp'] ??
          status['currentPeriodStartTimestamp'];
      final int? startTs = startTsRaw != null
          ? int.tryParse(startTsRaw.toString())
          : null;

      String? minuteStr =
          (status['elapsed'] ??
                  status['currentMinute'] ??
                  timeObj['currentMinute'] ??
                  timeObj['played'] ??
                  json['currentMinute'])
              ?.toString();
      DateTime? pStart;
      int? pBase;

      if (startTs != null) {
        final isMs = startTs > 9999999999;
        pStart = DateTime.fromMillisecondsSinceEpoch(
          isMs ? startTs : startTs * 1000,
        );
        final code =
            status['code'] ?? status['short'] ?? json['status']?['code'];
        pBase = 0;
        if (code == 7 || code == '2H')
          pBase = 45;
        else if (code == 24 || code == 'ET1')
          pBase = 90;
        else if (code == 25 || code == 'ET2')
          pBase = 105;

        if (minuteStr == null || minuteStr.isEmpty) {
          if (code == 31 || code == 'HT') {
            minuteStr = 'HT';
          } else {
            int diff = DateTime.now().difference(pStart).inMinutes;
            minuteStr = '${pBase + diff}';
          }
        }
      }

      return LiveMatch(
        id: fixture['id']?.toString() ?? '0',
        dateLabel:
            '${_dayName(date.weekday)} ${date.day} ${_monthName(date.month)}',
        localTime:
            '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
        dateTime: date,
        city: fixture['venue']?['city'] ?? 'Stadium',
        homeTeam: teams['home']?['name'] ?? 'TBD',
        homeCode: teams['home']?['id']?.toString() ?? 'UN',
        homeLogoUrl: teams['home']?['logo'],
        awayTeam: teams['away']?['name'] ?? 'TBD',
        awayCode: teams['away']?['id']?.toString() ?? 'UN',
        awayLogoUrl: teams['away']?['logo'],
        phaseLabel: json['league']?['round'] ?? 'World Cup',
        scoreHome: goals['home'],
        scoreAway: goals['away'],
        penaltyHome: (json['score'] as Map?)?['penalty']?['home'] as int?,
        penaltyAway: (json['score'] as Map?)?['penalty']?['away'] as int?,
        isLive:
            [
              '1H',
              '2H',
              'HT',
              'ET',
              'BT',
              'P',
              'LIVE',
              'INPROGRESS',
            ].contains(status['short']?.toString().toUpperCase()) ||
            (status['type']?.toString().toLowerCase() == 'inprogress'),
        statusShort: (status['short'] ?? status['type'])?.toString(),
        statusLong: status['long'] as String?,
        matchMinute: minuteStr,
        periodStart: pStart,
        periodBaseMinute: pBase,
      );
    } catch (e) {
      debugPrint('Erreur mapping LiveMatch: $e');
      rethrow;
    }
  }

  static String _dayName(int day) {
    return ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][day - 1];
  }

  static String _monthName(int month) {
    return [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ][month - 1];
  }
}
