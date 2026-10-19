import 'package:caride/features/car_rental/data/customer_rental_repository.dart';
import 'package:caride/features/chat/conversation_screen.dart';
import 'package:caride/features/chat/data/chat_repository.dart';
import 'package:caride/features/profile/data/driver_public_profile_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_models/shared_models.dart';

/// Customer Chat List Screen redesigned strictly matching the attached Messages UI,
/// incorporating CaRide brand emerald tokens, pill geometry, flat aesthetic (no shadows),
/// and segmented tabs for Drivers and Fleet Partners.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final ChatRepository _repository = ChatRepository();
  final DriverPublicProfileRepository _driverProfileRepo =
      DriverPublicProfileRepository();
  final CustomerRentalRepository _customerRentalRepo =
      CustomerRentalRepository();

  late final TabController _tabController;
  int _selectedTabIndex = 0; // 0 = Drivers, 1 = Fleet Partners
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
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Header Bar with Circular Back Button & Centered Title ──
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
                  const SizedBox(width: 44), // Balances the circular back button
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

            // ── Live Stream & Tabs ─────────────────────────────────────────
            Expanded(
              child: StreamBuilder<List<ChatThread>>(
                stream: _repository.watchThreads(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Unable to load chats right now.',
                        style: TextStyle(color: secondaryTextColor, fontSize: 14),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.brand,
                        strokeWidth: 2.5,
                      ),
                    );
                  }

                  final allThreads = snapshot.data!;
                  final driverThreads =
                      allThreads.where((t) => t.type != 'rental').toList();
                  final fleetThreads =
                      allThreads.where((t) => t.type == 'rental').toList();

                  final unreadDrivers =
                      driverThreads.fold<int>(0, (sum, t) => sum + t.unread);
                  final unreadFleet =
                      fleetThreads.fold<int>(0, (sum, t) => sum + t.unread);

                  final activeList =
                      _selectedTabIndex == 0 ? driverThreads : fleetThreads;
                  final filteredList = activeList.where((t) {
                    if (_searchQuery.isEmpty) return true;
                    final query = _searchQuery.toLowerCase();
                    final nameMatch = t.name.toLowerCase().contains(query);
                    final previewMatch =
                        t.preview.toLowerCase().contains(query);
                    final vehicleMatch =
                        (t.vehicleTitle ?? '').toLowerCase().contains(query);
                    return nameMatch || previewMatch || vehicleMatch;
                  }).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Pill Segment Tabs (Flat, Brand Emerald Active) ────
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
                                    const Text('Drivers'),
                                    if (unreadDrivers > 0) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: _selectedTabIndex == 0
                                              ? Colors.white.withValues(alpha: 0.25)
                                              : AppColors.brand,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Text(
                                          '$unreadDrivers',
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
                              Tab(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text('Fleet Partners'),
                                    if (unreadFleet > 0) ...[
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
                                          '$unreadFleet',
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

                      // ── Chat List ─────────────────────────────────────────
                      Expanded(
                        child: filteredList.isEmpty
                            ? _buildEmptyState(
                                isDark: isDark,
                                primaryText: primaryTextColor,
                                secondaryText: secondaryTextColor,
                                isSearching: _searchQuery.isNotEmpty,
                                isFleetTab: _selectedTabIndex == 1,
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.only(bottom: 24),
                                itemCount: filteredList.length,
                                separatorBuilder: (_, __) => Divider(
                                  height: 1,
                                  thickness: 1,
                                  color: isDark
                                      ? AppColors.glassBorderDark
                                      : const Color(0xFFF3F4F6),
                                ),
                                itemBuilder: (context, index) {
                                  final thread = filteredList[index];
                                  final isRental = thread.type == 'rental';

                                  if (isRental) {
                                    return _buildFleetThreadItem(
                                      context: context,
                                      thread: thread,
                                      isDark: isDark,
                                      primaryTextColor: primaryTextColor,
                                      secondaryTextColor: secondaryTextColor,
                                    );
                                  } else {
                                    return _buildDriverThreadItem(
                                      context: context,
                                      thread: thread,
                                      isDark: isDark,
                                      primaryTextColor: primaryTextColor,
                                      secondaryTextColor: secondaryTextColor,
                                    );
                                  }
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

  // ── Driver Thread Item (Flat list row matching reference UI) ─────────────

  Widget _buildDriverThreadItem({
    required BuildContext context,
    required ChatThread thread,
    required bool isDark,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    return StreamBuilder<DriverPublicProfile?>(
      stream: thread.driverUid.isEmpty
          ? Stream.value(null)
          : _driverProfileRepo.watchDriver(thread.driverUid),
      builder: (context, profileSnap) {
        final profile = profileSnap.data;
        final photoUrl = profile?.profilePhotoUrl ?? '';
        final name = (profile?.fullName.trim().isNotEmpty ?? false)
            ? profile!.fullName
            : thread.name;
        const isVerified = true;
        final hasUnread = thread.unread > 0;

        return InkWell(
          onTap: () {
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                builder: (_) => ConversationScreen(
                  rideId: thread.rideId,
                  driverName: name,
                  driverUid: thread.driverUid,
                  isFleet: false,
                  vehicleTitle: thread.vehicleTitle,
                  peerPhoto: photoUrl,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
            child: Row(
              children: [
                // Circular Avatar
                CircleAvatar(
                  radius: 25,
                  backgroundColor: AppColors.brand.withValues(alpha: 0.1),
                  backgroundImage:
                      photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                  child: photoUrl.isEmpty
                      ? Text(
                          name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'D',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                            color: AppColors.brand,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                // Center details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Name + Verified Badge (Left) & Timestamp (Right)
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: hasUnread
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      color: primaryTextColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isVerified) ...[
                                  const SizedBox(width: 5),
                                  const Icon(
                                    Icons.verified_rounded,
                                    size: 16,
                                    color: AppColors.brand,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTimestamp(thread.timestamp),
                            style: TextStyle(
                              fontSize: 12,
                              color: secondaryTextColor,
                              fontWeight: FontWeight.w400,
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
                                    ? (isDark ? Colors.white : const Color(0xFF1F2937))
                                    : secondaryTextColor,
                                fontWeight: hasUnread
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasUnread) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: AppColors.brand,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              constraints: const BoxConstraints(minWidth: 20),
                              alignment: Alignment.center,
                              child: Text(
                                '${thread.unread}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
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
    );
  }

  // ── Fleet Manager Thread Item (Flat list row matching reference UI) ──────

  Widget _buildFleetThreadItem({
    required BuildContext context,
    required ChatThread thread,
    required bool isDark,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    return FutureBuilder<FleetProfile?>(
      future: (thread.peerPhoto != null && thread.peerPhoto!.isNotEmpty)
          ? Future.value(null)
          : _customerRentalRepo.getFleetProfile(
              fleetId: thread.fleetId,
              ownerUid: thread.driverUid,
            ),
      builder: (context, fleetSnap) {
        final fleetProfile = fleetSnap.data;
        final photoUrl = (thread.peerPhoto != null && thread.peerPhoto!.isNotEmpty)
            ? thread.peerPhoto!
            : (fleetProfile?.logoUrl ??
                fleetProfile?.profilePictureUrl ??
                fleetProfile?.coverPhotoUrl ??
                '');
        final name = (thread.name.isNotEmpty && thread.name != 'Fleet Partner')
            ? thread.name
            : (fleetProfile?.businessName.isNotEmpty == true
                ? fleetProfile!.businessName
                : (thread.name.isNotEmpty ? thread.name : 'Fleet Partner'));
        final isVerified = fleetProfile?.isVerified ?? true;
        final hasUnread = thread.unread > 0;

        return InkWell(
          onTap: () {
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                builder: (_) => ConversationScreen(
                  rideId: thread.rideId,
                  driverName: name,
                  driverUid: thread.driverUid,
                  isFleet: true,
                  vehicleTitle: thread.vehicleTitle,
                  peerPhoto: photoUrl,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 14.0),
            child: Row(
              children: [
                // Circular Avatar
                CircleAvatar(
                  radius: 25,
                  backgroundColor: AppColors.brand.withValues(alpha: 0.1),
                  backgroundImage:
                      photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                  child: photoUrl.isEmpty
                      ? Text(
                          name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'F',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                            color: AppColors.brand,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 14),
                // Center details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Name + Verified Badge (Left) & Timestamp (Right)
                      Row(
                        children: [
                          Expanded(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    name,
                                    style: TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: hasUnread
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                      color: primaryTextColor,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isVerified) ...[
                                  const SizedBox(width: 5),
                                  const Icon(
                                    Icons.verified_rounded,
                                    size: 16,
                                    color: AppColors.brand,
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatTimestamp(thread.timestamp),
                            style: TextStyle(
                              fontSize: 12,
                              color: secondaryTextColor,
                              fontWeight: FontWeight.w400,
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
                                    ? (isDark ? Colors.white : const Color(0xFF1F2937))
                                    : secondaryTextColor,
                                fontWeight: hasUnread
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasUnread) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2.5),
                              decoration: BoxDecoration(
                                color: AppColors.brand,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              constraints: const BoxConstraints(minWidth: 20),
                              alignment: Alignment.center,
                              child: Text(
                                '${thread.unread}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
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
    );
  }

  // ── Contextual Empty State ───────────────────────────────────────────────

  Widget _buildEmptyState({
    required bool isDark,
    required Color primaryText,
    required Color secondaryText,
    required bool isSearching,
    required bool isFleetTab,
  }) {
    if (isSearching) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : const Color(0xFFF3F4F6),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.search_off_rounded,
                    size: 34, color: secondaryText),
              ),
              const SizedBox(height: 16),
              Text(
                'No Matching Messages',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Try searching with a different name or keyword.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: secondaryText),
              ),
            ],
          ),
        ),
      );
    }

    final title =
        isFleetTab ? 'No Fleet Conversations Yet' : 'No Driver Chats Yet';
    final desc = isFleetTab
        ? 'When you message a fleet partner or book a rental, your chats will appear here in real time.'
        : 'Book a ride or request a chauffeur to start chatting with your driver.';

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline_rounded,
                size: 38,
                color: AppColors.brand,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                color: primaryText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              desc,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: secondaryText,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
