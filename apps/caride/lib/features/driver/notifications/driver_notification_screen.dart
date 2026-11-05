import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:design_system/design_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Real-time Driver Notifications screen utilizing GlassAppBar, EmptyState, and design system tokens.
class DriverNotificationScreen extends StatelessWidget {
  const DriverNotificationScreen({super.key});

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Just now';
    if (timestamp is Timestamp) {
      return DateFormat('dd MMM yyyy, hh:mm a').format(timestamp.toDate());
    }
    if (timestamp is DateTime) {
      return DateFormat('dd MMM yyyy, hh:mm a').format(timestamp);
    }
    return 'Recently';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark
        ? AppColors.glassBorderDark
        : const Color(0xFFE5E7EB);

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: GlassAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: 'Notifications',
      ),
      body: SafeArea(
        child: uid.isEmpty
            ? const ResponsiveContainer(
                child: EmptyState(
                  title: 'No Notifications',
                  message:
                      "You'll see notifications here when you receive them.",
                  icon: Icons.notifications_none_rounded,
                ),
              )
            : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('drivers')
                    .doc(uid)
                    .collection('notifications')
                    .orderBy('createdAt', descending: true)
                    .limit(50)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: AppColors.brand),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const ResponsiveContainer(
                      child: EmptyState(
                        title: 'No Notifications',
                        message:
                            "You'll see notifications here when you receive them.",
                        icon: Icons.notifications_none_rounded,
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    itemCount: docs.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final docSnap = docs[index];
                      final data = docSnap.data();
                      final title = data['title'] as String? ?? 'Notification';
                      final body = data['body'] as String? ?? '';
                      final isRead = data['isRead'] as bool? ?? false;
                      final type = (data['type'] as String? ?? '')
                          .toLowerCase();
                      final createdAt = data['createdAt'];

                      final isCredit =
                          type == 'admin_credit' ||
                          title.toLowerCase().contains('credit');
                      final isDebit =
                          type == 'admin_debit' ||
                          title.toLowerCase().contains('debit');

                      final iconColor = isCredit
                          ? AppColors.brand
                          : (isDebit ? AppColors.error : AppColors.brand);
                      final iconBg = isCredit
                          ? (isDark
                                ? const Color(0xFF14301D)
                                : const Color(0xFFF0FDF4))
                          : (isDebit
                                ? const Color(0xFFFEF2F2)
                                : (isDark
                                      ? AppColors.darkSurface
                                      : const Color(0xFFF3F4F6)));

                      final iconData = isCredit
                          ? Icons.arrow_downward_rounded
                          : (isDebit
                                ? Icons.arrow_upward_rounded
                                : Icons.notifications_active_rounded);

                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          if (!isRead) {
                            docSnap.reference
                                .update({'isRead': true})
                                .catchError((_) {});
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isRead
                                ? cardBg
                                : (isDark
                                      ? const Color(0xFF1F2937)
                                      : const Color(0xFFF0FDF4)),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isRead
                                  ? borderColor
                                  : AppColors.brand.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: iconBg,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  iconData,
                                  color: iconColor,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            title,
                                            style: TextStyle(
                                              fontWeight: isRead
                                                  ? FontWeight.w600
                                                  : FontWeight.w800,
                                              fontSize: 15,
                                              color: primaryTextColor,
                                            ),
                                          ),
                                        ),
                                        if (!isRead)
                                          Container(
                                            width: 8,
                                            height: 8,
                                            decoration: const BoxDecoration(
                                              color: AppColors.brand,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      body,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        color: isDark
                                            ? AppColors.textSecondaryDark
                                            : const Color(0xFF4B5563),
                                        height: 1.35,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _formatDate(createdAt),
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: isDark
                                            ? AppColors.textSecondaryDark
                                            : const Color(0xFF9CA3AF),
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
              ),
      ),
    );
  }
}
