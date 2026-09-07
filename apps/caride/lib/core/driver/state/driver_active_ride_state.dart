import '../models/ride_model.dart';

/// Singleton that shares the currently selected/active ride across screens.
///
/// Set [selectedRide] before navigating to [DriverRoutePaths.requestDetail].
/// Trip screens read [activeRideId] to stream the current ride.
/// [lastCompletedRide] is set after [completeRide] for the summary screens.
class DriverActiveRideState {
  DriverActiveRideState._();
  static final instance = DriverActiveRideState._();

  /// Ride selected from the incoming requests list (before bid is placed).
  RideModel? selectedRide;

  /// The ride ID of the currently active (en-route or started) ride.
  String? activeRideId;

  /// The last completed ride — used by [TripCompleteScreen] and [DriverLeaveARateScreen].
  RideModel? lastCompletedRide;
}
