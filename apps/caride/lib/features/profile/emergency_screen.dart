import 'dart:async';

import 'package:caride/features/profile/data/emergency_repository.dart';
import 'package:caride/features/profile/data/shared_trip_repository.dart';
import 'package:caride/features/profile/data/trusted_contacts_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sending = false;
          _error = 'Failed to send alert. Please call 112 directly if in danger: $e';
        });
        _holdController.reset();
        setState(() => _isHolding = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final borderColor = isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 14, bottom: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: borderColor),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: primaryTextColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Emergency Assistance',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: primaryTextColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _sent ? _buildSentState(isDark) : _buildEmergencyState(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmergencyState(bool isDark) {
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 12),

                // Emergency Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.error,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 18),

                const Text(
                  'Request Emergency Help',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppColors.error,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'An immediate emergency alert will be dispatched to your trusted contacts with your live ride status and tracking location.',
                  style: TextStyle(
                    fontSize: 14,
                    color: secondaryTextColor,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                // In-View Error Banner
                if (_error != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.error),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _error!,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Trusted contacts list
                _buildContactsList(isDark),

                const SizedBox(height: 28),

                // Hold-to-confirm button
                _buildHoldButton(isDark),

                const SizedBox(height: 14),
                Text(
                  'Press and hold for 1.5s to trigger alert',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: secondaryTextColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),

        // Cancel / Safety button
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: Text(
                "I'm Safe — Cancel",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: primaryTextColor,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContactsList(bool isDark) {
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);

    if (_loadingContacts) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
          ),
        ),
      );
    }

    if (_contacts.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            const Icon(Icons.person_off_rounded, color: Colors.grey, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'No trusted contacts found. Please add one in Trusted Contacts.',
                style: TextStyle(fontSize: 13, color: secondaryTextColor),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Alert will be dispatched to:',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: secondaryTextColor,
            ),
          ),
          const SizedBox(height: 10),
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
                      child: const Icon(
                        Icons.person_rounded,
                        color: AppColors.error,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            c.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: primaryTextColor,
                            ),
                          ),
                          if (c.email.isNotEmpty)
                            Text(
                              c.email,
                              style: TextStyle(
                                fontSize: 12,
                                color: secondaryTextColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    const Icon(Icons.email_outlined, size: 16, color: AppColors.error),
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
                width: 124,
                height: 124,
                child: CircularProgressIndicator(
                  value: _holdController.value,
                  strokeWidth: 4,
                  backgroundColor: AppColors.error.withValues(alpha: 0.15),
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.error),
                ),
              ),
              // Core SOS button
              Container(
                width: 108,
                height: 108,
                decoration: BoxDecoration(
                  color: _isHolding ? AppColors.error : AppColors.error.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.5),
                    width: 2,
                  ),
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
                            color: _isHolding ? Colors.white : AppColors.error,
                            size: 38,
                          ),
                          Text(
                            'HOLD',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: _isHolding ? Colors.white : AppColors.error,
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
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
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
              child: const Icon(Icons.check_circle_rounded, color: AppColors.brand, size: 48),
            ),
            const SizedBox(height: 20),
            const Text(
              'Alert Dispatched',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: AppColors.brand,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'An emergency alert has been sent to ${_contacts.length} trusted contact${_contacts.length == 1 ? '' : 's'}.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: secondaryTextColor,
                height: 1.4,
              ),
            ),
            if (_shareCode != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.share_location_rounded, color: AppColors.brand, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Trip code $_shareCode was included so your contact can track your live route.',
                        style: TextStyle(
                          fontSize: 13,
                          color: primaryTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              'Stay calm. Help is being notified. If you need immediate assistance from emergency services, call 112.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: secondaryTextColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
