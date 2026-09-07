import 'package:caride/features/profile/data/address_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Redesigned Customer Saved Addresses Screen.
class SavedAddressScreen extends StatelessWidget {
  const SavedAddressScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final repo = AddressRepository();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: GlassAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: 'Saved Addresses',
      ),
      body: SafeArea(
        child: StreamBuilder<List<SavedAddress>>(
          stream: repo.watchAddresses(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: AppLoader());
            }
            final addresses = snapshot.data!;

            return Column(
              children: [
                Expanded(
                  child: addresses.isEmpty
                      ? EmptyState(
                          title: 'No saved addresses yet',
                          message: 'Add locations like Home or Work to book rides faster.',
                          icon: Icons.location_off_outlined,
                          iconWidget: Image.asset(
                            'lib/assets/icons/address.png',
                            width: 96,
                            height: 96,
                            fit: BoxFit.contain,
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.pagePadding,
                            vertical: AppSpacing.lg,
                          ),
                          itemCount: addresses.length,
                          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) {
                            final addr = addresses[index];
                            return _buildAddressCard(context, repo, addr);
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pagePadding,
                    vertical: AppSpacing.md,
                  ),
                  child: PrimaryButton(
                    label: 'Add Address',
                    onPressed: () => context.push(CustomerRoutePaths.addAddress),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAddressCard(BuildContext context, AddressRepository repo, SavedAddress addr) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.brandGlass,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: AppColors.brand,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  addr.label,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  size: 20,
                  color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                onSelected: (value) {
                  if (value == 'edit') {
                    context.push(CustomerRoutePaths.editAddress, extra: {
                      'id': addr.id,
                      'label': addr.label,
                      'address': addr.address,
                      'placeId': addr.placeId,
                      'lat': addr.lat,
                      'lng': addr.lng,
                    });
                  } else if (value == 'delete') {
                    _showDeleteConfirmation(context, repo, addr);
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Delete',
                      style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Divider(height: 1),
          ),
          Text(
            addr.address,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, AddressRepository repo, SavedAddress addr) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => BottomSheetShell(
        title: 'Delete Address',
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Are you sure you want to delete this saved address?',
                textAlign: TextAlign.center,
                style: AppTextStyles.titleMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              GlassContainer(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: AppColors.brand,
                          size: 20,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          addr.label,
                          style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      addr.address,
                      style: AppTextStyles.bodyMedium,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: 'Cancel',
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Yes, Delete',
                      backgroundColor: AppColors.error,
                      onPressed: () async {
                        Navigator.of(ctx).pop();
                        try {
                          await repo.deleteAddress(addr.id);
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Address deleted successfully.')),
                          );
                        } catch (_) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to delete address.')),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
