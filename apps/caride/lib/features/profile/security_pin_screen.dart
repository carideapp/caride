import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:caride/features/profile/data/security_pin_repository.dart';
import 'package:shared_widgets/shared_widgets.dart';

enum SecurityPinMode { create, change, reset }

class SecurityPinScreen extends StatefulWidget {
  const SecurityPinScreen({super.key, this.mode = SecurityPinMode.create});
  final SecurityPinMode mode;

  @override
  State<SecurityPinScreen> createState() => _SecurityPinScreenState();
}

class _SecurityPinScreenState extends State<SecurityPinScreen> {
  final _repo = SecurityPinRepository();

  // Which sub-step we're on
  int _step = 0;
  // For OTP (reset flow)
  final _otpController = TextEditingController();

  String _currentPin = '';
  String _firstPin = '';
  String _oldPin = '';
  String _otp = '';
  bool _loading = false;
  String? _error;
  bool _otpSent = false;

  String get _stepTitle {
    switch (_activeMode) {
      case SecurityPinMode.create:
        return _step == 0 ? 'Enter New PIN' : 'Confirm New PIN';
      case SecurityPinMode.change:
        if (_step == 0) return 'Enter Current PIN';
        if (_step == 1) return 'Enter New PIN';
        return 'Confirm New PIN';
      case SecurityPinMode.reset:
        if (_step == 0) return 'Enter OTP Code';
        if (_step == 1) return 'Enter New PIN';
        return 'Confirm New PIN';
    }
  }

  String get _stepSubtitle {
    switch (_activeMode) {
      case SecurityPinMode.create:
        return _step == 0
            ? 'Choose a 4-digit PIN to secure your transactions'
            : 'Re-enter your PIN to confirm';
      case SecurityPinMode.change:
        if (_step == 0) return 'Enter your existing security PIN';
        if (_step == 1) return 'Choose a new 4-digit PIN';
        return 'Re-enter your new PIN to confirm';
      case SecurityPinMode.reset:
        if (_step == 0) return 'Enter the 6-digit OTP sent to your email';
        if (_step == 1) return 'Choose a new 4-digit PIN';
        return 'Re-enter your new PIN to confirm';
    }
  }

  int get _pinLength => (_activeMode == SecurityPinMode.reset && _step == 0) ? 6 : 4;

  late SecurityPinMode _activeMode;

  @override
  void initState() {
    super.initState();
    _activeMode = widget.mode;
    if (_activeMode == SecurityPinMode.create) {
      _detectMode();
    } else if (_activeMode == SecurityPinMode.reset) {
      _sendOtp();
    }
  }

  Future<void> _detectMode() async {
    setState(() => _loading = true);
    try {
      final hasPin = await _repo.hasPinSet();
      if (mounted) {
        setState(() {
          if (hasPin) {
            _activeMode = SecurityPinMode.change;
          }
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    setState(() => _loading = true);
    try {
      await _repo.sendResetOtp();
      setState(() {
        _otpSent = true;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to send OTP. Please try again.';
        _loading = false;
      });
    }
  }

  void _onKey(String digit) {
    if (_currentPin.length < _pinLength) {
      setState(() {
        _currentPin += digit;
        _error = null;
      });
      if (_currentPin.length == _pinLength) {
        _onPinComplete();
      }
    }
  }

  void _onDelete() {
    if (_currentPin.isNotEmpty) {
      setState(() => _currentPin = _currentPin.substring(0, _currentPin.length - 1));
    }
  }

  Future<void> _onPinComplete() async {
    final pin = _currentPin;

    // Small debounce for animation
    await Future.delayed(const Duration(milliseconds: 150));

    switch (_activeMode) {
      case SecurityPinMode.create:
        await _handleCreate(pin);
      case SecurityPinMode.change:
        await _handleChange(pin);
      case SecurityPinMode.reset:
        await _handleReset(pin);
    }
  }

  Future<void> _handleCreate(String pin) async {
    if (_step == 0) {
      setState(() {
        _firstPin = pin;
        _currentPin = '';
        _step = 1;
      });
    } else {
      if (pin != _firstPin) {
        setState(() {
          _error = 'PINs do not match. Try again.';
          _currentPin = '';
          _step = 0;
        });
        return;
      }
      await _submit(() => _repo.createPin(pin));
    }
  }

  Future<void> _handleChange(String pin) async {
    if (_step == 0) {
      setState(() {
        _oldPin = pin;
        _currentPin = '';
        _step = 1;
      });
    } else if (_step == 1) {
      setState(() {
        _firstPin = pin;
        _currentPin = '';
        _step = 2;
      });
    } else {
      if (pin != _firstPin) {
        setState(() {
          _error = 'New PINs do not match. Try again.';
          _currentPin = '';
          _step = 1;
        });
        return;
      }
      await _submit(() => _repo.changePin(oldPin: _oldPin, newPin: pin));
    }
  }

  Future<void> _handleReset(String pin) async {
    if (_step == 0) {
      setState(() {
        _otp = pin;
        _currentPin = '';
        _step = 1;
      });
    } else if (_step == 1) {
      setState(() {
        _firstPin = pin;
        _currentPin = '';
        _step = 2;
      });
    } else {
      if (pin != _firstPin) {
        setState(() {
          _error = 'PINs do not match. Try again.';
          _currentPin = '';
          _step = 1;
        });
        return;
      }
      await _submit(() => _repo.resetPin(otp: _otp, newPin: pin));
    }
  }

  Future<void> _submit(Future<void> Function() action) async {
    setState(() => _loading = true);
    try {
      await action();
      if (!mounted) return;
      _showSuccess();
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
        _currentPin = '';
        _step = 0;
      });
    }
  }

  void _showSuccess() {
    Navigator.of(context).pop(); // pop pin screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_successMessage),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.brand,
      ),
    );
  }

