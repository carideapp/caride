import 'dart:async';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';
import 'package:caride/features/fleet_manager/controllers/fleet_manager_controller.dart';
import 'package:caride/features/fleet_manager/presentation/screens/vehicle/search_add_driver_screen.dart';

/// Screen allowing Fleet Managers to view, search, add and remove drivers.
class FleetDriverManagementScreen extends StatefulWidget {
  const FleetDriverManagementScreen({super.key});

  @override
  State<FleetDriverManagementScreen> createState() => _FleetDriverManagementScreenState();
}

class _FleetDriverManagementScreenState extends State<FleetDriverManagementScreen> {
  final TextEditingController _filterController = TextEditingController();
  String _filterQuery = '';

  @override
  void dispose() {
    _filterController.dispose();
    super.dispose();
  }

  Future<void> _navigateToAddDriver() async {
    final newDriver = await Navigator.of(context).push<FleetDriver>(
      MaterialPageRoute(
        builder: (_) => SearchAddDriverScreen(
          onDriverLinked: (driver) {
            if (mounted) {
              setState(() {});
            }
          },
        ),
      ),
    );
    if (newDriver != null && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.brand,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        icon: const Icon(Icons.person_search_rounded, color: Colors.white, size: 20),
        label: const Text(
          'Search & Add Driver',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
        ),
        onPressed: _navigateToAddDriver,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
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
                      'Drivers Management',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                      ),
                    ),
                  ),
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
                      icon: const Icon(
                        Icons.person_add_alt_1_rounded,
                        size: 20,
                        color: AppColors.brand,
                      ),
                      tooltip: 'Search & Add Driver',
                      onPressed: _navigateToAddDriver,
                    ),
                  ),
                ],
              ),
            ),

            // In-screen Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, color: AppColors.brand, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _filterController,
                        style: TextStyle(
                          fontSize: 14,
                          color: primaryTextColor,
                        ),
                        decoration: const InputDecoration(
                          hintText: 'Search drivers by name, phone or @username...',
                          hintStyle: TextStyle(
                            color: Color(0xFF9CA3AF),
                            fontSize: 13,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 12),
                        ),
                        onChanged: (val) {
                          setState(() {
                            _filterQuery = val.trim().toLowerCase();
                          });
                        },
                      ),
                    ),
                    if (_filterController.text.isNotEmpty)
                      IconButton(
                        icon: const Icon(Icons.clear, size: 18, color: Color(0xFF9CA3AF)),
                        onPressed: () {
                          _filterController.clear();
                          setState(() {
                            _filterQuery = '';
                          });
                        },
                      ),
                  ],
                ),
              ),
            ),

            // Drivers List
            Expanded(
              child: ListenableBuilder(
                listenable: fleetManagerController,
                builder: (context, _) {
                  final allDrivers = fleetManagerController.drivers;
                  final filteredDrivers = _filterQuery.isEmpty
                      ? allDrivers
                      : allDrivers.where((d) {
                          final name = d.fullName.toLowerCase();
                          final phone = d.phone.toLowerCase();
                          final email = d.email.toLowerCase();
                          final user = (d.username ?? '').toLowerCase();
                          return name.contains(_filterQuery) ||
                              phone.contains(_filterQuery) ||
                              email.contains(_filterQuery) ||
                              user.contains(_filterQuery);
                        }).toList();

                  if (allDrivers.isEmpty) {
                    return Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(22),
                              decoration: BoxDecoration(
                                color: AppColors.brand.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.people_outline_rounded,
                                size: 52,
                                color: AppColors.brand,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              'No drivers registered yet',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 17,
                                color: primaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tap "Search & Add Driver" to find drivers by username (@username), phone or email and link them to your fleet.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 22),
                            SizedBox(
                              height: 50,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.brand,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                                  padding: const EdgeInsets.symmetric(horizontal: 24),
                                ),
                                icon: const Icon(Icons.person_search_rounded, size: 20),
                                label: const Text(
                                  'Search & Add Driver',
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                ),
                                onPressed: _navigateToAddDriver,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  if (filteredDrivers.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.search_off_rounded, size: 48, color: Color(0xFF9CA3AF)),
                            const SizedBox(height: 12),
                            Text(
                              'No linked drivers match "$_filterQuery"',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: primaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Want to search the CaRide platform driver pool to add them?',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.brand,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                              ),
                              icon: const Icon(Icons.person_add_rounded, size: 18),
                              label: const Text('Search Platform Drivers'),
                              onPressed: _navigateToAddDriver,
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                    itemCount: filteredDrivers.length,
                    itemBuilder: (context, index) {
                      final driver = filteredDrivers[index];
                      return _DriverListItem(driver: driver);
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

class _DriverListItem extends StatelessWidget {
  const _DriverListItem({required this.driver});

  final FleetDriver driver;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        children: [
          // Profile picture
          ClipOval(
            child: SizedBox(
              width: 48,
              height: 48,
              child: driver.profilePhotoUrl != null && driver.profilePhotoUrl!.isNotEmpty
                  ? Image.network(
                      driver.profilePhotoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _fallbackAvatar(),
                    )
                  : _fallbackAvatar(),
            ),
          ),
          const SizedBox(width: 14),

          // Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        driver.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: primaryTextColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.verified, color: AppColors.brand, size: 16),
                  ],
                ),
                if (driver.username != null && driver.username!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '@${driver.username!.replaceAll('@', '')}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.brand,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  driver.phone.isNotEmpty ? driver.phone : driver.email,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                  ),
                ),
                if (driver.assignedVehicleTitle != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.directions_car, size: 12, color: AppColors.brand),
                        const SizedBox(width: 4),
                        Text(
                          driver.assignedVehicleTitle!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.brand,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Remove driver button
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              side: BorderSide(color: AppColors.error.withValues(alpha: 0.4)),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () async {
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

                        // Warning icon
                        Center(
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.person_remove_rounded, size: 34, color: AppColors.error),
                          ),
                        ),
                        const SizedBox(height: 16),

                        Text(
                          'Remove Driver',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: sheetText),
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'Remove ${driver.fullName} from your fleet?\nThey will no longer be assigned to your fleet vehicles.',
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
                            child: const Text('Yes, Remove Driver', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
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

              if (confirm == true) {
                try {
                  await fleetManagerController.removeDriver(driver.id);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${driver.fullName} removed from fleet.'),
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
                        content: Text('Failed to remove driver: $e'),
                        backgroundColor: AppColors.error,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    );
                  }
                }
              }
            },
            child: const Text('Delete', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  Widget _fallbackAvatar() {
    return Container(
      color: AppColors.brand.withValues(alpha: 0.12),
      child: Center(
        child: Text(
          driver.fullName.isNotEmpty ? driver.fullName[0].toUpperCase() : 'D',
          style: const TextStyle(
            color: AppColors.brand,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}

/// Show bottom sheet to search and add a driver from the platform `drivers` collection.
/// Can be invoked from Drivers Management or Assign Driver section in Add/Edit vehicle.
Future<FleetDriver?> showAddDriverBottomSheet(
  BuildContext context, {
  void Function(FleetDriver driver)? onDriverLinked,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;

  return showModalBottomSheet<FleetDriver>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (ctx) {
      return AnimatedPadding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: FractionallySizedBox(
          heightFactor: 0.88,
          child: _AddDriverSheetContent(onDriverLinked: onDriverLinked),
        ),
      );
    },
  );
}

class _AddDriverSheetContent extends StatefulWidget {
  const _AddDriverSheetContent({this.onDriverLinked});

  final void Function(FleetDriver driver)? onDriverLinked;

  @override
  State<_AddDriverSheetContent> createState() => _AddDriverSheetContentState();
}

class _AddDriverSheetContentState extends State<_AddDriverSheetContent> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  bool _isSearching = false;
  String _errorMessage = '';
  List<Map<String, dynamic>> _searchResults = [];

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _executeSearch(query);
    });
  }

  Future<void> _executeSearch(String query) async {
    _debounceTimer?.cancel();
    final term = query.trim();
    if (term.isEmpty) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _errorMessage = '';
          _searchResults = [];
        });
      }
      return;
    }

    // ignore: avoid_print
    print('[CaRide Driver Sheet] Executing search for: "$term"...');

    setState(() {
      _isSearching = true;
      _errorMessage = '';
    });

    try {
      final results = await fleetManagerController.searchDriversFromPlatform(term);
      // ignore: avoid_print
      print('[CaRide Driver Sheet] Received ${results.length} drivers for: "$term"');
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      // ignore: avoid_print
      print('[CaRide Driver Sheet] Search error: $e');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Search error: $e';
        _isSearching = false;
      });
    }
  }

  Future<void> _selectDriver(Map<String, dynamic> rawDriver) async {
    final driverUid = (rawDriver['uid'] ?? rawDriver['id'] ?? '').toString();
    final fullName = (rawDriver['fullName'] ?? rawDriver['name'] ?? 'Driver').toString();
    final phone = (rawDriver['phoneNumber'] ?? rawDriver['phone'] ?? '').toString();
    final email = (rawDriver['email'] ?? '').toString();
    final username = rawDriver['username']?.toString();
    final photoUrl = (rawDriver['profilePictureUrl'] ?? rawDriver['photoUrl'])?.toString();

    // Check if already in fleet
    final alreadyLinked = fleetManagerController.drivers.any((d) => d.id == driverUid);
    if (alreadyLinked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$fullName is already linked to your fleet.'),
          backgroundColor: const Color(0xFFF59E0B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
      return;
    }

    // Open confirmation bottom sheet
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ConfirmLinkDriverSheet(
        fullName: fullName,
        phone: phone,
        email: email,
        username: username,
        photoUrl: photoUrl,
      ),
    );

    if (confirmed == true && mounted) {
      // Execute link
      try {
        await fleetManagerController.linkDriverToFleet(
          driverUid: driverUid,
          fullName: fullName,
          phone: phone,
          email: email,
          username: username,
          photoUrl: photoUrl,
        );

        final newDriver = FleetDriver(
          id: driverUid,
          fullName: fullName,
          phone: phone,
          email: email,
          licenseNumber: rawDriver['driverLicenseNumber']?.toString() ?? '',
          photoUrl: photoUrl,
          username: username,
          status: FleetDriverStatus.active,
          joinedAt: DateTime.now(),
        );

        widget.onDriverLinked?.call(newDriver);

        if (mounted) {
          Navigator.of(context).pop(newDriver);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$fullName linked to your fleet successfully!'),
              backgroundColor: AppColors.brand,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to link driver: $e'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);

    return Padding(
      padding: const EdgeInsets.only(
        left: 20,
        right: 20,
        top: 14,
        bottom: 14,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Add Driver to Fleet',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Search verified drivers by username, email, or phone.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Search input field
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBackground : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, color: AppColors.brand, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    cursorColor: AppColors.brand,
                    style: TextStyle(
                      fontSize: 15,
                      color: primaryTextColor,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Search username, email or phone...',
                      hintStyle: TextStyle(
                        color: Color(0xFF9CA3AF),
                        fontSize: 14,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                    onChanged: _onSearchChanged,
                    onSubmitted: (v) {
                      FocusScope.of(context).unfocus();
                      _executeSearch(v);
                    },
                  ),
                ),
                if (_searchController.text.isNotEmpty) ...[
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_rounded, size: 20, color: AppColors.brand),
                    tooltip: 'Search',
                    onPressed: () {
                      FocusScope.of(context).unfocus();
                      _executeSearch(_searchController.text);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18, color: Color(0xFF9CA3AF)),
                    tooltip: 'Clear',
                    onPressed: () {
                      _searchController.clear();
                      _executeSearch('');
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // In-view error banner if any
          if (_errorMessage.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.error),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage,
                      style: const TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          // Search Content / Results
          Expanded(
            child: _buildSearchBody(isDark, primaryTextColor),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBody(bool isDark, Color primaryTextColor) {
    // ignore: avoid_print
    print('[CaRide Driver Sheet] _buildSearchBody: isSearching=$_isSearching, results=${_searchResults.length}, query="${_searchController.text.trim()}"');

    if (_isSearching) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
              ),
              const SizedBox(height: 14),
              Text(
                'Searching drivers...',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final query = _searchController.text.trim();

    // 1. Initial State: User hasn't typed a search term yet
    if (query.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.person_search_rounded,
                  size: 52,
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Search Driver to Link',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Type a username (e.g. @username), email address, or phone number above to find and link a driver to your fleet.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 2. Empty Results State
    if (_searchResults.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.search_off_rounded,
                size: 48,
                color: Color(0xFF9CA3AF),
              ),
              const SizedBox(height: 14),
              Text(
                'No drivers found matching "$query"',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Please verify the username, email, or phone number and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 3. Populated Search Results State
    return ListView.builder(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _searchResults.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Matching Drivers (${_searchResults.length})',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    _searchController.clear();
                    _executeSearch('');
                  },
                  child: const Text(
                    'Clear',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.brand,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        final raw = _searchResults[index - 1];
        return _buildDriverCard(raw, isDark, primaryTextColor);
      },
    );
  }

  Widget _buildDriverCard(
    Map<String, dynamic> raw,
    bool isDark,
    Color primaryTextColor,
  ) {
    final uid = (raw['uid'] ?? raw['id'] ?? '').toString();
    final rawName = raw['fullName'] ?? raw['name'] ?? raw['displayName'];
    final name = (rawName != null && rawName.toString().trim().isNotEmpty && rawName.toString() != 'null')
        ? rawName.toString().trim()
        : 'Driver';

    // ignore: avoid_print
    print('[CaRide Driver Sheet] _buildDriverCard rendering for: $name (uid: $uid)');

    final phone = (raw['phoneNumber'] ?? raw['phone'] ?? '').toString().trim();
    final email = (raw['email'] ?? '').toString().trim();
    final rawUsername = raw['username'];
    final username = (rawUsername != null &&
            rawUsername.toString().trim().isNotEmpty &&
            rawUsername.toString() != 'null')
        ? rawUsername.toString().trim().replaceAll('@', '')
        : null;

    final photoUrl = (raw['profilePictureUrl'] ?? raw['photoUrl'])?.toString();
    final alreadyInFleet = fleetManagerController.drivers.any((d) => d.id == uid || d.driverUid == uid);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBackground : const Color(0xFFF9FAFB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Picture
          ClipOval(
            child: SizedBox(
              width: 48,
              height: 48,
              child: _buildDriverAvatar(name, photoUrl),
            ),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: primaryTextColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.verified, color: AppColors.brand, size: 15),
                  ],
                ),
                if (username != null && username.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '@$username',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.brand,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  phone.isNotEmpty ? phone : (email.isNotEmpty ? email : 'Verified Platform Driver'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Select button / Status
          if (alreadyInFleet)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_rounded, size: 14, color: AppColors.brand),
                  SizedBox(width: 4),
                  Text(
                    'Linked',
                    style: TextStyle(
                      color: AppColors.brand,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          else
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () => _selectDriver(raw),
              child: const Text(
                'Select',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDriverAvatar(String name, String? photoUrl) {
    final hasValidUrl = photoUrl != null &&
        photoUrl.trim().isNotEmpty &&
        photoUrl != 'null' &&
        (photoUrl.startsWith('http://') || photoUrl.startsWith('https://'));

    if (!hasValidUrl) {
      return _fallbackAvatar(name);
    }

    return Image.network(
      photoUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _fallbackAvatar(name),
    );
  }

  Widget _fallbackAvatar(String name) {
    return Container(
      color: AppColors.brand.withValues(alpha: 0.15),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'D',
          style: const TextStyle(
            color: AppColors.brand,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
    );
  }
}

/// Confirmation bottom sheet to verify adding a driver to the fleet
class _ConfirmLinkDriverSheet extends StatefulWidget {
  const _ConfirmLinkDriverSheet({
    required this.fullName,
    required this.phone,
    required this.email,
    this.username,
    this.photoUrl,
  });

  final String fullName;
  final String phone;
  final String email;
  final String? username;
  final String? photoUrl;

  @override
  State<_ConfirmLinkDriverSheet> createState() => _ConfirmLinkDriverSheetState();
}

class _ConfirmLinkDriverSheetState extends State<_ConfirmLinkDriverSheet> {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag Handle
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
          const SizedBox(height: 20),

          // Header
          Center(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_add_alt_1_rounded,
                size: 36,
                color: AppColors.brand,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              'Confirm Link Driver',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: primaryTextColor,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              'Add this driver to your fleet organization?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Driver Preview Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBackground : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
              ),
            ),
            child: Row(
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 52,
                    height: 52,
                    child: widget.photoUrl != null && widget.photoUrl!.isNotEmpty
                        ? Image.network(
                            widget.photoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _fallbackAvatar(),
                          )
                        : _fallbackAvatar(),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: primaryTextColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified, color: AppColors.brand, size: 16),
                        ],
                      ),
                      if (widget.username != null && widget.username!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          '@${widget.username!.replaceAll('@', '')}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.brand,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        widget.phone.isNotEmpty ? widget.phone : widget.email,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Informative notice
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.brand.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notifications_active_outlined, color: AppColors.brand, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'The driver will receive a push notification that they have been linked to your fleet and can be assigned to vehicles.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white70 : const Color(0xFF374151),
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Actions
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text(
                'Confirm & Link Driver',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: isDark ? Colors.white70 : const Color(0xFF6B7280),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel', style: TextStyle(fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fallbackAvatar() {
    return Container(
      color: AppColors.brand.withValues(alpha: 0.15),
      child: Center(
        child: Text(
          widget.fullName.isNotEmpty ? widget.fullName[0].toUpperCase() : 'D',
          style: const TextStyle(
            color: AppColors.brand,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
    );
  }
}
