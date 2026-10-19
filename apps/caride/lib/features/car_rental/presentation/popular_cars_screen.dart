import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_widgets/shared_widgets.dart';
import 'package:caride/features/car_rental/customer_rental_controller.dart';

/// Replica screen displaying Popular Vehicles sorted by highest bookings & ratings.
class PopularCarsScreen extends StatefulWidget {
  const PopularCarsScreen({super.key});

  @override
  State<PopularCarsScreen> createState() => _PopularCarsScreenState();
}

class _PopularCarsScreenState extends State<PopularCarsScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.text = customerRentalController.searchQuery;
    _searchController.addListener(() {
      customerRentalController.setSearchQuery(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: IconButton(
                      icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: primaryTextColor),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Popular Vehicles',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: primaryTextColor,
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar & Grid Content
            Expanded(
              child: ListenableBuilder(
                listenable: customerRentalController,
                builder: (context, _) {
                  // Sort vehicles by highest trip count & highest rating
                  final allVehicles = List<RentalVehicle>.from(customerRentalController.vehicles)
                    ..sort((a, b) {
                      final bMetric = (b.tripCount * 10) + ((b.rating ?? 0.0) * b.reviewCount);
                      final aMetric = (a.tripCount * 10) + ((a.rating ?? 0.0) * a.reviewCount);
                      return bMetric.compareTo(aMetric);
                    });

                  return CustomScrollView(
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      // Search bar & Filter
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                          child: Container(
                            height: 52,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurface : const Color(0xFFFAFAFA),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: TextField(
                              controller: _searchController,
                              textAlignVertical: TextAlignVertical.center,
                              style: TextStyle(
                                color: primaryTextColor,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: 'Search popular vehicles...',
                                hintStyle: TextStyle(
                                  color: isDark ? AppColors.textSecondaryDark : const Color(0xFF9CA3AF),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w400,
                                ),
                                prefixIcon: const Padding(
                                  padding: EdgeInsets.only(left: 18, right: 10),
                                  child: Icon(
                                    Icons.search_rounded,
                                    color: Color(0xFF9CA3AF),
                                    size: 22,
                                  ),
                                ),
                                prefixIconConstraints: const BoxConstraints(
                                  minWidth: 48,
                                  minHeight: 48,
                                ),
                                suffixIcon: customerRentalController.searchQuery.isNotEmpty
                                    ? GestureDetector(
                                        onTap: () {
                                          _searchController.clear();
                                          customerRentalController.setSearchQuery('');
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.only(right: 14),
                                          child: Icon(
                                            Icons.cancel_rounded,
                                            color: Color(0xFF9CA3AF),
                                            size: 20,
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Vehicles Grid
                      if (customerRentalController.isLoadingVehicles)
                        const SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 60),
                            child: Center(child: AppLoader()),
                          ),
                        )
                      else if (allVehicles.isEmpty)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 60),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.directions_car_filled_rounded, size: 54, color: AppColors.brand),
                                const SizedBox(height: 16),
                                Text(
                                  'No Popular Vehicles Found',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: primaryTextColor,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Try adjusting your search query.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                          sliver: SliverGrid(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 14,
                              crossAxisSpacing: 14,
                              childAspectRatio: 0.72,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final vehicle = allVehicles[index];
                                return _PopularGridVehicleCard(
                                  vehicle: vehicle,
                                  isDark: isDark,
                                  onTap: () {
                                    context.push(
                                      CustomerRoutePaths.rentalVehicleDetail,
                                      extra: vehicle,
                                    );
                                  },
                                );
                              },
                              childCount: allVehicles.length,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PopularGridVehicleCard extends StatelessWidget {
  const _PopularGridVehicleCard({
    required this.vehicle,
    required this.isDark,
    required this.onTap,
  });

  final RentalVehicle vehicle;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final v = vehicle;
    final lowestRate = v.lowestAvailableRate;
    final rateUnit = (v.dailySelfDriveRate > 0 || v.dailyWithDriverRate > 0)
        ? (lowestRate == v.dropOffRate ? '/Trip' : '/Day')
        : '/Trip';
    final primaryColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryColor = isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Image Area with Rating Chip
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
                    child: v.images.isNotEmpty
                        ? Image.network(
                            v.images.first,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                              child: const Icon(Icons.directions_car_rounded, size: 40, color: AppColors.brand),
                            ),
                          )
                        : Container(
                            color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                            child: const Icon(Icons.directions_car_rounded, size: 40, color: AppColors.brand),
                          ),
                  ),
                  // Rating Badge Top-Left
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.75),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, size: 13, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 3),
                          Text(
                            v.rating != null && v.rating! > 0
                                ? '${v.rating!.toStringAsFixed(1)}${v.reviewCount > 0 ? ' (${v.reviewCount})' : ''}'
                                : 'New',
                            style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Info Details
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    v.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${v.year} • ${v.category.label}',
                    style: TextStyle(fontSize: 11, color: secondaryColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${NgnFormat.currency(lowestRate)}$rateUnit',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: primaryColor,
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