  String get _successMessage {
    switch (_activeMode) {
      case SecurityPinMode.create:
        return '✅ Security PIN created successfully!';
      case SecurityPinMode.change:
        return '✅ Security PIN changed successfully!';
      case SecurityPinMode.reset:
        return '✅ Security PIN reset successfully!';
    }
  }

  String get _screenTitle {
    switch (_activeMode) {
      case SecurityPinMode.create:
        return 'Create PIN';
      case SecurityPinMode.change:
        return 'Change PIN';
      case SecurityPinMode.reset:
        return 'Reset PIN';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: GlassAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: _screenTitle,
      ),
      body: SafeArea(
        child: _loading
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppLoader(),
                    SizedBox(height: AppSpacing.md),
                    Text('Processing...'),
                  ],
                ),
              )
            : Column(
                children: [
                  // Progress dots
                  const SizedBox(height: AppSpacing.lg),
                  _StepDots(
                    total: _activeMode == SecurityPinMode.create ? 2 : 3,
                    current: _step,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Title & subtitle
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
                    child: Column(
                      children: [
                        Text(
                          _stepTitle,
                          style: AppTextStyles.headlineSmall.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          _stepSubtitle,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (_activeMode == SecurityPinMode.reset && _step == 0 && _otpSent) ...[
                          const SizedBox(height: AppSpacing.sm),
                          Text(
                            'OTP sent! Check your email inbox.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.brand,
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // PIN dots indicator
                  _PinDots(
                    filled: _currentPin.length,
                    total: _pinLength,
                  ),

                  // Error
                  if (_error != null) ...[
                    const SizedBox(height: AppSpacing.md),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
                      child: Text(
                        _error!,
                        style: AppTextStyles.bodySmall.copyWith(color: AppColors.error),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],

                  const Spacer(),

                  // Keypad
                  _PinKeypad(onKey: _onKey, onDelete: _onDelete),
                  const SizedBox(height: AppSpacing.xl),

                  // Reset PIN link (only show on create/change screens)
                  if (_activeMode == SecurityPinMode.change && _step == 0)
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => const SecurityPinScreen(
                              mode: SecurityPinMode.reset,
                            ),
                          ),
                        );
                      },
                      child: Text(
                        'Forgot PIN? Reset via email',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.brand,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
      ),
    );
  }
}

// ── Step progress dots ────────────────────────────────────────────────────────
class _StepDots extends StatelessWidget {
  const _StepDots({required this.total, required this.current});
  final int total;
  final int current;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final isActive = i == current;
        final isDone = i < current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isDone || isActive
                ? AppColors.brand
                : (Theme.of(context).brightness == Brightness.dark
                    ? Colors.white24
                    : Colors.black12),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}

// ── PIN dots display ──────────────────────────────────────────────────────────
class _PinDots extends StatelessWidget {
  const _PinDots({required this.filled, required this.total});
  final int filled;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final isFilled = i < filled;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? AppColors.brand : Colors.transparent,
            border: Border.all(
              color: isFilled
                  ? AppColors.brand
                  : (Theme.of(context).brightness == Brightness.dark
                      ? Colors.white38
                      : Colors.black26),
              width: 2,
            ),
          ),
        );
      }),
    );
  }
}

// ── Custom keypad ─────────────────────────────────────────────────────────────
class _PinKeypad extends StatelessWidget {
  const _PinKeypad({required this.onKey, required this.onDelete});
  final void Function(String digit) onKey;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget key(String label, {VoidCallback? onTap, Widget? child}) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap ?? () => onKey(label),
          child: Container(
            margin: const EdgeInsets.all(6),
            height: 72,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: isDark
                  ? null
                  : [
                      const BoxShadow(
                        color: Color(0x0F000000),
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ],
            ),
            child: Center(
              child: child ??
                  Text(
                    label,
                    style: AppTextStyles.headlineMedium.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
            ),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        children: [
          Row(children: [key('1'), key('2'), key('3')]),
          Row(children: [key('4'), key('5'), key('6')]),
          Row(children: [key('7'), key('8'), key('9')]),
          Row(
            children: [
              const Expanded(child: SizedBox()),
              key('0'),
              key(
                '',
                onTap: onDelete,
                child: const Icon(Icons.backspace_outlined, size: 22),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
