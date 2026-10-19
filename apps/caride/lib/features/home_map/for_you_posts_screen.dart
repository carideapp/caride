import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_models/shared_models.dart';

/// Screen displaying all "For You" educational and safety articles, with category filtering and an empty state UI.
class ForYouPostsScreen extends StatefulWidget {
  const ForYouPostsScreen({super.key});

  @override
  State<ForYouPostsScreen> createState() => _ForYouPostsScreenState();
}

class _ForYouPostsScreenState extends State<ForYouPostsScreen> {
  String _selectedCategory = 'All';

  static final List<ForYouArticle> _fallbackArticles = [
    ForYouArticle(
      id: 'fallback-safety',
      title: 'Ride Safety: Verifying Your Vehicle & Driver PIN',
      shortDescription: 'Essential steps to confirm your driver before stepping in.',
      category: 'Safety',
      readTime: '3 min read',
      coverImageUrl:
          'https://images.unsplash.com/photo-1549317661-bd32c8ce0db2?auto=format&fit=crop&w=800&q=80',
      content: '''
### Stay Safe on Every Trip

At CaRide, passenger safety is our top priority. Every driver on our platform undergoes background screening and vehicle inspection before they can accept trips.

### 1. Verify Driver License Plate & Vehicle Model
Before getting in, always match the license plate number, vehicle make, and model displayed in your app with the vehicle in front of you.

### 2. Check Driver Photo & Name
Confirm the driver matches their profile photo. Never board a vehicle if a different person is driving.

### 3. Share Your Live Trip Status
Use our built-in trip sharing tool to send your live location and route directly to family or loved ones with a single tap.

### 4. Direct Emergency Assistance
If you ever feel unsafe, use the emergency SOS button available on your active trip screen for immediate 24/7 security dispatch.
''',
    ),
    ForYouArticle(
      id: 'fallback-rental',
      title: 'Car Rentals 101: How CaRide Vehicle Hire Works',
      shortDescription:
          'Everything you need to know about self-drive & chauffeur rentals.',
      category: 'Guide',
      readTime: '4 min read',
      coverImageUrl:
          'https://images.unsplash.com/photo-1503376780353-7e6692767b70?auto=format&fit=crop&w=800&q=80',
      content: '''
### Renting Made Simple & Transparent

Whether you need a luxury SUV for an event, a sedan for client meetings, or a commercial bus for interstate travel, CaRide Car Rental connects you with vetted fleet partners.

### Flexible Booking Options
* **With Chauffeur**: Enjoy relaxed travel with an experienced, professional driver.
* **Self Drive**: Full independence and privacy for your journey.

### Step-by-Step Rental Flow
1. **Browse Fleet Catalog**: Choose category, price range, and location.
2. **Submit Reservation**: Select dates and pickup hours.
3. **Fleet Manager Confirmation**: The vehicle owner confirms availability within minutes.
4. **Transparent Payment**: Pay securely via CaRide Wallet or direct card payment.
5. **Start Your Trip**: Use your unique 4-digit PIN code upon vehicle handover.
''',
    ),
    ForYouArticle(
      id: 'fallback-courier',
      title: 'Sending Items with CaRide Courier',
      shortDescription:
          'Quick door-to-door package delivery tips for seamless sending.',
      category: 'Tips',
      readTime: '2 min read',
      coverImageUrl:
          'https://images.unsplash.com/photo-1580674684081-7617fbf3d745?auto=format&fit=crop&w=800&q=80',
      content: '''
### Fast, Tracked Parcel Delivery

Need documents, electronics, or personal items delivered across town? CaRide Courier provides secure, point-to-point delivery with real-time driver tracking.

### Best Practices Before Dispatching:
* **Secure Packaging**: Ensure fragile items are properly cushioned and sealed.
* **Accurate Recipient Details**: Double check the recipient's phone number and dropoff landmark so the driver can connect effortlessly.
* **Live In-App Tracking**: Watch the courier driver’s progress in real-time until delivery confirmation.
''',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor =
        isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor =
        isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Header Bar ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: borderColor),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: primaryTextColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Blog & Articles',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: primaryTextColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),

            // ── Category Filter Pills ───────────────────────────────────────
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('for_you_articles')
                  .where('isActive', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                List<ForYouArticle> allArticles = [];
                if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
                  allArticles = snapshot.data!.docs
                      .map((doc) => ForYouArticle.fromMap(doc.data(), doc.id))
                      .toList();
                }
                if (allArticles.isEmpty) {
                  allArticles = _fallbackArticles;
                }

                // Collect categories dynamically
                final categoriesSet = <String>{'All'};
                for (final a in allArticles) {
                  if (a.category.trim().isNotEmpty) {
                    categoriesSet.add(a.category.trim());
                  }
                }
                final categories = categoriesSet.toList();

                // Filter items
                final filteredArticles = _selectedCategory == 'All'
                    ? allArticles
                    : allArticles
                        .where((a) =>
                            a.category.trim().toLowerCase() ==
                            _selectedCategory.toLowerCase())
                        .toList();

                return Expanded(
                  child: Column(
                    children: [
                      // Category Filter Horizontal List
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        child: Row(
                          children: categories.map((cat) {
                            final isSelected = _selectedCategory == cat;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ChoiceChip(
                                label: Text(cat),
                                selected: isSelected,
                                selectedColor: AppColors.brand,
                                backgroundColor: isDark
                                    ? AppColors.darkSurface
                                    : const Color(0xFFF3F4F6),
                                labelStyle: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected
                                      ? Colors.white
                                      : (isDark
                                          ? AppColors.textSecondaryDark
                                          : const Color(0xFF4B5563)),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                  side: BorderSide(
                                    color: isSelected
                                        ? AppColors.brand
                                        : borderColor,
                                  ),
                                ),
                                showCheckmark: false,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() => _selectedCategory = cat);
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // List View or Empty State
                      Expanded(
                        child: filteredArticles.isEmpty
                            ? _buildEmptyState(isDark, secondaryTextColor)
                            : ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  8,
                                  20,
                                  28,
                                ),
                                physics: const BouncingScrollPhysics(),
                                itemCount: filteredArticles.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 16),
                                itemBuilder: (context, index) {
                                  final article = filteredArticles[index];
                                  return _buildArticleCard(
                                    context,
                                    article,
                                    isDark,
                                    surfaceColor,
                                    borderColor,
                                    primaryTextColor,
                                    secondaryTextColor,
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── Clean Empty State using history.png ─────────────────────────────────
  Widget _buildEmptyState(bool isDark, Color secondaryTextColor) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: Image.asset(
                'lib/assets/icons/history.png',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.article_outlined,
                  size: 40,
                  color: AppColors.brand,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Tips Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No articles are currently available in this category. Check back soon for new safety guides and tips!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: secondaryTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Card Item ────────────────────────────────────────────────────────────
  Widget _buildArticleCard(
    BuildContext context,
    ForYouArticle article,
    bool isDark,
    Color surfaceColor,
    Color borderColor,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    return GestureDetector(
      onTap: () {
        context.push(
          CustomerRoutePaths.forYouDetail,
          extra: article,
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: borderColor),
        ),
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            // Cover Image Thumbnail with Category Badge
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 100,
                height: 90,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    article.coverImageUrl.isNotEmpty
                        ? Image.network(
                            article.coverImageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _cardPlaceholder(),
                          )
                        : _cardPlaceholder(),
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          article.category.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    article.title,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: primaryTextColor,
                      letterSpacing: -0.2,
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    article.shortDescription,
                    style: TextStyle(
                      fontSize: 12,
                      color: secondaryTextColor,
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cardPlaceholder() {
    return Container(
      color: AppColors.brand.withValues(alpha: 0.08),
      child: const Center(
        child: Icon(
          Icons.menu_book_rounded,
          size: 32,
          color: AppColors.brand,
        ),
      ),
    );
  }
}
