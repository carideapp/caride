import 'dart:async';

import 'package:caride/features/ride_booking/data/ride_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Redesigned Customer Legacy Select Driver Screen.
class SelectDriverScreen extends StatefulWidget {
  const SelectDriverScreen({super.key, this.params});

  final Map<String, dynamic>? params;

  @override
  State<SelectDriverScreen> createState() => _SelectDriverScreenState();
}

class _SelectDriverScreenState extends State<SelectDriverScreen>
    with SingleTickerProviderStateMixin {
  final RideRepository _rideRepo = RideRepository();
  late final AnimationController _waveController;
  late final Stream<List<DriverBid>> _bidsStream;
  bool _acceptLoading = false;

  String get _rideId => widget.params?['rideId'] as String? ?? '';

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
    if (_rideId.isNotEmpty) {
      _bidsStream = _rideRepo.watchBids(_rideId);
    } else {
      _bidsStream = const Stream.empty();
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _showCancelSheet() async {
    final shouldCancel = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return BottomSheetShell(
          title: 'Cancel request?',
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Are you sure you want to cancel your search? You will be returned to the home screen.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.lg),
              PrimaryButton(
                label: 'Keep searching',
                onPressed: () => Navigator.of(context).pop(false),
              ),
              const SizedBox(height: AppSpacing.sm),
              SecondaryButton(
                label: 'Cancel request',
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
        );
      },
    );
    if (shouldCancel == true && mounted) {
      if (_rideId.isNotEmpty) {
        await _rideRepo.cancelRide(_rideId, reason: 'Cancelled by user while searching');
      }
      if (mounted) context.go(CustomerRoutePaths.home);
    }
  }

  Future<void> _showRideAcceptedPopup() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: GlassSurface(
            radius: AppRadius.xl,
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'lib/assets/emoji/happy_face.png',
                  width: 96,
                  height: 96,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Ride request accepted!',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: AppColors.brand,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Your driver is confirmed. You can now monitor your trip.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: 'View My Ride',
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    context.push(CustomerRoutePaths.rideTrack, extra: {'rideId': _rideId});
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _declineBid(String bidId) {
    if (_rideId.isEmpty) return;
    _rideRepo.declineBid(rideId: _rideId, bidId: bidId);
  }

  Future<void> _acceptBid(DriverBid bid) async {
    if (_rideId.isEmpty || _acceptLoading) return;
    setState(() => _acceptLoading = true);
    try {
      await _rideRepo.acceptBid(rideId: _rideId, bid: bid);
      if (!mounted) return;
      _showRideAcceptedPopup();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not accept bid: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _acceptLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_rideId.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Invalid ride ID')),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: GlassAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: _showCancelSheet,
        ),
        title: 'Choose a driver',
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pagePadding,
              vertical: AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: StreamBuilder<List<DriverBid>>(
                    stream: _bidsStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return const Center(child: Text('Error loading bids'));
                      }
                      if (!snapshot.hasData) {
                        return _SearchingView(controller: _waveController);
                      }
                      
                      final bids = snapshot.data!
                          .where((b) => !b.isExpired)
                          .toList(growable: false);

                      if (bids.isEmpty) {
                        return _SearchingView(controller: _waveController);
                      }

                      return ListView.separated(
                        itemCount: bids.length,
                        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                        itemBuilder: (context, index) {
                          final offer = bids[index];
                          return _DriverOfferCard(
                            offer: offer,
                            onAccept: () => _acceptBid(offer),
                            onDecline: () => _declineBid(offer.id),
                            onExpired: () {},
                          );
                        },
                      );
                    },
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

class _SearchingView extends StatelessWidget {
  const _SearchingView({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final t = controller.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              _WaveCircle(scale: 0.9 + t * 1.8, opacity: (1 - t) * 0.30),
              _WaveCircle(
                scale: 0.6 + ((t + 0.33) % 1.0) * 1.8,
                opacity: (1 - ((t + 0.33) % 1.0)) * 0.24,
              ),
              _WaveCircle(
                scale: 0.3 + ((t + 0.66) % 1.0) * 1.8,
                opacity: (1 - ((t + 0.66) % 1.0)) * 0.18,
              ),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppColors.brandGlass,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_searching_rounded,
                  size: 34,
                  color: AppColors.brand,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _WaveCircle extends StatelessWidget {
  const _WaveCircle({
    required this.scale,
    required this.opacity,
  });

  final double scale;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.brand.withValues(alpha: opacity),
            width: 2,
          ),
        ),
      ),
    );
  }
}

class _DriverOfferCard extends StatefulWidget {
  const _DriverOfferCard({
    required this.offer,
    required this.onAccept,
    required this.onDecline,
    required this.onExpired,
  });

  final DriverBid offer;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final VoidCallback onExpired;

  @override
  State<_DriverOfferCard> createState() => _DriverOfferCardState();
}

class _DriverOfferCardState extends State<_DriverOfferCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _timerController;
  bool _accepted = false;

  @override
  void initState() {
    super.initState();
    final remainingSeconds = widget.offer.expiresAt.difference(DateTime.now()).inSeconds;
    final totalSeconds = 30;
    final initialValue = 1.0 - (remainingSeconds / totalSeconds).clamp(0.0, 1.0);
    
    _timerController = AnimationController(
      vsync: this,
      duration: Duration(seconds: remainingSeconds > 0 ? remainingSeconds : 1),
      value: initialValue,
    )
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          widget.onExpired();
        }
      })
      ..forward();
  }

  @override
  void dispose() {
    _timerController.dispose();
    super.dispose();
  }

  void _accept() {
    if (_accepted) return;
    setState(() => _accepted = true);
    widget.onAccept();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                '₦${widget.offer.offerNaira.toStringAsFixed(0)}  ${widget.offer.etaMinutes} min',
                style: AppTextStyles.headlineMedium.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF1F5F9),
                child: Text(
                  widget.offer.driverName.isNotEmpty ? widget.offer.driverName.characters.first : 'D',
                  style: AppTextStyles.titleMedium,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  '${widget.offer.driverName} ★${widget.offer.driverRating.toStringAsFixed(1)} ${widget.offer.driverRides} rides\n${widget.offer.vehicleName}',
                  style: AppTextStyles.bodyLarge,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'Decline',
                  onPressed: widget.onDecline,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: GestureDetector(
                  onTap: _accept,
                  child: Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: AppColors.brandGlass,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      child: Stack(
                        children: [
                          AnimatedBuilder(
                            animation: _timerController,
                            builder: (context, _) {
                              final remaining = 1 - _timerController.value;
                              return Align(
                                alignment: Alignment.centerRight,
                                child: FractionallySizedBox(
                                  widthFactor: remaining,
                                  child: Container(
                                    color: AppColors.brand.withValues(alpha: 0.3),
                                  ),
                                ),
                              );
                            },
                          ),
                          Center(
                            child: Text(
                              _accepted ? 'Accepted' : 'Accept',
                              style: AppTextStyles.titleMedium.copyWith(
                                color: AppColors.brand,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
