class CupTree {
  final List<CupTreeNode> rounds;

  CupTree({required this.rounds});

  factory CupTree.fromApi(Map<String, dynamic> json) {
    // SofaScore cuptrees is usually a list of rounds or a structured object
    // Depending on the version, it might be inside 'cupTree' key
    final list = (json['cupTree'] as List? ?? []);
    return CupTree(rounds: list.map((e) => CupTreeNode.fromApi(e)).toList());
  }
}

class CupTreeNode {
  final String name;
  final List<CupTreeMatch> matches;

  CupTreeNode({required this.name, required this.matches});

  factory CupTreeNode.fromApi(Map<String, dynamic> json) {
    return CupTreeNode(
      name: json['roundName'] ?? '',
      matches: (json['matches'] as List? ?? [])
          .map((e) => CupTreeMatch.fromApi(e))
          .toList(),
    );
  }
}

class CupTreeMatch {
  final int id;
  final CupTreeTeam home;
  final CupTreeTeam away;
  final int? status;

  CupTreeMatch({
    required this.id,
    required this.home,
    required this.away,
    this.status,
  });

  factory CupTreeMatch.fromApi(Map<String, dynamic> json) {
    return CupTreeMatch(
      id: json['id'] ?? 0,
      home: CupTreeTeam.fromApi(json['homeTeam'] ?? {}),
      away: CupTreeTeam.fromApi(json['awayTeam'] ?? {}),
      status: json['status']?['id'],
    );
  }
}

class CupTreeTeam {
  final int id;
  final String name;
  final int? score;

  CupTreeTeam({required this.id, required this.name, this.score});

  factory CupTreeTeam.fromApi(Map<String, dynamic> json) {
    return CupTreeTeam(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'TBD',
      score: json['score'],
    );
  }
}
