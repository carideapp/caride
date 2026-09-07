import 'package:caride/features/ride_booking/booking_shell/booking_shell_controller.dart';
import 'package:caride/features/profile/data/account_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Result model returned by [DropoffDetailsBottomSheet].
class DropoffDetailsResult {
  const DropoffDetailsResult({
    required this.name,
    required this.phone,
    required this.storeName,
    required this.unitFloor,
    required this.dropoffOption,
    required this.driverInstructions,
  });

  final String name;
  final String phone;
  final String storeName;
  final String unitFloor;
  final DropoffOption dropoffOption;
  final String driverInstructions;
}

enum DropoffOption { meetAtCurb, meetAtDoor }

/// Bottom sheet matching the `dropoff_details.jpeg` UI design.
/// Collects recipient contact info, location details, dropoff preference,
/// and special instructions for the driver.
class DropoffDetailsBottomSheet extends StatefulWidget {
  const DropoffDetailsBottomSheet({
    super.key,
    required this.addressLabel,
    required this.controller,
    this.isSender = false,
    this.initialName,
    this.initialPhone,
    this.isMe = false,
  });

  final String addressLabel;
  final BookingShellController controller;
  /// When true, we're editing sender details (for "I'm receiving" flow).
  final bool isSender;
  final String? initialName;
  final String? initialPhone;
  final bool isMe;

  static Future<DropoffDetailsResult?> show(
    BuildContext context, {
    required String addressLabel,
    required BookingShellController controller,
    bool isSender = false,
    String? initialName,
    String? initialPhone,
    bool isMe = false,
  }) {
    return showModalBottomSheet<DropoffDetailsResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DropoffDetailsBottomSheet(
        addressLabel: addressLabel,
        controller: controller,
        isSender: isSender,
        initialName: initialName,
        initialPhone: initialPhone,
        isMe: isMe,
      ),
    );
  }

  @override
  State<DropoffDetailsBottomSheet> createState() =>
      _DropoffDetailsBottomSheetState();
}

class _DropoffDetailsBottomSheetState
    extends State<DropoffDetailsBottomSheet> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _storeCtrl = TextEditingController();
  final _unitCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();
  DropoffOption _dropoffOption = DropoffOption.meetAtCurb;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.initialName ?? '';
    _phoneCtrl.text = widget.initialPhone ?? '';

    if (widget.isMe && _nameCtrl.text.isEmpty && _phoneCtrl.text.isEmpty) {
      _loadUserProfile();
    }
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await AccountRepository().watchProfile().first;
      if (profile != null && mounted) {
        setState(() {
          if (_nameCtrl.text.isEmpty) {
            _nameCtrl.text = profile.fullName;
          }
          if (_phoneCtrl.text.isEmpty) {
            _phoneCtrl.text = profile.phone;
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _storeCtrl.dispose();
    _unitCtrl.dispose();
    _instructionsCtrl.dispose();
    super.dispose();
  }

  void _save() {
    final result = DropoffDetailsResult(
      name: _nameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      storeName: _storeCtrl.text.trim(),
      unitFloor: _unitCtrl.text.trim(),
      dropoffOption: _dropoffOption,
      driverInstructions: _instructionsCtrl.text.trim(),
    );
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final mutedColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE9EAF0);
    final fieldBg =
        isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF8F9FA);

    final title = widget.isSender ? 'Pickup details' : 'Dropoff details';
    final contactQuestion = widget.isSender
        ? "Who's sending the package?"
        : "Who's receiving the package?";

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar
                Container(
                  margin: const EdgeInsets.only(top: AppSpacing.sm),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.pagePadding,
                    AppSpacing.sm,
                    AppSpacing.pagePadding,
                    AppSpacing.xl,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  // Header
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        style: IconButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(40, 40),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 40),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Contact question
                  Text(
                    contactQuestion,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Name field
                  _DetailsField(
                    controller: _nameCtrl,
                    hint: 'Name',
                    fieldBg: fieldBg,
                    borderColor: borderColor,
                    isDark: isDark,
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  // Phone field with Nigeria flag prefix
                  Container(
                    decoration: BoxDecoration(
                      color: fieldBg,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Nigerian flag emoji
                              const Text('🇳🇬',
                                  style: TextStyle(fontSize: 20)),
                              const SizedBox(width: 4),
                              Icon(Icons.arrow_drop_down_rounded,
                                  color: mutedColor, size: 20),
                              const SizedBox(width: 4),
                              Text(
                                '+234',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 32,
                          color: borderColor,
                        ),
                        Expanded(
                          child: TextField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            decoration: InputDecoration(
                              hintText: '0802 123 4567',
                              hintStyle: TextStyle(color: mutedColor),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.md,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Address display
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.location_on_rounded,
                          color: AppColors.brand, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.addressLabel.split(',').first,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              widget.addressLabel,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: mutedColor,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),

                  // Store name + Unit floor row
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Store or building name',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: mutedColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _DetailsField(
                              controller: _storeCtrl,
                              hint: 'E.g. Blue store',
                              fieldBg: fieldBg,
                              borderColor: borderColor,
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Unit/floor',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: mutedColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            _DetailsField(
                              controller: _unitCtrl,
                              hint: 'E.g. Unit 1A',
                              fieldBg: fieldBg,
                              borderColor: borderColor,
                              isDark: isDark,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Dropoff options
                  Text(
                    'Dropoff options',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      _DropoffOptionChip(
                        icon: Icons.airline_seat_recline_normal_rounded,
                        label: 'Meet at curb',
                        selected: _dropoffOption == DropoffOption.meetAtCurb,
                        onTap: () => setState(
                            () => _dropoffOption = DropoffOption.meetAtCurb),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _DropoffOptionChip(
                        icon: Icons.person_rounded,
                        label: 'Meet at door',
                        selected: _dropoffOption == DropoffOption.meetAtDoor,
                        onTap: () => setState(
                            () => _dropoffOption = DropoffOption.meetAtDoor),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),

                  // Instructions for driver
                  Text(
                    'Instructions for driver',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Container(
                    decoration: BoxDecoration(
                      color: fieldBg,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: borderColor),
                    ),
                    child: TextField(
                      controller: _instructionsCtrl,
                      maxLines: 3,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                      decoration: InputDecoration(
                        hintText:
                            'Add details to help your courier find you at the curb for dropoff (e.g., pickup spot, landmark, or what to look for).',
                        hintStyle: TextStyle(
                          color: mutedColor,
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.all(AppSpacing.md),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  SizedBox(
                    width: double.infinity,
                    child: PrimaryButton(
                      label: 'Save and continue',
                      onPressed: _save,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    ),
    );
  }
}

/// Simple single-line text input field used inside the bottom sheet.
class _DetailsField extends StatelessWidget {
  const _DetailsField({
    required this.controller,
    required this.hint,
    required this.fieldBg,
    required this.borderColor,
    required this.isDark,
  });

  final TextEditingController controller;
  final String hint;
  final Color fieldBg;
  final Color borderColor;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mutedColor =
        isDark ? Colors.grey[400]! : const Color(0xFF6E7191);

    return Container(
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: borderColor),
      ),
      child: TextField(
        controller: controller,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: mutedColor),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
        ),
      ),
    );
  }
}

/// Pill-style chip for selecting dropoff option.
class _DropoffOptionChip extends StatelessWidget {
  const _DropoffOptionChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: selected ? Colors.black : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(
            color: selected ? Colors.black : Colors.grey.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: selected ? Colors.white : Colors.grey),
            const SizedBox(width: 6),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: selected ? Colors.white : null,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
