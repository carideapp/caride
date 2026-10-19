import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:design_system/design_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:navigation/navigation.dart';

/// Fleet Manager Support Conversation Screen strictly matching UI/support-conversation.jpg & AGENTS.md.
/// Handles real-time messaging, status card, image attachments, and resolved/closed ticket state.
class FleetSupportConversationScreen extends StatefulWidget {
  const FleetSupportConversationScreen({
    super.key,
    required this.ticketId,
  });

  final String ticketId;

  @override
  State<FleetSupportConversationScreen> createState() => _FleetSupportConversationScreenState();
}

class _FleetSupportConversationScreenState extends State<FleetSupportConversationScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  File? _selectedImageFile;
  bool _isSending = false;

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
      if (picked != null) {
        setState(() => _selectedImageFile = File(picked.path));
      }
    } catch (_) {}
  }

  Future<void> _sendMessage(String ticketId) async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _selectedImageFile == null) return;

    setState(() => _isSending = true);
    final uid = _auth.currentUser?.uid ?? '';

    try {
      String? imageUrl;
      if (_selectedImageFile != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('support_tickets/$ticketId/${DateTime.now().millisecondsSinceEpoch}.jpg');
        await storageRef.putFile(_selectedImageFile!);
        imageUrl = await storageRef.getDownloadURL();
      }

      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final msgData = {
        'senderUid': uid,
        'senderRole': 'fleet',
        'senderName': _auth.currentUser?.displayName ?? 'Fleet Manager',
        'text': text,
        if (imageUrl != null) 'imageUrl': imageUrl,
        'createdAtMs': nowMs,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('support_tickets')
          .doc(ticketId)
          .collection('messages')
          .add(msgData);

      // Update parent ticket lastMessage
      await _firestore.collection('support_tickets').doc(ticketId).update({
        'lastMessage': text.isNotEmpty ? text : '[Image Attachment]',
        'lastMessageAtMs': nowMs,
        'updatedAtMs': nowMs,
      });

      _messageController.clear();
      setState(() => _selectedImageFile = null);

      // Scroll to bottom
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final borderColor = isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _firestore.collection('support_tickets').doc(widget.ticketId).snapshots(),
          builder: (context, ticketSnap) {
            final ticketData = ticketSnap.data?.data() ?? {};
            final subject = ticketData['subject'] as String? ?? 'Customer Support';
            final status = (ticketData['status'] as String? ?? 'open').toLowerCase();
            final isClosed = status == 'closed' || status == 'resolved';

            return Column(
              children: [
                // ── Header Bar ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: cardBg,
                          shape: BoxShape.circle,
                          border: Border.all(color: borderColor),
                        ),
                        child: IconButton(
                          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: primaryTextColor),
                          onPressed: () => context.pop(),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Customer Support',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: primaryTextColor,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Top Ticket Header Card (UI/support-conversation.jpg reference) ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: borderColor),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.support_agent_rounded, color: AppColors.brand, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                subject,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: primaryTextColor,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                isClosed ? 'Resolved ticket' : 'Active ticket conversation',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isClosed
                                ? (isDark ? Colors.white10 : const Color(0xFFF3F4F6))
                                : const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            isClosed ? 'Closed' : 'Open',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isClosed
                                  ? (isDark ? Colors.white70 : const Color(0xFF4B5563))
                                  : const Color(0xFF15803D),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Messages Stream ──
                Expanded(
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _firestore
                        .collection('support_tickets')
                        .doc(widget.ticketId)
                        .collection('messages')
                        .orderBy('createdAtMs', descending: false)
                        .snapshots(),
                    builder: (context, msgSnap) {
                      final msgDocs = msgSnap.data?.docs ?? [];

                      return ListView(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        children: [
                          ...msgDocs.map((doc) {
                            final data = doc.data();
                            final senderRole = (data['senderRole'] as String?)?.toLowerCase() ?? 'fleet';
                            final isMe = senderRole == 'fleet' || senderRole == 'user';
                            final text = data['text'] as String? ?? '';
                            final imageUrl = data['imageUrl'] as String?;
                            final timeMs = data['createdAtMs'] as int? ?? 0;
                            final timeStr = timeMs > 0
                                ? DateFormat('hh:mm a').format(DateTime.fromMillisecondsSinceEpoch(timeMs))
                                : '';

                            return Align(
                              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                constraints: BoxConstraints(
                                  maxWidth: MediaQuery.of(context).size.width * 0.76,
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                decoration: BoxDecoration(
                                  color: isMe
                                      ? AppColors.brand
                                      : (isDark ? AppColors.darkSurface : Colors.white),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(20),
                                    topRight: const Radius.circular(20),
                                    bottomLeft: Radius.circular(isMe ? 20 : 4),
                                    bottomRight: Radius.circular(isMe ? 4 : 20),
                                  ),
                                  border: isMe ? null : Border.all(color: borderColor),
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  children: [
                                    if (imageUrl != null && imageUrl.isNotEmpty) ...[
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: Image.network(
                                          imageUrl,
                                          height: 160,
                                          width: double.infinity,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                      if (text.isNotEmpty) const SizedBox(height: 8),
                                    ],
                                    if (text.isNotEmpty)
                                      Text(
                                        text,
                                        style: TextStyle(
                                          fontSize: 14.5,
                                          color: isMe ? Colors.white : primaryTextColor,
                                          height: 1.35,
                                        ),
                                      ),
                                    if (timeStr.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        timeStr,
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          color: isMe
                                              ? Colors.white70
                                              : (isDark ? AppColors.textSecondaryDark : const Color(0xFF9CA3AF)),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          }),

                          // Closed Central Notification Banner
                          if (isClosed)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16.0),
                              child: Center(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.darkSurface : Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: borderColor),
                                  ),
                                  child: Text(
                                    'This chat conversation has been closed by the administrator.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),

                // ── Bottom Section (Input Bar if Open OR Lock Banner if Closed per UI/support-conversation.jpg) ──
                if (isClosed)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFDCFCE7)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Color(0xFFDCFCE7),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.lock_outline_rounded, color: AppColors.brand, size: 20),
                          ),
                          const SizedBox(width: 14),
                          const Expanded(
                            child: Text(
                              'This ticket is resolved and closed.',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      border: Border(top: BorderSide(color: borderColor)),
                    ),
                    child: Column(
                      children: [
                        if (_selectedImageFile != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(_selectedImageFile!, width: 50, height: 50, fit: BoxFit.cover),
                                ),
                                const SizedBox(width: 8),
                                const Text('Image attached', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18, color: Colors.red),
                                  onPressed: () => setState(() => _selectedImageFile = null),
                                ),
                              ],
                            ),
                          ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.attach_file_rounded, color: AppColors.brand),
                              onPressed: _pickImage,
                            ),
                            Expanded(
                              child: TextField(
                                controller: _messageController,
                                style: TextStyle(fontSize: 14, color: primaryTextColor),
                                decoration: InputDecoration(
                                  hintText: 'Type your message...',
                                  hintStyle: TextStyle(
                                    fontSize: 14,
                                    color: isDark ? AppColors.textSecondaryDark : const Color(0xFF9CA3AF),
                                  ),
                                  filled: true,
                                  fillColor: isDark ? AppColors.darkBackground : const Color(0xFFF3F4F6),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(24),
                                    borderSide: BorderSide.none,
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: _isSending
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.brand),
                                    )
                                  : const Icon(Icons.send_rounded, color: AppColors.brand),
                              onPressed: _isSending ? null : () => _sendMessage(widget.ticketId),
                            ),
                          ],
                        ),
                      ],
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
