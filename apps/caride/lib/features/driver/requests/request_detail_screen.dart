import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:design_system/design_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:caride/core/driver/auth/driver_auth_controller.dart';
import 'package:caride/core/driver/models/ride_model.dart';
import 'package:caride/core/driver/state/driver_active_ride_state.dart';
import 'package:caride/features/driver/auth/data/driver_profile_repository.dart';
import 'package:caride/features/driver/ride/data/driver_ride_repository.dart';
import 'package:caride/features/ride_booking/data/ride_repository.dart' hide RideModel;
import 'package:flutter/material.dart';
import 'package:shared_widgets/shared_widgets.dart';
import 'package:caride/core/config/app_config_repository.dart';
import 'package:caride/features/driver/widgets/driver_counter_offer_bottom_sheet.dart';
import 'package:caride/features/driver/widgets/driver_debt_prompt_bottom_sheet.dart';
import 'package:caride/core/driver/models/driver_presence.dart';
import 'package:caride/core/driver/utils/distance_helper.dart';
import 'package:caride/features/driver/location/data/driver_presence_repository.dart';

class RequestDetailScreen extends StatefulWidget {
  const RequestDetailScreen({super.key});

  @override
  State<RequestDetailScreen> createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  final _rideRepo = DriverRideRepository();
  final _profileRepo = DriverProfileRepository();
  final _presenceRepo = DriverPresenceRepository();
  DriverPresence? _presence;
  bool _submitting = false;
  Timer? _viewerTimer;
  RideModel? _latestRide;

  RideModel? get _ride => _latestRide ?? DriverActiveRideState.instance.selectedRide;

  @override
  void initState() {
    super.initState();
    _fetchPresence();
    _registerViewerPresence();
    _viewerTimer = Timer.periodic(const Duration(seconds: 15), (_) => _registerViewerPresence());
  }

  void _fetchPresence() {
    _presenceRepo.getPresence().then((p) {
      if (mounted) {
        setState(() => _presence = p);
      }
    });
  }

  void _registerViewerPresence() {
    final ride = _ride;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (ride == null || uid == null) return;
    _profileRepo.getDriverProfile(uid).then((profile) {
      if (profile != null && mounted) {
        RideRepository().updateDriverRideViewerPresence(
          rideId: ride.id,
          driverUid: profile.uid,
          driverName: profile.fullName,
          profilePhotoUrl: profile.profilePhotoUrl,
        );
      }
    });
  }

  void _removeViewerPresence() {
    final ride = _ride;
    final user = FirebaseAuth.instance.currentUser;
    if (ride != null && user != null) {
      RideRepository().removeDriverRideViewerPresence(
        rideId: ride.id,
        driverUid: user.uid,
      );
    }
  }

  @override
  void dispose() {
    _viewerTimer?.cancel();
    _removeViewerPresence();
    super.dispose();
  }

