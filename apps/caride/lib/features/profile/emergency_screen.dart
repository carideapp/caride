import 'dart:async';

import 'package:caride/features/profile/data/emergency_repository.dart';
import 'package:caride/features/profile/data/shared_trip_repository.dart';
import 'package:caride/features/profile/data/trusted_contacts_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Emergency assistance screen.
///
/// The passenger presses and holds the emergency button for 1.5 seconds to
/// confirm the alert. Sends an email to each active trusted contact via the
/// [EmergencyRepository] Cloud Function.
class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({
    super.key,
    this.rideId,
  });

  /// The active ride ID, if available.
  final String? rideId;

  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen>
    with SingleTickerProviderStateMixin {
  final EmergencyRepository _emergencyRepo = EmergencyRepository();
  final TrustedContactsRepository _contactsRepo = TrustedContactsRepository();
  final SharedTripRepository _tripRepo = SharedTripRepository();

  List<TrustedContact> _contacts = [];
  bool _loadingContacts = true;
  bool _sending = false;
  bool _sent = false;
  String? _error;
  String? _shareCode;

  // Hold-to-confirm animation
  late AnimationController _holdController;
  bool _isHolding = false;
  Timer? _holdTimer;

  @override
  void initState() {
    super.initState();
    _loadContacts();
    _holdController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          _triggerEmergency();
        }
      });
  }

  @override
  void dispose() {
    _holdController.dispose();
    _holdTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadContacts() async {
    try {
      final contacts = await _contactsRepo.getActiveContacts();
      if (mounted) {
        setState(() {
          _contacts = contacts;
          _loadingContacts = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingContacts = false;
          _error = 'Could not load contacts: $e';
        });
      }
    }
  }

  void _startHold() {
    setState(() => _isHolding = true);
    HapticFeedback.lightImpact();
    _holdController.forward();
  }

  void _cancelHold() {
    if (_sent || _sending) return;
    setState(() => _isHolding = false);
    _holdController.reset();
  }

  Future<void> _triggerEmergency() async {
    if (_sending || _sent) return;
    HapticFeedback.heavyImpact();

    if (_contacts.isEmpty) {
      setState(() => _error = 'No active trusted contacts found. Please add one in Account & Security → Trusted Contacts.');
      _holdController.reset();
      setState(() => _isHolding = false);
      return;
    }

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      // Generate a share code for location sharing
      String? shareCode;
      if (widget.rideId != null) {
        try {
          shareCode = await _tripRepo.createShareCode(widget.rideId!);
          _shareCode = shareCode;
        } catch (_) {
          // Non-fatal — emergency alert still sends without share code
        }
      }

      // Send alert to each active trusted contact
      for (final contact in _contacts) {
        if (contact.email.isEmpty) continue;
        await _emergencyRepo.sendEmergencyAlert(
          trustedContactEmail: contact.email,
          trustedContactName: contact.name,
          rideId: widget.rideId,
          shareCode: shareCode,
        );
      }

      if (mounted) {
        setState(() {
          _sending = false;
          _sent = true;
        });
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = 'Failed to send alert: $e';
          _isHolding = false;
        });
        _holdController.reset();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF1A0A0A) : const Color(0xFFFFF5F5),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : AppColors.slate900,
            size: 20,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Emergency Assistance',
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppColors.slate900,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _sent ? _buildSentState(isDark) : _buildEmergencyState(isDark),
      ),
    );
  }

  Widget _buildEmergencyState(bool isDark) {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: AppSpacing.lg),

                // Emergency icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.error,
                    size: 40,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                Text(
                  'Request Emergency Help',
                  style: AppTextStyles.headlineMedium.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.error,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'An emergency alert email will be sent to your trusted contacts with your ride details and trip sharing code.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: AppSpacing.xl),

                // Trusted contacts list
                _buildContactsList(isDark),

                if (_error != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  InlineError(message: _error!),
                ],

                const SizedBox(height: AppSpacing.xl),

                // Hold-to-confirm button
                _buildHoldButton(isDark),

                const SizedBox(height: AppSpacing.md),
                Text(
                  'Press and hold for 1.5 seconds to send the alert',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),

        // Close button
        Padding(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          child: SecondaryButton(
            label: "I'm Safe — Cancel",
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
      ],
    );
  }

  Widget _buildContactsList(bool isDark) {
    if (_loadingContacts) {
      return const Center(child: AppLoader());
    }

    if (_contacts.isEmpty) {
      return GlassContainer(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            const Icon(Icons.person_off_rounded, color: Colors.grey, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'No trusted contacts. Add them in Account & Security → Trusted Contacts.',
                style: AppTextStyles.bodySmall.copyWith(color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Alert will be sent to:',
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w700,
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...(_contacts.map((c) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_rounded,
                          color: AppColors.error, size: 16),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.name,
                              style: AppTextStyles.bodyMedium
                                  .copyWith(fontWeight: FontWeight.w700)),
                          if (c.email.isNotEmpty)
                            Text(c.email,
                                style: AppTextStyles.bodySmall.copyWith(
                                    color: isDark
                                        ? AppColors.textSecondaryDark
                                        : AppColors.textSecondaryLight),
                                overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    const Icon(Icons.email_outlined,
                        size: 16, color: AppColors.error),
                  ],
                ),
              ))),
        ],
      ),
    );
  }

  Widget _buildHoldButton(bool isDark) {
    return AnimatedBuilder(
      animation: _holdController,
      builder: (context, child) {
        return GestureDetector(
          onLongPressStart: (_) => _startHold(),
          onLongPressEnd: (_) => _cancelHold(),
          onLongPressCancel: _cancelHold,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Progress ring
              SizedBox(
                width: 120,
                height: 120,
                child: CircularProgressIndicator(
                  value: _holdController.value,
                  strokeWidth: 4,
                  backgroundColor: AppColors.error.withValues(alpha: 0.15),
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppColors.error),
                ),
              ),
              // Core button
              Container(
                width: 106,
                height: 106,
                decoration: BoxDecoration(
                  color: _isHolding
                      ? AppColors.error
                      : AppColors.error.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.5),
                    width: 2,
                  ),
                  boxShadow: _isHolding
                      ? [
                          BoxShadow(
                            color: AppColors.error.withValues(alpha: 0.4),
                            blurRadius: 24,
                            spreadRadius: 6,
                          ),
                        ]
                      : null,
                ),
                child: _sending
                    ? const Center(
                        child: SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 3,
                          ),
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.sos_rounded,
                            color: _isHolding
                                ? Colors.white
                                : AppColors.error,
                            size: 38,
                          ),
                          Text(
                            'HOLD',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: _isHolding
                                  ? Colors.white
                                  : AppColors.error,
                              letterSpacing: 2,
                            ),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSentState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.pagePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded,
                  color: AppColors.brand, size: 48),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Alert Sent',
              style: AppTextStyles.headlineMedium.copyWith(
                fontWeight: FontWeight.w900,
                color: AppColors.brand,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'An emergency alert email has been sent to ${_contacts.length} trusted contact${_contacts.length == 1 ? '' : 's'}.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            if (_shareCode != null) ...[
              const SizedBox(height: AppSpacing.lg),
              GlassContainer(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    const Icon(Icons.share_location_rounded,
                        color: AppColors.brand, size: 20),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Trip code $_shareCode was included in the alert so your contact can track your location.',
                        style: AppTextStyles.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Stay calm. Help is on the way. If you need immediate assistance, call 112.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SizedBox(
              width: double.infinity,
              child: PrimaryButton(
                label: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
