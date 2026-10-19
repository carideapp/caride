import 'package:caride/features/chat/data/chat_repository.dart';
import 'package:caride/features/profile/data/driver_public_profile_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:design_system/design_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

/// Customer 1-on-1 Conversation Screen redesigned with simplified layout,
/// flat CaRide brand tokens, no shadows on buttons, circular back button,
/// clean pill text input, and modern speech bubbles.
class ConversationScreen extends StatefulWidget {
  const ConversationScreen({
    super.key,
    required this.driverName,
    required this.rideId,
    this.driverUid,
    this.isFleet = false,
    this.vehicleTitle,
    this.peerPhoto,
  });

  final String driverName;
  final String rideId;
  final String? driverUid;
  final bool isFleet;
  final String? vehicleTitle;
  final String? peerPhoto;

  @override
  State<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends State<ConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
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
        .asyncMap((doc) async {
      if (doc.exists) {
        final data = doc.data() ?? {};
        final participantUids = List<String>.from(data['participantUids'] ?? []);
        final peer = participantUids.firstWhere((id) => id != currentUid, orElse: () => '');
        if (peer.isNotEmpty) return peer;
      }
      try {
        final rideSnap = await FirebaseFirestore.instance.collection('rides').doc(widget.rideId).get();
        if (rideSnap.exists) {
          final rideData = rideSnap.data() ?? {};
          final dUid = rideData['driverUid'] as String?;
          final cUid = rideData['customerUid'] as String?;
          return (currentUid == cUid ? dUid : cUid) ?? '';
        }
      } catch (_) {}
      return '';
    });
  }

  Stream<String?> _getFleetPhotoStream(String driverUid) {
    if (widget.peerPhoto != null && widget.peerPhoto!.isNotEmpty) {
      return Stream.value(widget.peerPhoto);
    }
    return FirebaseFirestore.instance
        .collection('rideMessages')
        .doc(widget.rideId)
        .snapshots()
        .asyncMap((threadDoc) async {
      final threadData = threadDoc.data() ?? {};
      final directLogo = (threadData['fleetLogo'] as String?) ??
          (threadData['fleetLogoUrl'] as String?) ??
          (threadData['logoUrl'] as String?) ??
          (threadData['peerPhoto'] as String?);
      if (directLogo != null && directLogo.isNotEmpty) {
        return directLogo;
      }

      final fleetId = threadData['fleetId'] as String?;
      if (fleetId != null && fleetId.isNotEmpty) {
        try {
          final fDoc = await FirebaseFirestore.instance
              .collection('fleets')
              .doc(fleetId)
              .get();
          if (fDoc.exists && fDoc.data() != null) {
            final d = fDoc.data()!;
            final logo = (d['logoUrl'] as String?) ??
                (d['profilePictureUrl'] as String?) ??
                (d['photoUrl'] as String?) ??
                (d['coverPhotoUrl'] as String?);
            if (logo != null && logo.isNotEmpty) return logo;
          }
        } catch (_) {}
      }

      if (driverUid.isNotEmpty) {
        try {
          final snap = await FirebaseFirestore.instance
              .collection('fleets')
              .where('ownerUid', isEqualTo: driverUid)
              .limit(1)
              .get();
          if (snap.docs.isNotEmpty) {
            final d = snap.docs.first.data();
            return (d['logoUrl'] as String?) ??
                (d['profilePictureUrl'] as String?) ??
                (d['photoUrl'] as String?) ??
                (d['coverPhotoUrl'] as String?);
          }
        } catch (_) {}
      }
      return null;
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    final message = _messageController.text.trim();
    if (message.isEmpty) return;
    setState(() => _sending = true);
    _messageController.clear();

    try {
      await _repository.sendMessage(rideId: widget.rideId, text: message);
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
          content: const Text('Phone number not available.'),
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

  String _formatMessageTime(DateTime dt) {
    return DateFormat('h:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor =
        isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);
    final borderColor =
        isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    final driverProfileRepo = DriverPublicProfileRepository();

    return StreamBuilder<String>(
      stream: _getDriverUidStream(),
      builder: (context, uidSnap) {
        final driverUid = uidSnap.data ?? widget.driverUid ?? '';

        return StreamBuilder<DriverPublicProfile?>(
          stream: (driverUid.isEmpty || widget.isFleet)
              ? Stream.value(null)
              : driverProfileRepo.watchDriver(driverUid),
          builder: (context, profileSnap) {
            final driverProfile = profileSnap.data;

            return StreamBuilder<String?>(
              stream: widget.isFleet
                  ? _getFleetPhotoStream(driverUid)
                  : Stream.value(
                      driverProfile?.profilePhotoUrl ?? widget.peerPhoto),
              builder: (context, photoSnap) {
                final photoUrl = photoSnap.data ??
                    (widget.isFleet
                        ? (widget.peerPhoto ?? '')
                        : (driverProfile?.profilePhotoUrl ?? ''));
                final name = widget.isFleet
                    ? widget.driverName
                    : ((driverProfile?.fullName.trim().isNotEmpty ?? false)
                        ? driverProfile!.fullName
                        : widget.driverName);
                final phone = driverProfile?.phone ?? '';

                return Scaffold(
                  backgroundColor:
                      isDark ? AppColors.darkBackground : const Color(0xFFF9FAFB),
                  body: SafeArea(
                    child: Column(
                      children: [
                        // ── Clean Flat Top Bar Header ───────────────────────
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 10.0),
                          decoration: BoxDecoration(
                            color: cardBg,
                            border: Border(
                              bottom: BorderSide(color: borderColor),
                            ),
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
                              // Peer Avatar
                              CircleAvatar(
                                radius: 21,
                                backgroundColor:
                                    AppColors.brand.withValues(alpha: 0.1),
                                backgroundImage: photoUrl.isNotEmpty
                                    ? NetworkImage(photoUrl)
                                    : null,
                                child: photoUrl.isEmpty
                                    ? (widget.isFleet
                                        ? const Icon(
                                            Icons.apartment_rounded,
                                            size: 20,
                                            color: AppColors.brand,
                                          )
                                        : Text(
                                            name.isNotEmpty
                                                ? name
                                                    .substring(0, 1)
                                                    .toUpperCase()
                                                : '?',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                              color: AppColors.brand,
                                            ),
                                          ))
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              // Title & Subtitle Column
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
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
                                      widget.vehicleTitle != null &&
                                              widget.vehicleTitle!.isNotEmpty
                                          ? widget.vehicleTitle!
                                          : (widget.isFleet
                                              ? 'Fleet Partner'
                                              : 'Assigned Driver'),
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
                              // Phone Call Action Button (if phone available)
                              if (phone.isNotEmpty)
                                GestureDetector(
                                  onTap: () => _makePhoneCall(phone),
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
                          ),
                        ),

                        // ── Messages Stream List ───────────────────────────
                        Expanded(
                          child: StreamBuilder<List<ChatMessage>>(
                            stream: _repository.watchMessages(widget.rideId),
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

                              final messages = snapshot.data ?? [];
                              if (messages.isEmpty) {
                                return Center(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 36.0),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Container(
                                          width: 72,
                                          height: 72,
                                          decoration: BoxDecoration(
                                            color: AppColors.brand
                                                .withValues(alpha: 0.1),
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
                                          widget.isFleet
                                              ? 'Send a message to coordinate your rental with the fleet host.'
                                              : 'Send a message to your driver about pickup or ride details.',
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
                                  horizontal: 16.0,
                                  vertical: 16.0,
                                ),
                                itemCount: messages.length,
                                separatorBuilder: (_, __) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, index) {
                                  final message = messages[index];
                                  final isMe = message.senderUid == currentUid;

                                  return _Bubble(
                                    text: message.text,
                                    time: _formatMessageTime(message.createdAt),
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

                        // ── Bottom Input Bar (Flat, pill input, no shadow) ─
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16.0,
                            vertical: 10.0,
                          ),
                          decoration: BoxDecoration(
                            color: cardBg,
                            border: Border(
                              top: BorderSide(color: borderColor),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? AppColors.darkBackground
                                        : const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                  child: TextField(
                                    controller: _messageController,
                                    textInputAction: TextInputAction.send,
                                    onSubmitted: (_) => _send(),
                                    style: TextStyle(
                                      color: primaryTextColor,
                                      fontSize: 14,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Type a message...',
                                      hintStyle: TextStyle(
                                        color: secondaryTextColor,
                                        fontSize: 14,
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 13,
                                      ),
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              GestureDetector(
                                onTap: _sending ? null : _send,
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: const BoxDecoration(
                                    color: AppColors.brand,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: _sending
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              color: Colors.white,
                                              strokeWidth: 2,
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
              },
            );
          },
        );
      },
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
