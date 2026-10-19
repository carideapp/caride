import 'package:design_system/design_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_widgets/shared_widgets.dart';
import 'package:caride/features/fleet_manager/controllers/fleet_manager_controller.dart';
import 'package:caride/features/fleet_manager/presentation/widgets/fleet_bottom_nav.dart';

/// Redesigned Fleet Home Screen matching UI/Home.png & reference mockup aesthetics.
class FleetDashboardScreen extends StatefulWidget {
  const FleetDashboardScreen({super.key});

  @override
  State<FleetDashboardScreen> createState() => _FleetDashboardScreenState();
}

class _FleetDashboardScreenState extends State<FleetDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedBrand;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    fleetManagerController.init(uid);
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  void _showAssignDriverModal(RentalBooking booking) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (dialogCtx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 16,
            bottom: MediaQuery.of(dialogCtx).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 48, height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_outline_rounded, color: AppColors.brand, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                'Approve Booking',
                style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Approve the rental of ${booking.vehicleTitle} for ${booking.customerName}?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.brand.withValues(alpha: 0.25)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded, color: AppColors.brand, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'The customer will be notified to complete payment. You can assign a driver after payment.',
                        style: TextStyle(fontSize: 12, color: AppColors.brand),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  onPressed: () async {
                    Navigator.pop(dialogCtx);
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await fleetManagerController.approveBookingForPayment(booking.id);
                      if (!mounted) return;
                      messenger.showSnackBar(SnackBar(
                        content: const Text('Booking approved! Customer notified to pay.'),
                        backgroundColor: AppColors.brand,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ));
                    } catch (e) {
                      if (!mounted) return;
                      messenger.showSnackBar(SnackBar(
                        content: Text('Failed: $e'),
                        backgroundColor: AppColors.error,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ));
                    }
                  },
                  child: const Text('Yes, Approve Booking', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text('Cancel',
                    style: TextStyle(color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280))),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeclineModal(RentalBooking booking) {
    final reasonController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (dialogCtx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: MediaQuery.of(dialogCtx).viewInsets.bottom + 24,
        ),
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
            Text(
              'Decline Booking',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Are you sure you want to decline booking for ${booking.vehicleTitle}?',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: reasonController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Reason (e.g. vehicle booked offline)',
                filled: true,
                fillColor: isDark ? AppColors.darkSurface : const Color(0xFFF3F4F6),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                        side: const BorderSide(color: Color(0xFFD1D5DB)),
                      ),
                      onPressed: () => Navigator.pop(dialogCtx),
                      child: const Text('Cancel'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.error,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                      ),
                      onPressed: () async {
                        Navigator.pop(dialogCtx);
                        try {
                          await fleetManagerController.declineBooking(
                            booking.id,
                            reason: reasonController.text.trim(),
                          );
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text('Booking declined.'),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: AppColors.error,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            );
                          }
                        }
                      },
                      child: const Text('Decline', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ),
              ],
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

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      extendBody: true,
      bottomNavigationBar: FleetBottomNav(currentIndex: 0),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: fleetManagerController,
          builder: (context, _) {
            final profile = fleetManagerController.currentProfile;

            if (profile == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.brand.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.domain_rounded,
                          size: 48,
                          color: AppColors.brand,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Fleet Portal Ready',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Set up your fleet profile to showcase your vehicles and manage bookings.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: secondaryTextColor,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          icon: const Icon(Icons.add_rounded, size: 20),
                          label: const Text(
                            'Add Your First Vehicle',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          onPressed: () => context.push(FleetRoutePaths.addVehicle),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Vehicles filtering
            final allVehicles = fleetManagerController.vehicles;
            final query = _searchQuery.toLowerCase();
            final filteredVehicles = allVehicles.where((v) {
              final matchesQuery = query.isEmpty ||
                  v.make.toLowerCase().contains(query) ||
                  v.model.toLowerCase().contains(query) ||
                  v.city.toLowerCase().contains(query);
              final matchesBrand = _selectedBrand == null ||
                  v.make.toLowerCase() == _selectedBrand!.toLowerCase();
              return matchesQuery && matchesBrand;
            }).toList();

            // Include awaitingPayment bookings so fleet manager can see them
            final pendingBookings = fleetManagerController.bookings
                .where((b) =>
                    b.status == RentalBookingStatus.pendingApproval ||
                    b.status == RentalBookingStatus.awaitingPayment)
                .toList();

            final managerFirstName = profile.fullName.trim().isNotEmpty
                ? profile.fullName.trim().split(' ').first
                : profile.businessName;

            final locationDisplay = profile.city.isNotEmpty
                ? (profile.state.isNotEmpty &&
                        profile.state.toLowerCase() != profile.city.toLowerCase()
                    ? '${profile.city}, ${profile.state}'
                    : '${profile.city}, Nigeria')
                : (profile.state.isNotEmpty
                    ? '${profile.state}, Nigeria'
                    : 'Nigeria');

            return RefreshIndicator(
              color: AppColors.brand,
              onRefresh: () async {
                fleetManagerController.init();
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 110.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── 1. Top Bar: Location & Avatar ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Location badge & city
                          Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? AppColors.darkSurface
                                      : const Color(0xFFF3F4F6),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark
                                        ? AppColors.glassBorderDark
                                        : const Color(0xFFE5E7EB),
                                  ),
                                ),
                                child: const Icon(
                                  Icons.location_on_rounded,
                                  color: AppColors.brand,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Your location',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: secondaryTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 1),
                                  Text(
                                    locationDisplay,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: primaryTextColor,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),

                          // Clean Circular Profile Avatar (No glows, adhering to AGENTS.md)
                          GestureDetector(
                            onTap: () => context.push(FleetRoutePaths.profile),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDark
                                      ? AppColors.glassBorderDark
                                      : const Color(0xFFE5E7EB),
                                  width: 1.5,
                                ),
                              ),
                              child: ClipOval(
                                child: profile.profilePictureUrl != null &&
                                        profile.profilePictureUrl!.isNotEmpty
                                    ? Image.network(
                                        profile.profilePictureUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => _avatarFallback(profile),
                                      )
                                    : _avatarFallback(profile),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── 2. Welcoming Headline (UI/Home.png & Attached Mockup Reference) ──
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_getGreeting()}, $managerFirstName',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: primaryTextColor,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Locate and manage your fleet vehicles.',
                            style: TextStyle(
                              fontSize: 14,
                              color: secondaryTextColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ── 3. Pill Search Bar ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurface : const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: TextField(
                          controller: _searchController,
                          style: TextStyle(
                            fontSize: 14,
                            color: primaryTextColor,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search vehicle, make, or location...',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: secondaryTextColor,
                            ),
                            prefixIcon: Icon(
                              Icons.search_rounded,
                              color: secondaryTextColor,
                              size: 22,
                            ),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 20),
                                    onPressed: () {
                                      _searchController.clear();
                                    },
                                  )
                                : Icon(
                                    Icons.tune_rounded,
                                    color: secondaryTextColor,
                                    size: 20,
                                  ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── 4. Hero Feature Banner (CaRide Emerald Brand Gradient) ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF16A34A), Color(0xFF15803D)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Background decorative circle
                            Positioned(
                              right: -30,
                              bottom: -40,
                              child: Container(
                                width: 140,
                                height: 140,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'FLEET GROWTH',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 1.1,
                                          color: Colors.white.withValues(alpha: 0.85),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      const Text(
                                        'Expand Your Fleet Revenue',
                                        style: TextStyle(
                                          fontSize: 19,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                          height: 1.2,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Add verified rental vehicles & dispatch drivers easily.',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.white.withValues(alpha: 0.9),
                                          height: 1.3,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: AppColors.brand,
                                          elevation: 0,
                                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(28),
                                          ),
                                        ),
                                        icon: const Icon(Icons.add_rounded, size: 18, color: AppColors.brand),
                                        label: const Text(
                                          'Add Vehicle',
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                                        ),
                                        onPressed: () => context.push(FleetRoutePaths.addVehicle),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Container(
                                  width: 72,
                                  height: 72,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.directions_car_filled_rounded,
                                    color: Colors.white,
                                    size: 38,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),


                    const SizedBox(height: 24),

                    // ── 5. Top Brands Section (Attached Mockup Reference) ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Top Brands',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: primaryTextColor,
                            ),
                          ),
                          if (_selectedBrand != null)
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedBrand = null;
                                });
                              },
                              child: const Text(
                                'Clear Filter',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.brand,
                                ),
                              ),
                            )
                          else
                            GestureDetector(
                              onTap: () => context.push(FleetRoutePaths.vehicles),
                              child: const Text(
                                'See All',
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
                      height: 84,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          _buildBrandItem(
                            brandName: 'Toyota',
                            icon: Icons.directions_car_rounded,
                            isDark: isDark,
                          ),
                          const SizedBox(width: 12),
                          _buildBrandItem(
                            brandName: 'Honda',
                            icon: Icons.speed_rounded,
                            isDark: isDark,
                          ),
                          const SizedBox(width: 12),
                          _buildBrandItem(
                            brandName: 'Mercedes',
                            icon: Icons.stars_rounded,
                            isDark: isDark,
                          ),
                          const SizedBox(width: 12),
                          _buildBrandItem(
                            brandName: 'Lexus',
                            icon: Icons.shield_rounded,
                            isDark: isDark,
                          ),
                          const SizedBox(width: 12),
                          _buildBrandItem(
                            brandName: 'Hyundai',
                            icon: Icons.electric_car_rounded,
                            isDark: isDark,
                          ),
                          const SizedBox(width: 12),
                          _buildBrandItem(
                            brandName: 'Ford',
                            icon: Icons.airport_shuttle_rounded,
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── 6. Identify & Track Fleet Map Banner (Attached Mockup Reference) ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: GestureDetector(
                        onTap: () => context.push(FleetRoutePaths.vehicles),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? AppColors.glassBorderDark : const Color(0xFF334155),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Map thumbnail snippet
                              Container(
                                width: 72,
                                height: 50,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF334155),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Icon(
                                      Icons.map_rounded,
                                      color: Colors.white.withValues(alpha: 0.25),
                                      size: 32,
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.location_on,
                                        color: AppColors.brand,
                                        size: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Locate Fleet Inventory',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14,
                                      ),
                                    ),
                                    SizedBox(height: 3),
                                    Text(
                                      'View active cars across operating hubs',
                                      style: TextStyle(
                                        color: Color(0xFF94A3B8),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 36,
                                height: 36,
                                decoration: const BoxDecoration(
                                  color: AppColors.brand,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.arrow_forward_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    // ── 7. Fleet Vehicles Section ("Available Near You" layout) ──
                    // STRICTLY NO STATUS TAGS PER USER INSTRUCTION
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedBrand != null
                                ? '$_selectedBrand Vehicles'
                                : 'Fleet Vehicles',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: primaryTextColor,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context.push(FleetRoutePaths.vehicles),
                            child: const Text(
                              'See All',
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

                    if (filteredVehicles.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.directions_car_outlined,
                                size: 40,
                                color: secondaryTextColor,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _selectedBrand != null
                                    ? 'No $_selectedBrand vehicles found'
                                    : 'No vehicles registered yet',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: primaryTextColor,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Tap "Add Vehicle" above to list your cars.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: secondaryTextColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        height: 245,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: filteredVehicles.length,
                          separatorBuilder: (_, __) => const SizedBox(width: 14),
                          itemBuilder: (context, index) {
                            final vehicle = filteredVehicles[index];
                            return _VehicleCard(
                              vehicle: vehicle,
                              isDark: isDark,
                              onTap: () => context.push(FleetRoutePaths.vehicles),
                            );
                          },
                        ),
                      ),

                    const SizedBox(height: 30),

                    // ── 8. Recent Bookings Section (No Status Tags UI) ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Bookings',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: primaryTextColor,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context.push(FleetRoutePaths.bookings),
                            child: const Text(
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

                    if (pendingBookings.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.brand.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.done_all_rounded,
                                  size: 28,
                                  color: AppColors.brand,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'All caught up!',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                  color: primaryTextColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'No pending rental bookings waiting for approval.',
                                style: TextStyle(
                                  color: secondaryTextColor,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: pendingBookings.map((booking) {
                            return _BookingCard(
                              booking: booking,
                              isDark: isDark,
                              onAccept: booking.status == RentalBookingStatus.pendingApproval
                                  ? () => _showAssignDriverModal(booking)
                                  : null, // no action for awaitingPayment cards
                              onDecline: booking.status == RentalBookingStatus.pendingApproval
                                  ? () => _showDeclineModal(booking)
                                  : null,
                            );
                          }).toList(),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBrandItem({
    required String brandName,
    required IconData icon,
    required bool isDark,
  }) {
    final isSelected = _selectedBrand?.toLowerCase() == brandName.toLowerCase();
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);

    return GestureDetector(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedBrand = null;
          } else {
            _selectedBrand = brandName;
          }
        });
      },
      child: Container(
        width: 76,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brand.withValues(alpha: 0.1)
              : (isDark ? AppColors.darkSurface : const Color(0xFFF9FAFB)),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? AppColors.brand
                : (isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.brand
                    : (isDark ? const Color(0xFF374151) : const Color(0xFFF3F4F6)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 20,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : const Color(0xFF4B5563)),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              brandName,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? AppColors.brand : primaryTextColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarFallback(FleetProfile profile) {
    final initials = profile.fullName.trim().isNotEmpty
        ? profile.fullName.trim().split(' ').map((n) => n[0]).take(2).join()
        : profile.businessName.characters.take(2).toString();

    return Container(
      color: AppColors.brand.withValues(alpha: 0.15),
      alignment: Alignment.center,
      child: Text(
        initials.toUpperCase(),
        style: const TextStyle(
          color: AppColors.brand,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    );
  }
}

/// Vehicle Card adhering strictly to: "avoid the use of status, tags ui"
class _VehicleCard extends StatelessWidget {
  const _VehicleCard({
    required this.vehicle,
    required this.isDark,
    required this.onTap,
  });

  final RentalVehicle vehicle;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);
    final dailyRate = vehicle.dailySelfDriveRate > 0
        ? vehicle.dailySelfDriveRate
        : vehicle.dailyWithDriverRate;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 205,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vehicle Image Container
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 120,
                width: double.infinity,
                color: isDark ? const Color(0xFF374151) : const Color(0xFFE5E7EB),
                child: vehicle.images.isNotEmpty
                    ? Image.network(
                        vehicle.images.first,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _vehiclePlaceholder(),
                      )
                    : _vehiclePlaceholder(),
              ),
            ),
            const SizedBox(height: 10),

            // Vehicle Title
            Text(
              '${vehicle.make} ${vehicle.model}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: primaryTextColor,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 3),

            // Specs Row (Seats • Transmission • Year)
            Text(
              '${vehicle.seats} Seats • ${vehicle.transmission}',
              style: TextStyle(
                fontSize: 11,
                color: secondaryTextColor,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),

            // Price Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    NgnFormat.currency(dailyRate),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                      color: AppColors.brand,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '/ day',
                  style: TextStyle(
                    fontSize: 11,
                    color: secondaryTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _vehiclePlaceholder() {
    return Container(
      color: AppColors.brand.withValues(alpha: 0.1),
      child: const Center(
        child: Icon(
          Icons.directions_car_filled_rounded,
          color: AppColors.brand,
          size: 32,
        ),
      ),
    );
  }
}

/// Booking Card adhering strictly to: "avoid the use of status, tags ui"
class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    required this.isDark,
    required this.onAccept,
    required this.onDecline,
  });

  final RentalBooking booking;
  final bool isDark;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;

  @override
  Widget build(BuildContext context) {
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: booking.vehicleImage.isNotEmpty
                    ? Image.network(
                        booking.vehicleImage,
                        width: 60,
                        height: 50,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _carPlaceholder(),
                      )
                    : _carPlaceholder(),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.vehicleTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: primaryTextColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${booking.serviceType.label} • ${booking.durationDays} Day(s)',
                      style: TextStyle(
                        fontSize: 12,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                NgnFormat.currency(booking.totalAmount),
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: AppColors.brand,
                ),
              ),
            ],
          ),
          Divider(
            height: 20,
            color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
          ),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 16, color: AppColors.brand),
              const SizedBox(width: 6),
              Text(
                booking.customerName,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: primaryTextColor,
                ),
              ),
              const Spacer(),
              const Icon(Icons.location_on_outlined, size: 16, color: AppColors.brand),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  booking.pickupLocation,
                  style: TextStyle(
                    fontSize: 12,
                    color: secondaryTextColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // ── Status-Aware Action Buttons ──────────────────────────────────
          if (booking.status == RentalBookingStatus.awaitingPayment)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.schedule_rounded, color: Color(0xFFD97706), size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Awaiting customer payment. Driver can be assigned after payment.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF92400E), fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            )
          else
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: Color(0xFFFCA5A5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                      ),
                      onPressed: onDecline,
                      child: const Text('Decline', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.brand,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                      ),
                      onPressed: onAccept,
                      child: const Text(
                        'Approve Booking',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _carPlaceholder() {
    return Container(
      width: 60,
      height: 50,
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.directions_car, color: AppColors.brand, size: 24),
    );
  }
}
