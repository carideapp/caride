const activeRideStatuses = <String>{
  'requested',
  'bidding',
  'driverEnRoute',
  'rideStarted',
};

bool isActiveRideStatus(String status) => activeRideStatuses.contains(status);

bool customerCanCancel(String status) =>
    status == 'requested' || status == 'bidding' || status == 'driverEnRoute';

