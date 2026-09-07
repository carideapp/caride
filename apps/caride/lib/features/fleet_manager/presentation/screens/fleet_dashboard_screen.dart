import 'package:design_system/design_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_widgets/shared_widgets.dart';
import '../../controllers/fleet_manager_controller.dart';
import '../widgets/fleet_bottom_nav.dart';

/// Redesigned Fleet Dashboard Screen matching the CaRide design-system.md standards.
class FleetDashboardScreen extends StatefulWidget {
  const FleetDashboardScreen({super.key});

  @override
  State<FleetDashboardScreen> createState() => _FleetDashboardScreenState();
}

class _FleetDashboardScreenState extends State<FleetDashboardScreen> {
  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    fleetManagerController.init(uid);
  }

  void _showAssignDriverModal(RentalBooking booking) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final drivers = fleetManagerController.drivers;
    FleetDriver? selectedDriver;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
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
                      'Assign Driver & Confirm',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Booking for ${booking.vehicleTitle}',
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.brand),
                    ),
                    Text(
                      'Service: ${booking.serviceType.label} • ${booking.pickupLocation}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (booking.isChauffeur) ...[
                      Text(
                        'Select Chauffeur Driver',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : const Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (drivers.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.info_outline, color: Color(0xFFD97706), size: 20),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'No linked drivers yet. You can confirm now and assign later or add a driver in Fleet Drivers.',
                                  style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<FleetDriver>(
                              value: selectedDriver,
                              hint: const Text('Choose a registered driver', style: TextStyle(fontSize: 14)),
                              isExpanded: true,
                              dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
                              items: drivers.map((d) {
                                return DropdownMenuItem(
                                  value: d,
                                  child: Text('${d.fullName} (${d.phone})', style: const TextStyle(fontSize: 14)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                setModalState(() => selectedDriver = val);
                              },
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                    ],

                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                        ),
                        onPressed: () async {
                          Navigator.pop(ctx);
                          final messenger = ScaffoldMessenger.of(this.context);
                          try {
                            await fleetManagerController.approveBooking(
                              booking.id,
                              assignedDriverId: selectedDriver?.id,
                              assignedDriverName: selectedDriver?.fullName,
                              assignedDriverPhone: selectedDriver?.phone,
                            );
                            if (!mounted) return;
                            messenger.showSnackBar(
                              SnackBar(
                                content: const Text('Booking confirmed successfully!'),
                                backgroundColor: AppColors.brand,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            );
                          } catch (e) {
                            if (!mounted) return;
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text('Failed: $e'),
                                backgroundColor: AppColors.error,
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                            );
                          }
                        },
                        child: const Text('Confirm & Dispatch', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
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
    final primaryTextColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      extendBody: true,
      bottomNavigationBar: FleetBottomNav(currentIndex: 0),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Dashboard Title aligned to the left
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Dashboard',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: primaryTextColor,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
            ),

            // Dashboard Content
            Expanded(
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
                              'Fleet Workspace Ready',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: primaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Your fleet profile is set up. Add your vehicles and manage drivers from this portal.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
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
                                    borderRadius: BorderRadius.circular(26),
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

                  final pendingBookings = fleetManagerController.bookings
                      .where((b) => b.status == RentalBookingStatus.pendingApproval)
                      .toList();

                  return RefreshIndicator(
                    color: AppColors.brand,
                    onRefresh: () async {
                      fleetManagerController.init();
                    },
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 12.0, bottom: 96.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Business Header Card (CaRide Brand Green) ──
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF16A34A), Color(0xFF15803D)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF16A34A).withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 28,
                                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                                  child: const Icon(
                                    Icons.directions_car_filled_rounded,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              profile.businessName,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (profile.isVerified) ...[
                                            const SizedBox(width: 6),
                                            const Icon(
                                              Icons.verified_rounded,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${profile.city} • ${profile.phone}',
                                        style: TextStyle(
                                          color: Colors.white.withValues(alpha: 0.85),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),

                          // ── Live Stats Grid (20px Rounded Cards) ──
                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  title: 'Total Vehicles',
                                  value: '${fleetManagerController.totalVehiclesCount}',
                                  icon: Icons.directions_car_rounded,
                                  color: AppColors.brand,
                                  subtitle: '${fleetManagerController.availableVehiclesCount} Available',
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _StatCard(
                                  title: 'Active Rentals',
                                  value: '${fleetManagerController.activeBookingsCount}',
                                  icon: Icons.key_rounded,
                                  color: const Color(0xFF0EA5E9),
                                  subtitle: '${fleetManagerController.rentedVehiclesCount} On Road',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  title: 'Pending Orders',
                                  value: '${fleetManagerController.pendingBookingsCount}',
                                  icon: Icons.notification_important_rounded,
                                  color: const Color(0xFFF59E0B),
                                  subtitle: 'Requires action',
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: _StatCard(
                                  title: 'Total Revenue',
                                  value: NgnFormat.currency(fleetManagerController.totalRevenue),
                                  icon: Icons.payments_rounded,
                                  color: AppColors.brand,
                                  subtitle: 'Settled & Active',
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),

                          // ── Quick Actions ──
                          Text(
                            'Quick Actions',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _QuickActionButton(
                                  label: 'Add Car',
                                  icon: Icons.add_circle_outline_rounded,
                                  color: AppColors.brand,
                                  onTap: () => context.push(FleetRoutePaths.addVehicle),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _QuickActionButton(
                                  label: 'Inventory',
                                  icon: Icons.inventory_2_outlined,
                                  color: const Color(0xFF0EA5E9),
                                  onTap: () => context.push(FleetRoutePaths.vehicles),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _QuickActionButton(
                                  label: 'Orders',
                                  icon: Icons.receipt_long_rounded,
                                  color: AppColors.brand,
                                  badgeCount: fleetManagerController.pendingBookingsCount,
                                  onTap: () => context.push(FleetRoutePaths.bookings),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _QuickActionButton(
                                  label: 'Drivers',
                                  icon: Icons.people_alt_outlined,
                                  color: const Color(0xFF6366F1),
                                  onTap: () => context.push(FleetRoutePaths.drivers),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),

                          // ── Pending Booking Requests ──
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Pending Requests',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: primaryTextColor,
                                ),
                              ),
                              if (pendingBookings.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF3C7),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Text(
                                    '${pendingBookings.length} NEW',
                                    style: const TextStyle(
                                      color: Color(0xFFD97706),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          if (pendingBookings.isEmpty)
                            Container(
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
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    decoration: BoxDecoration(
                                      color: AppColors.brand.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.done_all_rounded,
                                      size: 32,
                                      color: AppColors.brand,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
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
                                      color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          else
                            ...pendingBookings.map((booking) {
                              return _BookingRequestCard(
                                booking: booking,
                                onAccept: () => _showAssignDriverModal(booking),
                                onDecline: () => _showDeclineModal(booking),
                              );
                            }),

                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
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

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.subtitle,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(18),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: color),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 18,
              color: isDark ? Colors.white : const Color(0xFF111827),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.textTertiaryDark : const Color(0xFF9CA3AF),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badgeCount = 0,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                    color: isDark ? Colors.white : const Color(0xFF1F2937),
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (badgeCount > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BookingRequestCard extends StatelessWidget {
  const _BookingRequestCard({
    required this.booking,
    required this.onAccept,
    required this.onDecline,
  });

  final RentalBooking booking;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
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
                        width: 64,
                        height: 52,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _carPlaceholder(),
                      )
                    : _carPlaceholder(),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.vehicleTitle,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.brand.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            booking.serviceType.label,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brand,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${booking.durationDays} Day(s)',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                NgnFormat.currency(booking.totalAmount),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.brand,
                ),
              ),
            ],
          ),
          Divider(height: 24, color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB)),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 16, color: AppColors.brand),
              const SizedBox(width: 6),
              Text(
                booking.customerName,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: isDark ? Colors.white : const Color(0xFF111827),
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
                    color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: Color(0xFFFCA5A5)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    onPressed: onDecline,
                    child: const Text('Decline', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    onPressed: onAccept,
                    child: Text(
                      booking.isChauffeur ? 'Assign Driver' : 'Approve Order',
                      style: const TextStyle(fontWeight: FontWeight.w600),
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
      width: 64,
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.directions_car, color: AppColors.brand, size: 24),
    );
  }
}
