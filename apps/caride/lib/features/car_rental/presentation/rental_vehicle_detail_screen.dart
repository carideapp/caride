import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_widgets/shared_widgets.dart';

import '../customer_rental_controller.dart';
import '../data/customer_rental_repository.dart';
import '../../driver/profile/driver_fleet_profile_view_screen.dart';
import 'vehicle_details_rating_screen.dart';
import 'widgets/vehicle_booking_calendar.dart';

/// Full vehicle detail screen redesigned strictly following the mockup inspiration
/// and CaRide brand guidelines (AppColors.brand Emerald Green, pill geometry, live Firestore data).
class RentalVehicleDetailScreen extends StatefulWidget {
  const RentalVehicleDetailScreen({super.key, required this.vehicle});

  final RentalVehicle vehicle;

  @override
  State<RentalVehicleDetailScreen> createState() =>
      _RentalVehicleDetailScreenState();
}

class _RentalVehicleDetailScreenState
    extends State<RentalVehicleDetailScreen> {
  final PageController _imagePageController = PageController();
  int _currentImagePage = 0;
  bool _featuresExpanded = false;
  FleetProfile? _fleetProfile;

  @override
  void initState() {
    super.initState();
    _loadFleetProfile();
  }

  Future<void> _loadFleetProfile() async {
    final v = widget.vehicle;
    final profile = await customerRentalRepository.getFleetProfile(
      fleetId: v.fleetId,
      ownerUid: v.ownerUid,
    );
    if (mounted) {
      setState(() {
        _fleetProfile = profile;
      });
    }
  }

  void _navigateToFleetProfile() async {
    if (_fleetProfile != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DriverFleetProfileViewScreen(fleet: _fleetProfile!),
        ),
      );
      return;
    }

    final v = widget.vehicle;
    final profile = await customerRentalRepository.getFleetProfile(
      fleetId: v.fleetId,
      ownerUid: v.ownerUid,
    );
    if (!mounted) return;
    if (profile != null) {
      setState(() => _fleetProfile = profile);
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DriverFleetProfileViewScreen(fleet: profile),
        ),
      );
    } else {
      final fallback = FleetProfile(
        fleetId: v.fleetId,
        ownerUid: v.ownerUid,
        businessName: 'Verified Fleet Partner',
        phone: '',
        email: '',
        city: v.city,
      );
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DriverFleetProfileViewScreen(fleet: fallback),
        ),
      );
    }
  }

  @override
  void dispose() {
    _imagePageController.dispose();
    super.dispose();
  }

  void _openFullScreenImage(
    BuildContext context,
    List<String> images,
    int initialIndex,
  ) {
    if (images.isEmpty) return;

    showDialog<void>(
      context: context,
      useSafeArea: false,
      barrierColor: Colors.black.withValues(alpha: 0.95),
      builder: (ctx) {
        final pageCtrl = PageController(initialPage: initialIndex);
        int currentIndex = initialIndex;

        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return Scaffold(
              backgroundColor: Colors.transparent,
              body: Stack(
                children: [
                  // Full Screen PageView with InteractiveViewer (pinch to zoom)
                  PageView.builder(
                    controller: pageCtrl,
                    itemCount: images.length,
                    onPageChanged: (idx) {
                      setDialogState(() => currentIndex = idx);
                    },
                    itemBuilder: (context, idx) {
                      final src = images[idx].trim();
                      final isNet = src.startsWith('http://') ||
                          src.startsWith('https://');

                      return InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4.0,
                        child: Center(
                          child: isNet
                              ? Image.network(
                                  src,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.broken_image_rounded,
                                    size: 64,
                                    color: Colors.white54,
                                  ),
                                )
                              : Image.asset(
                                  src,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.broken_image_rounded,
                                    size: 64,
                                    color: Colors.white54,
                                  ),
                                ),
                        ),
                      );
                    },
                  ),

                  // Top bar with close button and page indicator
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.of(dialogCtx).pop(),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withValues(alpha: 0.55),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: const Icon(
                                Icons.close_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                          if (images.length > 1)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.55),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white24),
                              ),
                              child: Text(
                                '${currentIndex + 1} / ${images.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }


  void _showMoreOptions(BuildContext context, RentalVehicle v, bool isDark) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, MediaQuery.of(ctx).padding.bottom + 20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              v.displayName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : const Color(0xFF111827),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading:
                  const Icon(Icons.business_rounded, color: AppColors.brand),
              title: const Text('View Fleet Partner Profile',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                _navigateToFleetProfile();
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.share_outlined, color: AppColors.brand),
              title: const Text('Share Vehicle Listing',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Sharing ${v.displayName} • ${v.city}'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    backgroundColor: AppColors.brand,
                  ),
                );
              },
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
    final secondaryTextColor =
        isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);
    final tertiaryTextColor =
        isDark ? AppColors.textTertiaryDark : const Color(0xFF9CA3AF);
    final v = widget.vehicle;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: Stack(
        children: [
          // ── Scrollable Body ────────────────────────────────────────────────
          SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Top Navigation Bar ───────────────────────────────────────
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      children: [
                        // Circular Back Button per AGENTS.md
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
                        Expanded(
                          child: Center(
                            child: Text(
                              'Car Details',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: primaryTextColor,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        ),
                        // Circular More Options Button
                        GestureDetector(
                          onTap: () => _showMoreOptions(context, v, isDark),
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

                const SizedBox(height: 8),

                // ── Hero Car Showcase (Filling Container & Tap to Pop Up) ───
                _buildCarShowcase(v, isDark),

                const SizedBox(height: 18),

                // ── Main Details Container ───────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 1. Title, Subtitle & Live Rating (with numbers in brackets)
                      _buildTitleAndRating(v, primaryTextColor, secondaryTextColor,
                          tertiaryTextColor),

                      const SizedBox(height: 18),

                      // Subtle Divider
                      Divider(
                        height: 1,
                        color: isDark
                            ? AppColors.glassBorderDark
                            : const Color(0xFFF1F5F9),
                      ),

                      const SizedBox(height: 18),

                      // 2. Fleet Partner / Owner Row with Action Buttons
                      _buildFleetPartnerRow(v, isDark, primaryTextColor,
                          secondaryTextColor),

                      const SizedBox(height: 28),

                      // 3. "Car features" 3-Column Specifications Grid
                      _buildSectionHeader('Car features', primaryTextColor),
                      const SizedBox(height: 14),
                      _buildFeaturesGrid(v, isDark, primaryTextColor,
                          secondaryTextColor),

                      const SizedBox(height: 28),

                      // 4. Rental Options & Pricing Breakdown
                      _buildSectionHeader('Rental Options', primaryTextColor),
                      const SizedBox(height: 14),
                      _buildRentalOptions(v, isDark),

                      const SizedBox(height: 28),

                      // 5. Live Booking & Availability Schedule (3-Month Calendar)
                      _buildSectionHeader(
                          'Booking & Availability Schedule', primaryTextColor),
                      const SizedBox(height: 14),
                      _buildAvailabilityCalendar(v, isDark),

                      // 6. Features & Amenities Chips (4 initially, others preview on tap)
                      if (v.features.isNotEmpty) ...[
                        const SizedBox(height: 28),
                        _buildSectionHeader(
                            'Features & Amenities', primaryTextColor),
                        const SizedBox(height: 14),
                        _buildAmenitiesChips(v, isDark),
                      ],

                      const SizedBox(height: 28),

                      // 7. Review Section (No fake ratings or hardcoded text)
                      _buildSectionHeader(
                          'Review (${v.reviewCount})', primaryTextColor),
                      const SizedBox(height: 14),
                      _buildReviewAssuranceCard(v, isDark, primaryTextColor,
                          secondaryTextColor),

                      // Bottom clearance for sticky CTA bar
                      const SizedBox(height: 120),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Sticky Bottom CTA Bar ──────────────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildStickyBottomBar(context, v, isDark, secondaryTextColor),
          ),
        ],
      ),
    );
  }

  // ── Car Showcase Filling Screen Container & Tap to Pop Up ──────────────────

  Widget _buildCarShowcase(RentalVehicle v, bool isDark) {
    final images = v.images;

    return Container(
      width: double.infinity,
      color: isDark ? const Color(0xFF141414) : const Color(0xFFFAFAFA),
      child: Column(
        children: [
          SizedBox(
            height: 250,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Vehicle Images PageView (BoxFit.cover to fill the image container screen)
                if (images.isNotEmpty)
                  PageView.builder(
                    controller: _imagePageController,
                    itemCount: images.length,
                    onPageChanged: (page) =>
                        setState(() => _currentImagePage = page),
                    itemBuilder: (context, index) {
                      final src = images[index].trim();
                      final isNet =
                          src.startsWith('http://') || src.startsWith('https://');

                      final fallback = Center(
                        child: Icon(
                          Icons.directions_car_rounded,
                          size: 90,
                          color: AppColors.brand.withValues(alpha: 0.3),
                        ),
                      );

                      return GestureDetector(
                        onTap: () =>
                            _openFullScreenImage(context, images, index),
                        child: isNet
                            ? Image.network(
                                src,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (_, __, ___) => fallback,
                              )
                            : Image.asset(
                                src,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                                errorBuilder: (_, __, ___) => fallback,
                              ),
                      );
                    },
                  )
                else
                  Center(
                    child: Icon(
                      Icons.directions_car_rounded,
                      size: 90,
                      color: AppColors.brand.withValues(alpha: 0.3),
                    ),
                  ),

                // Floating Favorite Heart Button at Top Right
                Positioned(
                  top: 12,
                  right: 18,
                  child: ListenableBuilder(
                    listenable: customerRentalController,
                    builder: (context, _) {
                      final isFav = customerRentalController.isFavorite(v.id);
                      return GestureDetector(
                        onTap: () => customerRentalController.toggleFavorite(v.id),
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
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            isFav
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 22,
                            color: isFav
                                ? const Color(0xFFEF4444)
                                : (isDark
                                    ? Colors.white70
                                    : const Color(0xFF4B5563)),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Pagination Dots Indicator
          if (images.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(images.length, (i) {
                  final active = i == _currentImagePage;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: active ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: active
                          ? (isDark ? Colors.white : const Color(0xFF1E293B))
                          : (isDark ? Colors.white24 : const Color(0xFFD1D5DB)),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }

  // ── Vehicle Title & Live Rating (Numbers in Brackets) ──────────────────────

  Widget _buildTitleAndRating(
    RentalVehicle v,
    Color primaryTextColor,
    Color secondaryTextColor,
    Color tertiaryTextColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          v.displayName,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: primaryTextColor,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          v.description.trim().isNotEmpty
              ? v.description.trim()
              : '${v.year} ${v.make} ${v.model} · ${v.category.label} · ${v.city}',
          style: TextStyle(
            fontSize: 13,
            color: secondaryTextColor,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  // ── Fleet Partner Row with Call & Message Action Buttons ───────────────────

  Widget _buildFleetPartnerRow(
    RentalVehicle v,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    // 1. Resolve Fleet Name: businessName -> fullName -> fallback
    final bName = _fleetProfile?.businessName.trim();
    final fName = _fleetProfile?.fullName.trim();
    final displayName = (bName != null && bName.isNotEmpty)
        ? bName
        : ((fName != null && fName.isNotEmpty) ? fName : 'Verified Fleet Partner');

    // 2. Resolve Fleet Avatar: logoUrl -> profilePictureUrl -> fallback
    final logo = _fleetProfile?.logoUrl?.trim();
    final profilePic = _fleetProfile?.profilePictureUrl?.trim();
    final avatarUrl = (logo != null && logo.isNotEmpty)
        ? logo
        : ((profilePic != null && profilePic.isNotEmpty) ? profilePic : null);

    final isVerified = _fleetProfile?.isVerified ?? true;
    final city = (_fleetProfile?.city.isNotEmpty == true)
        ? _fleetProfile!.city
        : v.city;

    return Row(
      children: [
        // Circular Avatar
        GestureDetector(
          onTap: _navigateToFleetProfile,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : const Color(0xFFF3F4F6),
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                width: 1,
              ),
            ),
            child: ClipOval(
              child: avatarUrl != null
                  ? Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _buildFleetAvatarFallback(displayName),
                    )
                  : _buildFleetAvatarFallback(displayName),
            ),
          ),
        ),

        const SizedBox(width: 12),

        // Fleet Partner Name & Location Subtitle
        Expanded(
          child: GestureDetector(
            onTap: _navigateToFleetProfile,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: primaryTextColor,
                        ),
                      ),
                    ),
                    if (isVerified) ...[
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.verified_rounded,
                        color: AppColors.brand,
                        size: 17,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Fleet Partner · $city',
                  style: TextStyle(
                    fontSize: 12,
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
        ),

        GestureDetector(
          onTap: _navigateToFleetProfile,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkSurface
                  : const Color(0xFFF3F4F6),
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
                Text(
                  'Profile',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: primaryTextColor,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: secondaryTextColor,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFleetAvatarFallback(String name) {
    if (name.isNotEmpty &&
        name != 'Verified Fleet' &&
        name != 'Verified Fleet Partner') {
      return Center(
        child: Text(
          name[0].toUpperCase(),
          style: const TextStyle(
            color: AppColors.brand,
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
      );
    }
    return Container(
      color: AppColors.brand.withValues(alpha: 0.1),
      child: const Center(
        child: Icon(
          Icons.business_rounded,
          color: AppColors.brand,
          size: 22,
        ),
      ),
    );
  }

  // ── "Car features" 3-Column Specifications Grid ────────────────────────────

  Widget _buildFeaturesGrid(
    RentalVehicle v,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    final specs = <_SpecItem>[
      _SpecItem(
        icon: Icons.airline_seat_recline_normal_rounded,
        label: 'Capacity',
        value: '${v.seats > 0 ? v.seats : 4} Seats',
      ),
      _SpecItem(
        icon: Icons.tune_rounded,
        label: 'Transmission',
        value: v.transmission.isNotEmpty ? v.transmission : 'Automatic',
      ),
      _SpecItem(
        icon: v.fuelType.toLowerCase() == 'electric'
            ? Icons.electric_car_outlined
            : Icons.local_gas_station_outlined,
        label: 'Fuel Type',
        value: v.fuelType.isNotEmpty ? v.fuelType : 'Petrol',
      ),
      _SpecItem(
        icon: Icons.directions_car_outlined,
        label: 'Category',
        value: v.category.label,
      ),
      _SpecItem(
        icon: Icons.person_pin_circle_outlined,
        label: 'Service Mode',
        value: v.rentalMode == 'both'
            ? 'Both Modes'
            : (v.rentalMode == 'self_drive_only'
                ? 'Self-Drive'
                : 'Chauffeur'),
      ),
      _SpecItem(
        icon: Icons.map_outlined,
        label: 'Interstate',
        value: v.allowsInterstate ? 'Permitted' : 'Local Only',
      ),
    ];

    if (v.isArmored) {
      specs.add(_SpecItem(
        icon: Icons.shield_outlined,
        label: 'Armor Spec',
        value: v.armorLevel ?? 'Bulletproof',
      ));
    }

    if (v.hasSecurityEscortOption) {
      specs.add(const _SpecItem(
        icon: Icons.security_rounded,
        label: 'Escort',
        value: 'Available',
      ));
    }

    if (v.hasDropOffOption) {
      specs.add(const _SpecItem(
        icon: Icons.flight_land_rounded,
        label: 'Drop-Off',
        value: 'Supported',
      ));
    }

    if (v.color.isNotEmpty) {
      specs.add(_SpecItem(
        icon: Icons.palette_outlined,
        label: 'Exterior',
        value: v.color,
      ));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - (2 * 10)) / 3;

        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: specs.map((spec) {
            return SizedBox(
              width: itemWidth,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurface
                      : const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark
                        ? AppColors.glassBorderDark
                        : const Color(0xFFE5E7EB),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? const Color(0xFF222222) : Colors.white,
                        border: Border.all(
                          color: isDark
                              ? AppColors.glassBorderDark
                              : const Color(0xFFE5E7EB),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        spec.icon,
                        size: 18,
                        color: isDark ? Colors.white70 : const Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      spec.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      spec.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: primaryTextColor,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ── Rental Options & Pricing Breakdown ─────────────────────────────────────

  Widget _buildRentalOptions(RentalVehicle v, bool isDark) {
    final options = <Widget>[];

    if (v.dailySelfDriveRate > 0) {
      options.add(_buildPricingRow(
        icon: Icons.key_rounded,
        title: 'Self-Drive Daily Rate',
        subtitle: 'Drive yourself with full vehicle freedom',
        amount: v.dailySelfDriveRate,
        suffix: '/ day',
        isDark: isDark,
      ));
    }

    if (v.dailyWithDriverRate > 0) {
      options.add(_buildPricingRow(
        icon: Icons.person_rounded,
        title: 'Chauffeur Daily Rate',
        subtitle: 'Dedicated professional chauffeur included',
        amount: v.dailyWithDriverRate,
        suffix: '/ day',
        isDark: isDark,
      ));
    }

    if (v.hourlyChauffeurRate > 0) {
      options.add(_buildPricingRow(
        icon: Icons.schedule_rounded,
        title: 'Hourly Chauffeur Service',
        subtitle: 'Min. ${v.minChauffeurHours} hours executive hire',
        amount: v.hourlyChauffeurRate,
        suffix: '/ hour',
        isDark: isDark,
      ));
    }

    if (v.hasDropOffOption && v.dropOffRate > 0) {
      options.add(_buildPricingRow(
        icon: Icons.flight_land_rounded,
        title: 'Airport & One-Way Drop-Off',
        subtitle: 'Point-to-point one stop transfer',
        amount: v.dropOffRate,
        suffix: '/ trip',
        isDark: isDark,
      ));
    }

    if (v.cautionDeposit > 0) {
      options.add(_buildPricingRow(
        icon: Icons.security_rounded,
        title: 'Refundable Caution Deposit',
        subtitle: 'Fully returned upon vehicle check-in inspection',
        amount: v.cautionDeposit,
        suffix: ' (refundable)',
        isDark: isDark,
      ));
    }

    if (v.interstateDailySurcharge > 0) {
      options.add(_buildPricingRow(
        icon: Icons.toll_rounded,
        title: 'Interstate Daily Surcharge',
        subtitle: 'Applies when traveling outside operating state',
        amount: v.interstateDailySurcharge,
        suffix: '/ day',
        isDark: isDark,
      ));
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        children: options,
      ),
    );
  }

  Widget _buildPricingRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required double amount,
    required String suffix,
    required bool isDark,
  }) {
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor =
        isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.brand, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                NgnFormat.currency(amount),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.brand,
                ),
              ),
              Text(
                suffix,
                style: TextStyle(
                  fontSize: 11,
                  color: secondaryTextColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Live 3-Month Booking Calendar ──────────────────────────────────────────

  Widget _buildAvailabilityCalendar(RentalVehicle v, bool isDark) {
    return StreamBuilder<List<RentalBooking>>(
      stream: customerRentalRepository.streamVehicleBookings(v.id),
      builder: (context, snapshot) {
        final bookings = snapshot.data ?? const [];
        return VehicleBookingCalendar(
          bookings: bookings,
          blackoutDates: v.blackoutDates,
        );
      },
    );
  }

  // ── Features & Amenities Chips (Displays 4, expands to all on tap) ─────────

  Widget _buildAmenitiesChips(RentalVehicle v, bool isDark) {
    final totalFeatures = v.features.length;
    final displayedFeatures = _featuresExpanded
        ? v.features
        : v.features.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: displayedFeatures.map((f) {
            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurface
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(24),
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
                    Icons.check_circle_rounded,
                    size: 14,
                    color: AppColors.brand,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    f,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : const Color(0xFF374151),
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
        if (totalFeatures > 4) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => setState(() => _featuresExpanded = !_featuresExpanded),
            child: Text(
              _featuresExpanded
                  ? 'Show less'
                  : 'View all amenities ($totalFeatures)',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.brand,
              ),
            ),
          ),
        ],
      ],
    );
  }

  // ── Live Review & Assurance Card (No hardcoded text) ───────────────────────

  Widget _buildReviewAssuranceCard(
    RentalVehicle v,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    final hasRating = v.rating != null && v.rating! > 0;
    final reviewCount = v.reviewCount;

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => VehicleDetailsRatingScreen(vehicle: v),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                hasRating ? Icons.star_rounded : Icons.reviews_outlined,
                color: AppColors.brand,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (hasRating) ...[
                    Row(
                      children: [
                        Text(
                          '${v.rating!.toStringAsFixed(1)} Rating',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: primaryTextColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.star_rounded,
                          size: 17,
                          color: Color(0xFFF59E0B),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$reviewCount ${reviewCount == 1 ? 'review' : 'reviews'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: secondaryTextColor,
                        height: 1.4,
                      ),
                    ),
                  ] else ...[
                    Text(
                      'No reviews yet',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$reviewCount ${reviewCount == 1 ? 'review' : 'reviews'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: secondaryTextColor,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: secondaryTextColor,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  // ── Sticky Bottom Bar with Pill "Book Now →" Button ────────────────────────

  Widget _buildStickyBottomBar(
    BuildContext context,
    RentalVehicle v,
    bool isDark,
    Color secondaryTextColor,
  ) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.of(context).padding.bottom + 14,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark
                ? AppColors.glassBorderDark
                : const Color(0xFFE5E7EB),
          ),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
      ),
      child: Row(
        children: [
          // Starting price breakdown
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Starting from',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: secondaryTextColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                NgnFormat.currency(v.lowestAvailableRate),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: AppColors.brand,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),

          const SizedBox(width: 18),

          // Primary Pill Action Button: "Book Now →"
          Expanded(
            child: SizedBox(
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(0, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                onPressed: () => context.push(
                  CustomerRoutePaths.rentalBookingForm,
                  extra: v,
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Book Now',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_rounded, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color primaryTextColor) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: primaryTextColor,
        letterSpacing: -0.2,
      ),
    );
  }
}

/// Helper model for specification grid items.
class _SpecItem {
  const _SpecItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}
