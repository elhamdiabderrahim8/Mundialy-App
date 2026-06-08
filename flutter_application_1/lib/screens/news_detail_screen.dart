import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const _kGold = Color(0xFFE7C16A);

class NewsDetailScreen extends StatelessWidget {
  final Map<String, dynamic> article;

  const NewsDetailScreen({super.key, required this.article});

  String get _imageUrl => article['urlToImage'] ?? article['image'] ?? '';
  String get _title => article['title'] ?? 'Article';
  String get _description => article['description'] ?? '';
  String get _content => article['content'] ?? article['body'] ?? '';
  String get _source => (article['source'] is Map)
      ? article['source']['name'] ?? ''
      : article['source']?.toString() ?? '';
  String get _publishedAt => article['publishedAt'] ?? article['published_at'] ?? '';
  String get _url => article['url'] ?? '';

  String _formatDate(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      const months = [
        'Jan', 'Fév', 'Mar', 'Avr', 'Mai', 'Juin',
        'Juil', 'Aoû', 'Sep', 'Oct', 'Nov', 'Déc'
      ];
      return '${dt.day} ${months[dt.month - 1]} ${dt.year} • ${dt.hour}h${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return raw;
    }
  }

  Future<void> _openOriginal() async {
    if (_url.isNotEmpty) {
      await launchUrl(Uri.parse(_url), mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF0E1A24) : const Color(0xFFF7F2E8);
    final textColor = isDark ? Colors.white : const Color(0xFF16324A);

    return Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: _imageUrl.isNotEmpty ? 280 : 0,
            pinned: true,
            backgroundColor: isDark ? const Color(0xFF0E1A24) : Colors.white,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new, color: _imageUrl.isNotEmpty ? Colors.white : textColor),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: _imageUrl.isNotEmpty
                ? FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        Hero(
                          tag: 'news_image_${_imageUrl.hashCode}',
                          child: Image.network(
                            _imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: isDark ? const Color(0xFF1D2D3B) : const Color(0xFFE8DECA),
                            ),
                          ),
                        ),
                        // Gradient overlay
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.6),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : null,
          ),
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Source + Date
                  Row(
                    children: [
                      if (_source.isNotEmpty) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _kGold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _kGold.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            _source.toUpperCase(),
                            style: const TextStyle(
                              color: _kGold,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      if (_publishedAt.isNotEmpty)
                        Text(
                          _formatDate(_publishedAt),
                          style: TextStyle(
                            color: textColor.withValues(alpha: 0.5),
                            fontSize: 11,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Title
                  Text(
                    _title,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Description
                  if (_description.isNotEmpty) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _kGold.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                            color: _kGold.withValues(alpha: 0.2)),
                      ),
                      child: Text(
                        _description,
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.85),
                          fontSize: 15,
                          height: 1.6,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Content
                  if (_content.isNotEmpty) ...[
                    Text(
                      // Remove "[+N chars]" truncation markers from NewsAPI
                      _content.replaceAll(RegExp(r'\[?\+\d+ chars\]?'), '').trim(),
                      style: TextStyle(
                        color: textColor.withValues(alpha: 0.8),
                        fontSize: 15,
                        height: 1.7,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Read more button
                  if (_url.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _openOriginal,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kGold,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text(
                          'LIRE L\'ARTICLE ORIGINAL',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
