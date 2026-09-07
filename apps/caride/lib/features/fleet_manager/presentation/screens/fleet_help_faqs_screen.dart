import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:url_launcher/url_launcher.dart';

/// Fleet Manager Help Center & FAQs screen strictly styled after UI/faqs.jpg, UI/contact-us.jpg and AGENTS.md.
/// Features dual tabs (FAQ and Contact Us), live search, expandable accordions, and real-time Firestore synchronization.
class FleetHelpFaqsScreen extends StatefulWidget {
  const FleetHelpFaqsScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  State<FleetHelpFaqsScreen> createState() => _FleetHelpFaqsScreenState();
}

class _FleetHelpFaqsScreenState extends State<FleetHelpFaqsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _searchQuery = '';
  int? _expandedFaqIndex;



  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTab.clamp(0, 1),
    );
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _launchUrl(String urlString) async {
    final uri = Uri.parse(urlString);
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      }
    } catch (_) {
      try {
        await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (_) {
        _showSnackBar('Could not open link: $urlString');
      }
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.brand,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final borderColor = isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final inputFill = isDark ? AppColors.darkBackground : const Color(0xFFF3F4F6);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: cardBg,
                      shape: BoxShape.circle,
                      border: Border.all(color: borderColor),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: primaryTextColor),
                      onPressed: () => context.pop(),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Help Center',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Tab Bar (FAQ & Contact Us) ──
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor, width: 1)),
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: AppColors.brand,
                indicatorWeight: 3,
                labelColor: AppColors.brand,
                unselectedLabelColor: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                labelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                unselectedLabelStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                tabs: const [
                  Tab(text: 'FAQ'),
                  Tab(text: 'Contact Us'),
                ],
              ),
            ),

            // ── Tab View Content ──
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: FAQ View (UI/faqs.jpg reference)
                  _buildFaqTabView(isDark, primaryTextColor, borderColor, cardBg, inputFill),

                  // Tab 2: Contact Us View (UI/contact-us.jpg reference)
                  _buildContactUsTabView(isDark, primaryTextColor, borderColor, cardBg),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab 1: FAQ Tab View ──
  Widget _buildFaqTabView(
    bool isDark,
    Color primaryTextColor,
    Color borderColor,
    Color cardBg,
    Color inputFill,
  ) {
    return Column(
      children: [
        const SizedBox(height: 12),
        // Search Bar (Pill geometry per AGENTS.md Rule 2)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
            decoration: BoxDecoration(
              color: inputFill,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  color: isDark ? AppColors.textSecondaryDark : const Color(0xFF9CA3AF),
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: TextStyle(fontSize: 14, color: primaryTextColor, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: 'Search FAQ',
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: isDark ? AppColors.textSecondaryDark : const Color(0xFF9CA3AF),
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () => _searchController.clear(),
                    child: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Live Firestore Stream from config/faqs document and collection/faqs
        Expanded(
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: _firestore.collection('config').doc('faqs').snapshots(),
            builder: (context, configSnap) {
              final Map<String, Map<String, String>> itemsMap = {};

              if (configSnap.hasData && configSnap.data!.exists) {
                final data = configSnap.data!.data();
                if (data != null && data['items'] is List) {
                  final list = data['items'] as List;
                  for (var item in list) {
                    if (item is Map) {
                      final category = (item['category'] as String?)?.toLowerCase() ?? 'fleet';
                      if (category == 'fleet' || category == 'all' || category == 'general') {
                        final q = item['question'] as String? ?? '';
                        final a = item['answer'] as String? ?? '';
                        if (q.isNotEmpty && a.isNotEmpty) {
                          itemsMap[q] = {'question': q, 'answer': a};
                        }
                      }
                    }
                  }
                }
              }

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _firestore.collection('faqs').snapshots(),
                builder: (context, colSnap) {
                  if (colSnap.hasData && colSnap.data!.docs.isNotEmpty) {
                    for (var doc in colSnap.data!.docs) {
                      final data = doc.data();
                      final category = (data['category'] as String?)?.toLowerCase() ?? 'fleet';
                      if (category == 'fleet' || category == 'all' || category == 'general') {
                        final q = data['question'] as String? ?? '';
                        final a = data['answer'] as String? ?? '';
                        if (q.isNotEmpty && a.isNotEmpty) {
                          itemsMap[q] = {'question': q, 'answer': a};
                        }
                      }
                    }
                  }

                  List<Map<String, String>> faqsList = itemsMap.values.toList();

                  // Apply Search Filter
                  if (_searchQuery.isNotEmpty) {
                    faqsList = faqsList.where((faq) {
                      final q = faq['question']?.toLowerCase() ?? '';
                      final a = faq['answer']?.toLowerCase() ?? '';
                      return q.contains(_searchQuery) || a.contains(_searchQuery);
                    }).toList();
                  }

                  if (faqsList.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _searchQuery.isNotEmpty ? Icons.search_off_rounded : Icons.help_outline_rounded,
                              size: 48,
                              color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _searchQuery.isNotEmpty
                                  ? 'No FAQs matched your search.'
                                  : 'No FAQs published by admin yet.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: faqsList.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = faqsList[index];
                  final isExpanded = _expandedFaqIndex == index;

                  return Container(
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isExpanded ? AppColors.brand : borderColor,
                        width: isExpanded ? 1.5 : 1,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        setState(() {
                          _expandedFaqIndex = isExpanded ? null : index;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(18.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item['question']!,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: primaryTextColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(
                                  isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                  color: isExpanded ? AppColors.brand : (isDark ? Colors.white54 : const Color(0xFF6B7280)),
                                  size: 22,
                                ),
                              ],
                            ),
                            if (isExpanded) ...[
                              const SizedBox(height: 12),
                              Divider(height: 1, color: borderColor),
                              const SizedBox(height: 12),
                              Text(
                                item['answer']!,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  color: isDark ? AppColors.textSecondaryDark : const Color(0xFF4B5563),
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    ),
  ],
);
  }

  // ── Tab 2: Contact Us Tab View (UI/contact-us.jpg reference) ──
  Widget _buildContactUsTabView(
    bool isDark,
    Color primaryTextColor,
    Color borderColor,
    Color cardBg,
  ) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('config').doc('appSupport').snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? {};
        final website = data['website'] as String? ?? 'https://www.caride.ng';
        final email = data['supportEmail'] as String? ?? 'support@caride.ng';
        final phone = data['supportPhone'] as String? ?? '+234 800 CARIDE';

        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            _buildContactChannelCard(
              title: 'WhatsApp Support',
              description: 'Chat directly with our 24/7 customer care team',
              icon: Icons.chat_bubble_outline_rounded,
              isDark: isDark,
              borderColor: borderColor,
              cardBg: cardBg,
              primaryTextColor: primaryTextColor,
              onTap: () => _launchUrl('https://wa.me/234800227433'),
            ),
            const SizedBox(height: 14),

            _buildContactChannelCard(
              title: 'Official Website',
              description: website,
              icon: Icons.language_rounded,
              isDark: isDark,
              borderColor: borderColor,
              cardBg: cardBg,
              primaryTextColor: primaryTextColor,
              onTap: () => _launchUrl(website.startsWith('http') ? website : 'https://$website'),
            ),
            const SizedBox(height: 14),

            _buildContactChannelCard(
              title: 'Email Support',
              description: email,
              icon: Icons.email_outlined,
              isDark: isDark,
              borderColor: borderColor,
              cardBg: cardBg,
              primaryTextColor: primaryTextColor,
              onTap: () => _launchUrl('mailto:$email'),
            ),
            const SizedBox(height: 14),

            _buildContactChannelCard(
              title: 'Customer Care Hotline',
              description: phone,
              icon: Icons.phone_outlined,
              isDark: isDark,
              borderColor: borderColor,
              cardBg: cardBg,
              primaryTextColor: primaryTextColor,
              onTap: () => _launchUrl('tel:${phone.replaceAll(' ', '')}'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildContactChannelCard({
    required String title,
    required String description,
    required IconData icon,
    required bool isDark,
    required Color borderColor,
    required Color cardBg,
    required Color primaryTextColor,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: AppColors.brand, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.keyboard_arrow_right_rounded,
                color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
