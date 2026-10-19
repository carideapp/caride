import 'dart:async';

import 'package:caride/features/profile/data/address_repository.dart';
import 'package:caride/core/config/app_config_repository.dart';
import 'package:caride/core/config/app_env.dart';
import 'package:caride/core/maps/google_map_utils.dart';
import 'package:caride/core/maps/dark_map_style.dart';
import 'package:caride/features/home_map/data/mapbox_search_service.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Redesigned Customer Add Saved Address Screen with map selector and draggable sheet.
class AddAnAddressScreen extends StatefulWidget {
  const AddAnAddressScreen({super.key});

  @override
  State<AddAnAddressScreen> createState() => _AddAnAddressScreenState();
}

class _AddAnAddressScreenState extends State<AddAnAddressScreen> {
  final AddressRepository _repo = AddressRepository();
  final AppConfigRepository _configRepository = AppConfigRepository();
  late final MapboxSearchService _searchService;

  final _searchCtrl = TextEditingController();
  final _labelCtrl = TextEditingController();
  final _labelFocusNode = FocusNode();

  StreamSubscription<AppDefaults?>? _defaultsSub;
  AppDefaults? _defaults;

  GoogleMapController? _googleMapController;
  bool _searching = false;
  List<MapboxPlace> _results = const [];
  MapboxPlace? _selectedPlace;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _searchService = MapboxSearchService(AppEnv.googleMapsApiKey);
    _labelFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    _defaultsSub = _configRepository.watchAppDefaults().listen((v) {
      if (!mounted) return;
      setState(() => _defaults = v);
      final controller = _googleMapController;
      if (controller != null && v != null) {
        controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(v.defaultMapCenterLat, v.defaultMapCenterLng),
              zoom: 12.0,
            ),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _defaultsSub?.cancel();
    _searchCtrl.dispose();
    _labelCtrl.dispose();
    _labelFocusNode.dispose();
    super.dispose();
  }

  void _onMapCreated(GoogleMapController controller) {
    _googleMapController = controller;
    unawaited(_initMap(controller));
  }

  Future<void> _initMap(GoogleMapController controller) async {
    final gps = await GoogleMapUtils.flyToGps(controller, zoom: 14.0);
    if (gps == null) {
      final v = _defaults;
      if (v != null) {
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(v.defaultMapCenterLat, v.defaultMapCenterLng),
              zoom: 12.0,
            ),
          ),
        );
      }
    }
  }

  Future<void> _search(String query) async {
    final q = query.trim();
    if (_selectedPlace != null) {
      setState(() => _selectedPlace = null);
    }
    if (q.isEmpty || AppEnv.googleMapsApiKey.isEmpty) {
      setState(() {
        _results = const [];
        _searching = false;
      });
      return;
    }

    setState(() => _searching = true);
    final defaults = _defaults;
    final results = await _searchService.searchPlaces(
      q,
      proximityLat: defaults?.defaultMapCenterLat,
      proximityLng: defaults?.defaultMapCenterLng,
    );
    if (!mounted) return;
    setState(() {
      _results = results;
      _searching = false;
    });
  }

  Future<void> _selectPlace(MapboxPlace place) async {
    setState(() {
      _selectedPlace = place;
      _results = const [];
      _searchCtrl.text = place.placeName;
    });

    await _googleMapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: LatLng(place.centerLat, place.centerLng),
          zoom: 15.0,
        ),
      ),
    );
  }

  Future<void> _save() async {
    final place = _selectedPlace;
    final label = _labelCtrl.text.trim();
    if (place == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a location first.')),
      );
      return;
    }
    if (label.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a name for this address.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _repo.addAddress(
        label: label,
        address: place.placeName,
        placeId: place.id,
        lat: place.centerLat,
        lng: place.centerLng,
      );
      if (!mounted) return;
      _showSuccessDialog(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save address.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showSuccessDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.transparent,
        contentPadding: EdgeInsets.zero,
        content: GlassSurface(
          radius: AppRadius.lg,
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: const BoxDecoration(
                  color: AppColors.brand,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 40),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Address Saved!',
                style: AppTextStyles.headlineSmall.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Your new address has been added successfully.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: 'OK',
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    context.pop();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final place = _selectedPlace;
    final labelPreview = _labelCtrl.text.trim();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          Positioned.fill(
            child: GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _defaults != null
                    ? LatLng(
                        _defaults!.defaultMapCenterLat,
                        _defaults!.defaultMapCenterLng,
                      )
                    : const LatLng(9.0820, 8.6753),
                zoom: 13.0,
              ),
              onMapCreated: _onMapCreated,
              style: isDark ? kGoogleMapDarkStyle : null,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              compassEnabled: false,
              mapToolbarEnabled: false,
              markers: _selectedPlace != null
                  ? {
                      Marker(
                        markerId: const MarkerId('selected_place'),
                        position: LatLng(_selectedPlace!.centerLat, _selectedPlace!.centerLng),
                        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                      ),
                    }
                  : const {},
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 14,
            left: 20,
            right: 20,
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
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: isDark ? Colors.white : const Color(0xFF111827),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: _search,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        prefixIcon: Icon(Icons.search_rounded, color: AppColors.brand, size: 20),
                        hintText: 'Search for a location',
                      ),
                      style: TextStyle(
                        fontSize: 15,
                        color: isDark ? Colors.white : const Color(0xFF111827),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_selectedPlace == null)
            const Center(
              child: _CrosshairPin(),
            ),
          if (_searchCtrl.text.isNotEmpty && (_searching || _results.isNotEmpty))
            Positioned(
              top: MediaQuery.of(context).padding.top + 76,
              left: AppSpacing.pagePadding,
              right: AppSpacing.pagePadding,
              child: GlassContainer(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: _searching
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(AppSpacing.md),
                            child: AppLoader(),
                          ),
                        )
                      : ListView.separated(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: _results.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight,
                          ),
                          itemBuilder: (context, index) {
                            final item = _results[index];
                            return Material(
                              color: Colors.transparent,
                              child: ListTile(
                                dense: true,
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.place_outlined, color: AppColors.brand),
                                title: Text(
                                  item.placeName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w500),
                                ),
                                onTap: () => _selectPlace(item),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
          Positioned.fill(
            child: DraggableScrollableSheet(
              initialChildSize: 0.42,
              minChildSize: 0.22,
              maxChildSize: 0.85,
              snap: true,
              snapSizes: const [0.22, 0.42, 0.85],
              builder: (context, scrollController) {
                return Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                    border: Border.all(
                      color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 16,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: EdgeInsets.fromLTRB(
                      20,
                      12,
                      20,
                      MediaQuery.of(context).padding.bottom +
                          16 +
                          (_labelFocusNode.hasFocus
                              ? MediaQuery.of(context).viewInsets.bottom
                              : 0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Add Saved Address',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.location_on_rounded, color: AppColors.brand, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      place == null
                                          ? 'No location selected'
                                          : (labelPreview.isEmpty
                                              ? 'Selected location'
                                              : labelPreview),
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : const Color(0xFF111827),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                place?.placeName ?? 'Search and select a location above.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Address Label',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : const Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          height: 54,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkSurface : const Color(0xFFF3F4F6),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          alignment: Alignment.center,
                          child: TextField(
                            controller: _labelCtrl,
                            focusNode: _labelFocusNode,
                            decoration: InputDecoration(
                              hintText: 'e.g. Home, Office, Gym',
                              hintStyle: TextStyle(
                                color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
                                fontSize: 14,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            style: TextStyle(
                              fontSize: 15,
                              color: isDark ? Colors.white : const Color(0xFF111827),
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 54,
                                child: OutlinedButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                  ),
                                  child: Text(
                                    'Cancel',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: SizedBox(
                                height: 54,
                                child: ElevatedButton(
                                  onPressed: _saving || _selectedPlace == null ? null : _save,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.brand,
                                    elevation: 0,
                                    disabledBackgroundColor: AppColors.brand.withValues(alpha: 0.4),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(28),
                                    ),
                                  ),
                                  child: _saving
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : const Text(
                                          'Save Address',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CrosshairPin extends StatelessWidget {
  const _CrosshairPin();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.brand,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: AppColors.brand.withValues(alpha: 0.3),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.location_on_rounded, color: Colors.white, size: 22),
        ),
        Container(
          width: 10,
          height: 5,
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(5),
          ),
        ),
      ],
    );
  }
}
