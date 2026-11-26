import 'dart:async';
import 'dart:io' show Platform;

import 'package:caride/core/auth/lockout_support_service.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Screen allowing locked-out users (Customer, Driver, Fleet Manager) to chat
/// directly with CaRide Admin Support before login.
///
/// Route tickets to their designated admin pages:
/// - Customer -> CustomerSupportPage (collection: `supportChats`, userType: 'customer')
/// - Driver -> DriverSupportPage (collection: `supportChats`, userType: 'driver')
/// - Fleet Manager -> FleetSupportPage (collection: `support_tickets`, userType: 'fleet')
class LockedAccountSupportScreen extends StatefulWidget {
  const LockedAccountSupportScreen({
    super.key,
    required this.email,
    required this.role,
    this.stageName,
    this.initialChatId,
  });

  final String email;
  final String role; // 'customer' | 'driver' | 'fleet'
  final String? stageName;
  final String? initialChatId;

  static Future<void> show(
    BuildContext context, {
    required String email,
    required String role,
    String? stageName,
    String? initialChatId,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => LockedAccountSupportScreen(
          email: email,
          role: role,
          stageName: stageName,
          initialChatId: initialChatId,
        ),
      ),
    );
  }

  @override
  State<LockedAccountSupportScreen> createState() =>
      _LockedAccountSupportScreenState();
}

