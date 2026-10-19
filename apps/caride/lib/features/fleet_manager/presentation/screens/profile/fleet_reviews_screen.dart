import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:design_system/design_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_widgets/shared_widgets.dart';

import 'package:caride/features/fleet_manager/auth/controllers/fleet_auth_controller.dart';

/// Screen allowing Fleet Managers to view ratings & reviews made by customers on their vehicles.
class FleetReviewsScreen extends StatefulWidget {
  const FleetReviewsScreen({super.key});

  @override
  State<FleetReviewsScreen> createState() => _FleetReviewsScreenState();
}

class _FleetReviewsScreenState extends State<FleetReviewsScreen> {
  int _selectedStarFilter = 0; // 0 = All, 5, 4, 3, 2, 1
  Stream<List<RentalReview>>? _reviewsStream;
  String _lastCandidateKey = '';

  @override
  void initState() {
    super.initState();
    _initReviewsStream();
  }

  void _initReviewsStream() {
    final authUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final profile = fleetAuthController.currentProfile;
    final fleetId = profile?.fleetId ?? '';
    final ownerUid = profile?.ownerUid ?? '';

    final candidateSet = <String>{
      if (fleetId.isNotEmpty) fleetId,
      if (ownerUid.isNotEmpty) ownerUid,
      if (authUid.isNotEmpty) authUid,
    };

    final candidateKey = candidateSet.join(',');
    if (candidateKey == _lastCandidateKey && _reviewsStream != null) return;
    _lastCandidateKey = candidateKey;

    _reviewsStream = _createCombinedReviewsStream(candidateSet.toList());
  }

  Stream<List<RentalReview>> _createCombinedReviewsStream(List<String> candidateIds) {
    if (candidateIds.isEmpty) {
      return Stream.value(const []);
    }

    final StreamController<List<RentalReview>> controller =
        StreamController<List<RentalReview>>.broadcast();
    final List<StreamSubscription> subs = [];
    final Map<String, RentalReview> reviewsMap = {};

    void emitLatest() {
      final list = reviewsMap.values.toList();
      list.sort((a, b) {
        final tA = a.createdAt ?? DateTime(2020);
        final tB = b.createdAt ?? DateTime(2020);
        return tB.compareTo(tA);
      });
      if (!controller.isClosed) {
        controller.add(list);
      }
    }

    // 1. Listen to rental_reviews for each candidate fleetId
    for (final cId in candidateIds) {
      subs.add(
        FirebaseFirestore.instance
            .collection('rental_reviews')
            .where('fleetId', isEqualTo: cId)
            .snapshots()
            .listen((snap) {
          for (final doc in snap.docs) {
            final review = RentalReview.fromMap(doc.data(), doc.id);
            reviewsMap[review.id] = review;
          }
          emitLatest();
        }, onError: (_) {}),
      );
    }

    // 2. Listen to rental_vehicles for candidate IDs to get vehicle IDs, then listen to rental_reviews by vehicleId
    for (final cId in candidateIds) {
      subs.add(
        FirebaseFirestore.instance
            .collection('rental_vehicles')
            .where('fleetId', isEqualTo: cId)
            .snapshots()
            .listen((vehSnap) {
          for (final vDoc in vehSnap.docs) {
            final vId = vDoc.id;
            subs.add(
              FirebaseFirestore.instance
                  .collection('rental_reviews')
                  .where('vehicleId', isEqualTo: vId)
                  .snapshots()
                  .listen((revSnap) {
                for (final doc in revSnap.docs) {
                  final review = RentalReview.fromMap(doc.data(), doc.id);
                  reviewsMap[review.id] = review;
                }
                emitLatest();
              }, onError: (_) {}),
            );
          }
        }, onError: (_) {}),
      );

      subs.add(
        FirebaseFirestore.instance
            .collection('rental_vehicles')
            .where('ownerUid', isEqualTo: cId)
            .snapshots()
            .listen((vehSnap) {
          for (final vDoc in vehSnap.docs) {
            final vId = vDoc.id;
            subs.add(
              FirebaseFirestore.instance
                  .collection('rental_reviews')
                  .where('vehicleId', isEqualTo: vId)
                  .snapshots()
                  .listen((revSnap) {
                for (final doc in revSnap.docs) {
                  final review = RentalReview.fromMap(doc.data(), doc.id);
                  reviewsMap[review.id] = review;
                }
                emitLatest();
              }, onError: (_) {}),
            );
          }
        }, onError: (_) {}),
      );
    }

    // 3. Listen to rental_bookings for candidate IDs as fallback
    for (final cId in candidateIds) {
      subs.add(
        FirebaseFirestore.instance
            .collection('rental_bookings')
            .where('fleetId', isEqualTo: cId)
            .snapshots()
            .listen((bookSnap) {
          for (final doc in bookSnap.docs) {
            final data = doc.data();
            final isRated = data['isRated'] == true;
            final rating = (data['rating'] as num?)?.toDouble() ?? 0.0;
            if (isRated || rating > 0) {
              final reviewId = doc.id;
              if (!reviewsMap.containsKey(reviewId) &&
                  !reviewsMap.values.any((r) => r.bookingId == doc.id)) {
                DateTime? created;
                final c = data['updatedAt'] ?? data['createdAt'];
                if (c is String) {
                  created = DateTime.tryParse(c);
                }
                final fallbackReview = RentalReview(
                  id: reviewId,
                  bookingId: doc.id,
                  vehicleId: (data['vehicleId'] as String?) ?? '',
                  vehicleTitle: (data['vehicleTitle'] as String?) ??
                      (data['vehicleName'] as String?) ??
                      'Rental Vehicle',
                  customerId: (data['customerId'] as String?) ?? '',
                  customerName: (data['customerName'] as String?) ?? 'Customer',
                  customerPhoto: data['customerPhoto'] as String?,
                  fleetId: (data['fleetId'] as String?) ?? cId,
                  rating: rating > 0 ? rating : 5.0,
                  comment: (data['reviewComment'] as String?) ?? '',
                  createdAt: created ?? DateTime.now(),
                );
                reviewsMap[fallbackReview.id] = fallbackReview;
              }
            }
          }
          emitLatest();
        }, onError: (_) {}),
      );
    }

    controller.onCancel = () {
      for (final s in subs) {
        s.cancel();
      }
    };

    return controller.stream;
  }

