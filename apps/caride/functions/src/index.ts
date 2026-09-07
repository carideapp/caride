import crypto from "node:crypto";
import https from "node:https";

import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import { HttpsError, onCall } from "firebase-functions/v2/https";
import { onDocumentCreated, onDocumentUpdated, onDocumentWritten } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { setGlobalOptions } from "firebase-functions/v2";

const REGION_PRIMARY = "us-east1";
const REGION_SCHEDULE = "us-west1";

setGlobalOptions({ cpu: 0.25, memory: "256MiB", maxInstances: 2 });

admin.initializeApp();


// ─────────────────────────── Types ───────────────────────────

type RequestOtpPayload = { email?: string; isSignUp?: boolean; role?: string; referredByCode?: string };
type VerifyOtpPayload = { challengeId?: string; email?: string; code?: string };
type InitPaystackPayload = { email?: string; amountKobo?: number; channels?: string[] };
type ChargePaystackPayload = { authorizationCode?: string; email?: string; amountKobo?: number };
type VerifyPaystackPayload = { reference?: string };

type DirectChargePayload = {
  cardNumber: string;
  cvv: string;
  expiryMonth: string;
  expiryYear: string;
  amountNaira: number;
  email: string;
  authorization?: Record<string, any>;
};

type ValidateChargePayload = {
  flwRef: string;
  otp: string;
};

type InitFlutterwavePayload = { amountNaira?: number; channels?: string[] };
type ChargeFlutterwavePayload = { authorizationCode?: string; email?: string; amountNaira?: number };
type VerifyFlutterwavePayload = { reference?: string };
type ResolveBankAccountPayload = {
  bankCode?: string;
  accountNumber?: string;
};
type SaveDriverBankAccountPayload = {
  bankCode?: string;
  bankName?: string;
  accountNumber?: string;
};
type CreateBidPayload = { rideId?: string; offerNaira?: number; etaMinutes?: number };
type UpdateRideStatusPayload = { rideId?: string; newStatus?: string; code?: string };
type PublishLocationPayload = {
  rideId?: string;
  lat?: number;
  lng?: number;
  heading?: number;
  speedMps?: number;
  accuracyM?: number;
};
type CompleteRidePayload = { rideId?: string };
type RespondToBidPayload = {
  rideId?: string;
  bidId?: string;
  action?: "accept" | "reject" | "counter";
  counterOffer?: number;
};
type CancelRideByCustomerPayload = { rideId?: string; reason?: string };
type RateCustomerPayload = { rideId?: string; rating?: number; comment?: string };
type CreateDriverProfilePayload = { referredByCode?: string; fullName?: string; phone?: string };
type AdminProcessWithdrawalPayload = { snapshotId?: string; driverUid?: string };


interface TierSetting {
  name: string;
  commissionPercent: number;
  minTrips: number;
  maxTrips: number | null;
  minRating: number;
  order: number;
}

interface VehicleInfoRecord {
  make?: string;
  model?: string;
  year?: number;
  color?: string;
  plateNumber?: string;
  vehicleType?: string;
  seatCount?: number;
  vehiclePhotoUrl?: string;
}

interface VehicleReviewRecord {
  status?: string;
  rejectionReason?: string | null;
  oldValues?: VehicleInfoRecord | null;
  newValues?: VehicleInfoRecord | null;
}

// ─────────────────────────── Constants ───────────────────────

const OTP_LENGTH = 6;
const OTP_TTL_MINUTES = 10;
const MAX_VERIFY_ATTEMPTS = 5;
const REFERRAL_COMMISSION_PERCENT = 2;
const VEHICLE_TYPE_REGULAR = "regular";
const VEHICLE_TYPE_COMFORT = "comfort";
const VEHICLE_TYPE_LUXURY = "luxury";
const VEHICLE_TYPE_COURIER = "courier";
const STANDARD_DRIVER_DOCUMENT_TYPES = [
  "national_id",
  "drivers_license",
  "profile_photo",
  "proof_of_address",
  "guarantor_info",
  "vehicle_registration",
  "proof_of_ownership",
  "proof_of_insurance",
  "road_worthiness",
  "vehicle_photo_front",
  "vehicle_photo_back",
] as const;
const COURIER_DRIVER_DOCUMENT_TYPES = [
  "national_id",
  "drivers_license",
  "profile_photo",
  "rider_permit",
  "proof_of_address",
  "guarantor_info",
  "vehicle_registration",
  "proof_of_ownership",
  "proof_of_insurance",
  "road_worthiness",
  "vehicle_photo_front",
  "vehicle_photo_back",
] as const;

const DOCUMENT_LABELS: Record<string, string> = {
  national_id: "National ID",
  drivers_license: "Driver's Licence",
  rider_permit: "Rider Permit",
  proof_of_address: "Proof of Address",
  guarantor_info: "Guarantor Information",
  vehicle_registration: "Vehicle Registration",
  proof_of_ownership: "Proof of Ownership",
  proof_of_insurance: "Proof of Insurance",
  road_worthiness: "Road Worthiness Certificate",
  vehicle_photo: "Vehicle Photo",
  vehicle_photo_front: "Vehicle Photo (Front)",
  vehicle_photo_back: "Vehicle Photo (Back)",
  profile_photo: "Profile Photo",
};

const CARIDE_LOGO_URL =
  process.env.CARIDE_LOGO_URL ??
  "https://firebasestorage.googleapis.com/v0/b/caride-app.firebasestorage.app/o/assets%2FCaRide_logo.png?alt=media&token=5c82f4b5-9f02-4fff-8dd7-a432b2f61356";

const challengeCollection = admin.firestore().collection("otpChallenges");
const customersCollection = admin.firestore().collection("customers");
const driversCollection = admin.firestore().collection("drivers");
const driverPresenceCollection = admin.firestore().collection("driverPresence");
const tierSettingsCollection = admin.firestore().collection("tierSettings");

/** Default tier settings seeded when none exist. */
const DEFAULT_TIER_SETTINGS: Record<string, TierSetting> = {
  bronze: { name: "Bronze", commissionPercent: 20, minTrips: 0, maxTrips: 49, minRating: 0, order: 1 },
  silver: { name: "Silver", commissionPercent: 19, minTrips: 50, maxTrips: 149, minRating: 4.0, order: 2 },
  gold: { name: "Gold", commissionPercent: 18, minTrips: 150, maxTrips: 299, minRating: 4.5, order: 3 },
  platinum: { name: "Platinum", commissionPercent: 17, minTrips: 300, maxTrips: null, minRating: 4.7, order: 4 },
};

// ─────────────────────────── Helpers ─────────────────────────

function sanitizeEmail(input?: string): string {
  if (!input) throw new HttpsError("invalid-argument", "Email is required.");
  return input.trim().toLowerCase();
}

function isValidEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function sanitizeE164Phone(raw?: string): string | undefined {
  if (!raw) return undefined;
  let p = raw.trim().replace(/[\s\-\(\)]/g, "");
  if (!p) return undefined;
  if (p.startsWith("0")) {
    p = "+234" + p.slice(1);
  }
  if (!p.startsWith("+")) {
    p = "+" + p;
  }
  if (/^\+[1-9]\d{6,14}$/.test(p)) {
    return p;
  }
  return undefined;
}

function generateOtpCode(): string {
  const min = 10 ** (OTP_LENGTH - 1);
  const max = 10 ** OTP_LENGTH - 1;
  return String(Math.floor(min + Math.random() * (max - min + 1)));
}

function hashCode(code: string): string {
  return crypto.createHash("sha256").update(code).digest("hex");
}

/** Generates a unique 6-character alphanumeric referral code. */
function generateReferralCode(): string {
  return crypto.randomBytes(4).toString("hex").toUpperCase().slice(0, 6);
}

/**
 * Determines the correct tier key based on completedRides and averageRating,
 * using the provided tier settings sorted by order ascending.
 */
function calculateTier(
  completedRides: number,
  averageRating: number,
  settings: Record<string, TierSetting>
): string {
  const sorted = Object.entries(settings).sort((a, b) => b[1].order - a[1].order);
  for (const [key, tier] of sorted) {
    const meetsTrips = completedRides >= tier.minTrips;
    const meetsRating = averageRating >= tier.minRating || completedRides === 0;
    if (meetsTrips && meetsRating) return key;
  }
  return "bronze";
}

function normalizeVehicleType(vehicleType?: string): string {
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

function requiredDriverDocumentsForVehicleType(vehicleType?: string): readonly string[] {
  return normalizeVehicleType(vehicleType) === VEHICLE_TYPE_COURIER ?
    COURIER_DRIVER_DOCUMENT_TYPES :
    STANDARD_DRIVER_DOCUMENT_TYPES;
}

function maskAccountNumber(accountNumber: string): string {
  const trimmed = accountNumber.trim();
  const visible = trimmed.slice(-4);
  return `****${visible}`;
}

function formatNairaCurrency(amount: number): string {
  return "\u20a6" + new Intl.NumberFormat("en-NG").format(Math.round(amount));
}

async function writeVerificationHistory(
  uid: string,
  entryType: string,
  data: Record<string, unknown>
): Promise<void> {
  await driversCollection
    .doc(uid)
    .collection("verificationHistory")
    .add({
      type: entryType,
      ...data,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
}

async function syncDriverApprovalStatus(uid: string): Promise<string> {
  const driverRef = driversCollection.doc(uid);
  const docsRef = driverRef.collection("documents");
  const approvedVehicleRef = driverRef.collection("vehicle").doc("info");
  const vehicleReviewRef = driverRef.collection("vehicle").doc("review");

  const [docsSnap, approvedVehicleSnap, vehicleReviewSnap] = await Promise.all([
    docsRef.get(),
    approvedVehicleRef.get(),
    vehicleReviewRef.get(),
  ]);

  const approvedVehicle = approvedVehicleSnap.exists ?
    (approvedVehicleSnap.data() as VehicleInfoRecord) :
    null;
  const vehicleReview = vehicleReviewSnap.exists ?
    (vehicleReviewSnap.data() as VehicleReviewRecord) :
    null;
  const currentVehicleType = normalizeVehicleType(
    vehicleReview?.newValues?.vehicleType ?? approvedVehicle?.vehicleType
  );
  const requiredDocTypes = requiredDriverDocumentsForVehicleType(currentVehicleType);
  const documentRows = new Map<string, {status?: string; rejectionReason?: string | null}>();
  docsSnap.docs.forEach((doc) => {
    documentRows.set(doc.id, {
      status: doc.data().status as string | undefined,
      rejectionReason: doc.data().rejectionReason as string | null | undefined,
    });
  });

  const hasRejectedDocument = requiredDocTypes.some((typeId) => documentRows.get(typeId)?.status === "rejected");
  const rejectedDocument = requiredDocTypes
    .map((typeId) => ({typeId, row: documentRows.get(typeId)}))
    .find((entry) => entry.row?.status === "rejected");
  const vehicleReviewStatus = vehicleReview?.status;
  const vehicleApproved = vehicleReviewStatus ?
    vehicleReviewStatus === "approved" :
    Boolean(approvedVehicle);
  const allDocsApproved = requiredDocTypes.every((typeId) => documentRows.get(typeId)?.status === "approved");
  const hasStartedVerification = Boolean(
    approvedVehicle ||
      vehicleReview ||
      requiredDocTypes.some((typeId) => documentRows.has(typeId))
  );

  let approvalStatus = "draft";
  let rejectionReason: string | null = null;

  if (vehicleReviewStatus === "rejected") {
    approvalStatus = "rejected";
    rejectionReason = vehicleReview?.rejectionReason ?? "Vehicle information update was rejected.";
  } else if (hasRejectedDocument) {
    approvalStatus = "rejected";
    rejectionReason = rejectedDocument?.row?.rejectionReason ??
      `A required document (${rejectedDocument?.typeId ?? "document"}) was rejected.`;
  } else if (vehicleApproved && allDocsApproved && hasStartedVerification) {
    approvalStatus = "approved";
  } else if (hasStartedVerification) {
    approvalStatus = "pending";
  }

  await driverRef.set({
    approvalStatus,
    rejectionReason,
    verificationRequirements: Array.from(requiredDocTypes),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});

  await driverPresenceCollection.doc(uid).set({
    approvalStatusSnapshot: approvalStatus,
    ...(approvalStatus === "approved" ? {} : {
      availabilityState: "offline",
      isAvailableForRequests: false,
      currentRideId: null,
    }),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});

  return approvalStatus;
}

async function fetchAllTierSettings(): Promise<Record<string, TierSetting>> {
  const snap = await tierSettingsCollection.get();
  if (snap.empty) return DEFAULT_TIER_SETTINGS;
  const result: Record<string, TierSetting> = {};
  snap.docs.forEach((doc) => {
    result[doc.id] = doc.data() as TierSetting;
  });
  return result;
}


// ───────────────────────── Resend Email + FCM Push ─────────────────────────

function buildEmailHtml(bodyHtml: string): string {
  return [
    '<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"></head>',
    '<body style="margin:0;padding:0;background:#f0f4f0;font-family:-apple-system,BlinkMacSystemFont,\'Segoe UI\',Roboto,Arial,sans-serif;">',
    '<table width="100%" cellpadding="0" cellspacing="0" style="background:#f0f4f0;padding:40px 16px;"><tr><td align="center">',
    '<table width="600" cellpadding="0" cellspacing="0" style="max-width:600px;width:100%;background:#fff;border-radius:16px;overflow:hidden;box-shadow:0 8px 32px rgba(0,0,0,.10);">',
    '<tr><td style="background:#fff;padding:32px 40px 20px;border-bottom:3px solid #16a34a;text-align:center;">',
    `<img src="${CARIDE_LOGO_URL}" alt="CaRide" style="height:52px;width:auto;max-width:180px;" /></td></tr>`,
    `<tr><td style="padding:40px;color:#111827;font-size:15px;line-height:1.7;">${bodyHtml}</td></tr>`,
    '<tr><td style="background:#f8faf8;padding:28px 40px;border-top:1px solid #e5e7eb;">',
    '<table width="100%" cellpadding="0" cellspacing="0"><tr><td align="center">',
    '<p style="margin:0 0 12px;font-size:10px;font-weight:700;letter-spacing:3px;text-transform:uppercase;color:#6b7280;">FOLLOW US</p>',
    '<table cellpadding="0" cellspacing="4" style="margin:0 auto;"><tr>',
    '<td><a href="https://www.caride.ng" style="color:#16a34a;text-decoration:none;font-size:12px;">&#127760;&nbsp;caride.ng</a></td>',
    '<td>&nbsp;&bull;&nbsp;</td><td><a href="https://facebook.com/carideapp_ng" style="color:#16a34a;text-decoration:none;font-size:12px;">Facebook</a></td>',
    '<td>&nbsp;&bull;&nbsp;</td><td><a href="https://instagram.com/carideapp_ng" style="color:#16a34a;text-decoration:none;font-size:12px;">Instagram</a></td>',
    '<td>&nbsp;&bull;&nbsp;</td><td><a href="https://tiktok.com/@carideapp_ng" style="color:#16a34a;text-decoration:none;font-size:12px;">TikTok</a></td>',
    '<td>&nbsp;&bull;&nbsp;</td><td><a href="https://x.com/carideapp_ng" style="color:#16a34a;text-decoration:none;font-size:12px;">X</a></td>',
    '</tr></table>',
    '<p style="margin:14px 0 0;font-size:11px;color:#9ca3af;">&copy; 2026 CaRide.</p>',
    '</td></tr></table></td></tr>',
    '</table></td></tr></table></body></html>',
  ].join("\n");
}

async function sendResendEmail(to: string, subject: string, html: string): Promise<void> {
  const apiKey = process.env.RESEND_API_KEY;
  const from = process.env.RESEND_FROM_EMAIL ?? "no-reply@caride.ng";
  if (!apiKey) { logger.warn("RESEND_API_KEY not set — skipping email", { to }); return; }
  const payload = JSON.stringify({ from, to, subject, html });
  await new Promise<void>((resolve, reject) => {
    const req = https.request(
      {
        hostname: "api.resend.com", path: "/emails", method: "POST",
        headers: { Authorization: `Bearer ${apiKey}`, "Content-Type": "application/json", "Content-Length": Buffer.byteLength(payload) },
      },
      (res) => {
        let d = ""; res.on("data", (c) => (d += c));
        res.on("end", () => { if ((res.statusCode ?? 0) >= 400) logger.error("Resend error", { status: res.statusCode, d }); resolve(); });
      }
    );
    req.on("error", (e) => { logger.error("Resend request failed", { e: e.message }); reject(e); });
    req.write(payload); req.end();
  });
}

async function sendPushToDriver(driverUid: string, title: string, body: string, data?: Record<string, string>): Promise<void> {
  try {
    const snap = await driversCollection.doc(driverUid).get();
    const token = snap.data()?.fcmToken as string | undefined;
    if (!token) return;
    await admin.messaging().send({
      token, notification: { title, body }, data: data ?? {},
      android: { priority: "high", notification: { sound: "default", channelId: "caride_alerts" } },
      apns: { payload: { aps: { sound: "default", badge: 1 } } },
    });
    logger.info("FCM push sent", { driverUid, title });
  } catch (e) { logger.warn("FCM push failed", { driverUid, e: String(e) }); }
}

async function sendPushToCustomer(customerUid: string, title: string, body: string, data?: Record<string, string>): Promise<void> {
  try {
    const snap = await customersCollection.doc(customerUid).get();
    const token = snap.data()?.fcmToken as string | undefined;
    if (!token) return;
    await admin.messaging().send({
      token, notification: { title, body }, data: data ?? {},
      android: { priority: "high", notification: { sound: "default", channelId: "caride_customer_alerts" } },
      apns: { payload: { aps: { sound: "default", badge: 1 } } },
    });
    logger.info("FCM push sent", { customerUid, title });
  } catch (e) { logger.warn("FCM push failed", { customerUid, e: String(e) }); }
}

async function sendOtpEmail(email: string, code: string): Promise<void> {
  const html = buildEmailHtml(
    `<h2 style="margin:0 0 8px;color:#16a34a;font-size:22px;">Verification Code</h2>` +
    `<p style="margin:0 0 24px;color:#6b7280;">Use this one-time password to sign in to CaRide. Expires in <strong>${OTP_TTL_MINUTES}&nbsp;minutes</strong>.</p>` +
    `<div style="background:#f0fdf4;border:1px solid #bbf7d0;border-radius:12px;padding:28px;text-align:center;margin:0 0 24px;">` +
    `<span style="font-size:44px;font-weight:800;letter-spacing:12px;color:#15803d;font-family:monospace;">${code}</span></div>` +
    `<p style="margin:0 0 10px;color:#111827;font-size:13px;"><strong>Do not share this code</strong> with anyone, including CaRide staff.</p>` +
    `<p style="margin:0;color:#9ca3af;font-size:13px;">If you didn't request this, ignore this email.</p>`
  );
  await sendResendEmail(email, "Your CaRide Verification Code", html);
}

async function sendDriverWelcomeEmail(email: string, fullName: string): Promise<void> {
  const name = fullName || "Driver";
  const html = buildEmailHtml(
    `<h2 style="margin:0 0 8px;color:#16a34a;font-size:22px;">Welcome to CaRide, ${name}!</h2>` +
    `<p style="margin:0 0 16px;color:#374151;">Your driver account is ready. Complete verification to start receiving ride requests and earning.</p>` +
    `<div style="background:#f0fdf4;border:1px solid #bbf7d0;border-radius:12px;padding:18px 18px;margin:0 0 18px;">` +
    `<p style="margin:0;font-weight:800;color:#15803d;">Next steps</p>` +
    `<ol style="margin:10px 0 0;padding-left:18px;color:#374151;">` +
    `<li style="margin-bottom:6px;">Complete your profile</li>` +
    `<li style="margin-bottom:6px;">Add your vehicle information</li>` +
    `<li style="margin-bottom:6px;">Upload required documents</li>` +
    `<li>Submit for review</li>` +
    `</ol>` +
    `</div>` +
    `<p style="margin:0;color:#6b7280;">Open the CaRide Driver app to continue onboarding.</p>` +
    `<p style="margin:14px 0 0;color:#9ca3af;font-size:13px;">Need help? Contact support@caride.ng</p>`
  );
  await sendResendEmail(email, "Welcome to CaRide Driver", html);
}

async function sendWelcomeEmail(email: string): Promise<void> {
  const html = buildEmailHtml(
    `<h2 style="margin:0 0 8px;color:#16a34a;font-size:22px;">Welcome to CaRide! &#x1F389;</h2>` +
    `<p style="margin:0 0 18px;color:#374151;">Your account is ready. Here\u2019s how to get started:</p>` +
    `<ul style="margin:0 0 20px;padding-left:18px;color:#374151;">` +
    `<li style="margin-bottom:8px;">Choose your pickup and dropoff locations</li>` +
    `<li style="margin-bottom:8px;">Select a ride type that fits your budget</li>` +
    `<li style="margin-bottom:8px;">Track your driver live in the app once assigned</li>` +
    `<li>Manage your wallet and receipts from your profile</li>` +
    `</ul>` +
    `<div style="background:#f0fdf4;border-left:4px solid #16a34a;padding:14px 18px;border-radius:0 10px 10px 0;">` +
    `<p style="margin:0;font-weight:700;color:#15803d;">Ready when you are</p>` +
    `<p style="margin:6px 0 0;color:#166534;">Open the CaRide app to book your first ride.</p>` +
    `</div>`
  );
  await sendResendEmail(email, "Welcome to CaRide", html);
}

function _degToRad(deg: number): number {
  return (deg * Math.PI) / 180.0;
}

function _haversineDistanceKm(aLat: number, aLng: number, bLat: number, bLng: number): number {
  const r = 6371.0;
  const dLat = _degToRad(bLat - aLat);
  const dLng = _degToRad(bLng - aLng);
  const lat1 = _degToRad(aLat);
  const lat2 = _degToRad(bLat);
  const x =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) * Math.sin(dLng / 2);
  const c = 2 * Math.atan2(Math.sqrt(x), Math.sqrt(1 - x));
  return r * c;
}

async function sendRideStartedEmail(email: string, rideId: string, ride: Record<string, unknown>): Promise<void> {
  const driverName = (ride.driverName as string | undefined) ?? "your driver";
  const vehicleName = (ride.vehicleName as string | undefined) ?? "";
  const pickupLabel = (ride.pickupLabel as string | undefined) ?? "Pickup";
  const dropoffLabel = (ride.dropoffLabel as string | undefined) ?? "Dropoff";
  const rideType = (ride.rideType as string | undefined) ?? "Regular";
  const vehicleLine = vehicleName ? `<p style="margin:0 0 16px;color:#374151;"><strong>Vehicle:</strong> ${vehicleName}</p>` : "";
  const html = buildEmailHtml(
    `<h2 style="margin:0 0 10px;color:#16a34a;font-size:22px;">Your ride has started</h2>` +
    `<p style="margin:0 0 18px;color:#374151;">${driverName} has started your ${rideType} ride.</p>` +
    `<div style="background:#f0fdf4;border:1px solid #bbf7d0;border-radius:12px;padding:18px 18px;margin:0 0 18px;">` +
    `<p style="margin:0 0 10px;color:#111827;"><strong>From:</strong> ${pickupLabel}</p>` +
    `<p style="margin:0;color:#111827;"><strong>To:</strong> ${dropoffLabel}</p>` +
    `</div>` +
    vehicleLine +
    `<p style="margin:0;color:#6b7280;">Open the CaRide app to track your ride live.</p>` +
    `<p style="margin:14px 0 0;color:#9ca3af;font-size:12px;">Ride ID: ${rideId}</p>`
  );
  await sendResendEmail(email, "CaRide: Ride Started", html);
}

async function sendRideCompletedEmail(email: string, rideId: string, ride: Record<string, unknown>): Promise<void> {
  const pickupLat = ride.pickupLat as number | undefined;
  const pickupLng = ride.pickupLng as number | undefined;
  const dropoffLat = ride.dropoffLat as number | undefined;
  const dropoffLng = ride.dropoffLng as number | undefined;
  const pickupLabel = (ride.pickupLabel as string | undefined) ?? "Pickup";
  const dropoffLabel = (ride.dropoffLabel as string | undefined) ?? "Dropoff";
  const rideType = (ride.rideType as string | undefined) ?? "Regular";
  const paymentMethod = (ride.paymentMethod as string | undefined) ?? "cash";
  const finalFare = (ride.finalFare as number | undefined) ?? (ride.amountNaira as number | undefined) ?? 0;
  const km =
    pickupLat != null && pickupLng != null && dropoffLat != null && dropoffLng != null
      ? _haversineDistanceKm(pickupLat, pickupLng, dropoffLat, dropoffLng)
      : null;
  const distanceLine =
    km != null && isFinite(km) && km > 0
      ? `<p style="margin:0 0 10px;color:#374151;"><strong>Estimated distance:</strong> ${km.toFixed(1)} km</p>`
      : "";
  const html = buildEmailHtml(
    `<h2 style="margin:0 0 10px;color:#16a34a;font-size:22px;">Ride completed</h2>` +
    `<p style="margin:0 0 18px;color:#374151;">Thanks for riding with CaRide.</p>` +
    `<div style="background:#f8faf8;border:1px solid #e5e7eb;border-radius:12px;padding:18px 18px;margin:0 0 18px;">` +
    `<p style="margin:0 0 10px;color:#111827;"><strong>From:</strong> ${pickupLabel}</p>` +
    `<p style="margin:0 0 10px;color:#111827;"><strong>To:</strong> ${dropoffLabel}</p>` +
    `<p style="margin:0 0 10px;color:#374151;"><strong>Ride type:</strong> ${rideType}</p>` +
    distanceLine +
    `<p style="margin:0;color:#111827;"><strong>Total:</strong> ${formatNairaCurrency(finalFare)} <span style="color:#6b7280;font-size:12px;">(${paymentMethod})</span></p>` +
    `</div>` +
    `<p style="margin:0;color:#6b7280;">Open the CaRide app to rate your driver.</p>` +
    `<p style="margin:14px 0 0;color:#9ca3af;font-size:12px;">Ride ID: ${rideId}</p>`
  );
  await sendResendEmail(email, "CaRide: Ride Completed", html);
}

async function sendRideReceiptEmail(email: string, rideId: string, ride: Record<string, unknown>): Promise<void> {
  const pickupLabel = (ride.pickupLabel as string | undefined) ?? "Pickup";
  const dropoffLabel = (ride.dropoffLabel as string | undefined) ?? "Dropoff";
  const rideType = (ride.rideType as string | undefined) ?? "Regular";
  const paymentMethod = (ride.paymentMethod as string | undefined) ?? "cash";
  const finalFare = (ride.finalFare as number | undefined) ?? (ride.amountNaira as number | undefined) ?? 0;
  const driverName = (ride.driverName as string | undefined) ?? "";
  const vehicleName = (ride.vehicleName as string | undefined) ?? "";
  const driverLine = driverName ? `<p style="margin:0 0 10px;color:#374151;"><strong>Driver:</strong> ${driverName}</p>` : "";
  const vehicleLine = vehicleName ? `<p style="margin:0 0 10px;color:#374151;"><strong>Vehicle:</strong> ${vehicleName}</p>` : "";
  const html = buildEmailHtml(
    `<h2 style="margin:0 0 10px;color:#16a34a;font-size:22px;">Payment receipt</h2>` +
    `<p style="margin:0 0 18px;color:#374151;">Here\u2019s a summary of your completed ride.</p>` +
    `<div style="background:#f8faf8;border:1px solid #e5e7eb;border-radius:12px;padding:18px 18px;margin:0 0 18px;">` +
    `<p style="margin:0 0 10px;color:#111827;"><strong>From:</strong> ${pickupLabel}</p>` +
    `<p style="margin:0 0 10px;color:#111827;"><strong>To:</strong> ${dropoffLabel}</p>` +
    `<p style="margin:0 0 10px;color:#374151;"><strong>Ride type:</strong> ${rideType}</p>` +
    driverLine +
    vehicleLine +
    `<hr style="border:none;border-top:1px solid #e5e7eb;margin:14px 0;" />` +
    `<p style="margin:0;color:#111827;"><strong>Total paid:</strong> ${formatNairaCurrency(finalFare)} <span style="color:#6b7280;font-size:12px;">(${paymentMethod})</span></p>` +
    `</div>` +
    `<p style="margin:0;color:#9ca3af;font-size:12px;">Ride ID: ${rideId}</p>`
  );
  await sendResendEmail(email, "CaRide: Payment Receipt", html);
}

async function sendDriverRideStartedEmail(email: string, rideId: string, ride: Record<string, unknown>): Promise<void> {
  const pickupLabel = (ride.pickupLabel as string | undefined) ?? "Pickup";
  const dropoffLabel = (ride.dropoffLabel as string | undefined) ?? "Dropoff";
  const rideType = (ride.rideType as string | undefined) ?? "Regular";
  const html = buildEmailHtml(
    `<h2 style="margin:0 0 10px;color:#16a34a;font-size:22px;">Trip started</h2>` +
    `<p style="margin:0 0 18px;color:#374151;">Your ${rideType} trip is now in progress.</p>` +
    `<div style="background:#f0fdf4;border:1px solid #bbf7d0;border-radius:12px;padding:18px 18px;margin:0 0 18px;">` +
    `<p style="margin:0 0 10px;color:#111827;"><strong>From:</strong> ${pickupLabel}</p>` +
    `<p style="margin:0;color:#111827;"><strong>To:</strong> ${dropoffLabel}</p>` +
    `</div>` +
    `<p style="margin:0;color:#6b7280;">Open the CaRide Driver app to continue.</p>` +
    `<p style="margin:14px 0 0;color:#9ca3af;font-size:12px;">Ride ID: ${rideId}</p>`
  );
  await sendResendEmail(email, "CaRide Driver: Trip Started", html);
}

async function sendDriverRideCompletedEmail(email: string, rideId: string, ride: Record<string, unknown>): Promise<void> {
  const pickupLat = ride.pickupLat as number | undefined;
  const pickupLng = ride.pickupLng as number | undefined;
  const dropoffLat = ride.dropoffLat as number | undefined;
  const dropoffLng = ride.dropoffLng as number | undefined;
  const pickupLabel = (ride.pickupLabel as string | undefined) ?? "Pickup";
  const dropoffLabel = (ride.dropoffLabel as string | undefined) ?? "Dropoff";
  const rideType = (ride.rideType as string | undefined) ?? "Regular";
  const paymentMethod = (ride.paymentMethod as string | undefined) ?? "cash";
  const finalFare = (ride.finalFare as number | undefined) ?? (ride.amountNaira as number | undefined) ?? 0;
  const commissionNaira = (ride.commissionNaira as number | undefined) ?? 0;
  const driverNet = (ride.driverNet as number | undefined) ?? (finalFare - commissionNaira);
  const km =
    pickupLat != null && pickupLng != null && dropoffLat != null && dropoffLng != null
      ? _haversineDistanceKm(pickupLat, pickupLng, dropoffLat, dropoffLng)
      : null;
  const distanceLine =
    km != null && isFinite(km) && km > 0
      ? `<p style="margin:0 0 10px;color:#374151;"><strong>Estimated distance:</strong> ${km.toFixed(1)} km</p>`
      : "";
  const html = buildEmailHtml(
    `<h2 style="margin:0 0 10px;color:#16a34a;font-size:22px;">Trip completed</h2>` +
    `<p style="margin:0 0 18px;color:#374151;">Here\u2019s your trip summary.</p>` +
    `<div style="background:#f8faf8;border:1px solid #e5e7eb;border-radius:12px;padding:18px 18px;margin:0 0 18px;">` +
    `<p style="margin:0 0 10px;color:#111827;"><strong>From:</strong> ${pickupLabel}</p>` +
    `<p style="margin:0 0 10px;color:#111827;"><strong>To:</strong> ${dropoffLabel}</p>` +
    `<p style="margin:0 0 10px;color:#374151;"><strong>Ride type:</strong> ${rideType}</p>` +
    distanceLine +
    `<hr style="border:none;border-top:1px solid #e5e7eb;margin:14px 0;" />` +
    `<p style="margin:0 0 10px;color:#111827;"><strong>Fare:</strong> ${formatNairaCurrency(finalFare)} <span style="color:#6b7280;font-size:12px;">(${paymentMethod})</span></p>` +
    `<p style="margin:0 0 10px;color:#111827;"><strong>Commission:</strong> ${formatNairaCurrency(commissionNaira)}</p>` +
    `<p style="margin:0;color:#111827;"><strong>Net earnings:</strong> ${formatNairaCurrency(driverNet)}</p>` +
    `</div>` +
    `<p style="margin:0;color:#6b7280;">Open the CaRide Driver app to rate the customer.</p>` +
    `<p style="margin:14px 0 0;color:#9ca3af;font-size:12px;">Ride ID: ${rideId}</p>`
  );
  await sendResendEmail(email, "CaRide Driver: Trip Completed", html);
}

function _getNestedValue(obj: unknown, parts: string[]): unknown {
  let cur: unknown = obj;
  for (const p of parts) {
    if (cur == null || typeof cur !== "object") return undefined;
    cur = (cur as Record<string, unknown>)[p];
  }
  return cur;
}

async function claimRideNotifyMarker(rideRef: admin.firestore.DocumentReference, fieldPath: string): Promise<boolean> {
  return admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(rideRef);
    if (!snap.exists) return false;
    const existing = _getNestedValue(snap.data(), fieldPath.split("."));
    if (existing != null) return false;
    tx.update(rideRef, { [fieldPath]: admin.firestore.FieldValue.serverTimestamp() });
    return true;
  });
}

