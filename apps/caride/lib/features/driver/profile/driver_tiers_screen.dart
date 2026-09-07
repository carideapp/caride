import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_widgets/shared_widgets.dart';

import 'data/driver_tier_repository.dart';

class DriverTiersScreen extends StatefulWidget {
  const DriverTiersScreen({super.key});

  @override
  State<DriverTiersScreen> createState() => _DriverTiersScreenState();
}

class _DriverTiersScreenState extends State<DriverTiersScreen> {
  final _repo = DriverTierRepository();

  static const Map<String, Color> _tierColors = {
    'bronze': Color(0xFFCD7F32),
    'silver': Color(0xFFC0C0C0),
    'gold': Color(0xFFFFD700),
    'platinum': Color(0xFFE5E4E2),
  };

  Color _colorForTier(String tierId) =>
      _tierColors[tierId] ?? const Color(0xFFCD7F32);

  int _orderForTier(String tierId, List<TierSetting> settings) {
    final match = settings.where((s) => s.id == tierId).toList();
    return match.isEmpty ? 1 : match.first.order;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark
        ? AppColors.darkBackground
        : AppColors.lightBackground;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          'Driver Tiers',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<DriverTierStats?>(
          stream: _repo.streamDriverTierStats(),
          builder: (context, statsSnap) {
            return StreamBuilder<List<TierSetting>>(
              stream: _repo.streamTierSettings(),
              builder: (context, tiersSnap) {
                final stats = statsSnap.data;
                final tiers = tiersSnap.data ?? [];

                if (statsSnap.connectionState == ConnectionState.waiting ||
                    tiersSnap.connectionState == ConnectionState.waiting) {
                  return const _TiersSkeletonLoader();
                }

                if (stats == null) {
                  return const Center(child: Text('No data available.'));
                }

                return _buildContent(context, stats, tiers);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    DriverTierStats stats,
    List<TierSetting> tiers,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final surfaceColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFFE9EAF0);

    final currentOrder = _orderForTier(stats.tier, tiers);
    final nextTier = tiers.where((t) => t.order == currentOrder + 1).toList();
    final hasNextTier = nextTier.isNotEmpty;

    return ResponsiveContainer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCurrentStatusCard(
              context,
              stats,
              tiers,
              isDark,
              surfaceColor,
              borderColor,
            ),
            const SizedBox(height: AppSpacing.lg),
            if (hasNextTier) ...[
              _buildProgressSection(
                context,
                stats,
                nextTier.first,
                isDark,
                surfaceColor,
                borderColor,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'All Tier Levels',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: isDark ? Colors.white : AppColors.slate900,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Complete more rides to unlock better commission rates',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? Colors.grey[400]
                          : const Color(0xFF6E7191),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
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
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Column(
                children: List.generate(tiers.length, (index) {
                  // Display from highest to lowest tier level
                  final tier = tiers.reversed.toList()[index];
                  final isCurrent = tier.id == stats.tier;
                  final isLocked = tier.order > currentOrder;
                  return _buildTierLevel(
                    context,
                    tier: tier,
                    isCurrent: isCurrent,
                    isLocked: isLocked,
                    isDark: isDark,
                  );
                }),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStatusCard(
    BuildContext context,
    DriverTierStats stats,
    List<TierSetting> tiers,
    bool isDark,
    Color surfaceColor,
    Color borderColor,
  ) {
    final theme = Theme.of(context);
    final currentTierSetting = tiers.where((t) => t.id == stats.tier).toList();
    final commissionPercent = currentTierSetting.isEmpty
        ? 20
        : currentTierSetting.first.commissionPercent;

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
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Row(
            children: [
              Lottie.asset(
                'lib/assets/lottie/Trophy.lottie',
                width: 130,
                height: 130,
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
                  children: [
                    Text(
                      '${stats.tier.toUpperCase()} TIER',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: 2,
                        color: isDark ? Colors.white : AppColors.slate900,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${stats.completedRides} trips completed',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark
                            ? Colors.grey[400]
                            : const Color(0xFF6E7191),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSimpleStat(
                context,
                '$commissionPercent%',
                'Commission',
                isDark,
              ),
              Container(
                width: 1,
                height: 30,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : const Color(0xFFE9EAF0),
              ),
              _buildSimpleStat(
                context,
                stats.averageRating > 0
                    ? stats.averageRating.toStringAsFixed(1)
                    : 'N/A',
                'Avg Rating',
                isDark,
              ),
              Container(
                width: 1,
                height: 30,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : const Color(0xFFE9EAF0),
              ),
              _buildSimpleStat(
                context,
                '${stats.totalRatings}',
                'Reviews',
                isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleStat(
    BuildContext context,
    String value,
    String label,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppColors.slate900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: isDark ? Colors.grey[400] : const Color(0xFF8A90A6),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressSection(
    BuildContext context,
    DriverTierStats stats,
    TierSetting nextTier,
    bool isDark,
    Color surfaceColor,
    Color borderColor,
  ) {
    final theme = Theme.of(context);
    final trips = stats.completedRides;
    final minTrips = nextTier.minTrips;
    final progress = minTrips > 0 ? (trips / minTrips).clamp(0.0, 1.0) : 1.0;

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: borderColor),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progress to ${nextTier.name}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : AppColors.slate900,
                ),
              ),
              Text(
                '${(progress * 100).toStringAsFixed(0)}%',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.primaryGreen,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: isDark
                  ? const Color(0xFF2C2C2C)
                  : const Color(0xFFF3F4F7),
              valueColor: const AlwaysStoppedAnimation<Color>(
                AppColors.primaryGreen,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildRequirementRow(
            context,
            Icons.local_taxi_rounded,
            '$trips / $minTrips trips completed',
            isDark,
          ),
          if (nextTier.minRating > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            _buildRequirementRow(
              context,
              Icons.star_rounded,
              '${stats.averageRating.toStringAsFixed(1)} / ${nextTier.minRating} rating required',
              isDark,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRequirementRow(
    BuildContext context,
    IconData icon,
    String text,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          icon,
          size: 18,
          color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? Colors.grey[300] : const Color(0xFF4A4D70),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTierLevel(
    BuildContext context, {
    required TierSetting tier,
    required bool isCurrent,
    required bool isLocked,
    required bool isDark,
  }) {
    final theme = Theme.of(context);
    final tierColor = _colorForTier(tier.id);

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: isCurrent
            ? AppColors.primaryGreen.withValues(alpha: 0.04)
            : (isDark
                  ? Colors.white.withValues(alpha: 0.02)
                  : const Color(0xFFF9FAFB)),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: isCurrent
              ? AppColors.primaryGreen.withValues(alpha: 0.2)
              : (isDark ? Colors.white12 : const Color(0xFFE9EAF0)),
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: tierColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              isLocked
                  ? Icons.lock_outline_rounded
                  : (isCurrent
                        ? Icons.check_circle_rounded
                        : Icons.workspace_premium_rounded),
              color: isLocked ? Colors.grey[400] : tierColor,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      tier.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : AppColors.slate900,
                      ),
                    ),
                    if (isCurrent) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen,
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: const Text(
                          'CURRENT',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${tier.tripsLabel}${tier.minRating > 0 ? ' · ${tier.ratingLabel}' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${tier.commissionPercent}%',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: isCurrent
                      ? AppColors.primaryGreen
                      : (isDark ? Colors.white : AppColors.slate900),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Commission',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.grey[400] : const Color(0xFF8A90A6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TiersSkeletonLoader extends StatefulWidget {
  const _TiersSkeletonLoader();

  @override
  State<_TiersSkeletonLoader> createState() => _TiersSkeletonLoaderState();
}

class _TiersSkeletonLoaderState extends State<_TiersSkeletonLoader>
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
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.sm,
            ),
            children: [
              // Current Status Card Skeleton
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: isDark ? Colors.white10 : const Color(0xFFE9EAF0),
                  ),
                ),
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: baseShimmerColor,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(width: 140, height: 20, color: baseShimmerColor),
                              const SizedBox(height: 12),
                              Container(width: 90, height: 14, color: baseShimmerColor),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Container(width: 60, height: 30, color: baseShimmerColor),
                        Container(width: 60, height: 30, color: baseShimmerColor),
                        Container(width: 60, height: 30, color: baseShimmerColor),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Progress Section Skeleton
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(
                    color: isDark ? Colors.white10 : const Color(0xFFE9EAF0),
                  ),
                ),
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(width: 150, height: 16, color: baseShimmerColor),
                        Container(width: 40, height: 16, color: baseShimmerColor),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Container(
                      width: double.infinity,
                      height: 8,
                      decoration: BoxDecoration(
                        color: baseShimmerColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Container(width: 220, height: 14, color: baseShimmerColor),
                    const SizedBox(height: AppSpacing.sm),
                    Container(width: 180, height: 14, color: baseShimmerColor),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Tier Levels Header Skeleton
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xs),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 120, height: 16, color: baseShimmerColor),
                    const SizedBox(height: 6),
                    Container(width: 250, height: 12, color: baseShimmerColor),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),

              // List of tier levels skeletons
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: isDark ? Colors.white10 : const Color(0xFFE9EAF0),
                  ),
                ),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Column(
                  children: List.generate(4, (index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: baseShimmerColor,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(width: 100, height: 14, color: baseShimmerColor),
                                const SizedBox(height: 6),
                                Container(width: 80, height: 10, color: baseShimmerColor),
                              ],
                            ),
                          ),
                          Container(width: 60, height: 28, color: baseShimmerColor),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
