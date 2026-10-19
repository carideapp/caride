import 'package:caride/features/profile/data/trusted_contacts_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Form screen or bottom sheet for adding or editing a trusted contact.
class TrustedContactFormScreen extends StatefulWidget {
  const TrustedContactFormScreen({
    super.key,
    this.existing,
    this.isSheet = false,
  });

  /// When provided, the form is in edit mode.
  final TrustedContact? existing;

  /// Whether this widget is presented inside a bottom sheet.
  final bool isSheet;

  /// Helper method to open the form inside a bottom sheet.
  static Future<void> showSheet(
    BuildContext context, {
    TrustedContact? existing,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final keyboardHeight = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: keyboardHeight),
          child: Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: SingleChildScrollView(
              child: TrustedContactFormScreen(existing: existing, isSheet: true),
            ),
          ),
        );
      },
    );
  }

  @override
  State<TrustedContactFormScreen> createState() => _TrustedContactFormScreenState();
}

class _TrustedContactFormScreenState extends State<TrustedContactFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _relationshipCtrl = TextEditingController();
  final _repo = TrustedContactsRepository();
  bool _loading = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final c = widget.existing!;
      _nameCtrl.text = c.name;
      _emailCtrl.text = c.email;
      _relationshipCtrl.text = c.relationship;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _relationshipCtrl.dispose();
    super.dispose();
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    final r = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!r.hasMatch(v.trim())) return 'Enter a valid email address';
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final contact = TrustedContact(
        id: widget.existing?.id ?? '',
        name: _nameCtrl.text.trim(),
        email: _emailCtrl.text.trim().toLowerCase(),
        relationship: _relationshipCtrl.text.trim(),
      );
      if (_isEditing) {
        await _repo.updateContact(contact);
      } else {
        await _repo.addContact(contact);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) setState(() => _error = 'Failed to save contact. Please verify details and try again.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final borderColor = isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);
    final inputBg = isDark ? AppColors.darkSurface : const Color(0xFFF3F4F6);

    final formContent = Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        widget.isSheet ? 16 : 20,
        20,
        24 + (widget.isSheet ? 0 : MediaQuery.of(context).viewInsets.bottom),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isSheet) ...[
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
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _isEditing ? Icons.edit_rounded : Icons.person_add_rounded,
                      color: AppColors.brand,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEditing ? 'Edit Trusted Contact' : 'Add Trusted Contact',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: primaryTextColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Ride emergency alerts will be routed here',
                          style: TextStyle(
                            fontSize: 13,
                            color: secondaryTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: primaryTextColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],

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

            Text(
              'Full Name',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 8),
            _buildPillField(
              controller: _nameCtrl,
              hint: 'e.g. Sarah Johnson',
              icon: Icons.person_outline_rounded,
              isDark: isDark,
              borderColor: borderColor,
              inputBg: inputBg,
              primaryTextColor: primaryTextColor,
              secondaryTextColor: secondaryTextColor,
              validator: (v) => (v?.trim().isEmpty ?? true) ? 'Name is required' : null,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),

            Text(
              'Email Address',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 8),
            _buildPillField(
              controller: _emailCtrl,
              hint: 'e.g. sarah@example.com',
              icon: Icons.email_outlined,
              isDark: isDark,
              borderColor: borderColor,
              inputBg: inputBg,
              primaryTextColor: primaryTextColor,
              secondaryTextColor: secondaryTextColor,
              keyboardType: TextInputType.emailAddress,
              validator: _validateEmail,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),

            Text(
              'Relationship (optional)',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: 8),
            _buildPillField(
              controller: _relationshipCtrl,
              hint: 'e.g. Sister, Friend, Spouse',
              icon: Icons.favorite_border_rounded,
              isDark: isDark,
              borderColor: borderColor,
              inputBg: inputBg,
              primaryTextColor: primaryTextColor,
              secondaryTextColor: secondaryTextColor,
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  elevation: 0,
                  disabledBackgroundColor: AppColors.brand.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        _isEditing ? 'Save Contact Changes' : 'Add Trusted Contact',
                        style: const TextStyle(
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

    if (widget.isSheet) {
      return formContent;
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
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
                    _isEditing ? 'Edit Contact' : 'Add Trusted Contact',
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
              child: SingleChildScrollView(child: formContent),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPillField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isDark,
    required Color borderColor,
    required Color inputBg,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      style: TextStyle(
        fontSize: 15,
        color: primaryTextColor,
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          fontSize: 14,
          color: secondaryTextColor,
        ),
        filled: true,
        fillColor: inputBg,
        prefixIcon: Icon(icon, color: AppColors.brand, size: 20),
        contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: AppColors.brand, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: AppColors.error, width: 1.8),
        ),
      ),
    );
  }
}
