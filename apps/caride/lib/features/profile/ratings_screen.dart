import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_widgets/shared_widgets.dart';

class RatingsScreen extends StatefulWidget {
  const RatingsScreen({super.key});

  @override
  State<RatingsScreen> createState() => _RatingsScreenState();
}

class _RatingsScreenState extends State<RatingsScreen> {
  Stream<QuerySnapshot<Map<String, dynamic>>>? _ratingsStream;

  @override
  void initState() {
    super.initState();
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _ratingsStream = FirebaseFirestore.instance
          .collection('rides')
          .where('customerUid', isEqualTo: user.uid)
          .limit(100)
          .snapshots();
    }
  }

  String _formatDate(DateTime date) {
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
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          backgroundColor: backgroundColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          title: Text(
            'Ratings & Reviews',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: const Center(
          child: Text('Please sign in to view your ratings.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          'Ratings & Reviews',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _ratingsStream,
          builder: (context, snapshot) {
            final isWaiting = snapshot.connectionState == ConnectionState.waiting;

            if (snapshot.hasError) {
              return Center(
                child: Text('Error loading ratings: ${snapshot.error}'),
              );
            }

            final docs = snapshot.data?.docs ?? [];
            final ratedRides = docs.where((doc) {
              final data = doc.data();
              return data['customerRating'] != null;
            }).toList();

            ratedRides.sort((a, b) {
              final aTime = (a.data()['customerRatedAt'] as Timestamp?) ??
                  (a.data()['updatedAt'] as Timestamp?) ??
                  Timestamp.now();
              final bTime = (b.data()['customerRatedAt'] as Timestamp?) ??
                  (b.data()['updatedAt'] as Timestamp?) ??
                  Timestamp.now();
              return bTime.compareTo(aTime);
            });

            double sum = 0.0;
            for (final ride in ratedRides) {
              final rating = ride.data()['customerRating'];
              if (rating is num) {
                sum += rating.toDouble();
              }
            }
            final averageRating = ratedRides.isEmpty ? 0.0 : sum / ratedRides.length;

            return ResponsiveContainer(
              child: isWaiting
                  ? const _RatingsSkeletonLoader()
                  : ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: AppSpacing.sm,
                      ),
                      children: [
                        _buildOverallCard(context, averageRating, ratedRides.length),
                        const SizedBox(height: AppSpacing.lg),
                        if (ratedRides.isEmpty)
                          _buildEmptyState(context)
                        else ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                            ),
                            child: _buildReviewsHeader(context, ratedRides.length),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          ...ratedRides.map((e) {
                            final data = e.data();
                            final date = ((data['customerRatedAt'] as Timestamp?) ??
                                    (data['updatedAt'] as Timestamp?) ??
                                    Timestamp.now())
                                .toDate();
                            return _ReviewCard(
                              driverName: data['driverName'] as String? ?? 'Driver',
                              rating: (data['customerRating'] as num?)?.toInt() ?? 5,
                              comment: data['customerRatingComment'] as String?,
                              dropoffLabel: (data['dropoffLabel'] as String?) ??
                                  (data['dropoffAddress'] as String?),
                              ratedAt: date,
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
    );
  }

  Widget _buildOverallCard(
    BuildContext context,
    double averageRating,
    int totalRatings,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE9EAF0);

    final displayRating = averageRating > 0 ? averageRating.toStringAsFixed(1) : '0';
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
            width: 120,
            height: 120,
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
                  'Your Rider Score',
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
                        color: isDark ? Colors.grey[500] : const Color(0xFF8A90A6),
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

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE9EAF0);

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
            'No ratings yet',
            style: theme.textTheme.titleMedium?.copyWith(
              color: isDark ? Colors.white : AppColors.slate900,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Complete trips to start receiving ratings from drivers.',
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

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({
    required this.driverName,
    required this.rating,
    required this.comment,
    required this.dropoffLabel,
    required this.ratedAt,
    required this.formatDate,
  });

  final String driverName;
  final int rating;
  final String? comment;
  final String? dropoffLabel;
  final DateTime ratedAt;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE9EAF0);

    final initial = driverName.isNotEmpty ? driverName[0].toUpperCase() : '?';

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
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.1),
                  child: Text(
                    initial,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryGreen,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        driverName,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.slate900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatDate(ratedAt),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: List.generate(
                    5,
                    (i) => Icon(
                      i < rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      size: 16,
                      color: i < rating ? const Color(0xFFFFB100) : Colors.grey[300],
                    ),
                  ),
                ),
              ],
            ),
            if (dropoffLabel != null && dropoffLabel!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Ride to $dropoffLabel',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            if (comment != null && comment!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                comment!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.grey[300] : const Color(0xFF4A4D70),
                  height: 1.5,
                ),
              ),
            ],
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
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
                          child: Icon(Icons.star_rounded, color: baseShimmerColor, size: 28),
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
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
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
                              Container(width: 100, height: 14, color: baseShimmerColor),
                              const SizedBox(height: 6),
                              Container(width: 60, height: 10, color: baseShimmerColor),
                              const SizedBox(height: 12),
                              Container(width: double.infinity, height: 14, color: baseShimmerColor),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Row(
                          children: List.generate(
                            5,
                            (i) => Icon(Icons.star_rounded, color: baseShimmerColor, size: 14),
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
