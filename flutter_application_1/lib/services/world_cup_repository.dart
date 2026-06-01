import '../models/live_match.dart';
import '../models/match_details.dart';
import 'api_service.dart';

class WorldCupRepository {
  static Future<List<LiveMatch>> getWC2022Matches() async {
    return ApiService.fetchMatches(year: 2022);
  }

  static Future<MatchDetails?> getMatchDetails(LiveMatch match) async {
    return ApiService.fetchMatchDetails(match);
  }
}
