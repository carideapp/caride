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
            top: MediaQuery.of(context).padding.top + AppSpacing.md,
            left: AppSpacing.pagePadding,
            right: AppSpacing.pagePadding,
            child: Row(
              children: [
                GlassIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: GlassContainer(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: _search,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        isDense: true,
                        prefixIcon: Icon(Icons.search_rounded, color: AppColors.brand, size: 20),
                        hintText: 'Search for a location',
                      ),
                      style: AppTextStyles.bodyLarge,
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
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32.0)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      MediaQuery.of(context).padding.bottom +
                          AppSpacing.md +
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
                              color: isDark ? Colors.grey[800] : Colors.grey[300],
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'Add saved address',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        GlassContainer(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.location_on_rounded, color: AppColors.brand, size: 20),
                                  const SizedBox(width: AppSpacing.xs),
                                  Expanded(
                                    child: Text(
                                      place == null
                                          ? 'No location selected'
                                          : (labelPreview.isEmpty
                                              ? 'Selected location'
                                              : labelPreview),
                                      style: AppTextStyles.bodyLarge.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                place?.placeName ?? 'Search and select a location above.',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'Name label',
                          style: AppTextStyles.titleSmall.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        AppTextField(
                          controller: _labelCtrl,
                          focusNode: _labelFocusNode,
                          hint: 'e.g. Home, Office',
                          obscureText: false,
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        Row(
                          children: [
                            Expanded(
                              child: SecondaryButton(
                                label: 'Cancel',
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: PrimaryButton(
                                label: 'Save Address',
                                onPressed: _saving || _selectedPlace == null ? null : _save,
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
