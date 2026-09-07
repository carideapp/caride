import 'package:design_system/design_system.dart';
import 'package:caride/features/driver/chat/data/driver_chat_repository.dart';
import 'package:caride/core/driver/widgets/customer_avatar.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Redesigned Messages List Screen with GlassContainers and AppScaffold.
class DriverChatScreen extends StatelessWidget {
  const DriverChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final repo = DriverChatRepository();

    return AppScaffold(
      extendBody: true,
      title: 'Messages',
      body: SafeArea(
        child: StreamBuilder<List<DriverChatThread>>(
          stream: repo.watchThreads(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: AppLoader());
            }
            final threads = snapshot.data ?? [];
            if (threads.isEmpty) {
              return Center(
                child: EmptyState(
                  title: 'No messages yet',
                  message:
                      'Your chats with customers during rides will appear here.',
                  icon: Icons.chat_bubble_outline_rounded,
                  iconWidget: Image.asset(
                    'lib/assets/icons/chat.png',
                    width: 96,
                    height: 96,
                    fit: BoxFit.contain,
                  ),
                ),
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.pagePadding),
              itemCount: threads.length,
              separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
              itemBuilder: (context, i) {
                final thread = threads[i];

                return AppCard(
                  onTap: () => context.push(
                    DriverRoutePaths.conversation,
                    extra: {
                      'rideId': thread.rideId,
                      'customerName': thread.customerName,
                    },
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                  child: Row(
                    children: [
                      CustomerAvatar(
                        customerUid: thread.customerUid,
                        fallbackLetter: thread.customerName,
                        radius: 24,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              thread.customerName,
                              style: AppTextStyles.titleMedium.copyWith(
                                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              thread.preview,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      if (thread.unread > 0)
                        Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: AppColors.brand,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${thread.unread}',
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else
                        Icon(
                          Icons.chevron_right_rounded,
                          color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                          size: 20,
                        ),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
