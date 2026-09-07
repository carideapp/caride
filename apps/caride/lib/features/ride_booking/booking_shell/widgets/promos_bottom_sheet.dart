import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/shared_widgets.dart';
import '../models/promo_model.dart';

class PromosBottomSheet extends StatefulWidget {
  const PromosBottomSheet({
    super.key,
    required this.currentOffer,
    this.selectedPromoId,
  });

  final double currentOffer;
  final String? selectedPromoId;

  static Future<PromoModel?> show(
    BuildContext context, {
    required double currentOffer,
    String? selectedPromoId,
  }) {
    return showModalBottomSheet<PromoModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => PromosBottomSheet(
        currentOffer: currentOffer,
        selectedPromoId: selectedPromoId,
      ),
    );
  }

  @override
  State<PromosBottomSheet> createState() => _PromosBottomSheetState();
}

class _PromosBottomSheetState extends State<PromosBottomSheet> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<int> _getUserPromoUsageCount(String promoCode) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || promoCode.isEmpty) return 0;
    try {
      final snap = await _firestore
          .collection('rides')
          .where('customerUid', isEqualTo: uid)
          .where('promoCode', isEqualTo: promoCode)
          .get();
      return snap.docs.length;
    } catch (e) {
      debugPrint('Error getting promo usage count: $e');
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BottomSheetShell(
      title: 'Select Special Offer',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _firestore
                  .collection('promos')
                  .where('isActive', isEqualTo: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 120,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Text(
                      'Error loading offers: ${snapshot.error}',
                      style: const TextStyle(color: AppColors.error),
                      textAlign: TextAlign.center,
                    ),
                  );
                }

                final docs = snapshot.data?.docs ?? [];
                final promos = docs.map((d) => PromoModel.fromDoc(d)).toList();

                // Remove expired promos locally just in case
                final now = DateTime.now();
                final activePromos = promos.where((p) {
                  if (p.expiryDate != null && p.expiryDate!.isBefore(now)) {
                    return false;
                  }
                  return true;
                }).toList();

                if (activePromos.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: Text(
                      'No special offers available at this time.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  );
                }

                return ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: activePromos.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) {
                      final p = activePromos[i];
                      final isSelected = widget.selectedPromoId == p.id;
                      final qualifies = widget.currentOffer >= p.minFare;

                      return FutureBuilder<int>(
                        future: _getUserPromoUsageCount(p.code),
                        builder: (context, usageSnapshot) {
                          final isLoadingUsage = usageSnapshot.connectionState == ConnectionState.waiting;
                          final usageCount = usageSnapshot.data ?? 0;
                          final reachedLimit = p.usageLimitPerCustomer > 0 && usageCount >= p.usageLimitPerCustomer;
                          final activeAndQualifying = qualifies && !reachedLimit;

                          return InkWell(
                            onTap: activeAndQualifying
                                ? () => Navigator.pop(context, p)
                                : null,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            child: Opacity(
                              opacity: activeAndQualifying ? 1.0 : 0.5,
                              child: GlassContainer(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: activeAndQualifying ? AppColors.brandGlass : (isDark ? Colors.grey[850] : Colors.grey[200]),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.local_offer_outlined,
                                        color: activeAndQualifying ? AppColors.brand : Colors.grey,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            p.code,
                                            style: AppTextStyles.bodyLarge.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            p.discountType == 'percentage'
                                                ? '${p.discountValue}% discount'
                                                : '₦${p.discountValue.toStringAsFixed(0)} discount',
                                            style: AppTextStyles.bodySmall.copyWith(
                                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                            ),
                                          ),
                                          if (!qualifies) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              'Requires min fare of ₦${p.minFare.toStringAsFixed(0)}',
                                              style: const TextStyle(
                                                color: AppColors.error,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                          if (!isLoadingUsage && reachedLimit) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              'Usage limit reached (${p.usageLimitPerCustomer}/${p.usageLimitPerCustomer})',
                                              style: const TextStyle(
                                                color: AppColors.error,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                          if (isLoadingUsage) ...[
                                            const SizedBox(height: 4),
                                            const SizedBox(
                                              width: 10,
                                              height: 10,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 1.5,
                                                color: AppColors.brand,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Icon(
                                      isSelected && activeAndQualifying
                                          ? Icons.radio_button_checked_rounded
                                          : Icons.radio_button_off_rounded,
                                      color: isSelected && activeAndQualifying ? AppColors.brand : Colors.grey,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            if (widget.selectedPromoId != null) ...[
              SecondaryButton(
                label: 'Remove Applied Promo',
                onPressed: () => Navigator.pop(context, PromoModel(
                  id: '',
                  code: '',
                  discountType: 'flat',
                  discountValue: 0,
                  minFare: 0,
                  maxCap: 0,
                  isActive: false,
                )),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
          ],
        ),
      ),
    );
  }
}
