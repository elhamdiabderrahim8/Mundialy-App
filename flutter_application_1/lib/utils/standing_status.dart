import 'package:flutter/material.dart';

enum StandingQualification { qualified, inContention, eliminated }

StandingQualification standingQualification(
  int rank, {
  int year = 2026,
  bool? isQualified,
  bool? toQualify,
}) {
  if (isQualified == true) return StandingQualification.qualified;
  if (toQualify == false) return StandingQualification.eliminated;

  if (year == 2026) {
    if (rank <= 2) return StandingQualification.qualified;
    if (rank == 3) return StandingQualification.inContention;
    return StandingQualification.eliminated;
  }
  if (rank <= 2) return StandingQualification.qualified;
  return StandingQualification.eliminated;
}

String standingStatusLabel(StandingQualification status) {
  return switch (status) {
    StandingQualification.qualified => 'Qualifié',
    StandingQualification.inContention => 'En lice',
    StandingQualification.eliminated => 'Éliminé',
  };
}

Color standingStatusColor(StandingQualification status) {
  return switch (status) {
    StandingQualification.qualified => const Color(0xFF2ECC71),
    StandingQualification.inContention => const Color(0xFFE7C16A),
    StandingQualification.eliminated => const Color(0xFFE74C3C),
  };
}
