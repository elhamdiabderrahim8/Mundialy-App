class MatchNews {
  final int id;
  final String title;
  final String? imageUrl;
  final String? url;
  final String? sourceName;
  final DateTime? publishDate;

  MatchNews({
    required this.id,
    required this.title,
    this.imageUrl,
    this.url,
    this.sourceName,
    this.publishDate,
  });

  factory MatchNews.fromJson(Map<String, dynamic> json, Map<int, String>? sourcesMap) {
    int sourceId = json['sourceId'] ?? 0;
    return MatchNews(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      imageUrl: json['image'],
      url: json['url'],
      sourceName: sourcesMap?[sourceId] ?? 'Actualité',
      publishDate: json['publishDate'] != null
          ? DateTime.tryParse(json['publishDate'])
          : null,
    );
  }
}
