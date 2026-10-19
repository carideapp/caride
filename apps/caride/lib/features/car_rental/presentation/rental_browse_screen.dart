import 'dart:math' as math;
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_widgets/shared_widgets.dart';
import 'package:caride/features/car_rental/customer_rental_controller.dart';

/// Redesigned Customer Car Rental Search & Browse Screen.
/// Matches the attached UI mockup with clean top search bar, brand emblems,
/// 2-column "Recommend For You" grid, "Our Popular Cars" horizontal carousel,
/// and full comprehensive Filter Bottom Sheet.
class RentalBrowseScreen extends StatefulWidget {
  const RentalBrowseScreen({super.key});

  @override
  State<RentalBrowseScreen> createState() => _RentalBrowseScreenState();
}

class _RentalBrowseScreenState extends State<RentalBrowseScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  late final AnimationController _animController;
  late final Animation<double> _fadeAnim;

  static const List<String> _cities = [
    'All Cities',
    'Abuja',
    'Lagos',
    'Port Harcourt',
    'Kano',
    'Ibadan',
    'Enugu',
    'Benin City',
    'Asaba',
    'Warri',
    'Calabar',
    'Uyo',
    'Owerri',
    'Kaduna',
    'Jos',
  ];

  static const List<_BrandItem> _brands = [
    _BrandItem(name: 'ALL', iconType: _BrandIconType.all),
    _BrandItem(name: 'Ferrari', iconType: _BrandIconType.ferrari),
    _BrandItem(name: 'Tesla', iconType: _BrandIconType.tesla),
    _BrandItem(name: 'BMW', iconType: _BrandIconType.bmw),
    _BrandItem(name: 'Lamborghini', iconType: _BrandIconType.lamborghini),
    _BrandItem(name: 'Mercedes', iconType: _BrandIconType.mercedes),
    _BrandItem(name: 'Toyota', iconType: _BrandIconType.toyota),
    _BrandItem(name: 'Rolls-Royce', iconType: _BrandIconType.rollsRoyce),
    _BrandItem(name: 'Range Rover', iconType: _BrandIconType.rangeRover),
    _BrandItem(name: 'Lexus', iconType: _BrandIconType.lexus),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      customerRentalController.init();
    });

    _searchController.addListener(() {
      customerRentalController.setSearchQuery(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animController.dispose();
    super.dispose();
  }

  void _openFilterSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RentalFilterBottomSheet(
        cities: _cities,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // ── Top Navigation Bar ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      // Circular Back Button per AGENTS.md (only when pushed)
                      if (Navigator.of(context).canPop())
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark ? AppColors.darkSurface : Colors.white,
                              border: Border.all(
                                color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                              ),
                              boxShadow: isDark
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: 0.03),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                            ),
                            child: Icon(
                              Icons.chevron_left_rounded,
                              color: primaryTextColor,
                              size: 26,
                            ),
                          ),
                        )
                      else
                        const SizedBox(width: 44, height: 44),
                      Expanded(
                        child: Center(
                          child: Text(
                            'Search',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: primaryTextColor,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ),
                      // Circular Filter / More Options Button
                      GestureDetector(
                        onTap: () => _openFilterSheet(context),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark ? AppColors.darkSurface : Colors.white,
                            border: Border.all(
                              color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                            ),
                            boxShadow: isDark
                                ? null
                                : [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.03),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                          ),
                          child: Icon(
                            Icons.more_horiz_rounded,
                            color: primaryTextColor,
                            size: 22,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Search Bar & Filter Button ─────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Row(
                    children: [
                      // Search Input Field (Pill Shape)
                      Expanded(
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
                              hintText: 'Search your dream car...',
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
                              suffixIcon: ListenableBuilder(
                                listenable: customerRentalController,
                                builder: (_, __) => customerRentalController.searchQuery.isNotEmpty
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
                              ),
                              suffixIconConstraints: const BoxConstraints(
                                minWidth: 38,
                                minHeight: 48,
                              ),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Filter Button (Circular with active dot)
                      GestureDetector(
                        onTap: () => _openFilterSheet(context),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark ? AppColors.darkSurface : Colors.white,
                                border: Border.all(
                                  color: isDark
                                      ? AppColors.glassBorderDark
                                      : const Color(0xFFE5E7EB),
                                ),
                                boxShadow: isDark
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.03),
                                          blurRadius: 8,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                              ),
                              child: Icon(
                                Icons.tune_rounded,
                                color: primaryTextColor,
                                size: 22,
                              ),
                            ),
                            ListenableBuilder(
                              listenable: customerRentalController,
                              builder: (_, __) {
                                if (!customerRentalController.hasActiveFilters) {
                                  return const SizedBox.shrink();
                                }
                                return Positioned(
                                  top: 3,
                                  right: 3,
                                  child: Container(
                                    width: 11,
                                    height: 11,
                                    decoration: BoxDecoration(
                                      color: AppColors.brand,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isDark ? AppColors.darkSurface : Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Brand Chips Row (Directly Below Search Bar) ────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 22),
                  child: ListenableBuilder(
                    listenable: customerRentalController,
                    builder: (_, __) => SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: _brands.map((brand) {
                          final isAll = brand.name == 'ALL';
                          final isSelected = isAll
                              ? customerRentalController.selectedBrand == null
                              : customerRentalController.selectedBrand?.toLowerCase() ==
                                  brand.name.toLowerCase();

                          return GestureDetector(
                            onTap: () {
                              if (isAll) {
                                customerRentalController.setBrand(null);
                              } else {
                                customerRentalController.setBrand(brand.name);
                              }
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.only(right: 12),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? (isDark ? Colors.white : const Color(0xFF1E293B))
                                    : (isDark ? AppColors.darkSurface : Colors.white),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: isSelected
                                      ? (isDark ? Colors.white : const Color(0xFF1E293B))
                                      : (isDark
                                          ? AppColors.glassBorderDark
                                          : const Color(0xFFE5E7EB)),
                                ),
                                boxShadow: isDark
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.03),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _BrandLogoBadge(
                                    brand: brand,
                                    isSelected: isSelected,
                                    isDark: isDark,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    brand.name,
                                    style: TextStyle(
                                      color: isSelected
                                          ? (isDark ? const Color(0xFF111827) : Colors.white)
                                          : (isDark
                                              ? AppColors.textSecondaryDark
                                              : const Color(0xFF4B5563)),
                                      fontSize: 13,
                                      fontWeight:
                                          isSelected ? FontWeight.w800 : FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),

              // ── Section 1: "Our Popular Cars" ──────────────────────────────
              ListenableBuilder(
                listenable: customerRentalController,
                builder: (context, _) {
                  final all = customerRentalController.allVehiclesUnfiltered;
                  if (all.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());

                  // Show up to 5 cars for popular horizontal carousel
                  final popularCars = List<RentalVehicle>.from(all)
                    ..sort((a, b) {
                      final bScore = (b.tripCount * 10) + ((b.rating ?? 0.0) * b.reviewCount);
                      final aScore = (a.tripCount * 10) + ((a.rating ?? 0.0) * a.reviewCount);
                      return bScore.compareTo(aScore);
                    });
                  final topPopular = popularCars.take(5).toList();

                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Our Popular Cars',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: primaryTextColor,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    context.push(CustomerRoutePaths.popularCars);
                                  },
                                  child: Text(
                                    'View All',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.brand,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            height: 104,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.symmetric(horizontal: 20),
                              physics: const BouncingScrollPhysics(),
                              itemCount: topPopular.length,
                              separatorBuilder: (_, __) => const SizedBox(width: 14),
                              itemBuilder: (context, index) {
                                final v = topPopular[index];
                                return _PopularCarCard(
                                  vehicle: v,
                                  isDark: isDark,
                                  onTap: () => context.push(
                                    CustomerRoutePaths.rentalVehicleDetail,
                                    extra: v,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // ── Section 2 Header: "Recommend For You" ──────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recommend For You',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: primaryTextColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                      // Removed "View All" beside Recommend For You per requirements
                    ],
                  ),
                ),
              ),

              // ── Recommend For You 2-Column Grid ────────────────────────────
              ListenableBuilder(
                listenable: customerRentalController,
                builder: (context, _) {
                  if (customerRentalController.isLoadingVehicles) {
                    return const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: CircularProgressIndicator(color: AppColors.brand),
                        ),
                      ),
                    );
                  }

                  final vehicles = customerRentalController.vehicles;

                  if (vehicles.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 36),
                        child: Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.glassBorderDark
                                  : const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.brand.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.directions_car_rounded,
                                  size: 38,
                                  color: AppColors.brand,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                'No vehicles match your filters',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: primaryTextColor,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Try clearing some filters or changing your location.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: secondaryTextColor,
                                ),
                              ),
                              const SizedBox(height: 16),
                              TextButton(
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.brand,
                                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  side: BorderSide(color: AppColors.brand.withValues(alpha: 0.3)),
                                ),
                                onPressed: () {
                                  customerRentalController.clearAllFilters();
                                },
                                child: const Text(
                                  'Clear All Filters',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverGrid(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.69,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 16,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final vehicle = vehicles[index];
                          return _MockupVehicleCard(
                            vehicle: vehicle,
                            isDark: isDark,
                            onTap: () => context.push(
                              CustomerRoutePaths.rentalVehicleDetail,
                              extra: vehicle,
                            ),
                          );
                        },
                        childCount: vehicles.length,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── 2-Column Mockup Vehicle Card ─────────────────────────────────────────────

class _MockupVehicleCard extends StatelessWidget {
  const _MockupVehicleCard({
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
    final isFav = customerRentalController.isFavorite(v.id);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Car Image Top Area with Soft Background ─────────────────────
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF222222) : const Color(0xFFF3F4F6),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(21)),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: _buildVehiclePhoto(v.images, isDark),
                  ),
                  // Top Left Badges: Rating & Review Count (+ Drop-Off if applicable)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Ratings & Review badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 4,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.star_rounded,
                                size: 12,
                                color: Color(0xFFF59E0B),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                v.reviewCount > 0
                                    ? '${(v.rating ?? 0.0).toStringAsFixed(1)} (${v.reviewCount})'
                                    : ((v.rating ?? 0.0) > 0
                                        ? (v.rating ?? 0.0).toStringAsFixed(1)
                                        : 'New'),
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (v.allowsDropOff) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: AppColors.brand,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.flight_land_rounded, size: 11, color: Colors.white),
                                SizedBox(width: 3),
                                Text(
                                  'Drop-Off',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    letterSpacing: -0.1,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Floating Favorite Heart Button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => customerRentalController.toggleFavorite(v.id),
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? const Color(0xFF333333) : Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          size: 16,
                          color: isFav ? const Color(0xFFEF4444) : const Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Vehicle Information ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title
                  Text(
                    v.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: primaryColor,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 4),

                  // Category and Specs Tag
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.brand.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          v.category.label,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.brand,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Location
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_outlined,
                        size: 13,
                        color: Color(0xFF9CA3AF),
                      ),
                      const SizedBox(width: 3),
                      Expanded(
                        child: Text(
                          v.city.isNotEmpty ? '${v.city}, Nigeria' : 'Nigeria',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF9CA3AF),
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Price
                  Text(
                    '${NgnFormat.currency(lowestRate)}$rateUnit',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: primaryColor,
                      letterSpacing: -0.2,
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

  static Widget _buildVehiclePhoto(List<String> images, bool isDark) {
    final validUrl = images.firstWhere(
      (url) => url.trim().isNotEmpty,
      orElse: () => '',
    );

    if (validUrl.isEmpty) {
      return _carPlaceholder(isDark);
    }

    if (validUrl.startsWith('http://') || validUrl.startsWith('https://')) {
      return Image.network(
        validUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _carPlaceholder(isDark),
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;
          return Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                    : null,
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.brand),
              ),
            ),
          );
        },
      );
    } else {
      return Image.asset(
        validUrl,
        width: double.infinity,
        height: double.infinity,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _carPlaceholder(isDark),
      );
    }
  }

  static Widget _carPlaceholder(bool isDark) {
    return Container(
      color: isDark ? const Color(0xFF222222) : const Color(0xFFF3F4F6),
      child: Center(
        child: Icon(
          Icons.directions_car_filled_rounded,
          size: 44,
          color: isDark ? Colors.white24 : const Color(0xFFCBD5E1),
        ),
      ),
    );
  }
}

// ── Horizontal "Our Popular Cars" Card ───────────────────────────────────────

class _PopularCarCard extends StatelessWidget {
  const _PopularCarCard({
    required this.vehicle,
    required this.isDark,
    required this.onTap,
  });

  final RentalVehicle vehicle;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final lowestRate = vehicle.lowestAvailableRate;
    final rateUnit = (vehicle.dailySelfDriveRate > 0 || vehicle.dailyWithDriverRate > 0)
        ? (lowestRate == vehicle.dropOffRate ? '/Trip' : '/Day')
        : '/Trip';
    final primaryColor = isDark ? Colors.white : const Color(0xFF111827);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
          ),
          boxShadow: isDark
              ? null
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            // Left Image Box
            Container(
              width: 86,
              height: 76,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF222222) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(14),
              ),
              clipBehavior: Clip.antiAlias,
              child: _MockupVehicleCard._buildVehiclePhoto(vehicle.images, isDark),
            ),
            const SizedBox(width: 12),
            // Right Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    vehicle.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: primaryColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (vehicle.rating != null && vehicle.rating! > 0)
                    Row(
                      children: [
                        Text(
                          vehicle.rating!.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                        const SizedBox(width: 3),
                        const Icon(
                          Icons.star_rounded,
                          size: 14,
                          color: Color(0xFFF59E0B),
                        ),
                      ],
                    )
                  else
                    Text(
                      '${vehicle.year} • ${vehicle.category.label}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF9CA3AF),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    '${NgnFormat.currency(lowestRate)}$rateUnit',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
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

// ── Brand Item Model & Logo Badge ────────────────────────────────────────────

enum _BrandIconType {
  all,
  ferrari,
  tesla,
  bmw,
  lamborghini,
  mercedes,
  toyota,
  rollsRoyce,
  rangeRover,
  lexus,
}

class _BrandItem {
  const _BrandItem({required this.name, required this.iconType});
  final String name;
  final _BrandIconType iconType;
}

class _BrandLogoBadge extends StatelessWidget {
  const _BrandLogoBadge({
    required this.brand,
    required this.isSelected,
    required this.isDark,
  });

  final _BrandItem brand;
  final bool isSelected;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    Color circleBg;
    Color iconColor;

    if (isSelected) {
      circleBg = isDark ? const Color(0xFF111827) : Colors.white;
      iconColor = isDark ? Colors.white : const Color(0xFF1E293B);
    } else {
      circleBg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF3F4F6);
      iconColor = isDark ? Colors.white70 : const Color(0xFF1F2937);
    }

    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: circleBg,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: _buildIcon(iconColor),
      ),
    );
  }

  Widget _buildIcon(Color color) {
    switch (brand.iconType) {
      case _BrandIconType.all:
        return Icon(Icons.motion_photos_on_rounded, size: 16, color: color);
      case _BrandIconType.tesla:
        return Text(
          'T',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 13,
            fontFamily: 'sans-serif',
          ),
        );
      case _BrandIconType.ferrari:
        return Icon(Icons.bolt_rounded, size: 15, color: color);
      case _BrandIconType.bmw:
        return Icon(Icons.pie_chart_rounded, size: 14, color: color);
      case _BrandIconType.lamborghini:
        return Icon(Icons.shield_rounded, size: 14, color: color);
      case _BrandIconType.mercedes:
        return Icon(Icons.stars_rounded, size: 15, color: color);
      case _BrandIconType.toyota:
        return Icon(Icons.radio_button_checked_rounded, size: 14, color: color);
      case _BrandIconType.rollsRoyce:
        return Text(
          'RR',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 10,
          ),
        );
      case _BrandIconType.rangeRover:
        return Icon(Icons.terrain_rounded, size: 14, color: color);
      case _BrandIconType.lexus:
        return Text(
          'L',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        );
    }
  }
}