async function sendDocumentStatusEmail(
  email: string, fullName: string, docLabel: string,
  status: "approved" | "rejected", reason?: string | null
): Promise<void> {
  const name = fullName || "Driver";
  const isOk = status === "approved";
  const col = isOk ? "#16a34a" : "#dc2626";
  const bg = isOk ? "#f0fdf4" : "#fef2f2";
  const icon = isOk ? "&#x2705;" : "&#x26A0;&#xFE0F;";
  const html = buildEmailHtml(
    `<h2 style="margin:0 0 8px;color:${col};font-size:20px;">${icon} ${docLabel} ${isOk ? "Approved" : "Rejected"}</h2>` +
    `<p style="margin:0 0 20px;">Hi <strong>${name}</strong>, here is an update on your document submission.</p>` +
    `<div style="background:${bg};border:1px solid ${col};border-radius:10px;padding:20px;margin:0 0 24px;">` +
    `<p style="margin:0;font-size:16px;font-weight:700;color:${col};">${docLabel}</p>` +
    `<p style="margin:6px 0 0;color:${col};font-size:14px;">Status: <strong>${isOk ? "Approved \u2714" : "Rejected \u2718"}</strong></p>` +
    (reason ? `<p style="margin:8px 0 0;color:#374151;font-size:14px;"><strong>Reason:</strong> ${reason}</p>` : "") +
    `</div>` +
    (isOk
      ? `<p style="margin:0;">Great job! Keep uploading remaining documents to complete verification.</p>`
      : `<p style="margin:0;">Please re-upload your <strong>${docLabel}</strong> in the CaRide Driver App and resubmit.</p>`) +
    `<p style="margin:16px 0 0;color:#9ca3af;font-size:13px;">Questions? Contact support@caride.ng</p>`
  );
  const subj = isOk ? `\u2705 Approved: ${docLabel}` : `\u26A0\uFE0F Action Required: ${docLabel}`;
  await sendResendEmail(email, subj, html);
}

async function sendAllDocumentsApprovedEmail(email: string, fullName: string): Promise<void> {
  const name = fullName || "Driver";
  const html = buildEmailHtml(
    `<h2 style="margin:0 0 8px;color:#16a34a;font-size:22px;">&#x1F389; You're Fully Verified!</h2>` +
    `<p style="margin:0 0 16px;">Congratulations, <strong>${name}</strong>! All your documents are approved. You are officially a verified CaRide driver.</p>` +
    `<div style="background:#f0fdf4;border:2px solid #16a34a;border-radius:12px;padding:24px;text-align:center;margin:0 0 24px;">` +
    `<p style="margin:0;font-size:32px;">&#x1F3C6;</p>` +
    `<p style="margin:8px 0 0;font-size:18px;font-weight:700;color:#15803d;">Driver Verified</p>` +
    `<p style="margin:4px 0 0;color:#166534;font-size:14px;">You can now go online and accept ride requests</p></div>` +
    `<p style="margin:0;">Open the CaRide Driver App, set yourself <strong>Online</strong>, and start earning!</p>` +
    `<p style="margin:16px 0 0;color:#9ca3af;font-size:13px;">Welcome to the team! &mdash; The CaRide Team</p>`
  );
  await sendResendEmail(email, "\uD83C\uDF89 You\u2019re Fully Verified on CaRide!", html);
}

async function sendDriverApprovedEmail(email: string, fullName: string): Promise<void> {
  await sendAllDocumentsApprovedEmail(email, fullName);
}

async function sendDriverRejectedEmail(email: string, fullName: string, reason: string): Promise<void> {
  const name = fullName || "Driver";
  const html = buildEmailHtml(
    `<h2 style="margin:0 0 8px;color:#dc2626;font-size:20px;">&#x26A0; Application Update</h2>` +
    `<p style="margin:0 0 16px;">Hi <strong>${name}</strong>, unfortunately your CaRide application could not be approved at this time.</p>` +
    `<div style="background:#fef2f2;border:1px solid #fca5a5;border-radius:10px;padding:20px;margin:0 0 24px;">` +
    `<p style="margin:0;font-weight:700;color:#dc2626;">Reason for rejection:</p>` +
    `<p style="margin:8px 0 0;color:#374151;">${reason}</p></div>` +
    `<p style="margin:0;">Please address the issue above and resubmit your documents via the CaRide Driver App.</p>` +
    `<p style="margin:16px 0 0;color:#9ca3af;font-size:13px;">Need help? Contact support@caride.ng</p>`
  );
  await sendResendEmail(email, "CaRide Driver Application Update", html);
}


async function sendPayoutEmail(
  email: string,
  fullName: string,
  amountNaira: number,
  bankName: string,
  maskedAccount: string,
  snapshotId: string,
  balanceAtPayout: number,
): Promise<void> {
  const name = fullName || "Driver";
  const amount = formatNairaCurrency(amountNaira);
  const balanceText = formatNairaCurrency(balanceAtPayout);
  const html = buildEmailHtml(
    `<h2 style="margin:0 0 8px;color:#16a34a;font-size:22px;">Withdrawal processed</h2>` +
    `<p style="margin:0 0 18px;color:#374151;">Hi <strong>${name}</strong>, your payout has been processed.</p>` +
    `<div style="background:#f8faf8;border:1px solid #e5e7eb;border-radius:12px;padding:18px 18px;margin:0 0 18px;">` +
    `<p style="margin:0 0 10px;color:#111827;"><strong>Amount:</strong> ${amount}</p>` +
    `<p style="margin:0 0 10px;color:#111827;"><strong>Bank:</strong> ${bankName}</p>` +
    `<p style="margin:0 0 10px;color:#111827;"><strong>Account:</strong> ${maskedAccount}</p>` +
    `<p style="margin:0 0 10px;color:#111827;"><strong>Balance at payout:</strong> ${balanceText}</p>` +
    `<p style="margin:0;color:#9ca3af;font-size:12px;">Reference: ${snapshotId}</p>` +
    `</div>` +
    `<p style="margin:0;color:#6b7280;">If you don\u2019t see the funds soon, contact support@caride.ng.</p>`
  );
  await sendResendEmail(email, "CaRide: Withdrawal Receipt", html);
}

async function sendWalletTopUpReceiptEmail(
  email: string,
  reference: string,
  amountNaira: number,
  paymentMethod: string
): Promise<void> {
  const html = buildEmailHtml(
    `<h2 style="margin:0 0 10px;color:#16a34a;font-size:22px;">Wallet Top Up Successful</h2>` +
    `<p style="margin:0 0 18px;color:#374151;">Here is your transaction receipt for funding your CaRide wallet.</p>` +
    `<div style="background:#f8faf8;border:1px solid #e5e7eb;border-radius:12px;padding:18px 18px;margin:0 0 18px;">` +
    `<p style="margin:0 0 10px;color:#374151;"><strong>Amount Funded:</strong> ${formatNairaCurrency(amountNaira)}</p>` +
    `<p style="margin:0 0 10px;color:#374151;"><strong>Payment Method:</strong> ${paymentMethod}</p>` +
    `<p style="margin:0 0 10px;color:#374151;"><strong>Reference:</strong> ${reference}</p>` +
    `<p style="margin:0;color:#374151;"><strong>Date:</strong> ${new Date().toLocaleDateString("en-US", { year: "numeric", month: "long", day: "numeric", hour: "2-digit", minute: "2-digit" })}</p>` +
    `</div>` +
    `<p style="margin:0;color:#6b7280;">Thank you for using CaRide!</p>`
  );
  await sendResendEmail(email, "CaRide: Wallet Top Up Receipt", html);
}

async function sendAdminNotificationEmail(email: string, uid: string): Promise<void> {
  const html = buildEmailHtml(
    `<h2 style="margin:0 0 8px;color:#16a34a;">New Driver Application</h2>` +
    `<p>A driver has submitted their application for review.</p>` +
    `<ul><li><strong>Email:</strong> ${email}</li><li><strong>UID:</strong> ${uid}</li></ul>` +
    `<p>Review in the <a href="https://admin.caride.ng" style="color:#16a34a;">Admin Dashboard</a>.</p>`
  );
  const adminEmail = process.env.ADMIN_EMAIL ?? "admin@caride.ng";
  await sendResendEmail(adminEmail, "New Driver Application Submitted", html);
}

/** Makes a JSON request to the Flutterwave API. */
function flutterwaveRequest<T>(
  method: string,
  path: string,
  body?: object
): Promise<T> {
  return new Promise((resolve, reject) => {
    const secretKey = process.env.FLUTTERWAVE_SECRET_KEY || "FLWSECK-c201c6f7eb05eecf5245124fb70a2155-19ef45e6418vt-X";
    if (!secretKey) {
      reject(new HttpsError("failed-precondition", "Flutterwave is not configured."));
      return;
    }
    const payload = body ? JSON.stringify(body) : undefined;
    const req = https.request(
      {
        hostname: "api.flutterwave.com",
        path: `/v3${path}`,
        method,
        headers: {
          Authorization: `Bearer ${secretKey}`,
          "Content-Type": "application/json",
          ...(payload ? { "Content-Length": Buffer.byteLength(payload) } : {}),
        },
      },
      (res) => {
        let data = "";
        res.on("data", (chunk) => (data += chunk));
        res.on("end", () => {
          try {
            resolve(JSON.parse(data) as T);
          } catch {
            reject(new HttpsError("internal", "Flutterwave returned invalid JSON."));
          }
        });
      }
    );
    req.on("error", (e) =>
      reject(new HttpsError("internal", `Flutterwave request failed: ${e.message}`))
    );
    if (payload) req.write(payload);
    req.end();
  });
}

/** Makes a JSON request to the Paystack API. */
function paystackRequest<T>(
  method: string,
  path: string,
  body?: object
): Promise<T> {
  return new Promise((resolve, reject) => {
    const secretKey = process.env.PAYSTACK_SECRET_KEY;
    if (!secretKey) {
      reject(new HttpsError("failed-precondition", "Paystack is not configured."));
      return;
    }
    const payload = body ? JSON.stringify(body) : undefined;
    const req = https.request(
      {
        hostname: "api.paystack.co",
        path,
        method,
        headers: {
          Authorization: `Bearer ${secretKey}`,
          "Content-Type": "application/json",
          ...(payload ? { "Content-Length": Buffer.byteLength(payload) } : {}),
        },
      },
      (res) => {
        let data = "";
        res.on("data", (chunk) => (data += chunk));
        res.on("end", () => {
          try {
            resolve(JSON.parse(data) as T);
          } catch {
            reject(new HttpsError("internal", "Paystack returned invalid JSON."));
          }
        });
      }
    );
    req.on("error", (e) =>
      reject(new HttpsError("internal", `Paystack request failed: ${e.message}`))
    );
    if (payload) req.write(payload);
    req.end();
  });
}

// ─────────────────────────── OTP Functions ───────────────────

export const requestEmailOtp = onCall({ region: REGION_PRIMARY, maxInstances: 5 }, async (request) => {
  const payload = request.data as RequestOtpPayload;
  const email = sanitizeEmail(payload.email);
  const isSignUp = Boolean(payload.isSignUp);
  const role = payload.role || "customer";

  if (!isValidEmail(email)) {
    throw new HttpsError("invalid-argument", "Invalid email format.");
  }

  const userRecord = await admin.auth().getUserByEmail(email).catch(() => null);
  if (isSignUp && userRecord) {
    // Check if the user already has an active profile for THIS specific role
    if (role === "customer") {
      const customerDoc = await customersCollection.doc(userRecord.uid).get();
      if (customerDoc.exists) {
        throw new HttpsError("already-exists", "Account already exists.");
      }
    } else if (role === "driver") {
      const driverDoc = await driversCollection.doc(userRecord.uid).get();
      if (driverDoc.exists) {
        throw new HttpsError("already-exists", "Driver account already exists.");
      }
    } else if (role === "fleet") {
      const [fleetDoc, fleetManagerDoc] = await Promise.all([
        admin.firestore().collection("fleets").where("ownerUid", "==", userRecord.uid).limit(1).get(),
        admin.firestore().collection("fleet_managers").doc(userRecord.uid).get(),
      ]);
      const hasFleetProfile = !fleetDoc.empty || (fleetManagerDoc.exists && fleetManagerDoc.data()?.verificationStatus === "approved");
      if (hasFleetProfile) {
        throw new HttpsError("already-exists", "Fleet manager account already exists for this email.");
      }
    } else {
      throw new HttpsError("already-exists", "Account already exists.");
    }
  }
  if (!isSignUp && !userRecord) {
    throw new HttpsError("not-found", "No account exists for this email.");
  }

  const expiresAt = new Date(Date.now() + OTP_TTL_MINUTES * 60_000);
  const code = generateOtpCode();
  const challengeId = crypto.randomUUID();

  await challengeCollection.doc(challengeId).set({
    challengeId,
    email,
    codeHash: hashCode(code),
    isSignUp,
    role,
    referredByCode: payload.referredByCode?.trim().toUpperCase() || null,
    attempts: 0,
    maxAttempts: MAX_VERIFY_ATTEMPTS,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    used: false,
  });

  await sendOtpEmail(email, code);
  logger.info("OTP challenge created", { challengeId, email, isSignUp, role });

  return { challengeId, expiresAt: expiresAt.toISOString() };
});

export const sendCustomPasswordResetEmail = onCall({ region: REGION_PRIMARY, maxInstances: 5 }, async (request) => {
  const payload = request.data as { email?: string };
  const email = sanitizeEmail(payload.email);

  if (!isValidEmail(email)) {
    throw new HttpsError("invalid-argument", "Invalid email format.");
  }

  const userRecord = await admin.auth().getUserByEmail(email).catch(() => null);
  if (!userRecord) {
    throw new HttpsError("not-found", "No account exists for this email.");
  }

  try {
    const actionCodeSettings = {
      url: "https://caride-app.web.app",
    };
    let resetLink = await admin.auth().generatePasswordResetLink(email, actionCodeSettings);
    // Replace default unreachable firebaseapp.com with web.app domain
    resetLink = resetLink.replace("caride-app.firebaseapp.com", "caride-app.web.app");

    const html = buildEmailHtml(
      `<h2 style="margin:0 0 8px;color:#16a34a;font-size:22px;">Reset Your Password</h2>` +
      `<p style="margin:0 0 24px;color:#374151;font-size:15px;line-height:1.6;">Hi,</p>` +
      `<p style="margin:0 0 24px;color:#374151;font-size:15px;line-height:1.6;">We received a request to reset the password for your CaRide account. Click the button below to set a new password:</p>` +
      `<div style="text-align:center;margin:32px 0;">` +
      `<a href="${resetLink}" style="background-color:#16a34a;color:#ffffff;padding:14px 28px;text-decoration:none;font-weight:bold;border-radius:8px;font-size:16px;display:inline-block;box-shadow:0 4px 6px rgba(22,163,74,0.2);">Reset Password</a>` +
      `</div>` +
      `<p style="margin:24px 0 10px;color:#6b7280;font-size:13px;line-height:1.6;">If the button doesn't work, you can copy and paste this link into your browser:</p>` +
      `<p style="margin:0 0 24px;color:#16a34a;font-size:12px;word-break:break-all;"><a href="${resetLink}" style="color:#16a34a;text-decoration:underline;">${resetLink}</a></p>` +
      `<p style="margin:0;color:#9ca3af;font-size:13px;">If you didn't request this, you can safely ignore this email.</p>`
    );

    await sendResendEmail(email, "Reset Your CaRide Password", html);
    logger.info("Custom password reset email sent", { email });
    return { success: true };
  } catch (error: any) {
    logger.error("Failed to generate/send custom password reset email", { email, error });
    throw new HttpsError("internal", error.message || "Failed to process password reset request.");
  }
});


