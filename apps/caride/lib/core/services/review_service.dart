import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';

class ReviewService {
  static final InAppReview _inAppReview = InAppReview.instance;

  /// Triggers the In-App Review prompt in release/production.
  /// Falls back to opening the native platform store listing if unavailable.
  static Future<void> requestReview() async {
    try {
      if (kReleaseMode) {
        final isAvailable = await _inAppReview.isAvailable();
        if (isAvailable) {
          await _inAppReview.requestReview();
          return;
        }
      }
      await _inAppReview.openStoreListing();
    } catch (e) {
      debugPrint('Error during in-app review: $e');
      try {
        await _inAppReview.openStoreListing();
      } catch (innerError) {
        debugPrint('Error opening store listing: $innerError');
      }
    }
  }
}
