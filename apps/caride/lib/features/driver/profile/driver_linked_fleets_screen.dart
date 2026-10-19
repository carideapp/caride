import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_models/shared_models.dart';
import 'package:caride/core/driver/auth/driver_auth_controller.dart';
import 'package:caride/features/driver/auth/data/driver_profile_repository.dart';

/// Screen displaying the list of fleet managers/fleets the driver is linked to.
class DriverLinkedFleetsScreen extends StatefulWidget {
  const DriverLinkedFleetsScreen({super.key});

  @override
  State<DriverLinkedFleetsScreen> createState() => _DriverLinkedFleetsScreenState();
}

class _DriverLinkedFleetsScreenState extends State<DriverLinkedFleetsScreen> {
  final _profileRepo = DriverProfileRepository();
  final _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);
    final uid = driverAuthController.currentUid;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF9FAFB),
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
                      'My Fleet Managers',
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

            // Main Content
            Expanded(
              child: uid == null
                  ? Center(
                      child: Text(
                        'Please sign in to view linked fleets',
                        style: TextStyle(color: secondaryTextColor),
                      ),
                    )
                  : StreamBuilder(
                      stream: _profileRepo.streamDriverProfile(uid),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
                            ),
                          );
                        }

                        final profile = snapshot.data;
                        final fleetIds = profile?.linkedFleetIds ?? [];

                        if (fleetIds.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 32.0),
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
                                      Icons.business_rounded,
                                      size: 52,
                                      color: AppColors.brand,
                                    ),
                                  ),
                                  const SizedBox(height: 18),
                                  Text(
                                    'No Linked Fleet Managers',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 18,
                                      color: primaryTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'When a fleet manager links you to their fleet organization, they will appear here.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: secondaryTextColor,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: _firestore
                              .collection('fleets')
                              .where(FieldPath.documentId, whereIn: fleetIds.take(10).toList())
                              .snapshots(),
                          builder: (context, fleetSnap) {
                            if (fleetSnap.connectionState == ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
                                ),
                              );
                            }

                            final docs = fleetSnap.data?.docs ?? [];
                            if (docs.isEmpty) {
                              return Center(
                                child: Text(
                                  'Linked fleet records not found.',
                                  style: TextStyle(color: secondaryTextColor),
                                ),
                              );
                            }

                            final fleets = docs.map((d) => FleetProfile.fromMap(d.data(), d.id)).toList();

                            return ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                              itemCount: fleets.length,
                              itemBuilder: (context, index) {
                                final fleet = fleets[index];
                                return _LinkedFleetCard(fleet: fleet);
                              },
                            );
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

class _LinkedFleetCard extends StatelessWidget {
  const _LinkedFleetCard({required this.fleet});

  final FleetProfile fleet;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cover Photo
          Stack(
            children: [
              Container(
                height: 110,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.15),
                ),
                child: fleet.coverPhotoUrl != null && fleet.coverPhotoUrl!.isNotEmpty
                    ? Image.network(
                        fleet.coverPhotoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _defaultCoverBanner(),
                      )
                    : _defaultCoverBanner(),
              ),
              // Verified badge overlay
              Positioned(
                top: 10,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        fleet.isVerified ? Icons.verified : Icons.schedule_rounded,
                        color: fleet.isVerified ? AppColors.brand : const Color(0xFFF59E0B),
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        fleet.isVerified ? 'Verified Fleet' : 'Pending',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Details Body
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Fleet Logo / Avatar
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBackground : const Color(0xFFF3F4F6),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                      width: 1.5,
                    ),
                  ),
                  child: ClipOval(
                    child: fleet.profilePictureUrl != null && fleet.profilePictureUrl!.isNotEmpty
                        ? Image.network(
                            fleet.profilePictureUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _fallbackLogo(),
                          )
                        : _fallbackLogo(),
                  ),
                ),
                const SizedBox(width: 14),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        fleet.businessName.isNotEmpty ? fleet.businessName : 'Fleet Partner',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Icon(Icons.location_on_outlined, size: 14, color: AppColors.brand),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              fleet.operatingStates.isNotEmpty
                                  ? fleet.operatingStates.join(', ')
                                  : (fleet.city.isNotEmpty ? fleet.city : 'Nigeria'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 12, color: secondaryTextColor),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.directions_car_outlined, size: 14, color: AppColors.brand),
                          const SizedBox(width: 4),
                          Text(
                            '${fleet.totalVehicles} Vehicles',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : const Color(0xFF374151),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // View Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(72, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                  onPressed: () {
                    context.push(DriverRoutePaths.fleetProfileView, extra: fleet);
                  },
                  child: const Text(
                    'View',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _defaultCoverBanner() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.brand.withValues(alpha: 0.8),
            AppColors.brandLight.withValues(alpha: 0.6),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          Icons.directions_car_rounded,
          size: 40,
          color: Colors.white.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _fallbackLogo() {
    return Center(
      child: Text(
        fleet.businessName.isNotEmpty ? fleet.businessName[0].toUpperCase() : 'F',
        style: const TextStyle(
          color: AppColors.brand,
          fontWeight: FontWeight.bold,
          fontSize: 22,
        ),
      ),
    );
  }
}