  void _showSuccessPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        final surfaceColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;

        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          backgroundColor: surfaceColor,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: const BoxDecoration(
                  color: AppColors.primaryGreen,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Bid Placed!',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Your bid has been sent. Waiting for customer to respond.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: 'Back to Requests',
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<bool> _checkDebtLimit() async {
    final uid = driverAuthController.currentUid;
    if (uid == null) return false;
    final profile = await _profileRepo.getDriverProfile(uid);
    final settings = await AppConfigRepository().getDriverSettings();
    final balance = profile?.walletBalance ?? 0.0;
    if (balance <= -settings.maxNegativeBalanceNaira) {
      if (mounted) {
        await DriverDebtPromptBottomSheet.show(
          context,
          currentBalance: balance,
          maxNegativeBalance: settings.maxNegativeBalanceNaira,
        );
      }
      return true;
    }
    return false;
  }

  Future<void> _placeBid(double amount) async {
    final ride = _ride;
    if (ride == null) return;

    final uid = driverAuthController.currentUid;
    if (uid == null) return;

    final isRestricted = await _checkDebtLimit();
    if (isRestricted) return;

    setState(() => _submitting = true);
    try {
      final profile = await _profileRepo.getDriverProfile(uid);
      
      int eta = 5;
      final presence = _presence;
      if (presence != null && presence.latitude != null && presence.longitude != null && ride.pickupLat != null && ride.pickupLng != null) {
        final dist = calculateDistance(
          presence.latitude!,
          presence.longitude!,
          ride.pickupLat!,
          ride.pickupLng!,
        );
        eta = estimateEtaMinutes(dist);
      }

      await _rideRepo.placeBid(
        rideId: ride.id,
        driverName: profile?.fullName ?? 'Driver',
        offerNaira: amount,
        etaMinutes: eta,
        driverRating: profile?.rating ?? 0.0,
        driverRides: profile?.completedRides ?? 0,
      );
      if (!mounted) return;
      _showSuccessPopup();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to place bid: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _showCounterSheet() async {
    final ride = _ride;
    if (ride == null) return;

    final isRestricted = await _checkDebtLimit();
    if (isRestricted || !mounted) return;

    DriverCounterOfferBottomSheet.show(
      context: context,
      customerOffer: ride.customerOffer,
      onSubmit: (amount) => _placeBid(amount),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surfaceColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE9EAF0);
    final initialRide = DriverActiveRideState.instance.selectedRide;

    if (initialRide == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Offer Details')),
        body: const Center(
          child: EmptyState(
            title: 'No ride selected',
            message: 'Go back and select a ride request.',
            icon: Icons.search_off_rounded,
          ),
        ),
      );
    }

    return StreamBuilder<RideModel?>(
      stream: _rideRepo.streamRide(initialRide.id),
      initialData: initialRide,
      builder: (context, snapshot) {
        final ride = snapshot.data ?? initialRide;
        _latestRide = ride;

        final double? distanceKm = (_presence?.latitude != null &&
                _presence?.longitude != null &&
                ride.pickupLat != null &&
                ride.pickupLng != null)
            ? calculateDistance(
                _presence!.latitude!,
                _presence!.longitude!,
                ride.pickupLat!,
                ride.pickupLng!,
              )
            : null;

        return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          'Offer Details',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.sm,
            ),
            children: [
              // ── Customer Info Card ──
              FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: FirebaseFirestore.instance
                    .collection('customers')
                    .doc(ride.customerUid)
                    .get(),
                builder: (context, custSnap) {
                  final custData = custSnap.data?.data();
                  final fullName = (custData?['fullName'] as String?)?.trim() ??
                      (custData?['name'] as String?)?.trim() ??
                      'Customer';
                  final photoUrl = (custData?['photoUrl'] as String?) ??
                      (custData?['profilePhotoUrl'] as String?) ??
                      '';
                  final double rating = (custData?['rating'] as num?)?.toDouble() ??
                      (custData?['customerRating'] as num?)?.toDouble() ??
                      0.0;

                  return Container(
                    decoration: BoxDecoration(
                      color: surfaceColor,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: borderColor),
                      boxShadow: isDark
                          ? null
                          : [
                              const BoxShadow(
                                color: Color(0x0F0F172A),
                                blurRadius: 18,
                                offset: Offset(0, 8),
                              ),
                            ],
                    ),
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        // Avatar with verified badge
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF1F5F9),
                              backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                              child: photoUrl.isEmpty
                                  ? Icon(
                                      Icons.person_rounded,
                                      size: 26,
                                      color: isDark ? Colors.white30 : Colors.black26,
                                    )
                                  : null,
                            ),
                            Positioned(
                              right: -2,
                              bottom: -1,
                              child: Container(
                                padding: const EdgeInsets.all(1),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.verified_rounded,
                                  size: 15,
                                  color: Color(0xFFFFB100),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fullName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : AppColors.slate900,
                                ),
                              ),
                              const SizedBox(height: 4),
                              if (rating > 0)
                                Row(
                                  children: [
                                  // Rating chip
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFB100).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.star_rounded,
                                          size: 14,
                                          color: Color(0xFFFFB100),
                                        ),
                                        const SizedBox(width: 3),
                                        Text(
                                          rating.toStringAsFixed(1),
                                          style: theme.textTheme.labelSmall?.copyWith(
                                            fontWeight: FontWeight.w900,
                                            color: const Color(0xFFD97706),
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // ── Main Card ──
              Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: borderColor),
                  boxShadow: isDark
                      ? null
                      : [
                          const BoxShadow(
                            color: Color(0x0F0F172A),
                            blurRadius: 18,
                            offset: Offset(0, 8),
                          ),
                        ],
                ),
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  'CUSTOMER OFFER',
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    letterSpacing: 1.2,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (distanceKm != null) ...[
                                const SizedBox(width: AppSpacing.sm),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryGreen.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(AppRadius.sm),
                                  ),
                                  child: Text(
                                    '${distanceKm.toStringAsFixed(1)} km away',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: AppColors.primaryGreen,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Delivery badge for Courier rides
                            if ((ride.rideType.toLowerCase() == 'courier') ||
                                (ride.receiverName?.isNotEmpty ?? false)) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Icons.inventory_2_rounded, size: 12, color: Colors.orange),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Delivery',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: Colors.orange,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                            ],
                            StatusChip(
                              label: ride.rideType,
                              tone: StatusChipTone.neutral,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      NgnFormat.whole(ride.customerOffer),
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.primaryGreen,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Column(
                          children: [
                            const Icon(Icons.circle, size: 12, color: AppColors.primaryGreen),
                            Container(
                              width: 2,
                              height: 32,
                              color: isDark ? Colors.grey[800] : Colors.grey[200],
                            ),
                            const Icon(Icons.location_on_rounded, size: 14, color: AppColors.error),
                          ],
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'PICKUP',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark ? Colors.grey[400] : const Color(0xFF8A90A6),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 9,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                ride.pickupLabel,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : AppColors.slate900,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'DROPOFF',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark ? Colors.grey[400] : const Color(0xFF8A90A6),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 9,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                ride.dropoffLabel,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : AppColors.slate900,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              // Recipient info for delivery rides
                              if ((ride.receiverName?.isNotEmpty ?? false) ||
                                  (ride.receiverPhone?.isNotEmpty ?? false)) ...[
                                const SizedBox(height: AppSpacing.md),
                                Container(
                                  padding: const EdgeInsets.all(AppSpacing.sm),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                    border: Border.all(
                                        color: Colors.orange.withValues(alpha: 0.2)),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'RECIPIENT',
                                        style: theme.textTheme.labelSmall?.copyWith(
                                          color: Colors.orange,
                                          letterSpacing: 1,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 9,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      if (ride.receiverName?.isNotEmpty ?? false)
                                        Text(
                                          ride.receiverName!,
                                          style: theme.textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? Colors.white : AppColors.slate900,
                                          ),
                                        ),
                                      if (ride.receiverPhone?.isNotEmpty ?? false)
                                        Text(
                                          ride.receiverPhone!,
                                          style: theme.textTheme.bodySmall?.copyWith(
                                            color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // ── Main Actions ──
              PrimaryButton(
                label: 'Accept Customer Price',
                isLoading: _submitting,
                onPressed: () => _placeBid(ride.customerOffer),
              ),
              const SizedBox(height: AppSpacing.md),
              SecondaryButton(
                label: 'Counter',
                onPressed: _submitting ? null : _showCounterSheet,
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Decline Request',
                    style: TextStyle(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
      },
    );
  }
}
