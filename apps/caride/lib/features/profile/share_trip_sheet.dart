import 'package:caride/core/services/deep_link_service.dart';
import 'package:caride/features/profile/data/shared_trip_repository.dart';
import 'package:caride/features/profile/data/trusted_contacts_repository.dart';
import 'package:caride/features/profile/data/emergency_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_widgets/shared_widgets.dart';
import 'package:url_launcher/url_launcher.dart';

/// Bottom sheet for sharing the current trip with trusted contacts via email.
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

  // Track which contacts have had an email sent
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

  Future<void> _sendEmailToContact(TrustedContact contact) async {
    if (_sendingEmail) return;
    setState(() {
      _sendingEmail = true;
      _error = null;
    });
    try {
      final code = await _getOrCreateShareCode();
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
            content: Text('Trip shared with ${contact.name} via email ✓'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to send email: $e');
    } finally {
      if (mounted) setState(() => _sendingEmail = false);
    }
  }

  Future<void> _copyCode() async {
    final code = await _getOrCreateShareCode();
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Trip code copied to clipboard'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _shareLink() async {
    final code = await _getOrCreateShareCode();
    final link = DeepLinkService.instance.generateTripLink(code);
    final from = widget.pickupLabel ?? 'pickup location';
    final to   = widget.dropoffLabel ?? 'destination';
    final driver = widget.driverName;
    final text = 'Track my CaRide trip in real time!\n'
        'From: $from\nTo: $to\n'
        '${driver != null ? 'Driver: $driver\n' : ''}'
        '\n$link';
    await Share.share(text, subject: 'Track my CaRide trip');
  }

  Future<void> _shareViaEmail(TrustedContact contact) async {
    final code = await _getOrCreateShareCode();
    final from = widget.pickupLabel ?? 'pickup location';
    final to = widget.dropoffLabel ?? 'destination';
    final driver = widget.driverName;
    final body = Uri.encodeComponent(
      'Hi ${contact.name},\n\n'
      'I\'m sharing my CaRide trip with you so you can monitor my journey.\n\n'
      'From: $from\nTo: $to\n'
      '${driver != null ? 'Driver: $driver\n' : ''}'
      '\nTrip code: $code\n'
      'Open the CaRide app and go to Monitor Trip, then enter the code above.\n\n'
      'Stay safe! 🚗',
    );
    final subject = Uri.encodeComponent('Tracking my CaRide trip — code $code');
    final uri = Uri.parse('mailto:${contact.email}?subject=$subject&body=$body');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      // Fallback: send via Cloud Function
      await _sendEmailToContact(contact);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE9EAF0);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141416) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xxl)),
      ),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        AppSpacing.sm,
        AppSpacing.pagePadding,
        AppSpacing.pagePadding + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag Handle
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Header
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(Icons.share_location_rounded,
                        color: AppColors.brand, size: 24),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Share Your Trip',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppColors.slate900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Let a trusted contact follow your journey live',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? Colors.white70 : const Color(0xFF6E7191),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Share code display card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.brand.withValues(alpha: 0.25)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.verified_user_rounded, color: AppColors.brand, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              'Live Share Code',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppColors.brand,
                              ),
                            ),
                          ],
                        ),
                        if (_shareCode != null)
                          InkWell(
                            onTap: _copyCode,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.copy_rounded, size: 14, color: AppColors.brand),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Copy',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.brand,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _generatingCode
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(AppSpacing.sm),
                              child: AppLoader(),
                            ),
                          )
                        : _shareCode != null
                            ? Text(
                                _shareCode!.length == 6
                                    ? '${_shareCode!.substring(0, 3)} ${_shareCode!.substring(3, 6)}'
                                    : _shareCode!,
                                style: theme.textTheme.headlineLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.brand,
                                  letterSpacing: 6,
                                ),
                              )
                            : Text(
                                'A 6-digit code will be generated',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: isDark ? Colors.white70 : const Color(0xFF6E7191),
                                ),
                              ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Contacts section
              if (_loadingContacts)
                const Center(child: Padding(padding: EdgeInsets.all(AppSpacing.md), child: AppLoader()))
              else if (_contacts.isEmpty)
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: borderColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_off_rounded, color: Colors.grey, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'No trusted contacts added yet. Add them in Account & Security.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: isDark ? Colors.white70 : Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                Text(
                  'Trusted Contacts',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.slate900,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ...(_contacts.map((contact) {
                  final sent = _sentContactIds.contains(contact.id);
                  return Container(
                    margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm + 2),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 18,
                          backgroundColor: (sent ? AppColors.brand : (isDark ? Colors.white12 : Colors.grey[200]!)),
                          child: Icon(
                            sent ? Icons.check_rounded : Icons.person_rounded,
                            color: sent ? Colors.white : (isDark ? Colors.white : AppColors.slate900),
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                contact.name,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : AppColors.slate900,
                                ),
                              ),
                              Text(
                                contact.email,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark ? Colors.white70 : const Color(0xFF6E7191),
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        if (!sent)
                          ElevatedButton.icon(
                            onPressed: _sendingEmail ? null : () => _shareViaEmail(contact),
                            icon: const Icon(Icons.email_rounded, size: 14),
                            label: const Text('Email'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brand,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              minimumSize: const Size(0, 34),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.brand.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(AppRadius.sm),
                            ),
                            child: Text(
                              'Sent ✓',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: AppColors.brand,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                })),
              ],

              if (_error != null) ...[
                const SizedBox(height: AppSpacing.sm),
                InlineError(message: _error!),
              ],

              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: 'Share Trip Link',
                onPressed: _shareLink,
                icon: Icons.share_rounded,
              ),
              const SizedBox(height: AppSpacing.sm),
              SecondaryButton(
                label: 'Done',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
