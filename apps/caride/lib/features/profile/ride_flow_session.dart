import 'dart:math';

enum RideTripStage {
  driverHeadingToPickup,
  tripStarted,
  headingToDestination,
  arrived,
}

class RideFlowSession {
  RideFlowSession._();

  static final RideFlowSession instance = RideFlowSession._();
  static final Random _random = Random();

  RideTripStage _stage = RideTripStage.driverHeadingToPickup;
  String _startTripPin = _generatePin();
  String _endTripPin = _generatePin();
  bool _showArrivalOnNextHistoryOpen = false;

  RideTripStage get stage => _stage;
  bool get showArrivalOnNextHistoryOpen => _showArrivalOnNextHistoryOpen;
  bool get hasTripStarted =>
      _stage.index >= RideTripStage.tripStarted.index &&
      _stage != RideTripStage.arrived;
  bool get isArrived => _stage == RideTripStage.arrived;

  String get activePin => hasTripStarted ? _endTripPin : _startTripPin;
  String get startTripPin => _startTripPin;
  String get endTripPin => _endTripPin;

  void reset() {
    _stage = RideTripStage.driverHeadingToPickup;
    _startTripPin = _generatePin();
    _endTripPin = _generatePin();
    _showArrivalOnNextHistoryOpen = false;
  }

  void setStage(RideTripStage stage) {
    _stage = stage;
    if (_stage == RideTripStage.arrived) {
      _showArrivalOnNextHistoryOpen = true;
    }
  }

  void startTrip() {
    _stage = RideTripStage.tripStarted;
    _endTripPin = _generatePin();
  }

  void headToDestination() {
    _stage = RideTripStage.headingToDestination;
  }

  void arrive() {
    _stage = RideTripStage.arrived;
    _showArrivalOnNextHistoryOpen = true;
  }

  void consumeArrivalPrompt() {
    _showArrivalOnNextHistoryOpen = false;
  }

  static String _generatePin() {
    final value = 1000 + _random.nextInt(9000);
    return value.toString();
  }
}
