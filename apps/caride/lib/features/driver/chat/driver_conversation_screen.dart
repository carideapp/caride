import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:design_system/design_system.dart';
import 'package:caride/core/driver/auth/driver_auth_controller.dart';
import 'package:caride/features/driver/chat/data/driver_chat_repository.dart';
import 'package:caride/core/driver/widgets/customer_avatar.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

/// Driver 1-on-1 Conversation Screen redesigned with simplified flat layout,
/// circular back button, pill text input, zero-shadow send button, and CaRide brand emerald styling.
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
    if (text.isEmpty || _rideId.isEmpty || _sending) return;
    setState(() => _sending = true);
    _textController.clear();

    try {
      await _repo.sendMessage(rideId: _rideId, text: text);
      _scrollToBottom();
    } finally {
      if (mounted) setState(() => _sending = false);
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

  String _formatTime(DateTime dt) {
    return DateFormat('h:mm a').format(dt);
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
    final myUid = driverAuthController.currentUid ?? '';

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Bar Header (Flat, Circular Back Button, Customer Info) ──
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16.0, vertical: 10.0),
              decoration: BoxDecoration(
                color: cardBg,
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
                future: _rideId.isEmpty
                    ? Future.value(null)
                    : FirebaseFirestore.instance
                        .collection('rides')
                        .doc(_rideId)
                        .get(),
                builder: (context, rideSnap) {
                  final rideData = rideSnap.data?.data();
                  final customerUid =
                      rideData?['customerUid'] as String? ?? '';
                  final customerPhone =
                      (rideData?['customerPhone'] ??
                              rideData?['phone']) as String? ??
                          '';

                  return Row(
                    children: [
                      // Circular Back Button per AGENTS.md (44x44px)
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isDark
                                ? AppColors.darkBackground
                                : Colors.white,
                            border: Border.all(color: borderColor),
                          ),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            size: 20,
                            color: primaryTextColor,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Customer Avatar
                      CustomerAvatar(
                        customerUid: customerUid,
                        fallbackLetter: widget.customerName,
                        radius: 21,
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
                              'Passenger',
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

                      // Call Customer Button (if phone exists)
                      if (customerPhone.isNotEmpty)
                        GestureDetector(
                          onTap: () => _makePhoneCall(customerPhone),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color:
                                  AppColors.brand.withValues(alpha: 0.1),
                            ),
                            child: const Icon(
                              Icons.phone_rounded,
                              color: AppColors.brand,
                              size: 19,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),

            // ── Messages Stream ─────────────────────────────────────────────
            Expanded(
              child: _rideId.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32.0),
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
                              'No Active Ride',
                              style: TextStyle(
                                fontSize: 16.5,
                                fontWeight: FontWeight.w700,
                                color: primaryTextColor,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Accept a ride to start chatting with your passenger.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                color: secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : StreamBuilder<List<DriverChatMessage>>(
                      stream: _repo.watchMessages(_rideId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: AppColors.brand,
                              strokeWidth: 2.5,
                            ),
                          );
                        }

                        final msgs = snapshot.data ?? [];
                        if (msgs.isEmpty) {
                          return Center(
                            child: Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 36.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 72,
                                    height: 72,
                                    decoration: BoxDecoration(
                                      color:
                                          AppColors.brand.withValues(alpha: 0.1),
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
                                    'Say Hello!',
                                    style: TextStyle(
                                      fontSize: 16.5,
                                      fontWeight: FontWeight.w700,
                                      color: primaryTextColor,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Send a message to ${widget.customerName} about pickup or arrival.',
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          itemCount: msgs.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) {
                            final msg = msgs[i];
                            final isMe = msg.senderUid == myUid;

                            return _Bubble(
                              text: msg.text,
                              time: _formatTime(msg.createdAt),
                              isMe: isMe,
                              isDark: isDark,
                              primaryTextColor: primaryTextColor,
                              secondaryTextColor: secondaryTextColor,
                              borderColor: borderColor,
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
                        controller: _textController,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        style: TextStyle(
                          color: primaryTextColor,
                          fontSize: 14,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Send a message...',
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
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Send Button (Zero shadow, pill/circle, CaRide brand emerald)
                  GestureDetector(
                    onTap: _sending ? null : _send,
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.brand,
                      ),
                      child: Center(
                        child: _sending
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

class _Bubble extends StatelessWidget {
  const _Bubble({
    required this.text,
    required this.time,
    required this.isMe,
    required this.isDark,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.borderColor,
  });

  final String text;
  final String time;
  final bool isMe;
  final bool isDark;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width * 0.75;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: isMe
                ? AppColors.brand
                : (isDark ? AppColors.darkSurface : Colors.white),
            border: isMe ? null : Border.all(color: borderColor),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isMe ? 18 : 4),
              bottomRight: Radius.circular(isMe ? 4 : 18),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                style: TextStyle(
                  color: isMe ? Colors.white : primaryTextColor,
                  fontSize: 14.5,
                  height: 1.35,
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  time,
                  style: TextStyle(
                    color: isMe ? Colors.white70 : secondaryTextColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
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
