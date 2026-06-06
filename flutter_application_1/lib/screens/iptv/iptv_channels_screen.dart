import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/iptv_service.dart';
import 'iptv_player_screen.dart';

const Color _kGold = Color(0xFFE7C16A);
const Color _kDarkBg = Color(0xFF0E1A24);
const Color _kCardDark = Color(0xFF1D2D3B);

class IptvChannelsScreen extends StatefulWidget {
  final IptvService iptvService;
  final String categoryId;
  final String categoryName;

  const IptvChannelsScreen({
    super.key,
    required this.iptvService,
    required this.categoryId,
    required this.categoryName,
  });

  @override
  State<IptvChannelsScreen> createState() => _IptvChannelsScreenState();
}

class _IptvChannelsScreenState extends State<IptvChannelsScreen> {
  List<dynamic> _channels = [];
  List<dynamic> _filteredChannels = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchChannels();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchChannels() async {
    final channels = await widget.iptvService.getLiveStreams(widget.categoryId);
    if (mounted) {
      setState(() {
        _channels = channels;
        _filteredChannels = channels;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredChannels = _channels.where((c) {
        final name = (c['name'] ?? '').toString().toLowerCase();
        return name.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? _kDarkBg : const Color(0xFFF7F2E8);
    final fieldBg = isDark ? const Color(0xFF152231) : const Color(0xFFF0EBE0);
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          // Ambient glow
          Positioned(
            top: -40,
            left: -30,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [_kGold.withValues(alpha: 0.1), _kGold.withValues(alpha: 0)],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Custom AppBar
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 12, 20, 0),
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back_ios_new_rounded, color: _kGold, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.categoryName.toUpperCase(),
                              style: TextStyle(
                                color: _kGold,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1.5,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (!_isLoading)
                              Text(
                                '${_filteredChannels.length} chaîne${_filteredChannels.length > 1 ? 's' : ''}',
                                style: TextStyle(color: textColor.withValues(alpha: 0.4), fontSize: 12),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Search bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: textColor, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Rechercher une chaîne...',
                      hintStyle: TextStyle(color: textColor.withValues(alpha: 0.3), fontSize: 14),
                      prefixIcon: Icon(Icons.search_rounded, color: _kGold.withValues(alpha: 0.6), size: 20),
                      filled: true,
                      fillColor: fieldBg,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: _kGold.withValues(alpha: 0.4)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Content
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(color: _kGold),
                              const SizedBox(height: 16),
                              Text('Chargement des chaînes...', style: TextStyle(color: textColor.withValues(alpha: 0.4))),
                            ],
                          ),
                        )
                      : _filteredChannels.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.tv_off_rounded, color: _kGold.withValues(alpha: 0.3), size: 48),
                                  const SizedBox(height: 12),
                                  Text('Aucune chaîne trouvée', style: TextStyle(color: textColor.withValues(alpha: 0.5))),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                              itemCount: _filteredChannels.length,
                              itemBuilder: (context, index) {
                                final channel = _filteredChannels[index];
                                final name = channel['name']?.toString() ?? 'Inconnu';
                                final logo = channel['stream_icon']?.toString() ?? '';
                                final streamId = channel['stream_id'];

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: GestureDetector(
                                    onTap: () {
                                      if (streamId != null) {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => IptvPlayerScreen(
                                              iptvService: widget.iptvService,
                                              streamId: int.parse(streamId.toString()),
                                              channelName: name,
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: isDark ? _kCardDark : Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: _kGold.withValues(alpha: 0.12)),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                                            blurRadius: 8,
                                            offset: const Offset(0, 3),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          // Channel logo
                                          Container(
                                            width: 56,
                                            height: 56,
                                            decoration: BoxDecoration(
                                              color: isDark ? const Color(0xFF152231) : const Color(0xFFF5F0E5),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: _kGold.withValues(alpha: 0.1)),
                                            ),
                                            child: ClipRRect(
                                              borderRadius: BorderRadius.circular(11),
                                              child: logo.isNotEmpty
                                                  ? CachedNetworkImage(
                                                      imageUrl: logo,
                                                      fit: BoxFit.contain,
                                                      placeholder: (_, __) => Icon(Icons.tv_rounded, color: _kGold.withValues(alpha: 0.3), size: 24),
                                                      errorWidget: (_, __, ___) => Icon(Icons.tv_rounded, color: _kGold.withValues(alpha: 0.3), size: 24),
                                                    )
                                                  : Icon(Icons.tv_rounded, color: _kGold.withValues(alpha: 0.3), size: 24),
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          // Channel name
                                          Expanded(
                                            child: Text(
                                              name,
                                              style: TextStyle(
                                                color: textColor,
                                                fontSize: 14,
                                                fontWeight: FontWeight.w700,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          // Play button
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              gradient: LinearGradient(
                                                colors: [_kGold, _kGold.withValues(alpha: 0.7)],
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: _kGold.withValues(alpha: 0.3),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: const Icon(Icons.play_arrow_rounded, color: Color(0xFF0E1A24), size: 22),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
