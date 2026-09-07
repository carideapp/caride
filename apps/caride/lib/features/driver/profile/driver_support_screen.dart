import 'dart:io';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

import 'package:caride/core/driver/auth/driver_auth_controller.dart';
import 'package:caride/core/driver/models/driver_support_chat.dart';
import 'package:caride/core/driver/models/driver_support_message.dart';
import 'package:caride/features/driver/auth/data/driver_profile_repository.dart';
import 'package:caride/features/driver/profile/data/driver_support_repository.dart';

/// Driver Support Chat list and detail session matching Customer Support UI & UX with image attachment support.
class DriverSupportScreen extends StatefulWidget {
  const DriverSupportScreen({super.key});

  @override
  State<DriverSupportScreen> createState() => _DriverSupportScreenState();
}

class _DriverSupportScreenState extends State<DriverSupportScreen> {
  final _profileRepo = DriverProfileRepository();
  final _supportRepo = DriverSupportRepository();
  final TextEditingController _messageController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  String? _selectedChatId;
  bool _isSending = false;
  File? _pendingImage;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1200,
      );
      if (picked != null && mounted) {
        setState(() => _pendingImage = File(picked.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick image: $e')),
        );
      }
    }
  }

  Future<void> _showNewChatDialog({
    required String driverUid,
    required String driverName,
    required String driverEmail,
  }) async {
    final subjectController = TextEditingController();
    final issueController = TextEditingController();
    String? errorText;
    bool isSubmitting = false;
    File? dialogImage;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> pickDialogImage() async {
              try {
                final XFile? picked = await _picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 80,
                  maxWidth: 1200,
                );
                if (picked != null) {
                  setDialogState(() => dialogImage = File(picked.path));
                }
              } catch (_) {}
            }

            Future<void> submit() async {
              final subject = subjectController.text.trim();
              final message = issueController.text.trim();
              if (subject.isEmpty || (message.isEmpty && dialogImage == null)) {
                setDialogState(() => errorText = 'Subject and message (or image) are required.');
                return;
              }

              setDialogState(() {
                isSubmitting = true;
                errorText = null;
              });
              try {
                String? uploadedImageUrl;
                final tempDocRefId = DateTime.now().millisecondsSinceEpoch.toString();
                if (dialogImage != null) {
                  uploadedImageUrl = await _supportRepo.uploadChatImage(dialogImage!, tempDocRefId);
                }

                final chatId = await _supportRepo.createChat(
                  driverUid: driverUid,
                  driverName: driverName,
                  driverEmail: driverEmail,
                  subject: subject,
                  initialMessage: message,
                  initialImageUrl: uploadedImageUrl,
                );

                if (!mounted || !dialogContext.mounted) return;
                setState(() => _selectedChatId = chatId);
                Navigator.of(dialogContext).pop();
              } catch (_) {
                if (!dialogContext.mounted) return;
                setDialogState(() {
                  errorText = 'Unable to start a support chat right now.';
                  isSubmitting = false;
                });
              }
            }

            return AlertDialog(
              backgroundColor: Colors.transparent,
              contentPadding: EdgeInsets.zero,
              content: GlassSurface(
                radius: AppRadius.lg,
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Start a support chat',
                        style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Our support team is here to help. Describe your issue and attach a screenshot if helpful.',
                        style: AppTextStyles.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppTextField(
                        controller: subjectController,
                        hint: 'Subject (e.g., Withdrawal issue)',
                        obscureText: false,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppTextField(
                        controller: issueController,
                        hint: 'Message / Issue detail',
                        obscureText: false,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                      const SizedBox(height: AppSpacing.sm),

                      if (dialogImage != null)
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              child: Image.file(
                                dialogImage!,
                                height: 100,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => setDialogState(() => dialogImage = null),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close_rounded, color: Colors.white, size: 16),
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        OutlinedButton.icon(
                          onPressed: pickDialogImage,
                          icon: const Icon(Icons.image_rounded, size: 18),
                          label: const Text('Attach Screenshot / Image'),
                          style: OutlinedButton.styleFrom(
                            side: BorderSide(color: AppColors.brand.withValues(alpha: 0.5)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                          ),
                        ),

                      if (errorText != null) ...[
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          errorText!,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      Row(
                        children: [
                          Expanded(
                            child: SecondaryButton(
                              label: 'Cancel',
                              onPressed: () => Navigator.of(dialogContext).pop(),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: PrimaryButton(
                              label: 'Submit',
                              isLoading: isSubmitting,
                              onPressed: submit,
                            ),
                          ),
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
  }

  Future<void> _sendMessage(String driverUid) async {
    final chatId = _selectedChatId;
    if (chatId == null) return;
    final text = _messageController.text.trim();
    if (text.isEmpty && _pendingImage == null) return;

    final imageToSend = _pendingImage;
    _messageController.clear();
    setState(() {
      _pendingImage = null;
      _isSending = true;
    });

    try {
      String? imageUrl;
      if (imageToSend != null) {
        imageUrl = await _supportRepo.uploadChatImage(imageToSend, chatId);
      }
      await _supportRepo.sendDriverMessage(
        chatId: chatId,
        driverUid: driverUid,
        text: text,
        imageUrl: imageUrl,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  void _viewImageFullScreen(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(AppSpacing.md),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final uid = driverAuthController.currentUid;
    if (uid == null) {
      return const Scaffold(body: Center(child: AppLoader()));
    }

    return StreamBuilder(
      stream: _profileRepo.streamDriverProfile(uid),
      builder: (context, profileSnap) {
        final profile = profileSnap.data;
        final driverName = profile?.fullName.isNotEmpty == true
            ? profile!.fullName
            : 'Driver';
        final driverEmail = profile?.email ?? driverAuthController.currentEmail ?? '';

        return Scaffold(
          backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
          appBar: GlassAppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () {
                if (_selectedChatId != null) {
                  setState(() => _selectedChatId = null);
                } else {
                  context.pop();
                }
              },
            ),
            title: _selectedChatId == null ? 'Driver Support' : 'Support Chat',
          ),
          body: SafeArea(
            child: ResponsiveContainer(
              child: _selectedChatId == null
                  ? _buildChatsList(uid, driverName, driverEmail)
                  : _buildChatSession(uid),
            ),
          ),
        );
      },
    );
  }

  Widget _buildChatsList(String driverUid, String name, String email) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<List<DriverSupportChat>>(
      stream: _supportRepo.streamDriverChats(driverUid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: AppLoader());
        }

        final chats = snapshot.data ?? [];

        return Column(
          children: [
            Expanded(
              child: chats.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.pagePadding,
                        vertical: AppSpacing.lg,
                      ),
                      itemCount: chats.length,
                      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                      itemBuilder: (context, index) {
                        final chat = chats[index];
                        final isResolved = chat.isResolved;
                        return GlassContainer(
                          padding: EdgeInsets.zero,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => setState(() => _selectedChatId = chat.id),
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              child: Padding(
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            chat.subject,
                                            style: AppTextStyles.titleMedium.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          if (chat.lastMessage.isNotEmpty)
                                            Text(
                                              chat.lastMessage,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: AppTextStyles.bodyMedium.copyWith(
                                                color: isDark
                                                    ? AppColors.textSecondaryDark
                                                    : AppColors.textSecondaryLight,
                                              ),
                                            ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: isResolved
                                                      ? (isDark ? Colors.grey[800] : Colors.grey.shade100)
                                                      : AppColors.brandGlass,
                                                  borderRadius: BorderRadius.circular(AppRadius.sm),
                                                ),
                                                child: Text(
                                                  chat.status.toUpperCase(),
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 10,
                                                    color: isResolved ? Colors.grey : AppColors.brand,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.sm),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.pagePadding,
                vertical: AppSpacing.sm,
              ),
              child: SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: 'Start New Support Chat',
                  onPressed: () => _showNewChatDialog(
                    driverUid: driverUid,
                    driverName: name,
                    driverEmail: email,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return const EmptyState(
      title: 'No Support History',
      message: 'If you are having issues, start a new support request below.',
      icon: Icons.support_agent_outlined,
    );
  }

  Widget _buildChatSession(String driverUid) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<DriverSupportMessage>>(
            stream: _supportRepo.streamMessages(_selectedChatId!),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: AppLoader());
              }

              final messages = snapshot.data ?? [];
              if (messages.isEmpty) {
                return Center(
                  child: Text(
                    'No messages yet.',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pagePadding,
                  vertical: AppSpacing.lg,
                ),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isDriver = msg.isDriver;
                  final bubbleColor = isDriver
                      ? AppColors.brand
                      : (isDark ? AppColors.darkSurface : Colors.white);
                  final borderColor = isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight;
                  final textColor = isDriver ? Colors.white : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight);

                  return Align(
                    alignment: isDriver ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        border: isDriver ? null : Border.all(color: borderColor),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(AppRadius.lg),
                          topRight: const Radius.circular(AppRadius.lg),
                          bottomLeft: Radius.circular(isDriver ? AppRadius.lg : AppRadius.sm),
                          bottomRight: Radius.circular(isDriver ? AppRadius.sm : AppRadius.lg),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (msg.hasImage) ...[
                            GestureDetector(
                              onTap: () => _viewImageFullScreen(msg.imageUrl!),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(AppRadius.md),
                                child: Image.network(
                                  msg.imageUrl!,
                                  width: 220,
                                  height: 160,
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, progress) {
                                    if (progress == null) return child;
                                    return Container(
                                      width: 220,
                                      height: 160,
                                      color: isDark
                                          ? AppColors.darkSurfaceRaised
                                          : AppColors.lightSurfaceRaised,
                                      child: const Center(child: AppLoader()),
                                    );
                                  },
                                  errorBuilder: (_, __, ___) => Container(
                                    width: 220,
                                    height: 100,
                                    color: Colors.grey.withValues(alpha: 0.2),
                                    child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
                                  ),
                                ),
                              ),
                            ),
                            if (msg.text.isNotEmpty) const SizedBox(height: 6),
                          ],
                          if (msg.text.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Text(
                                msg.text,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: textColor,
                                  height: 1.4,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        _buildMessageComposer(driverUid),
      ],
    );
  }

  Widget _buildMessageComposer(String driverUid) {
    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.sm),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_pendingImage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        child: Image.file(
                          _pendingImage!,
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => setState(() => _pendingImage = null),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded, color: Colors.white, size: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text('Image attached', style: AppTextStyles.bodySmall),
                ],
              ),
            ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.image_rounded, color: AppColors.brand, size: 22),
                onPressed: _isSending ? null : _pickImage,
                tooltip: 'Attach Image',
              ),
              Expanded(
                child: AppTextField(
                  controller: _messageController,
                  hint: 'Type a message...',
                  obscureText: false,
                  textCapitalization: TextCapitalization.sentences,
                  onSubmitted: (_) => _sendMessage(driverUid),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              GlassIconButton(
                icon: Icons.send_rounded,
                onPressed: _isSending ? null : () => _sendMessage(driverUid),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