// ── Redesigned Filter Bottom Sheet (Matching Attached UI Mockup) ─────────────

class _RentalFilterBottomSheet extends StatefulWidget {
  const _RentalFilterBottomSheet({
    required this.cities,
  });

  final List<String> cities;

  @override
  State<_RentalFilterBottomSheet> createState() => _RentalFilterBottomSheetState();
}

class _RentalFilterBottomSheetState extends State<_RentalFilterBottomSheet> {
  // Filter States matching the mockup & available RentalVehicle fields
  late String _typeOfCar; // 'all' | 'regular' | 'luxury'
  late RangeValues _priceRange;
  late String _rentalTime; // 'day' | 'hour' | 'weekly' | 'monthly'
  late String _selectedCity;
  String? _selectedColor;
  int? _selectedSeats;
  String? _selectedFuel;

  // Available options
  static const List<Map<String, dynamic>> _colorOptions = [
    {'name': 'White', 'color': Colors.white, 'border': Color(0xFFD1D5DB)},
    {'name': 'Gray', 'color': Color(0xFF9CA3AF), 'border': Colors.transparent},
    {'name': 'Blue', 'color': Color(0xFF2563EB), 'border': Colors.transparent},
    {'name': 'Black', 'color': Color(0xFF111827), 'border': Colors.transparent},
    {'name': 'Red', 'color': Color(0xFFDC2626), 'border': Colors.transparent},
    {'name': 'Silver', 'color': Color(0xFFCBD5E1), 'border': Colors.transparent},
  ];