  Future<void> _toggleLike(RentalReview review) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final uid = user.uid;
    final docRef =
        FirebaseFirestore.instance.collection('rental_reviews').doc(review.id);
    final isLiked = review.likedByUids.contains(uid);

    try {
      if (isLiked) {
        await docRef.update({
          'likedByUids': FieldValue.arrayRemove([uid]),
          'likeCount': FieldValue.increment(-1),
        });
      } else {
        await docRef.update({
          'likedByUids': FieldValue.arrayUnion([uid]),
          'likeCount': FieldValue.increment(1),
        });
      }
    } catch (e) {
      debugPrint('Error toggling review like: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: fleetAuthController,
      builder: (context, _) {
        _initReviewsStream();
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
        final secondaryTextColor =
            isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);
        final currentUid = FirebaseAuth.instance.currentUser?.uid ?? '';
        final dateFormat = DateFormat('MMM dd, yyyy • h:mm a');

        return Scaffold(
          backgroundColor:
              isDark ? AppColors.darkBackground : AppColors.lightBackground,
          body: SafeArea(
            child: Column(
              children: [
                // ── Top Navigation Bar ───────────────────────────────────────────
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.of(context).pop(),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                isDark ? AppColors.darkSurface : Colors.white,
                            border: Border.all(
                              color: isDark
                                  ? AppColors.glassBorderDark
                                  : const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: Icon(
                            Icons.chevron_left_rounded,
                            color: primaryTextColor,
                            size: 26,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            'Ratings & Reviews',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: primaryTextColor,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 44),
                    ],
                  ),
                ),

                // ── Stream Content ───────────────────────────────────────────────
                Expanded(
                  child: StreamBuilder<List<RentalReview>>(
                    stream: _reviewsStream,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          !snapshot.hasData) {
                        return const ReviewsListSkeleton();
                      }

                      final allReviews = snapshot.data ?? [];

                      // Calculate rating metrics
                      double totalRatingSum = 0;
                      final starCounts = <int, int>{5: 0, 4: 0, 3: 0, 2: 0, 1: 0};

                      for (final r in allReviews) {
                        totalRatingSum += r.rating;
                        final roundedStar = r.rating.round().clamp(1, 5);
                        starCounts[roundedStar] = (starCounts[roundedStar] ?? 0) + 1;
                      }

                      final double avgRating = allReviews.isNotEmpty
                          ? totalRatingSum / allReviews.length
                          : 0.0;

                      // Filter reviews by selected star filter
                      final filteredReviews = _selectedStarFilter == 0
                          ? allReviews
                          : allReviews
                              .where((r) => r.rating.round() == _selectedStarFilter)
                              .toList();

                      return CustomScrollView(
                        slivers: [
                          // ── Rating Overview Banner ──────────────────────────────────
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                              child: _buildOverviewHeader(
                                context,
                                avgRating: avgRating,
                                totalCount: allReviews.length,
                                starCounts: starCounts,
                                isDark: isDark,
                                primaryTextColor: primaryTextColor,
                                secondaryTextColor: secondaryTextColor,
                              ),
                            ),
                          ),

                          // ── Filter Chips Row ───────────────────────────────────────
                          if (allReviews.isNotEmpty)
                            SliverToBoxAdapter(
                              child: SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                child: Row(
                                  children: [
                                    _buildFilterChip(
                                      label: 'All (${allReviews.length})',
                                      isSelected: _selectedStarFilter == 0,
                                      onTap: () => setState(() => _selectedStarFilter = 0),
                                      isDark: isDark,
                                    ),
                                    const SizedBox(width: 8),
                                    for (int star = 5; star >= 1; star--) ...[
                                      _buildFilterChip(
                                        label: '$star ★ (${starCounts[star] ?? 0})',
                                        isSelected: _selectedStarFilter == star,
                                        onTap: () => setState(() => _selectedStarFilter = star),
                                        isDark: isDark,
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                  ],
                                ),
                              ),
                            ),

                          // ── Reviews List / Empty State ─────────────────────────────
                          if (filteredReviews.isEmpty)
                            SliverFillRemaining(
                              hasScrollBody: false,
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 72,
                                        height: 72,
                                        decoration: BoxDecoration(
                                          color: AppColors.brand.withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.star_outline_rounded,
                                          size: 36,
                                          color: AppColors.brand,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        _selectedStarFilter == 0
                                            ? 'No Vehicle Reviews Yet'
                                            : 'No $_selectedStarFilter-Star Reviews',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: primaryTextColor,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        _selectedStarFilter == 0
                                            ? 'Customer ratings and reviews for your rental fleet will be displayed here once completed.'
                                            : 'There are currently no reviews matching this rating filter.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: secondaryTextColor,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.all(20),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate(
                                  (context, index) {
                                    final r = filteredReviews[index];
                                    final isLiked = r.likedByUids.contains(currentUid);
                                    return Padding(
                                      padding: const EdgeInsets.only(bottom: 14),
                                      child: _buildReviewCard(
                                        context,
                                        review: r,
                                        isLiked: isLiked,
                                        dateFormat: dateFormat,
                                        isDark: isDark,
                                        primaryTextColor: primaryTextColor,
                                        secondaryTextColor: secondaryTextColor,
                                      ),
                                    );
                                  },
                                  childCount: filteredReviews.length,
                                ),
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
      },
    );
  }

  Widget _buildOverviewHeader(
    BuildContext context, {
    required double avgRating,
    required int totalCount,
    required Map<int, int> starCounts,
    required bool isDark,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          // Large Average Rating Score
          Column(
            children: [
              Text(
                avgRating > 0 ? avgRating.toStringAsFixed(1) : '0.0',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w900,
                  color: primaryTextColor,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(5, (index) {
                  final starVal = index + 1;
                  return Icon(
                    starVal <= avgRating.floor()
                        ? Icons.star_rounded
                        : (starVal - avgRating <= 0.5 && avgRating % 1 != 0)
                            ? Icons.star_half_rounded
                            : Icons.star_outline_rounded,
                    color: const Color(0xFFF59E0B),
                    size: 18,
                  );
                }),
              ),
              const SizedBox(height: 6),
              Text(
                '$totalCount ${totalCount == 1 ? 'review' : 'reviews'}',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: secondaryTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(width: 24),

          // Rating Bars Distribution
          Expanded(
            child: Column(
              children: [
                for (int star = 5; star >= 1; star--) ...[
                  Row(
                    children: [
                      Text(
                        '$star',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.star_rounded, size: 12, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: totalCount > 0
                                ? (starCounts[star] ?? 0) / totalCount
                                : 0.0,
                            backgroundColor: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
                            color: AppColors.brand,
                            minHeight: 6,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 24,
                        child: Text(
                          '${starCounts[star] ?? 0}',
                          textAlign: TextAlign.end,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: secondaryTextColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (star > 1) const SizedBox(height: 4),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brand
              : (isDark ? AppColors.darkSurface : const Color(0xFFF3F4F6)),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected
                ? AppColors.brand
                : (isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB)),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected
                ? Colors.white
                : (isDark ? Colors.white70 : const Color(0xFF374151)),
          ),
        ),
      ),
    );
  }

  Widget _buildReviewCard(
    BuildContext context, {
    required RentalReview review,
    required bool isLiked,
    required DateFormat dateFormat,
    required bool isDark,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Customer Photo Avatar
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.brand,
                backgroundImage: (review.customerPhoto?.isNotEmpty ?? false)
                    ? NetworkImage(review.customerPhoto!)
                    : null,
                child: (review.customerPhoto?.isEmpty ?? true)
                    ? Text(
                        review.customerName.isNotEmpty
                            ? review.customerName[0].toUpperCase()
                            : 'C',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review.customerName.isNotEmpty
                          ? review.customerName
                          : 'Valued Customer',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      review.vehicleTitle.isNotEmpty
                          ? review.vehicleTitle
                          : 'Rental Vehicle',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.brand,
                      ),
                    ),
                  ],
                ),
              ),
              // Rating Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      size: 15,
                      color: Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      review.rating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFB45309),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              '"${review.comment}"',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: primaryTextColor,
                fontStyle: FontStyle.italic,
                height: 1.35,
              ),
            ),
          ],

          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                review.createdAt != null
                    ? dateFormat.format(review.createdAt!)
                    : 'Recent',
                style: TextStyle(
                  fontSize: 11.5,
                  color: secondaryTextColor,
                ),
              ),
              GestureDetector(
                onTap: () => _toggleLike(review),
                child: Row(
                  children: [
                    Icon(
                      isLiked ? Icons.thumb_up_rounded : Icons.thumb_up_outlined,
                      size: 16,
                      color: isLiked ? AppColors.brand : secondaryTextColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${review.likeCount}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isLiked ? AppColors.brand : secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

