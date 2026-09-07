import 'package:caride/features/chat/data/chat_repository.dart';
import 'package:caride/features/profile/data/driver_public_profile_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:design_system/design_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Redesigned Customer Conversation Screen utilizing GlassAppBar, GlassContainer, and custom speech bubbles.
class ConversationScreen extends StatefulWidget {
  const ConversationScreen({
    super.key,
    required this.driverName,
    required this.rideId,
    this.driverUid,
  });

  final String driverName;
  final String rideId;
  final String? driverUid;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ChatRepository _repository = ChatRepository();
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _repository.markAsRead(widget.rideId);
  }

  Stream<String> _getDriverUidStream() {
    if (widget.driverUid != null && widget.driverUid!.isNotEmpty) {
      return Stream.value(widget.driverUid!);
    }
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    return FirebaseFirestore.instance
        .collection('rideMessages')
        .doc(widget.rideId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return '';
          final data = doc.data() ?? {};
          final participantUids = List<String>.from(data['participantUids'] ?? []);
          return participantUids.firstWhere((id) => id != currentUid, orElse: () => '');
        });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    final message = _messageController.text.trim();
    if (message.isEmpty) return;
    setState(() => _sending = true);
    await _repository.sendMessage(rideId: widget.rideId, text: message);
    if (!mounted) return;
    _messageController.clear();
    setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final driverProfileRepo = DriverPublicProfileRepository();

    return StreamBuilder<String>(
      stream: _getDriverUidStream(),
      builder: (context, uidSnap) {
        final driverUid = uidSnap.data ?? widget.driverUid ?? '';
        return StreamBuilder<DriverPublicProfile?>(
          stream: driverUid.isEmpty
              ? Stream.value(null)
              : driverProfileRepo.watchDriver(driverUid),
          builder: (context, profileSnap) {
            final profile = profileSnap.data;
            final photoUrl = profile?.profilePhotoUrl ?? '';
            final name = (profile?.fullName.trim().isNotEmpty ?? false)
                ? profile!.fullName
                : widget.driverName;

            return Scaffold(
              backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
              appBar: GlassAppBar(
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                title: name,
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: AppSpacing.md),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: isDark ? AppColors.darkSurfaceVariant : const Color(0xFFF1F5F9),
                      backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      child: photoUrl.isEmpty
                          ? Text(
                              name.isNotEmpty ? name.substring(0, 1) : '?',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                  ),
                ],
              ),
              body: SafeArea(
                child: Column(
                  children: [
                    Expanded(
                      child: StreamBuilder<List<ChatMessage>>(
                        stream: _repository.watchMessages(widget.rideId),
                        builder: (context, snapshot) {
                          if (snapshot.hasError) {
                            return Center(
                              child: Text(
                                'Unable to load messages.',
                                style: AppTextStyles.bodyLarge,
                              ),
                            );
                          }
                          if (!snapshot.hasData) {
                            return const Center(child: AppLoader());
                          }

                          final messages = snapshot.data!;
                          if (messages.isEmpty) {
                            return Center(
                              child: Text(
                                'No messages yet. Say hello to your driver.',
                                style: AppTextStyles.bodyLarge.copyWith(
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                              ),
                            );
                          }

                          return ListView.separated(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.pagePadding,
                              vertical: AppSpacing.md,
                            ),
                            itemCount: messages.length,
                            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                            itemBuilder: (context, index) {
                              final message = messages[index];
                              return _Bubble(
                                text: message.text,
                                time: _formatMessageTime(message.createdAt),
                                isMe: message.senderUid == currentUid,
                              );
                            },
                          );
                        },
                      ),
                    ),
                    GlassContainer(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      child: Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: _messageController,
                              hint: 'Send a message...',
                              obscureText: false,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _send(),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          GlassIconButton(
                            icon: Icons.send_rounded,
                            onPressed: _sending ? null : _send,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

String _formatMessageTime(DateTime timestamp) {
  final hh = timestamp.hour.toString().padLeft(2, '0');
  final mm = timestamp.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.time, this.isMe = false});

  final String text;
  final String time;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final align = isMe ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor = isMe
        ? AppColors.brand
        : (isDark ? AppColors.darkSurface : Colors.white);
    final borderColor = isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight;
    final textColor = isMe ? Colors.white : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight);
    final timeColor = isMe ? Colors.white.withValues(alpha: 0.72) : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight);

    return Align(
      alignment: align,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 300),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: bubbleColor,
            border: isMe ? null : Border.all(color: borderColor),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(AppRadius.lg),
              topRight: const Radius.circular(AppRadius.lg),
              bottomLeft: Radius.circular(isMe ? AppRadius.lg : AppRadius.sm),
              bottomRight: Radius.circular(isMe ? AppRadius.sm : AppRadius.lg),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                style: AppTextStyles.bodyLarge.copyWith(
                  color: textColor,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  time,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: timeColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
