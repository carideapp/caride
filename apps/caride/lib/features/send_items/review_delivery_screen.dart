import 'dart:math';

import 'package:caride/features/ride_booking/booking_shell/booking_shell_controller.dart';
import 'package:caride/features/ride_booking/booking_shell/widgets/payment_methods_bottom_sheet.dart';
import 'package:caride/features/send_items/widgets/dropoff_details_bottom_sheet.dart';
import 'package:caride/features/send_items/widgets/pin_info_bottom_sheet.dart';
import 'package:caride/features/send_items/prohibited_items_screen.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// A standalone full-screen screen that holds the entire review delivery layout.
/// Pushed via [Navigator.push] from [SendItemsShellScreen] when the user taps
/// "Continue to Review". On confirmation it pops so the shell can advance to
/// the bids step.
class ReviewDeliveryScreen extends StatefulWidget {
  const ReviewDeliveryScreen({
    super.key,
    required this.controller,
    required this.onConfirmed,
  });

  final BookingShellController controller;
  final Future<void> Function({
    required String paymentMethod,
    String? deliveryPin,
  }) onConfirmed;

  @override
  State<ReviewDeliveryScreen> createState() => _ReviewDeliveryScreenState();
}

class _ReviewDeliveryScreenState extends State<ReviewDeliveryScreen> {
  bool _isSending = true; // toggle between "I'm sending" and "I'm receiving"
  bool _confirming = false;

  String _paymentMethod = 'wallet';
  String _paymentMethodLabel = 'CaRide Wallet';
  String? _selectedAuthCode;

  // Tracks if recipient details have been filled for this session
  String? _filledRecipientName;
  String? _filledSenderName;
  String? _filledSenderPhone;

  BookingShellController get _c => widget.controller;

