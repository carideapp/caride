import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';
import 'driver_fleet_ratings_screen.dart';

/// Screen displaying the Fleet Profile strictly matching the layout and design of UI/Vendor.png,
/// fully compliant with CaRide brand standards (AppColors.brand Emerald Green, pill geometry).
class DriverFleetProfileViewScreen extends StatefulWidget {
  const DriverFleetProfileViewScreen({
    super.key,
    required this.fleet,
  });

  final FleetProfile fleet;

  @override
  State<DriverFleetProfileViewScreen> createState() => _DriverFleetProfileViewScreenState();
}

class _DriverFleetProfileViewScreenState extends State<DriverFleetProfileViewScreen> {
  final _firestore = FirebaseFirestore.instance;

  String _selectedCategory = 'All';
  bool _isFavorite = false;

  static const List<String> _categories = [
    'All',
    'Sedan',
    'SUV',
    'Luxury',
    'Armored',
    'Van',
  ];

  void _showVehicleDetails(RentalVehicle vehicle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? const Color(0xFFD1D5DB) : const Color(0xFF6B7280);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              if (vehicle.images.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.network(
                    vehicle.images.first,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      '${vehicle.make} ${vehicle.model} (${vehicle.year})',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      vehicle.category.name.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.brand,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'Plate: ${vehicle.plateNumber} • ${vehicle.seats} Seats • ${vehicle.transmission} • ${vehicle.city}',
                style: TextStyle(fontSize: 13, color: secondaryTextColor),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Text(
                    'Daily Chauffeur Rate: ',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: primaryTextColor,
                    ),
                  ),
                  Text(
                    '₦${vehicle.dailyWithDriverRate.toStringAsFixed(0)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brand,
                    ),
                  ),
                ],
              ),
              if (vehicle.assignedDefaultDriverName != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Assigned Driver: ${vehicle.assignedDefaultDriverName}',
                  style: TextStyle(fontSize: 13, color: secondaryTextColor),
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final fleet = widget.fleet;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? const Color(0xFFD1D5DB) : const Color(0xFF6B7280);

    final effectiveFleetId = fleet.fleetId.isNotEmpty ? fleet.fleetId : fleet.id;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: effectiveFleetId.isNotEmpty
          ? _firestore
              .collection('rental_vehicles')
              .where('fleetId', isEqualTo: effectiveFleetId)
              .snapshots()
          : (fleet.ownerUid.isNotEmpty
              ? _firestore
                  .collection('rental_vehicles')
                  .where('ownerUid', isEqualTo: fleet.ownerUid)
                  .snapshots()
              : const Stream.empty()),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final allVehicles =
            docs.map((d) => RentalVehicle.fromMap(d.data(), d.id)).toList();

        final fleetSize = allVehicles.isNotEmpty
            ? allVehicles.length
            : fleet.totalVehicles;
        final totalReviews =
            allVehicles.fold<int>(0, (acc, v) => acc + v.tripCount);
        final ratedVehicles =
            allVehicles.where((v) => v.rating != null && v.rating! > 0).toList();
        final double avgRating = ratedVehicles.isNotEmpty
            ? (ratedVehicles.fold<double>(
                    0.0, (acc, v) => acc + v.rating!) /
                ratedVehicles.length)
            : (totalReviews > 0 && fleet.rating > 0 ? fleet.rating : 0.0);
        final bool hasRatings =
            avgRating > 0 && (ratedVehicles.isNotEmpty || totalReviews > 0);

        var displayedVehicles = allVehicles;
        if (_selectedCategory != 'All') {
          displayedVehicles = allVehicles.where((v) {
            final catName = v.category.name.toLowerCase();
            final selected = _selectedCategory.toLowerCase();
            if (selected == 'armored') return v.isArmored;
            return catName.contains(selected);
          }).toList();
        }

        return Scaffold(
          backgroundColor:
              isDark ? AppColors.darkBackground : const Color(0xFFFAFAFA),
          body: CustomScrollView(
            slivers: [
          // ── Top Stacked Cover Header (Matching UI/Vendor.png) ──
          SliverToBoxAdapter(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Full-width Cover Photo
                Container(
                  height: 270,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : const Color(0xFFE5E7EB),
                  ),
                  child: fleet.coverPhotoUrl != null && fleet.coverPhotoUrl!.isNotEmpty
                      ? Image.network(
                          fleet.coverPhotoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _defaultCoverHeader(),
                        )
                      : _defaultCoverHeader(),
                ),

                // Top Controls: Back Button, Title, Favorite Heart
                Positioned(
                  top: MediaQuery.of(context).padding.top + 8,
                  left: 16,
                  right: 16,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Circular Back Button
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ),

                      // Title
                      const Text(
                        'Fleet Profile',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          shadows: [Shadow(blurRadius: 4, color: Colors.black45)],
                        ),
                      ),

                      // Heart/Favorite Icon
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: _isFavorite ? AppColors.error : Colors.white,
                            size: 22,
                          ),
                          onPressed: () => setState(() => _isFavorite = !_isFavorite),
                        ),
                      ),
                    ],
                  ),
                ),

                // Floating Fleet Details Card (Overlapping Cover, strictly matching UI/Vendor.png)
                Padding(
                  padding: const EdgeInsets.only(top: 210, left: 16, right: 16),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Row 1: Fleet Business Name + Verified checkmark
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      fleet.businessName.isNotEmpty ? fleet.businessName : 'CaRide Fleet',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                        color: primaryTextColor,
                                        letterSpacing: -0.3,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Icon(
                                    fleet.isVerified ? Icons.verified : Icons.verified_outlined,
                                    color: AppColors.brand,
                                    size: 18,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Row 2: Tagline / Description
                        Text(
                          fleet.description != null && fleet.description!.isNotEmpty
                              ? fleet.description!
                              : 'Premium Chauffeur & Executive Vehicle Rentals',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: primaryTextColor,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Row 3: Operating Schedule & Availability
                        Row(
                          children: [
                            Text(
                              'Open 24/7',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: primaryTextColor,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: secondaryTextColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Mon - Sun',
                              style: TextStyle(
                                fontSize: 12,
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Row 4: Inner 3-Stats Container (Matching UI/Vendor.png)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkBackground : const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Stat 1: Base Location
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Operating Base',
                                      style: TextStyle(fontSize: 11, color: secondaryTextColor),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      fleet.city.isNotEmpty ? fleet.city : 'Nigeria',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: primaryTextColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Vertical Divider
                              Container(
                                width: 1,
                                height: 28,
                                color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                              ),
                              const SizedBox(width: 14),

                              // Stat 2: Total Vehicles
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Fleet Size',
                                      style: TextStyle(fontSize: 11, color: secondaryTextColor),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.directions_car_rounded, size: 14, color: AppColors.brand),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$fleetSize Cars',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: primaryTextColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              // Vertical Divider
                              Container(
                                width: 1,
                                height: 28,
                                color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                              ),
                              const SizedBox(width: 14),

                              // Stat 3: Ratings & Reviews (Tap to view all reviews)
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            DriverFleetRatingsScreen(fleet: fleet),
                                      ),
                                    );
                                  },
                                  behavior: HitTestBehavior.opaque,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Ratings',
                                        style: TextStyle(fontSize: 11, color: secondaryTextColor),
                                      ),
                                      const SizedBox(height: 4),
                                      if (hasRatings)
                                        Row(
                                          children: [
                                            const Icon(Icons.star_rounded, size: 16, color: Color(0xFFF59E0B)),
                                            const SizedBox(width: 3),
                                            Text(
                                              avgRating.toStringAsFixed(1),
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: primaryTextColor,
                                              ),
                                            ),
                                            if (totalReviews > 0) ...[
                                              const SizedBox(width: 3),
                                              Text(
                                                '($totalReviews)',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: secondaryTextColor,
                                                ),
                                              ),
                                            ],
                                          ],
                                        )
                                      else
                                        Text(
                                          totalReviews > 0 ? '($totalReviews Reviews)' : 'No ratings yet',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: secondaryTextColor,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Spacing
          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // ── Horizontal Category Filter Chips (Strictly CaRide Brand Emerald) ──
          SliverToBoxAdapter(
            child: SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = _selectedCategory == cat;

                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: InkWell(
                      onTap: () => setState(() => _selectedCategory = cat),
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.brand
                              : (isDark ? AppColors.darkSurface : const Color(0xFFF3F4F6)),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.brand
                                : (isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB)),
                          ),
                        ),
                        child: Center(
                          child: Text(
                            cat,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark ? Colors.white : const Color(0xFF4B5563)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // ── 2-Column Vehicle Grid (UI/Vendor.png design) ──
          if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(40.0),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
                  ),
                ),
              ),
            )
          else if (displayedVehicles.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.directions_car_outlined,
                        size: 48,
                        color: secondaryTextColor.withValues(alpha: 0.5),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No vehicles available in this category',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Try selecting "All" or another vehicle category.',
                        style: TextStyle(fontSize: 13, color: secondaryTextColor),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.72,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final v = displayedVehicles[index];
                    return _VendorVehicleCard(
                      vehicle: v,
                      onTap: () => _showVehicleDetails(v),
                    );
                  },
                  childCount: displayedVehicles.length,
                ),
              ),
            ),

          // Bottom padding for scroll
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
    );
      },
    );
  }

  Widget _defaultCoverHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.brand.withValues(alpha: 0.85),
            AppColors.brandLight.withValues(alpha: 0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.directions_car_rounded,
          size: 72,
          color: Colors.white.withValues(alpha: 0.8),
        ),
      ),
    );
  }
}

