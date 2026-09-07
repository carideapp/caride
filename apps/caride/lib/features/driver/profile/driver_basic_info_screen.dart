import 'package:design_system/design_system.dart';
import 'package:caride/core/driver/auth/driver_auth_controller.dart';
import 'package:caride/features/driver/auth/data/driver_profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/shared_widgets.dart';

class DriverBasicInfoScreen extends StatefulWidget {
  const DriverBasicInfoScreen({super.key});

  @override
  State<DriverBasicInfoScreen> createState() => _DriverBasicInfoScreenState();
}

class _DriverBasicInfoScreenState extends State<DriverBasicInfoScreen> {
  final _profileRepo = DriverProfileRepository();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = driverAuthController.currentUid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    final profile = await _profileRepo.getDriverProfile(uid);
    if (mounted) {
      _nameController.text = profile?.fullName ?? '';
      _phoneController.text = profile?.phone ?? '';
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final uid = driverAuthController.currentUid;
    if (uid == null) return;

    setState(() => _saving = true);
    try {
      await _profileRepo.updateBasicInfo(
        uid: uid,
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
      );
      if (!mounted) return;
      _showSuccessPopup();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update info: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showSuccessPopup() {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
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
                'Profile Updated',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Your basic information has been updated successfully.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: 'OK',
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop();
                  },
                ),
              ),
            ],
          ),
        );
      },
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

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          'Personal Info',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Styled info banner matching customer app style
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
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
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.info_outline_rounded,
                              color: AppColors.primaryGreen,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Text(
                              'Your name and phone are visible to customers during rides.',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark ? Colors.grey[300] : const Color(0xFF4A4D70),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    _buildInputField(
                      context,
                      label: 'Full Name',
                      controller: _nameController,
                    ),
                    _buildInputField(
                      context,
                      label: 'Phone Number',
                      controller: _phoneController,
                      prefix: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('🇳🇬', style: TextStyle(fontSize: 14)),
                          SizedBox(width: 4),
                          Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: AppColors.primaryGreen),
                        ],
                      ),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    PrimaryButton(
                      label: 'Save Changes',
                      isLoading: _saving,
                      onPressed: _submit,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInputField(
    BuildContext context, {
    required String label,
    required TextEditingController controller,
    Widget? prefix,
    TextInputType? keyboardType,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppColors.slate900,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          AppTextField(
            controller: controller,
            hint: label,
            keyboardType: keyboardType,
            prefix: prefix != null
                ? Padding(
                    padding: const EdgeInsets.only(
                      left: AppSpacing.md,
                      right: AppSpacing.sm,
                    ),
                    child: prefix,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}
