import 'package:caride/features/profile/data/trusted_contacts_repository.dart';
import 'package:caride/features/profile/trusted_contact_form_screen.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Screen that lists all saved trusted contacts for the current passenger.
class TrustedContactsScreen extends StatelessWidget {
  const TrustedContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final repo = TrustedContactsRepository();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: GlassAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: 'Trusted Contacts',
      ),
      body: SafeArea(
        child: StreamBuilder<List<TrustedContact>>(
          stream: repo.watchContacts(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: AppLoader());
            }
            final contacts = snapshot.data ?? [];

            if (contacts.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.pagePadding),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: AppColors.brand.withValues(alpha: 0.10),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.people_outline_rounded,
                          color: AppColors.brand,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'No trusted contacts yet',
                        style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Add someone you trust so CaRide can notify them if you need help during a trip.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      PrimaryButton(
                        label: 'Add Trusted Contact',
                        icon: Icons.person_add_rounded,
                        onPressed: () => TrustedContactFormScreen.showSheet(context),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pagePadding, AppSpacing.md, AppSpacing.pagePadding, 0),
                  child: GlassContainer(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            color: AppColors.brand, size: 18),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            'Trusted contacts receive email alerts when you trigger an emergency during a trip.',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : AppColors.textSecondaryLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.pagePadding),
                    itemCount: contacts.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.sm),
                    itemBuilder: (context, i) {
                      final contact = contacts[i];
                      return _ContactTile(
                        contact: contact,
                        repo: repo,
                        isDark: isDark,
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pagePadding, 0, AppSpacing.pagePadding, AppSpacing.md),
                  child: PrimaryButton(
                    label: 'Add Another Contact',
                    icon: Icons.person_add_rounded,
                    onPressed: () => TrustedContactFormScreen.showSheet(context),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({
    required this.contact,
    required this.repo,
    required this.isDark,
  });

  final TrustedContact contact;
  final TrustedContactsRepository repo;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: (contact.isActive ? AppColors.brand : Colors.grey)
                  .withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.person_rounded,
              color: contact.isActive ? AppColors.brand : Colors.grey,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        contact.name,
                        style: AppTextStyles.bodyLarge
                            .copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (!contact.isActive)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey.withValues(alpha: 0.2),
                          borderRadius:
                              BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Text(
                          'Inactive',
                          style: AppTextStyles.caption
                              .copyWith(color: Colors.grey),
                        ),
                      ),
                  ],
                ),
                if (contact.email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(Icons.email_outlined,
                          size: 12,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          contact.email,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
                if (contact.relationship.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    contact.relationship,
                    style: AppTextStyles.caption.copyWith(
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiaryLight,
                    ),
                  ),
                ],
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded, size: 20),
            onSelected: (value) async {
              switch (value) {
                case 'edit':
                  TrustedContactFormScreen.showSheet(context, existing: contact);
                case 'toggle':
                  await repo.toggleActive(contact.id,
                      isActive: !contact.isActive);
                case 'delete':
                  _confirmDelete(context, contact, repo);
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'edit',
                child: const Row(children: [
                  Icon(Icons.edit_rounded, size: 18),
                  SizedBox(width: 8),
                  Text('Edit'),
                ]),
              ),
              PopupMenuItem(
                value: 'toggle',
                child: Row(children: [
                  Icon(
                    contact.isActive
                        ? Icons.toggle_off_rounded
                        : Icons.toggle_on_rounded,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(contact.isActive ? 'Deactivate' : 'Activate'),
                ]),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(children: [
                  Icon(Icons.delete_outline_rounded,
                      size: 18, color: AppColors.error),
                  SizedBox(width: 8),
                  Text('Delete',
                      style: TextStyle(color: AppColors.error)),
                ]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, TrustedContact contact,
      TrustedContactsRepository repo) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: GlassSurface(
          radius: AppRadius.lg,
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Remove Contact?',
                  style: AppTextStyles.titleLarge
                      .copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: AppSpacing.sm),
              Text(
                '${contact.name} will be removed from your trusted contacts.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(
                      label: 'Cancel',
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Remove',
                      backgroundColor: AppColors.error,
                      onPressed: () async {
                        Navigator.pop(context);
                        await repo.deleteContact(contact.id);
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