/// 2-Column Grid Vehicle Card matching UI/Vendor.png layout
class _VendorVehicleCard extends StatelessWidget {
  const _VendorVehicleCard({
    required this.vehicle,
    required this.onTap,
  });

  final RentalVehicle vehicle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? const Color(0xFFD1D5DB) : const Color(0xFF6B7280);

    final title = '${vehicle.make} ${vehicle.model}';
    final rate = vehicle.dailyWithDriverRate > 0
        ? vehicle.dailyWithDriverRate
        : vehicle.dailySelfDriveRate;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vehicle Image
            Expanded(
              flex: 5,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: vehicle.images.isNotEmpty
                        ? Image.network(
                            vehicle.images.first,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _fallbackVehiclePhoto(),
                          )
                        : _fallbackVehiclePhoto(),
                  ),
                  if (vehicle.isArmored)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.65),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.shield, size: 10, color: AppColors.brand),
                            SizedBox(width: 3),
                            Text(
                              'Armored',
                              style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Card Body (Make, Model, Subtitle, Price & Plus Button)
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${vehicle.category.name.toUpperCase()} • ${vehicle.seats} seats',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),

                    // Price and Plus Button Row (Matching UI/Vendor.png)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            '₦${rate.toStringAsFixed(0)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.brand,
                            ),
                          ),
                        ),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: AppColors.brand,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackVehiclePhoto() {
    return Container(
      color: AppColors.brand.withValues(alpha: 0.1),
      child: const Center(
        child: Icon(Icons.directions_car_rounded, color: AppColors.brand, size: 36),
      ),
    );
  }
}
