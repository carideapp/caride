import 'package:caride/features/chat/conversation_screen.dart';
import 'package:caride/features/chat/data/chat_repository.dart';
import 'package:caride/features/profile/data/driver_public_profile_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Redesigned Customer Chat List Screen with GlassAppBar and GlassContainers.
class ChatScreen extends StatelessWidget {
  const ChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final repository = ChatRepository();
    final driverProfileRepo = DriverPublicProfileRepository();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: GlassAppBar(
        automaticallyImplyLeading: false,
        title: 'Chats',
      ),
      body: StreamBuilder<List<ChatThread>>(
        stream: repository.watchThreads(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Unable to load chats right now.',
                style: AppTextStyles.bodyLarge,
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: AppLoader());
          }

          final chats = snapshot.data!;
          if (chats.isEmpty) {
            return EmptyState(
              title: 'No chats yet',
              message: 'Start a ride to message a driver.',
              icon: Icons.forum_outlined,
              iconWidget: Image.asset(
                'lib/assets/icons/chat.png',
                width: 96,
                height: 96,
                fit: BoxFit.contain,
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pagePadding,
              vertical: AppSpacing.md,
            ),
            itemCount: chats.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final thread = chats[index];
              return StreamBuilder<DriverPublicProfile?>(
                stream: thread.driverUid.isEmpty
                    ? Stream.value(null)
                    : driverProfileRepo.watchDriver(thread.driverUid),
                builder: (context, profileSnap) {
                  final profile = profileSnap.data;
                  final photoUrl = profile?.profilePhotoUrl ?? '';
                  final name = (profile?.fullName.trim().isNotEmpty ?? false)
                      ? profile!.fullName
                      : thread.name;

                  return GlassContainer(
                    padding: EdgeInsets.zero,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      onTap: () {
                        Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute(
                            builder: (_) => ConversationScreen(
                              rideId: thread.rideId,
                              driverName: name,
                              driverUid: thread.driverUid,
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: isDark ? AppColors.darkSurfaceVariant : const Color(0xFFF1F5F9),
                              backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                              child: photoUrl.isEmpty
                                  ? Text(
                                      name.isNotEmpty ? name.substring(0, 1) : '?',
                                      style: AppTextStyles.titleMedium.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: AppTextStyles.titleMedium.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    thread.preview,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  _formatTimestamp(thread.timestamp),
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (thread.unread > 0) ...[
                                  const SizedBox(height: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.brand,
                                      borderRadius: BorderRadius.circular(
                                        AppRadius.md,
                                      ),
                                    ),
                                    child: Text(
                                      '${thread.unread}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

String _formatTimestamp(DateTime timestamp) {
  if (timestamp == DateTime.fromMillisecondsSinceEpoch(0)) {
    return '';
  }
  final hh = timestamp.hour.toString().padLeft(2, '0');
  final mm = timestamp.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}
