import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:design_system/design_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:navigation/navigation.dart';

/// Fleet Manager Support screen strictly styled after UI/support.jpg and AGENTS.md.
/// Features top header banner, "Start a Conversation" card, "Help/FAQs" menu link,
/// and live support ticket history stream.
class FleetSupportScreen extends StatefulWidget {
  const FleetSupportScreen({super.key});

  @override
  State<FleetSupportScreen> createState() => _FleetSupportScreenState();
}

class _FleetSupportScreenState extends State<FleetSupportScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  void _openStartConversationBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) => _StartConversationBottomSheet(
        firestore: _firestore,
        auth: _auth,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final borderColor = isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final uid = _auth.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFFAFAFA),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Top Emerald Banner (UI/support.jpg layout with CaRide Brand Palette per AGENTS.md Rule 1) ──
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
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.white),
                        onPressed: () => context.pop(),
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
                                  Positioned(left: 0, child: _buildAvatarBadge('https://i.pravatar.cc/100?img=33', 0)),
                                  Positioned(left: 22, child: _buildAvatarBadge('https://i.pravatar.cc/100?img=47', 1)),
                                  Positioned(left: 44, child: _buildAvatarBadge('https://i.pravatar.cc/100?img=12', 2)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Get a reply in minutes',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
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
                            onPressed: () => _openStartConversationBottomSheet(context),
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
                          onTap: () => context.push(FleetRoutePaths.helpFaqs),
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

              // ── Section: "History" ──
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

              // Live Support Tickets Stream
              if (uid.isEmpty)
                _buildEmptyHistoryState(isDark, borderColor, cardBg, primaryTextColor)
              else
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _firestore
                      .collection('support_tickets')
                      .where('userId', isEqualTo: uid)
                      .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _buildEmptyHistoryState(isDark, borderColor, cardBg, primaryTextColor);
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return _buildEmptyHistoryState(isDark, borderColor, cardBg, primaryTextColor);
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final docId = docs[index].id;
                      final data = docs[index].data();
                      final subject = data['subject'] as String? ?? 'Support Inquiry';
                      final status = (data['status'] as String? ?? 'open').toLowerCase();
                      final isClosed = status == 'closed' || status == 'resolved';
                      final subtitle = isClosed ? 'Ticket closed by administrator.' : 'Support ticket open — awaiting reply.';

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
                              color: isClosed
                                  ? const Color(0xFFDCFCE7)
                                  : (isDark ? Colors.white10 : const Color(0xFFF3F4F6)),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isClosed ? Icons.check_circle_outline_rounded : Icons.chat_bubble_outline_rounded,
                              color: isClosed ? AppColors.brand : (isDark ? Colors.white70 : const Color(0xFF374151)),
                              size: 22,
                            ),
                          ),
                          title: Text(
                            subject,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: primaryTextColor,
                            ),
                          ),
                          subtitle: Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                            ),
                          ),
                          trailing: Icon(
                            Icons.chevron_right_rounded,
                            color: isDark ? Colors.white38 : const Color(0xFF9CA3AF),
                            size: 22,
                          ),
                          onTap: () => context.push(FleetRoutePaths.supportConversation, extra: docId),
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
  }

  Widget _buildAvatarBadge(String url, int index) {
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
                  color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet modal to start a new support conversation per AGENTS.md rules.
class _StartConversationBottomSheet extends StatefulWidget {
  const _StartConversationBottomSheet({
    required this.firestore,
    required this.auth,
  });

  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  @override
  State<_StartConversationBottomSheet> createState() => _StartConversationBottomSheetState();
}

class _StartConversationBottomSheetState extends State<_StartConversationBottomSheet> {
  final _headingController = TextEditingController();
  final _messageController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

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
      final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 75);
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
    if (message.isEmpty) {
      setState(() => _errorMessage = 'Please enter your message.');
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final uid = widget.auth.currentUser?.uid ?? '';
    final userEmail = widget.auth.currentUser?.email ?? '';
    final userName = widget.auth.currentUser?.displayName ?? 'Fleet Manager';

    try {
      final ticketRef = widget.firestore.collection('support_tickets').doc();
      final ticketId = ticketRef.id;

      String? imageUrl;
      if (_selectedImage != null) {
        final storageRef = FirebaseStorage.instance
            .ref()
            .child('support_tickets/$ticketId/initial.jpg');
        await storageRef.putFile(_selectedImage!);
        imageUrl = await storageRef.getDownloadURL();
      }

      final nowMs = DateTime.now().millisecondsSinceEpoch;

      // Save primary ticket
      await ticketRef.set({
        'ticketId': ticketId,
        'userId': uid,
        'userEmail': userEmail,
        'userName': userName,
        'userType': 'fleet',
        'subject': heading,
        'status': 'open',
        'lastMessage': message,
        'lastMessageAtMs': nowMs,
        'updatedAtMs': nowMs,
        'createdAtMs': nowMs,
        'lastMessageAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Save initial message
      await ticketRef.collection('messages').add({
        'senderUid': uid,
        'senderRole': 'fleet',
        'senderName': userName,
        'text': message,
        if (imageUrl != null) 'imageUrl': imageUrl,
        'createdAtMs': nowMs,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      Navigator.pop(context); // Close bottom sheet
      context.push(FleetRoutePaths.supportConversation, extra: ticketId);
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
                hintText: 'e.g., Payout inquiry, Vehicle documentation',
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

