import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';

import 'controllers/fleet_auth_controller.dart';
import 'controllers/fleet_auth_error_helper.dart';

/// Redesigned Fleet Manager Login Screen matching the modern pill-styled minimalist aesthetic.
class FleetManagerLoginScreen extends StatefulWidget {
  const FleetManagerLoginScreen({super.key});

  @override
  State<FleetManagerLoginScreen> createState() => _FleetManagerLoginScreenState();
}

class _FleetManagerLoginScreenState extends State<FleetManagerLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  // Design tokens matching CaRide brand and reference layout
  static const Color _primaryBrand = AppColors.brand; // Color(0xFF16A34A)
  static const Color _lightInputFill = Color(0xFFF3F4F6);
  static const Color _labelColor = Color(0xFF1F2937);
  static const Color _hintColor = Color(0xFF9CA3AF);
  static const Color _subtitleColor = Color(0xFF6B7280);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await fleetAuthController.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;

      context.go(FleetRoutePaths.dashboard);
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

    final inputFill = isDark ? AppColors.darkSurface : _lightInputFill;
    final primaryTextColor = isDark ? Colors.white : Colors.black;
    final labelTextColor = isDark ? AppColors.textPrimaryDark : _labelColor;
    final subtitleTextColor = isDark ? AppColors.textSecondaryDark : _subtitleColor;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Back Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 20,
                      color: primaryTextColor,
                    ),
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go(CustomerRoutePaths.roleSelector);
                      }
                    },
                  ),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 8.0,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),

                      // Title
                      Text(
                        'Welcome Back',
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
                        'Login to manage your vehicles and fleet operations.',
                        style: TextStyle(
                          fontSize: 15,
                          color: subtitleTextColor,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Error message banner if any
                      if (_errorMessage != null)
                        FleetAuthErrorHelper.buildErrorBanner(
                          message: _errorMessage!,
                          isDark: isDark,
                          onDismiss: () => setState(() => _errorMessage = null),
                        ),

                      // Field 1: Email / Phone Number
                      Text(
                        'Email / Phone Number',
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
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter email or phone number',
                          hintStyle: const TextStyle(
                            color: _hintColor,
                            fontSize: 14,
                          ),
                          filled: true,
                          fillColor: inputFill,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 18,
                          ),
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
                            borderSide: const BorderSide(
                              color: _primaryBrand,
                              width: 1.5,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter your email or phone number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 20),

                      // Field 2: Password
                      Text(
                        'Password',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: labelTextColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: 15,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter password',
                          hintStyle: const TextStyle(
                            color: _hintColor,
                            fontSize: 14,
                          ),
                          filled: true,
                          fillColor: inputFill,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 18,
                          ),
                          suffixIcon: Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: _primaryBrand,
                                size: 22,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
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
                            borderSide: const BorderSide(
                              color: _primaryBrand,
                              width: 1.5,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 14),

                      // Forgot Password Link
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          onTap: () => context.push(FleetRoutePaths.forgotPassword),
                          child: const Text(
                            'Forgot password ?',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _primaryBrand,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Login Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _primaryBrand,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          onPressed: _isLoading ? null : _handleLogin,
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
                                  'Login',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Don't have an account ? Sign Up
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Don't have an account ? ",
                            style: TextStyle(
                              fontSize: 14,
                              color: subtitleTextColor,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => context.push(FleetRoutePaths.signup),
                            child: const Text(
                              'Sign Up',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _primaryBrand,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
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
