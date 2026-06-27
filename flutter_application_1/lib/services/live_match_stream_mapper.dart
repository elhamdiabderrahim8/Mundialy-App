import '../models/live_match_model.dart';
import '../models/live_stream_source_model.dart';

class LiveMatchStreamMapper {
  const LiveMatchStreamMapper._();

  static List<LiveMatch> bindStreamsToMatches({
    required List<LiveMatch> fixtures,
    required List<LiveStreamSource> streams,
  }) {
    final streamsByMatchId = <String, LiveStreamSource>{
      for (final stream in streams)
        if (stream.isEnabled && stream.matchId.isNotEmpty)
          stream.matchId: stream,
    };

    return fixtures
        .map((fixture) {
          final stream = streamsByMatchId[fixture.id];
          if (stream == null) return fixture;

          return LiveMatch(
            id: fixture.id,
            homeTeam: fixture.homeTeam,
            awayTeam: fixture.awayTeam,
            homeLogo: fixture.homeLogo,
            awayLogo: fixture.awayLogo,
            time: fixture.time,
            targetStreamUrl: stream.targetStreamUrl,
          );
        })
        .toList(growable: false);
  }
}
