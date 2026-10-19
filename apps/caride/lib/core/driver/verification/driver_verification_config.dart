import 'package:flutter/material.dart';

const String vehicleTypeRegular = 'regular';
const String vehicleTypeComfort = 'comfort';
const String vehicleTypeLuxury = 'luxury';
const String vehicleTypeCourier = 'courier';
const String vehicleTypeTricycle = 'tricycle';
const String vehicleTypeMotorcycle = 'motorcycle';

const List<String> supportedVehicleTypes = <String>[
  vehicleTypeRegular,
  vehicleTypeComfort,
  vehicleTypeLuxury,
  vehicleTypeCourier,
  vehicleTypeTricycle,
  vehicleTypeMotorcycle,
];

const List<String> standardDriverDocumentTypes = <String>[
  'national_id',
  'drivers_license',
  'profile_photo',
  'proof_of_address',
  'guarantor_info',
  'vehicle_registration',
  'proof_of_ownership',
  'proof_of_insurance',
  'road_worthiness',
  'vehicle_photo',
];

const List<String> courierDriverDocumentTypes = <String>[
  'national_id',
  'drivers_license',
  'profile_photo',
  'rider_permit',
  'proof_of_address',
  'guarantor_info',
  'vehicle_registration',
  'proof_of_ownership',
  'proof_of_insurance',
  'road_worthiness',
  'vehicle_photo',
];

/// Commercial Tricycle (Keke) requirements in Nigeria:
/// FRSC Class A Driver's Licence (for 3-wheelers/motorcycles) / Rider's Permit,
/// Vehicle Registration, Road Worthiness, Commercial Third Party Insurance,
/// Proof of Ownership, Exterior Vehicle Photos, NIN, Guarantor, Address.
const List<String> kekeDriverDocumentTypes = <String>[
  'national_id',
  'drivers_license',
  'rider_permit',
  'profile_photo',
  'proof_of_address',
  'guarantor_info',
  'vehicle_registration',
  'proof_of_ownership',
  'proof_of_insurance',
  'road_worthiness',
  'vehicle_photo',
];

/// Commercial Motorcycle (Bike) requirements in Nigeria:
/// FRSC Class A Driver's Licence / Rider's Permit, Commercial Road Worthiness,
/// Vehicle Registration, Proof of Ownership, Third Party Insurance, Vehicle Photos, NIN, Guarantor.
const List<String> motorcycleDriverDocumentTypes = <String>[
  'national_id',
  'drivers_license',
  'rider_permit',
  'profile_photo',
  'proof_of_address',
  'guarantor_info',
  'vehicle_registration',
  'proof_of_ownership',
  'proof_of_insurance',
  'road_worthiness',
  'vehicle_photo',
];

class DriverDocumentDefinition {
  const DriverDocumentDefinition({
    required this.type,
    required this.label,
    required this.icon,
    this.description,
  });

  final String type;
  final String label;
  final IconData icon;
  final String? description;
}

String normalizeVehicleType(String? vehicleType) {
  final normalized = vehicleType?.trim().toLowerCase() ?? vehicleTypeRegular;
  if (supportedVehicleTypes.contains(normalized)) {
    return normalized;
  }
  if (normalized == 'keke') return vehicleTypeTricycle;
  if (normalized == 'bike') return vehicleTypeMotorcycle;
  return vehicleTypeRegular;
}

bool isCourierVehicleType(String? vehicleType) {
  return normalizeVehicleType(vehicleType) == vehicleTypeCourier;
}

bool isTricycleVehicleType(String? vehicleType) {
  return normalizeVehicleType(vehicleType) == vehicleTypeTricycle;
}

bool isMotorcycleVehicleType(String? vehicleType) {
  return normalizeVehicleType(vehicleType) == vehicleTypeMotorcycle;
}

String vehicleTypeLabel(String? vehicleType) {
  return switch (normalizeVehicleType(vehicleType)) {
    vehicleTypeRegular => 'Regular',
    vehicleTypeComfort => 'Comfort',
    vehicleTypeLuxury => 'Luxury',
    vehicleTypeCourier => 'Courier',
    vehicleTypeTricycle => 'Tricycle (Keke)',
    vehicleTypeMotorcycle => 'Motorcycle',
    _ => 'Regular',
  };
}

int seatCountForVehicleType(String? vehicleType) {
  return switch (normalizeVehicleType(vehicleType)) {
    vehicleTypeRegular => 4,
    vehicleTypeComfort => 4,
    vehicleTypeLuxury => 4,
    vehicleTypeCourier => 1,
    vehicleTypeTricycle => 3,
    vehicleTypeMotorcycle => 1,
    _ => 4,
  };
}

String vehicleTypeAsset(String? vehicleType) {
  return switch (normalizeVehicleType(vehicleType)) {
    vehicleTypeTricycle => 'lib/assets/caride_branded/tricyle.png',
    vehicleTypeMotorcycle => 'lib/assets/motorcycle.png',
    vehicleTypeComfort => 'lib/assets/ride_options/comfort.png',
    vehicleTypeLuxury => 'lib/assets/ride_options/luxury.png',
    vehicleTypeCourier => 'lib/assets/ride_options/courier.png',
    _ => 'lib/assets/ride_options/regular.png',
  };
}

