import 'package:caride/core/services/deep_link_service.dart';
import 'package:caride/features/profile/data/shared_trip_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

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
      setState(() => _error = 'Please enter a trip code');
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
        setState(() => _error = 'Invalid or expired trip code');
        // If the code came from a deep link and is invalid, clear it so
        // the user is not stuck in a loop.
        await DeepLinkService.instance.clearPendingTripCode();
      } else {
        // Clear the pending deep link before navigating.
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
        setState(() => _error = 'An error occurred. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE9EAF0);
    final primaryTextColor = isDark ? Colors.white : AppColors.slate900;
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);

    final isTablet = Responsive.isTablet(context) || Responsive.isSmallTablet(context);
    final isLandscape = Responsive.isLandscape(context);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: true,
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          'Monitor a Trip',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: isTablet || isLandscape ? 500 : double.infinity,
            ),
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              children: [
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Track a friend\'s journey',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: primaryTextColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Enter the 6-digit sharing code provided by your friend to view their live trip updates.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: mutedTextColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: cardBg,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Trip Sharing Code',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: primaryTextColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      AppTextField(
                        controller: _codeController,
                        hint: 'e.g. 123456',
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.done,
                        prefix: Icon(Icons.share_location_rounded, color: mutedTextColor),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        InlineError(message: _error!),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      PrimaryButton(
                        label: 'Monitor Trip',
                        isLoading: _loading,
                        onPressed: _submit,
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
