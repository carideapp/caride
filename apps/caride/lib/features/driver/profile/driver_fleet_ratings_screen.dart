import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:design_system/design_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Screen displaying all customer ratings & reviews for a fleet's vehicles,
/// matching the exact structure and design aesthetics of ratings_screen.dart
/// and adhering to AGENTS.md rules (Lottie zip decoding, CaRide brand green, pill geometry).
class DriverFleetRatingsScreen extends StatefulWidget {
  const DriverFleetRatingsScreen({
    super.key,
    required this.fleet,
  });

  final FleetProfile fleet;

  @override
  State<DriverFleetRatingsScreen> createState() =>
      _DriverFleetRatingsScreenState();
}

class _DriverFleetRatingsScreenState extends State<DriverFleetRatingsScreen> {
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

  String _formatDate(DateTime? date) {
    if (date == null) return 'Recently';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final borderColor =
        isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final fleet = widget.fleet;
    final targetFleetId =
        fleet.fleetId.isNotEmpty ? fleet.fleetId : fleet.ownerUid;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Navigation Bar Header ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(
                  left: 20, right: 20, top: 14, bottom: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : Colors.white,
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
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Fleet Ratings & Reviews',
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

            // ── Reviews Stream ───────────────────────────────────────────────
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('rental_reviews')
                    .where('fleetId', isEqualTo: targetFleetId)
                    .snapshots(),
                builder: (context, snapshot) {
                  final isWaiting =
                      snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData;

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Error loading reviews: ${snapshot.error}',
                        style: TextStyle(color: primaryTextColor),
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  final reviews = docs
                      .map((d) => RentalReview.fromMap(d.data(), d.id))
                      .toList();

                  // Sort newest first
                  reviews.sort((a, b) {
                    final tA = a.createdAt ?? DateTime(2020);
                    final tB = b.createdAt ?? DateTime(2020);
                    return tB.compareTo(tA);
                  });

                  double sum = 0.0;
                  for (final r in reviews) {
                    sum += r.rating;
                  }
                  final averageRating =
                      reviews.isEmpty ? (fleet.rating > 0 ? fleet.rating : 0.0) : sum / reviews.length;

                  return ResponsiveContainer(
                    child: isWaiting
                        ? const _RatingsSkeletonLoader()
                        : ListView(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.sm,
                            ),
                            children: [
                              _buildOverallCard(
                                  context, averageRating, reviews.length),
                              const SizedBox(height: AppSpacing.lg),
                              if (reviews.isEmpty)
                                _buildEmptyState(context, fleet.businessName)
                              else ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpacing.xs,
                                  ),
                                  child: _buildReviewsHeader(
                                      context, reviews.length),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                ...reviews.map((r) {
                                  final isLiked =
                                      r.likedByUids.contains(currentUid);
                                  return _FleetReviewCard(
                                    review: r,
                                    isLiked: isLiked,
                                    onToggleLike: () => _toggleLike(r),
                                    formatDate: _formatDate,
                                  );
                                }),
                              ],
                              const SizedBox(height: AppSpacing.xl),
                            ],
                          ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallCard(
    BuildContext context,
    double averageRating,
    int totalRatings,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor =
        isDark ? AppColors.glassBorderDark : const Color(0xFFE9EAF0);

    final displayRating =
        averageRating > 0 ? averageRating.toStringAsFixed(1) : '0';
    final fullStars = averageRating.floor();
    final hasHalf = (averageRating - fullStars) >= 0.5;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? null
            : [
                const BoxShadow(
                  color: Color(0x0F0F172A),
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
      ),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Row(
        children: [
          Lottie.asset(
            'lib/assets/lottie/Trophy.lottie',
            width: 110,
            height: 110,
            fit: BoxFit.contain,
            decoder: (bytes) {
              return LottieComposition.decodeZip(
                bytes,
                filePicker: (files) {
                  return files.firstWhere(
                    (f) =>
                        f.name.startsWith('animations/') &&
                        f.name.endsWith('.json'),
                  );
                },
              );
            },
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Fleet Vehicle Score',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: isDark ? Colors.grey[300] : const Color(0xFF6E7191),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      displayRating,
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.slate900,
                      ),
                    ),
                    Text(
                      '/5',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color:
                            isDark ? Colors.grey[500] : const Color(0xFF8A90A6),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: List.generate(5, (i) {
                    IconData icon;
                    if (i < fullStars) {
                      icon = Icons.star_rounded;
                    } else if (i == fullStars && hasHalf) {
                      icon = Icons.star_half_rounded;
                    } else {
                      icon = Icons.star_outline_rounded;
                    }
                    return Icon(icon, color: const Color(0xFFFFB100), size: 20);
                  }),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  totalRatings == 0
                      ? 'No reviews yet'
                      : 'Based on $totalRatings review${totalRatings == 1 ? '' : 's'}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewsHeader(BuildContext context, int totalRatings) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Recent Reviews',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppColors.slate900,
          ),
        ),
        Text(
          '$totalRatings total',
          style: theme.textTheme.bodySmall?.copyWith(
            color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, String businessName) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor =
        isDark ? AppColors.glassBorderDark : const Color(0xFFE9EAF0);
    final bName = businessName.isNotEmpty ? businessName : 'this fleet';

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        children: [
          Icon(
            Icons.star_outline_rounded,
            size: 56,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No vehicle ratings yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: isDark ? Colors.white : AppColors.slate900,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Customer reviews and ratings for vehicles owned by $bName will appear here once trips are completed.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
            ),
          ),
        ],
      ),
    );
  }
}

class _FleetReviewCard extends StatelessWidget {
  const _FleetReviewCard({
    required this.review,
    required this.isLiked,
    required this.onToggleLike,
    required this.formatDate,
  });

