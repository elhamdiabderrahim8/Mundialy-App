import 'dart:convert';
import 'package:flutter/foundation.dart';

void main() {
  final jsonString = '''
{
  "fixture": {
    "id": 855736,
    "date": "2022-11-20T16:00:00+00:00",
    "status": {
      "short": "FT"
    }
  },
  "league": {
    "round": "Group Stage - 1"
  },
  "teams": {
    "home": {
      "id": 1569,
      "name": "Qatar",
      "logo": "https://media.api-sports.io/football/teams/1569.png"
    },
    "away": {
      "id": 2382,
      "name": "Ecuador",
      "logo": "https://media.api-sports.io/football/teams/2382.png"
    }
  },
  "goals": {
    "home": 0,
    "away": 2
  },
  "score": {
    "penalty": {
      "home": null,
      "away": null
    }
  }
}
  ''';

  final json = jsonDecode(jsonString);
  final fixture = json['fixture'] ?? {};
  final teams = json['teams'] ?? {};
  final home = teams['home'] ?? {};
  final away = teams['away'] ?? {};
  final goals = json['goals'] ?? {};
  final score = json['score'] ?? {};
  final penalty = score['penalty'] ?? {};
  final status = fixture['status'] ?? {};
  
  print('homeTeam: \${home['name']}');
  print('scoreHome: \${goals['home']}');
}
