export const VEHICLE_TYPE_REGULAR = 'regular';
export const VEHICLE_TYPE_COMFORT = 'comfort';
export const VEHICLE_TYPE_LUXURY = 'luxury';
export const VEHICLE_TYPE_COURIER = 'courier';
export const VEHICLE_TYPE_TRICYCLE = 'tricycle';
export const VEHICLE_TYPE_MOTORCYCLE = 'motorcycle';

export const ALL_VEHICLE_TYPES = [
  VEHICLE_TYPE_REGULAR,
  VEHICLE_TYPE_COMFORT,
  VEHICLE_TYPE_LUXURY,
  VEHICLE_TYPE_COURIER,
  VEHICLE_TYPE_TRICYCLE,
  VEHICLE_TYPE_MOTORCYCLE,
] as const;

export const NIGERIAN_STATES = [
  'Abia', 'Adamawa', 'Akwa Ibom', 'Anambra', 'Bauchi', 'Bayelsa', 'Benue', 'Borno',
  'Cross River', 'Delta', 'Ebonyi', 'Edo', 'Ekiti', 'Enugu', 'FCT (Abuja)', 'Gombe',
  'Imo', 'Jigawa', 'Kaduna', 'Kano', 'Katsina', 'Kebbi', 'Kogi', 'Kwara', 'Lagos',
  'Nasarawa', 'Niger', 'Ogun', 'Ondo', 'Osun', 'Oyo', 'Plateau', 'Rivers', 'Sokoto',
  'Taraba', 'Yobe', 'Zamfara',
] as const;

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

/**
 * Commercial Tricycle (Keke) requirements in Nigeria:
 * FRSC Class A Driver's Licence (for 3-wheelers/motorcycles) / Rider's Permit,
 * Vehicle Registration, Road Worthiness, Commercial Third Party Insurance,
 * Proof of Ownership, Exterior Vehicle Photos, NIN, Guarantor, Address.
 * In states like Lagos, LASDRI certification / Stage Carriage permit applies.
 */
export const TRICYCLE_DRIVER_DOCUMENT_TYPES = [
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
  'vehicle_photo_front',
  'vehicle_photo_back',
] as const;

/**
 * Commercial Motorcycle (Bike) requirements in Nigeria:
 * FRSC Class A Driver's Licence / Rider's Permit, Commercial Road Worthiness / Stage Carriage,
 * Vehicle Registration, Proof of Ownership, Third Party Insurance, Vehicle Photos, NIN, Guarantor.
 */
export const MOTORCYCLE_DRIVER_DOCUMENT_TYPES = [
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
    case VEHICLE_TYPE_TRICYCLE:
    case VEHICLE_TYPE_MOTORCYCLE:
      return normalized;
    case 'keke':
      return VEHICLE_TYPE_TRICYCLE;
    case 'bike':
      return VEHICLE_TYPE_MOTORCYCLE;
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
    case VEHICLE_TYPE_TRICYCLE:
      return 'Tricycle (Keke)';
    case VEHICLE_TYPE_MOTORCYCLE:
      return 'Motorcycle';
    default:
      return 'Regular';
  }
}

export function requiredDriverDocumentTypes(
  vehicleType?: string | null,
  operatingState?: string | null,
): readonly string[] {
  const normType = normalizeVehicleType(vehicleType);
  const state = operatingState?.trim().toLowerCase();

  let baseDocs: readonly string[];
  switch (normType) {
    case VEHICLE_TYPE_COURIER:
      baseDocs = COURIER_DRIVER_DOCUMENT_TYPES;
      break;
    case VEHICLE_TYPE_TRICYCLE:
      baseDocs = TRICYCLE_DRIVER_DOCUMENT_TYPES;
      break;
    case VEHICLE_TYPE_MOTORCYCLE:
      baseDocs = MOTORCYCLE_DRIVER_DOCUMENT_TYPES;
      break;
    default:
      baseDocs = STANDARD_DRIVER_DOCUMENT_TYPES;
      break;
  }

  // State-specific regulations:
  // Lagos State requires LASDRI recertification for commercial drivers/riders
  if (state === 'lagos') {
    if (!baseDocs.includes('lasdri_card')) {
      return [...baseDocs, 'lasdri_card'];
    }
  }

  return baseDocs;
}

export const DRIVER_DOCUMENT_LABELS: Record<string, string> = {
  national_id: 'National ID (NIN / Voter Card / Passport)',
  drivers_license: "Driver's Licence (FRSC Class A for Bike/Keke)",
  profile_photo: 'Profile Photo',
  rider_permit: 'Rider Permit / Commercial Badge',
  proof_of_address: 'Proof of Address',
  guarantor_info: 'Guarantor Information',
  vehicle_registration: 'Vehicle Registration',
  proof_of_ownership: 'Proof of Ownership',
  proof_of_insurance: 'Proof of Insurance',
  road_worthiness: 'Road Worthiness Certificate',
  vehicle_photo: 'Vehicle Photo',
  vehicle_photo_front: 'Vehicle Photo (Front)',
  vehicle_photo_back: 'Vehicle Photo (Back)',
  lasdri_card: 'LASDRI Card (Lagos Drivers Institute)',
  stage_carriage_permit: 'State Stage Carriage Permit',
};