  static const List<int> _seatOptions = [2, 4, 6, 8];
  static const List<String> _fuelOptions = ['Electric', 'Petrol', 'Diesel', 'Hybrid'];

  // Histogram mock distribution bar heights (relative 0.15 - 1.0)
  static const List<double> _histogramBars = [
    0.15, 0.20, 0.30, 0.25, 0.35, 0.40, 0.50, 0.65, 0.85, 1.00,
    0.90, 0.75, 0.80, 0.60, 0.70, 0.85, 0.65, 0.55, 0.70, 0.80,
    0.95, 0.85, 0.70, 0.60, 0.50, 0.40, 0.45, 0.35, 0.30, 0.25,
    0.20, 0.25, 0.18, 0.15, 0.22, 0.18, 0.15,
  ];

  @override
  void initState() {
    super.initState();
    _typeOfCar = customerRentalController.carType;
    final minP = customerRentalController.minPrice > 0 ? customerRentalController.minPrice : 10000.0;
    final maxP = customerRentalController.maxPrice < 1000000 ? customerRentalController.maxPrice : 350000.0;
    _priceRange = RangeValues(minP.clamp(10000.0, 500000.0), maxP.clamp(10000.0, 500000.0));
    _rentalTime = customerRentalController.rentalTime != 'all' ? customerRentalController.rentalTime : 'day';
    _selectedCity = customerRentalController.selectedCity;
    _selectedColor = customerRentalController.selectedColor;
    _selectedSeats = customerRentalController.selectedSeats;
    _selectedFuel = customerRentalController.selectedFuelType;
  }

