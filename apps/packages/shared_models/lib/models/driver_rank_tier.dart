enum DriverRankTier { bronze, silver, gold, platinum }

extension DriverRankTierX on DriverRankTier {
  String get label {
    switch (this) {
      case DriverRankTier.bronze:
        return 'Bronze';
      case DriverRankTier.silver:
        return 'Silver';
      case DriverRankTier.gold:
        return 'Gold';
      case DriverRankTier.platinum:
        return 'Platinum';
    }
  }

  String get firestoreKey {
    switch (this) {
      case DriverRankTier.bronze:
        return 'bronze';
      case DriverRankTier.silver:
        return 'silver';
      case DriverRankTier.gold:
        return 'gold';
      case DriverRankTier.platinum:
        return 'platinum';
    }
  }

  static DriverRankTier fromString(String? value) {
    switch (value) {
      case 'silver':
        return DriverRankTier.silver;
      case 'gold':
        return DriverRankTier.gold;
      case 'platinum':
        return DriverRankTier.platinum;
      default:
        return DriverRankTier.bronze;
    }
  }
}
