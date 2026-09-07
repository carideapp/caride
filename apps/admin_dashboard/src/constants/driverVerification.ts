export const VEHICLE_TYPE_REGULAR = 'regular';
export const VEHICLE_TYPE_COMFORT = 'comfort';
export const VEHICLE_TYPE_LUXURY = 'luxury';
export const VEHICLE_TYPE_COURIER = 'courier';

export const STANDARD_DRIVER_DOCUMENT_TYPES = [
  'national_id',
  'drivers_license',
  'profile_photo',
  'proof_of_address',
  'guarantor_info',
  'vehicle_registration',
  'proof_of_ownership',
  'proof_of_insurance',
  'road_worthiness',
  'vehicle_photo_front',
  'vehicle_photo_back',
] as const;

export const COURIER_DRIVER_DOCUMENT_TYPES = [
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
  'vehicle_photo_front',
  'vehicle_photo_back',
] as const;

export function normalizeVehicleType(vehicleType?: string | null): string {
  const normalized = vehicleType?.trim().toLowerCase();
  switch (normalized) {
    case VEHICLE_TYPE_REGULAR:
    case VEHICLE_TYPE_COMFORT:
    case VEHICLE_TYPE_LUXURY:
    case VEHICLE_TYPE_COURIER:
      return normalized;
    default:
      return VEHICLE_TYPE_REGULAR;
  }
}

export function vehicleTypeLabel(vehicleType?: string | null): string {
  switch (normalizeVehicleType(vehicleType)) {
    case VEHICLE_TYPE_REGULAR:
      return 'Regular';
    case VEHICLE_TYPE_COMFORT:
      return 'Comfort';
    case VEHICLE_TYPE_LUXURY:
      return 'Luxury';
    case VEHICLE_TYPE_COURIER:
      return 'Courier';
    default:
      return 'Regular';
  }
}

export function requiredDriverDocumentTypes(vehicleType?: string | null): readonly string[] {
  return normalizeVehicleType(vehicleType) === VEHICLE_TYPE_COURIER
    ? COURIER_DRIVER_DOCUMENT_TYPES
    : STANDARD_DRIVER_DOCUMENT_TYPES;
}

export const DRIVER_DOCUMENT_LABELS: Record<string, string> = {
  national_id: 'National ID (NIN / Voter Card / Passport)',
  drivers_license: "Driver's licence",
  profile_photo: 'Profile photo',
  rider_permit: 'Rider permit',
  proof_of_address: 'Proof of Address',
  guarantor_info: 'Guarantor Information',
  vehicle_registration: 'Vehicle Registration',
  proof_of_ownership: 'Proof of Ownership',
  proof_of_insurance: 'Proof of Insurance',
  road_worthiness: 'Road Worthiness Certificate',
  vehicle_photo: 'Vehicle photo',
  vehicle_photo_front: 'Vehicle photo (Front)',
  vehicle_photo_back: 'Vehicle photo (Back)',
};
