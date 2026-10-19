import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

/// Safe helper for picking images without crashing or throwing
/// `PlatformException(already_active, Image picker is already active, null, null)`.
class SafeImagePicker {
  SafeImagePicker._();

  static final ImagePicker _picker = ImagePicker();
  static bool _isActive = false;

  /// Whether an image pick operation is currently in progress.
  static bool get isActive => _isActive;

  /// Picks a single image safely. Returns `null` if the picker is already active,
  /// if the user cancels, or if an `already_active` PlatformException occurs.
  static Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    if (_isActive) {
      debugPrint('[SafeImagePicker] Picker is already active. Ignoring tap.');
      return null;
    }

    _isActive = true;
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
        preferredCameraDevice: preferredCameraDevice,
        requestFullMetadata: requestFullMetadata,
      );
      return picked;
    } on PlatformException catch (e) {
      if (e.code == 'already_active') {
        debugPrint('[SafeImagePicker] Caught already_active PlatformException: ${e.message}');
        return null;
      }
      rethrow;
    } catch (e) {
      debugPrint('[SafeImagePicker] Error picking image: $e');
      rethrow;
    } finally {
      _isActive = false;
    }
  }

  /// Picks multiple images safely. Returns empty list if already active.
  static Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    int? limit,
    bool requestFullMetadata = true,
  }) async {
    if (_isActive) {
      debugPrint('[SafeImagePicker] Picker is already active. Ignoring tap.');
      return const [];
    }

    _isActive = true;
    try {
      final picked = await _picker.pickMultiImage(
        maxWidth: maxWidth,
        maxHeight: maxHeight,
        imageQuality: imageQuality,
        limit: limit,
        requestFullMetadata: requestFullMetadata,
      );
      return picked;
    } on PlatformException catch (e) {
      if (e.code == 'already_active') {
        debugPrint('[SafeImagePicker] Caught already_active PlatformException: ${e.message}');
        return const [];
      }
      rethrow;
    } catch (e) {
      debugPrint('[SafeImagePicker] Error picking multi images: $e');
      rethrow;
    } finally {
      _isActive = false;
    }
  }
}
