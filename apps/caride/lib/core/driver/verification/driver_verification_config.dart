import 'package:flutter/material.dart';

const String vehicleTypeRegular = 'regular';
const String vehicleTypeComfort = 'comfort';
const String vehicleTypeLuxury = 'luxury';
const String vehicleTypeCourier = 'courier';

const List<String> supportedVehicleTypes = <String>[
  vehicleTypeRegular,
  vehicleTypeComfort,
  vehicleTypeLuxury,
  vehicleTypeCourier,
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
  return vehicleTypeRegular;
}

bool isCourierVehicleType(String? vehicleType) {
  return normalizeVehicleType(vehicleType) == vehicleTypeCourier;
}

String vehicleTypeLabel(String? vehicleType) {
  return switch (normalizeVehicleType(vehicleType)) {
    vehicleTypeRegular => 'Regular',
    vehicleTypeComfort => 'Comfort',
    vehicleTypeLuxury => 'Luxury',
    vehicleTypeCourier => 'Courier',
    _ => 'Regular',
  };
}

int seatCountForVehicleType(String? vehicleType) {
  return switch (normalizeVehicleType(vehicleType)) {
    vehicleTypeRegular => 4,
    vehicleTypeComfort => 4,
    vehicleTypeLuxury => 4,
    vehicleTypeCourier => 1,
    _ => 4,
  };
}

List<DriverDocumentDefinition> requiredDocumentsForVehicleType(String? vehicleType) {
  final normalized = normalizeVehicleType(vehicleType);
  final types = normalized == vehicleTypeCourier
      ? courierDriverDocumentTypes
      : standardDriverDocumentTypes;

  return types.map(documentDefinitionForType).toList(growable: false);
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
      description: 'Upload a valid government-issued driver licence.',
    ),
    'rider_permit' => const DriverDocumentDefinition(
      type: 'rider_permit',
      label: 'Rider Permit',
      icon: Icons.two_wheeler_outlined,
      description: 'Required for courier and delivery bike verification.',
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
      label: 'Vehicle Photo',
      icon: Icons.photo_camera_outlined,
      description: 'Front and rear photos of your vehicle.',
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
    _ => DriverDocumentDefinition(
      type: type,
      label: type,
      icon: Icons.description_outlined,
    ),
  };
}
