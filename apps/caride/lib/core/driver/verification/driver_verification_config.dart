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
  'vehicle_registration',
  'proof_of_insurance',
  'vehicle_photo',
];

const List<String> courierDriverDocumentTypes = <String>[
  'national_id',
  'drivers_license',
  'profile_photo',
  'rider_permit',
  'vehicle_registration',
  'proof_of_insurance',
  'vehicle_photo',
];

/// Commercial Tricycle (Keke) requirements in Nigeria:
/// FRSC Class A Driver's Licence (for 3-wheelers/motorcycles) / Rider's Permit,
/// Vehicle Registration, Commercial Third Party Insurance, Exterior Vehicle Photos, NIN.
const List<String> kekeDriverDocumentTypes = <String>[
  'national_id',
  'drivers_license',
  'rider_permit',
  'profile_photo',
  'vehicle_registration',
  'proof_of_insurance',
  'vehicle_photo',
];

/// Commercial Motorcycle (Bike) requirements in Nigeria:
/// FRSC Class A Driver's Licence / Rider's Permit,
/// Vehicle Registration, Third Party Insurance, Vehicle Photos, NIN.
const List<String> motorcycleDriverDocumentTypes = <String>[
  'national_id',
  'drivers_license',
  'rider_permit',
  'profile_photo',
  'vehicle_registration',
  'proof_of_insurance',
  'vehicle_photo',
];

/// Optional / Admin-Toggleable Driver Document Types.
/// By default these are OFF (hidden & optional in the mobile app).
/// When toggled ON by Admin in `config/driverSettings.requiredDocuments`,
/// they become visible and required in the mobile app and backend.
const Map<String, bool> defaultToggleableDocumentRequirements = <String, bool>{
  'proof_of_address': false,
  'guarantor_info': false,
  'proof_of_ownership': false,
  'road_worthiness': false,
  'lasdri_card': false,
};

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
  Map<String, bool>? toggleOverrides,
}) {
  final normalized = normalizeVehicleType(vehicleType);
  final List<String> baseTypes = switch (normalized) {
    vehicleTypeCourier => [...courierDriverDocumentTypes],
    vehicleTypeTricycle => [...kekeDriverDocumentTypes],
    vehicleTypeMotorcycle => [...motorcycleDriverDocumentTypes],
    _ => [...standardDriverDocumentTypes],
  };

  final toggles = <String, bool>{
    ...defaultToggleableDocumentRequirements,
    if (toggleOverrides != null) ...toggleOverrides,
  };

  // Append any optional documents that Admin has toggled ON
  for (final docKey in <String>[
    'proof_of_address',
    'guarantor_info',
    'proof_of_ownership',
    'road_worthiness',
  ]) {
    if (toggles[docKey] == true && !baseTypes.contains(docKey)) {
      baseTypes.add(docKey);
    }
  }

  // State-specific or Admin-toggled LASDRI card:
  // Only shown when Admin toggles `lasdri_card` ON (for Lagos or all states if enabled)
  final state = operatingState?.trim().toLowerCase();
  if (toggles['lasdri_card'] == true &&
      (state == 'lagos' || state == null || state.isEmpty)) {
    if (!baseTypes.contains('lasdri_card')) {
      baseTypes.add('lasdri_card');
    }
  } else if (toggles['lasdri_card'] == true &&
      !baseTypes.contains('lasdri_card')) {
    baseTypes.add('lasdri_card');
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
      description:
          'Lagos State Drivers Institute recertification card (Lagos operators).',
    ),
    _ => DriverDocumentDefinition(
      type: type,
      label: type,
      icon: Icons.description_outlined,
    ),
  };
}