  int _calculateMatchingCount() {
    final all = customerRentalController.allVehiclesUnfiltered;
    return all.where((v) {
      // Car Type
      if (_typeOfCar == 'regular' && (v.category == RentalVehicleCategory.luxury || v.isArmored)) {
        return false;
      }
      if (_typeOfCar == 'luxury' && (v.category != RentalVehicleCategory.luxury && !v.isArmored)) {
        return false;
      }

      // City
      if (_selectedCity != 'All Cities' && v.city != _selectedCity) {
        return false;
      }

      // Price
      final rate = v.dailySelfDriveRate > 0 ? v.dailySelfDriveRate : v.dailyWithDriverRate;
      if (rate < _priceRange.start || rate > _priceRange.end) {
        return false;
      }

      // Rental Time
      if (_rentalTime == 'hour' && v.hourlyChauffeurRate <= 0) {
        return false;
      }

      // Color
      if (_selectedColor != null && !v.color.toLowerCase().contains(_selectedColor!.toLowerCase())) {
        return false;
      }

      // Seats
      if (_selectedSeats != null && v.seats != _selectedSeats) {
        return false;
      }

      // Fuel Type
      if (_selectedFuel != null && v.fuelType.toLowerCase() != _selectedFuel!.toLowerCase()) {
        return false;
      }

      return true;
    }).length;
  }

