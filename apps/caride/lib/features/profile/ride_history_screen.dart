import 'package:caride/features/profile/cancel_ride_screen.dart';
import 'package:caride/features/profile/data/activity_repository.dart';
import 'package:caride/features/profile/rate_driver_screen.dart';
import 'package:caride/features/profile/trip_details_screen.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Redesigned Customer Ride History / Activity Screen adhering to CaRide Profile standards.
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final borderColor = isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);
    final canPop = Navigator.of(context).canPop();

    return DefaultTabController(
      length: _RideTab.values.length,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFFAFAFA),
        body: SafeArea(
          child: Column(
            children: [
              // Top Bar
              Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, top: 14, bottom: 8),
                child: Row(
                  children: [
                    if (canPop) ...[
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
                    ],
                    Text(
                      'Trip Activity',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: primaryTextColor,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ],
                ),
              ),

              // Tab Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: TabBar(
                    indicator: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: borderColor),
                    ),
                    indicatorSize: TabBarIndicatorSize.tab,
                    labelColor: AppColors.brand,
                    unselectedLabelColor: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                    labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    unselectedLabelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                    dividerColor: Colors.transparent,
                    tabs: _RideTab.values.map((t) => Tab(text: t.label)).toList(growable: false),
                  ),
                ),
              ),

              Expanded(
                child: StreamBuilder<List<RideActivityRecord>>(
                  stream: _activityStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Unable to load activity right now.',
                          style: TextStyle(
                            color: isDark ? Colors.white : const Color(0xFF111827),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(
                        child: CircularProgressIndicator(color: AppColors.brand),
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabBody(_RideTab tab, List<RideActivityRecord> allRecords) {
    final items = allRecords.where((o) => _tabForRecord(o) == tab).toList();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    if (items.isEmpty) {
      final String assetPath = switch (tab) {
        _RideTab.ongoing => 'lib/assets/icons/ongoing.png',
        _RideTab.completed => 'lib/assets/icons/completed.png',
      };

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                assetPath,
                width: 88,
                height: 88,
                fit: BoxFit.contain,
              ),
              const SizedBox(height: 18),
              Text(
                'No ${tab.label.toLowerCase()} trips',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Your ${tab.label.toLowerCase()} ride records will appear here.',
                style: TextStyle(
                  fontSize: 14,
                  color: secondaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    final amount = _formatNaira(item.amountNaira);
    final paidLabel = item.paid ? 'Paid' : 'Unpaid';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onViewTrip,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(16),
                ),
                padding: const EdgeInsets.all(8),
                child: Image.asset(
                  _rideTypeAsset(item.rideType),
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.dropoff,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: primaryTextColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: item.paid
                                ? AppColors.brand.withValues(alpha: 0.12)
                                : (isDark ? Colors.white10 : const Color(0xFFF3F4F6)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            paidLabel,
                            style: TextStyle(
                              color: item.paid ? AppColors.brand : secondaryTextColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.date,
                      style: TextStyle(
                        color: secondaryTextColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      amount,
                      style: const TextStyle(
                        color: AppColors.brand,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