  @override
  void initState() {
    super.initState();
    _c.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    _c.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openDropoffDetails({required bool isSender}) async {
    final address = isSender
        ? (_c.from?.placeName ?? '')
        : (_c.to?.placeName ?? '');

    final isMe = (isSender && _isSending) || (!isSender && !_isSending);
    
    final initialName = isSender 
        ? _filledSenderName 
        : (_filledRecipientName ?? _c.receiverName);
        
    final initialPhone = isSender 
        ? _filledSenderPhone 
        : (_c.receiverPhone);

    final result = await DropoffDetailsBottomSheet.show(
      context,
      addressLabel: address,
      controller: _c,
      isSender: isSender,
      initialName: initialName,
      initialPhone: initialPhone,
      isMe: isMe,
    );

    if (result != null) {
      if (!isSender) {
        // Recipient details → saved in controller
        _c.setReceiverDetails(result.name, result.phone);
        setState(() {
          _filledRecipientName = result.name;
        });
      } else {
        // Sender details (for "I'm receiving" mode)
        setState(() {
          _filledSenderName = result.name;
          _filledSenderPhone = result.phone;
        });
      }
    }
  }

  Future<void> _selectPaymentMethod() async {
    final choice = await PaymentMethodsBottomSheet.show(
      context,
      selectedMethod: _paymentMethod,
    );
    if (choice != null) {
      setState(() {
        _paymentMethod = choice.method;
        _paymentMethodLabel = choice.label;
        _selectedAuthCode = choice.authorizationCode;
      });
    }
  }

  Future<void> _confirmDelivery() async {
    final String? partnerName = _isSending 
        ? (_filledRecipientName ?? _c.receiverName)
        : _filledSenderName;
        
    final String? partnerPhone = _isSending
        ? _c.receiverPhone
        : _filledSenderPhone;

    if (partnerName == null || partnerName.trim().isEmpty ||
        partnerPhone == null || partnerPhone.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isSending 
              ? 'Please fill in recipient name and phone number.' 
              : 'Please fill in sender name and phone number.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _confirming = true);
    try {
      String? deliveryPin;
      if (_c.pinConfirmationEnabled) {
        // Generate a 4-digit delivery PIN
        deliveryPin = (1000 + Random().nextInt(9000)).toString();
      }

      final method = _paymentMethod == 'card' && _selectedAuthCode != null
          ? _selectedAuthCode!
          : _paymentMethod;

      await widget.onConfirmed(
        paymentMethod: method,
        deliveryPin: deliveryPin,
      );
      HapticFeedback.lightImpact();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to confirm delivery: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final fgColor = isDark ? Colors.white : AppColors.slate900;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: GlassAppBar(
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: fgColor,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: 'Review delivery',
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pagePadding,
            vertical: AppSpacing.md,
          ),
          children: [
            // ── "I'm sending / I'm receiving" Toggle ──
            _SendingToggle(
              isSending: _isSending,
              onToggle: (val) => setState(() {
                _isSending = val;
                // Reset filled names when switching tabs
                _filledSenderName = null;
                _filledRecipientName = null;
                _c.setReceiverDetails(null, null);
              }),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── Trip details ──
            Text(
              'Trip details',
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),

            _TripDetailsCard(
              isSending: _isSending,
              pickupLabel: _c.from?.placeName ?? '—',
              dropoffLabel: _c.to?.placeName ?? '—',
              filledSenderName: _filledSenderName,
              filledRecipientName: _filledRecipientName ?? _c.receiverName,
              onAddSender: () => _openDropoffDetails(isSender: true),
              onAddRecipient: () => _openDropoffDetails(isSender: false),
              isDark: isDark,
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── Payment method ──
            InkWell(
              onTap: _selectPaymentMethod,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: GlassContainer(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.brandGlass,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _paymentMethod == 'wallet'
                            ? Icons.account_balance_wallet_outlined
                            : Icons.credit_card_rounded,
                        color: AppColors.brand,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Payment Method',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                          Text(
                            _paymentMethodLabel,
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── Protect your delivery ──
            _ProtectDeliverySection(
              controller: _c,
              isDark: isDark,
            ),

            // ── Review package guidelines ──
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Review package guidelines',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w800,
                color: fgColor,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'For a successful delivery, make sure your package is:',
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '• 15 kg or less',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark ? Colors.grey[300] : const Color(0xFF2C2C2C),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '• ₦50,000 or less in value',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark ? Colors.grey[300] : const Color(0xFF2C2C2C),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '• Securely sealed and ready for pickup',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark ? Colors.grey[300] : const Color(0xFF2C2C2C),
                    ),
                  ),
                ],
              ),
            ),

            // ── Prohibited items ──
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Prohibited items',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w800,
                color: fgColor,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Alcohol, medication, drugs, firearms, items of irreplaceable sentimental value, and dangerous or illegal items are prohibited. Items sent via CaRide must comply with all laws and regulations and with CaRide policies. Violations may be reported to authorities and app access may be removed. CaRide will cooperate with law enforcement on any illegal activity.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ProhibitedItemsScreen(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF3F4F7),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Text(
                    'See all prohibited items',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: fgColor,
                    ),
                  ),
                ),
              ),
            ),

            // ── If your delivery can't be completed ──
            const SizedBox(height: AppSpacing.xl),
            Text(
              "If your delivery can't be completed",
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w800,
                color: fgColor,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'If the delivery fails, you may be charged to get the package returned. The courier will hold the item for 24 hours for non-food deliveries, and for 1 hour for food items. After this period, the item will be discarded.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            
            // ── Disclaimer ──
            Text(
              'CaRide does not maintain insurance for packages. By tapping confirm order, you are consenting to the Terms and Conditions.',
              style: AppTextStyles.bodySmall.copyWith(
                color: isDark ? Colors.grey[500] : const Color(0xFF8A90A6),
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.pagePadding),
          child: PrimaryButton(
            label: _confirming
                ? 'Confirming…'
                : 'Confirm delivery • ${NgnFormat.whole(_c.offerNaira)}',
            onPressed: _confirming ? null : _confirmDelivery,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────

class _SendingToggle extends StatelessWidget {
  const _SendingToggle({
    required this.isSending,
    required this.onToggle,
  });

  final bool isSending;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _ToggleTab(
            label: "I'm sending",
            active: isSending,
            onTap: () => onToggle(true),
          ),
          _ToggleTab(
            label: "I'm receiving",
            active: !isSending,
            onTap: () => onToggle(false),
          ),
        ],
      ),
    );
  }
}