  void _showCityPicker(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Select Operating State / City',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 14),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.45,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.cities.length,
                itemBuilder: (ctx, i) {
                  final city = widget.cities[i];
                  final isSelected = city == _selectedCity;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    leading: Icon(
                      Icons.location_on_outlined,
                      color: isSelected ? AppColors.brand : const Color(0xFF9CA3AF),
                    ),
                    title: Text(
                      city,
                      style: TextStyle(
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        color: isSelected
                            ? AppColors.brand
                            : (isDark ? Colors.white : const Color(0xFF111827)),
                      ),
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_rounded, color: AppColors.brand)
                        : null,
                    onTap: () {
                      setState(() => _selectedCity = city);
                      Navigator.pop(ctx);
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);
    final matchingCount = _calculateMatchingCount();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // ── Header Bar with Close X and Title ─────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22),
                  color: primaryTextColor,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: Center(
                    child: Text(
                      'Filters',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: primaryTextColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 48), // Balance close button spacing
              ],
            ),
          ),
          Divider(
            height: 1,
            color: isDark ? AppColors.glassBorderDark : const Color(0xFFF3F4F6),
          ),

          // ── Scrollable Filter Body ─────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Type of Cars
                  Text(
                    'Type of Cars',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    height: 48,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF222222) : const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Row(
                      children: [
                        _buildCarTypeSegment('All Cars', 'all', isDark),
                        _buildCarTypeSegment('Regular Cars', 'regular', isDark),
                        _buildCarTypeSegment('Luxury Cars', 'luxury', isDark),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // 2. Price range
                  Text(
                    'Price range',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Histogram Bar Chart Graphic (Matching Screenshot)
                  SizedBox(
                    height: 54,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final totalBars = _histogramBars.length;
                        final barWidth = (constraints.maxWidth - (totalBars - 1) * 3) / totalBars;
                        final minNorm = (_priceRange.start - 10000.0) / (500000.0 - 10000.0);
                        final maxNorm = (_priceRange.end - 10000.0) / (500000.0 - 10000.0);

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(totalBars, (i) {
                            final fraction = i / totalBars;
                            final isInRange = fraction >= minNorm && fraction <= maxNorm;
                            final height = math.max(6.0, _histogramBars[i] * 50.0);

                            return Container(
                              width: math.max(2.5, barWidth),
                              height: height,
                              margin: EdgeInsets.only(right: i < totalBars - 1 ? 3 : 0),
                              decoration: BoxDecoration(
                                color: isInRange
                                    ? (isDark ? Colors.white : const Color(0xFF1E293B))
                                    : (isDark ? Colors.white24 : const Color(0xFFE5E7EB)),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            );
                          }),
                        );
                      },
                    ),
                  ),

                  // Range Slider
                  RangeSlider(
                    values: _priceRange,
                    min: 10000.0,
                    max: 500000.0,
                    divisions: 49,
                    activeColor: isDark ? Colors.white : const Color(0xFF1E293B),
                    inactiveColor: isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                    onChanged: (values) => setState(() => _priceRange = values),
                  ),

                  // Minimum & Maximum Value Boxes
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Minimum',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: secondaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF222222) : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  NgnFormat.currency(_priceRange.start),
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: primaryTextColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Maximum',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: secondaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF222222) : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  '${NgnFormat.currency(_priceRange.end)}+',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: primaryTextColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // 3. Rental Time
                  Text(
                    'Rental Time',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildPillOption('Hour', 'hour', isDark),
                      const SizedBox(width: 8),
                      _buildPillOption('Day', 'day', isDark),
                      const SizedBox(width: 8),
                      _buildPillOption('Weekly', 'weekly', isDark),
                      const SizedBox(width: 8),
                      _buildPillOption('Monthly', 'monthly', isDark),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // 4. Car Location (Operating City / State Filter)
                  Text(
                    'Car Location',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => _showCityPicker(context),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF222222) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            color: Color(0xFF9CA3AF),
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _selectedCity == 'All Cities'
                                  ? 'All Operating Locations (Nigeria)'
                                  : '$_selectedCity, Nigeria',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: primaryTextColor,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: secondaryTextColor,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // 5. Colors
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Colors',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: primaryTextColor,
                        ),
                      ),
                      if (_selectedColor != null)
                        GestureDetector(
                          onTap: () => setState(() => _selectedColor = null),
                          child: Text(
                            'Clear',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: secondaryTextColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: _colorOptions.map((opt) {
                        final name = opt['name'] as String;
                        final color = opt['color'] as Color;
                        final border = opt['border'] as Color;
                        final isSelected = _selectedColor?.toLowerCase() == name.toLowerCase();

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedColor = isSelected ? null : name;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 14),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isSelected
                                          ? AppColors.brand
                                          : (border != Colors.transparent
                                              ? border
                                              : (isDark ? Colors.white24 : Colors.transparent)),
                                      width: isSelected ? 2.5 : 1,
                                    ),
                                  ),
                                  child: isSelected
                                      ? Icon(
                                          Icons.check_rounded,
                                          size: 14,
                                          color: color == Colors.white ? Colors.black : Colors.white,
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected ? primaryTextColor : secondaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // 6. Siting Capacity
                  Text(
                    'Siting Capacity',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: _seatOptions.map((seat) {
                      final isSelected = _selectedSeats == seat;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedSeats = isSelected ? null : seat;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            height: 44,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark ? Colors.white : const Color(0xFF1E293B))
                                  : (isDark ? const Color(0xFF222222) : Colors.white),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: isSelected
                                    ? (isDark ? Colors.white : const Color(0xFF1E293B))
                                    : (isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB)),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                '$seat',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  color: isSelected
                                      ? (isDark ? const Color(0xFF111827) : Colors.white)
                                      : (isDark ? AppColors.textSecondaryDark : const Color(0xFF4B5563)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),

                  // 7. Fuel Type
                  Text(
                    'Fuel Type',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: _fuelOptions.map((fuel) {
                      final isSelected = _selectedFuel?.toLowerCase() == fuel.toLowerCase();
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedFuel = isSelected ? null : fuel;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            height: 44,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark ? Colors.white : const Color(0xFF1E293B))
                                  : (isDark ? const Color(0xFF222222) : Colors.white),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(
                                color: isSelected
                                    ? (isDark ? Colors.white : const Color(0xFF1E293B))
                                    : (isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB)),
                              ),
                            ),
                            child: Center(
                              child: Text(
                                fuel,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  color: isSelected
                                      ? (isDark ? const Color(0xFF111827) : Colors.white)
                                      : (isDark ? AppColors.textSecondaryDark : const Color(0xFF4B5563)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),

          // ── Bottom Action Buttons ──────────────────────────────────────────
          Divider(
            height: 1,
            color: isDark ? AppColors.glassBorderDark : const Color(0xFFF3F4F6),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              14,
              20,
              MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: Row(
              children: [
                // Clear All Button
                TextButton(
                  onPressed: () {
                    setState(() {
                      _typeOfCar = 'all';
                      _priceRange = const RangeValues(10000.0, 350000.0);
                      _rentalTime = 'day';
                      _selectedCity = 'All Cities';
                      _selectedColor = null;
                      _selectedSeats = null;
                      _selectedFuel = null;
                    });
                  },
                  child: Text(
                    'Clear All',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: primaryTextColor,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Show X+ Cars Primary Button
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(0, 52),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    onPressed: () {
                      customerRentalController.applyAdvancedFilters(
                        city: _selectedCity,
                        carType: _typeOfCar,
                        minPrice: _priceRange.start,
                        maxPrice: _priceRange.end,
                        rentalTime: _rentalTime,
                        color: _selectedColor,
                        seats: _selectedSeats,
                        fuelType: _selectedFuel,
                      );
                      Navigator.of(context).pop();
                    },
                    child: Text(
                      matchingCount > 0 ? 'Show $matchingCount+ Cars' : 'Show Cars',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarTypeSegment(String label, String value, bool isDark) {
    final isSelected = _typeOfCar == value;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _typeOfCar = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? Colors.white : const Color(0xFF1E293B))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? (isDark ? const Color(0xFF111827) : Colors.white)
                    : (isDark ? AppColors.textSecondaryDark : const Color(0xFF4B5563)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPillOption(String label, String value, bool isDark) {
    final isSelected = _rentalTime == value;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _rentalTime = value),
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark ? Colors.white : const Color(0xFF1E293B))
                : (isDark ? const Color(0xFF222222) : Colors.white),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: isSelected
                  ? (isDark ? Colors.white : const Color(0xFF1E293B))
                  : (isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB)),
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? (isDark ? const Color(0xFF111827) : Colors.white)
                    : (isDark ? AppColors.textSecondaryDark : const Color(0xFF4B5563)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
