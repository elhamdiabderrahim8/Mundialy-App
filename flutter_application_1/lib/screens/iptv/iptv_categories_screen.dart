import 'package:flutter/material.dart';
import '../../services/iptv_service.dart';
import 'iptv_channels_screen.dart';

const Color _kGold = Color(0xFFE7C16A);
const Color _kDarkBg = Color(0xFF0E1A24);
const Color _kCardDark = Color(0xFF1D2D3B);

class IptvCategoriesScreen extends StatefulWidget {
  final IptvService iptvService;
  final VoidCallback onLogout;

  const IptvCategoriesScreen({
    super.key,
    required this.iptvService,
    required this.onLogout,
  });

  @override
  State<IptvCategoriesScreen> createState() => _IptvCategoriesScreenState();
}

class _IptvCategoriesScreenState extends State<IptvCategoriesScreen> {
  List<dynamic> _categories = [];
  List<dynamic> _filteredCategories = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    final cats = await widget.iptvService.getLiveCategories();
    if (mounted) {
      setState(() {
        _categories = cats;
        _filteredCategories = cats;
        _isLoading = false;
      });
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCategories = _categories.where((c) {
        final name = (c['category_name'] ?? '').toString().toLowerCase();
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
            top: -50,
            right: -30,
            child: Container(
              width: 180,
              height: 180,
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
                  padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [_kGold, _kGold.withValues(alpha: 0.6)],
                          ),
                        ),
                        child: const Icon(Icons.live_tv_rounded, color: Color(0xFF0E1A24), size: 22),
                      ),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'CATÉGORIES',
                            style: TextStyle(
                              color: _kGold,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2,
                            ),
                          ),
                          Text(
                            '${_categories.length} catégories disponibles',
                            style: TextStyle(color: textColor.withValues(alpha: 0.4), fontSize: 12),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Container(
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _kGold.withValues(alpha: 0.3)),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.logout_rounded, color: _kGold, size: 20),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                backgroundColor: isDark ? _kCardDark : Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                title: Text('Déconnexion', style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                                content: Text('Se déconnecter du serveur IPTV ?', style: TextStyle(color: textColor.withValues(alpha: 0.7))),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx),
                                    child: Text('Annuler', style: TextStyle(color: textColor.withValues(alpha: 0.5))),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pop(ctx);
                                      widget.onLogout();
                                    },
                                    child: const Text('Déconnexion', style: TextStyle(color: Colors.redAccent)),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Search bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(color: textColor, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Rechercher une catégorie...',
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
                const SizedBox(height: 16),

                // Content
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const CircularProgressIndicator(color: _kGold),
                              const SizedBox(height: 16),
                              Text('Chargement des catégories...', style: TextStyle(color: textColor.withValues(alpha: 0.4))),
                            ],
                          ),
                        )
                      : _filteredCategories.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.category_rounded, color: _kGold.withValues(alpha: 0.3), size: 48),
                                  const SizedBox(height: 12),
                                  Text('Aucune catégorie trouvée', style: TextStyle(color: textColor.withValues(alpha: 0.5))),
                                ],
                              ),
                            )
                          : GridView.builder(
                              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                childAspectRatio: 2.2,
                                crossAxisSpacing: 14,
                                mainAxisSpacing: 14,
                              ),
                              itemCount: _filteredCategories.length,
                              itemBuilder: (context, index) {
                                final cat = _filteredCategories[index];
                                final name = cat['category_name']?.toString() ?? 'Inconnu';
                                final id = cat['category_id']?.toString() ?? '';

                                return GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => IptvChannelsScreen(
                                          iptvService: widget.iptvService,
                                          categoryId: id,
                                          categoryName: name,
                                        ),
                                      ),
                                    );
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: isDark ? _kCardDark : Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(color: _kGold.withValues(alpha: 0.15)),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Stack(
                                      children: [
                                        // Subtle gold accent top-right
                                        Positioned(
                                          top: -8,
                                          right: -8,
                                          child: Container(
                                            width: 30,
                                            height: 30,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: _kGold.withValues(alpha: 0.08),
                                            ),
                                          ),
                                        ),
                                        Center(
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 36,
                                                  height: 36,
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(10),
                                                    color: _kGold.withValues(alpha: 0.12),
                                                  ),
                                                  child: Icon(Icons.folder_rounded, color: _kGold, size: 18),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    name,
                                                    style: TextStyle(
                                                      color: textColor,
                                                      fontSize: 13,
                                                      fontWeight: FontWeight.w700,
                                                      height: 1.2,
                                                    ),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
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
