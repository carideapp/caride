import 'package:design_system/design_system.dart';
import 'package:caride/core/driver/models/earnings_model.dart';
import 'package:caride/features/driver/earnings/data/earnings_repository.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/shared_widgets.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:caride/features/driver/earnings/withdrawal/driver_withdraw_bank_details_screen.dart';

/// Redesigned Earnings screen with premium glass-morphic list cards, stat headers, and summaries.
class DriverEarningsScreen extends StatefulWidget {
  const DriverEarningsScreen({super.key});

  @override
  State<DriverEarningsScreen> createState() => _DriverEarningsScreenState();
}

class _DriverEarningsScreenState extends State<DriverEarningsScreen> {
  final _repo = EarningsRepository();


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppScaffold(
      extendBody: true,
      title: 'Earnings',
      body: SafeArea(
        child: ResponsiveContainer(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.pagePadding),
            children: [
              // ── Premium Balance Card ──────────────────────────────
              Container(
                height: 190,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            const Color(0xFF0a3d22),
                            const Color(0xFF16A34A),
                            const Color(0xFF0f6630),
                          ]
                        : [
                            const Color(0xFF0f5132),
                            const Color(0xFF16A34A),
                            const Color(0xFF1db954),
                          ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF16A34A).withValues(alpha: isDark ? 0.25 : 0.40),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
                    children: [
                      // Decorative circles (card pattern)
                      Positioned(
                        right: -30,
                        top: -30,
                        child: Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.07),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 30,
                        bottom: -50,
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                        ),
                      ),
                      Positioned(
                        left: -20,
                        bottom: -40,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.04),
                          ),
                        ),
                      ),
                      // Shine overlay
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.center,
                              colors: [
                                Colors.white.withValues(alpha: 0.10),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Card content
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header row
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(
                                    Icons.account_balance_wallet_rounded,
                                    size: 20,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  'Driver Earnings',
                                  style: AppTextStyles.labelLarge.copyWith(
                                    color: Colors.white.withValues(alpha: 0.85),
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                            const Spacer(),
                            // Balance label
                            Text(
                              'Available Balance',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.white.withValues(alpha: 0.70),
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Balance amount
                            StreamBuilder<double>(
                              stream: _repo.streamWalletBalance(),
                              builder: (context, balSnap) {
                                final bal = balSnap.data ?? 0.0;
                                final formatted = '₦${bal.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
                                return Text(
                                  formatted,
                                  style: AppTextStyles.displaySmall.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                );
                              },
                            ),
                            const Spacer(),
                            // Footer: user name + chip
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    FirebaseAuth.instance.currentUser?.displayName ?? 'Driver',
                                    style: AppTextStyles.titleSmall.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    'ACTIVE',
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: 'Withdraw',
                      icon: Icons.account_balance_wallet_rounded,
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const DriverWithdrawBankDetailsScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),

              // Transaction history Section Header
              Text(
                'Transaction History',
                style: AppTextStyles.headlineMedium.copyWith(
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Past ride earnings history and deposits',
                style: AppTextStyles.bodySmall.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              StreamBuilder<List<EarningsEntry>>(
                stream: _repo.streamEarnings(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: AppLoader());
                  }
                  final entries = snapshot.data ?? [];
                  if (entries.isEmpty) {
                    return const EmptyState(
                      title: 'No earnings yet',
                      message:
                          'Complete rides to start earning. Your earnings will appear here.',
                      icon: Icons.account_balance_wallet_outlined,
                    );
                  }

                  return GlassContainer(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                    child: Column(
                      children: List.generate(entries.length, (index) {
                        final e = entries[index];
                        return _EarningTile(entry: e);
                      }),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppSpacing.massive),
            ],
          ),
        ),
      ),
    );
  }
}

class _EarningTile extends StatelessWidget {
  const _EarningTile({required this.entry});

  final EarningsEntry entry;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.brandGlass,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_downward_rounded,
              color: AppColors.brand,
              size: 16,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.description ?? 'Ride Earnings',
                  style: AppTextStyles.titleMedium.copyWith(
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDate(entry.date),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '+${NgnFormat.whole(entry.amountNaira)}',
            style: AppTextStyles.titleLarge.copyWith(
              color: AppColors.brand,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return 'Today, ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return '${date.day}/${date.month}/${date.year}';
  }
}
