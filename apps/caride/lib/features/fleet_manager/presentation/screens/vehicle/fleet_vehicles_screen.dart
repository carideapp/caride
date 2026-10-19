import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_widgets/shared_widgets.dart';
import 'package:caride/features/fleet_manager/controllers/fleet_manager_controller.dart';
import 'package:caride/features/fleet_manager/presentation/widgets/fleet_bottom_nav.dart';
import 'package:caride/features/car_rental/presentation/widgets/vehicle_booking_calendar.dart';

/// Redesigned Fleet Vehicles Inventory Screen matching the CaRide design-system.md standards.
class FleetVehiclesScreen extends StatefulWidget {
  const FleetVehiclesScreen({super.key});

  @override
  State<FleetVehiclesScreen> createState() => _FleetVehiclesScreenState();
}

class _FleetVehiclesScreenState extends State<FleetVehiclesScreen> {
  String _searchQuery = '';
  RentalVehicleStatus? _filterStatus;

  static const Color _lightInputFill = Color(0xFFF3F4F6);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      extendBody: true,
      bottomNavigationBar: FleetBottomNav(currentIndex: 3),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 56.0),
        child: FloatingActionButton.extended(
          backgroundColor: AppColors.brand,
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 22),
          label: const Text(
            'Add Vehicle',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
          ),
          onPressed: () => context.push(FleetRoutePaths.addVehicle),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Center(
                child: Text(
                  'Fleet Inventory',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: primaryTextColor,
                  ),
                ),
              ),
            ),

            // Search Bar (Pill)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
              child: TextFormField(
                style: TextStyle(color: primaryTextColor, fontSize: 15),
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'Search by make, model or plate...',
                  hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                  filled: true,
                  fillColor: isDark ? AppColors.darkSurface : _lightInputFill,
                  prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF9CA3AF), size: 22),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(28), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(28),
                    borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
                  ),
                ),
              ),
            ),

            // Filter Chips (Pill)
            ListenableBuilder(
              listenable: fleetManagerController,
              builder: (context, _) {
                final allVehicles = fleetManagerController.vehicles;
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                  child: Row(
                    children: [
                      _FilterChip(
                        label: 'All (${allVehicles.length})',
                        isSelected: _filterStatus == null,
                        isDark: isDark,
                        onTap: () => setState(() => _filterStatus = null),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Available (${fleetManagerController.availableVehiclesCount})',
                        isSelected: _filterStatus == RentalVehicleStatus.available,
                        isDark: isDark,
                        onTap: () => setState(() => _filterStatus = RentalVehicleStatus.available),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Inactive (${fleetManagerController.inactiveVehiclesCount})',
                        isSelected: _filterStatus == RentalVehicleStatus.inactive,
                        isDark: isDark,
                        onTap: () => setState(() => _filterStatus = RentalVehicleStatus.inactive),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Rented (${fleetManagerController.rentedVehiclesCount})',
                        isSelected: _filterStatus == RentalVehicleStatus.rented,
                        isDark: isDark,
                        onTap: () => setState(() => _filterStatus = RentalVehicleStatus.rented),
                      ),
                      const SizedBox(width: 8),
                      _FilterChip(
                        label: 'Maintenance (${fleetManagerController.maintenanceVehiclesCount})',
                        isSelected: _filterStatus == RentalVehicleStatus.maintenance,
                        isDark: isDark,
                        onTap: () => setState(() => _filterStatus = RentalVehicleStatus.maintenance),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Vehicle List
            Expanded(
              child: ListenableBuilder(
                listenable: fleetManagerController,
                builder: (context, _) {
                  final allVehicles = fleetManagerController.vehicles;
                  final filtered = allVehicles.where((v) {
                    final matchesQuery = _searchQuery.isEmpty ||
                        v.displayName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                        v.plateNumber.toLowerCase().contains(_searchQuery.toLowerCase());
                    final matchesStatus = _filterStatus == null || v.status == _filterStatus;
                    return matchesQuery && matchesStatus;
                  }).toList();

                  if (filtered.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: AppColors.brand.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.directions_car_outlined,
                              size: 48,
                              color: AppColors.brand,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            allVehicles.isEmpty
                                ? 'No vehicles added yet'
                                : 'No vehicles match your filter',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            allVehicles.isEmpty
                                ? 'Tap "+ Add Vehicle" to list your first rental car.'
                                : 'Try adjusting your search criteria.',
                            style: TextStyle(
                              color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.only(left: 20.0, right: 20.0, top: 8.0, bottom: 96.0),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final vehicle = filtered[index];
                      return _VehicleCard(vehicle: vehicle);
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
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
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
        child: Text(
          label,
          style: TextStyle(
            color: isSelected
                ? Colors.white
                : (isDark ? AppColors.textSecondaryDark : const Color(0xFF4B5563)),
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  const _VehicleCard({required this.vehicle});

  final RentalVehicle vehicle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color statusColor;
    Color statusBg;
    switch (vehicle.status) {
      case RentalVehicleStatus.available:
        statusColor = AppColors.brand;
        statusBg = const Color(0xFFDCFCE7);
        break;
      case RentalVehicleStatus.rented:
        statusColor = const Color(0xFF0EA5E9);
        statusBg = const Color(0xFFE0F2FE);
        break;
      case RentalVehicleStatus.maintenance:
        statusColor = const Color(0xFFF59E0B);
        statusBg = const Color(0xFFFEF3C7);
        break;
      case RentalVehicleStatus.inactive:
        statusColor = const Color(0xFF9CA3AF);
        statusBg = const Color(0xFFF3F4F6);
        break;
    }

    final isActive = vehicle.status != RentalVehicleStatus.inactive;

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: vehicle.images.isNotEmpty
                    ? Image.network(
                        vehicle.images.first,
                        width: 76,
                        height: 56,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      vehicle.displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${vehicle.plateNumber} • ${vehicle.category.label}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Active / Inactive Switch in top right
              GestureDetector(
                onTap: () => _handleToggleStatus(context, vehicle, !isActive),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isActive
                        ? AppColors.brand.withValues(alpha: 0.08)
                        : (isDark ? Colors.white10 : const Color(0xFFF3F4F6)),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isActive
                          ? AppColors.brand.withValues(alpha: 0.25)
                          : (isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB)),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isActive
                              ? AppColors.brand
                              : (isDark ? AppColors.textTertiaryDark : const Color(0xFF9CA3AF)),
                        ),
                      ),
                      const SizedBox(width: 4),
                      SizedBox(
                        height: 20,
                        width: 34,
                        child: FittedBox(
                          fit: BoxFit.fill,
                          child: Switch.adaptive(
                            value: isActive,
                            activeThumbColor: AppColors.brand,
                            activeTrackColor: AppColors.brand.withValues(alpha: 0.35),
                            inactiveThumbColor: const Color(0xFF9CA3AF),
                            inactiveTrackColor: isDark ? Colors.white12 : const Color(0xFFE5E7EB),
                            onChanged: (val) => _handleToggleStatus(context, vehicle, val),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Divider(height: 24, color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        vehicle.dailySelfDriveRate > 0 || vehicle.dailyWithDriverRate > 0 ? 'Starting Rate' : 'Drop-Off Rate',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? AppColors.textTertiaryDark : const Color(0xFF9CA3AF),
                        ),
                      ),
                      Text(
                        '${NgnFormat.currency(vehicle.lowestAvailableRate)}${vehicle.dailySelfDriveRate > 0 || vehicle.dailyWithDriverRate > 0 ? '/day' : '/trip'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.brand,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 10),
                  // Vehicle Status Badge on the right side of price
                  InkWell(
                    onTap: () => _showStatusPickerBottomSheet(context, vehicle),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: statusColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            vehicle.status.label,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.brand,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      side: BorderSide(color: AppColors.brand.withValues(alpha: 0.4)),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.calendar_month_rounded, size: 14),
                    label: const Text('Schedule', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    onPressed: () => _showVehicleScheduleBottomSheet(context, vehicle),
                  ),
                  const SizedBox(width: 6),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.brand,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      side: BorderSide(color: AppColors.brand.withValues(alpha: 0.4)),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: const Text('Edit', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    onPressed: () => context.push(
                      FleetRoutePaths.editVehicle,
                      extra: vehicle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    icon: const Icon(Icons.delete_outline_rounded, size: 14),
                    label: const Text('Delete', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                    onPressed: () => _confirmDeleteVehicle(context, vehicle),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _placeholder() {
    return Container(
      width: 76,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.brand.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.directions_car_rounded, color: AppColors.brand, size: 28),
    );
  }

  void _showVehicleScheduleBottomSheet(BuildContext context, RentalVehicle vehicle) {
    final activeBookings =
        fleetManagerController.getActiveBookingsForVehicle(vehicle.id);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final primaryText = isDark ? Colors.white : const Color(0xFF111827);
        final secondaryText =
            isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);
        final mediaQuery = MediaQuery.of(ctx);
        final maxSheetHeight = mediaQuery.size.height * 0.90;

        return Container(
          constraints: BoxConstraints(
            maxHeight: maxSheetHeight,
            minHeight: mediaQuery.size.height * 0.50,
          ),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
            20,
            16,
            20,
            mediaQuery.viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top drag handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Pinned Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.calendar_month_rounded,
                      color: AppColors.brand,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          vehicle.displayName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: primaryText,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${vehicle.plateNumber} • 3-Month Booking Schedule',
                          style: TextStyle(
                            fontSize: 12,
                            color: secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Scrollable Responsive Content
              Flexible(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      VehicleBookingCalendar(
                        bookings: activeBookings,
                        blackoutDates: vehicle.blackoutDates,
                        isManagerMode: true,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        'Upcoming Reservations (${activeBookings.length})',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: primaryText,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (activeBookings.isEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.04)
                                : const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.glassBorderDark
                                  : const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: Center(
                            child: Text(
                              'No upcoming bookings scheduled for this vehicle.',
                              style: TextStyle(fontSize: 13, color: secondaryText),
                            ),
                          ),
                        )
                      else
                        ...activeBookings.map((b) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.04)
                                  : const Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.glassBorderDark
                                    : const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.brand,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        b.customerName.isNotEmpty ? b.customerName : 'Customer Booking',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: primaryText,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${DateFormat('MMM d').format(b.startDate)} - ${DateFormat('MMM d, yyyy').format(b.endDate)} • ${b.serviceType.label}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: secondaryText,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.brand.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    b.status.label,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.brand,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Pinned Close Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                    elevation: 0,
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text(
                    'Close Schedule',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
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

  Future<void> _confirmDeleteVehicle(BuildContext context, RentalVehicle vehicle) async {
    final confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final sheetDark = Theme.of(ctx).brightness == Brightness.dark;
        final sheetText = sheetDark ? Colors.white : const Color(0xFF111827);
        final sheetSub = sheetDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);

        return Container(
          decoration: BoxDecoration(
            color: sheetDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
            24, 16, 24,
            MediaQuery.of(ctx).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 22),

              // Warning icon in tinted circle
              Center(
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_outline_rounded, size: 34, color: AppColors.error),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Delete Vehicle',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: sheetText),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Remove ${vehicle.displayName} (${vehicle.plateNumber}) from your fleet?\nThis will remove the vehicle from your inventory.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: sheetSub, height: 1.45),
                ),
              ),
              const SizedBox(height: 24),

              // Confirm button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text(
                    'Yes, Delete Vehicle',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Cancel button
              SizedBox(
                width: double.infinity,
                height: 46,
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: sheetSub,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        );
      },
    );

    if (confirm == true && context.mounted) {
      try {
        await fleetManagerController.deleteVehicle(vehicle.id);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${vehicle.displayName} deleted successfully'),
              backgroundColor: AppColors.brand,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete vehicle: $e'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          );
        }
      }
    }
  }

  Future<void> _handleToggleStatus(
    BuildContext context,
    RentalVehicle vehicle,
    bool makeActive,
  ) async {
    if (!makeActive && vehicle.status == RentalVehicleStatus.rented) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Cannot deactivate a vehicle while it is on an active rental trip.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
      return;
    }

    final newStatus = makeActive ? RentalVehicleStatus.available : RentalVehicleStatus.inactive;

    try {
      await fleetManagerController.toggleVehicleStatus(vehicle.id, newStatus);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  makeActive ? Icons.check_circle_rounded : Icons.pause_circle_outline_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    makeActive
                        ? '${vehicle.displayName} marked as Active (available for bookings)'
                        : '${vehicle.displayName} marked as Inactive (hidden from bookings)',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
            ),
            backgroundColor: makeActive ? AppColors.brand : const Color(0xFF374151),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update status: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
    }
  }

  Future<void> _showStatusPickerBottomSheet(BuildContext context, RentalVehicle vehicle) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final sheetDark = Theme.of(ctx).brightness == Brightness.dark;
        final cardBg = sheetDark ? AppColors.darkBackground : const Color(0xFFF9FAFB);
        final borderColor = sheetDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);

        return Container(
          decoration: BoxDecoration(
            color: sheetDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.fromLTRB(
            24, 16, 24,
            MediaQuery.of(ctx).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.tune_rounded, color: AppColors.brand, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vehicle Status',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${vehicle.displayName} • ${vehicle.plateNumber}',
                          style: TextStyle(fontSize: 13, color: secondaryTextColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (vehicle.status == RentalVehicleStatus.rented) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBAE6FD)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, color: Color(0xFF0284C7), size: 20),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'This vehicle is on an active rental trip. Status will automatically update when the trip completes.',
                          style: TextStyle(color: Color(0xFF0369A1), fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Option 1: Available (Active)
              _buildStatusOptionTile(
                ctx: ctx,
                title: 'Active (Available)',
                subtitle: 'Vehicle is ready and listed for customer bookings',
                icon: Icons.check_circle_rounded,
                accentColor: AppColors.brand,
                isSelected: vehicle.status == RentalVehicleStatus.available,
                cardBg: cardBg,
                borderColor: borderColor,
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor,
                onTap: () async {
                  Navigator.pop(ctx);
                  if (vehicle.status != RentalVehicleStatus.available) {
                    await _handleToggleStatus(context, vehicle, true);
                  }
                },
              ),
              const SizedBox(height: 10),

              // Option 2: Inactive (Paused)
              _buildStatusOptionTile(
                ctx: ctx,
                title: 'Inactive (Paused)',
                subtitle: 'Temporarily hide vehicle from customer search & bookings',
                icon: Icons.pause_circle_outline_rounded,
                accentColor: const Color(0xFF6B7280),
                isSelected: vehicle.status == RentalVehicleStatus.inactive,
                cardBg: cardBg,
                borderColor: borderColor,
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor,
                onTap: () async {
                  Navigator.pop(ctx);
                  if (vehicle.status != RentalVehicleStatus.inactive) {
                    await _handleToggleStatus(context, vehicle, false);
                  }
                },
              ),
              const SizedBox(height: 10),

              // Option 3: Maintenance
              _buildStatusOptionTile(
                ctx: ctx,
                title: 'Under Maintenance',
                subtitle: 'Vehicle is currently in service, repairs, or inspection',
                icon: Icons.build_circle_outlined,
                accentColor: const Color(0xFFF59E0B),
                isSelected: vehicle.status == RentalVehicleStatus.maintenance,
                cardBg: cardBg,
                borderColor: borderColor,
                primaryTextColor: primaryTextColor,
                secondaryTextColor: secondaryTextColor,
                onTap: () async {
                  Navigator.pop(ctx);
                  if (vehicle.status == RentalVehicleStatus.rented) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('Cannot set to maintenance while vehicle is on a live rental trip.'),
                        backgroundColor: AppColors.error,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    );
                    return;
                  }
                  try {
                    await fleetManagerController.toggleVehicleStatus(
                      vehicle.id,
                      RentalVehicleStatus.maintenance,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${vehicle.displayName} marked as Under Maintenance'),
                          backgroundColor: const Color(0xFFF59E0B),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to update status: $e'),
                          backgroundColor: AppColors.error,
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 16),

              // Close button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: secondaryTextColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Dismiss', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusOptionTile({
    required BuildContext ctx,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required bool isSelected,
    required Color cardBg,
    required Color borderColor,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withValues(alpha: 0.08) : cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? accentColor : borderColor,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isSelected ? accentColor : primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: secondaryTextColor),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle_rounded, color: accentColor, size: 20),
          ],
        ),
      ),
    );
  }
}
