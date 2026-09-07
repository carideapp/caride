import 'dart:async';

import 'package:caride/features/home_map/data/mapbox_search_service.dart';
import 'package:caride/features/home_map/data/recent_places_repository.dart';
import 'package:caride/features/profile/data/address_repository.dart';
import 'package:caride/features/ride_booking/booking_shell/booking_shell_controller.dart';
import 'package:caride/features/ride_booking/booking_shell/models/booking_shell_step.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/shared_widgets.dart';

enum _ActiveField { from, to }

class FromToStep extends StatefulWidget {
  const FromToStep({
    super.key,
    required this.controller,
    this.hideTitle = false,
  });

  final BookingShellController controller;
  final bool hideTitle;

  @override
  State<FromToStep> createState() => _FromToStepState();
}

class _FromToStepState extends State<FromToStep> {
  late final TextEditingController _fromCtrl;
  late final TextEditingController _toCtrl;
  final FocusNode _fromFocusNode = FocusNode();
  final FocusNode _toFocusNode = FocusNode();
  _ActiveField _activeField = _ActiveField.to;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fromCtrl = TextEditingController(text: widget.controller.from?.placeName ?? '');
    _toCtrl = TextEditingController(text: widget.controller.to?.placeName ?? '');
    
    _fromFocusNode.addListener(() {
      if (_fromFocusNode.hasFocus) {
        unawaited(widget.controller.searchTo(_fromCtrl.text));
      }
      setState(() {
        if (_fromFocusNode.hasFocus) {
          _activeField = _ActiveField.from;
        }
      });
    });

    _toFocusNode.addListener(() {
      if (_toFocusNode.hasFocus) {
        unawaited(widget.controller.searchTo(_toCtrl.text));
      }
      setState(() {
        if (_toFocusNode.hasFocus) {
          _activeField = _ActiveField.to;
        }
      });
    });