class _ToggleTab extends StatelessWidget {
  const _ToggleTab({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.md),
            boxShadow: active && !isDark
                ? [
                    const BoxShadow(
                      color: Color(0x18000000),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: active
                  ? Colors.black
                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
            ),
          ),
        ),
      ),
    );
  }
}

class _TripDetailsCard extends StatelessWidget {
  const _TripDetailsCard({
    required this.isSending,
    required this.pickupLabel,
    required this.dropoffLabel,
    required this.filledSenderName,
    required this.filledRecipientName,
    required this.onAddSender,
    required this.onAddRecipient,
    required this.isDark,
  });

  final bool isSending;
  final String pickupLabel;
  final String dropoffLabel;
  final String? filledSenderName;
  final String? filledRecipientName;
  final VoidCallback onAddSender;
  final VoidCallback onAddRecipient;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFFE9EAF0);

    final senderTitle = isSending
        ? (filledSenderName?.isNotEmpty == true ? filledSenderName! : 'You (sender)')
        : (filledSenderName?.isNotEmpty == true ? filledSenderName! : 'Add sender details');

    final recipientTitle = !isSending
        ? (filledRecipientName?.isNotEmpty == true ? filledRecipientName! : 'You (recipient)')
        : (filledRecipientName?.isNotEmpty == true ? filledRecipientName! : 'Add recipient details');

    final senderNeedsAdding = !isSending && (filledSenderName?.isEmpty ?? true);
    final recipientNeedsAdding = isSending && (filledRecipientName?.isEmpty ?? true);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        children: [
          _TripRow(
            icon: Icons.inventory_2_rounded,
            title: senderTitle,
            address: pickupLabel,
            subtitle: 'Meet at curb • Add instructions',
            showAdd: senderNeedsAdding,
            onAdd: onAddSender,
            isDark: isDark,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Container(
              height: 1,
              color: borderColor,
            ),
          ),
          _TripRow(
            icon: Icons.crop_square_rounded,
            title: recipientTitle,
            address: dropoffLabel,
            subtitle: 'Meet at curb • Add instructions',
            showAdd: recipientNeedsAdding,
            onAdd: onAddRecipient,
            isDark: isDark,
          ),
        ],
      ),
    );
  }
}

class _TripRow extends StatelessWidget {
  const _TripRow({
    required this.icon,
    required this.title,
    required this.address,
    required this.subtitle,
    required this.showAdd,
    required this.onAdd,
    required this.isDark,
  });

  final IconData icon;
  final String title;
  final String address;
  final String subtitle;
  final bool showAdd;
  final VoidCallback onAdd;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final primaryColor = isDark ? Colors.white : AppColors.slate900;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.brandGlass,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: AppColors.brand),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  address,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: mutedColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: mutedColor,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: onAdd,
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 6),
              minimumSize: Size.zero,
              side: BorderSide(
                color: showAdd
                    ? (isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.15))
                    : AppColors.brand.withValues(alpha: 0.4),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: Text(
              showAdd ? 'Add' : 'Edit',
              style: TextStyle(
                color: showAdd ? (isDark ? Colors.white : Colors.black) : AppColors.brand,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProtectDeliverySection extends StatelessWidget {
  const _ProtectDeliverySection({
    required this.controller,
    required this.isDark,
  });

  final BookingShellController controller;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = isDark ? Colors.white : AppColors.slate900;
    final mutedColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);

    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Protect your delivery',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w800,
              color: primaryColor,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'PIN confirmation',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          onTap: () => PinInfoBottomSheet.show(context),
                          child: Icon(
                            Icons.info_outline_rounded,
                            size: 16,
                            color: mutedColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      controller.pinConfirmationEnabled
                          ? 'You will receive a 4-digit PIN once the package is on its way.'
                          : 'Turn on to confirm delivery with a 4-digit PIN.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: mutedColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Switch(
                value: controller.pinConfirmationEnabled,
                onChanged: controller.setPinConfirmationEnabled,
                activeTrackColor: AppColors.brand,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
