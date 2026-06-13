import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/match_details.dart';
import '../models/top_scorer.dart';
import '../models/live_match.dart';
import 'api_service.dart';

class ScorerCalculationService {
  static const String _storageKey = 'eternal_scorers_v2'; // Version 2 pour réinitialiser les bugs de comptage
  static const String _processedGoalsKey = 'processed_goals_ledger_v1';

  static final ValueNotifier<int> progressNotifier = ValueNotifier(0);

  /// Algorithme d'ingénieur pour l'agrégation "Éternelle" des buteurs.
  /// Charge une base initiale (JSON fourni) et l'enrichit dynamiquement.
  static Future<void> runAggregator(List<LiveMatch> matches) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // 1. Chargement de l'état actuel (depuis SharedPreferences)
      String? storedRaw = prefs.getString(_storageKey);
      Map<String, dynamic> playerMap;

      if (storedRaw == null) {
        // PREMIER LANCEMENT : On initialise avec votre fichier JSON fourni
        playerMap = await _initializeFromAsset();
      } else {
        playerMap = jsonDecode(storedRaw);
      }
      
      // 2. Registre des buts pour éviter le sur-comptage (Idempotence totale)
      final List<String> goalLedger = prefs.getStringList(_processedGoalsKey) ?? [];

      // 3. Filtrage des matchs
      final targetMatches = matches.where((m) => m.isFinished || m.isLive).toList();
      targetMatches.sort((a, b) => (b.dateTime ?? DateTime.now()).compareTo(a.dateTime ?? DateTime.now()));

      if (targetMatches.isEmpty) return;

      bool dataChanged = false;

      for (final match in targetMatches.take(10)) {
        final details = await ApiService.fetchMatchDetails(match);
        if (details == null) continue;

        for (final event in details.summary.events) {
          if (event.icon == MatchEventIcon.goal) {
            final String name = event.scorerName;
            final String team = event.teamName;
            
            // Signature unique du but : matchId + minute + nom_joueur
            final String goalSignature = '${match.id}_${event.minute}_${name.trim().toLowerCase()}';
            
            if (goalLedger.contains(goalSignature)) continue; // Déjà compté !

            final String key = _findMatchingPlayerKey(playerMap, name, team);

            if (playerMap.containsKey(key)) {
              playerMap[key]['goals'] = (playerMap[key]['goals'] ?? 0) + 1;
              // Accumulation de statistiques supplémentaires
              _accumulateStats(playerMap[key], event);
              debugPrint('[ScorerEngine] COMPTÉ : $name (+1 but)');
            } else {
              playerMap[key] = {
                'name': name,
                'team': team,
                'goals': 1,
                'id': event.playerId ?? 0,
                'assists': 0,
                'yellowCards': 0,
                'redCards': 0,
                'minutes': 0,
              };
              _accumulateStats(playerMap[key], event);
              debugPrint('[ScorerEngine] NOUVEAU : $name');
            }
            
            goalLedger.add(goalSignature);
            dataChanged = true;
          }
          
          // Captation des cartons et passes même si pas de but
          _processSecondaryEvents(playerMap, event, match.id, goalLedger);
        }
        
        if (dataChanged) {
          await prefs.setString(_storageKey, jsonEncode(playerMap));
          await prefs.setStringList(_processedGoalsKey, goalLedger);
          progressNotifier.value++;
        }
      }
    } catch (e) {
      debugPrint('[ScorerEngine] Erreur : $e');
    }
  }

  static void _accumulateStats(Map<String, dynamic> player, MatchEvent event) {
    if (event.icon == MatchEventIcon.yellowCard) player['yellowCards'] = (player['yellowCards'] ?? 0) + 1;
    if (event.icon == MatchEventIcon.redCard) player['redCards'] = (player['redCards'] ?? 0) + 1;
    // On pourrait estimer les minutes via la présence dans le match, mais ici on se concentre sur les actions directes
  }

  static void _processSecondaryEvents(Map<String, dynamic> map, MatchEvent event, String matchId, List<String> ledger) {
    // Logique similaire pour les passes décisives et les cartons sans but
    if (event.assistant != null && event.assistant!.isNotEmpty) {
      final sig = '${matchId}_ast_${event.minute}_${event.assistant!.trim().toLowerCase()}';
      if (!ledger.contains(sig)) {
        final key = _findMatchingPlayerKey(map, event.assistant!, event.teamName);
        if (!map.containsKey(key)) {
           map[key] = {'name': event.assistant, 'team': event.teamName, 'goals':0, 'assists':1, 'id': event.assistantId ?? 0, 'yellowCards':0, 'redCards':0};
        } else {
           map[key]['assists'] = (map[key]['assists'] ?? 0) + 1;
        }
        ledger.add(sig);
      }
    }
  }

  /// Initialise la Map (Désormais vide au départ comme demandé)
  static Future<Map<String, dynamic>> _initializeFromAsset() async {
    return {}; // Stratégie de captation pure : on commence à zéro
  }

  /// Algorithme de correspondance intelligente (Nom ou Prénom + Équipe normalisée)
  static String _findMatchingPlayerKey(Map<String, dynamic> map, String name, String team) {
    final normName = name.toLowerCase().trim();
    final normTeam = _normalizeTeamName(team);

    // 1. Essai de correspondance exacte
    for (final entry in map.entries) {
      if (entry.value['name'].toString().toLowerCase().trim() == normName &&
          _normalizeTeamName(entry.value['team']) == normTeam) {
        return entry.key;
      }
    }

    // 2. Essai par fragments de nom (ex: "Jimenez" match avec "Raul Jimenez")
    final parts = normName.split(' ').where((p) => p.length > 2).toList();
    for (final entry in map.entries) {
      final existingName = entry.value['name'].toString().toLowerCase();
      if (_normalizeTeamName(entry.value['team']) == normTeam) {
        for (final p in parts) {
          if (existingName.contains(p)) return entry.key;
        }
      }
    }

    return '${name.trim()}_${team.trim()}';
  }

  static String _normalizeTeamName(String team) {
    final t = team.toLowerCase();
    if (t.contains('usa') || t.contains('états-unis') || t.contains('united states')) return 'usa';
    if (t.contains('mexique') || t.contains('mexico')) return 'mexico';
    if (t.contains('corée') || t.contains('korea')) return 'south korea';
    return t;
  }

  static String _generateKey(String name, String team) => '${name.trim()}_${team.trim()}';

  static Future<List<TopScorer>> getStoredScorers() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_storageKey);
      if (raw == null) {
        // Si vide, on affiche au moins les données initiales du JSON
        final initMap = await _initializeFromAsset();
        return _mapToList(initMap);
      }

      return _mapToList(jsonDecode(raw));
    } catch (_) {
      return [];
    }
  }

  static List<TopScorer> _mapToList(Map<String, dynamic> map) {
    final List<TopScorer> list = map.values.map((v) {
      return TopScorer(
        playerId: v['id'] ?? 0,
        playerName: v['name'] ?? '',
        teamName: v['team'] ?? '',
        teamCode: '',
        goals: v['goals'] ?? 0,
        matches: 0,
        assists: v['assists'] ?? 0,
        yellowCards: v['yellowCards'] ?? 0,
        redCards: v['redCards'] ?? 0,
      );
    }).toList();

    list.sort((a, b) => b.goals.compareTo(a.goals));
    for (int i = 0; i < list.length; i++) list[i].rank = i + 1;
    return list;
  }
}
