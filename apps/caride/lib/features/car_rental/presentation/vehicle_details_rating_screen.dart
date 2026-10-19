import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:design_system/design_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';

/// Screen displaying all customer ratings & reviews for a specific vehicle,
/// matching the provided design reference with star filter chips, search, and review cards.
class VehicleDetailsRatingScreen extends StatefulWidget {
  const VehicleDetailsRatingScreen({super.key, required this.vehicle});

  final RentalVehicle vehicle;

  @override
  State<VehicleDetailsRatingScreen> createState() =>
      _VehicleDetailsRatingScreenState();
}

class _VehicleDetailsRatingScreenState
    extends State<VehicleDetailsRatingScreen> {
  int _selectedStarFilter = 0; // 0 = All, 5, 4, 3, 2, 1
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggleLike(RentalReview review) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;
    final docRef =
        FirebaseFirestore.instance.collection('rental_reviews').doc(review.id);
    final isLiked = review.likedByUids.contains(uid);

    try {
      if (isLiked) {
        await docRef.update({
          'likedByUids': FieldValue.arrayRemove([uid]),
          'likeCount': FieldValue.increment(-1),
        });
      } else {
        await docRef.update({
          'likedByUids': FieldValue.arrayUnion([uid]),
          'likeCount': FieldValue.increment(1),
        });
      }
    } catch (e) {
      debugPrint('Error toggling review like: $e');
    }
  }

  String _formatTimeAgo(DateTime? date) {
    if (date == null) return 'Recently';
    final diff = DateTime.now().difference(date);
    if (diff.inDays >= 30) {
      final months = (diff.inDays / 30).floor();
      return '$months ${months == 1 ? 'month' : 'months'} ago';
    } else if (diff.inDays >= 7) {
      final weeks = (diff.inDays / 7).floor();
      return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
    } else if (diff.inDays >= 1) {
      return '${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'} ago';
    } else if (diff.inHours >= 1) {
      return '${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'} ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor =
        isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);
    final v = widget.vehicle;
    final ratingStr = (v.rating ?? 0.0) > 0 ? (v.rating ?? 0.0).toStringAsFixed(1) : 'New';
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Bar Header ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        border: Border.all(
                          color: isDark
                              ? AppColors.glassBorderDark
                              : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Icon(
                        Icons.chevron_left_rounded,
                        color: primaryTextColor,
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _isSearching
                        ? TextField(
                            controller: _searchController,
                            autofocus: true,
                            onChanged: (_) => setState(() {}),
                            style: TextStyle(color: primaryTextColor, fontSize: 16),
                            decoration: InputDecoration(
                              hintText: 'Search reviews...',
                              hintStyle: TextStyle(color: secondaryTextColor, fontSize: 14),
                              border: InputBorder.none,
                            ),
                          )
                        : Text(
                            '$ratingStr (${v.reviewCount} ${v.reviewCount == 1 ? 'review' : 'reviews'})',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: primaryTextColor,
                              letterSpacing: -0.3,
                            ),
                          ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isSearching = !_isSearching;
                        if (!_isSearching) _searchController.clear();
                      });
                    },
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        border: Border.all(
                          color: isDark
                              ? AppColors.glassBorderDark
                              : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Icon(
                        _isSearching ? Icons.close_rounded : Icons.search_rounded,
                        color: primaryTextColor,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Star Filter Chips Bar (★ All, ★ 5, ★ 4, ★ 3, ★ 2, ★ 1) ─────
            SizedBox(
              height: 42,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildStarChip(0, 'All', isDark),
                  const SizedBox(width: 8),
                  _buildStarChip(5, '5', isDark),
                  const SizedBox(width: 8),
                  _buildStarChip(4, '4', isDark),
                  const SizedBox(width: 8),
                  _buildStarChip(3, '3', isDark),
                  const SizedBox(width: 8),
                  _buildStarChip(2, '2', isDark),
                  const SizedBox(width: 8),
                  _buildStarChip(1, '1', isDark),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Live Stream of Vehicle Reviews ──────────────────────────────
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('rental_reviews')
                    .where('vehicleId', isEqualTo: v.id)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.brand,
                        strokeWidth: 2.5,
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  var reviews = docs
                      .map((doc) => RentalReview.fromMap(
                          doc.data() as Map<String, dynamic>, doc.id))
                      .toList();

                  // Sort by most recent
                  reviews.sort((a, b) {
                    final tA = a.createdAt ?? DateTime(2020);
                    final tB = b.createdAt ?? DateTime(2020);
                    return tB.compareTo(tA);
                  });

                  // Filter by star rating pill selection
                  if (_selectedStarFilter > 0) {
                    reviews = reviews
                        .where((r) => r.rating.round() == _selectedStarFilter)
                        .toList();
                  }

                  // Filter by search query
                  final query = _searchController.text.trim().toLowerCase();
                  if (query.isNotEmpty) {
                    reviews = reviews.where((r) {
                      return r.comment.toLowerCase().contains(query) ||
                          r.customerName.toLowerCase().contains(query);
                    }).toList();
                  }

                  if (reviews.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: AppColors.brand.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.star_outline_rounded,
                                size: 36,
                                color: AppColors.brand,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _selectedStarFilter > 0
                                  ? 'No $_selectedStarFilter-star reviews yet'
                                  : 'No reviews found',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: primaryTextColor,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Be the first to rate and review ${v.displayName} after your trip!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13.5,
                                color: secondaryTextColor,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
                    itemCount: reviews.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 20),
                    itemBuilder: (context, index) {
                      final r = reviews[index];
                      final isLiked = r.likedByUids.contains(currentUid);
                      final likesCount = r.likeCount;

                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isDark
                                ? AppColors.glassBorderDark
                                : const Color(0xFFF1F5F9),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Customer Name, Photo & Rating Badge
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: AppColors.brand,
                                  backgroundImage:
                                      (r.customerPhoto?.isNotEmpty ?? false)
                                          ? NetworkImage(r.customerPhoto!)
                                          : null,
                                  child: (r.customerPhoto?.isEmpty ?? true)
                                      ? Text(
                                          r.customerName.isNotEmpty
                                              ? r.customerName[0].toUpperCase()
                                              : 'C',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 16,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    r.customerName.isNotEmpty
                                        ? r.customerName
                                        : 'Customer',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: primaryTextColor,
                                    ),
                                  ),
                                ),
                                // Rating Pill Capsule (Matching reference mockup: star icon inside pill)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.white10
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isDark
                                          ? AppColors.glassBorderDark
                                          : const Color(0xFFE5E7EB),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.star_rounded,
                                        size: 14,
                                        color: Color(0xFF1E293B),
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        r.rating.toInt().toString(),
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF1E293B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            // Review Comment
                            if (r.comment.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Text(
                                r.comment,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                  color: primaryTextColor,
                                  height: 1.4,
                                ),
                              ),
                            ],

                            const SizedBox(height: 14),

                            // Bottom Actions Row: Real Heart Likes & Time Ago
                            Row(
                              children: [
                                GestureDetector(
                                  onTap: () => _toggleLike(r),
                                  child: Row(
                                    children: [
                                      Icon(
                                        isLiked
                                            ? Icons.favorite_rounded
                                            : Icons.favorite_border_rounded,
                                        size: 18,
                                        color: isLiked
                                            ? const Color(0xFFEF4444)
                                            : primaryTextColor,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '$likesCount',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: primaryTextColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 24),
                                Text(
                                  _formatTimeAgo(r.createdAt),
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: secondaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStarChip(int star, String label, bool isDark) {
    final isSelected = _selectedStarFilter == star;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedStarFilter = star;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brand
              : (isDark ? AppColors.darkSurface : Colors.white),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? AppColors.brand
                : (isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB)),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.star_rounded,
              size: 16,
              color: isSelected ? Colors.white : const Color(0xFF1E293B),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white : const Color(0xFF1E293B)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
