import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:caride/features/profile/cancel_ride_screen.dart';
import 'package:caride/features/profile/data/activity_repository.dart';
import 'package:caride/features/profile/rate_driver_screen.dart';
import 'package:caride/features/profile/trip_details_screen.dart';

class RideHistoryScreen extends StatefulWidget {
  const RideHistoryScreen({super.key});

  @override
  State<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends State<RideHistoryScreen> {
  final ActivityRepository _activityRepository = ActivityRepository();
  late final Stream<List<RideActivityRecord>> _activityStream;

  @override
  void initState() {
    super.initState();
    _activityStream = _activityRepository.watchActivity();
  }

  _RideTab? _tabForRecord(RideActivityRecord record) {
    return switch (record.tab) {
      RideActivityTab.ongoing => _RideTab.ongoing,
      RideActivityTab.completed => _RideTab.completed,
      RideActivityTab.canceled => null,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;

    return DefaultTabController(
      length: _RideTab.values.length,
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: AppBar(
          automaticallyImplyLeading: true,
          backgroundColor: backgroundColor,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
          title: Text(
            'Activity',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          bottom: TabBar(
            labelColor: AppColors.primaryGreen,
            unselectedLabelColor: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
            indicatorColor: AppColors.primaryGreen,
            indicatorSize: TabBarIndicatorSize.tab,
            labelStyle: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
            unselectedLabelStyle: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
            tabs: _RideTab.values
                .map((t) => Tab(text: t.label))
                .toList(growable: false),
          ),
        ),
        body: StreamBuilder<List<RideActivityRecord>>(
          stream: _activityStream,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Text(
                  'Unable to load activity right now.',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: isDark ? Colors.white : AppColors.slate900,
                  ),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
                ),
              );
            }
            final records = snapshot.data!;
            return TabBarView(
              children: _RideTab.values
                  .map((tab) => _tabBody(tab, records))
                  .toList(growable: false),
            );
          },
        ),
      ),
    );
  }

  Widget _tabBody(_RideTab tab, List<RideActivityRecord> allRecords) {
    final items = allRecords.where((o) => _tabForRecord(o) == tab).toList();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (items.isEmpty) {
      final String assetPath = switch (tab) {
        _RideTab.ongoing => 'lib/assets/icons/ongoing.png',
        _RideTab.completed => 'lib/assets/icons/completed.png',
      };

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                assetPath,
                width: 92,
                height: 92,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'No ${tab.label.toLowerCase()} rides yet.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: isDark ? Colors.white : AppColors.slate900,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.only(
        left: AppSpacing.md,
        right: AppSpacing.md,
        top: AppSpacing.sm,
        bottom: 80,
      ),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final item = items[index];
        return _RideActivityCard(
          item: item,
          tab: tab,
          onViewTrip: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => TripDetailsScreen(
                  rideId: item.id,
                ),
              ),
            );
          },
          onCancelRide: tab == _RideTab.ongoing
              ? () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => CancelRideScreen(rideId: item.id)),
                  );
                }
              : null,
          onRateDriver: tab == _RideTab.completed
              ? () {
                  Navigator.of(context, rootNavigator: true).push(
                    MaterialPageRoute(builder: (_) => RateDriverScreen(rideId: item.id)),
                  );
                }
              : null,
        );
      },
    );
  }
}

enum _RideTab {
  ongoing('Ongoing'),
  completed('Completed');

  const _RideTab(this.label);
  final String label;
}

class _RideActivityCard extends StatelessWidget {
  const _RideActivityCard({
    required this.item,
    required this.tab,
    this.onCancelRide,
    this.onViewTrip,
    this.onRateDriver,
  });

  final RideActivityRecord item;
  final _RideTab tab;
  final VoidCallback? onCancelRide;
  final VoidCallback? onViewTrip;
  final VoidCallback? onRateDriver;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE9EAF0);
    final primaryTextColor = isDark ? Colors.white : AppColors.slate900;
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);

    final amount = _formatNaira(item.amountNaira);
    final paidLabel = item.paid ? 'Paid' : 'Unpaid';

    return GestureDetector(
      onTap: onViewTrip,
      child: Container(
        decoration: BoxDecoration(
          color: cardBg,
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
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: (isDark ? Colors.grey[800] : Colors.grey[100])?.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              padding: const EdgeInsets.all(AppSpacing.xs),
              child: Image.asset(
                _rideTypeAsset(item.rideType),
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.dropoff,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: primaryTextColor,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        item.date,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: mutedTextColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.xs,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: item.paid
                              ? AppColors.primaryGreen.withValues(alpha: 0.12)
                              : (isDark ? Colors.grey[800] : const Color(0xFFF1F5F9)),
                          borderRadius: BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          paidLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: item.paid
                                ? AppColors.primaryGreen
                                : mutedTextColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 10,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    amount,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatNaira(double value) {
  final rounded = value.round().toString();
  final withCommas = rounded.replaceAllMapped(
    RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
  return '₦$withCommas';
}

String _rideTypeAsset(String rideType) {
  final cleaned = rideType.trim().toLowerCase();
  return switch (cleaned) {
    'comfort' => 'lib/assets/ride_options/comfort.png',
    'luxury' => 'lib/assets/ride_options/luxury.png',
    'courier' => 'lib/assets/ride_options/courier.png',
    _ => 'lib/assets/ride_options/regular.png',
  };
}
