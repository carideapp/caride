import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:design_system/design_system.dart';
import 'package:caride/core/driver/auth/driver_auth_controller.dart';
import 'package:caride/features/driver/chat/data/driver_chat_repository.dart';
import 'package:caride/core/driver/widgets/customer_avatar.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Redesigned Conversation Screen with GlassAppBar, GlassContainer bubbles, and tactical text field inputs.
class DriverConversationScreen extends StatefulWidget {
  const DriverConversationScreen({
    super.key,
    required this.customerName,
    this.rideId,
  });

  final String customerName;
  final String? rideId;

  @override
  State<DriverConversationScreen> createState() =>
      _DriverConversationScreenState();
}

class _DriverConversationScreenState extends State<DriverConversationScreen> {
  final _repo = DriverChatRepository();
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  String get _rideId => widget.rideId ?? '';

  @override
  void initState() {
    super.initState();
    if (_rideId.isNotEmpty) {
      _repo.markAsRead(_rideId);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _textController.text.trim();
    if (text.isEmpty || _rideId.isEmpty) return;
    setState(() => _sending = true);
    try {
      await _repo.sendMessage(rideId: _rideId, text: text);
      _textController.clear();
      _scrollToBottom();
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final myUid = driverAuthController.currentUid ?? '';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: GlassAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: widget.customerName,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
              future: _rideId.isEmpty
                  ? Future<DocumentSnapshot<Map<String, dynamic>>?>.value(null)
                  : FirebaseFirestore.instance.collection('rides').doc(_rideId).get(),
              builder: (context, rideSnap) {
                final customerUid = rideSnap.data?.data()?['customerUid'] as String? ?? '';
                return CustomerAvatar(
                  customerUid: customerUid,
                  fallbackLetter: widget.customerName,
                  radius: 18,
                );
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: _rideId.isEmpty
                  ? const Center(
                      child: EmptyState(
                        title: 'No active ride',
                        message: 'Accept a ride to start chatting.',
                        icon: Icons.chat_bubble_outline,
                      ),
                    )
                  : StreamBuilder<List<DriverChatMessage>>(
                      stream: _repo.watchMessages(_rideId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(child: AppLoader());
                        }
                        final msgs = snapshot.data ?? [];
                        if (msgs.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(AppSpacing.md),
                                  decoration: BoxDecoration(
                                    color: AppColors.brandGlass,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: AppColors.brandGlassBorder),
                                  ),
                                  child: const Icon(
                                    Icons.chat_bubble_outline_rounded,
                                    size: 32,
                                    color: AppColors.brand,
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  'Say hello to ${widget.customerName}!',
                                  style: AppTextStyles.titleMedium.copyWith(
                                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        WidgetsBinding.instance.addPostFrameCallback(
                          (_) => _scrollToBottom(),
                        );
                        return ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.pagePadding,
                            vertical: AppSpacing.md,
                          ),
                          itemCount: msgs.length,
                          itemBuilder: (_, i) {
                            final msg = msgs[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: AppSpacing.md),
                              child: _Bubble(
                                text: msg.text,
                                time: _formatTime(msg.createdAt),
                                isMe: msg.senderUid == myUid,
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
            // Input Bar
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.darkSurface.withValues(alpha: 0.9)
                    : AppColors.lightSurface.withValues(alpha: 0.95),
                border: Border(
                  top: BorderSide(
                    color: isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight,
                    width: AppGlass.borderThin,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _textController,
                      hint: 'Send a message...',
                      obscureText: false,
                      maxLines: 5,
                      minLines: 1,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  GlassIconButton(
                    icon: Icons.send_rounded,
                    color: AppColors.brand,
                    onPressed: _sending ? null : _send,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.text,
    required this.time,
    this.isMe = false,
  });

  final String text;
  final String time;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final align = isMe ? Alignment.centerRight : Alignment.centerLeft;
    final bubbleColor =
        isMe ? AppColors.brandGlass : (isDark ? AppColors.darkSurfaceRaised : AppColors.lightSurfaceRaised);
    final textColor = isMe ? (isDark ? Colors.white : AppColors.brandDark) : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight);
    final timeColor = isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight;
    final border = isMe ? AppColors.brandGlassBorder : (isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight);

    return Align(
      alignment: align,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: bubbleColor,
            border: Border.all(color: border, width: AppGlass.borderThin),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(AppRadius.lg),
              topRight: const Radius.circular(AppRadius.lg),
              bottomLeft:
                  Radius.circular(isMe ? AppRadius.lg : AppRadius.sm),
              bottomRight:
                  Radius.circular(isMe ? AppRadius.sm : AppRadius.lg),
            ),
            boxShadow: isMe ? null : (isDark ? AppShadows.cardDark : AppShadows.cardLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                text,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: textColor,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  time,
                  style: AppTextStyles.caption.copyWith(
                    color: timeColor,
                    fontSize: 9,
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
