import 'dart:io';
import 'package:flutter_application_1/services/scores365_service.dart';
import 'package:flutter_application_1/data/competitions_catalog.dart';

void main() async {
  print("Testing fetch...");
  final now = DateTime.now();
  final start = "${now.subtract(const Duration(days: 30)).day.toString().padLeft(2, '0')}/${now.subtract(const Duration(days: 30)).month.toString().padLeft(2, '0')}/${now.subtract(const Duration(days: 30)).year}";
  final end = "${now.add(const Duration(days: 30)).day.toString().padLeft(2, '0')}/${now.add(const Duration(days: 30)).month.toString().padLeft(2, '0')}/${now.add(const Duration(days: 30)).year}";

  print("Start: \$start, End: \$end");
  
  final comp = CompetitionsCatalog.all.first; // 5930?
  print("Fetching for \${comp.name} (\${comp.id})");
  
  try {
    final matches = await Scores365Service.fetchMatchesByCompetition(
      competitionId: comp.id,
      startDate: start,
      endDate: end,
    );
    print("Fetched \${matches.length} matches.");
  } catch(e, st) {
    print("Error: \$e");
    print(st);
  }
  exit(0);
}
