import 'dart:async';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:shared_models/shared_models.dart';
import 'package:caride/features/fleet_manager/controllers/fleet_manager_controller.dart';

/// Dedicated screen for Fleet Managers to search and add platform drivers to their fleet.
class SearchAddDriverScreen extends StatefulWidget {
  const SearchAddDriverScreen({
    super.key,
    this.onDriverLinked,
  });

  final void Function(FleetDriver driver)? onDriverLinked;

  @override
  State<SearchAddDriverScreen> createState() => _SearchAddDriverScreenState();
}

class _SearchAddDriverScreenState extends State<SearchAddDriverScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _debounceTimer;

  bool _isSearching = false;
  bool _isLinking = false;
  String _errorMessage = '';
  List<Map<String, dynamic>> _searchResults = [];

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _executeSearch(query);
    });
  }

  Future<void> _executeSearch(String query) async {
    _debounceTimer?.cancel();
    final term = query.trim();
    if (term.isEmpty) {
      if (mounted) {
        setState(() {
          _isSearching = false;
          _errorMessage = '';
          _searchResults = [];
        });
      }
      return;
    }

    if (!mounted) return;
    setState(() {
      _isSearching = true;
      _errorMessage = '';
    });

    try {
      final results = await fleetManagerController.searchDriversFromPlatform(term);
      if (!mounted) return;
      setState(() {
        _searchResults = List<Map<String, dynamic>>.from(results);
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Search failed. Please try again.';
        _isSearching = false;
      });
    }
  }

  Future<void> _selectDriver(Map<String, dynamic> rawDriver) async {
    final driverUid = (rawDriver['uid'] ?? rawDriver['id'] ?? '').toString();
    final fullName = (rawDriver['fullName'] ?? rawDriver['name'] ?? 'Driver').toString();
    final phone = (rawDriver['phoneNumber'] ?? rawDriver['phone'] ?? '').toString().trim();
    final email = (rawDriver['email'] ?? '').toString().trim();
    final username = rawDriver['username']?.toString();
    final photoUrl = (rawDriver['profilePictureUrl'] ?? rawDriver['photoUrl'])?.toString();

    final alreadyLinked = fleetManagerController.drivers.any(
      (d) => d.id == driverUid || d.driverUid == driverUid,
    );
    if (alreadyLinked) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$fullName is already linked to your fleet.'),
            backgroundColor: const Color(0xFFF59E0B),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
      return;
    }

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => _ConfirmLinkModal(
        fullName: fullName,
        phone: phone,
        email: email,
        username: username,
        photoUrl: photoUrl,
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLinking = true);

      try {
        await fleetManagerController.linkDriverToFleet(
          driverUid: driverUid,
          fullName: fullName,
          phone: phone,
          email: email,
          username: username,
          photoUrl: photoUrl,
        );

        final newDriver = FleetDriver(
          id: driverUid,
          driverUid: driverUid,
          fullName: fullName,
          phone: phone,
          email: email,
          licenseNumber: rawDriver['driverLicenseNumber']?.toString() ?? '',
          photoUrl: photoUrl,
          username: username,
          status: FleetDriverStatus.active,
          joinedAt: DateTime.now(),
        );

        widget.onDriverLinked?.call(newDriver);

        if (mounted) {
          setState(() => _isLinking = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$fullName linked to your fleet successfully!'),
              backgroundColor: AppColors.brand,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          );
          Navigator.of(context).pop(newDriver);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLinking = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to link driver. Please try again.'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      // Critical: don't resize, we handle keyboard height manually
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ──── App Bar ────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Center(
                        child: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: primaryTextColor),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Search & Add Driver',
                          style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: primaryTextColor),
                        ),
                        Text(
                          'Find verified drivers to link to your fleet',
                          style: TextStyle(fontSize: 12, color: secondaryTextColor),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ──── Search Input (login-style: label above + flat pill field) ────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Driver Username / Email / Phone',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 58,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: TextField(
                      controller: _searchController,
                      textInputAction: TextInputAction.search,
                      cursorColor: AppColors.brand,
                      autofocus: true,
                      style: TextStyle(fontSize: 15, color: primaryTextColor),
                      decoration: InputDecoration(
                        hintText: 'e.g. @username, email, or phone',
                        hintStyle: TextStyle(
                          color: secondaryTextColor.withValues(alpha: 0.8),
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  _executeSearch('');
                                },
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 14),
                                  child: Icon(Icons.close_rounded, size: 20, color: secondaryTextColor),
                                ),
                              )
                            : null,
                        suffixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                      ),
                      onChanged: _onSearchChanged,
                      onSubmitted: (v) => _executeSearch(v),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ──── Linking progress ────
            if (_isLinking)
              LinearProgressIndicator(
                minHeight: 3,
                backgroundColor: AppColors.brand.withValues(alpha: 0.15),
                valueColor: const AlwaysStoppedAnimation<Color>(AppColors.brand),
              ),

            // ──── Error banner ────
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF450A0A) : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_errorMessage, style: const TextStyle(color: AppColors.error, fontSize: 13))),
                      GestureDetector(
                        onTap: () => setState(() => _errorMessage = ''),
                        child: const Icon(Icons.close_rounded, size: 16, color: AppColors.error),
                      ),
                    ],
                  ),
                ),
              ),

            // ──── Main content — fills remaining space ────
            Expanded(
              child: _buildContent(context, isDark, primaryTextColor, secondaryTextColor, keyboardHeight),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    bool isDark,
    Color primaryTextColor,
    Color secondaryTextColor,
    double keyboardHeight,
  ) {
    // Searching spinner
    if (_isSearching) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.brand),
              ),
            ),
            const SizedBox(height: 14),
            Text('Searching drivers...', style: TextStyle(fontSize: 14, color: secondaryTextColor)),
          ],
        ),
      );
    }

    final query = _searchController.text.trim();

    // Empty query — show hint
    if (query.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 16, 24, keyboardHeight + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_search_rounded, size: 52, color: AppColors.brand),
              ),
              const SizedBox(height: 18),
              Text(
                'Search Driver to Link',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: primaryTextColor),
              ),
              const SizedBox(height: 8),
              Text(
                'Type a username (@username), email address, or phone number.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: secondaryTextColor, height: 1.4),
              ),
            ],
          ),
        ),
      );
    }

    // No results
    if (_searchResults.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.fromLTRB(24, 16, 24, keyboardHeight + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off_rounded, size: 52, color: Color(0xFF9CA3AF)),
              const SizedBox(height: 14),
              Text(
                'No drivers found for "$query"',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: primaryTextColor),
              ),
              const SizedBox(height: 6),
              Text(
                'Check the username, email, or phone and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: secondaryTextColor),
              ),
            ],
          ),
        ),
      );
    }

    // Results list — use SingleChildScrollView+Column (always works)
    return SingleChildScrollView(
      controller: _scrollController,
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: EdgeInsets.fromLTRB(16, 8, 16, keyboardHeight + 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Matching Drivers (${_searchResults.length})',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: secondaryTextColor),
              ),
              GestureDetector(
                onTap: () {
                  _searchController.clear();
                  _executeSearch('');
                },
                child: const Text(
                  'Clear',
                  style: TextStyle(fontSize: 13, color: AppColors.brand, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Driver cards
          for (final raw in _searchResults)
            _DriverResultCard(
              raw: raw,
              isDark: isDark,
              primaryTextColor: primaryTextColor,
              secondaryTextColor: secondaryTextColor,
              onSelect: _selectDriver,
            ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Extracted stateless driver result card — avoids any layout issues
// ──────────────────────────────────────────────────────────────────────────────
class _DriverResultCard extends StatelessWidget {
  const _DriverResultCard({
    required this.raw,
    required this.isDark,
    required this.primaryTextColor,
    required this.secondaryTextColor,
    required this.onSelect,
  });

  final Map<String, dynamic> raw;
  final bool isDark;
  final Color primaryTextColor;
  final Color secondaryTextColor;
  final Future<void> Function(Map<String, dynamic>) onSelect;

  @override
  Widget build(BuildContext context) {
    final uid = (raw['uid'] ?? raw['id'] ?? '').toString();
    final rawName = raw['fullName'] ?? raw['name'] ?? raw['displayName'];
    final name = (rawName != null && rawName.toString().trim().isNotEmpty && rawName.toString() != 'null')
        ? rawName.toString().trim()
        : 'Driver';
    final phone = (raw['phoneNumber'] ?? raw['phone'] ?? '').toString().trim();
    final email = (raw['email'] ?? '').toString().trim();
    final rawUsername = raw['username'];
    final username = (rawUsername != null &&
            rawUsername.toString().trim().isNotEmpty &&
            rawUsername.toString() != 'null')
        ? rawUsername.toString().trim().replaceAll('@', '')
        : null;
    final photoUrl = (raw['profilePictureUrl'] ?? raw['photoUrl'])?.toString().trim();
    final hasPhoto = photoUrl != null &&
        photoUrl.isNotEmpty &&
        photoUrl != 'null' &&
        (photoUrl.startsWith('http://') || photoUrl.startsWith('https://'));

    final alreadyInFleet = fleetManagerController.drivers.any((d) => d.id == uid || d.driverUid == uid);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Avatar
          Container(
            width: 50,
            height: 50,
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.brand.withValues(alpha: 0.15),
            ),
            child: hasPhoto
                ? Image.network(
                    photoUrl,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _initials(name),
                  )
                : _initials(name),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: primaryTextColor),
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.verified_rounded, color: AppColors.brand, size: 14),
                  ],
                ),
                if (username != null && username.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    '@$username',
                    style: const TextStyle(fontSize: 12, color: AppColors.brand, fontWeight: FontWeight.w700),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  phone.isNotEmpty ? phone : (email.isNotEmpty ? email : 'Platform Driver'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: secondaryTextColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Action
          if (alreadyInFleet)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_rounded, size: 13, color: AppColors.brand),
                  SizedBox(width: 3),
                  Text('Linked', style: TextStyle(color: AppColors.brand, fontWeight: FontWeight.w700, fontSize: 12)),
                ],
              ),
            )
          else
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => onSelect(raw),
              child: const Text('Select', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            ),
        ],
      ),
    );
  }

  Widget _initials(String name) {
    return Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : 'D',
        style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.bold, fontSize: 18),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Confirmation bottom sheet
