class LiveStreamSource {
  final String matchId;
  final String providerName;
  final String targetStreamUrl;
  final bool isEnabled;

  const LiveStreamSource({
    required this.matchId,
    required this.providerName,
    required this.targetStreamUrl,
    this.isEnabled = true,
  });

  factory LiveStreamSource.fromJson(Map<String, dynamic> json) {
    return LiveStreamSource(
      matchId: _asString(json['matchId']),
      providerName: _asString(json['providerName']),
      targetStreamUrl: _asString(json['targetStreamUrl']),
      isEnabled: json['isEnabled'] is bool ? json['isEnabled'] as bool : true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'matchId': matchId,
      'providerName': providerName,
      'targetStreamUrl': targetStreamUrl,
      'isEnabled': isEnabled,
    };
  }

  static String _asString(Object? value) => value?.toString().trim() ?? '';
}
