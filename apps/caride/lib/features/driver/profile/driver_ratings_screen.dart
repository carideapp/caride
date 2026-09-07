import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_widgets/shared_widgets.dart';

import 'data/driver_ratings_repository.dart';

class DriverRatingsScreen extends StatefulWidget {
  const DriverRatingsScreen({super.key});

  @override
  State<DriverRatingsScreen> createState() => _DriverRatingsScreenState();
}

class _DriverRatingsScreenState extends State<DriverRatingsScreen> {
  final _repo = DriverRatingsRepository();

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
        child: StreamBuilder<DriverRatingsSummary>(
          stream: _repo.streamRatingsSummary(),
          builder: (context, snapshot) {
            final isWaiting = snapshot.connectionState == ConnectionState.waiting;

            final summary = snapshot.data ??
                const DriverRatingsSummary(
                  averageRating: 0,
                  totalRatings: 0,
                  entries: [],
                );

            return ResponsiveContainer(
              child: isWaiting
                  ? const _RatingsSkeletonLoader()
                  : ListView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: AppSpacing.sm,
                      ),
                      children: [
                        _buildOverallCard(context, summary),
                        const SizedBox(height: AppSpacing.lg),
                        if (summary.entries.isEmpty)
                          _buildEmptyState(context)
                        else ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.xs,
                            ),
                            child: _buildReviewsHeader(context, summary),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          ...summary.entries.map((e) => _ReviewCard(
                                entry: e,
                                formatDate: _formatDate,
                              )),
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

  Widget _buildOverallCard(BuildContext context, DriverRatingsSummary summary) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE9EAF0);

    final avg = summary.averageRating;
    final displayRating = avg > 0 ? avg.toStringAsFixed(1) : '0';
    final fullStars = avg.floor();
    final hasHalf = (avg - fullStars) >= 0.5;

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
            'lib/assets/lottie/Premium_Quality.lottie',
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
                  'Your Average Rating',
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
                  summary.totalRatings == 0
                      ? 'No reviews yet'
                      : 'Based on ${summary.totalRatings} review${summary.totalRatings == 1 ? '' : 's'}',
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

  Widget _buildReviewsHeader(
      BuildContext context, DriverRatingsSummary summary) {
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
          '${summary.totalRatings} total',
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
            'Complete trips to start receiving ratings from passengers.',
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
  const _ReviewCard({required this.entry, required this.formatDate});

  final DriverRatingEntry entry;
  final String Function(DateTime) formatDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE9EAF0);

    final initial = entry.customerName.isNotEmpty
        ? entry.customerName[0].toUpperCase()
        : '?';

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
                        entry.customerName,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppColors.slate900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        formatDate(entry.ratedAt),
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
                      i < entry.rating
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      size: 16,
                      color: i < entry.rating
                          ? const Color(0xFFFFB100)
                          : Colors.grey[300],
                    ),
                  ),
                ),
              ],
            ),
            if (entry.dropoffLabel != null) ...[
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
                      'Ride to ${entry.dropoffLabel}',
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
            if (entry.comment != null && entry.comment!.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                entry.comment!,
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
