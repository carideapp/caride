import 'package:caride/features/profile/data/trusted_contacts_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/shared_widgets.dart';

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
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final keyboardHeight = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: keyboardHeight),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.65,
            minChildSize: 0.40,
            maxChildSize: 0.95,
            builder: (_, ctrl) => GlassSurface(
              radius: AppRadius.xl,
              child: SingleChildScrollView(
                controller: ctrl,
                child: TrustedContactFormScreen(existing: existing, isSheet: true),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  State<TrustedContactFormScreen> createState() =>
      _TrustedContactFormScreenState();
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
      if (mounted) setState(() => _error = 'Failed to save contact: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final formContent = Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pagePadding,
        widget.isSheet ? AppSpacing.md : AppSpacing.pagePadding,
        AppSpacing.pagePadding,
        AppSpacing.pagePadding + (widget.isSheet ? 0 : MediaQuery.of(context).viewInsets.bottom),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isSheet) ...[
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.brand.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(
                      _isEditing
                          ? Icons.edit_rounded
                          : Icons.person_add_rounded,
                      color: AppColors.brand,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isEditing ? 'Edit Contact' : 'Add Trusted Contact',
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Emergency alerts will be sent to this email',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
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
              const SizedBox(height: AppSpacing.lg),
            ],
            GlassContainer(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.brand,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'This person will receive an email alert if you trigger an emergency during a ride.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Full Name',
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            AppTextField(
              controller: _nameCtrl,
              hint: 'e.g. Sarah Johnson',
              prefixIcon: Icons.person_rounded,
              validator: (v) =>
                  (v?.trim().isEmpty ?? true) ? 'Name is required' : null,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Email Address',
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            AppTextField(
              controller: _emailCtrl,
              hint: 'e.g. sarah@email.com',
              prefixIcon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: _validateEmail,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Relationship (optional)',
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            AppTextField(
              controller: _relationshipCtrl,
              hint: 'e.g. Sister, Friend, Partner',
              prefixIcon: Icons.favorite_border_rounded,
              textInputAction: TextInputAction.done,
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.md),
              InlineError(message: _error!),
            ],
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: _isEditing ? 'Save Changes' : 'Add Contact',
              isLoading: _loading,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );

    if (widget.isSheet) {
      return formContent;
    }

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: GlassAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: _isEditing ? 'Edit Contact' : 'Add Trusted Contact',
      ),
      body: SafeArea(child: SingleChildScrollView(child: formContent)),
    );
  }
}
