/// Normalise et compare les noms de joueurs (ex. "L. Messi" ↔ "Lionel Messi").
class PlayerResolver {
  PlayerResolver._();

  static String normalize(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    return raw
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-zàâäéèêëïîôùûüç\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static String _lastName(String normalized) {
    final parts = normalized.split(' ').where((p) => p.length >= 2).toList();
    return parts.isEmpty ? normalized : parts.last;
  }

  static bool namesMatch(String? a, String? b) {
    if (a == null || b == null || a.isEmpty || b.isEmpty) return false;
    final na = normalize(a);
    final nb = normalize(b);
    if (na == nb) return true;
    if (na.contains(nb) || nb.contains(na)) return true;

    final lastA = _lastName(na);
    final lastB = _lastName(nb);
    if (lastA.length >= 3 && lastA == lastB) {
      // Initiales : "l messi" vs "lionel messi"
      final initialA = na.split(' ').first;
      final initialB = nb.split(' ').first;
      if (initialA.length <= 2 || initialB.length <= 2) return true;
    }
    return false;
  }
}
