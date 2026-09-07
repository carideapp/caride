import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';

import 'controllers/fleet_auth_controller.dart';
import 'controllers/fleet_auth_error_helper.dart';

/// Redesigned Fleet Manager Forgot Password Screen matching the design system.
class FleetManagerForgotPasswordScreen extends StatefulWidget {
  const FleetManagerForgotPasswordScreen({super.key});

  @override
  State<FleetManagerForgotPasswordScreen> createState() =>
      _FleetManagerForgotPasswordScreenState();
}

class _FleetManagerForgotPasswordScreenState
    extends State<FleetManagerForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  bool _emailSent = false;
  String? _errorMessage;

  static const Color _lightInputFill = Color(0xFFF3F4F6);
  static const Color _labelColor = Color(0xFF1F2937);
  static const Color _hintColor = Color(0xFF9CA3AF);
  static const Color _subtitleColor = Color(0xFF6B7280);

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleReset() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await fleetAuthController
          .sendPasswordResetEmail(_emailController.text.trim());
      if (!mounted) return;
      setState(() => _emailSent = true);
    } catch (e) {
      if (!mounted) return;
      final parsed = FleetAuthErrorHelper.parseError(e);
      setState(() {
        _errorMessage = parsed;
      });
      FleetAuthErrorHelper.showErrorSnackBar(context, parsed);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Circular Back Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: primaryTextColor,
                      ),
                      onPressed: () => context.pop(),
                    ),
                  ),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                child: _emailSent
                    ? _buildSuccessView(isDark, primaryTextColor)
                    : _buildFormView(isDark, primaryTextColor),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormView(bool isDark, Color primaryTextColor) {
    final labelTextColor = isDark ? AppColors.textPrimaryDark : _labelColor;
    final subtitleTextColor = isDark ? AppColors.textSecondaryDark : _subtitleColor;
    final inputFill = isDark ? AppColors.darkSurface : _lightInputFill;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),

          // Title
          Text(
            'Forgot Password?',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: primaryTextColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),

          // Subtitle
          Text(
            'Enter the email address registered with your Fleet Manager account and we will send you recovery instructions.',
            style: TextStyle(
              fontSize: 15,
              color: subtitleTextColor,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),

          // Error Banner
          if (_errorMessage != null)
            FleetAuthErrorHelper.buildErrorBanner(
              message: _errorMessage!,
              isDark: isDark,
              onDismiss: () => setState(() => _errorMessage = null),
            ),

          // Field: Email Address
          Text(
            'Email Address',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: labelTextColor,
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: TextStyle(color: primaryTextColor, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Enter your registered email',
              hintStyle: const TextStyle(color: _hintColor, fontSize: 14),
              filled: true,
              fillColor: inputFill,
              contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter your email address';
              }
              if (!value.contains('@') || !value.contains('.')) {
                return 'Please enter a valid email address';
              }
              return null;
            },
          ),
          const SizedBox(height: 32),

          // Send Instructions Button (Green Pill)
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              onPressed: _isLoading ? null : _handleReset,
              child: _isLoading
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Send Recovery Instructions',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSuccessView(bool isDark, Color primaryTextColor) {
    final subtitleTextColor = isDark ? AppColors.textSecondaryDark : _subtitleColor;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),

          // Scalloped Rosette Success Emblem in AppColors.brand
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: AppColors.brand,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 44,
            ),
          ),
          const SizedBox(height: 28),

          Text(
            'Reset Link Sent!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: primaryTextColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'We have sent a password reset link to ${_emailController.text.trim()}. Please check your inbox.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: subtitleTextColor,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 36),

          // Return to Login Button (Green Pill)
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              onPressed: () => context.pop(),
              child: const Text(
                'Back to Login',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
