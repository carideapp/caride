import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:caride/core/driver/auth/driver_auth_controller.dart';
import 'package:caride/features/driver/profile/data/driver_document_repository.dart';
import 'package:caride/features/driver/profile/widgets/success_dialog.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/shared_widgets.dart';

class DriverGuarantorInfoScreen extends StatefulWidget {
  const DriverGuarantorInfoScreen({super.key});

  @override
  State<DriverGuarantorInfoScreen> createState() => _DriverGuarantorInfoScreenState();
}

class _DriverGuarantorInfoScreenState extends State<DriverGuarantorInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repo = DriverDocumentRepository();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _relationshipController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _relationshipController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final uid = driverAuthController.currentUid;
    if (uid == null) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await _repo.saveGuarantorInfo(
        uid: uid,
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        address: _addressController.text.trim(),
        relationship: _relationshipController.text.trim(),
      );

      if (!mounted) return;
      Navigator.of(context).pop();

      unawaited(SuccessDialog.show(
        context,
        title: 'Guarantor Details Saved',
        description:
            'Your guarantor information has been submitted successfully for verification.',
        buttonLabel: 'Okay',
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Failed to save guarantor info. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.lightBackground;

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: const Text('Guarantor Information'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Guarantor Verification',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Provide the details of a verifiable guarantor (family member, employer, or respected community member).',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                AppTextField(
                  controller: _nameController,
                  hint: 'Guarantor Full Name',
                  prefixIcon: Icons.person_outline,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Guarantor full name is required'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _phoneController,
                  hint: 'Guarantor Phone Number',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (v) => (v == null || v.trim().length < 10)
                      ? 'Valid phone number is required'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _relationshipController,
                  hint: 'Relationship (e.g. Employer, Brother, Friend)',
                  prefixIcon: Icons.people_outline,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Relationship is required'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),
                AppTextField(
                  controller: _addressController,
                  hint: 'Guarantor Residential Address',
                  prefixIcon: Icons.location_on_outlined,
                  maxLines: 3,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Residential address is required'
                      : null,
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: AppColors.error),
                    textAlign: TextAlign.center,
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: _isSubmitting ? 'Submitting...' : 'Submit Guarantor Details',
                  isLoading: _isSubmitting,
                  onPressed: _isSubmitting ? null : _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
