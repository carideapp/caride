import 'package:caride/core/services/deep_link_service.dart';
import 'package:caride/features/profile/data/shared_trip_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';

class MonitorTripEntryScreen extends StatefulWidget {
  const MonitorTripEntryScreen({super.key});

  @override
  State<MonitorTripEntryScreen> createState() => _MonitorTripEntryScreenState();
}

class _MonitorTripEntryScreenState extends State<MonitorTripEntryScreen> {
  final _codeController = TextEditingController();
  final _sharedRepo = SharedTripRepository();
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkPendingTripCode();
  }

  /// If the app was launched via a shared-trip deep link, auto-populate
  /// the code field and submit it without requiring manual entry.
  Future<void> _checkPendingTripCode() async {
    final code = await DeepLinkService.instance.getOrFetchPendingTripCode();
    if (code != null && code.isNotEmpty && mounted) {
      _codeController.text = code;
      // Small delay so the user can see the code being filled in.
      await Future.delayed(const Duration(milliseconds: 400));
      if (mounted) await _submit();
    }
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Please enter a valid 6-digit trip sharing code.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rideId = await _sharedRepo.getRideIdFromCode(code);
      if (!mounted) return;

      if (rideId == null) {
        setState(() => _error = 'Invalid or expired trip code. Please ask the rider for an active code.');
        await DeepLinkService.instance.clearPendingTripCode();
      } else {
        await DeepLinkService.instance.clearPendingTripCode();
        if (!mounted) return;
        context.push(
          CustomerRoutePaths.monitorTrip,
          extra: {
            'rideId': rideId,
            'code': code,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Failed to connect to trip server. Please check your internet connection.');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);
    final inputBg = isDark ? AppColors.darkSurface : const Color(0xFFF3F4F6);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
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
                    'Monitor a Trip',
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
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: AppColors.brand.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.share_location_rounded,
                              color: AppColors.brand,
                              size: 26,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Text(
                            "Track a Friend's Journey",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: primaryTextColor,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Enter the 6-character trip sharing code provided by your friend to view their live route, driver details, and estimated arrival in real-time.',
                            style: TextStyle(
                              fontSize: 14,
                              color: secondaryTextColor,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 24),

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
                            'Trip Sharing Code',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: primaryTextColor,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _codeController,
                            keyboardType: TextInputType.text,
                            textCapitalization: TextCapitalization.characters,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _submit(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2,
                              color: primaryTextColor,
                            ),
                            decoration: InputDecoration(
                              hintText: 'e.g. AB12CD',
                              hintStyle: TextStyle(
                                fontSize: 14,
                                letterSpacing: 0,
                                color: secondaryTextColor,
                              ),
                              filled: true,
                              fillColor: inputBg,
                              prefixIcon: const Icon(Icons.pin_rounded, color: AppColors.brand, size: 20),
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
                            ),
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
                                  : const Text(
                                      'Start Monitoring Trip',
                                      style: TextStyle(
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