  final RentalReview review;
  final bool isLiked;
  final VoidCallback onToggleLike;
  final String Function(DateTime?) formatDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor =
        isDark ? AppColors.glassBorderDark : const Color(0xFFE9EAF0);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor =
        isDark ? AppColors.textSecondaryDark : const Color(0xFF6E7191);

    final initial = review.customerName.isNotEmpty
        ? review.customerName[0].toUpperCase()
        : 'C';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: borderColor),
          boxShadow: isDark
              ? null
              : [
                  const BoxShadow(
                    color: Color(0x0F0F172A),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
        ),
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Customer Avatar, Customer Name & Vehicle Badge + Star Rating
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.brand.withValues(alpha: 0.1),
                  backgroundImage: (review.customerPhoto?.isNotEmpty ?? false)
                      ? NetworkImage(review.customerPhoto!)
                      : null,
                  child: (review.customerPhoto?.isEmpty ?? true)
                      ? Text(
                          initial,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.brand,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        review.customerName.isNotEmpty
                            ? review.customerName
                            : 'Valued Customer',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: primaryTextColor,
                        ),
                      ),
                      if (review.vehicleTitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          review.vehicleTitle,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.brand,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < review.rating.round()
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 16,
                      color: i < review.rating.round()
                          ? const Color(0xFFFFB100)
                          : Colors.grey[300],
                    ),
                  ),
                ),
              ],
            ),

            if (review.comment.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                review.comment,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.grey[300] : const Color(0xFF4A4D70),
                  height: 1.45,
                ),
              ),
            ],

            const SizedBox(height: AppSpacing.md),

            // Bottom Actions Row: Heart Likes & Formatted Date
            Row(
              children: [
                GestureDetector(
                  onTap: onToggleLike,
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
                        '${review.likeCount}',
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
                  formatDate(review.createdAt),
                  style: TextStyle(
                    fontSize: 12.5,
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingsSkeletonLoader extends StatefulWidget {
  const _RatingsSkeletonLoader();

  @override
  State<_RatingsSkeletonLoader> createState() => _RatingsSkeletonLoaderState();
}

class _RatingsSkeletonLoaderState extends State<_RatingsSkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: 0.4, end: 1.0).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final baseShimmerColor = isDark ? Colors.grey[800]! : Colors.grey[200]!;

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            children: [
              // Hero Overall Card Skeleton
              Container(
                height: 180,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(
                    color: isDark ? Colors.white10 : const Color(0xFFE9EAF0),
                  ),
                ),
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  children: [
                    Container(width: 120, height: 16, color: baseShimmerColor),
                    const SizedBox(height: AppSpacing.sm),
                    Container(width: 80, height: 48, color: baseShimmerColor),
                    const SizedBox(height: AppSpacing.sm),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        5,
                        (i) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Icon(Icons.star_rounded,
                              color: baseShimmerColor, size: 28),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(width: 150, height: 14, color: baseShimmerColor),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Reviews Header Skeleton
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(width: 110, height: 16, color: baseShimmerColor),
                    Container(width: 60, height: 14, color: baseShimmerColor),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // List of review card Skeletons
              ...List.generate(
                3,
                (i) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Container(
                    height: 110,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      border: Border.all(
                        color: isDark ? Colors.white10 : const Color(0xFFE9EAF0),
                      ),
                    ),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: baseShimmerColor,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                  width: 100, height: 14, color: baseShimmerColor),
                              const SizedBox(height: 6),
                              Container(
                                  width: 60, height: 10, color: baseShimmerColor),
                              const SizedBox(height: 12),
                              Container(
                                  width: double.infinity,
                                  height: 14,
                                  color: baseShimmerColor),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Row(
                          children: List.generate(
                            5,
                            (i) => Icon(Icons.star_rounded,
                                color: baseShimmerColor, size: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
