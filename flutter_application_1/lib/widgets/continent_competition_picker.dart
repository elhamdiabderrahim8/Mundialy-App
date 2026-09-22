// lib/widgets/continent_competition_picker.dart
// Sélecteur de compétition par continents : chaque continent (icône SVG de
// sa carte) se déplie dans la même page pour afficher ses compétitions.
// Un tap sur une compétition remonte son ID via [onSelectCompetition].
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/competitions_catalog.dart';
import '../models/competition.dart';
import 'competition_badge.dart';

/// Un continent du sélecteur : libellé + icône SVG (carte) + confédérations.
class _ContinentEntry {
  const _ContinentEntry({
    required this.key,
    required this.label,
    required this.asset,
    required this.confederations,
  });
  final String key;
  final String label;
  final String asset;
  final List<Confederation> confederations;
}

class ContinentCompetitionPicker extends StatefulWidget {
  const ContinentCompetitionPicker({
    super.key,
    required this.onSelectCompetition,
    required this.isDark,
  });

  /// Appelé avec l'ID 365Scores de la compétition choisie.
  final void Function(int competitionId) onSelectCompetition;
  final bool isDark;

  @override
  State<ContinentCompetitionPicker> createState() =>
      _ContinentCompetitionPickerState();
}

class _ContinentCompetitionPickerState
    extends State<ContinentCompetitionPicker> {
  static const Color _gold = Color(0xFFE7C16A);

  static const List<_ContinentEntry> _continents = [
    _ContinentEntry(
      key: 'afrique',
      label: 'Afrique',
      asset: 'assets/continents/africa.svg',
      confederations: [Confederation.caf],
    ),
    _ContinentEntry(
      key: 'europe',
      label: 'Europe',
      asset: 'assets/continents/europe.svg',
      confederations: [Confederation.uefa],
    ),
    _ContinentEntry(
      key: 'asie',
      label: 'Asie',
      asset: 'assets/continents/asia.svg',
      confederations: [Confederation.afc],
    ),
    _ContinentEntry(
      key: 'amerique',
      label: 'Amérique',
      asset: 'assets/continents/americas.svg',
      confederations: [Confederation.concacaf, Confederation.conmebol],
    ),
    _ContinentEntry(
      key: 'monde',
      label: 'Monde',
      asset: 'assets/continents/world.svg',
      confederations: [Confederation.fifa, Confederation.ofc],
    ),
  ];

  final Set<String> _expanded = {};

  List<Competition> _competitionsOf(_ContinentEntry continent) {
    final comps = <Competition>[];
    for (final conf in continent.confederations) {
      comps.addAll(CompetitionsCatalog.byConfederation(conf));
    }
    comps.sort((a, b) {
      if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    return comps;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;
    final textColor = isDark ? Colors.white : Colors.black;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
      itemCount: _continents.length,
      itemBuilder: (context, i) {
        final continent = _continents[i];
        final comps = _competitionsOf(continent);
        final expanded = _expanded.contains(continent.key);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color:
                isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: expanded
                  ? _gold.withValues(alpha: 0.6)
                  : (isDark ? Colors.white10 : Colors.grey.shade300),
            ),
          ),
          child: Column(
            children: [
              InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => setState(() {
                  if (expanded) {
                    _expanded.remove(continent.key);
                  } else {
                    _expanded.add(continent.key);
                  }
                }),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: _gold.withValues(alpha: 0.14),
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: SvgPicture.asset(
                          continent.asset,
                          width: 30,
                          height: 30,
                          colorFilter: const ColorFilter.mode(
                              _gold, BlendMode.srcIn),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              continent.label,
                              style: TextStyle(
                                  color: textColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${comps.length} compétitions',
                              style: TextStyle(
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.grey.shade600,
                                  fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(Icons.expand_more_rounded,
                            color: isDark
                                ? Colors.white54
                                : Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),
              if (expanded) ...[
                Divider(
                    height: 1,
                    thickness: 0.5,
                    color:
                        isDark ? Colors.white10 : Colors.grey.shade300),
                ...comps.map((comp) => ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 2),
                      leading: CompetitionBadge(
                        competition: comp,
                        size: 36,
                      ),
                      title: Text(
                        comp.name,
                        style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 14),
                      ),
                      subtitle: comp.isActive
                          ? const Text('EN COURS',
                              style: TextStyle(
                                  color: Colors.green,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700))
                          : null,
                      trailing: const Icon(Icons.chevron_right,
                          color: Colors.grey),
                      onTap: () =>
                          widget.onSelectCompetition(comp.id),
                    )),
                const SizedBox(height: 6),
              ],
            ],
          ),
        );
      },
    );
  }
}
