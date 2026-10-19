export {
  DRIVER_DOCUMENT_LABELS,
  STANDARD_DRIVER_DOCUMENT_TYPES as DRIVER_DOCUMENT_TYPES,
} from './driverVerification';

export type DriverDocumentTypeId =
  | 'drivers_license'
  | 'rider_permit'
  | 'vehicle_registration'
  | 'proof_of_insurance'
  | 'vehicle_photo'
  | 'vehicle_photo_front'
  | 'vehicle_photo_back'
  | 'profile_photo';
