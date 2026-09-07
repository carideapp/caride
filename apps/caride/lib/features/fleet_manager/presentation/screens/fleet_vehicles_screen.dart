import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_widgets/shared_widgets.dart';
import '../../controllers/fleet_manager_controller.dart';
import '../widgets/fleet_bottom_nav.dart';

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
            // Top Bar with Circular Back Button & Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: primaryTextColor,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Fleet Inventory',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
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
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  vehicle.status.label,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          Divider(height: 24, color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Rate',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? AppColors.textTertiaryDark : const Color(0xFF9CA3AF),
                    ),
                  ),
                  Text(
                    '${NgnFormat.currency(vehicle.dailySelfDriveRate > 0 ? vehicle.dailySelfDriveRate : vehicle.dailyWithDriverRate)}/day',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.brand,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.brand),
                    onPressed: () => context.push(
                      FleetRoutePaths.editVehicle,
                      extra: vehicle,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppColors.error),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: const Text('Delete Vehicle'),
                          content: Text('Remove ${vehicle.displayName} from your fleet?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.error,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Delete', style: TextStyle(color: Colors.white)),
                            ),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await fleetManagerController.deleteVehicle(vehicle.id);
                      }
                    },
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
}