// ──────────────────────────────────────────────────────────────────────────────
class _ConfirmLinkModal extends StatelessWidget {
  const _ConfirmLinkModal({
    required this.fullName,
    required this.phone,
    required this.email,
    this.username,
    this.photoUrl,
  });

  final String fullName;
  final String phone;
  final String email;
  final String? username;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);
    final hasPhoto = photoUrl != null &&
        photoUrl!.isNotEmpty &&
        (photoUrl!.startsWith('http://') || photoUrl!.startsWith('https://'));

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.fromLTRB(
        24, 16, 24,
        MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          Center(
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.person_add_alt_1_rounded, size: 32, color: AppColors.brand),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Confirm Link Driver',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: primaryTextColor),
          ),
          const SizedBox(height: 5),
          Text(
            'Add this driver to your fleet?',
            style: TextStyle(fontSize: 13, color: secondaryTextColor),
          ),
          const SizedBox(height: 18),

          // Driver preview
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBackground : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.brand.withValues(alpha: 0.15),
                  ),
                  child: hasPhoto
                      ? Image.network(photoUrl!, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Center(
                            child: Text(
                              fullName.isNotEmpty ? fullName[0].toUpperCase() : 'D',
                              style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ))
                      : Center(
                          child: Text(
                            fullName.isNotEmpty ? fullName[0].toUpperCase() : 'D',
                            style: const TextStyle(color: AppColors.brand, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: primaryTextColor),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded, color: AppColors.brand, size: 14),
                        ],
                      ),
                      if (username != null && username!.isNotEmpty) ...[
                        Text(
                          '@${username!.replaceAll('@', '')}',
                          style: const TextStyle(fontSize: 12, color: AppColors.brand, fontWeight: FontWeight.w600),
                        ),
                      ],
                      Text(
                        phone.isNotEmpty ? phone : email,
                        style: TextStyle(fontSize: 12, color: secondaryTextColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Notice
          Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.brand.withValues(alpha: 0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.notifications_active_outlined, color: AppColors.brand, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'The driver will receive a push notification that they\'ve been linked to your fleet.',
                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : const Color(0xFF374151), height: 1.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.brand,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Confirm & Link Driver', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6B7280),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              ),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
