import 'dart:io';

import 'package:caride/core/models/customer_support_chat.dart';
import 'package:caride/core/models/customer_support_message.dart';
import 'package:caride/core/utils/safe_image_picker.dart';
import 'package:design_system/design_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

import '../profile/data/account_repository.dart';
import '../profile/data/customer_support_repository.dart';

/// Customer Support screen redesigned to match FleetSupportScreen UI and AGENTS.md guidelines.
/// Features top emerald header banner, "Start a Conversation" card, "Help/FAQs" menu link,
/// live support ticket history stream, and in-app chat session.
class CustomerSupportScreen extends StatefulWidget {
  const CustomerSupportScreen({super.key});

  @override
  State<CustomerSupportScreen> createState() => _CustomerSupportScreenState();
}

class _CustomerSupportScreenState extends State<CustomerSupportScreen> {
  final AccountRepository _profileRepo = AccountRepository();
  final CustomerSupportRepository _supportRepo = CustomerSupportRepository();
  final TextEditingController _messageController = TextEditingController();

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
      final XFile? picked = await SafeImagePicker.pickImage(
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

  void _openStartConversationBottomSheet({
    required BuildContext context,
    required String customerUid,
    required String customerName,
    required String customerEmail,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => _StartConversationBottomSheet(
        supportRepo: _supportRepo,
        customerUid: customerUid,
        customerName: customerName,
        customerEmail: customerEmail,
        onChatCreated: (chatId) {
          if (mounted) {
            setState(() => _selectedChatId = chatId);
          }
        },
      ),
    );
  }

  Future<void> _sendMessage(String customerUid) async {
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
      await _supportRepo.sendCustomerMessage(
        chatId: chatId,
        customerUid: customerUid,
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
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
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
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        body: const Center(child: Text('Please log in')),
      );
    }

    return StreamBuilder<AccountProfile?>(
      stream: _profileRepo.watchProfile(),
      builder: (context, profileSnap) {
        final profile = profileSnap.data;
        final customerName = profile?.fullName.isNotEmpty == true
            ? profile!.fullName
            : (user.displayName?.isNotEmpty == true ? user.displayName! : 'Customer');
        final customerEmail = profile?.email.isNotEmpty == true ? profile!.email : (user.email ?? '');

        if (_selectedChatId != null) {
          return Scaffold(
            backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFFAFAFA),
            body: SafeArea(
              child: Column(
                children: [
                  // Top Bar for Active Chat Session
                  Padding(
                    padding: const EdgeInsets.only(left: 20, right: 20, top: 14, bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(color: borderColor),
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: primaryTextColor),
                            onPressed: () => setState(() => _selectedChatId = null),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'Chat Support',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: primaryTextColor,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Expanded(child: _buildChatSession(user.uid, secondaryTextColor)),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
          body: SafeArea(
            top: false,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Top Emerald Banner (UI/support.jpg layout per AGENTS.md) ──
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.fromLTRB(
                      20,
                      MediaQuery.of(context).padding.top + 16,
                      20,
                      36,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF15803D), AppColors.brand],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Back Button
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white30),
                          ),
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Ask a question or start\na conversation with our team.',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            height: 1.25,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Floating "Start a Conversation" Card ──
                  Transform.translate(
                    offset: const Offset(0, -20),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: borderColor),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Start a Conversation',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: primaryTextColor,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 14),

                            // Support Avatars + Response Estimate
                            Row(
                              children: [
                                SizedBox(
                                  width: 84,
                                  height: 36,
                                  child: Stack(
                                    children: [
                                      Positioned(left: 0, child: _buildAvatarBadge('https://i.pravatar.cc/100?img=33')),
                                      Positioned(left: 22, child: _buildAvatarBadge('https://i.pravatar.cc/100?img=47')),
                                      Positioned(left: 44, child: _buildAvatarBadge('https://i.pravatar.cc/100?img=12')),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Get a reply in minutes',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: secondaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Full Pill Action Button (AGENTS.md Rule 2)
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.brand,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                                ),
                                onPressed: () => _openStartConversationBottomSheet(
                                  context: context,
                                  customerUid: user.uid,
                                  customerName: customerName,
                                  customerEmail: customerEmail,
                                ),
                                child: const Text(
                                  'Start Conversation',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Divider(height: 1, color: borderColor),
                            const SizedBox(height: 12),

                            // Single-line Help/FAQs Menu Item
                            InkWell(
                              onTap: () => context.push(CustomerRoutePaths.helpSupport),
                              borderRadius: BorderRadius.circular(16),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Icon(Icons.help_outline_rounded, color: AppColors.brand, size: 20),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        'Help/FAQs',
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                          color: primaryTextColor,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right_rounded,
                                      color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                                      size: 22,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // ── Section Title: "History" ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Text(
                      'History',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),

                  // Live Customer Support Chats Stream
                  StreamBuilder<List<CustomerSupportChat>>(
                    stream: _supportRepo.streamCustomerChats(user.uid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(
                            child: CircularProgressIndicator(color: AppColors.brand, strokeWidth: 2.5),
                          ),
                        );
                      }

                      final chats = snapshot.data ?? [];
                      if (chats.isEmpty) {
                        return _buildEmptyHistoryState(isDark, borderColor, cardBg, primaryTextColor, secondaryTextColor);
                      }

                      return ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        itemCount: chats.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final chat = chats[index];
                          final isResolved = chat.status == 'resolved';
                          final subtitle = isResolved
                              ? 'Ticket closed by support team.'
                              : (chat.lastMessage?.isNotEmpty == true
                                  ? chat.lastMessage!
                                  : 'Support chat active — awaiting reply.');

                          return Container(
                            decoration: BoxDecoration(
                              color: cardBg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: borderColor),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                              leading: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: isResolved
                                      ? const Color(0xFFDCFCE7)
                                      : (isDark ? Colors.white10 : const Color(0xFFF3F4F6)),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  isResolved ? Icons.check_circle_outline_rounded : Icons.chat_bubble_outline_rounded,
                                  color: isResolved ? AppColors.brand : (isDark ? Colors.white70 : const Color(0xFF374151)),
                                  size: 22,
                                ),
                              ),
                              title: Text(
                                chat.subject,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: primaryTextColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                subtitle,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: secondaryTextColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Icon(
                                Icons.chevron_right_rounded,
                                color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                                size: 22,
                              ),
                              onTap: () => setState(() => _selectedChatId = chat.id),
                            ),
                          );
                        },
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAvatarBadge(String url) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
      child: CircleAvatar(
        backgroundImage: NetworkImage(url),
        backgroundColor: AppColors.brand,
      ),
    );
  }

  Widget _buildEmptyHistoryState(
    bool isDark,
    Color borderColor,
    Color cardBg,
    Color primaryTextColor,
    Color secondaryTextColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Center(
          child: Column(
            children: [
              Icon(
                Icons.history_rounded,
                size: 40,
                color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
              ),
              const SizedBox(height: 10),
              Text(
                'No Support History Yet',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: primaryTextColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Your previous conversation tickets and support inquiries will appear here.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: secondaryTextColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatSession(String customerUid, Color secondaryTextColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<List<CustomerSupportMessage>>(
            stream: _supportRepo.streamMessages(_selectedChatId!),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const TransactionListSkeleton(itemCount: 4);
              }

              final messages = snapshot.data ?? [];
              if (messages.isEmpty) {
                return Center(
                  child: Text(
                    'No messages yet.',
                    style: TextStyle(fontSize: 15, color: secondaryTextColor),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index];
                  final isCustomer = msg.senderRole == 'customer';
                  final bubbleColor = isCustomer
                      ? AppColors.brand
                      : (isDark ? AppColors.darkSurface : Colors.white);
                  final borderColor = isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);
                  final textColor = isCustomer
                      ? Colors.white
                      : (isDark ? Colors.white : const Color(0xFF111827));

                  return Align(
                    alignment: isCustomer ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        border: isCustomer ? null : Border.all(color: borderColor),
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(20),
                          topRight: const Radius.circular(20),
                          bottomLeft: Radius.circular(isCustomer ? 20 : 6),
                          bottomRight: Radius.circular(isCustomer ? 6 : 20),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (msg.imageUrl != null && msg.imageUrl!.isNotEmpty) ...[
                            GestureDetector(
                              onTap: () => _viewImageFullScreen(msg.imageUrl!),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(14),
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
                                      color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                                      child: const Center(
                                        child: CircularProgressIndicator(color: AppColors.brand, strokeWidth: 2),
                                      ),
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
                            if (msg.text.isNotEmpty) const SizedBox(height: 8),
                          ],
                          if (msg.text.isNotEmpty)
                            Text(
                              msg.text,
                              style: TextStyle(
                                color: textColor,
                                fontSize: 14.5,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
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
        _buildMessageComposer(customerUid, secondaryTextColor),
      ],
    );
  }

  Widget _buildMessageComposer(String customerUid, Color secondaryTextColor) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);
    final inputBg = isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF3F4F6);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: cardBg,
        border: Border(top: BorderSide(color: borderColor)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_pendingImage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
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
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.close_rounded, color: Colors.white, size: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Image attached',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: secondaryTextColor,
                    ),
                  ),
                ],
              ),
            ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.image_outlined, color: AppColors.brand, size: 24),
                onPressed: _isSending ? null : _pickImage,
                tooltip: 'Attach Image',
              ),
              const SizedBox(width: 4),
              Expanded(
                child: TextField(
                  controller: _messageController,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(fontSize: 15, color: primaryTextColor),
                  decoration: InputDecoration(
                    hintText: 'Type a message...',
                    hintStyle: TextStyle(fontSize: 14, color: secondaryTextColor),
                    filled: true,
                    fillColor: inputBg,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(28),
                      borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  onSubmitted: (_) => _sendMessage(customerUid),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _isSending ? null : () => _sendMessage(customerUid),
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _isSending ? AppColors.brand.withValues(alpha: 0.5) : AppColors.brand,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
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

/// Bottom sheet modal to start a new support conversation.
class _StartConversationBottomSheet extends StatefulWidget {
  const _StartConversationBottomSheet({
    required this.supportRepo,
    required this.customerUid,
    required this.customerName,
    required this.customerEmail,
    required this.onChatCreated,
  });

  final CustomerSupportRepository supportRepo;
  final String customerUid;
  final String customerName;
  final String customerEmail;
  final ValueChanged<String> onChatCreated;

  @override
  State<_StartConversationBottomSheet> createState() => _StartConversationBottomSheetState();
}

class _StartConversationBottomSheetState extends State<_StartConversationBottomSheet> {
  final _headingController = TextEditingController();
  final _messageController = TextEditingController();

  File? _selectedImage;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _headingController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picked = await SafeImagePicker.pickImage(source: ImageSource.gallery, imageQuality: 75);
      if (picked != null) {
        setState(() => _selectedImage = File(picked.path));
      }
    } catch (_) {}
  }

  Future<void> _submitTicket() async {
    final heading = _headingController.text.trim();
    final message = _messageController.text.trim();

    if (heading.isEmpty) {
      setState(() => _errorMessage = 'Please enter a ticket subject/heading.');
      return;
    }
    if (message.isEmpty && _selectedImage == null) {
      setState(() => _errorMessage = 'Please enter your message or attach a screenshot.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final chatId = await widget.supportRepo.createChat(
        customerUid: widget.customerUid,
        customerName: widget.customerName,
        customerEmail: widget.customerEmail,
        subject: heading,
        initialMessage: message.isNotEmpty ? message : '📷 Attachment',
      );

      if (_selectedImage != null) {
        final imageUrl = await widget.supportRepo.uploadChatImage(_selectedImage!, chatId);
        await widget.supportRepo.sendCustomerMessage(
          chatId: chatId,
          customerUid: widget.customerUid,
          text: message,
          imageUrl: imageUrl,
        );
      }

      if (!mounted) return;
      Navigator.pop(context); // Close bottom sheet
      widget.onChatCreated(chatId);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _errorMessage = 'Failed to submit conversation: ${e.toString()}';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Drag Handle Indicator
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white30 : const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Start a Conversation',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: primaryTextColor,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: isDark ? Colors.white70 : const Color(0xFF6B7280)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (_errorMessage != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.error),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(fontSize: 13, color: AppColors.error, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Heading / Subject Input
            Text(
              'Heading / Subject *',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: primaryTextColor),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _headingController,
              style: TextStyle(fontSize: 15, color: primaryTextColor),
              decoration: InputDecoration(
                hintText: 'e.g., Fare inquiry, Ride issue, Account help',
                filled: true,
                fillColor: isDark ? AppColors.darkBackground : const Color(0xFFF3F4F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
              ),
            ),
            const SizedBox(height: 16),

            // Message Input
            Text(
              'Message *',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: primaryTextColor),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _messageController,
              maxLines: 4,
              style: TextStyle(fontSize: 15, color: primaryTextColor),
              decoration: InputDecoration(
                hintText: 'Describe how we can help you...',
                filled: true,
                fillColor: isDark ? AppColors.darkBackground : const Color(0xFFF3F4F6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.all(18),
              ),
            ),
            const SizedBox(height: 16),

            // Attachment Option
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.brand,
                    side: const BorderSide(color: AppColors.brand),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                  icon: const Icon(Icons.attach_file_rounded, size: 18),
                  label: const Text('Attach Screenshot (Optional)'),
                  onPressed: _pickImage,
                ),
                if (_selectedImage != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(_selectedImage!, width: 40, height: 40, fit: BoxFit.cover),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18, color: Colors.red),
                        onPressed: () => setState(() => _selectedImage = null),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                onPressed: _isSubmitting ? null : _submitTicket,
                child: _isSubmitting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                      )
                    : const Text(
                        'Submit Conversation',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
