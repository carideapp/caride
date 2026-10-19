import 'package:caride/features/chat/data/chat_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

/// 1-on-1 Real-time Conversation Screen between Fleet Manager and Rental Customer.
/// Designed with flat layout, pill geometry, circular back button, call action, and zero button shadows.
class FleetConversationScreen extends StatefulWidget {
  const FleetConversationScreen({
    super.key,
    required this.threadId,
    required this.customerName,
    this.customerUid,
    this.customerPhone,
    this.vehicleTitle,
    this.bookingId,
  });

  final String threadId;
  final String customerName;
  final String? customerUid;
  final String? customerPhone;
  final String? vehicleTitle;
  final String? bookingId;

  @override
  State<FleetConversationScreen> createState() => _FleetConversationScreenState();
}

class _FleetConversationScreenState extends State<FleetConversationScreen> {
  final _repository = ChatRepository();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _repository.markAsRead(widget.threadId);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() => _isSending = true);
    _messageController.clear();

    try {
      await _repository.sendMessage(
        rideId: widget.threadId,
        text: text,
      );
      _scrollToBottom();
    } catch (e) {
      debugPrint('[FleetConversationScreen] Send error: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _makePhoneCall(String phone) async {
    final clean = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (clean.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Customer phone number is not available.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
      return;
    }
    final uri = Uri.parse('tel:$clean');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor =
        isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor =
        isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);
    final inputFill =
        isDark ? AppColors.darkBackground : const Color(0xFFF3F4F6);
    final currentUid = FirebaseAuth.instance.currentUser?.uid;

    final customerPhone = widget.customerPhone?.trim() ?? '';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Bar Header (Flat, Circular Back Button, Customer Info, Call Action) ──
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              decoration: BoxDecoration(
                color: cardBg,
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  // Circular Back Button per AGENTS.md (44x44px)
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? AppColors.darkBackground : Colors.white,
                        border: Border.all(color: borderColor),
                      ),
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: primaryTextColor,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Customer Avatar
                  CircleAvatar(
                    radius: 21,
                    backgroundColor: AppColors.brand.withValues(alpha: 0.12),
                    child: Text(
                      widget.customerName.trim().isNotEmpty
                          ? widget.customerName.trim().substring(0, 1).toUpperCase()
                          : 'C',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.brand,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Customer Details Column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.customerName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: primaryTextColor,
                            letterSpacing: -0.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.vehicleTitle != null && widget.vehicleTitle!.isNotEmpty
                              ? widget.vehicleTitle!
                              : 'Rental Customer',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.brand,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),

                  // Call Customer Action Button (Zero shadow, flat brand icon)
                  if (customerPhone.isNotEmpty)
                    GestureDetector(
                      onTap: () => _makePhoneCall(customerPhone),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.brand.withValues(alpha: 0.1),
                        ),
                        child: const Icon(
                          Icons.phone_rounded,
                          color: AppColors.brand,
                          size: 19,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // ── Messages Stream ─────────────────────────────────────────────
            Expanded(
              child: StreamBuilder<List<ChatMessage>>(
                stream: _repository.watchMessages(widget.threadId),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.brand,
                        strokeWidth: 2.5,
                      ),
                    );
                  }

                  final messages = snapshot.data ?? [];

                  if (messages.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 36.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                color: AppColors.brand.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.chat_bubble_outline_rounded,
                                color: AppColors.brand,
                                size: 34,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Start Conversation',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: primaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Coordinate pickup, vehicle handover, and answer any rental questions.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: secondaryTextColor,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    itemCount: messages.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg.senderUid == currentUid;
                      final timeStr = DateFormat('h:mm a').format(msg.createdAt);
                      final maxWidth = MediaQuery.of(context).size.width * 0.75;

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxWidth),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 11),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? AppColors.brand
                                  : (isDark ? AppColors.darkSurface : Colors.white),
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(18),
                                topRight: const Radius.circular(18),
                                bottomLeft: Radius.circular(isMe ? 18 : 4),
                                bottomRight: Radius.circular(isMe ? 4 : 18),
                              ),
                              border: isMe ? null : Border.all(color: borderColor),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  msg.text,
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    color: isMe ? Colors.white : primaryTextColor,
                                    height: 1.35,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    timeStr,
                                    style: TextStyle(
                                      fontSize: 10.5,
                                      color: isMe ? Colors.white70 : secondaryTextColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
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
            ),

            // ── Input Bar (Flat, pill input, zero-shadow send button) ───────
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 10.0,
              ),
              decoration: BoxDecoration(
                color: cardBg,
                border: Border(top: BorderSide(color: borderColor)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: inputFill,
                        borderRadius: BorderRadius.circular(28),
                      ),
                      child: TextField(
                        controller: _messageController,
                        style: TextStyle(color: primaryTextColor, fontSize: 14),
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(
                            color: secondaryTextColor,
                            fontSize: 14,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 13,
                          ),
                          border: InputBorder.none,
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Send Button (Zero shadow, pill/circle, CaRide brand emerald)
                  GestureDetector(
                    onTap: _isSending ? null : _sendMessage,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.brand,
                      ),
                      child: Center(
                        child: _isSending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.send_rounded,
                                color: Colors.white,
                                size: 19,
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