export const verifyEmailOtp = onCall({ region: REGION_PRIMARY, maxInstances: 5 }, async (request) => {
  const payload = request.data as VerifyOtpPayload;
  const challengeId = payload.challengeId?.trim();
  const code = payload.code?.trim();
  const email = sanitizeEmail(payload.email);

  if (!challengeId || !code) {
    throw new HttpsError("invalid-argument", "Missing challengeId or code.");
  }
  if (!/^\d{6}$/.test(code)) {
    throw new HttpsError("invalid-argument", "Invalid OTP format.");
  }

  const docRef = challengeCollection.doc(challengeId);
  const snapshot = await docRef.get();
  if (!snapshot.exists) {
    throw new HttpsError("not-found", "OTP challenge not found.");
  }

  const data = snapshot.data() as {
    email: string;
    codeHash: string;
    attempts: number;
    maxAttempts: number;
    used: boolean;
    isSignUp: boolean;
    role?: string;
    referredByCode?: string;
    expiresAt: admin.firestore.Timestamp;
  };

  if (data.used) throw new HttpsError("failed-precondition", "OTP already used.");
  if (data.email !== email) throw new HttpsError("permission-denied", "OTP does not match email.");
  if (data.expiresAt.toDate().getTime() < Date.now()) {
    throw new HttpsError("deadline-exceeded", "OTP has expired.");
  }
  if (data.attempts >= data.maxAttempts) {
    throw new HttpsError("resource-exhausted", "Maximum OTP attempts reached.");
  }
  if (hashCode(code) !== data.codeHash) {
    await docRef.update({ attempts: admin.firestore.FieldValue.increment(1) });
    throw new HttpsError("permission-denied", "Incorrect OTP code.");
  }

  let userRecord = await admin.auth().getUserByEmail(email).catch(() => null);
  const isNewUser = !userRecord;
  if (!userRecord) {
    userRecord = await admin.auth().createUser({
      email,
      emailVerified: true,
      displayName: "",
    });
  }

  await docRef.update({
    used: true,
    verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  const referredByCode = data.referredByCode || null;
  const role = data.role || "customer";

  if ((isNewUser || data.isSignUp) && role === "customer") {
    const customerDocRef = customersCollection.doc(userRecord.uid);
    const customerDoc = await customerDocRef.get();

    if (!customerDoc.exists) {
      let referralCode = generateReferralCode();
      for (let i = 0; i < 3; i++) {
        const existing = await customersCollection
          .where("referralCodeLower", "==", referralCode.toLowerCase())
          .limit(1)
          .get();
        if (existing.empty) break;
        referralCode = generateReferralCode();
      }

      await customerDocRef.set({
        uid: userRecord.uid,
        email,
        fullName: "",
        phone: "",
        gender: "",
        dateOfBirth: "",
        photoUrl: "",
        walletBalance: 0,
        referralCode,
        referralCodeLower: referralCode.toLowerCase(),
        referredByCode,
        referralEarnings: 0,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      if (referredByCode) {
        const cleanRefLower = referredByCode.trim().toLowerCase();
        // Record referral relationship under referrer doc (check customers first, then drivers)
        let referrerDoc = (await customersCollection
          .where("referralCodeLower", "==", cleanRefLower)
          .limit(1)
          .get()).docs[0];
        if (!referrerDoc) {
          referrerDoc = (await customersCollection
            .where("referralCode", "==", referredByCode.trim())
            .limit(1)
            .get()).docs[0];
        }
        if (!referrerDoc) {
          referrerDoc = (await driversCollection
            .where("referralCodeLower", "==", cleanRefLower)
            .limit(1)
            .get()).docs[0];
        }
        if (!referrerDoc) {
          referrerDoc = (await driversCollection
            .where("referralCode", "==", referredByCode.trim())
            .limit(1)
            .get()).docs[0];
        }

        if (referrerDoc) {
          await referrerDoc.ref.collection("referrals").doc(userRecord.uid).set({
            uid: userRecord.uid,
            email,
            joinedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      }

      logger.info("New customer user document created", { uid: userRecord.uid, referralCode, referredByCode });
    }
  } else if ((isNewUser || data.isSignUp) && role === "fleet") {
    // Provision fleet manager document & users metadata for fleet role
    const now = admin.firestore.FieldValue.serverTimestamp();
    const [custSnap, driverSnap] = await Promise.all([
      customersCollection.doc(userRecord.uid).get(),
      driversCollection.doc(userRecord.uid).get(),
    ]);

    await admin.firestore().collection("users").doc(userRecord.uid).set({
      uid: userRecord.uid,
      activeRole: "fleet",
      customerExists: custSnap.exists,
      driverExists: driverSnap.exists,
      fleetExists: false,
      hasFleet: false,
      isFleetSignupInProgress: true,
      updatedAt: now,
    }, { merge: true });

    await admin.firestore().collection("fleet_managers").doc(userRecord.uid).set({
      uid: userRecord.uid,
      email,
      signupStatus: "onboarding",
      signupStep: 1,
      verificationStatus: "draft",
      referredByCode: referredByCode || null,
      createdAt: now,
      updatedAt: now,
    }, { merge: true });

    logger.info("New fleet manager draft document created", { uid: userRecord.uid, email });
  }

  logger.info("OTP challenge verified", { challengeId, email, uid: userRecord.uid, role });

  const customToken = await admin.auth().createCustomToken(userRecord.uid);
  return { customToken };
});

// ─────────────────────────── Driver Profile Callable ─────────

/**
 * Called after a driver verifies their OTP. Creates the driver document in
 * Firestore with initial tier (bronze), a generated referral code, and
 * optionally links them to a referrer via referredByCode.
 */
export const createDriverProfileCallable = onCall({ region: REGION_PRIMARY, maxInstances: 5 }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const uid = request.auth.uid;
  const email = request.auth.token.email ?? "";
  const payload = request.data as CreateDriverProfilePayload;
  const referredByCode = payload.referredByCode?.trim().toUpperCase() ?? null;
  const fullName = payload.fullName?.trim() ?? "";
  const phone = payload.phone?.trim() ?? "";

  const driverRef = driversCollection.doc(uid);
  const driverSnap = await driverRef.get();

  if (driverSnap.exists) {
    // Profile already created — idempotent, return success
    return { success: true, alreadyExists: true };
  }

  // Generate a unique referral code for this driver
  let referralCode = generateReferralCode();
  for (let i = 0; i < 3; i++) {
    const existing = await driversCollection
      .where("referralCode", "==", referralCode)
      .limit(1)
      .get();
    if (existing.empty) break;
    referralCode = generateReferralCode();
  }

  const now = admin.firestore.FieldValue.serverTimestamp();

  await driverRef.set({
    uid,
    email,
    role: "driver",
    fullName,
    phone,
    profilePhotoUrl: "",
    isEmailVerified: true,
    profileCompleted: false,
    approvalStatus: "draft",
    rejectionReason: null,
    walletBalance: 0,
    // Tier system
    tier: "bronze",
    completedRides: 0,
    averageRating: 0.0,
    totalRatings: 0,
    // Referral system
    referralCode,
    referralCodeLower: referralCode.toLowerCase(),
    referralEarnings: 0,
    referredByCode: referredByCode ?? null,
    createdAt: now,
    updatedAt: now,
  });

  await driverPresenceCollection.doc(uid).set({
    driverUid: uid,
    availabilityState: "offline",
    isAvailableForRequests: false,
    currentRideId: null,
    vehicleType: null,
    approvalStatusSnapshot: "draft",
    lastHeartbeatAt: now,
    updatedAt: now,
  }, {merge: true});

  // If referred by someone, record this driver in the referrer's subcollection
  if (referredByCode) {
    const cleanRefLower = referredByCode.trim().toLowerCase();
    let referrerDoc = (await driversCollection
      .where("referralCodeLower", "==", cleanRefLower)
      .limit(1)
      .get()).docs[0];
    if (!referrerDoc) {
      referrerDoc = (await driversCollection
        .where("referralCode", "==", referredByCode.trim())
        .limit(1)
        .get()).docs[0];
    }
    if (!referrerDoc) {
      referrerDoc = (await customersCollection
        .where("referralCodeLower", "==", cleanRefLower)
        .limit(1)
        .get()).docs[0];
    }
    if (!referrerDoc) {
      referrerDoc = (await customersCollection
        .where("referralCode", "==", referredByCode.trim())
        .limit(1)
        .get()).docs[0];
    }

    if (referrerDoc) {
      await referrerDoc.ref.collection("referrals").doc(uid).set({
        driverUid: uid,
        email,
        joinedAt: now,
      });
      logger.info("Referral recorded", { referrerUid: referrerDoc.id, newDriverUid: uid });
    } else {
      logger.warn("Referral code not found for driver", { referredByCode, uid });
    }
  }

  logger.info("Driver profile created via callable", { uid, referralCode });
  return { success: true, referralCode };
});

/**
 * Callable function allowing a customer/driver to apply a referral code to their account.
 * Atomically validates eligibility, single-use restriction, credits Credit Wallet, and logs transactions.
 */
export const applyReferralCode = onCall({ region: REGION_PRIMARY, maxInstances: 10, cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in to apply referral code.");
  }
  const uid = request.auth.uid;
  const referralCodeInput = (request.data?.referralCode as string | undefined)?.trim();

  if (!referralCodeInput || referralCodeInput.length < 3 || referralCodeInput.length > 25) {
    throw new HttpsError("invalid-argument", "Please enter a valid referral code (3-25 characters).");
  }

  const codeLower = referralCodeInput.toLowerCase();
  const codeUpper = referralCodeInput.toUpperCase();

  // 1. Fetch user doc (check customer collection first, then driver)
  let userRef = admin.firestore().collection("customers").doc(uid);
  let userSnap = await userRef.get();
  let userType: "customer" | "driver" = "customer";

  if (!userSnap.exists) {
    userRef = admin.firestore().collection("drivers").doc(uid);
    userSnap = await userRef.get();
    userType = "driver";
  }

  if (!userSnap.exists) {
    throw new HttpsError("not-found", "User profile not found.");
  }

  const userData = userSnap.data()!;
  if (userData.referredByCode) {
    throw new HttpsError("already-exists", "You have already applied a referral code to your account.");
  }

  const userOwnCode = (userData.referralCode as string | undefined)?.toLowerCase();
  if (userOwnCode === codeLower) {
    throw new HttpsError("invalid-argument", "You cannot apply your own referral code.");
  }

  // 2. Find referrer (search customers, drivers, and staff)
  let referrerSnap = (await admin.firestore().collection("customers")
    .where("referralCodeLower", "==", codeLower)
    .limit(1)
    .get()).docs[0];

  if (!referrerSnap) {
    referrerSnap = (await admin.firestore().collection("customers")
      .where("referralCode", "==", codeUpper)
      .limit(1)
      .get()).docs[0];
  }

  if (!referrerSnap) {
    referrerSnap = (await admin.firestore().collection("drivers")
      .where("referralCodeLower", "==", codeLower)
      .limit(1)
      .get()).docs[0];
  }

  if (!referrerSnap) {
    referrerSnap = (await admin.firestore().collection("drivers")
      .where("referralCode", "==", codeUpper)
      .limit(1)
      .get()).docs[0];
  }

  // Check staff collection if not found in customers or drivers
  let isStaffReferrer = false;
  if (!referrerSnap) {
    referrerSnap = (await admin.firestore().collection("staff")
      .where("referralCodeLower", "==", codeLower)
      .limit(1)
      .get()).docs[0];

    if (!referrerSnap) {
      referrerSnap = (await admin.firestore().collection("staff")
        .where("referralCode", "==", codeUpper)
        .limit(1)
        .get()).docs[0];
    }

    if (!referrerSnap) {
      referrerSnap = (await admin.firestore().collection("staff")
        .where("referralCode", "==", referralCodeInput)
        .limit(1)
        .get()).docs[0];
    }

    if (referrerSnap) isStaffReferrer = true;
  }

  if (!referrerSnap) {
    throw new HttpsError("not-found", "Invalid referral code. Please check and try again.");
  }

  if (referrerSnap.id === uid) {
    throw new HttpsError("invalid-argument", "You cannot apply your own referral code.");
  }

  // 3. Read configured creditAmount
  let creditAmount = 1000;
  try {
    const settingsSnap = await admin.firestore().collection("config").doc("referralSettings").get();
    if (settingsSnap.exists && typeof settingsSnap.data()?.creditAmount === "number") {
      creditAmount = settingsSnap.data()!.creditAmount;
    }
  } catch (_) {}

  const referrerData = referrerSnap.data()!;
  const referrerName = referrerData.fullName || referrerData.email || "Referrer";

  // 4. Perform atomic credit updates
  await admin.firestore().runTransaction(async (tx) => {
    if (isStaffReferrer) {
      tx.update(userRef, {
        referredByCode: referrerData.referralCode || referralCodeInput,
        staffId: referrerSnap.id,
        creditBalance: admin.firestore.FieldValue.increment(creditAmount),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const isCust = userType === "customer";
      tx.update(referrerSnap.ref, {
        "stats.totalReferrals": admin.firestore.FieldValue.increment(1),
        "stats.customersReferred": isCust ? admin.firestore.FieldValue.increment(1) : admin.firestore.FieldValue.increment(0),
        "stats.driversReferred": !isCust ? admin.firestore.FieldValue.increment(1) : admin.firestore.FieldValue.increment(0),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const staffRefSub = referrerSnap.ref.collection("referrals").doc(uid);
      tx.set(staffRefSub, {
        referredUid: uid,
        userType: userType,
        email: userData.email || "",
        fullName: userData.fullName || "",
        referralCode: referralCodeInput,
        staffTypeAtJoin: referrerData.staffType || "tracking",
        joinedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const userCreditTxRef = admin.firestore().collection("credit_transactions").doc();
      tx.set(userCreditTxRef, {
        uid: uid,
        type: "referral_reward",
        amountNaira: creditAmount,
        referralCode: referralCodeInput,
        referredUserUid: referrerSnap.id,
        description: `Welcome referral bonus from CaRide Staff (${referrerName})`,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      // Regular customer/driver referrer
      tx.update(userRef, {
        referredByCode: referrerData.referralCode || referralCodeInput,
        creditBalance: admin.firestore.FieldValue.increment(creditAmount),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      tx.update(referrerSnap.ref, {
        creditBalance: admin.firestore.FieldValue.increment(creditAmount),
        referralEarnings: admin.firestore.FieldValue.increment(creditAmount),
        successfulReferralsCount: admin.firestore.FieldValue.increment(1),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const referralSubRef = referrerSnap.ref.collection("referrals").doc(uid);
      tx.set(referralSubRef, {
        referredUid: uid,
        email: userData.email || "",
        fullName: userData.fullName || "",
        status: "completed",
        rewardAmount: creditAmount,
        referralCode: referralCodeInput,
        joinedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const userCreditTxRef = admin.firestore().collection("credit_transactions").doc();
      tx.set(userCreditTxRef, {
        uid: uid,
        type: "referral_reward",
        amountNaira: creditAmount,
        referralCode: referralCodeInput,
        referredUserUid: referrerSnap.id,
        description: `Welcome referral bonus from ${referrerName}`,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const referrerCreditTxRef = admin.firestore().collection("credit_transactions").doc();
      tx.set(referrerCreditTxRef, {
        uid: referrerSnap.id,
        type: "referral_reward",
        amountNaira: creditAmount,
        referralCode: referralCodeInput,
        referredUserUid: uid,
        description: `Referral reward for inviting ${userData.fullName || userData.email || 'a new user'}`,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });

  return {
    success: true,
    creditAmount,
    referrerName,
    message: `Successfully applied referral code! ₦${creditAmount.toLocaleString()} has been added to your Credit Wallet.`,
  };
});

/**
 * Callable function for Admin to create a new Staff account.
 * Creates Firebase Auth user, assigns 'staff' role, validates unique referral code, and creates staff profile in Firestore.
 */
export const createStaffAccount = onCall({ region: REGION_PRIMARY, maxInstances: 5, cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in as Admin.");
  }

  const {
    firstName,
    lastName,
    email,
    phone,
    staffType,
    commissionRatePercent = 0,
    referralCode,
    password,
    staffId: customStaffId,
  } = request.data ?? {};

  if (!firstName || !lastName || !email || !password || !referralCode || !staffType) {
    throw new HttpsError("invalid-argument", "Missing required staff registration details.");
  }

  if (staffType !== "tracking" && staffType !== "commission") {
    throw new HttpsError("invalid-argument", "Staff type must be either 'tracking' or 'commission'.");
  }

  const codeTrimmed = (referralCode as string).trim();
  const codeLower = codeTrimmed.toLowerCase();

  // 1. Verify referral code uniqueness across customers, drivers, and staff
  const [custCodeSnap, driverCodeSnap, staffCodeSnap] = await Promise.all([
    admin.firestore().collection("customers").where("referralCodeLower", "==", codeLower).limit(1).get(),
    admin.firestore().collection("drivers").where("referralCodeLower", "==", codeLower).limit(1).get(),
    admin.firestore().collection("staff").where("referralCodeLower", "==", codeLower).limit(1).get(),
  ]);

  if (!custCodeSnap.empty || !driverCodeSnap.empty || !staffCodeSnap.empty) {
    throw new HttpsError("already-exists", `Referral code '${codeTrimmed}' is already taken by another account.`);
  }

  // 2. Create Firebase Auth User
  let authUser;
  const e164Phone = sanitizeE164Phone(phone as string | undefined);
  try {
    authUser = await admin.auth().createUser({
      email: (email as string).trim(),
      password: (password as string).trim(),
      displayName: `${firstName.trim()} ${lastName.trim()}`,
      ...(e164Phone ? { phoneNumber: e164Phone } : {}),
    });
  } catch (err: any) {
    throw new HttpsError("already-exists", err.message || "Failed to create staff authentication user.");
  }

  // Set custom claims for RBAC
  await admin.auth().setCustomUserClaims(authUser.uid, { role: "staff", staffType });

  const generatedStaffId = customStaffId ? (customStaffId as string).trim() : `STAFF-${Math.floor(1000 + Math.random() * 9000)}`;

  // 3. Create Staff profile document in Firestore
  const staffDocRef = admin.firestore().collection("staff").doc(authUser.uid);
  const now = admin.firestore.FieldValue.serverTimestamp();

  const allowedPagesInput = Array.isArray(request.data?.allowedPages)
    ? request.data.allowedPages
    : ["announcements", "customer_support", "driver_support", "promotion", "offers", "verification"];

  await staffDocRef.set({
    staffUid: authUser.uid,
    staffId: generatedStaffId,
    firstName: (firstName as string).trim(),
    lastName: (lastName as string).trim(),
    fullName: `${(firstName as string).trim()} ${(lastName as string).trim()}`,
    email: (email as string).trim(),
    phone: phone ? (phone as string).trim() : "",
    role: "staff",
    staffType, // 'tracking' or 'commission'
    commissionRatePercent: staffType === "commission" ? Number(commissionRatePercent) || 0 : 0,
    allowedPages: allowedPagesInput,
    referralCode: codeTrimmed,
    referralCodeLower: codeLower,
    referralLink: `https://www.caride.ng/app/referral/${codeTrimmed}`,
    previousReferralCodes: [],
    accountStatus: "active", // 'active', 'suspended', 'disabled'
    wallet: {
      availableBalance: 0,
      pendingWithdrawals: 0,
      totalEarned: 0,
      totalWithdrawn: 0,
    },
    bankDetails: {
      bankName: "",
      accountName: "",
      accountNumber: "",
    },
    stats: {
      totalReferrals: 0,
      customersReferred: 0,
      driversReferred: 0,
      totalCompanyCommissionGenerated: 0,
    },
    createdAt: now,
    updatedAt: now,
  });

  logger.info("Staff account created successfully", { staffUid: authUser.uid, staffType, referralCode: codeTrimmed });

  return {
    success: true,
    staffUid: authUser.uid,
    staffId: generatedStaffId,
    referralCode: codeTrimmed,
    referralLink: `https://www.caride.ng/app/referral/${codeTrimmed}`,
  };
});

/**
 * Callable function for Admin to update an existing Staff profile.
 * Supports changing referral code (maintaining legacy codes), staff type, commission percentage, and account status.
 */
export const updateStaffProfile = onCall({ region: REGION_PRIMARY, maxInstances: 5, cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in as Admin.");
  }

  const {
    staffUid,
    firstName,
    lastName,
    phone,
    staffType,
    commissionRatePercent,
    referralCode,
    accountStatus,
    bankDetails,
  } = request.data ?? {};

  if (!staffUid) {
    throw new HttpsError("invalid-argument", "Missing staffUid parameter.");
  }

  const staffRef = admin.firestore().collection("staff").doc(staffUid);
  const staffSnap = await staffRef.get();
  if (!staffSnap.exists) {
    throw new HttpsError("not-found", "Staff profile not found.");
  }

  const currentStaff = staffSnap.data()!;
  const updates: Record<string, any> = {
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (firstName && lastName) {
    updates.firstName = (firstName as string).trim();
    updates.lastName = (lastName as string).trim();
    updates.fullName = `${(firstName as string).trim()} ${(lastName as string).trim()}`;
  }

  if (phone !== undefined) updates.phone = (phone as string).trim();
  if (accountStatus) updates.accountStatus = accountStatus;
  if (bankDetails) updates.bankDetails = bankDetails;
  if (Array.isArray(request.data?.allowedPages)) {
    updates.allowedPages = request.data.allowedPages;
  }

  if (staffType) {
    if (staffType !== "tracking" && staffType !== "commission") {
      throw new HttpsError("invalid-argument", "Staff type must be either 'tracking' or 'commission'.");
    }
    updates.staffType = staffType;
  }

  const newStaffType = staffType || currentStaff.staffType;
  if (newStaffType === "commission") {
    if (commissionRatePercent !== undefined) {
      const rate = Number(commissionRatePercent);
      if (isNaN(rate) || rate < 0 || rate > 100) {
        throw new HttpsError("invalid-argument", "Commission percentage must be between 0% and 100%.");
      }
      updates.commissionRatePercent = rate;
    }
  } else {
    updates.commissionRatePercent = 0;
  }

  // Handle referral code modification and uniqueness validation
  if (referralCode && (referralCode as string).trim() !== currentStaff.referralCode) {
    const newCode = (referralCode as string).trim();
    const newCodeLower = newCode.toLowerCase();

    const [cSnap, dSnap, sSnap] = await Promise.all([
      admin.firestore().collection("customers").where("referralCodeLower", "==", newCodeLower).limit(1).get(),
      admin.firestore().collection("drivers").where("referralCodeLower", "==", newCodeLower).limit(1).get(),
      admin.firestore().collection("staff").where("referralCodeLower", "==", newCodeLower).limit(1).get(),
    ]);

    if (!cSnap.empty || !dSnap.empty || (!sSnap.empty && sSnap.docs[0].id !== staffUid)) {
      throw new HttpsError("already-exists", `Referral code '${newCode}' is already taken.`);
    }

    const prevCodes = currentStaff.previousReferralCodes || [];
    if (!prevCodes.includes(currentStaff.referralCode)) {
      prevCodes.push(currentStaff.referralCode);
    }

    updates.referralCode = newCode;
    updates.referralCodeLower = newCodeLower;
    updates.referralLink = `https://www.caride.ng/app/referral/${newCode}`;
    updates.previousReferralCodes = prevCodes;
  }

  await staffRef.update(updates);
  return { success: true, message: "Staff profile updated successfully." };
});

/**
 * Callable function for Commission Staff to submit a withdrawal request.
 * Atomically reserves balance from availableBalance to pendingWithdrawals.
 */
export const requestStaffWithdrawal = onCall({ region: REGION_PRIMARY, maxInstances: 5 }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in to request withdrawal.");
  }
  const staffUid = request.auth.uid;
  const amount = Number(request.data?.amount);

  if (isNaN(amount) || amount <= 0) {
    throw new HttpsError("invalid-argument", "Please enter a valid withdrawal amount.");
  }

  const staffRef = admin.firestore().collection("staff").doc(staffUid);

  await admin.firestore().runTransaction(async (tx) => {
    const staffSnap = await tx.get(staffRef);
    if (!staffSnap.exists) {
      throw new HttpsError("not-found", "Staff profile not found.");
    }
    const data = staffSnap.data()!;
    if (data.accountStatus !== "active") {
      throw new HttpsError("permission-denied", "Your staff account is not active.");
    }
    if (data.staffType !== "commission") {
      throw new HttpsError("failed-precondition", "Only Commission Staff can request withdrawals.");
    }

    const avail = (data.wallet?.availableBalance as number) || 0;
    if (amount > avail) {
      throw new HttpsError("failed-precondition", `Insufficient available balance. You have ₦${avail.toLocaleString()} available.`);
    }

    // Immediately reserve requested amount from availableBalance
    tx.update(staffRef, {
      "wallet.availableBalance": admin.firestore.FieldValue.increment(-amount),
      "wallet.pendingWithdrawals": admin.firestore.FieldValue.increment(amount),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const withdrawalRef = admin.firestore().collection("staff_withdrawal_requests").doc();
    const now = admin.firestore.FieldValue.serverTimestamp();
    const dateStr = new Date().toISOString().slice(0, 10).replace(/-/g, "");
    const customWdId = `WD-CARIDE-${dateStr}-${withdrawalRef.id.slice(0, 5).toUpperCase()}`;

    tx.set(withdrawalRef, {
      withdrawalId: customWdId,
      staffId: staffUid,
      staffName: data.fullName || `${data.firstName || ''} ${data.lastName || ''}`.trim(),
      staffEmail: data.email || "",
      amount,
      status: "pending",
      bankDetails: data.bankDetails || {},
      requestedAt: now,
      createdAt: now,
    });
  });

  return { success: true, message: `Withdrawal request for ₦${amount.toLocaleString()} submitted successfully.` };
});

/**
 * Callable function for Admin to process (Pay or Reject) a staff withdrawal request.
 */
export const processStaffWithdrawal = onCall({ region: REGION_PRIMARY, maxInstances: 5, cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in as Admin.");
  }
  const adminUid = request.auth.uid;
  const { withdrawalDocId, action, rejectionReason } = request.data ?? {};

  if (!withdrawalDocId || (action !== "paid" && action !== "reject")) {
    throw new HttpsError("invalid-argument", "Invalid parameters. Action must be 'paid' or 'reject'.");
  }

  if (action === "reject" && !rejectionReason?.trim()) {
    throw new HttpsError("invalid-argument", "Please provide a rejection reason.");
  }

  const wdRef = admin.firestore().collection("staff_withdrawal_requests").doc(withdrawalDocId);

  await admin.firestore().runTransaction(async (tx) => {
    const wdSnap = await tx.get(wdRef);
    if (!wdSnap.exists) {
      throw new HttpsError("not-found", "Withdrawal request not found.");
    }
    const wdData = wdSnap.data()!;
    if (wdData.status !== "pending") {
      throw new HttpsError("failed-precondition", `This withdrawal request is already ${wdData.status}.`);
    }

    const staffRef = admin.firestore().collection("staff").doc(wdData.staffId);
    const amount = Number(wdData.amount) || 0;

    if (action === "paid") {
      tx.update(wdRef, {
        status: "paid",
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        processedByAdminUid: adminUid,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      tx.update(staffRef, {
        "wallet.pendingWithdrawals": admin.firestore.FieldValue.increment(-amount),
        "wallet.totalWithdrawn": admin.firestore.FieldValue.increment(amount),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      // Action === 'reject': Credit back requested amount to availableBalance
      tx.update(wdRef, {
        status: "rejected",
        rejectionReason: (rejectionReason as string).trim(),
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        processedByAdminUid: adminUid,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      tx.update(staffRef, {
        "wallet.pendingWithdrawals": admin.firestore.FieldValue.increment(-amount),
        "wallet.availableBalance": admin.firestore.FieldValue.increment(amount),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });

  return { success: true, message: `Withdrawal request successfully ${action === "paid" ? "marked as paid" : "rejected"}.` };
});

/**
 * Callable function for Admin to permanently delete a Staff account.
 * Deletes Firebase Auth user and Firestore staff document + referrals subcollection.
 */
export const deleteStaffAccount = onCall({ region: REGION_PRIMARY, maxInstances: 5, cors: true }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in as Admin.");
  }

  const { staffUid } = (request.data ?? {}) as { staffUid?: string };

  if (!staffUid || typeof staffUid !== "string") {
    throw new HttpsError("invalid-argument", "Missing staffUid parameter.");
  }

  const staffRef = admin.firestore().collection("staff").doc(staffUid);
  const staffSnap = await staffRef.get();

  if (!staffSnap.exists) {
    throw new HttpsError("not-found", "Staff profile not found.");
  }

  // 1. Delete referrals subcollection docs
  try {
    const referralsSnap = await staffRef.collection("referrals").get();
    const batch = admin.firestore().batch();
    referralsSnap.docs.forEach((d) => batch.delete(d.ref));
    await batch.commit();
  } catch (err: any) {
    logger.warn("Failed to delete referrals subcollection docs:", { staffUid, error: err.message });
  }

  // 2. Delete Firestore staff document
  await staffRef.delete();

  // 3. Delete Firebase Auth user
  try {
    await admin.auth().deleteUser(staffUid);
  } catch (err: any) {
    if (err?.code !== "auth/user-not-found") {
      logger.error("Failed to delete staff auth user:", { staffUid, error: err.message });
    }
  }

  logger.info("Staff account permanently deleted", { staffUid });
  return { success: true, message: "Staff account deleted successfully." };
});

// ─────────────────────────── Tier Settings Seed ──────────────

/**
 * Admin callable to seed default tier settings. Safe to call multiple times —
 * only creates docs that do not already exist.
 */
export const initializeTierSettings = onCall({ region: "us-east1" }, async (request) => {
  const results: string[] = [];
  for (const [key, setting] of Object.entries(DEFAULT_TIER_SETTINGS)) {
    const ref = tierSettingsCollection.doc(key);
    const snap = await ref.get();
    if (!snap.exists) {
      await ref.set(setting);
      results.push(`Created ${key}`);
    } else {
      results.push(`Skipped ${key} (exists)`);
    }
  }
  logger.info("Tier settings initialized", { results });
  return { success: true, results };
});

// ─────────────────────────── Flutterwave Functions ──────────────

export const initializeFlutterwaveTransaction = onCall({ region: REGION_PRIMARY, maxInstances: 5 }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const payload = request.data as InitFlutterwavePayload;
  const email = request.auth.token.email || "customer@caride.ng";
  const amountNaira = payload.amountNaira;

  if (amountNaira == null || amountNaira <= 0) {
    throw new HttpsError("invalid-argument", "Valid amount in Naira is required.");
  }

  const uid = request.auth.uid;
  const reference = `caride_flw_${Date.now()}_${uid.substring(0, 5)}`;

  // Map requested channels to Flutterwave options.
  let paymentOptions = "card, account, ussd, banktransfer";
  if (payload.channels && payload.channels.length > 0) {
    const mapped: string[] = [];
    for (const ch of payload.channels) {
      if (ch === "card") mapped.push("card");
      else if (ch === "bank_transfer") mapped.push("banktransfer");
      else if (ch === "bank") { mapped.push("account"); mapped.push("ussd"); }
    }
    if (mapped.length > 0) paymentOptions = mapped.join(", ");
  }

  type FlutterwaveInitResponse = {
    status: string;
    message: string;
    data?: { link: string };
  };

  const response = await flutterwaveRequest<FlutterwaveInitResponse>("POST", "/payments", {
    tx_ref: reference,
    amount: amountNaira.toString(),
    currency: "NGN",
    redirect_url: "https://caride.com/payment-callback",
    customer: {
      email: email,
      name: request.auth.token.name || "CaRide Customer",
    },
    customizations: {
      title: "CaRide Wallet Top Up",
      description: "Top up CaRide Wallet",
    },
    payment_options: paymentOptions,
  });

  if (response.status !== "success" || !response.data?.link) {
    logger.error("Flutterwave initialization failed", { response });
    throw new HttpsError("internal", response.message ?? "Flutterwave initialization failed.");
  }

  logger.info("Flutterwave transaction initialized", { uid, amountNaira, reference });

  return {
    authorizationUrl: response.data.link,
    reference,
  };
});



export const chargeFlutterwaveCard = onCall({ region: REGION_PRIMARY, maxInstances: 5 }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const payload = request.data as ChargeFlutterwavePayload;
  const { authorizationCode, amountNaira } = payload;
  const email = payload.email || request.auth.token.email;

  if (!authorizationCode || amountNaira == null || amountNaira <= 0 || !email) {
    throw new HttpsError("invalid-argument", "authorizationCode, email, and amountNaira are required.");
  }

  const uid = request.auth.uid;
  const reference = `caride_flw_charge_${Date.now()}_${uid.substring(0, 5)}`;

  type FlutterwaveChargeResponse = {
    status: string;
    message: string;
    data?: { status: string; amount: number; payment_type?: string };
  };

  const response = await flutterwaveRequest<FlutterwaveChargeResponse>("POST", "/tokenized-charges", {
    token: authorizationCode,
    email: email,
    currency: "NGN",
    country: "NG",
    amount: amountNaira,
    tx_ref: reference,
    redirect_url: "https://caride.com/payment-callback",
  });

  if (response.status !== "success" || response.data?.status !== "successful") {
    logger.error("Flutterwave charge failed", { response });
    throw new HttpsError("internal", response.message ?? "Flutterwave card charge failed.");
  }

  const amountCredited = response.data.amount;
  const paymentType = response.data.payment_type ?? "card";
  const txRef = admin.firestore().collection("walletTransactions").doc(reference);
  const userRef = admin.firestore().collection("customers").doc(uid);

  await admin.firestore().runTransaction(async (tx) => {
    const txSnap = await tx.get(txRef);
    if (txSnap.exists) {
      logger.warn("Idempotency: Flutterwave charge already processed", { reference });
      return;
    }

    const userSnap = await tx.get(userRef);
    const currentBalance = (userSnap.data()?.walletBalance as number | undefined) ?? 0;

    tx.set(txRef, {
      uid,
      type: "credit",
      amountNaira: amountCredited,
      method: paymentType.toLowerCase() === "card" ? "Card" : paymentType,
      description: "Wallet Top Up via Saved Card",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    tx.set(userRef, {
      walletBalance: currentBalance + amountCredited,
    }, { merge: true });
  });

  logger.info("Flutterwave card charge successful", { uid, amountCredited, reference });
  return { amountNaira: amountCredited, reference };
});

export const verifyFlutterwaveTransaction = onCall({ region: REGION_PRIMARY, maxInstances: 5 }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const payload = request.data as VerifyFlutterwavePayload;
  const reference = payload.reference;

  if (!reference) {
    throw new HttpsError("invalid-argument", "Reference is required.");
  }

  const uid = request.auth.uid;

  type FlutterwaveVerifyResponse = {
    status: string;
    message: string;
    data?: {
      status: string;
      amount: number;
      payment_type?: string;
      customer?: { email?: string };
      card?: { token?: string; last_4digits?: string; type?: string };
    };
  };

  const response = await flutterwaveRequest<FlutterwaveVerifyResponse>("GET", `/transactions/verify_by_reference?tx_ref=${reference}`);

  if (response.status !== "success" || !response.data) {
    logger.error("Flutterwave verification API error", { response });
    throw new HttpsError("internal", response.message ?? "Flutterwave verification failed.");
  }

  if (response.data.status !== "successful") {
    throw new HttpsError("failed-precondition", "Transaction was not successful.");
  }

  const amount = response.data.amount;
  const paymentType = response.data.payment_type ?? "Flutterwave";
  
  const txRef = admin.firestore().collection("walletTransactions").doc(reference);
  const userRef = admin.firestore().collection("customers").doc(uid);

  let wasProcessed = false;

  await admin.firestore().runTransaction(async (tx) => {
    const txSnap = await tx.get(txRef);
    if (txSnap.exists) {
      logger.warn("Idempotency: Flutterwave verification already processed", { reference });
      wasProcessed = true;
      return;
    }

    const userSnap = await tx.get(userRef);
    const currentBalance = (userSnap.data()?.walletBalance as number | undefined) ?? 0;

    const methodDisplay = paymentType.toLowerCase() === "card" ? "Card" : "Bank Transfer";

    tx.set(txRef, {
      uid,
      type: "credit",
      amountNaira: amount,
      method: methodDisplay,
      description: "Wallet Top Up",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    tx.set(userRef, {
      walletBalance: currentBalance + amount,
    }, { merge: true });
  });

  if (!wasProcessed) {
    // Optionally email receipt
    try {
      const email = response.data.customer?.email || request.auth.token.email;
      if (email) {
        await sendWalletTopUpReceiptEmail(email, reference, amount, paymentType);
      }
    } catch (e) {
      logger.warn("Failed to send Flutterwave top-up receipt", { reference, e });
    }

    // Save card securely if it's a card transaction
    const cardData = response.data.card;
    if (cardData && cardData.token) {
      const token = cardData.token;
      const last4 = cardData.last_4digits ?? "****";
      const brand = cardData.type ?? "Card";
      const customerEmail = response.data.customer?.email || request.auth.token.email || "";

      const cardId = `card_${token.substring(0, 8)}_${last4}`;
      const savedCardRef = userRef.collection("savedCards").doc(cardId);
      
      // Save it outside the main transaction to prevent failures if it already exists
      await savedCardRef.set({
        authorizationCode: token,
        last4,
        brand,
        email: customerEmail,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    }
    
    logger.info("Flutterwave transaction verified & wallet credited", { uid, amount, reference });
  }

  return { amountNaira: amount, reference };
});

// ─────────────────────────── Paystack Functions ──────────────

/**
 * Initializes a Paystack "Pay with Transfer" (PwT) charge.
 * Calls POST /charge with bank_transfer to generate a temporary virtual account
 * number unique to this transaction. Returns the account details for display.
 *
 * NOTE: "Pay with Transfer" must be enabled on the Paystack integration.
 * The /charge endpoint with bank_transfer returns status:"pay_offline" and
 * data contains the temporary account number, bank name, and account name.
 */
export const initializeBankTransfer = onCall({ region: REGION_PRIMARY, maxInstances: 5 }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }

  const payload = request.data as { email?: string; amountKobo?: number; preferred_bank?: string };
  const rawEmail = payload.email || request.auth.token.email;
  const email = sanitizeEmail(rawEmail);
  const amountKobo = payload.amountKobo;

  if (!isValidEmail(email)) {
    throw new HttpsError("invalid-argument", "A valid email address is required.");
  }
  if (!amountKobo || amountKobo < 10000) {
    throw new HttpsError("invalid-argument", "Minimum top-up is ₦100.");
  }

  // Paystack /charge response for bank_transfer channel
  type PaystackChargeResponse = {
    status: boolean;
    message: string;
    data?: {
      reference: string;
      status: string;           // "pay_offline" or "pending"
      display_text?: string;
      account_number?: string;
      bank_name?: string;
      account_name?: string;
      // Some integrations nest inside bank_transfer or payment_method
      bank_transfer?: {
        account_number?: string;
        bank_name?: string;
        account_name?: string;
        account_expires_at?: string;
      };
      // Alternative nesting
      ussd?: { reference?: string };
    };
  };

  logger.info("initializeBankTransfer: calling Paystack /charge for PwT", {
    uid: request.auth.uid,
    amountKobo,
    email,
  });

  const response = await paystackRequest<PaystackChargeResponse>(
    "POST",
    "/charge",
    {
      email,
      amount: amountKobo,
      metadata: {
        uid: request.auth.uid,
        cancel_action: "https://caride.ng",
      },
      bank_transfer: {
        // Expire in 30 minutes by default
        account_expires_at: new Date(Date.now() + 30 * 60 * 1000).toISOString(),
      },
    }
  );

  logger.info("initializeBankTransfer: Paystack /charge raw response", {
    uid: request.auth.uid,
    status: response.status,
    message: response.message,
    dataStatus: response.data?.status,
    accountNumber: response.data?.account_number ?? response.data?.bank_transfer?.account_number,
  });

  if (!response.status || !response.data) {
    throw new HttpsError("internal", response.message ?? "Paystack bank transfer initialization failed.");
  }

  const data = response.data;

  // Extract account details — Paystack may nest under data directly or data.bank_transfer
  const accountNumber =
    data.account_number ||
    data.bank_transfer?.account_number ||
    null;

  const bankName =
    data.bank_name ||
    data.bank_transfer?.bank_name ||
    "Paystack-Titan";

  const accountName =
    data.account_name ||
    data.bank_transfer?.account_name ||
    "Paystack Checkout";

  const expiresAt = data.bank_transfer?.account_expires_at ?? null;
  const reference = data.reference;

  if (!accountNumber) {
    logger.error("initializeBankTransfer: Paystack returned no account number", {
      uid: request.auth.uid,
      data,
    });
    throw new HttpsError(
      "internal",
      `Paystack did not return a virtual account. Status: ${data.status}. ` +
      "Ensure 'Pay with Transfer' is enabled on your Paystack integration."
    );
  }

  logger.info("initializeBankTransfer: SUCCESS", {
    uid: request.auth.uid,
    reference,
    accountNumber,
    bankName,
  });

  return {
    reference,
    accountNumber,
    bankName,
    accountName,
    expiresAt,
    status: data.status,
  };
});

export const initializePaystackTransaction = onCall({ region: REGION_PRIMARY, maxInstances: 5 }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const payload = request.data as InitPaystackPayload;
  // Prefer the client-supplied email, but fall back to the Firebase Auth token email
  // (handles OTP-based accounts where user.email may be null on the client).
  const rawEmail = payload.email || request.auth.token.email;
  const email = sanitizeEmail(rawEmail);
  const amountKobo = payload.amountKobo;

  if (!isValidEmail(email)) {
    throw new HttpsError("invalid-argument", "A valid email address is required to process payment.");
  }

  if (!amountKobo || amountKobo < 10000) {
    throw new HttpsError("invalid-argument", "Minimum top-up is ₦100.");
  }

  type PaystackInitResponse = {
    status: boolean;
    message: string;
    data?: { authorization_url: string; access_code: string; reference: string };
  };

  const channels = payload.channels || ["card", "bank_transfer", "ussd"];

  const response = await paystackRequest<PaystackInitResponse>(
    "POST",
    "/transaction/initialize",
    {
      email,
      amount: amountKobo,
      metadata: { uid: request.auth.uid },
      channels,
    }
  );

  if (!response.status || !response.data) {
    throw new HttpsError("internal", response.message ?? "Paystack initialization failed.");
  }

  logger.info("Paystack transaction initialized", {
    uid: request.auth.uid,
    reference: response.data.reference,
  });

  return {
    authorizationUrl: response.data.authorization_url,
    reference: response.data.reference,
  };
});

// ─────── Charge a saved card directly (no webview needed) ────────
export const chargePaystackCard = onCall({ region: REGION_PRIMARY, maxInstances: 5 }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const payload = request.data as ChargePaystackPayload;
  const authorizationCode = payload.authorizationCode?.trim();
  const email = sanitizeEmail(payload.email);
  const amountKobo = payload.amountKobo;

  if (!authorizationCode) {
    throw new HttpsError("invalid-argument", "authorizationCode is required.");
  }
  if (!amountKobo || amountKobo < 10000) {
    throw new HttpsError("invalid-argument", "Minimum amount is ₦100.");
  }

  type ChargeResponse = {
    status: boolean;
    message: string;
    data?: { status: string; reference: string; amount: number; gateway_response: string };
  };

  const response = await paystackRequest<ChargeResponse>(
    "POST",
    "/transaction/charge_authorization",
    {
      email,
      amount: amountKobo,
      authorization_code: authorizationCode,
      metadata: { uid: request.auth.uid },
    }
  );

  if (!response.status || !response.data) {
    throw new HttpsError("internal", response.message ?? "Charge failed.");
  }

  const chargeStatus = response.data.status;
  if (chargeStatus !== "success") {
    throw new HttpsError("failed-precondition", `Charge not successful: ${chargeStatus}.`);
  }

  // Credit wallet
  const amountNaira = amountKobo / 100;
  const uid = request.auth.uid;
  const userRef = customersCollection.doc(uid);
  const reference = response.data.reference;

  await admin.firestore().runTransaction(async (tx) => {
    const snap = await tx.get(userRef);
    const current = (snap.data()?.walletBalance as number) ?? 0;
    tx.update(userRef, { walletBalance: current + amountNaira });

    const txRef = admin.firestore().collection("walletTransactions").doc();
    tx.set(txRef, {
      uid,
      type: "credit",
      amountNaira,
      method: "card",
      reference,
      description: "Wallet Top Up",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  // Send email receipt
  try {
    const userDoc = await userRef.get();
    const customerEmail = userDoc.data()?.email || request.auth.token.email || email;
    if (customerEmail) {
      await sendWalletTopUpReceiptEmail(customerEmail, reference, amountNaira, "Saved Card");
    }
  } catch (err) {
    logger.error("Failed to send top-up email receipt", { uid, reference, error: String(err) });
  }

  logger.info("Paystack card charge successful", { uid, amountNaira, reference });
  return { success: true, credited: amountNaira, reference };
});

export const verifyPaystackTransaction = onCall({ region: REGION_PRIMARY, maxInstances: 5 }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const payload = request.data as VerifyPaystackPayload;
  const reference = payload.reference?.trim();

  if (!reference) {
    throw new HttpsError("invalid-argument", "Transaction reference is required.");
  }

  type PaystackVerifyResponse = {
    status: boolean;
    message: string;
    data?: {
      status: string;
      amount: number;
      reference: string;
      channel?: string;
      metadata?: { uid?: string };
      authorization?: {
        authorization_code: string;
        last4: string;
        brand: string;
        reusable: boolean;
      };
      customer?: {
        email: string;
      };
    };
  };

  const response = await paystackRequest<PaystackVerifyResponse>(
    "GET",
    `/transaction/verify/${reference}`
  );

  if (!response.status || !response.data) {
    throw new HttpsError("internal", response.message ?? "Paystack verification failed.");
  }

  if (response.data.status !== "success") {
    throw new HttpsError("failed-precondition", "Payment was not successful.");
  }

  const txUid = response.data.metadata?.uid;
  if (txUid && txUid !== request.auth.uid) {
    throw new HttpsError("permission-denied", "Transaction does not belong to this user.");
  }

  const amountNaira = response.data.amount / 100;
  const userRef = customersCollection.doc(request.auth.uid);

  const receiptRef = admin.firestore().collection("paystackReceipts").doc(reference);
  const receipt = await receiptRef.get();
  if (receipt.exists) {
    logger.warn("Duplicate Paystack verification attempt", { reference });
    throw new HttpsError("already-exists", "This transaction has already been processed.");
  }

  await admin.firestore().runTransaction(async (tx) => {
    tx.set(receiptRef, {
      reference,
      uid: request.auth!.uid,
      amountNaira,
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.update(userRef, {
      walletBalance: admin.firestore.FieldValue.increment(amountNaira),
    });
    const txRef = admin.firestore().collection("walletTransactions").doc();
    tx.set(txRef, {
      uid: request.auth!.uid,
      type: "credit",
      amountNaira,
      method: "card",
      reference,
      description: "Wallet Top Up",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Auto-save card details if payment was made using a reusable card
    if (response.data?.channel === "card" && response.data?.authorization?.reusable) {
      const authData = response.data.authorization;
      const cardEmail = response.data.customer?.email || "";
      const cardRef = userRef.collection("savedCards").doc();
      tx.set(cardRef, {
        authorizationCode: authData.authorization_code,
        last4: authData.last4,
        brand: authData.brand || "Card",
        email: cardEmail,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });

  // Send email receipt
  try {
    const userDoc = await userRef.get();
    const customerEmail = userDoc.data()?.email || request.auth.token.email || response.data.customer?.email;
    if (customerEmail) {
      const channel = response.data.channel || "payment";
      let paymentMethod = "Paystack";
      if (channel === "card") paymentMethod = "Card";
      else if (channel === "bank_transfer") paymentMethod = "Bank Transfer";
      else if (channel === "mobile_money") paymentMethod = "Mobile Money";
      else if (channel === "ussd") paymentMethod = "USSD";
      else if (channel === "opay" || channel === "bank") paymentMethod = "Bank Transfer";

      await sendWalletTopUpReceiptEmail(customerEmail, reference, amountNaira, paymentMethod);
    }
  } catch (err) {
    logger.error("Failed to send top-up email receipt", { uid: request.auth.uid, reference, error: String(err) });
  }

  logger.info("Wallet topped up", { uid: request.auth.uid, amountNaira, reference });
  return { amountNaira };
});

export const savePaystackCard = onCall({ region: REGION_PRIMARY, maxInstances: 5 }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const payload = request.data as { authorizationCode: string; last4: string; brand: string; email: string };
  const authCode = payload.authorizationCode?.trim();
  if (!authCode) throw new HttpsError("invalid-argument", "Missing authorization code.");

  await customersCollection
    .doc(request.auth.uid)
    .collection("savedCards")
    .add({
      authorizationCode: authCode,
      last4: payload.last4 || "****",
      brand: payload.brand || "Card",
      email: payload.email || request.auth.token.email || "",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

  return { success: true };
});

export const listPaystackBanks = onCall({ region: "us-east1" }, async () => {
  type PaystackBanksResponse = {
    status: boolean;
    message: string;
    data?: Array<{ name: string; code: string }>;
  };

  const response = await paystackRequest<PaystackBanksResponse>(
    "GET",
    "/bank?country=nigeria&currency=NGN&perPage=100"
  );

  if (!response.status || !response.data) {
    throw new HttpsError("internal", response.message ?? "Unable to load banks.");
  }

  return {
    banks: response.data
      .map((bank) => ({name: bank.name, code: bank.code}))
      .sort((a, b) => a.name.localeCompare(b.name)),
  };
});

export const resolvePaystackBankAccount = onCall({ region: REGION_PRIMARY, maxInstances: 5 }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }

  const payload = request.data as ResolveBankAccountPayload;
  const bankCode = payload.bankCode?.trim();
  const accountNumber = payload.accountNumber?.trim();

  if (!bankCode || !accountNumber || !/^\d{10}$/.test(accountNumber)) {
    throw new HttpsError(
      "invalid-argument",
      "Bank code and a valid 10-digit account number are required."
    );
  }

  type PaystackResolveResponse = {
    status: boolean;
    message: string;
    data?: { account_name: string; account_number: string; bank_id: number };
  };

  const response = await paystackRequest<PaystackResolveResponse>(
    "GET",
    `/bank/resolve?account_number=${accountNumber}&bank_code=${bankCode}`
  );

  if (!response.status || !response.data) {
    throw new HttpsError("failed-precondition", response.message ?? "Unable to verify account.");
  }

  return {
    accountName: response.data.account_name,
    accountNumber: response.data.account_number,
  };
});

export const saveDriverBankAccount = onCall({ region: REGION_PRIMARY, maxInstances: 5 }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }

  const payload = request.data as SaveDriverBankAccountPayload;
  const bankCode = payload.bankCode?.trim();
  const bankName = payload.bankName?.trim();
  const accountNumber = payload.accountNumber?.trim();

  if (!bankCode || !bankName || !accountNumber || !/^\d{10}$/.test(accountNumber)) {
    throw new HttpsError(
      "invalid-argument",
      "Bank code, bank name, and a valid 10-digit account number are required."
    );
  }

  type PaystackResolveResponse = {
    status: boolean;
    message: string;
    data?: { account_name: string; account_number: string };
  };
  type PaystackRecipientResponse = {
    status: boolean;
    message: string;
    data?: { recipient_code: string };
  };

  const resolveResponse = await paystackRequest<PaystackResolveResponse>(
    "GET",
    `/bank/resolve?account_number=${accountNumber}&bank_code=${bankCode}`
  );

  if (!resolveResponse.status || !resolveResponse.data) {
    throw new HttpsError("failed-precondition", resolveResponse.message ?? "Unable to verify account.");
  }

  const email = request.auth.token.email;
  const recipientResponse = await paystackRequest<PaystackRecipientResponse>(
    "POST",
    "/transferrecipient",
    {
      type: "nuban",
      name: resolveResponse.data.account_name,
      account_number: resolveResponse.data.account_number,
      bank_code: bankCode,
      currency: "NGN",
      email,
    }
  );

  if (!recipientResponse.status || !recipientResponse.data?.recipient_code) {
    throw new HttpsError(
      "internal",
      recipientResponse.message ?? "Unable to create transfer recipient."
    );
  }

  const accountsCol = driversCollection.doc(request.auth.uid).collection("bankAccounts");
  const existingAccounts = await accountsCol.get();
  const existingMatch = existingAccounts.docs.find((doc) => {
    const data = doc.data();
    return data.bankCode === bankCode && data.accountNumber === accountNumber;
  });

  if (existingMatch) {
    await existingMatch.ref.set({
      bankName,
      accountName: resolveResponse.data.account_name,
      maskedAccountNumber: maskAccountNumber(resolveResponse.data.account_number),
      verificationStatus: "verified",
      recipientCode: recipientResponse.data.recipient_code,
      isDefault: true,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});

    await writeVerificationHistory(request.auth.uid, "bank_account_saved", {
      bankName,
      maskedAccountNumber: maskAccountNumber(resolveResponse.data.account_number),
    });

    return {
      accountId: existingMatch.id,
      accountName: resolveResponse.data.account_name,
      maskedAccountNumber: maskAccountNumber(resolveResponse.data.account_number),
    };
  }

  const batch = admin.firestore().batch();
  existingAccounts.docs.forEach((doc) => {
    batch.set(doc.ref, {isDefault: false}, {merge: true});
  });

  const newAccountRef = accountsCol.doc();
  batch.set(newAccountRef, {
    bankCode,
    bankName,
    accountNumber: resolveResponse.data.account_number,
    maskedAccountNumber: maskAccountNumber(resolveResponse.data.account_number),
    accountName: resolveResponse.data.account_name,
    verificationStatus: "verified",
    recipientCode: recipientResponse.data.recipient_code,
    isDefault: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  await batch.commit();

  await writeVerificationHistory(request.auth.uid, "bank_account_saved", {
    bankName,
    maskedAccountNumber: maskAccountNumber(resolveResponse.data.account_number),
  });

  return {
    accountId: newAccountRef.id,
    accountName: resolveResponse.data.account_name,
    maskedAccountNumber: maskAccountNumber(resolveResponse.data.account_number),
  };
});

// ─────────────────────────── Firestore Triggers ──────────────

export const onDriverDocumentCreated = onDocumentCreated(
  { document: "drivers/{uid}/documents/{documentType}", region: REGION_PRIMARY, maxInstances: 2 },
  async (event) => {
    const uid = event.params.uid;
    const documentType = event.params.documentType;
    const after = event.data?.data() as {
      status?: string;
      rejectionReason?: string | null;
    } | undefined;
    if (!after) return;

    await writeVerificationHistory(uid, "document_uploaded", {
      documentType,
      status: after.status ?? "pending",
    });
    await syncDriverApprovalStatus(uid);
  }
);

export const onDriverDocumentUpdated = onDocumentUpdated(
  { document: "drivers/{uid}/documents/{documentType}", region: REGION_PRIMARY, maxInstances: 2 },
  async (event) => {
    const uid = event.params.uid;
    const documentType = event.params.documentType;
    const before = event.data?.before.data() as { status?: string; fileUrl?: string; rejectionReason?: string | null } | undefined;
    const after = event.data?.after.data() as { status?: string; fileUrl?: string; rejectionReason?: string | null } | undefined;
    if (!before || !after) return;

    const fileChanged = before.fileUrl !== after.fileUrl;
    const statusChanged = before.status !== after.status;

    if (fileChanged && after.status === "pending") {
      await writeVerificationHistory(uid, "document_resubmitted", { documentType, status: after.status ?? "pending" });
    } else if (statusChanged) {
      await writeVerificationHistory(uid, `document_${after.status ?? "updated"}`, {
        documentType, status: after.status ?? "pending", rejectionReason: after.rejectionReason ?? null,
      });
      // Send per-document email + push when admin approves or rejects a document
      if (after.status === "approved" || after.status === "rejected") {
        try {
          const driverDoc = await driversCollection.doc(uid).get();
          const driverData = driverDoc.data();
          const email = driverData?.email as string | undefined;
          const fullName = driverData?.fullName as string | undefined;
          const docLabel = DOCUMENT_LABELS[documentType] ?? documentType;
          if (email) {
            await sendDocumentStatusEmail(email, fullName ?? "", docLabel, after.status as "approved" | "rejected", after.rejectionReason);
          }
          const pushTitle = after.status === "approved" ? `\u2705 ${docLabel} Approved` : `\u26A0\uFE0F ${docLabel} Rejected`;
          const pushBody = after.status === "approved"
            ? `Your ${docLabel} has been approved. Keep uploading remaining documents.`
            : `Your ${docLabel} was rejected. ${after.rejectionReason ? after.rejectionReason : "Please resubmit."}` ;
          await sendPushToDriver(uid, pushTitle, pushBody, { type: "document_status", documentType, status: after.status });
        } catch (e) {
          logger.error("Failed to send document status notification", { uid, documentType, e });
        }
      }
    }

    await syncDriverApprovalStatus(uid);
  }
);
export const onVehicleReviewCreated = onDocumentCreated(
  { document: "drivers/{uid}/vehicle/review", region: REGION_PRIMARY, maxInstances: 2 },
  async (event) => {
    const uid = event.params.uid;
    const review = event.data?.data() as VehicleReviewRecord | undefined;
    if (!review) return;

    await writeVerificationHistory(uid, "vehicle_submitted", {
      status: review.status ?? "pending",
      plateNumber: review.newValues?.plateNumber ?? null,
      vehicleType: normalizeVehicleType(review.newValues?.vehicleType),
    });
    await syncDriverApprovalStatus(uid);
  }
);

export const onVehicleReviewUpdated = onDocumentUpdated(
  { document: "drivers/{uid}/vehicle/review", region: REGION_PRIMARY, maxInstances: 2 },
  async (event) => {
    const uid = event.params.uid;
    const before = event.data?.before.data() as VehicleReviewRecord | undefined;
    const after = event.data?.after.data() as VehicleReviewRecord | undefined;
    if (!before || !after) return;

    const statusChanged = before.status !== after.status;
    const vehicleChanged = JSON.stringify(before.newValues ?? {}) !== JSON.stringify(after.newValues ?? {});

    if ((vehicleChanged || statusChanged) && after.status === "pending") {
      await writeVerificationHistory(uid, "vehicle_resubmitted", {
        status: after.status,
        plateNumber: after.newValues?.plateNumber ?? null,
        vehicleType: normalizeVehicleType(after.newValues?.vehicleType),
      });
    }

    if (statusChanged && after.status === "approved" && after.newValues) {
      await driversCollection.doc(uid).collection("vehicle").doc("info").set({
        ...after.newValues,
        approvedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
      await writeVerificationHistory(uid, "vehicle_approved", {
        plateNumber: after.newValues.plateNumber ?? null,
        vehicleType: normalizeVehicleType(after.newValues.vehicleType),
      });
      await sendPushToDriver(uid, "\u2705 Vehicle Info Approved", "Your vehicle information has been verified. Keep uploading your remaining documents.", { type: "vehicle_approved" });
    }

    if (statusChanged && after.status === "rejected") {
      await writeVerificationHistory(uid, "vehicle_rejected", {
        plateNumber: after.newValues?.plateNumber ?? null,
        vehicleType: normalizeVehicleType(after.newValues?.vehicleType),
        rejectionReason: after.rejectionReason ?? null,
      });
      try {
        const driverDoc = await driversCollection.doc(uid).get();
        const driverData = driverDoc.data();
        const email = driverData?.email as string | undefined;
        const fullName = driverData?.fullName as string | undefined;
        if (email) {
          const reason = after.rejectionReason ?? "Please resubmit your vehicle information.";
          await sendDocumentStatusEmail(email, fullName ?? "", "Vehicle Information", "rejected", reason);
        }
      } catch (e) { logger.error("Failed to send vehicle rejection email", { uid, e }); }
      await sendPushToDriver(uid, "\u26A0\uFE0F Vehicle Info Rejected", after.rejectionReason ?? "Your vehicle information was rejected. Please update and resubmit.", { type: "vehicle_rejected" });
    }

    await syncDriverApprovalStatus(uid);
  }
);


export const sendWelcomeEmailOnProfileCreate = onDocumentCreated(
  { document: "customers/{uid}", region: REGION_PRIMARY, maxInstances: 2 },
  async (event) => {
    const user = event.data?.data() as { email?: string } | undefined;
    if (!user?.email) return;
    await sendWelcomeEmail(user.email);
  }
);

export const sendDriverWelcomeOnProfileCreate = onDocumentCreated(
  { document: "drivers/{uid}", region: "us-east1" },
  async (event) => {
    const driver = event.data?.data() as { email?: string; fullName?: string } | undefined;
    if (!driver?.email) return;
    try {
      await sendDriverWelcomeEmail(driver.email, driver.fullName ?? "");
      await sendPushToDriver(event.params.uid, "Welcome to CaRide! \uD83D\uDE97", "Your account is ready. Complete your profile and documents to start earning.", { type: "welcome" });
    } catch (e) { logger.error("Failed to send driver welcome", { uid: event.params.uid, e }); }
  }
);

export const notifyDriverApprovalStatus = onDocumentUpdated(
  { document: "drivers/{uid}", region: REGION_PRIMARY, maxInstances: 2 },
  async (event) => {
    const before = event.data?.before.data() as { approvalStatus?: string; email?: string; fullName?: string; rejectionReason?: string } | undefined;
    const after = event.data?.after.data() as { approvalStatus?: string; email?: string; fullName?: string; rejectionReason?: string } | undefined;

    if (!before || !after) return;
    if (before.approvalStatus === after.approvalStatus) return;

    const uid = event.params.uid;
    await writeVerificationHistory(uid, "driver_status_changed", {
      previousStatus: before.approvalStatus ?? null,
      nextStatus: after.approvalStatus ?? null,
      rejectionReason: after.rejectionReason ?? null,
    });
    if (!after.email) return;

    const fullName = after.fullName ?? "";
    try {
      if (after.approvalStatus === "approved") {
        await sendAllDocumentsApprovedEmail(after.email, fullName);
        await sendPushToDriver(uid, "\uD83C\uDF89 You're Fully Verified!", "Congratulations! All documents approved. You can now go online and accept rides.", { type: "fully_verified" });
        logger.info("Driver approval email+push sent", { uid });
      } else if (after.approvalStatus === "rejected") {
        const reason = after.rejectionReason ?? "Please re-submit your documents and try again.";
        await sendDriverRejectedEmail(after.email, fullName, reason);
        await sendPushToDriver(uid, "\u26A0\uFE0F Application Update", `Your application was not approved. Reason: ${reason}`, { type: "application_rejected" });
        logger.info("Driver rejection email+push sent", { uid });
      } else if (after.approvalStatus === "pending") {
        await sendPushToDriver(uid, "\uD83D\uDCCB Application Under Review", "Your application has been submitted and is under review. We'll notify you once it's processed.", { type: "application_pending" });
      }
    } catch (e) {
      logger.error("Failed to send driver status notification", { uid, error: e });
    }
  }
);


/**
 * Fires when a ride document is updated. When `driverRating` is freshly set by
 * a customer, this trigger:
 *   1. Fetches the customer's name and denormalizes it onto the ride doc.
 *   2. Recalculates the driver's averageRating across all rated rides.
 *   3. Re-evaluates and updates the driver's tier based on new rating + trips.
 */
export const onDriverRatingChanged = onDocumentUpdated({ document: "rides/{rideId}", region: "us-east1" }, async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;

  // Only act when driverRating is newly set
  if (before.driverRating != null || after.driverRating == null) return;

  const driverUid = after.driverUid as string | undefined;
  const customerUid = after.customerUid as string | undefined;
  const rideId = event.params.rideId;

  if (!driverUid) return;

  // Denormalize customer name onto the ride for easy display
  if (customerUid) {
    try {
      const customerDoc = await customersCollection.doc(customerUid).get();
      const customerName = (customerDoc.data()?.fullName as string) || "Customer";
      await admin.firestore().collection("rides").doc(rideId).update({ customerName });
    } catch (e) {
      logger.warn("Failed to denormalize customer name on ride", { rideId, e });
    }
  }

  // Recalculate average rating for the driver
  try {
    const ratedRidesSnap = await admin.firestore()
      .collection("rides")
      .where("driverUid", "==", driverUid)
      .where("driverRating", ">", 0)
      .get();

    const ratings = ratedRidesSnap.docs.map((d) => (d.data().driverRating as number) || 0);
    const total = ratings.length;
    const average = total > 0 ? ratings.reduce((a, b) => a + b, 0) / total : 0;
    const roundedAverage = Math.round(average * 10) / 10;

    const driverRef = driversCollection.doc(driverUid);
    const driverDoc = await driverRef.get();
    if (!driverDoc.exists) return;

    const driverData = driverDoc.data()!;
    const completedRides = (driverData.completedRides as number) ?? 0;
    const allTierSettings = await fetchAllTierSettings();
    const newTier = calculateTier(completedRides, roundedAverage, allTierSettings);

    await driverRef.update({
      averageRating: roundedAverage,
      totalRatings: total,
      tier: newTier,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    logger.info("Driver rating updated", { driverUid, average: roundedAverage, total, newTier });
  } catch (e) {
    logger.error("Failed to update driver average rating", { driverUid, e });
  }
});


// ─────────────────────────── Driver Functions ────────────────

export const submitDriverApplication = onCall({ region: REGION_PRIMARY, maxInstances: 5 }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const uid = request.auth.uid;

  const driverRef = driversCollection.doc(uid);
  const driverDoc = await driverRef.get();
  if (!driverDoc.exists) {
    throw new HttpsError("not-found", "Driver profile not found.");
  }

  const driver = driverDoc.data() as { email?: string; fullName?: string };
  const docsSnap = await driverRef.collection("documents").get();
  const vehicleReviewSnap = await driverRef.collection("vehicle").doc("review").get();
  const approvedVehicleSnap = await driverRef.collection("vehicle").doc("info").get();
  const vehicleType = normalizeVehicleType(
    (vehicleReviewSnap.data() as VehicleReviewRecord | undefined)?.newValues?.vehicleType ??
    (approvedVehicleSnap.data() as VehicleInfoRecord | undefined)?.vehicleType
  );
  const requiredDocTypes = requiredDriverDocumentsForVehicleType(vehicleType);
  const uploadedDocTypes = new Set(docsSnap.docs.map((doc) => doc.id));
  const missingDocTypes = requiredDocTypes.filter((typeId) => !uploadedDocTypes.has(typeId));

  if (!vehicleReviewSnap.exists && !approvedVehicleSnap.exists) {
    throw new HttpsError(
      "failed-precondition",
      "Please submit your vehicle information before submitting for review."
    );
  }

  if (missingDocTypes.length > 0) {
    throw new HttpsError(
      "failed-precondition",
      `Missing required documents: ${missingDocTypes.join(", ")}.`
    );
  }

  await driverRef.update({
    profileCompleted: true,
    approvalStatus: "pending",
    applicationSubmittedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
  await syncDriverApprovalStatus(uid);

  try {
    await sendAdminNotificationEmail(driver.email ?? "", uid);
  } catch (e) {
    logger.warn("Failed to send admin notification email", { uid });
  }

  logger.info("Driver application submitted", { uid });
  return { success: true };
});

export const createDriverBid = onCall({ region: REGION_PRIMARY, maxInstances: 5 }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const uid = request.auth.uid;
  const payload = request.data as CreateBidPayload;

  const { rideId, offerNaira, etaMinutes } = payload;
  if (!rideId || offerNaira == null || etaMinutes == null) {
    throw new HttpsError("invalid-argument", "Missing required fields.");
  }
  if (offerNaira <= 0) {
    throw new HttpsError("invalid-argument", "Offer amount must be positive.");
  }

  const [rideDoc, driverDoc, presenceDoc] = await Promise.all([
    admin.firestore().collection("rides").doc(rideId).get(),
    driversCollection.doc(uid).get(),
    driverPresenceCollection.doc(uid).get(),
  ]);

  if (!rideDoc.exists) {
    throw new HttpsError("not-found", "Ride not found.");
  }
  if (!driverDoc.exists) {
    throw new HttpsError("not-found", "Driver profile not found.");
  }

  const ride = rideDoc.data()!;
  if (!["requested", "bidding"].includes(ride.status)) {
    throw new HttpsError("failed-precondition", "This ride is no longer accepting bids.");
  }

  const driver = driverDoc.data()!;
  if (driver.approvalStatus !== "approved") {
    throw new HttpsError("permission-denied", "Driver is not approved to place bids.");
  }

  const presence = presenceDoc.data();
  if (!presence || presence.isAvailableForRequests !== true || presence.availabilityState !== "online") {
    throw new HttpsError("failed-precondition", "Driver must be online and available before placing bids.");
  }

  const bidRef = admin.firestore().collection("bids").doc(rideId).collection("offers").doc();
  const expiresAt = new Date(Date.now() + 60_000);

  await admin.firestore().runTransaction(async (tx) => {
    tx.set(bidRef, {
      bidId: bidRef.id,
      rideId,
      driverUid: uid,
      driverName: driver.fullName ?? "Driver",
      driverRating: driver.averageRating ?? driver.rating ?? 5.0,
      driverRides: driver.completedRides ?? driver.totalRides ?? 0,
      driverTier: driver.tier ?? "bronze",
      vehicleName: driver.vehicleName ?? "",
      offerNaira,
      etaMinutes,
      status: "pending",
      expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    tx.update(admin.firestore().collection("rides").doc(rideId), {
      status: "bidding",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  logger.info("Driver bid created", { uid, rideId, bidId: bidRef.id });
  return { bidId: bidRef.id };
});

export const updateRideStatus = onCall({ region: REGION_PRIMARY, maxInstances: 5 }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const uid = request.auth.uid;
  const payload = request.data as UpdateRideStatusPayload;

  const { rideId, newStatus, code } = payload;
  if (!rideId || !newStatus) {
    throw new HttpsError("invalid-argument", "Missing rideId or newStatus.");
  }

  const allowedTransitions: Record<string, string[]> = {
    driverEnRoute: ["driverArrived", "rideStarted"],
    driverArrived: ["rideStarted"],
  };

  const rideRef = admin.firestore().collection("rides").doc(rideId);
  const rideDoc = await rideRef.get();
  if (!rideDoc.exists) {
    throw new HttpsError("not-found", "Ride not found.");
  }

  const ride = rideDoc.data()!;
  if (ride.driverUid !== uid) {
    throw new HttpsError("permission-denied", "You are not the assigned driver for this ride.");
  }

  const allowedNextStatuses = allowedTransitions[ride.status] ?? [];
  if (!allowedNextStatuses.includes(newStatus)) {
    throw new HttpsError(
      "failed-precondition",
      `Invalid status transition from ${ride.status} to ${newStatus}.`
    );
  }

  if (newStatus === "rideStarted") {
    // Check whether the customer has startCode verification enabled.
    // Default is true (enabled) for safety. Only skip code check if explicitly disabled.
    const customerUid = ride.customerUid as string | undefined;
    let startCodeEnabled = true;
    if (customerUid) {
      try {
        const customerDoc = await customersCollection.doc(customerUid).get();
        const rawEnabled = customerDoc.data()?.startCodeEnabled;
        if (rawEnabled === false) startCodeEnabled = false;
      } catch (e) {
        logger.warn("Failed to fetch startCodeEnabled for customer, defaulting to enabled", { customerUid, e: String(e) });
      }
    }

    if (startCodeEnabled) {
      if (!code) {
        throw new HttpsError("invalid-argument", "Missing ride start code.");
      }
      if (String(ride.startCode) !== String(code).trim()) {
        throw new HttpsError("failed-precondition", "Incorrect start code.");
      }
    }
    // If startCodeEnabled === false, no code validation is required — driver proceeds directly.
  }

  const updates: Record<string, unknown> = {
    status: newStatus,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  if (newStatus === "driverArrived") {
    updates.driverArrivedAt = admin.firestore.FieldValue.serverTimestamp();
  } else if (newStatus === "rideStarted") {
    updates.rideStartedAt = admin.firestore.FieldValue.serverTimestamp();
  }

  await rideRef.update(updates);

  if (newStatus === "rideStarted") {
    await driverPresenceCollection.doc(uid).set({
      driverUid: uid,
      availabilityState: "on_trip",
      isAvailableForRequests: false,
      currentRideId: rideId,
      lastHeartbeatAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, {merge: true});
  }

  logger.info("Ride status updated by driver", { uid, rideId, newStatus });
  return { success: true };
});

export const publishDriverLocation = onCall({ region: REGION_PRIMARY, maxInstances: 5 }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const uid = request.auth.uid;
  const payload = request.data as PublishLocationPayload;
  const { rideId, lat, lng, heading, speedMps, accuracyM } = payload;

  if (!rideId || lat == null || lng == null) {
    throw new HttpsError("invalid-argument", "Missing rideId, lat, or lng.");
  }

  const rideDoc = await admin.firestore().collection("rides").doc(rideId).get();
  if (!rideDoc.exists) {
    throw new HttpsError("not-found", "Ride not found.");
  }
  if (rideDoc.data()!.driverUid !== uid) {
    throw new HttpsError("permission-denied", "You are not the assigned driver.");
  }

  await admin.firestore().collection("driverLocations").doc(rideId).set({
    driverUid: uid,
    lat,
    lng,
    heading,
    speedMps,
    accuracyM,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true };
});

export const completeRide = onCall({ region: REGION_PRIMARY, maxInstances: 5 }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const uid = request.auth.uid;
  const payload = request.data as CompleteRidePayload;
  const { rideId } = payload;

  if (!rideId) {
    throw new HttpsError("invalid-argument", "Missing rideId.");
  }

  const rideRef = admin.firestore().collection("rides").doc(rideId);
  const [rideDoc, driverDoc, allTierSettings] = await Promise.all([
    rideRef.get(),
    driversCollection.doc(uid).get(),
    fetchAllTierSettings(),
  ]);

  if (!rideDoc.exists) {
    throw new HttpsError("not-found", "Ride not found.");
  }

  const ride = rideDoc.data()!;
  if (ride.driverUid !== uid) {
    throw new HttpsError("permission-denied", "You are not the assigned driver.");
  }
  if (ride.status !== "rideStarted") {
    throw new HttpsError("failed-precondition", "Ride is not in started state.");
  }

  const driverData = driverDoc.data() ?? {};
  const driverTier = (driverData.tier as string) ?? "bronze";
  const referredByCode = (driverData.referredByCode as string) ?? null;
  const currentCompletedRides = (driverData.completedRides as number) ?? 0;
  const averageRating = (driverData.averageRating as number) ?? 0;

  // Read commission rate from tier settings (fallback to 20%)
  const tierSetting = allTierSettings[driverTier] ?? DEFAULT_TIER_SETTINGS.bronze;
  const commissionPercent = tierSetting.commissionPercent;
  const commissionRate = commissionPercent / 100;

  const customerUid = ride.customerUid as string | undefined;
  const customerRef = customerUid ? customersCollection.doc(customerUid) : null;
  const destination = ride.dropoffLabel ?? "destination";

  const finalFare = ride.finalFare ?? ride.amountNaira ?? 0;
  const promoDiscount = (ride.promoDiscount as number) ?? 0;

  let creditDiscount = (ride.creditDiscount as number) ?? 0;
  if (ride.useCreditWallet && customerRef && !creditDiscount) {
    let creditAmountChargePercent = 10;
    try {
      const sSnap = await admin.firestore().collection("config").doc("referralSettings").get();
      if (sSnap.exists && typeof sSnap.data()?.creditAmountChargePercent === "number") {
        creditAmountChargePercent = sSnap.data()!.creditAmountChargePercent;
      }
    } catch (_) {}
    const cSnap = await customerRef.get();
    if (cSnap.exists) {
      const availCredit = (cSnap.data()?.creditBalance as number) || 0;
      const maxCover = Math.floor(finalFare * (creditAmountChargePercent / 100));
      creditDiscount = Math.min(availCredit, maxCover);
    }
  }

  const customerCharged = Math.max(0, finalFare - promoDiscount - creditDiscount);

  const paymentMethod = (ride.paymentMethod as string) ?? "cash";
  const commissionNaira = Math.round(finalFare * commissionRate);
  const driverNet = finalFare - commissionNaira;
  const driverRef = driversCollection.doc(uid);

  const newCompletedRides = currentCompletedRides + 1;
  const newTier = calculateTier(newCompletedRides, averageRating, allTierSettings);

  await admin.firestore().runTransaction(async (tx) => {
    if (ride.useCreditWallet && creditDiscount > 0 && customerRef) {
      tx.update(customerRef, {
        creditBalance: admin.firestore.FieldValue.increment(-creditDiscount),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const creditTxRef = admin.firestore().collection("credit_transactions").doc();
      tx.set(creditTxRef, {
        uid: customerUid,
        type: "credit_used",
        amountNaira: creditDiscount,
        rideId,
        description: `Credit Wallet discount applied for ride to ${destination}`,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    if (paymentMethod === "wallet" && customerCharged > 0) {
      if (!customerRef) {
        throw new HttpsError("failed-precondition", "Missing customerUid for wallet ride.");
      }
      const customerSnap = await tx.get(customerRef);
      if (!customerSnap.exists) {
        throw new HttpsError("failed-precondition", "Customer not found.");
      }
      const currentBalance = (customerSnap.data()?.walletBalance as number) || 0;
      if (currentBalance < customerCharged) {
        throw new HttpsError("failed-precondition", "Insufficient wallet balance.");
      }
      tx.update(customerRef, {
        walletBalance: admin.firestore.FieldValue.increment(-customerCharged),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      const customerDebitTxRef = admin.firestore().collection("walletTransactions").doc();
      tx.set(customerDebitTxRef, {
        uid: customerUid,
        type: "debit",
        amountNaira: customerCharged,
        method: "wallet",
        reference: rideId,
        description: `Payment for ride to ${destination}${ride.promoCode ? ' (Promo applied)' : ''}`,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    tx.update(rideRef, {
      status: "completed",
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      commissionNaira,
      commissionRate,
      commissionPercent,
      driverNet,
      driverTier,
      ...(paymentMethod === "wallet"
        ? {
            paymentStatus: "paid",
            paidAt: admin.firestore.FieldValue.serverTimestamp(),
          }
        : {}),
    });

    // Update driver trip count and tier
    tx.update(driverRef, {
      completedRides: admin.firestore.FieldValue.increment(1),
      tier: newTier,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    if (paymentMethod === "cash") {
      tx.update(driverRef, {
        walletBalance: admin.firestore.FieldValue.increment(-commissionNaira),
      });

      const commissionTxRef = admin.firestore().collection("walletTransactions").doc();
      tx.set(commissionTxRef, {
        uid,
        type: "commission_debit",
        amountNaira: commissionNaira,
        method: "cash_ride",
        reference: rideId,
        description: `Platform commission (${commissionPercent}%) for cash ride to ${destination}`,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const earningsTxRef = admin.firestore().collection("walletTransactions").doc();
      tx.set(earningsTxRef, {
        uid,
        type: "credit",
        amountNaira: finalFare,
        method: "cash_ride",
        reference: rideId,
        description: `Cash fare collected for ride to ${destination}`,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      tx.update(driverRef, {
        walletBalance: admin.firestore.FieldValue.increment(driverNet),
      });

      const earningsTxRef = admin.firestore().collection("walletTransactions").doc();
      tx.set(earningsTxRef, {
        uid,
        type: "credit",
        amountNaira: driverNet,
        method: "wallet_ride",
        reference: rideId,
        description: `Earnings (after ${commissionPercent}% commission) for ride to ${destination}`,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    const platformTxRef = admin.firestore().collection("platformEarnings").doc();
    tx.set(platformTxRef, {
      rideId,
      driverUid: uid,
      customerUid: ride.customerUid,
      commissionNaira,
      commissionRate,
      commissionPercent,
      finalFare,
      paymentMethod,
      driverTier,
      promoCode: ride.promoCode || null,
      promoDiscount: promoDiscount,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  // ── Referral earnings (outside main transaction to avoid complexity) ──────
  let driverReferralPercent = 2;
  let customerReferralPercent = 2;
  try {
    const settingsSnap = await admin.firestore().collection("config").doc("referralSettings").get();
    if (settingsSnap.exists) {
      const data = settingsSnap.data();
      if (data) {
        if (typeof data.driverReferralPercent === "number") {
          driverReferralPercent = data.driverReferralPercent;
        }
        if (typeof data.customerReferralPercent === "number") {
          customerReferralPercent = data.customerReferralPercent;
        }
      }
    }
  } catch (err) {
    logger.warn("Failed to fetch referralSettings config", err);
  }

  if (referredByCode) {
    try {
      const cleanRefLower = referredByCode.trim().toLowerCase();
      let referrerDoc = (await driversCollection
        .where("referralCodeLower", "==", cleanRefLower)
        .limit(1)
        .get()).docs[0];
      if (!referrerDoc) {
        referrerDoc = (await driversCollection
          .where("referralCode", "==", referredByCode.trim())
          .limit(1)
          .get()).docs[0];
      }
      if (!referrerDoc) {
        referrerDoc = (await customersCollection
          .where("referralCodeLower", "==", cleanRefLower)
          .limit(1)
          .get()).docs[0];
      }
      if (!referrerDoc) {
        referrerDoc = (await customersCollection
          .where("referralCode", "==", referredByCode.trim())
          .limit(1)
          .get()).docs[0];
      }

      if (referrerDoc) {
        const referrerUid = referrerDoc.id;
        const referralEarning = Math.round(finalFare * (driverReferralPercent / 100));

        await admin.firestore().runTransaction(async (tx) => {
          tx.update(referrerDoc!.ref, {
            walletBalance: admin.firestore.FieldValue.increment(referralEarning),
            referralEarnings: admin.firestore.FieldValue.increment(referralEarning),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          const referralTxRef = admin.firestore().collection("walletTransactions").doc();
          tx.set(referralTxRef, {
            uid: referrerUid,
            type: "referral_credit",
            amountNaira: referralEarning,
            method: "referral",
            reference: rideId,
            referredDriverUid: uid,
            description: `${driverReferralPercent}% referral earning from driver ride to ${destination}`,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        });

        logger.info("Referral earning credited", { referrerUid, referralEarning, rideId });
      }
    } catch (e) {
      logger.error("Failed to process referral earning", { uid, referredByCode, rideId, e });
    }
  }

  // ── Customer Referral earnings (outside main transaction to avoid complexity) ──────
  if (customerUid) {
    try {
      const customerDoc = await customersCollection.doc(customerUid).get();
      const customerReferredBy = customerDoc.data()?.referredByCode;
      if (customerReferredBy) {
        const cleanRefLower = customerReferredBy.trim().toLowerCase();
        let referrerDoc = (await customersCollection
          .where("referralCodeLower", "==", cleanRefLower)
          .limit(1)
          .get()).docs[0];
        if (!referrerDoc) {
          referrerDoc = (await customersCollection
            .where("referralCode", "==", customerReferredBy.trim())
            .limit(1)
            .get()).docs[0];
        }
        if (!referrerDoc) {
          referrerDoc = (await driversCollection
            .where("referralCodeLower", "==", cleanRefLower)
            .limit(1)
            .get()).docs[0];
        }
        if (!referrerDoc) {
          referrerDoc = (await driversCollection
            .where("referralCode", "==", customerReferredBy.trim())
            .limit(1)
            .get()).docs[0];
        }

        if (referrerDoc) {
          const customerReferralEarning = Math.round(commissionNaira * (customerReferralPercent / 100));
          if (customerReferralEarning > 0) {
            const refDocRef = referrerDoc.ref;
            await admin.firestore().runTransaction(async (tx) => {
              tx.update(refDocRef, {
                walletBalance: admin.firestore.FieldValue.increment(customerReferralEarning),
                referralEarnings: admin.firestore.FieldValue.increment(customerReferralEarning),
                updatedAt: admin.firestore.FieldValue.serverTimestamp(),
              });

              const referralTxRef = admin.firestore().collection("walletTransactions").doc();
              tx.set(referralTxRef, {
                uid: refDocRef.id,
                type: "referral_credit",
                amountNaira: customerReferralEarning,
                method: "referral",
                reference: rideId,
                referredCustomerUid: customerUid,
                description: `${customerReferralPercent}% referral commission from customer ride to ${destination}`,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
              });
            });
            logger.info("Customer referral earning credited", { referrerUid: refDocRef.id, customerReferralEarning, rideId });
          }
        }
      }
    } catch (e) {
      logger.error("Failed to process customer referral earning", { customerUid, rideId, e });
    }
  }

  logger.info("Ride completed with dynamic commission", {
    uid, rideId, finalFare, commissionNaira, commissionPercent, driverNet, paymentMethod, driverTier, newTier,
  });
  await admin.firestore().collection("driverLocations").doc(rideId).delete().catch(() => undefined);
  await driverPresenceCollection.doc(uid).set({
    availabilityState: "online",
    isAvailableForRequests: true,
    currentRideId: null,
    approvalStatusSnapshot: "approved",
    lastHeartbeatAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});
  return { success: true, finalFare, commissionNaira, commissionPercent, driverNet, driverTier };
});

export const respondToBid = onCall({ region: REGION_PRIMARY, maxInstances: 5 }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const uid = request.auth.uid;
  const payload = request.data as RespondToBidPayload;
  const { rideId, bidId, action, counterOffer } = payload;

  if (!rideId || !bidId || !action) {
    throw new HttpsError("invalid-argument", "Missing rideId, bidId, or action.");
  }

  const rideRef = admin.firestore().collection("rides").doc(rideId);
  const bidRef = admin
    .firestore()
    .collection("bids")
    .doc(rideId)
    .collection("offers")
    .doc(bidId);

  const [rideDoc, bidDoc] = await Promise.all([rideRef.get(), bidRef.get()]);

  if (!rideDoc.exists) {
    throw new HttpsError("not-found", "Ride not found.");
  }
  if (!bidDoc.exists) {
    throw new HttpsError("not-found", "Bid not found.");
  }

  const ride = rideDoc.data()!;
  if (ride.customerUid !== uid) {
    throw new HttpsError("permission-denied", "Only the customer can respond to bids.");
  }

  const bid = bidDoc.data()!;

  let promoDoc: admin.firestore.DocumentSnapshot | null = null;
  if (action === "accept" && ride.promoCode) {
    const promoSnap = await admin.firestore()
      .collection("promos")
      .where("code", "==", ride.promoCode)
      .where("isActive", "==", true)
      .limit(1)
      .get();
    if (!promoSnap.empty) {
      promoDoc = promoSnap.docs[0];
    }
  }

  if (action === "accept") {
    await admin.firestore().runTransaction(async (tx) => {
      const [rideSnap, bidSnap, presenceSnap] = await Promise.all([
        tx.get(rideRef),
        tx.get(bidRef),
        tx.get(driverPresenceCollection.doc(bid.driverUid)),
      ]);
      if (!rideSnap.exists) {
        throw new HttpsError("not-found", "Ride not found.");
      }
      if (!bidSnap.exists) {
        throw new HttpsError("not-found", "Bid not found.");
      }
      const liveRide = rideSnap.data()!;
      const liveBid = bidSnap.data()!;
      const presence = presenceSnap.data();

      if (liveRide.customerUid !== uid) {
        throw new HttpsError("permission-denied", "Only the customer can respond to bids.");
      }
      if (!["requested", "bidding"].includes(liveRide.status)) {
        throw new HttpsError("failed-precondition", "Ride not accepting bids.");
      }
      if (liveRide.driverUid) {
        throw new HttpsError("failed-precondition", "Ride already assigned.");
      }
      if (liveBid.status !== "pending") {
        throw new HttpsError("failed-precondition", "Bid not pending.");
      }
      const expiresAt = (liveBid.expiresAt as admin.firestore.Timestamp | undefined)?.toDate();
      if (expiresAt && expiresAt.getTime() < Date.now()) {
        throw new HttpsError("failed-precondition", "Bid expired.");
      }
      if (
        !presence ||
        presence.availabilityState !== "online" ||
        presence.isAvailableForRequests !== true ||
        presence.currentRideId
      ) {
        throw new HttpsError("failed-precondition", "Driver not available.");
      }

      let promoDiscount = 0;
      if (promoDoc && promoDoc.exists) {
        const promoData = promoDoc.data()!;
        const minFare = Number(promoData.minFare) || 0;
        const discountType = promoData.discountType || "percentage";
        const discountValue = Number(promoData.discountValue) || 0;
        const maxCap = Number(promoData.maxCap) || 0;
        const finalFare = liveBid.offerNaira || 0;

        if (finalFare >= minFare) {
          if (discountType === "flat") {
            promoDiscount = Math.min(discountValue, finalFare);
          } else {
            let calculated = finalFare * (discountValue / 100);
            if (maxCap > 0 && calculated > maxCap) {
              calculated = maxCap;
            }
            promoDiscount = Math.min(calculated, finalFare);
          }
        }
      }

      // Calculate Credit Wallet discount on accepted driver bid
      let creditDiscount = 0;
      if (liveRide.useCreditWallet && uid) {
        let creditAmountChargePercent = 10;
        try {
          const sSnap = await admin.firestore().collection("config").doc("referralSettings").get();
          if (sSnap.exists && typeof sSnap.data()?.creditAmountChargePercent === "number") {
            creditAmountChargePercent = sSnap.data()!.creditAmountChargePercent;
          }
        } catch (_) {}

        const custSnap = await admin.firestore().collection("customers").doc(uid).get();
        if (custSnap.exists) {
          const availCredit = (custSnap.data()?.creditBalance as number) || 0;
          const maxCoverage = Math.floor((liveBid.offerNaira || 0) * (creditAmountChargePercent / 100));
          creditDiscount = Math.min(availCredit, maxCoverage);
        }
      }

      tx.update(rideRef, {
        status: "driverEnRoute",
        driverUid: liveBid.driverUid,
        driverName: liveBid.driverName,
        finalFare: liveBid.offerNaira,
        amountNaira: liveBid.offerNaira,
        acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        acceptedBidId: (liveBid.bidId as string | undefined) ?? bidId,
        promoDiscount: Math.round(promoDiscount),
        creditDiscount: Math.round(creditDiscount),
        customerPayable: Math.max(0, (liveBid.offerNaira || 0) - Math.round(promoDiscount) - Math.round(creditDiscount)),
      });
      tx.update(bidRef, { status: "accepted", updatedAt: admin.firestore.FieldValue.serverTimestamp() });
      // Chat thread is now created on-demand when a message is first sent,
      // rather than auto-created on bid acceptance.
      tx.set(driverPresenceCollection.doc(liveBid.driverUid), {
        driverUid: liveBid.driverUid,
        availabilityState: "on_trip",
        isAvailableForRequests: false,
        currentRideId: rideId,
        approvalStatusSnapshot: "approved",
        lastHeartbeatAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
    });

    const offersSnap = await admin
      .firestore()
      .collection("bids")
      .doc(rideId)
      .collection("offers")
      .get();
    const batch = admin.firestore().batch();
    for (const offer of offersSnap.docs) {
      if (offer.id === bidId) continue;
      batch.update(offer.ref, {
        status: "rejected",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  } else if (action === "reject") {
    await bidRef.update({ status: "rejected", updatedAt: admin.firestore.FieldValue.serverTimestamp() });
  } else if (action === "counter") {
    if (counterOffer == null || counterOffer <= 0) {
      throw new HttpsError("invalid-argument", "Invalid counter offer amount.");
    }
    await bidRef.update({
      counterOffer,
      status: "countered",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      counterAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } else {
    throw new HttpsError("invalid-argument", `Unknown action: ${action}`);
  }

  logger.info("Bid response recorded", { uid, rideId, bidId, action });
  return { success: true };
});

export const cancelRideByCustomer = onCall({ region: REGION_PRIMARY, maxInstances: 5 }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const uid = request.auth.uid;
  const payload = request.data as CancelRideByCustomerPayload;
  const rideId = payload.rideId?.trim();
  const reason = payload.reason?.trim();
  if (!rideId) {
    throw new HttpsError("invalid-argument", "Missing rideId.");
  }

  const rideRef = admin.firestore().collection("rides").doc(rideId);
  await admin.firestore().runTransaction(async (tx) => {
    const rideSnap = await tx.get(rideRef);
    if (!rideSnap.exists) {
      throw new HttpsError("not-found", "Ride not found.");
    }
    const ride = rideSnap.data()!;
    if (ride.customerUid !== uid) {
      throw new HttpsError("permission-denied", "Not your ride.");
    }
    // Already cancelled — succeed silently
    if (ride.status === "cancelled") {
      return;
    }
    // Allow cancellation while waiting for or reviewing driver bids
    if (!["requested", "bidding"].includes(ride.status)) {
      throw new HttpsError("failed-precondition", `Cannot cancel ride with status: ${ride.status}.`);
    }

    tx.update(rideRef, {
      status: "cancelled",
      ...(reason ? { cancellationReason: reason } : {}),
      cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      cancelledBy: "customer",
    });

    const driverUid = ride.driverUid as string | undefined;
    if (driverUid) {
      tx.set(
        driverPresenceCollection.doc(driverUid),
        {
          availabilityState: "online",
          isAvailableForRequests: true,
          currentRideId: null,
          lastHeartbeatAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    }
  });

  return { success: true };
});

export const rateCustomer = onCall({ region: REGION_PRIMARY, maxInstances: 5 }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const uid = request.auth.uid;
  const payload = request.data as RateCustomerPayload;
  const { rideId, rating, comment } = payload;

  if (!rideId || rating == null || rating < 1 || rating > 5) {
    throw new HttpsError("invalid-argument", "Invalid rideId or rating (must be 1-5).");
  }

  const rideRef = admin.firestore().collection("rides").doc(rideId);
  const rideDoc = await rideRef.get();
  if (!rideDoc.exists) {
    throw new HttpsError("not-found", "Ride not found.");
  }
  if (rideDoc.data()!.driverUid !== uid) {
    throw new HttpsError("permission-denied", "Only the assigned driver can rate the customer.");
  }

  await rideRef.update({
    customerRating: rating,
    ...(comment ? { customerRatingComment: comment } : {}),
    customerRatedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  logger.info("Customer rated by driver", { uid, rideId, rating });
  return { success: true };
});

// ─────────────────────────── Ride Triggers ───────────────────

export const onRideStatusChanged = onDocumentUpdated({ document: "rides/{rideId}", region: "us-east1" }, async (event) => {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!before || !after) return;

  if (before.status !== "completed" && after.status === "completed") {
    const uid = after.customerUid as string;
    const paymentMethod = after.paymentMethod as string;
    const finalFare = (after.finalFare as number) || 0;
    const rideId = event.params.rideId;

    if (paymentMethod === "wallet" && finalFare > 0) {
      if ((after.paymentStatus as string | undefined) === "paid" || after.paidAt) {
        return;
      }
      const rideRef = admin.firestore().collection("rides").doc(rideId);
      const userRef = customersCollection.doc(uid);

      await admin.firestore().runTransaction(async (tx) => {
        const userDoc = await tx.get(userRef);
        if (!userDoc.exists) return;

        const currentBalance = (userDoc.data()?.walletBalance as number) || 0;
        if (currentBalance < finalFare) return;

        tx.update(userRef, {
          walletBalance: admin.firestore.FieldValue.increment(-finalFare),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        const txRef = admin.firestore().collection("walletTransactions").doc();
        tx.set(txRef, {
          uid,
          type: "debit",
          amountNaira: finalFare,
          method: "wallet",
          reference: rideId,
          description: `Payment for ride to ${(after.dropoffLabel as string) || "destination"}`,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        tx.update(rideRef, {
          paymentStatus: "paid",
          paidAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });
    }
  }
});

export const onRideCreatedCustomerNotify = onDocumentCreated(
  { document: "rides/{rideId}", region: "us-east1" },
  async (event) => {
    const ride = event.data?.data() as Record<string, unknown> | undefined;
    if (!ride) return;
    if ((ride.status as string | undefined) !== "requested") return;
    const customerUid = ride.customerUid as string | undefined;
    if (!customerUid) return;
    const rideId = event.params.rideId as string;
    const rideRef = event.data!.ref;

    const ok = await claimRideNotifyMarker(rideRef, "customerNotify.rideBookedPushSentAt");
    if (!ok) return;

    await sendPushToCustomer(
      customerUid,
      "Ride request received",
      "We\u2019re searching for nearby drivers.",
      { type: "ride_booked", rideId }
    );
  }
);

export const onRideUpdatedCustomerNotify = onDocumentUpdated(
  { document: "rides/{rideId}", region: "us-east1" },
  async (event) => {
    const before = event.data?.before.data() as Record<string, unknown> | undefined;
    const after = event.data?.after.data() as Record<string, unknown> | undefined;
    if (!before || !after) return;

    const rideId = event.params.rideId as string;
    const rideRef = event.data!.after.ref;
    const customerUid = after.customerUid as string | undefined;
    if (!customerUid) return;

    const customerSnap = await customersCollection.doc(customerUid).get();
    const customerEmail = customerSnap.data()?.email as string | undefined;

    const beforeStatus = before.status as string | undefined;
    const afterStatus = after.status as string | undefined;

    if (beforeStatus !== "driverArrived" && afterStatus === "driverArrived") {
      const pushOk = await claimRideNotifyMarker(rideRef, "customerNotify.driverArrivedPushSentAt");
      if (pushOk) {
        await sendPushToCustomer(
          customerUid,
          "Driver has arrived!",
          "Your driver has arrived at the pickup location.",
          { type: "driver_arrived", rideId }
        );
      }
    }

    if (beforeStatus !== "rideStarted" && afterStatus === "rideStarted") {
      const pushOk = await claimRideNotifyMarker(rideRef, "customerNotify.rideStartedPushSentAt");
      if (pushOk) {
        await sendPushToCustomer(
          customerUid,
          "Ride started",
          "Your driver has started your trip.",
          { type: "ride_started", rideId }
        );
      }

      const emailOk = await claimRideNotifyMarker(rideRef, "customerNotify.rideStartedSentAt");
      if (emailOk && customerEmail) {
        await sendRideStartedEmail(customerEmail, rideId, after);
      }
    }

    if (beforeStatus !== "completed" && afterStatus === "completed") {
      const pushOk = await claimRideNotifyMarker(rideRef, "customerNotify.rideCompletedPushSentAt");
      if (pushOk) {
        await sendPushToCustomer(
          customerUid,
          "Ride completed",
          "Thanks for riding with CaRide. Please rate your driver in the app.",
          { type: "ride_completed", rideId }
        );
      }

      const completedEmailOk = await claimRideNotifyMarker(rideRef, "customerNotify.rideCompletedSentAt");
      if (completedEmailOk && customerEmail) {
        await sendRideCompletedEmail(customerEmail, rideId, after);
      }

      const receiptEmailOk = await claimRideNotifyMarker(rideRef, "customerNotify.receiptSentAt");
      if (receiptEmailOk && customerEmail) {
        await sendRideReceiptEmail(customerEmail, rideId, after);
      }
    }
  }
);

export const onRideUpdatedDriverNotify = onDocumentUpdated(
  { document: "rides/{rideId}", region: "us-east1" },
  async (event) => {
    const before = event.data?.before.data() as Record<string, unknown> | undefined;
    const after = event.data?.after.data() as Record<string, unknown> | undefined;
    if (!before || !after) return;

    const rideId = event.params.rideId as string;
    const rideRef = event.data!.after.ref;
    const driverUid = after.driverUid as string | undefined;
    if (!driverUid) return;

    const beforeStatus = before.status as string | undefined;
    const afterStatus = after.status as string | undefined;

    const pickupLabel = (after.pickupLabel as string | undefined) ?? "Pickup";
    const dropoffLabel = (after.dropoffLabel as string | undefined) ?? "Dropoff";

    if (beforeStatus !== "driverEnRoute" && afterStatus === "driverEnRoute") {
      const ok = await claimRideNotifyMarker(rideRef, "driverNotify.rideAssignedPushSentAt");
      if (ok) {
        await sendPushToDriver(
          driverUid,
          "Trip assigned",
          `Pickup: ${pickupLabel}`,
          { type: "ride_assigned", rideId }
        );
      }
    }

    if (beforeStatus !== "cancelled" && afterStatus === "cancelled") {
      const ok = await claimRideNotifyMarker(rideRef, "driverNotify.rideCancelledPushSentAt");
      if (ok) {
        await sendPushToDriver(
          driverUid,
          "Trip cancelled",
          `Dropoff: ${dropoffLabel}`,
          { type: "ride_cancelled", rideId }
        );
      }
    }

    if (beforeStatus !== "rideStarted" && afterStatus === "rideStarted") {
      const pushOk = await claimRideNotifyMarker(rideRef, "driverNotify.rideStartedPushSentAt");
      if (pushOk) {
        await sendPushToDriver(
          driverUid,
          "Trip started",
          `${pickupLabel} → ${dropoffLabel}`,
          { type: "ride_started", rideId }
        );
      }

      const emailOk = await claimRideNotifyMarker(rideRef, "driverNotify.rideStartedEmailSentAt");
      if (emailOk) {
        const driverSnap = await driversCollection.doc(driverUid).get();
        const driverEmail = driverSnap.data()?.email as string | undefined;
        if (driverEmail) {
          await sendDriverRideStartedEmail(driverEmail, rideId, after);
        }
      }
    }

    if (beforeStatus !== "completed" && afterStatus === "completed") {
      const pushOk = await claimRideNotifyMarker(rideRef, "driverNotify.rideCompletedPushSentAt");
      if (pushOk) {
        await sendPushToDriver(
          driverUid,
          "Trip completed",
          "Open the app to view your summary.",
          { type: "ride_completed", rideId }
        );
      }

      const emailOk = await claimRideNotifyMarker(rideRef, "driverNotify.rideCompletedEmailSentAt");
      if (emailOk) {
        const driverSnap = await driversCollection.doc(driverUid).get();
        const driverEmail = driverSnap.data()?.email as string | undefined;
        if (driverEmail) {
          await sendDriverRideCompletedEmail(driverEmail, rideId, after);
        }
      }
    }
  }
);

// ─────────────────────────── Withdrawal Functions ────────────────────────────

/**
 * Called by admin dashboard when marking a driver's weekly payout as "Paid".
 * Deducts the snapshotted wallet balance, logs a payout transaction, marks the
 * snapshot entry as paid, and notifies the driver.
 */
export const adminProcessWithdrawal = onCall({ region: REGION_PRIMARY, maxInstances: 1 }, async (request) => {
  // Basic auth check — in production add admin custom claim check
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const adminSnap = await admin
    .firestore()
    .collection("admins")
    .doc(request.auth.uid)
    .get();
  if (!adminSnap.exists) {
    throw new HttpsError("permission-denied", "Admin only.");
  }
  const payload = request.data as AdminProcessWithdrawalPayload;
  const snapshotId = payload.snapshotId?.trim();
  const driverUid = payload.driverUid?.trim();

  if (!snapshotId || !driverUid) {
    throw new HttpsError("invalid-argument", "Missing snapshotId or driverUid.");
  }

  const entryRef = admin.firestore()
    .collection("withdrawalSnapshots")
    .doc(snapshotId)
    .collection("entries")
    .doc(driverUid);

  const [entrySnap, driverSnap] = await Promise.all([entryRef.get(), driversCollection.doc(driverUid).get()]);

  if (!entrySnap.exists) {
    throw new HttpsError("not-found", "Withdrawal snapshot entry not found.");
  }

  const entry = entrySnap.data() as {
    walletBalance: number; fullName: string; email: string;
    paid?: boolean; bankAccount?: { bankName: string; accountName: string; maskedAccountNumber: string };
  };

  if (entry.paid) {
    throw new HttpsError("already-exists", "This payout has already been processed.");
  }

  const amountNaira = entry.walletBalance;
  if (amountNaira <= 0) {
    throw new HttpsError("failed-precondition", "Wallet balance is zero — nothing to pay.");
  }

  const driverData = driverSnap.data() ?? {};
  const currentBalance = (driverData.walletBalance as number) ?? 0;

  await admin.firestore().runTransaction(async (tx) => {
    // Deduct from driver wallet (use current balance, not snapshot — safer)
    tx.update(driversCollection.doc(driverUid), {
      walletBalance: admin.firestore.FieldValue.increment(-amountNaira),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Log a payout transaction in walletTransactions
    const txRef = admin.firestore().collection("walletTransactions").doc();
    tx.set(txRef, {
      uid: driverUid,
      type: "payout",
      amountNaira,
      method: "bank_transfer",
      reference: snapshotId,
      description: `Weekly payout to ${entry.bankAccount?.bankName ?? "bank"} ${entry.bankAccount?.maskedAccountNumber ?? ""}`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Mark the snapshot entry as paid
    tx.update(entryRef, {
      paid: true,
      paidAt: admin.firestore.FieldValue.serverTimestamp(),
      paidByUid: request.auth!.uid,
      balanceAtPayout: currentBalance,
    });
  });

  // Send email + push to driver
  try {
    const bank = entry.bankAccount;
    if (entry.email) {
      await sendPayoutEmail(
        entry.email,
        entry.fullName,
        amountNaira,
        bank?.bankName ?? "Bank",
        bank?.maskedAccountNumber ?? "****",
        snapshotId,
        currentBalance,
      );
    }
    await sendPushToDriver(
      driverUid,
      "\uD83D\uDCB8 Payout Processed!",
      `${formatNairaCurrency(amountNaira)} has been sent to your ${bank?.bankName ?? "bank"} account.`,
      { type: "payout", amount: String(amountNaira) }
    );
  } catch (e) {
    logger.error("Failed to send payout notification", { driverUid, e });
  }

  logger.info("Withdrawal processed", { driverUid, snapshotId, amountNaira });
  return { success: true, amountNaira };
});

// ─────────────────────────── Flutterwave Settlement Functions ───────────────────────────

export const adminProcessSinglePayout = onCall({ region: REGION_PRIMARY, maxInstances: 1 }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const adminSnap = await admin.firestore().collection("admins").doc(request.auth.uid).get();
  if (!adminSnap.exists) {
    throw new HttpsError("permission-denied", "Admin only.");
  }

  const { driverId, amount, batchId } = request.data as { driverId?: string; amount?: number; batchId?: string };
  if (!driverId || !amount || amount <= 0) {
    throw new HttpsError("invalid-argument", "Missing or invalid driverId or amount.");
  }

  const driverRef = driversCollection.doc(driverId);
  const driverSnap = await driverRef.get();
  if (!driverSnap.exists) {
    throw new HttpsError("not-found", "Driver not found.");
  }
  const driverData = driverSnap.data()!;

  // Fetch primary bank account
  const bankSnap = await driverRef.collection("bankAccounts").where("isDefault", "==", true).limit(1).get();
  if (bankSnap.empty) {
    throw new HttpsError("failed-precondition", "Driver has no bank account linked.");
  }
  const bank = bankSnap.docs[0].data();
  const bankCode = bank.bankCode?.trim();
  const accountNumber = bank.accountNumber?.trim();
  const accountName = bank.accountName?.trim() || bank.account_name?.trim();

  if (!bankCode || !accountNumber || !accountName) {
    throw new HttpsError("failed-precondition", "Incomplete bank details (missing account number, bank code, or account name).");
  }

  // Idempotency: Check driverPayouts for existing successful payout using same batch and driver
  if (batchId) {
    const existingPayout = await admin.firestore().collection("driverPayouts")
      .where("driverId", "==", driverId)
      .where("batchId", "==", batchId)
      .where("status", "==", "successful")
      .limit(1)
      .get();
    if (!existingPayout.empty) {
      throw new HttpsError("already-exists", "A successful payout already exists for this driver in this batch.");
    }
  }

  // Double check balance
  const currentBalance = (driverData.walletBalance as number) ?? 0;
  if (currentBalance < amount) {
    throw new HttpsError("failed-precondition", "Insufficient wallet balance.");
  }

  const reference = `payout_${driverId}_${batchId || "single"}_${Date.now()}`;

  let transferRes: any;
  try {
    transferRes = await flutterwaveRequest<any>("POST", "/transfers", {
      account_bank: bankCode,
      account_number: accountNumber,
      amount: amount,
      narration: "CaRide Settlement Payout",
      currency: "NGN",
      reference: reference,
    });
  } catch (err: any) {
    logger.error("Flutterwave API transfer call crashed", { driverId, err: String(err) });
    throw new HttpsError("internal", `Flutterwave API request failed: ${err.message || String(err)}`);
  }

  const isSuccess = transferRes?.status === "success" && transferRes?.data?.status !== "FAILED";

  const payoutRef = admin.firestore().collection("driverPayouts").doc();
  const payoutId = payoutRef.id;

  if (isSuccess) {
    const flutterwaveId = String(transferRes?.data?.id || transferRes?.data?.reference || reference);

    await admin.firestore().runTransaction(async (tx) => {
      // Set wallet balance to 0 (or decrement)
      tx.update(driverRef, {
        walletBalance: 0,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Create transaction log
      const txRef = admin.firestore().collection("transactions").doc();
      tx.set(txRef, {
        driverId,
        type: "payout",
        amount,
        status: "successful",
        reference,
        flutterwaveTransferId: flutterwaveId,
        description: `Settlement to ${bank.bankName || "Bank"} ${accountNumber}`,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Create legacy walletTransactions for app compatibility
      const legacyTxRef = admin.firestore().collection("walletTransactions").doc();
      tx.set(legacyTxRef, {
        uid: driverId,
        type: "payout",
        amountNaira: amount,
        method: "bank_transfer",
        reference,
        description: `Payout to ${bank.bankName || "Bank"} ${accountNumber}`,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Create payout record
      tx.set(payoutRef, {
        driverId,
        amount,
        status: "successful",
        flutterwaveTransferId: flutterwaveId,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        processedBy: request.auth!.uid,
        batchId: batchId || null,
        reference,
      });

      // Log admin audit
      const auditRef = admin.firestore().collection("adminAuditLogs").doc();
      tx.set(auditRef, {
        adminId: request.auth!.uid,
        action: "single_payout",
        driverId,
        amount,
        reference,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });

    // Notify driver
    try {
      if (driverData.email) {
        await sendPayoutEmail(
          driverData.email,
          driverData.fullName || "Driver",
          amount,
          bank.bankName || "Bank",
          bank.maskedAccountNumber || accountNumber.slice(-4),
          reference,
          0,
        );
      }
      await sendPushToDriver(
        driverId,
        "💸 Payout Processed!",
        `${formatNairaCurrency(amount)} has been sent to your bank account.`,
        { type: "payout", amount: String(amount) }
      );
    } catch (e) {
      logger.error("Failed to send payout notification", { driverId, e });
    }

    return { success: true, payoutId, status: "successful", flutterwaveTransferId: flutterwaveId };
  } else {
    const reason = transferRes?.message || "Failed to process transfer via Flutterwave.";
    await payoutRef.set({
      driverId,
      amount,
      status: "failed",
      failureReason: reason,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      processedBy: request.auth!.uid,
      batchId: batchId || null,
      reference,
    });

    // Log admin audit for failure
    await admin.firestore().collection("adminAuditLogs").add({
      adminId: request.auth!.uid,
      action: "single_payout_failed",
      driverId,
      amount,
      reason,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return { success: false, payoutId, status: "failed", failureReason: reason };
  }
});

export const adminCreateSettlementBatch = onCall({ region: REGION_PRIMARY, maxInstances: 1 }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const adminSnap = await admin.firestore().collection("admins").doc(request.auth.uid).get();
  if (!adminSnap.exists) {
    throw new HttpsError("permission-denied", "Admin only.");
  }

  // Fetch all eligible drivers (walletBalance > 0)
  const driversSnap = await driversCollection.where("walletBalance", ">", 0).get();
  if (driversSnap.empty) {
    return { success: false, message: "No drivers with positive wallet balance found." };
  }

  const batchRef = admin.firestore().collection("withdrawalBatches").doc();
  const batchId = batchRef.id;

  let totalAmount = 0;
  const entries: any[] = [];

  for (const doc of driversSnap.docs) {
    const d = doc.data();
    const uid = doc.id;
    const walletBalance = (d.walletBalance as number) ?? 0;
    totalAmount += walletBalance;

    // Fetch default bank account
    const bankSnap = await driversCollection.doc(uid).collection("bankAccounts")
      .where("isDefault", "==", true).limit(1).get();
    const bank = bankSnap.empty ? null : bankSnap.docs[0].data();

    entries.push({
      driverUid: uid,
      fullName: (d.fullName as string) ?? "",
      email: (d.email as string) ?? "",
      phone: (d.phone as string) ?? "",
      profilePhotoUrl: (d.profilePhotoUrl as string) ?? "",
      walletBalance,
      bankAccount: bank ? {
        bankName: bank.bankName ?? "",
        accountName: bank.accountName ?? "",
        accountNumber: bank.accountNumber ?? "",
        maskedAccountNumber: bank.maskedAccountNumber ?? bank.accountNumber ?? "",
        bankCode: bank.bankCode ?? "",
      } : null,
    });
  }

  await batchRef.set({
    driverCount: entries.length,
    totalAmount,
    status: "pending",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    createdBy: request.auth.uid,
  });

  // Write subcollection entries
  const entriesCol = batchRef.collection("entries");
  const chunks: any[][] = [];
  for (let i = 0; i < entries.length; i += 400) {
    chunks.push(entries.slice(i, i + 400));
  }

  for (const chunk of chunks) {
    const firestoreBatch = admin.firestore().batch();
    for (const entry of chunk) {
      firestoreBatch.set(entriesCol.doc(entry.driverUid), {
        ...entry,
        status: "pending",
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    await firestoreBatch.commit();
  }

  // Create admin audit log
  await admin.firestore().collection("adminAuditLogs").add({
    adminId: request.auth.uid,
    action: "create_batch",
    batchId,
    amount: totalAmount,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true, batchId, driverCount: entries.length, totalAmount };
});

export const adminExecuteSettlementBatch = onCall({ region: REGION_PRIMARY, maxInstances: 1 }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const adminSnap = await admin.firestore().collection("admins").doc(request.auth.uid).get();
  if (!adminSnap.exists) {
    throw new HttpsError("permission-denied", "Admin only.");
  }

  const { batchId } = request.data as { batchId?: string };
  if (!batchId) {
    throw new HttpsError("invalid-argument", "Missing batchId.");
  }

  const batchRef = admin.firestore().collection("withdrawalBatches").doc(batchId);
  const batchSnap = await batchRef.get();
  if (!batchSnap.exists) {
    throw new HttpsError("not-found", "Settlement batch not found.");
  }

  const batchData = batchSnap.data()!;
  if (batchData.status !== "pending") {
    throw new HttpsError("failed-precondition", `Batch is already in ${batchData.status} state.`);
  }

  await batchRef.update({ status: "processing" });

  const entriesSnap = await batchRef.collection("entries").get();
  let successCount = 0;
  let failedCount = 0;

  for (const entryDoc of entriesSnap.docs) {
    const entry = entryDoc.data();
    const driverId = entry.driverUid;
    const amount = entry.walletBalance;

    if (!entry.bankAccount || !entry.bankAccount.bankCode || !entry.bankAccount.accountNumber) {
      // Mark as failed directly
      const reason = "Missing or incomplete bank account details.";
      await entryDoc.ref.update({
        status: "failed",
        failureReason: reason,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      await admin.firestore().collection("driverPayouts").add({
        driverId,
        amount,
        status: "failed",
        failureReason: reason,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        processedBy: request.auth.uid,
        batchId,
      });

      failedCount++;
      continue;
    }

    // Idempotency: Check if already paid successfully in this batch
    const existingPayout = await admin.firestore().collection("driverPayouts")
      .where("driverId", "==", driverId)
      .where("batchId", "==", batchId)
      .where("status", "==", "successful")
      .limit(1)
      .get();

    if (!existingPayout.empty) {
      await entryDoc.ref.update({
        status: "successful",
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      successCount++;
      continue;
    }

    // Call Flutterwave
    const reference = `payout_${driverId}_${batchId}_${Date.now()}`;
    let transferRes: any;
    try {
      transferRes = await flutterwaveRequest<any>("POST", "/transfers", {
        account_bank: entry.bankAccount.bankCode,
        account_number: entry.bankAccount.accountNumber,
        amount: amount,
        narration: "CaRide Batch Payout",
        currency: "NGN",
        reference,
      });
    } catch (err: any) {
      logger.error(`Batch execution error on driver ${driverId}`, { err: String(err) });
      transferRes = { status: "error", message: err.message || String(err) };
    }

    const isSuccess = transferRes?.status === "success" && transferRes?.data?.status !== "FAILED";

    if (isSuccess) {
      const flutterwaveId = String(transferRes?.data?.id || transferRes?.data?.reference || reference);
      const driverRef = driversCollection.doc(driverId);
      const driverSnap = await driverRef.get();
      const driverData = driverSnap.data() || {};

      await admin.firestore().runTransaction(async (tx) => {
        tx.update(driverRef, {
          walletBalance: 0,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        const txRef = admin.firestore().collection("transactions").doc();
        tx.set(txRef, {
          driverId,
          type: "payout",
          amount,
          status: "successful",
          reference,
          flutterwaveTransferId: flutterwaveId,
          description: `Batch settlement to ${entry.bankAccount.bankName} ${entry.bankAccount.accountNumber}`,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        const legacyTxRef = admin.firestore().collection("walletTransactions").doc();
        tx.set(legacyTxRef, {
          uid: driverId,
          type: "payout",
          amountNaira: amount,
          method: "bank_transfer",
          reference,
          description: `Payout to ${entry.bankAccount.bankName} ${entry.bankAccount.accountNumber}`,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        const payoutRef = admin.firestore().collection("driverPayouts").doc();
        tx.set(payoutRef, {
          driverId,
          amount,
          status: "successful",
          flutterwaveTransferId: flutterwaveId,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          processedBy: request.auth!.uid,
          batchId,
          reference,
        });

        tx.update(entryDoc.ref, {
          status: "successful",
          flutterwaveTransferId: flutterwaveId,
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      });

      // Send notifications
      try {
        if (entry.email) {
          await sendPayoutEmail(
            entry.email,
            entry.fullName,
            amount,
            entry.bankAccount.bankName,
            entry.bankAccount.maskedAccountNumber || entry.bankAccount.accountNumber.slice(-4),
            reference,
            0,
          );
        }
        await sendPushToDriver(
          driverId,
          "💸 Payout Processed!",
          `${formatNairaCurrency(amount)} has been sent to your bank account.`,
          { type: "payout", amount: String(amount) }
        );
      } catch (e) {
        logger.error("Failed to notify driver", { driverId, e });
      }

      successCount++;
    } else {
      const reason = transferRes?.message || "Failed to process transfer via Flutterwave.";
      await entryDoc.ref.update({
        status: "failed",
        failureReason: reason,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      await admin.firestore().collection("driverPayouts").add({
        driverId,
        amount,
        status: "failed",
        failureReason: reason,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        processedBy: request.auth.uid,
        batchId,
        reference,
      });

      failedCount++;
    }
  }

  await batchRef.update({
    status: "completed",
    successCount,
    failedCount,
    executedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  // Create admin audit log
  await admin.firestore().collection("adminAuditLogs").add({
    adminId: request.auth.uid,
    action: "bulk_payout",
    batchId,
    amount: batchData.totalAmount,
    successCount,
    failedCount,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true, successCount, failedCount };
});

export const adminRetryFailedPayout = onCall({ region: REGION_PRIMARY, maxInstances: 1 }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const adminSnap = await admin.firestore().collection("admins").doc(request.auth.uid).get();
  if (!adminSnap.exists) {
    throw new HttpsError("permission-denied", "Admin only.");
  }

  const { payoutId, batchId } = request.data as { payoutId?: string; batchId?: string };

  if (!payoutId && !batchId) {
    throw new HttpsError("invalid-argument", "Either payoutId or batchId must be provided.");
  }

  if (payoutId) {
    const payoutRef = admin.firestore().collection("driverPayouts").doc(payoutId);
    const payoutSnap = await payoutRef.get();
    if (!payoutSnap.exists) {
      throw new HttpsError("not-found", "Payout record not found.");
    }
    const payout = payoutSnap.data()!;
    if (payout.status === "successful") {
      return { success: true, message: "Payout is already successful." };
    }

    const driverId = payout.driverId;
    const amount = payout.amount;
    const parentBatchId = payout.batchId;

    // Trigger single payout execution logic
    const driverRef = driversCollection.doc(driverId);
    const driverSnap = await driverRef.get();
    const driverData = driverSnap.data()!;
    const bankSnap = await driverRef.collection("bankAccounts").where("isDefault", "==", true).limit(1).get();
    if (bankSnap.empty) {
      throw new HttpsError("failed-precondition", "Driver has no bank account linked.");
    }
    const bank = bankSnap.docs[0].data();

    const reference = `retry_${driverId}_${Date.now()}`;
    let transferRes: any;
    try {
      transferRes = await flutterwaveRequest<any>("POST", "/transfers", {
        account_bank: bank.bankCode,
        account_number: bank.accountNumber,
        amount: amount,
        narration: "CaRide Settlement Payout Retry",
        currency: "NGN",
        reference,
      });
    } catch (err: any) {
      throw new HttpsError("internal", `Flutterwave API request failed: ${err.message || String(err)}`);
    }

    const isSuccess = transferRes?.status === "success" && transferRes?.data?.status !== "FAILED";

    if (isSuccess) {
      const flutterwaveId = String(transferRes?.data?.id || transferRes?.data?.reference || reference);
      await admin.firestore().runTransaction(async (tx) => {
        tx.update(driverRef, {
          walletBalance: 0,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        const txRef = admin.firestore().collection("transactions").doc();
        tx.set(txRef, {
          driverId,
          type: "payout",
          amount,
          status: "successful",
          reference,
          flutterwaveTransferId: flutterwaveId,
          description: `Retry payout to ${bank.bankName} ${bank.accountNumber}`,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        const legacyTxRef = admin.firestore().collection("walletTransactions").doc();
        tx.set(legacyTxRef, {
          uid: driverId,
          type: "payout",
          amountNaira: amount,
          method: "bank_transfer",
          reference,
          description: `Payout to ${bank.bankName} ${bank.accountNumber}`,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        tx.update(payoutRef, {
          status: "successful",
          flutterwaveTransferId: flutterwaveId,
          failureReason: admin.firestore.FieldValue.delete(),
          reference,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        if (parentBatchId) {
          const entryRef = admin.firestore().collection("withdrawalBatches").doc(parentBatchId).collection("entries").doc(driverId);
          tx.update(entryRef, {
            status: "successful",
            flutterwaveTransferId: flutterwaveId,
            failureReason: admin.firestore.FieldValue.delete(),
            processedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      });

      return { success: true, status: "successful" };
    } else {
      const reason = transferRes?.message || "Failed to process transfer via Flutterwave.";
      await payoutRef.update({
        failureReason: reason,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      return { success: false, status: "failed", failureReason: reason };
    }
  }

  if (batchId) {
    const batchRef = admin.firestore().collection("withdrawalBatches").doc(batchId);
    const failedEntriesSnap = await batchRef.collection("entries").where("status", "==", "failed").get();

    let retrySuccess = 0;
    for (const entryDoc of failedEntriesSnap.docs) {
      const entry = entryDoc.data();
      const driverId = entry.driverUid;
      const amount = entry.walletBalance;

      const driverRef = driversCollection.doc(driverId);
      const bankSnap = await driverRef.collection("bankAccounts").where("isDefault", "==", true).limit(1).get();
      if (bankSnap.empty) continue;
      const bank = bankSnap.docs[0].data();

      const reference = `retry_${driverId}_${batchId}_${Date.now()}`;
      let transferRes: any;
      try {
        transferRes = await flutterwaveRequest<any>("POST", "/transfers", {
          account_bank: bank.bankCode,
          account_number: bank.accountNumber,
          amount: amount,
          narration: "CaRide Batch Payout Retry",
          currency: "NGN",
          reference,
        });
      } catch {
        continue;
      }

      const isSuccess = transferRes?.status === "success" && transferRes?.data?.status !== "FAILED";

      if (isSuccess) {
        const flutterwaveId = String(transferRes?.data?.id || transferRes?.data?.reference || reference);
        await admin.firestore().runTransaction(async (tx) => {
          tx.update(driverRef, {
            walletBalance: 0,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          const txRef = admin.firestore().collection("transactions").doc();
          tx.set(txRef, {
            driverId,
            type: "payout",
            amount,
            status: "successful",
            reference,
            flutterwaveTransferId: flutterwaveId,
            description: `Retry batch payout to ${bank.bankName} ${bank.accountNumber}`,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          const legacyTxRef = admin.firestore().collection("walletTransactions").doc();
          tx.set(legacyTxRef, {
            uid: driverId,
            type: "payout",
            amountNaira: amount,
            method: "bank_transfer",
            reference,
            description: `Payout to ${bank.bankName} ${bank.accountNumber}`,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          tx.update(entryDoc.ref, {
            status: "successful",
            flutterwaveTransferId: flutterwaveId,
            failureReason: admin.firestore.FieldValue.delete(),
            processedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        });
        retrySuccess++;
      }
    }

    // Update batch meta counts
    const updatedBatchSnap = await batchRef.get();
    const currentMeta = updatedBatchSnap.data()!;
    const newFailedCount = Math.max(0, (currentMeta.failedCount ?? 0) - retrySuccess);
    const newSuccessCount = (currentMeta.successCount ?? 0) + retrySuccess;
    await batchRef.update({
      failedCount: newFailedCount,
      successCount: newSuccessCount,
    });

    return { success: true, retrySuccessCount: retrySuccess };
  }

  return { success: false };
});


export const reconcileStuckRides = onSchedule(
  { schedule: "every 5 minutes", timeZone: "UTC", region: REGION_SCHEDULE, maxInstances: 1 },
  async () => {
  const nowMs = Date.now();
  const biddingTimeoutMs = 10 * 60_000;
  const enRouteTimeoutMs = 20 * 60_000;
  const staleLocationMs = 5 * 60_000;

  const ridesCol = admin.firestore().collection("rides");

  const biddingSnap = await ridesCol
    .where("status", "==", "bidding")
    .orderBy("updatedAt", "asc")
    .limit(50)
    .get();

  for (const doc of biddingSnap.docs) {
    const ride = doc.data();
    const updatedAtMs =
      (ride.updatedAt as admin.firestore.Timestamp | undefined)?.toDate()?.getTime() ?? 0;
    if (updatedAtMs <= 0 || nowMs - updatedAtMs < biddingTimeoutMs) continue;

    const offersSnap = await admin
      .firestore()
      .collection("bids")
      .doc(doc.id)
      .collection("offers")
      .get();

    const hasLiveOffer = offersSnap.docs.some((d) => {
      const v = d.data();
      if (v.status !== "pending") return false;
      const expMs =
        (v.expiresAt as admin.firestore.Timestamp | undefined)?.toDate()?.getTime() ?? 0;
      return expMs > nowMs;
    });

    if (!hasLiveOffer) {
      await doc.ref.update({
        status: "requested",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  }

  const enRouteSnap = await ridesCol
    .where("status", "==", "driverEnRoute")
    .orderBy("updatedAt", "asc")
    .limit(50)
    .get();

  for (const doc of enRouteSnap.docs) {
    const ride = doc.data();
    const updatedAtMs =
      (ride.updatedAt as admin.firestore.Timestamp | undefined)?.toDate()?.getTime() ?? 0;
    if (updatedAtMs <= 0 || nowMs - updatedAtMs < enRouteTimeoutMs) continue;

    const rideId = doc.id;
    const driverUid = (ride.driverUid as string | undefined)?.trim();
    if (!driverUid) continue;

    const locSnap = await admin.firestore().collection("driverLocations").doc(rideId).get();
    const loc = locSnap.data();
    const locUpdatedAtMs =
      (loc?.updatedAt as admin.firestore.Timestamp | undefined)?.toDate()?.getTime() ?? 0;

    if (locUpdatedAtMs > 0 && nowMs - locUpdatedAtMs < staleLocationMs) continue;

    await admin.firestore().runTransaction(async (tx) => {
      const rideRef = ridesCol.doc(rideId);
      const fresh = await tx.get(rideRef);
      if (!fresh.exists) return;
      const data = fresh.data()!;
      if (data.status !== "driverEnRoute") return;
      tx.update(rideRef, {
        status: "cancelled",
        cancellationReason: "driver_location_stale",
        cancelledBy: "system",
        cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      tx.set(
        driverPresenceCollection.doc(driverUid),
        {
          availabilityState: "online",
          isAvailableForRequests: true,
          currentRideId: null,
          lastHeartbeatAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    });
  }
  }
);

/**
 * Runs every Thursday at 11:59 PM Nigeria time (UTC+1 = 22:59 UTC).
 * Snapshots all drivers with walletBalance > 0 along with their primary bank
 * account into a new withdrawalSnapshots document.
 */
export const takeWeeklyWalletSnapshot = onSchedule(
  { schedule: "59 22 * * 4", timeZone: "Africa/Lagos", region: REGION_SCHEDULE, maxInstances: 1 },
  async () => {
    const snapshotRef = admin.firestore().collection("withdrawalSnapshots").doc();
    const snapshotId = snapshotRef.id;

    // Get all drivers with a positive wallet balance
    const driversSnap = await driversCollection.where("walletBalance", ">", 0).get();
    if (driversSnap.empty) {
      logger.info("Weekly snapshot: no drivers with positive balance.");
      await snapshotRef.set({
        snapshotAt: admin.firestore.FieldValue.serverTimestamp(),
        totalDrivers: 0,
        totalAmount: 0,
        status: "completed",
      });
      return;
    }

    // Create metadata doc
    await snapshotRef.set({
      snapshotAt: admin.firestore.FieldValue.serverTimestamp(),
      totalDrivers: driversSnap.size,
      totalAmount: driversSnap.docs.reduce((sum, d) => sum + ((d.data().walletBalance as number) ?? 0), 0),
      status: "pending",
    });

    // Batch-write individual driver entries into the subcollection
    const entriesCol = snapshotRef.collection("entries");
    const chunks: typeof driversSnap.docs[] = [];
    for (let i = 0; i < driversSnap.docs.length; i += 400) {
      chunks.push(driversSnap.docs.slice(i, i + 400));
    }

    for (const chunk of chunks) {
      const batch = admin.firestore().batch();
      await Promise.all(chunk.map(async (driverDoc) => {
        const d = driverDoc.data();
        const uid = driverDoc.id;
        // Fetch primary bank account
        const bankSnap = await driversCollection.doc(uid).collection("bankAccounts")
          .where("isDefault", "==", true).limit(1).get();
        const bank = bankSnap.empty ? null : bankSnap.docs[0].data();
        batch.set(entriesCol.doc(uid), {
          driverUid: uid,
          fullName: (d.fullName as string) ?? "",
          email: (d.email as string) ?? "",
          phone: (d.phone as string) ?? "",
          profilePhotoUrl: (d.profilePhotoUrl as string) ?? "",
          tier: (d.tier as string) ?? "bronze",
          walletBalance: (d.walletBalance as number) ?? 0,
          bankAccount: bank ? {
            bankName: bank.bankName ?? "",
            accountName: bank.accountName ?? "",
            accountNumber: bank.accountNumber ?? "",
            maskedAccountNumber: bank.maskedAccountNumber ?? "",
            bankCode: bank.bankCode ?? "",
            recipientCode: bank.recipientCode ?? "",
          } : null,
          paid: false,
          snapshotAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }));
      await batch.commit();
    }

    await snapshotRef.update({ status: "completed" });
    logger.info("Weekly wallet snapshot completed", { snapshotId, driverCount: driversSnap.size });
  }
);

export const onChatMessageCreated = onDocumentCreated(
  { document: "rideMessages/{rideId}/messages/{messageId}", region: "us-east1" },
  async (event) => {
    const msg = event.data?.data() as Record<string, unknown> | undefined;
    if (!msg) return;
    const senderUid = msg.senderUid as string | undefined;
    const text = msg.text as string | undefined;
    const rideId = event.params.rideId as string;

    if (!senderUid || !text) return;

    const threadSnap = await admin.firestore().collection("rideMessages").doc(rideId).get();
    if (!threadSnap.exists) return;
    const threadData = threadSnap.data();
    if (!threadData) return;

    const participantUids = threadData.participantUids as string[] | undefined;
    if (!participantUids || participantUids.length === 0) return;

    const recipientUid = participantUids.find((uid) => uid !== senderUid);
    if (!recipientUid) return;

    const customerDoc = await customersCollection.doc(recipientUid).get();
    if (customerDoc.exists) {
      const senderName = threadData.peerName ?? "Driver";
      await sendPushToCustomer(
        recipientUid,
        senderName,
        text,
        { type: "chat_message", rideId, senderUid }
      );
    } else {
      const senderSnap = await customersCollection.doc(senderUid).get();
      const senderName = senderSnap.data()?.fullName ?? "Customer";
      await sendPushToDriver(
        recipientUid,
        senderName,
        text,
        { type: "chat_message", rideId, senderUid }
      );
    }
  }
);

export const sendAnnouncementPush = onCall({ region: REGION_PRIMARY, maxInstances: 5 }, async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const adminDoc = await admin.firestore().collection("admins").doc(auth.uid).get();
  if (!adminDoc.exists) {
    throw new HttpsError("permission-denied", "Only administrators can send push announcements.");
  }

  const { target, audience, uids, title, body, imageUrl } = request.data as {
    target: "customers" | "drivers";
    audience: "all" | "specific";
    uids: string[];
    title: string;
    body: string;
    imageUrl?: string;
  };

  if (!title || !body) {
    throw new HttpsError("invalid-argument", "Title and body are required.");
  }

  const targetCollection = target === "customers" ? customersCollection : driversCollection;
  let targetUids: string[] = [];

  if (audience === "all") {
    const allDocs = await targetCollection.select().get();
    targetUids = allDocs.docs.map(doc => doc.id);
  } else {
    targetUids = uids || [];
  }

  if (targetUids.length === 0) {
    return { success: true, count: 0 };
  }

  const sendPromises = targetUids.map(async (uid) => {
    if (target === "customers") {
      return sendPushToCustomer(uid, title, body, imageUrl ? { imageUrl } : undefined);
    } else {
      return sendPushToDriver(uid, title, body, imageUrl ? { imageUrl } : undefined);
    }
  });

  await Promise.all(sendPromises);
  return { success: true, count: targetUids.length };
});

export const sendAnnouncementEmail = onCall({ region: REGION_PRIMARY, maxInstances: 5 }, async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const adminDoc = await admin.firestore().collection("admins").doc(auth.uid).get();
  if (!adminDoc.exists) {
    throw new HttpsError("permission-denied", "Only administrators can send email announcements.");
  }

  const { target, audience, uids, subject, htmlBody } = request.data as {
    target: "customers" | "drivers";
    audience: "all" | "specific";
    uids: string[];
    subject: string;
    htmlBody: string;
  };

  if (!subject || !htmlBody) {
    throw new HttpsError("invalid-argument", "Subject and htmlBody are required.");
  }

  const targetCollection = target === "customers" ? customersCollection : driversCollection;
  let targetUsers: { email: string }[] = [];

  if (audience === "all") {
    const allDocs = await targetCollection.get();
    targetUsers = allDocs.docs
      .map(doc => ({ email: doc.data().email as string | undefined }))
      .filter((u): u is { email: string } => typeof u.email === "string" && u.email.includes("@"));
  } else {
    const userDocs = await Promise.all((uids || []).map(uid => targetCollection.doc(uid).get()));
    targetUsers = userDocs
      .map(doc => ({ email: doc.data()?.email as string | undefined }))
      .filter((u): u is { email: string } => typeof u.email === "string" && u.email.includes("@"));
  }

  if (targetUsers.length === 0) {
    return { success: true, count: 0 };
  }

  const sendPromises = targetUsers.map(async (user) => {
    return sendResendEmail(user.email, subject, htmlBody);
  });

  await Promise.all(sendPromises);
  return { success: true, count: targetUsers.length };
});

// ─────────────────────────── Customer Security PIN Functions ───────────────────────────

export const createCustomerSecurityPin = onCall({ region: REGION_PRIMARY, maxInstances: 5 }, async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const { pin } = request.data as { pin?: string };
  if (!pin || pin.length !== 4 || !/^\d{4}$/.test(pin)) {
    throw new HttpsError("invalid-argument", "PIN must be a 4-digit numeric string.");
  }

  const customerRef = customersCollection.doc(auth.uid);
  const customerSnap = await customerRef.get();
  if (!customerSnap.exists) {
    throw new HttpsError("not-found", "Customer not found.");
  }

  const hashed = hashCode(pin);
  await customerRef.update({
    securityPinHash: hashed,
    hasPinSet: true,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true };
});

export const changeCustomerSecurityPin = onCall({ region: REGION_PRIMARY, maxInstances: 5 }, async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const { oldPin, newPin } = request.data as { oldPin?: string; newPin?: string };
  if (!oldPin || !newPin || newPin.length !== 4 || !/^\d{4}$/.test(newPin)) {
    throw new HttpsError("invalid-argument", "New PIN must be a 4-digit numeric string.");
  }

  const customerRef = customersCollection.doc(auth.uid);
  const customerSnap = await customerRef.get();
  if (!customerSnap.exists) {
    throw new HttpsError("not-found", "Customer not found.");
  }
  const data = customerSnap.data()!;
  const currentHash = data.securityPinHash as string | undefined;
  if (!currentHash || currentHash !== hashCode(oldPin)) {
    throw new HttpsError("permission-denied", "Incorrect old security PIN.");
  }

  const hashed = hashCode(newPin);
  await customerRef.update({
    securityPinHash: hashed,
    hasPinSet: true,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true };
});

export const sendCustomerPinResetOtp = onCall({ region: REGION_PRIMARY, maxInstances: 5 }, async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const customerRef = customersCollection.doc(auth.uid);
  const customerSnap = await customerRef.get();
  if (!customerSnap.exists) {
    throw new HttpsError("not-found", "Customer not found.");
  }
  const email = customerSnap.data()!.email as string | undefined;
  if (!email) {
    throw new HttpsError("failed-precondition", "Customer profile has no email address.");
  }

  const otp = generateOtpCode();
  const challengeId = crypto.randomUUID();
  const expiresAt = new Date(Date.now() + OTP_TTL_MINUTES * 60 * 1000);

  await challengeCollection.doc(challengeId).set({
    uid: auth.uid,
    email: email.toLowerCase(),
    codeHash: hashCode(otp),
    expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    attempts: 0,
    role: "customer",
    type: "pin_reset",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await sendOtpEmail(email, otp);

  return { success: true, challengeId };
});

export const resetCustomerSecurityPin = onCall({ region: REGION_PRIMARY, maxInstances: 5 }, async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const { otp, newPin } = request.data as { otp?: string; newPin?: string };
  if (!otp || !newPin || newPin.length !== 4 || !/^\d{4}$/.test(newPin)) {
    throw new HttpsError("invalid-argument", "New PIN must be a 4-digit numeric string.");
  }

  // Find the latest valid challenge for this user
  const challengeSnap = await challengeCollection
    .where("uid", "==", auth.uid)
    .where("type", "==", "pin_reset")
    .orderBy("createdAt", "desc")
    .limit(1)
    .get();

  if (challengeSnap.empty) {
    throw new HttpsError("not-found", "No OTP challenge found for PIN reset.");
  }

  const doc = challengeSnap.docs[0];
  const challenge = doc.data() as {
    codeHash: string;
    expiresAt: admin.firestore.Timestamp;
    attempts: number;
  };

  if (challenge.expiresAt.toDate() < new Date()) {
    throw new HttpsError("failed-precondition", "OTP code has expired.");
  }
  if (challenge.attempts >= MAX_VERIFY_ATTEMPTS) {
    throw new HttpsError("failed-precondition", "Too many failed attempts. Try requesting a new code.");
  }

  if (challenge.codeHash !== hashCode(otp)) {
    await doc.ref.update({ attempts: admin.firestore.FieldValue.increment(1) });
    throw new HttpsError("permission-denied", "Invalid OTP code.");
  }

  const customerRef = customersCollection.doc(auth.uid);
  const hashed = hashCode(newPin);
  await customerRef.update({
    securityPinHash: hashed,
    hasPinSet: true,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await doc.ref.delete();

  return { success: true };
});

export const verifyCustomerSecurityPin = onCall({ region: REGION_PRIMARY, maxInstances: 5 }, async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const { pin } = request.data as { pin?: string };
  if (!pin) {
    throw new HttpsError("invalid-argument", "PIN is required.");
  }

  const customerSnap = await customersCollection.doc(auth.uid).get();
  if (!customerSnap.exists) {
    throw new HttpsError("not-found", "Customer not found.");
  }
  const currentHash = customerSnap.data()!.securityPinHash as string | undefined;
  return { valid: currentHash === hashCode(pin) };
});

// ─────────────────────────── Customer Payout / Withdrawal Functions ───────────────────────────

export const processCustomerWithdrawal = onCall({ region: REGION_PRIMARY, maxInstances: 1 }, async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const { accountNumber, bankCode, bankName, accountName, amountNaira, pin } = request.data as {
    accountNumber?: string;
    bankCode?: string;
    bankName?: string;
    accountName?: string;
    amountNaira?: number;
    pin?: string;
  };

  if (!accountNumber || !bankCode || !bankName || !accountName || !amountNaira || amountNaira <= 0 || !pin) {
    throw new HttpsError("invalid-argument", "Missing or invalid withdrawal details.");
  }

  const customerRef = customersCollection.doc(auth.uid);
  const customerSnap = await customerRef.get();
  if (!customerSnap.exists) {
    throw new HttpsError("not-found", "Customer not found.");
  }

  const customer = customerSnap.data()!;
  const walletBalance = (customer.walletBalance as number) ?? 0;
  const pinHash = customer.securityPinHash as string | undefined;

  if (!pinHash || pinHash !== hashCode(pin)) {
    throw new HttpsError("permission-denied", "Incorrect security PIN.");
  }

  if (walletBalance < amountNaira) {
    throw new HttpsError("failed-precondition", "Insufficient wallet balance.");
  }

  // ── Step 1: Create a Paystack transfer recipient ─────────────────────
  const reference = `WDR-${auth.uid.slice(0, 5)}-${Date.now()}`;

  type PaystackRecipientResponse = {
    status: boolean;
    message: string;
    data?: { recipient_code: string };
  };

  const recipientRes = await paystackRequest<PaystackRecipientResponse>(
    "POST",
    "/transferrecipient",
    {
      type: "nuban",
      name: accountName,
      account_number: accountNumber,
      bank_code: bankCode,
      currency: "NGN",
    }
  );

  if (!recipientRes.status || !recipientRes.data?.recipient_code) {
    logger.error("Paystack create recipient failed", { response: recipientRes });
    throw new HttpsError("internal", `Transfer processing failed: ${recipientRes.message}`);
  }

  const recipientCode = recipientRes.data.recipient_code;

  // ── Step 2: Initiate the Paystack transfer ────────────────────────────
  type PaystackTransferResponse = {
    status: boolean;
    message: string;
    data?: { reference: string; status: string; transfer_code: string };
  };

  const transferRes = await paystackRequest<PaystackTransferResponse>(
    "POST",
    "/transfer",
    {
      source: "balance",
      amount: Math.round(amountNaira * 100), // Paystack uses kobo
      recipient: recipientCode,
      reason: "CaRide Wallet Withdrawal",
      reference,
      currency: "NGN",
    }
  );

  if (!transferRes.status || !transferRes.data) {
    logger.error("Paystack transfer failed", { response: transferRes });
    throw new HttpsError("internal", `Transfer processing failed: ${transferRes.message}`);
  }

  // Deduct from wallet and write transaction record
  await admin.firestore().runTransaction(async (tx) => {
    tx.update(customerRef, {
      walletBalance: admin.firestore.FieldValue.increment(-amountNaira),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const txRef = admin.firestore().collection("walletTransactions").doc();
    tx.set(txRef, {
      uid: auth.uid,
      type: "debit",
      amountNaira,
      method: "bank_transfer",
      reference,
      paystackTransferCode: transferRes.data!.transfer_code,
      description: `Transfer to ${accountName} (${maskAccountNumber(accountNumber)}) • ${bankName}`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  // Try sending receipt email
  if (customer.email) {
    try {
      await sendPayoutEmail(
        customer.email,
        customer.fullName ?? "User",
        amountNaira,
        bankName,
        maskAccountNumber(accountNumber),
        reference,
        walletBalance - amountNaira
      );
    } catch (e) {
      logger.error("Failed to send payout email to customer", { e });
    }
  }

  return { success: true, reference };
});



// Driver Security PIN Functions

export const createDriverSecurityPin = onCall({ region: REGION_PRIMARY, maxInstances: 5 }, async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const { pin } = request.data as { pin?: string };
  if (!pin || pin.length !== 4 || !/^\d{4}$/.test(pin)) {
    throw new HttpsError("invalid-argument", "PIN must be a 4-digit numeric string.");
  }

  const driverRef = driversCollection.doc(auth.uid);
  const driverSnap = await driverRef.get();
  if (!driverSnap.exists) {
    throw new HttpsError("not-found", "Driver not found.");
  }

  const hashed = hashCode(pin);
  await driverRef.update({
    securityPinHash: hashed,
    hasPinSet: true,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true };
});

export const changeDriverSecurityPin = onCall({ region: REGION_PRIMARY, maxInstances: 5 }, async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const { oldPin, newPin } = request.data as { oldPin?: string; newPin?: string };
  if (!oldPin || !newPin || newPin.length !== 4 || !/^\d{4}$/.test(newPin)) {
    throw new HttpsError("invalid-argument", "New PIN must be a 4-digit numeric string.");
  }

  const driverRef = driversCollection.doc(auth.uid);
  const driverSnap = await driverRef.get();
  if (!driverSnap.exists) {
    throw new HttpsError("not-found", "Driver not found.");
  }
  const data = driverSnap.data()!;
  const currentHash = data.securityPinHash as string | undefined;
  if (!currentHash || currentHash !== hashCode(oldPin)) {
    throw new HttpsError("permission-denied", "Incorrect old security PIN.");
  }

  const hashed = hashCode(newPin);
  await driverRef.update({
    securityPinHash: hashed,
    hasPinSet: true,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  return { success: true };
});

export const sendDriverPinResetOtp = onCall({ region: REGION_PRIMARY, maxInstances: 5 }, async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const driverRef = driversCollection.doc(auth.uid);
  const driverSnap = await driverRef.get();
  if (!driverSnap.exists) {
    throw new HttpsError("not-found", "Driver not found.");
  }
  const email = driverSnap.data()!.email as string | undefined;
  if (!email) {
    throw new HttpsError("failed-precondition", "Driver profile has no email address.");
  }

  const otp = generateOtpCode();
  const challengeId = crypto.randomUUID();
  const expiresAt = new Date(Date.now() + OTP_TTL_MINUTES * 60 * 1000);

  await challengeCollection.doc(challengeId).set({
    uid: auth.uid,
    email: email.toLowerCase(),
    codeHash: hashCode(otp),
    expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    attempts: 0,
    role: "driver",
    type: "pin_reset",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await sendOtpEmail(email, otp);

  return { success: true, challengeId };
});

export const resetDriverSecurityPin = onCall({ region: REGION_PRIMARY, maxInstances: 5 }, async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const { otp, newPin } = request.data as { otp?: string; newPin?: string };
  if (!otp || !newPin || newPin.length !== 4 || !/^\d{4}$/.test(newPin)) {
    throw new HttpsError("invalid-argument", "New PIN must be a 4-digit numeric string.");
  }

  // Find the latest valid challenge for this user
  const challengeSnap = await challengeCollection
    .where("uid", "==", auth.uid)
    .where("type", "==", "pin_reset")
    .orderBy("createdAt", "desc")
    .limit(1)
    .get();

  if (challengeSnap.empty) {
    throw new HttpsError("not-found", "No OTP challenge found for PIN reset.");
  }

  const doc = challengeSnap.docs[0];
  const challenge = doc.data() as {
    codeHash: string;
    expiresAt: admin.firestore.Timestamp;
    attempts: number;
  };

  if (challenge.expiresAt.toDate() < new Date()) {
    throw new HttpsError("failed-precondition", "OTP code has expired.");
  }
  if (challenge.attempts >= MAX_VERIFY_ATTEMPTS) {
    throw new HttpsError("failed-precondition", "Too many failed attempts. Try requesting a new code.");
  }

  if (challenge.codeHash !== hashCode(otp)) {
    await doc.ref.update({ attempts: admin.firestore.FieldValue.increment(1) });
    throw new HttpsError("permission-denied", "Invalid OTP code.");
  }

  const driverRef = driversCollection.doc(auth.uid);
  const hashed = hashCode(newPin);
  await driverRef.update({
    securityPinHash: hashed,
    hasPinSet: true,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  await doc.ref.delete();

  return { success: true };
});

export const verifyDriverSecurityPin = onCall({ region: REGION_PRIMARY, maxInstances: 5 }, async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const { pin } = request.data as { pin?: string };
  if (!pin) {
    throw new HttpsError("invalid-argument", "PIN is required.");
  }

  const driverSnap = await driversCollection.doc(auth.uid).get();
  if (!driverSnap.exists) {
    throw new HttpsError("not-found", "Driver not found.");
  }
  const currentHash = driverSnap.data()!.securityPinHash as string | undefined;
  return { valid: currentHash === hashCode(pin) };
});

// ─────────────────────────── Driver Payout / Withdrawal Functions ───────────────────────────


// Driver Withdrawal Functions

export const processDriverWithdrawal = onCall({ region: REGION_PRIMARY, maxInstances: 1 }, async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const { accountNumber, bankCode, bankName, accountName, amountNaira, pin } = request.data as {
    accountNumber?: string;
    bankCode?: string;
    bankName?: string;
    accountName?: string;
    amountNaira?: number;
    pin?: string;
  };

  if (!accountNumber || !bankCode || !bankName || !accountName || !amountNaira || amountNaira <= 0 || !pin) {
    throw new HttpsError("invalid-argument", "Missing or invalid withdrawal details.");
  }

  const driverRef = driversCollection.doc(auth.uid);
  const driverSnap = await driverRef.get();
  if (!driverSnap.exists) {
    throw new HttpsError("not-found", "Driver not found.");
  }

  const driver = driverSnap.data()!;
  const walletBalance = (driver.walletBalance as number) ?? 0;
  const pinHash = driver.securityPinHash as string | undefined;

  if (!pinHash || pinHash !== hashCode(pin)) {
    throw new HttpsError("permission-denied", "Incorrect security PIN.");
  }

  if (walletBalance < amountNaira) {
    throw new HttpsError("failed-precondition", "Insufficient wallet balance.");
  }

  // ── Step 1: Create a Paystack transfer recipient ─────────────────────
  const reference = `WDR-${auth.uid.slice(0, 5)}-${Date.now()}`;

  type PaystackRecipientResponse = {
    status: boolean;
    message: string;
    data?: { recipient_code: string };
  };

  const recipientRes = await paystackRequest<PaystackRecipientResponse>(
    "POST",
    "/transferrecipient",
    {
      type: "nuban",
      name: accountName,
      account_number: accountNumber,
      bank_code: bankCode,
      currency: "NGN",
    }
  );

  if (!recipientRes.status || !recipientRes.data?.recipient_code) {
    logger.error("Paystack create recipient failed", { response: recipientRes });
    throw new HttpsError("internal", `Transfer processing failed: ${recipientRes.message}`);
  }

  const recipientCode = recipientRes.data.recipient_code;

  // ── Step 2: Initiate the Paystack transfer ────────────────────────────
  type PaystackTransferResponse = {
    status: boolean;
    message: string;
    data?: { reference: string; status: string; transfer_code: string };
  };

  const transferRes = await paystackRequest<PaystackTransferResponse>(
    "POST",
    "/transfer",
    {
      source: "balance",
      amount: Math.round(amountNaira * 100), // Paystack uses kobo
      recipient: recipientCode,
      reason: "CaRide Wallet Withdrawal",
      reference,
      currency: "NGN",
    }
  );

  if (!transferRes.status || !transferRes.data) {
    logger.error("Paystack transfer failed", { response: transferRes });
    throw new HttpsError("internal", `Transfer processing failed: ${transferRes.message}`);
  }

  // Deduct from wallet and write transaction record
  await admin.firestore().runTransaction(async (tx) => {
    tx.update(driverRef, {
      walletBalance: admin.firestore.FieldValue.increment(-amountNaira),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    const txRef = admin.firestore().collection("walletTransactions").doc();
    tx.set(txRef, {
      uid: auth.uid,
      type: "debit",
      amountNaira,
      method: "bank_transfer",
      reference,
      paystackTransferCode: transferRes.data!.transfer_code,
      description: `Transfer to ${accountName} (${maskAccountNumber(accountNumber)}) • ${bankName}`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  // Try sending receipt email
  if (driver.email) {
    try {
      await sendPayoutEmail(
        driver.email,
        driver.fullName ?? "User",
        amountNaira,
        bankName,
        maskAccountNumber(accountNumber),
        reference,
        walletBalance - amountNaira
      );
    } catch (e) {
      logger.error("Failed to send payout email to driver", { e });
    }
  }

  return { success: true, reference };
});



export const resolveFlutterwaveBankAccount = onCall({ region: REGION_PRIMARY, maxInstances: 5 }, async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }
  const { bankCode, accountNumber } = request.data as { bankCode?: string; accountNumber?: string };
  if (!bankCode || !accountNumber) {
    throw new HttpsError("invalid-argument", "Missing bankCode or accountNumber.");
  }

  try {
    const response = await flutterwaveRequest<{ status: string; message: string; data?: { account_name: string; account_number: string } }>(
      "POST",
      "/accounts/resolve",
      {
        account_number: accountNumber,
        account_bank: bankCode,
      }
    );
    if (response.status === "success" && response.data) {
      return {
        accountName: response.data.account_name,
        accountNumber: response.data.account_number,
      };
    }
    throw new HttpsError("failed-precondition", response.message || "Failed to resolve account.");
  } catch (e) {
    throw new HttpsError("internal", `Flutterwave resolution failed: ${e}`);
  }
});

// ─────────────────────────── Referral System ───────────────────────────

async function processReferralAttribution(
  newUserId: string,
  newUserEmail: string,
  userRole: "customer" | "driver",
  referredByCode: string
): Promise<{ success: boolean; message: string }> {
  if (!referredByCode || !referredByCode.trim()) {
    return { success: false, message: "No referral code provided." };
  }

  const cleanCode = referredByCode.trim().toUpperCase();
  const db = admin.firestore();

  // 1. Check if user has already been attributed to a referrer
  const userDocRef = db.collection(userRole === "customer" ? "customers" : "drivers").doc(newUserId);
  const userSnap = await userDocRef.get();
  const userData = userSnap.data() || {};

  if (userData.referredByUid) {
    return { success: false, message: "User already has a registered referrer." };
  }

  // 2. Find the referrer by code in customers or drivers collection
  let referrerUid: string | null = null;
  let referrerRole: "customer" | "driver" = "customer";

  const custQuery = await db.collection("customers").where("referralCode", "==", cleanCode).limit(1).get();
  if (!custQuery.empty) {
    referrerUid = custQuery.docs[0].id;
    referrerRole = "customer";
  } else {
    const driverQuery = await db.collection("drivers").where("referralCode", "==", cleanCode).limit(1).get();
    if (!driverQuery.empty) {
      referrerUid = driverQuery.docs[0].id;
      referrerRole = "driver";
    }
  }

  if (!referrerUid) {
    logger.warn(`Referral processing: invalid code ${cleanCode} for user ${newUserId}`);
    return { success: false, message: "Invalid referral code." };
  }

  // 3. Security: Prevent self-referrals
  if (referrerUid === newUserId) {
    logger.warn(`Referral processing: self-referral attempt by ${newUserId}`);
    return { success: false, message: "Self-referral is not allowed." };
  }

  // 4. Fetch reward configuration (default 500 NGN or 2% bonus)
  let rewardAmount = 500.0;
  try {
    const settingsSnap = await db.collection("config").doc("referralSettings").get();
    if (settingsSnap.exists) {
      const data = settingsSnap.data();
      rewardAmount = Number(data?.defaultBonusNaira ?? 500.0);
    }
  } catch (e) {
    logger.error("Error reading referralSettings config", { e });
  }

  const referrerRef = db.collection(referrerRole === "customer" ? "customers" : "drivers").doc(referrerUid);

  // 5. Execute atomic transaction to record referral and update referrer statistics
  await db.runTransaction(async (tx) => {
    const freshUserSnap = await tx.get(userDocRef);
    if (freshUserSnap.data()?.referredByUid) {
      throw new Error("Already processed referral for this user.");
    }

    tx.set(
      userDocRef,
      {
        referredByCode: cleanCode,
        referredByUid: referrerUid,
        referredByRole: referrerRole,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    tx.set(
      referrerRef,
      {
        referralEarnings: admin.firestore.FieldValue.increment(rewardAmount),
        successfulReferralsCount: admin.firestore.FieldValue.increment(1),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true }
    );

    const referralRecordRef = referrerRef.collection("referrals").doc(newUserId);
    tx.set(referralRecordRef, {
      referredUid: newUserId,
      email: newUserEmail,
      role: userRole,
      status: "completed",
      rewardAmount: rewardAmount,
      joinedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  logger.info(`Referral successfully processed: ${newUserId} referred by ${referrerUid} (${cleanCode})`);
  return { success: true, message: "Referral applied successfully." };
}

export const processCustomerReferralOnCreate = onDocumentCreated(
  { region: REGION_PRIMARY, document: "customers/{customerId}" },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const data = snap.data();
    const customerId = event.params.customerId;
    const referredByCode = data.referredByCode as String | undefined;
    const email = (data.email as String | undefined) || "";

    if (referredByCode && typeof referredByCode === "string") {
      try {
        await processReferralAttribution(customerId, email as string, "customer", referredByCode as string);
      } catch (err) {
        logger.error(`Failed to process customer referral for ${customerId}`, { err });
      }
    }
  }
);

export const processDriverReferralOnCreate = onDocumentCreated(
  { region: REGION_PRIMARY, document: "drivers/{driverId}" },
  async (event) => {
    const snap = event.data;
    if (!snap) return;
    const data = snap.data();
    const driverId = event.params.driverId;
    const referredByCode = data.referredByCode as String | undefined;
    const email = (data.email as String | undefined) || "";

    if (referredByCode && typeof referredByCode === "string") {
      try {
        await processReferralAttribution(driverId, email as string, "driver", referredByCode as string);
      } catch (err) {
        logger.error(`Failed to process driver referral for ${driverId}`, { err });
      }
    }
  }
);

export const processReferralCode = onCall({ region: REGION_PRIMARY }, async (request) => {
  const auth = request.auth;
  if (!auth) {
    throw new HttpsError("unauthenticated", "Authentication required.");
  }

  const { referralCode, role } = request.data as { referralCode?: string; role?: "customer" | "driver" };
  if (!referralCode) {
    throw new HttpsError("invalid-argument", "Missing referralCode.");
  }

  const userRole = role === "driver" ? "driver" : "customer";
  const email = auth.token.email || "";

  try {
    const result = await processReferralAttribution(auth.uid, email, userRole, referralCode);
    if (!result.success) {
      throw new HttpsError("failed-precondition", result.message);
    }
    return result;
  } catch (e: any) {
    if (e instanceof HttpsError) throw e;
    throw new HttpsError("internal", `Referral processing error: ${e.message || e}`);
  }
});


// ─────────────────────────── Emergency Alert ────────────────────

type SendEmergencyAlertPayload = {
  rideId?: string;
  trustedContactEmail?: string;
  trustedContactName?: string;
  shareCode?: string;
};

/**
 * Callable function that sends an emergency safety alert email to a trusted contact.
 * Called by the passenger app when the user confirms an emergency during an active ride.
 */
export const sendEmergencyAlert = onCall({ region: REGION_PRIMARY, maxInstances: 5 }, async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Must be signed in.");
  }
  const uid = request.auth.uid;
  const payload = request.data as SendEmergencyAlertPayload;

  const { rideId, trustedContactEmail, trustedContactName, shareCode } = payload;

  if (!trustedContactEmail) {
    throw new HttpsError("invalid-argument", "Trusted contact email is required.");
  }
  if (!isValidEmail(trustedContactEmail)) {
    throw new HttpsError("invalid-argument", "Invalid trusted contact email address.");
  }

  // Fetch passenger info
  const customerDoc = await customersCollection.doc(uid).get();
  if (!customerDoc.exists) {
    throw new HttpsError("not-found", "Customer not found.");
  }
  const customerData = customerDoc.data()!;
  const passengerName: string = (customerData.fullName as string) || "A CaRide Passenger";
  const passengerPhone: string = (customerData.phone as string) || "";

  // Fetch ride info
  let driverName = "";
  let pickupLabel = "";
  let dropoffLabel = "";
  let rideType = "";
  let plateNumber = "";
  let driverPhone = "";

  if (rideId) {
    try {
      const rideDoc = await admin.firestore().collection("rides").doc(rideId).get();
      if (rideDoc.exists) {
        const ride = rideDoc.data()!;
        driverName = (ride.driverName as string) || "";
        pickupLabel = (ride.pickupLabel as string) || "";
        dropoffLabel = (ride.dropoffLabel as string) || "";
        rideType = (ride.rideType as string) || "";

        const driverUid = ride.driverUid as string | undefined;
        if (driverUid) {
          try {
            const driverDoc = await admin.firestore().collection("drivers").doc(driverUid).get();
            driverPhone = (driverDoc.data()?.phone as string) || "";
            // Try to get plate from vehicle info
            const vehicleDoc = await admin.firestore().collection("drivers").doc(driverUid).collection("vehicle").doc("info").get();
            plateNumber = (vehicleDoc.data()?.plateNumber as string) || "";
          } catch (_) { /* non-critical, continue */ }
        }
      }
    } catch (e) {
      logger.warn("Failed to fetch ride for emergency alert", { rideId, e: String(e) });
    }
  }

  // Write emergency event record
  const eventRef = admin.firestore().collection("emergencyEvents").doc();
  await eventRef.set({
    customerUid: uid,
    rideId: rideId ?? null,
    trustedContactEmail,
    trustedContactName: trustedContactName ?? null,
    shareCode: shareCode ?? null,
    triggeredAt: admin.firestore.FieldValue.serverTimestamp(),
    status: "sent",
  });

  // Build the emergency email
  const contactName = trustedContactName || "Friend";
  const tripLink = shareCode ? `https://caride.ng/app/trip/${shareCode}` : null;
  const tripLinkLine = tripLink
    ? `<p style="margin:0 0 14px;"><a href="${tripLink}" style="color:#dc2626;font-weight:700;">View live trip</a> (open CaRide app and enter code: <strong>${shareCode}</strong>)</p>`
    : "";
  const driverLine = driverName ? `<p style="margin:0 0 10px;color:#111827;"><strong>Driver:</strong> ${driverName}${plateNumber ? ` — ${plateNumber}` : ""}</p>` : "";
  const driverPhoneLine = driverPhone ? `<p style="margin:0 0 10px;color:#111827;"><strong>Driver phone:</strong> ${driverPhone}</p>` : "";
  const pickupLine = pickupLabel ? `<p style="margin:0 0 10px;color:#111827;"><strong>From:</strong> ${pickupLabel}</p>` : "";
  const dropoffLine = dropoffLabel ? `<p style="margin:0;color:#111827;"><strong>To:</strong> ${dropoffLabel}</p>` : "";
  const passengerPhoneLine = passengerPhone ? `<p style="margin:0 0 10px;color:#111827;"><strong>Passenger phone:</strong> ${passengerPhone}</p>` : "";

  const html = buildEmailHtml(
    `<h2 style="margin:0 0 10px;color:#dc2626;font-size:24px;">&#x1F6A8; Emergency Safety Alert</h2>` +
    `<p style="margin:0 0 18px;color:#374151;">Hi <strong>${contactName}</strong>,</p>` +
    `<p style="margin:0 0 18px;color:#374151;"><strong>${passengerName}</strong> has triggered a safety alert during their CaRide trip. Please check in on them immediately.</p>` +
    `<div style="background:#fef2f2;border:2px solid #dc2626;border-radius:12px;padding:20px;margin:0 0 20px;">` +
    `<p style="margin:0 0 10px;font-weight:700;color:#dc2626;">&#x26A0;&#xFE0F; Passenger Details</p>` +
    `<p style="margin:0 0 10px;color:#111827;"><strong>Name:</strong> ${passengerName}</p>` +
    passengerPhoneLine +
    `</div>` +
    (driverName || pickupLabel || dropoffLabel
      ? `<div style="background:#f8faf8;border:1px solid #e5e7eb;border-radius:12px;padding:20px;margin:0 0 20px;">` +
        `<p style="margin:0 0 10px;font-weight:700;color:#374151;">Trip Information</p>` +
        driverLine + driverPhoneLine + pickupLine + dropoffLine +
        `</div>`
      : "") +
    tripLinkLine +
    `<p style="margin:0 0 14px;color:#374151;">If you cannot reach them, please contact local emergency services immediately.</p>` +
    `<p style="margin:0;color:#9ca3af;font-size:12px;">This alert was sent automatically from CaRide at ${new Date().toUTCString()}.${rideId ? ` Ride ID: ${rideId}` : ""}</p>`
  );

  await sendResendEmail(
    trustedContactEmail,
    `&#x1F6A8; Safety Alert: ${passengerName} needs a check-in`,
    html
  );

  logger.info("Emergency alert sent", { uid, rideId, trustedContactEmail, eventId: eventRef.id });
  return { success: true, eventId: eventRef.id };
});



