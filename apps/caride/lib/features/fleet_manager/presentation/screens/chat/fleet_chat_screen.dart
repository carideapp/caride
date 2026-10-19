import 'package:caride/features/chat/data/chat_repository.dart';
import 'package:caride/features/fleet_manager/presentation/widgets/fleet_bottom_nav.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'fleet_conversation_screen.dart';

/// Top-level Fleet Manager Chat List Screen redesigned strictly matching the attached Messages UI,
/// with flat list items, circular back button, pill search, pill tabs ("All", "Unread"), and CaRide brand green accents.
class FleetChatScreen extends StatefulWidget {
  const FleetChatScreen({super.key});

  @override
  State<FleetChatScreen> createState() => _FleetChatScreenState();
}

class _FleetChatScreenState extends State<FleetChatScreen>
    with SingleTickerProviderStateMixin {
  final ChatRepository _repository = ChatRepository();
  late final TabController _tabController;
  int _selectedTabIndex = 0; // 0 = All, 1 = Unread
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_selectedTabIndex != _tabController.index) {
        setState(() {
          _selectedTabIndex = _tabController.index;
        });
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  String _formatTimestamp(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return DateFormat('h:mm a').format(dt);
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return DateFormat('EEE').format(dt);
    return DateFormat('MMM d').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor =
        isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);
    final borderColor =
        isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);
    final inputFill =
        isDark ? AppColors.darkSurface : const Color(0xFFF9FAFB);
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      extendBody: true,
      bottomNavigationBar: FleetBottomNav(currentIndex: 2),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Bar with Circular Back Button & Centered Title ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
              child: Row(
                children: [
                  if (canPop)
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? AppColors.darkSurface : Colors.white,
                          border: Border.all(color: borderColor),
                        ),
                        child: Icon(
                          Icons.arrow_back_rounded,
                          size: 20,
                          color: primaryTextColor,
                        ),
                      ),
                    )
                  else
                    const SizedBox(width: 44),
                  Expanded(
                    child: Center(
                      child: Text(
                        'Messages',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: primaryTextColor,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),

            // ── Pill Search Field ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 6.0),
              child: TextFormField(
                controller: _searchController,
                style: TextStyle(color: primaryTextColor, fontSize: 14),
                onChanged: (val) => setState(() => _searchQuery = val.trim()),
                decoration: InputDecoration(
                  hintText: 'Search messages..',
                  hintStyle: TextStyle(
                    color: secondaryTextColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                  filled: true,
                  fillColor: inputFill,
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: secondaryTextColor,
                    size: 20,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          child: Icon(
                            Icons.close_rounded,
                            color: secondaryTextColor,
                            size: 18,
                          ),
                        )
                      : null,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
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
                    borderSide:
                        const BorderSide(color: AppColors.brand, width: 1.5),
                  ),
                ),
              ),
            ),

            // ── Chat List Stream ───────────────────────────────────────────
            Expanded(
              child: StreamBuilder<List<ChatThread>>(
                stream: _repository.watchThreads(filterType: 'rental'),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.brand,
                        strokeWidth: 2.5,
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Unable to load messages right now.',
                        style: TextStyle(color: secondaryTextColor, fontSize: 14),
                      ),
                    );
                  }

                  final allThreads = snapshot.data ?? [];
                  final unreadThreads =
                      allThreads.where((t) => t.unread > 0).toList();
                  final totalUnread =
                      allThreads.fold<int>(0, (sum, t) => sum + t.unread);

                  final activeList =
                      _selectedTabIndex == 0 ? allThreads : unreadThreads;

                  final filtered = activeList.where((t) {
                    if (_searchQuery.isEmpty) return true;
                    final query = _searchQuery.toLowerCase();
                    final nameMatch = t.name.toLowerCase().contains(query);
                    final vehicleMatch =
                        (t.vehicleTitle ?? '').toLowerCase().contains(query);
                    final previewMatch =
                        t.preview.toLowerCase().contains(query);
                    return nameMatch || vehicleMatch || previewMatch;
                  }).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Pill Segment Tabs (All, Unread) ──────────────────
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20.0, vertical: 8.0),
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppColors.darkSurface
                                : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(28),
                          ),
                          child: TabBar(
                            controller: _tabController,
                            indicator: BoxDecoration(
                              color: AppColors.brand,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            indicatorSize: TabBarIndicatorSize.tab,
                            dividerColor: Colors.transparent,
                            labelColor: Colors.white,
                            labelStyle: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                            unselectedLabelColor: isDark
                                ? AppColors.textSecondaryDark
                                : const Color(0xFF6B7280),
                            unselectedLabelStyle: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13.5,
                            ),
                            tabs: [
                              Tab(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('All Messages'),
                                    if (allThreads.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: _selectedTabIndex == 0
                                              ? Colors.white.withValues(alpha: 0.25)
                                              : (isDark
                                                  ? Colors.white12
                                                  : Colors.black12),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '${allThreads.length}',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                            color: _selectedTabIndex == 0
                                                ? Colors.white
                                                : secondaryTextColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              Tab(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('Unread'),
                                    if (totalUnread > 0) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: _selectedTabIndex == 1
                                              ? Colors.white.withValues(alpha: 0.25)
                                              : AppColors.brand,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '$totalUnread',
                                          style: const TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w800,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── Section Title "Messages" ──────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
                        child: Text(
                          'Messages',
                          style: TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                            color: primaryTextColor,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),

                      // ── Flat Conversations List ───────────────────────────
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 32.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 76,
                                        height: 76,
                                        decoration: BoxDecoration(
                                          color: AppColors.brand
                                              .withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.chat_bubble_outline_rounded,
                                          color: AppColors.brand,
                                          size: 38,
                                        ),
                                      ),
                                      const SizedBox(height: 18),
                                      Text(
                                        _searchQuery.isNotEmpty
                                            ? 'No Matching Messages'
                                            : 'No Conversations Yet',
                                        style: TextStyle(
                                          fontSize: 16.5,
                                          fontWeight: FontWeight.w700,
                                          color: primaryTextColor,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _searchQuery.isNotEmpty
                                            ? 'Try searching with a different customer name or vehicle title.'
                                            : 'When customers book your rental vehicles, your conversations will appear here in real time.',
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
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.only(bottom: 96),
                                itemCount: filtered.length,
                                separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: isDark
                                      ? AppColors.glassBorderDark
                                      : const Color(0xFFF3F4F6),
                                ),
                                itemBuilder: (context, index) {
                                  final thread = filtered[index];
                                  final hasUnread = thread.unread > 0;
                                  final photoUrl = thread.peerPhoto ?? '';

                                  return InkWell(
                                    onTap: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              FleetConversationScreen(
                                            threadId: thread.rideId,
                                            customerName: thread.name,
                                            customerUid: thread.driverUid,
                                            vehicleTitle: thread.vehicleTitle,
                                            bookingId: thread.bookingId,
                                          ),
                                        ),
                                      );
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 20.0, vertical: 14.0),
                                      child: Row(
                                        children: [
                                          // Circular Customer Avatar
                                          CircleAvatar(
                                            radius: 25,
                                            backgroundColor: AppColors.brand
                                                .withValues(alpha: 0.1),
                                            backgroundImage: photoUrl.isNotEmpty
                                                ? NetworkImage(photoUrl)
                                                : null,
                                            child: photoUrl.isEmpty
                                                ? Text(
                                                    thread.name.trim().isNotEmpty
                                                        ? thread.name
                                                            .trim()
                                                            .substring(0, 1)
                                                            .toUpperCase()
                                                        : 'C',
                                                    style: const TextStyle(
                                                      fontSize: 17,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: AppColors.brand,
                                                    ),
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(width: 14),
                                          // Center details
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                // Top Row: Name + Verified Badge + Timestamp
                                                Row(
                                                  children: [
                                                    Flexible(
                                                      child: Text(
                                                        thread.name,
                                                        style: TextStyle(
                                                          fontSize: 15.5,
                                                          fontWeight: hasUnread
                                                              ? FontWeight.w700
                                                              : FontWeight.w600,
                                                          color:
                                                              primaryTextColor,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 5),
                                                    const Icon(
                                                      Icons.verified_rounded,
                                                      size: 16,
                                                      color: AppColors.brand,
                                                    ),
                                                    const Spacer(),
                                                    Text(
                                                      _formatTimestamp(
                                                          thread.timestamp),
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        color:
                                                            secondaryTextColor,
                                                        fontWeight:
                                                            FontWeight.w400,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 3),
                                                // Bottom Row: Preview Message + Unread Badge Pill
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        thread.preview,
                                                        style: TextStyle(
                                                          fontSize: 13.5,
                                                          color: hasUnread
                                                              ? (isDark
                                                                  ? Colors.white
                                                                  : const Color(
                                                                      0xFF1F2937))
                                                              : secondaryTextColor,
                                                          fontWeight: hasUnread
                                                              ? FontWeight.w600
                                                              : FontWeight.w400,
                                                        ),
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                      ),
                                                    ),
                                                    if (hasUnread) ...[
                                                      const SizedBox(width: 8),
                                                      Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 7,
                                                                vertical: 2.5),
                                                        decoration:
                                                            BoxDecoration(
                                                          color:
                                                              AppColors.brand,
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(12),
                                                        ),
                                                        constraints:
                                                            const BoxConstraints(
                                                                minWidth: 20),
                                                        alignment:
                                                            Alignment.center,
                                                        child: Text(
                                                          '${thread.unread}',
                                                          style:
                                                              const TextStyle(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            fontSize: 11,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