List<DriverDocumentDefinition> requiredDocumentsForVehicleType(
  String? vehicleType, {
  String? operatingState,
}) {
  final normalized = normalizeVehicleType(vehicleType);
  final List<String> baseTypes = switch (normalized) {
    vehicleTypeCourier => [...courierDriverDocumentTypes],
    vehicleTypeTricycle => [...kekeDriverDocumentTypes],
    vehicleTypeMotorcycle => [...motorcycleDriverDocumentTypes],
    _ => [...standardDriverDocumentTypes],
  };

  // State-specific regulations:
  // Lagos State requires LASDRI recertification card for commercial drivers/riders
  final state = operatingState?.trim().toLowerCase();
  if (state == 'lagos') {
    if (!baseTypes.contains('lasdri_card')) {
      baseTypes.add('lasdri_card');
    }
  }

  return baseTypes.map(documentDefinitionForType).toList(growable: false);
}

DriverDocumentDefinition documentDefinitionForType(String type) {
  return switch (type) {
    'national_id' => const DriverDocumentDefinition(
      type: 'national_id',
      label: 'National ID',
      icon: Icons.credit_card_outlined,
      description: 'NIN slip/card, Voter’s Card, or International Passport.',
    ),
    'drivers_license' => const DriverDocumentDefinition(
      type: 'drivers_license',
      label: "Driver's Licence",
      icon: Icons.badge_outlined,
      description:
          'Valid FRSC Driver’s Licence (Class A for Bike/Tricycle, Class B/E for Cars).',
    ),
    'rider_permit' => const DriverDocumentDefinition(
      type: 'rider_permit',
      label: 'Rider Permit / Commercial Badge',
      icon: Icons.two_wheeler_outlined,
      description: 'Required commercial rider permit or state transport badge.',
    ),
    'proof_of_address' => const DriverDocumentDefinition(
      type: 'proof_of_address',
      label: 'Proof of Address',
      icon: Icons.home_work_outlined,
      description: 'Utility bill, tenancy agreement, or address document.',
    ),
    'guarantor_info' => const DriverDocumentDefinition(
      type: 'guarantor_info',
      label: 'Guarantor Information',
      icon: Icons.person_add_alt_1_outlined,
      description: 'Provide details of your verified guarantor.',
    ),
    'vehicle_registration' => const DriverDocumentDefinition(
      type: 'vehicle_registration',
      label: 'Vehicle Registration',
      icon: Icons.description_outlined,
      description: 'Upload your current vehicle registration papers.',
    ),
    'proof_of_ownership' => const DriverDocumentDefinition(
      type: 'proof_of_ownership',
      label: 'Proof of Ownership',
      icon: Icons.assignment_turned_in_outlined,
      description: 'Receipt of purchase, transfer, or owner authorization.',
    ),
    'proof_of_insurance' => const DriverDocumentDefinition(
      type: 'proof_of_insurance',
      label: 'Proof of Insurance',
      icon: Icons.shield_outlined,
      description: 'Upload an active insurance certificate or cover note.',
    ),
    'road_worthiness' => const DriverDocumentDefinition(
      type: 'road_worthiness',
      label: 'Road Worthiness Certificate',
      icon: Icons.verified_user_outlined,
      description: 'Current certificate issued by appropriate authority.',
    ),
    'vehicle_photo' => const DriverDocumentDefinition(
      type: 'vehicle_photo',
      label: 'Vehicle Photo',
      icon: Icons.photo_camera_outlined,
      description: 'Upload a clear exterior photo of the vehicle you use.',
    ),
    'vehicle_photo_front' => const DriverDocumentDefinition(
      type: 'vehicle_photo_front',
      label: 'Vehicle Photo (Front)',
      icon: Icons.photo_camera_outlined,
      description: 'Front photo of your vehicle.',
    ),
    'vehicle_photo_back' => const DriverDocumentDefinition(
      type: 'vehicle_photo_back',
      label: 'Vehicle Photo (Back)',
      icon: Icons.photo_camera_outlined,
      description: 'Rear photo of your vehicle.',
    ),
    'profile_photo' => const DriverDocumentDefinition(
      type: 'profile_photo',
      label: 'Profile Photo',
      icon: Icons.person_outline,
      description: 'Upload a clear headshot for your driver profile.',
    ),
    'lasdri_card' => const DriverDocumentDefinition(
      type: 'lasdri_card',
      label: 'LASDRI Card',
      icon: Icons.card_membership_outlined,
      description: 'Lagos State Drivers Institute recertification card (Lagos operators).',
    ),
    _ => DriverDocumentDefinition(
      type: type,
      label: type,
      icon: Icons.description_outlined,
    ),
  };
}