    widget.controller.addListener(_onControllerChanged);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.controller.from != null && widget.controller.to == null) {
        _toFocusNode.requestFocus();
      } else if (widget.controller.from == null) {
        _fromFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _debounce?.cancel();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _fromFocusNode.dispose();
    _toFocusNode.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    final fromName = widget.controller.from?.placeName ?? '';
    if (_fromCtrl.text != fromName && !_fromFocusNode.hasFocus) {
      _fromCtrl.text = fromName;
    }
    final toName = widget.controller.to?.placeName ?? '';
    if (_toCtrl.text != toName && !_toFocusNode.hasFocus) {
      _toCtrl.text = toName;
    }
  }

  void _search(String q, {required _ActiveField field}) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 260), () {
      unawaited(widget.controller.searchTo(q));
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        final isFocused = _fromFocusNode.hasFocus || _toFocusNode.hasFocus;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!widget.hideTitle) ...[
              Text(
                'Where to?',
                style: AppTextStyles.headlineSmall.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    const SizedBox(height: 24),
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppColors.brand,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Container(
                      width: 2,
                      height: 52,
                      color: isDark ? AppColors.glassBorderDark : const Color(0xFFE2E8F0),
                    ),
                    const Icon(Icons.location_on_rounded, size: 16, color: AppColors.error),
                  ],
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    children: [
                      if (c.isResolvingLocation)
                        Container(
                          height: 54,
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Row(
                            children: [
                              const SizedBox(width: AppSpacing.md),
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.brand,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                'Fetching your location...',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: isDark
                                      ? Colors.white54
                                      : AppColors.slate900.withValues(alpha: 0.5),
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        AppTextField(
                          controller: _fromCtrl,
                          focusNode: _fromFocusNode,
                          onChanged: (q) => _search(q, field: _ActiveField.from),
                          onSubmitted: (_) => _toFocusNode.requestFocus(),
                          hint: 'Enter pickup location',
                          obscureText: false,
                          keyboardType: TextInputType.text,
                        ),
                      const SizedBox(height: AppSpacing.sm),
                      AppTextField(
                        controller: _toCtrl,
                        focusNode: _toFocusNode,
                        onChanged: (q) => _search(q, field: _ActiveField.to),
                        onSubmitted: (_) => FocusScope.of(context).unfocus(),
                        hint: 'Where are you going?',
                        obscureText: false,
                        keyboardType: TextInputType.text,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: c.searching
                  ? const Center(child: AppLoader())
                  : _Suggestions(
                      controller: c,
                      searchResults: c.searchResults,
                      onPick: (p) {
                        if (_activeField == _ActiveField.from) {
                          c.setFrom(p);
                          _fromCtrl.text = p.placeName;
                          _toFocusNode.requestFocus();
                        } else {
                          c.setTo(p);
                          _toCtrl.text = p.placeName;
                          FocusScope.of(context).unfocus();
                        }
                        unawaited(c.searchTo(""));
                      },
                    ),
            ),
            if (!isFocused) ...[
              const SizedBox(height: AppSpacing.md),
              PrimaryButton(
                label: 'Continue',
                onPressed: c.from != null && c.to != null
                    ? () => c.goTo(BookingShellStep.rideType)
                    : null,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _Suggestions extends StatelessWidget {
  const _Suggestions({
    required this.controller,
    required this.searchResults,
    required this.onPick,
  });

  final BookingShellController controller;
  final List<MapboxPlace> searchResults;
  final ValueChanged<MapboxPlace> onPick;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (searchResults.isNotEmpty) {
      return ListView.separated(
        padding: EdgeInsets.zero,
        itemCount: searchResults.length,
        separatorBuilder: (_, __) => Divider(
          height: 1,
          color: isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight,
        ),
        itemBuilder: (context, i) {
          final p = searchResults[i];
          return Material(
            color: Colors.transparent,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(AppSpacing.xs),
                decoration: BoxDecoration(
                  color: AppColors.brandGlass,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.place_outlined,
                  size: 18,
                  color: AppColors.brand,
                ),
              ),
              title: Text(
                p.placeName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              onTap: () => onPick(p),
            ),
          );
        },
      );
    }

    return StreamBuilder<List<RecentPlace>>(
      stream: controller.watchRecentPlaces(limit: 6),
      builder: (context, recentSnap) {
        return StreamBuilder<List<SavedAddress>>(
          stream: controller.watchSavedAddresses(),
          builder: (context, savedSnap) {
            final recent = recentSnap.data ?? const <RecentPlace>[];
            final saved = savedSnap.data ?? const <SavedAddress>[];

            if (recent.isEmpty && saved.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.search_rounded,
                      size: 48,
                      color: isDark ? Colors.grey[800] : Colors.grey.shade300,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Search for a destination.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView(
              padding: EdgeInsets.zero,
              children: [
                if (recent.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Text(
                      'Recent Places',
                      style: AppTextStyles.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                  ...recent.map((rp) {
                    final p = MapboxPlace(
                      id: rp.placeId ?? rp.id,
                      placeName: rp.placeName,
                      centerLng: rp.lng,
                      centerLat: rp.lat,
                    );
                    return Material(
                      color: Colors.transparent,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(AppSpacing.xs),
                          decoration: BoxDecoration(
                            color: AppColors.brandGlass,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.history,
                            size: 18,
                            color: AppColors.brand,
                          ),
                        ),
                        title: Text(
                          p.placeName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: () => onPick(p),
                      ),
                    );
                  }),
                  const SizedBox(height: AppSpacing.md),
                ],
                if (saved.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                    child: Text(
                      'Saved Locations',
                      style: AppTextStyles.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ),
                  ...saved.map((addr) {
                    final lat = addr.lat;
                    final lng = addr.lng;
                    return Material(
                      color: Colors.transparent,
                      child: ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Container(
                          padding: const EdgeInsets.all(AppSpacing.xs),
                          decoration: BoxDecoration(
                            color: AppColors.brandGlass,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.bookmark_outline,
                            size: 18,
                            color: AppColors.brand,
                          ),
                        ),
                        title: Text(
                          addr.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          addr.address,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onTap: () async {
                          MapboxPlace? place;
                          if (lat != null && lng != null) {
                            place = MapboxPlace(
                              id: addr.placeId ?? addr.id,
                              placeName: addr.address,
                              centerLng: lng,
                              centerLat: lat,
                            );
                          } else {
                            place = await controller.geocodePlace(addr.address);
                          }
                          if (place == null) return;
                          onPick(place);
                        },
                      ),
                    );
                  }),
                ],
              ],
            );
          },
        );
      },
    );
  }
}