class _LockedAccountSupportScreenState
    extends State<LockedAccountSupportScreen> {
  final LockoutSupportService _service = LockoutSupportService();
  final TextEditingController _composeController = TextEditingController();
  final TextEditingController _replyController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  String? _activeChatId;
  String? _ticketStatus;
  String? _ticketSubject;
  List<Map<String, dynamic>> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _initChat();
    // Auto-refresh chat every 8 seconds to catch admin replies
    _refreshTimer = Timer.periodic(const Duration(seconds: 8), (_) {
      if (mounted && _activeChatId != null && !_isSending) {
        _loadChat(_activeChatId!, silent: true);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _composeController.dispose();
    _replyController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  String get _roleLabel {
    switch (widget.role.toLowerCase()) {
      case 'driver':
        return 'Driver';
      case 'fleet':
        return 'Fleet Manager';
      default:
        return 'Customer';
    }
  }

  Future<void> _initChat() async {
    setState(() => _isLoading = true);
    try {
      String? targetChatId = widget.initialChatId;
      if (targetChatId == null || targetChatId.isEmpty) {
        targetChatId = await LockoutSupportService.getActiveChatId(
          role: widget.role,
          email: widget.email,
        );
      }

      if (targetChatId != null && targetChatId.isNotEmpty) {
        await _loadChat(targetChatId);
      } else {
        // Prepare pre-composed message
        final defaultMessage =
            'Hello CaRide Support Team,\n\n'
            'My account is currently locked for security reasons after exceeding the allowed login attempts. '
            'Please review and unlock my account.\n\n'
            'Account Email: ${widget.email.isNotEmpty ? widget.email : "Not provided"}\n'
            'Role: $_roleLabel\n'
            'Lockout Stage: ${widget.stageName ?? "Final Lockout / Manual Unlock Required"}\n'
            'Timestamp: ${DateTime.now().toLocal()}\n'
            'Device: ${Platform.operatingSystem}\n\n'
            'Thank you.';
        _composeController.text = defaultMessage;
        if (mounted) {
          setState(() {
            _activeChatId = null;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Could not load support ticket: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadChat(String chatId, {bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    try {
      final res = await _service.getChat(
        chatId: chatId,
        email: widget.email,
        role: widget.role,
      );

      final rawMessages = res['messages'] as List<dynamic>? ?? [];
      final messages = rawMessages
          .map((m) => Map<String, dynamic>.from(m as Map))
          .toList();

      if (mounted) {
        setState(() {
          _activeChatId = chatId;
          _ticketStatus = res['status'] as String? ?? 'active';
          _ticketSubject =
              res['subject'] as String? ?? 'Account Lockout Support';
          _messages = messages;
          _isLoading = false;
          _errorMessage = null;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() {
          _errorMessage = 'Unable to fetch conversation details: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 60,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _handleStartNewTicket() async {
    final text = _composeController.text.trim();
    if (text.isEmpty) {
      setState(() => _errorMessage = 'Please enter a message for support.');
      return;
    }

    setState(() {
      _isSending = true;
      _errorMessage = null;
    });

    try {
      final res = await _service.submitMessage(
        email: widget.email,
        role: widget.role,
        message: text,
        subject: '$_roleLabel Account Lockout Support Request',
        stageName: widget.stageName,
      );

      final newChatId = res['chatId'] as String?;
      if (newChatId != null) {
        await LockoutSupportService.recordActiveLockout(
          role: widget.role,
          email: widget.email,
          chatId: newChatId,
        );
        await _loadChat(newChatId);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Failed to submit ticket: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _handleSendReply() async {
    final chatId = _activeChatId;
    if (chatId == null) return;
    final text = _replyController.text.trim();
    if (text.isEmpty) return;

    _replyController.clear();
    setState(() => _isSending = true);

    try {
      await _service.submitMessage(
        email: widget.email,
        role: widget.role,
        message: text,
        chatId: chatId,
      );
      await _loadChat(chatId, silent: true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not send message: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _showConversationsList() async {
    setState(() => _isLoading = true);
    try {
      final chats = await _service.listChats(
        email: widget.email,
        role: widget.role,
      );
      if (!mounted) return;
      setState(() => _isLoading = false);

      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (modalCtx) {
          final isDark = Theme.of(modalCtx).brightness == Brightness.dark;
          final cardBg = isDark ? AppColors.darkSurface : Colors.white;
          return Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Your Support Tickets',
                      style: AppTextStyles.headlineSmall.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('New Chat'),
                      onPressed: () {
                        Navigator.of(modalCtx).pop();
                        setState(() {
                          _activeChatId = null;
                          _composeController.text =
                              'Hello Support Team,\nI need assistance with my locked account (${widget.email}).';
                        });
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (chats.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Center(
                      child: Text(
                        'No previous tickets found.',
                        style: TextStyle(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ),
                  )
                else
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: chats.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final c = chats[i];
                        final cId = c['id'] as String;
                        final isSelected = cId == _activeChatId;
                        final status = c['status'] as String? ?? 'active';
                        final isResolved =
                            status == 'resolved' || status == 'closed';
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            c['subject'] as String? ?? 'Support Inquiry',
                            style: TextStyle(
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: isSelected ? AppColors.brand : null,
                            ),
                          ),
                          subtitle: Text(
                            c['lastMessage'] as String? ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isResolved
                                  ? AppColors.success.withValues(alpha: 0.15)
                                  : const Color(
                                      0xFFF59E0B,
                                    ).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              isResolved ? 'Resolved' : 'Active',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isResolved
                                    ? AppColors.success
                                    : const Color(0xFFB45309),
                              ),
                            ),
                          ),
                          onTap: () {
                            Navigator.of(modalCtx).pop();
                            _loadChat(cId);
                          },
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not load tickets: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : AppColors.textPrimaryLight;
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark
        ? AppColors.glassBorderDark
        : const Color(0xFFE5E7EB);
    final isResolved = _ticketStatus == 'resolved' || _ticketStatus == 'closed';

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Support - Locked Account',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            Text(
              '$_roleLabel • ${widget.email.isNotEmpty ? widget.email : "Account Access"}',
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'View Conversations',
            icon: const Icon(Icons.history_rounded),
            onPressed: _showConversationsList,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () {
              if (_activeChatId != null) {
                _loadChat(_activeChatId!);
              } else {
                _initChat();
              }
            },
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _activeChatId == null
            ? _buildInitialComposeView(
                isDark,
                primaryTextColor,
                cardBg,
                borderColor,
              )
            : _buildActiveChatView(
                isDark,
                primaryTextColor,
                isResolved,
                cardBg,
                borderColor,
              ),
      ),
    );
  }

  Widget _buildInitialComposeView(
    bool isDark,
    Color primaryTextColor,
    Color cardBg,
    Color borderColor,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner Badge
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: isDark ? 0.12 : 0.08),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: AppColors.error.withValues(alpha: 0.25),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.shield_outlined,
                  color: AppColors.error,
                  size: 26,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Account Access Temporarily Restricted',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Our Operations & Security team receives your request directly in the Admin Dashboard.',
                        style: AppTextStyles.caption.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          Text(
            'Compose Support Message',
            style: AppTextStyles.bodyMedium.copyWith(
              color: primaryTextColor,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Your account details and lockout status will be included automatically so administrators can verify and restore your access promptly.',
            style: AppTextStyles.caption.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Message input
          Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: borderColor),
            ),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: TextField(
              controller: _composeController,
              maxLines: 10,
              style: TextStyle(
                fontSize: 13,
                color: primaryTextColor,
                height: 1.4,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText:
                    'Describe your issue or request access restoration...',
              ),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _errorMessage!,
              style: const TextStyle(color: AppColors.error, fontSize: 12),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),

          PrimaryButton(
            label: _isSending
                ? 'Sending to Support...'
                : 'Send Message to Support',
            icon: Icons.send_rounded,
            isLoading: _isSending,
            onPressed: _handleStartNewTicket,
          ),
        ],
      ),
    );
  }

  Widget _buildActiveChatView(
    bool isDark,
    Color primaryTextColor,
    bool isResolved,
    Color cardBg,
    Color borderColor,
  ) {
    return Column(
      children: [
        // Top status card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isResolved
                ? AppColors.success.withValues(alpha: 0.12)
                : const Color(0xFFF59E0B).withValues(alpha: 0.12),
            border: Border(
              bottom: BorderSide(
                color: isResolved
                    ? AppColors.success.withValues(alpha: 0.3)
                    : const Color(0xFFF59E0B).withValues(alpha: 0.3),
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isResolved
                    ? Icons.check_circle_outline_rounded
                    : Icons.support_agent_rounded,
                size: 18,
                color: isResolved ? AppColors.success : const Color(0xFFB45309),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  isResolved
                      ? 'Ticket Resolved — Account Access Restored. You may sign in.'
                      : 'Support Ticket Active — Awaiting reply from Administrator.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isResolved
                        ? AppColors.success
                        : (isDark ? Colors.white : const Color(0xFF92400E)),
                  ),
                ),
              ),
              if (isResolved)
                TextButton(
                  onPressed: () {
                    LockoutSupportService.clearLockoutRecord(
                      role: widget.role,
                      email: widget.email,
                    );
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Go to Sign In',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                  ),
                ),
            ],
          ),
        ),

        // Message List
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final m = _messages[index];
              final role = (m['senderRole'] as String? ?? '').toLowerCase();
              final isAdmin = role == 'admin';
              final text = m['text'] as String? ?? '';
              final timeMs = m['createdAtMs'] as int?;
              final timeStr = timeMs != null && timeMs > 0
                  ? DateTime.fromMillisecondsSinceEpoch(
                      timeMs,
                    ).toLocal().toString().substring(11, 16)
                  : '';

              return Align(
                alignment: isAdmin
                    ? Alignment.centerLeft
                    : Alignment.centerRight,
                child: Container(
                  margin: const EdgeInsets.only(bottom: AppSpacing.sm),
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.78,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: isAdmin
                        ? (isDark ? AppColors.darkSurface : Colors.white)
                        : AppColors.brand,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isAdmin ? 2 : 16),
                      bottomRight: Radius.circular(isAdmin ? 16 : 2),
                    ),
                    border: Border.all(
                      color: isAdmin ? borderColor : AppColors.brand,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isAdmin) ...[
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.brand.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'CaRide Admin',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.brand,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            if (timeStr.isNotEmpty)
                              Text(
                                timeStr,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondaryLight,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        text,
                        style: TextStyle(
                          fontSize: 13,
                          color: isAdmin ? primaryTextColor : Colors.white,
                          height: 1.35,
                        ),
                      ),
                      if (!isAdmin && timeStr.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Align(
                          alignment: Alignment.bottomRight,
                          child: Text(
                            timeStr,
                            style: const TextStyle(
                              fontSize: 9,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // Bottom text bar
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: cardBg,
            border: Border(top: BorderSide(color: borderColor)),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _replyController,
                  minLines: 1,
                  maxLines: 4,
                  style: TextStyle(fontSize: 13, color: primaryTextColor),
                  decoration: InputDecoration(
                    hintText: isResolved
                        ? 'Ticket resolved. Type to send message...'
                        : 'Reply to support...',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: isDark
                        ? AppColors.darkBackground
                        : AppColors.lightBackground,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: borderColor),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: borderColor),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                decoration: const BoxDecoration(
                  color: AppColors.brand,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: _isSending
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.arrow_upward_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                  onPressed: _isSending ? null : _handleSendReply,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
