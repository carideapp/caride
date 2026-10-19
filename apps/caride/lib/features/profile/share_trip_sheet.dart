import 'package:caride/core/services/deep_link_service.dart';
import 'package:caride/features/profile/data/emergency_repository.dart';
import 'package:caride/features/profile/data/shared_trip_repository.dart';
import 'package:caride/features/profile/data/trusted_contacts_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Bottom sheet for sharing the current trip with trusted contacts via email or link.
class ShareTripSheet extends StatefulWidget {
  const ShareTripSheet({
    super.key,
    required this.rideId,
    this.pickupLabel,
    this.dropoffLabel,
    this.driverName,
  });

  final String rideId;
  final String? pickupLabel;
  final String? dropoffLabel;
  final String? driverName;

  @override
  State<ShareTripSheet> createState() => _ShareTripSheetState();
}

class _ShareTripSheetState extends State<ShareTripSheet> {
  final _contactsRepo = TrustedContactsRepository();
  final _tripRepo = SharedTripRepository();
  final _emergencyRepo = EmergencyRepository();

  List<TrustedContact> _contacts = [];
  bool _loadingContacts = true;
  bool _generatingCode = false;
  String? _shareCode;
  String? _error;

  final Set<String> _sentContactIds = {};
  bool _sendingEmail = false;

  @override
  void initState() {
    super.initState();
    _loadContacts();
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
          _error = 'Failed to load contacts: $e';
        });
      }
    }
  }

  Future<String> _getOrCreateShareCode() async {
    if (_shareCode != null) return _shareCode!;
    setState(() => _generatingCode = true);
    try {
      final code = await _tripRepo.createShareCode(widget.rideId);
      if (mounted) setState(() => _shareCode = code);
      return code;
    } finally {
      if (mounted) setState(() => _generatingCode = false);
    }
  }

  Future<void> _copyCode() async {
    final code = await _getOrCreateShareCode();
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trip sharing code copied to clipboard'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _shareLink() async {
    final code = await _getOrCreateShareCode();
    final link = DeepLinkService.instance.generateTripLink(code);
    final from = widget.pickupLabel ?? 'pickup location';
    final to = widget.dropoffLabel ?? 'destination';
    final driver = widget.driverName;
    final text = 'Track my CaRide trip in real time!\n'
        'From: $from\nTo: $to\n'
        '${driver != null ? 'Driver: $driver\n' : ''}'
        '\n$link';
    await Share.share(text, subject: 'Track my CaRide trip');
  }

  Future<void> _shareViaEmail(TrustedContact contact) async {
    final code = await _getOrCreateShareCode();
    final link = DeepLinkService.instance.generateTripLink(code);
    final from = widget.pickupLabel ?? 'pickup location';
    final to = widget.dropoffLabel ?? 'destination';
    final driver = widget.driverName;

    final subject = Uri.encodeComponent('Track my trip on CaRide');
    final body = Uri.encodeComponent(
      'Hi ${contact.name},\n\n'
      'I am currently on a ride with CaRide and sharing my trip details with you for safety.\n\n'
      'From: $from\n'
      'To: $to\n'
      '${driver != null ? 'Driver: $driver\n' : ''}'
      'Trip Code: $code\n\n'
      'Track my live route here:\n$link\n\n'
      'Stay safe,\nYour Friend',
    );

    final emailUri = Uri.parse('mailto:${contact.email}?subject=$subject&body=$body');

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri, mode: LaunchMode.externalApplication);
        if (mounted) setState(() => _sentContactIds.add(contact.id));
      } else {
        await _sendBackendEmail(contact, code);
      }
    } catch (_) {
      await _sendBackendEmail(contact, code);
    }
  }

  Future<void> _sendBackendEmail(TrustedContact contact, String code) async {
    if (_sendingEmail) return;
    setState(() {
      _sendingEmail = true;
      _error = null;
    });
    try {
      await _emergencyRepo.sendEmergencyAlert(
        trustedContactEmail: contact.email,
        trustedContactName: contact.name,
        rideId: widget.rideId,
        shareCode: code,
      );
      if (mounted) {
        setState(() => _sentContactIds.add(contact.id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Trip alert sent to ${contact.name}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to send email alert: $e');
    } finally {
      if (mounted) setState(() => _sendingEmail = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(20, 14, 20, MediaQuery.of(context).padding.bottom + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Header
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.share_location_rounded, color: AppColors.brand, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Share Your Journey',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Allow friends to follow your trip live',
                        style: TextStyle(
                          fontSize: 13,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Live Share Code Card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.brand.withValues(alpha: 0.25)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.verified_user_rounded, color: AppColors.brand, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Active Share Code',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brand,
                            ),
                          ),
                        ],
                      ),
                      if (_shareCode != null)
                        GestureDetector(
                          onTap: _copyCode,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.brand.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.copy_rounded, size: 13, color: AppColors.brand),
                                SizedBox(width: 4),
                                Text(
                                  'Copy',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.brand,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _generatingCode
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
                            ),
                          ),
                        )
                      : _shareCode != null
                          ? Text(
                              _shareCode!.length == 6
                                  ? '${_shareCode!.substring(0, 3)} ${_shareCode!.substring(3, 6)}'
                                  : _shareCode!,
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                color: AppColors.brand,
                                letterSpacing: 5,
                              ),
                            )
                          : Text(
                              'Tap below to create live code',
                              style: TextStyle(
                                fontSize: 13,
                                color: secondaryTextColor,
                              ),
                            ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Trusted Contacts
            if (_loadingContacts)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
                  ),
                ),
              )
            else if (_contacts.isEmpty)
              Container(
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
                        'No trusted contacts saved yet. You can still share the live link with anyone.',
                        style: TextStyle(fontSize: 13, color: secondaryTextColor),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              Text(
                'Send Direct Alert',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 10),
              ...(_contacts.map((contact) {
                final sent = _sentContactIds.contains(contact.id);
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: sent
                              ? AppColors.brand.withValues(alpha: 0.14)
                              : (isDark ? Colors.white10 : const Color(0xFFF3F4F6)),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          sent ? Icons.check_rounded : Icons.person_rounded,
                          color: sent ? AppColors.brand : primaryTextColor,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              contact.name,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: primaryTextColor,
                              ),
                            ),
                            Text(
                              contact.email,
                              style: TextStyle(
                                fontSize: 12,
                                color: secondaryTextColor,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (!sent)
                        ElevatedButton.icon(
                          onPressed: _sendingEmail ? null : () => _shareViaEmail(contact),
                          icon: const Icon(Icons.send_rounded, size: 13, color: Colors.white),
                          label: const Text(
                            'Share',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.brand,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.brand.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Sent ✓',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.brand,
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              })),
            ],

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.error),
                ),
                child: Text(
                  _error!,
                  style: const TextStyle(fontSize: 13, color: AppColors.error),
                ),
              ),
            ],

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _shareLink,
                icon: const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                label: const Text(
                  'Share Trip Link',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Done',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: secondaryTextColor,
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
