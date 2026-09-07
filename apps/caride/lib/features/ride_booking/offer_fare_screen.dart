import 'package:caride/features/ride_booking/data/ride_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Redesigned Customer Offer Fare Screen.
class OfferFareScreen extends StatefulWidget {
  const OfferFareScreen({super.key, this.params});

  /// Expected keys: rideType, priceMin, priceMax, priceSuggested,
  /// pickupLabel, pickupLat, pickupLng, dropoffLabel, dropoffLat, dropoffLng.
  final Map<String, dynamic>? params;

  @override
  State<OfferFareScreen> createState() => _OfferFareScreenState();
}

class _OfferFareScreenState extends State<OfferFareScreen> {
  final RideRepository _rideRepo = RideRepository();

  late double _price;
  late double _priceMin;
  late double _priceMax;
  String _paymentMethod = 'wallet';
  String _paymentMethodLabel = 'CaRide Wallet';
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final p = widget.params ?? {};
    _priceMin = ((p['priceMin'] as num?)?.toDouble() ?? 2000);
    _priceMin = ((_priceMin / 100).round() * 100).toDouble();
    _priceMax = ((p['priceMax'] as num?)?.toDouble() ?? 8000);
    _priceMax = ((_priceMax / 100).round() * 100).toDouble();
    _price = ((p['priceSuggested'] as num?)?.toDouble() ?? _priceMin);
    _price = ((_price / 100).round() * 100).toDouble();
    _price = _price.clamp(_priceMin, _priceMax);
  }

  String get _rideType =>
      (widget.params?['rideType'] as String?) ?? 'Regular';
  String get _pickupLabel =>
      (widget.params?['pickupLabel'] as String?) ?? '';
  double get _pickupLat =>
      (widget.params?['pickupLat'] as num?)?.toDouble() ?? 0.0;
  double get _pickupLng =>
      (widget.params?['pickupLng'] as num?)?.toDouble() ?? 0.0;
  String get _dropoffLabel =>
      (widget.params?['dropoffLabel'] as String?) ?? '';
  double get _dropoffLat =>
      (widget.params?['dropoffLat'] as num?)?.toDouble() ?? 0.0;
  double get _dropoffLng =>
      (widget.params?['dropoffLng'] as num?)?.toDouble() ?? 0.0;

  Future<void> _findDriver() async {
    if (_submitting) return;
    setState(() => _submitting = true);
    try {
      final rideId = await _rideRepo.createRideRequest(
        pickupLabel: _pickupLabel,
        pickupLat: _pickupLat,
        pickupLng: _pickupLng,
        dropoffLabel: _dropoffLabel,
        dropoffLat: _dropoffLat,
        dropoffLng: _dropoffLng,
        rideType: _rideType,
        customerOffer: _price,
        paymentMethod: _paymentMethod,
      );
      if (!mounted) return;
      context.push(
        CustomerRoutePaths.selectDriver,
        extra: {'rideId': rideId},
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not create ride: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _selectPaymentMethod() {
    final methods = [
      ('wallet', 'CaRide Wallet', Icons.account_balance_wallet_outlined),
      ('card', 'Card', Icons.credit_card_rounded),
    ];

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return BottomSheetShell(
          title: 'Select Payment Method',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: methods.map((m) {
              return Material(
                color: Colors.transparent,
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.brandGlass,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(m.$3, color: AppColors.brand, size: 20),
                  ),
                  title: Text(
                    m.$2,
                    style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
                  ),
                  trailing: _paymentMethod == m.$1
                      ? const Icon(Icons.check_circle_rounded, color: AppColors.brand)
                      : null,
                  onTap: () {
                    setState(() {
                      _paymentMethod = m.$1;
                      _paymentMethodLabel = m.$2;
                    });
                    Navigator.of(ctx).pop();
                  },
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final divisions = ((_priceMax - _priceMin) / 50).round().clamp(1, 100);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: GlassAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: 'Offer your fare',
        actions: [
          Container(
            margin: const EdgeInsets.only(right: AppSpacing.sm),
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm, vertical: AppSpacing.xxs),
            decoration: BoxDecoration(
              color: AppColors.brandGlass,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Center(
              child: Text(
                _rideType,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.brand,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pagePadding,
              vertical: AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GlassContainer(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Your offer',
                            style: AppTextStyles.titleMedium.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '₦${_price.toStringAsFixed(0)}',
                            style: AppTextStyles.titleLarge.copyWith(
                              color: AppColors.brand,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Slider(
                        value: _price,
                        min: _priceMin,
                        max: _priceMax,
                        divisions: divisions,
                        label: '₦${_price.toStringAsFixed(0)}',
                        activeColor: AppColors.brand,
                        inactiveColor: isDark ? Colors.grey[800] : const Color(0xFFE2E8F0),
                        onChanged: (v) => setState(() => _price = ((v / 100).round() * 100).toDouble()),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '₦${_priceMin.toStringAsFixed(0)}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '₦${_priceMax.toStringAsFixed(0)}',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Center(
                        child: Text(
                          'Drag to set your offer — drivers will respond',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                _SurfaceRowTile(
                  icon: Icons.payments_outlined,
                  title: _paymentMethodLabel,
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                  ),
                  onTap: _selectPaymentMethod,
                ),
                const SizedBox(height: AppSpacing.sm),

                if (_pickupLabel.isNotEmpty)
                  _SurfaceRowTile(
                    icon: Icons.circle_outlined,
                    iconColor: AppColors.brand,
                    overline: 'From',
                    title: _pickupLabel,
                    trailing: const SizedBox.shrink(),
                  ),
                if (_pickupLabel.isNotEmpty)
                  const SizedBox(height: AppSpacing.sm),

                if (_dropoffLabel.isNotEmpty)
                  _SurfaceRowTile(
                    icon: Icons.location_on_rounded,
                    iconColor: AppColors.error,
                    overline: 'To',
                    title: _dropoffLabel,
                    trailing: const SizedBox.shrink(),
                  ),

                const SizedBox(height: AppSpacing.xl),
                PrimaryButton(
                  label: _submitting ? 'Finding drivers...' : 'Find a driver',
                  onPressed: _submitting ? null : _findDriver,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SurfaceRowTile extends StatelessWidget {
  const _SurfaceRowTile({
    required this.icon,
    this.overline,
    required this.title,
    required this.trailing,
    this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String? overline;
  final String title;
  final Widget trailing;
  final VoidCallback? onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: GlassContainer(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: (iconColor ?? AppColors.brand).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor ?? AppColors.brand, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (overline != null)
                      Text(
                        overline!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      title,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
        ),
      ),
    );
  }
}
