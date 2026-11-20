import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import { onDocumentCreated, onDocumentUpdated } from "firebase-functions/v2/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";
import { distanceBetween, geohashForLocation, geohashQueryBounds } from "geofire-common";

const REGION_PRIMARY = "us-east1";
const REGION_SCHEDULE = "us-west1";

export interface DispatchSettings {
  tiersKm: number[];
  tiersByRideType: Record<string, number[]>;
  minDriversForTier: number;
  maxDriversPerTier: number[];
  rideExpirySeconds: number;
  alertTtlSeconds: number;
  maxHeartbeatAgeMinutes: number;
}

export const DEFAULT_DISPATCH_SETTINGS: DispatchSettings = {
  tiersKm: [4, 7, 10],
  tiersByRideType: {
    regular: [4, 7, 10],
    comfort: [4, 7, 10],
    luxury: [5, 9, 15],
    courier: [5, 9, 15],
  },
  minDriversForTier: 5,
  maxDriversPerTier: [15, 15, 20],
  rideExpirySeconds: 180,
  alertTtlSeconds: 45,
  maxHeartbeatAgeMinutes: 15,
};

export interface EligibleDriverCandidate {
  driverUid: string;
  distanceKm: number;
  presenceData: Record<string, unknown>;
  driverData: Record<string, unknown>;
}

export interface AdaptiveTierSelectionResult {
  selected: EligibleDriverCandidate[];
  tierIndex: number;
  appliedRadiusKm: number;
}

export interface ResolvedTokenTarget {
  uid: string;
  token: string;
  platform: "android" | "ios";
  source: "device" | "driver" | "presence";
  deviceId?: string;
}

function getDb(): admin.firestore.Firestore {
  return admin.firestore();
}

function getMessaging(): admin.messaging.Messaging {
  return admin.messaging();
}

export function normalizeRideType(value: unknown): string {
  return typeof value === "string" ? value.trim().toLowerCase() : "";
}

export function normalizePlatform(value: unknown): "android" | "ios" {
  return typeof value === "string" && value.trim().toLowerCase() === "ios"
    ? "ios"
    : "android";
}

export function resolveDispatchTiersKm(
  rideType: unknown,
  settings: DispatchSettings = DEFAULT_DISPATCH_SETTINGS
): number[] {
  const normalized = normalizeRideType(rideType);
  const override = settings.tiersByRideType[normalized];
  if (Array.isArray(override) && override.length > 0) {
    return override
      .map((n) => Number(n))
      .filter((n) => Number.isFinite(n) && n > 0)
      .sort((a, b) => a - b);
  }
  const fallback = settings.tiersKm
    .map((n) => Number(n))
    .filter((n) => Number.isFinite(n) && n > 0)
    .sort((a, b) => a - b);
  return fallback.length > 0 ? fallback : [4, 7, 10];
}

/**
 * Pure density-adaptive tiered driver selection.
 * Candidates must already be filtered for eligibility and within max(tiersKm),
 * and may be unsorted (sorted ascending by distanceKm internally).
 */
export function selectDriversByAdaptiveTiers(
  candidates: EligibleDriverCandidate[],
  tiersKm: number[],
  minDriversForTier: number,
  maxDriversPerTier: number[]
): AdaptiveTierSelectionResult {
  const sorted = [...candidates].sort((a, b) => a.distanceKm - b.distanceKm);
  const safeTiers = tiersKm.length > 0 ? tiersKm : [4, 7, 10];

  for (let i = 0; i < safeTiers.length; i++) {
    const radiusKm = safeTiers[i];
    const withinTier = sorted.filter((c) => c.distanceKm <= radiusKm);
    const isLastTier = i === safeTiers.length - 1;
    if (withinTier.length >= minDriversForTier || isLastTier) {
      const cap =
        maxDriversPerTier[i] ??
        maxDriversPerTier[maxDriversPerTier.length - 1] ??
        20;
      return {
        selected: withinTier.slice(0, cap),
        tierIndex: i,
        appliedRadiusKm: radiusKm,
      };
    }
  }

  return {
    selected: [],
    tierIndex: safeTiers.length - 1,
    appliedRadiusKm: safeTiers[safeTiers.length - 1],
  };
}

function parseTimestampMillis(value: unknown): number | null {
  if (!value) return null;
  if (value instanceof admin.firestore.Timestamp) {
    return value.toMillis();
  }
  if (typeof (value as { toMillis?: () => number }).toMillis === "function") {
    return (value as { toMillis: () => number }).toMillis();
  }
  if (typeof (value as { toDate?: () => Date }).toDate === "function") {
    return (value as { toDate: () => Date }).toDate().getTime();
  }
  return null;
}

function parseGeoPoint(value: unknown): { lat: number; lng: number } | null {
  if (!value || typeof value !== "object") return null;
  const gp = value as { latitude?: unknown; longitude?: unknown };
  if (typeof gp.latitude === "number" && typeof gp.longitude === "number") {
    if (Number.isFinite(gp.latitude) && Number.isFinite(gp.longitude)) {
      return { lat: gp.latitude, lng: gp.longitude };
    }
  }
  return null;
}

function formatNairaWhole(amount: number): string {
  const rounded = Math.round(Number.isFinite(amount) ? amount : 0);
  return rounded.toLocaleString("en-US");
}

function isInvalidTokenErrorCode(code?: string): boolean {
  return (
    code === "messaging/registration-token-not-registered" ||
    code === "messaging/invalid-registration-token"
  );
}

export async function pruneStaleTokens(
  targets: ResolvedTokenTarget[],
  responses: admin.messaging.SendResponse[]
): Promise<void> {
  const db = getDb();
  const cleanupOps: Promise<unknown>[] = [];

  for (let i = 0; i < targets.length && i < responses.length; i++) {
    const resp = responses[i];
    if (resp.success || !isInvalidTokenErrorCode(resp.error?.code)) continue;

    const target = targets[i];
    if (target.source === "device" && target.deviceId) {
      cleanupOps.push(
        db
          .collection("users")
          .doc(target.uid)
          .collection("devices")
          .doc(target.deviceId)
          .delete()
          .catch(() => {})
      );
    }

    cleanupOps.push(
      db
        .collection("drivers")
        .doc(target.uid)
        .get()
        .then((snap) => {
          if (snap.exists && snap.data()?.fcmToken === target.token) {
            return snap.ref.update({
              fcmToken: admin.firestore.FieldValue.delete(),
            });
          }
          return null;
        })
        .catch(() => {})
    );

    cleanupOps.push(
      db
        .collection("driverPresence")
        .doc(target.uid)
        .get()
        .then((snap) => {
          if (snap.exists && snap.data()?.fcmToken === target.token) {
            return snap.ref.update({
              fcmToken: admin.firestore.FieldValue.delete(),
            });
          }
          return null;
        })
        .catch(() => {})
    );
  }

  if (cleanupOps.length > 0) {
    await Promise.all(cleanupOps);
    logger.info("Pruned stale FCM token references", { count: cleanupOps.length });
  }
}

export async function resolveDriverTokens(
  driverUid: string,
  presenceData?: Record<string, unknown>,
  driverData?: Record<string, unknown>
): Promise<ResolvedTokenTarget[]> {
  const db = getDb();
  const seenTokens = new Set<string>();
  const resolved: ResolvedTokenTarget[] = [];

  try {
    const devicesSnap = await db
      .collection("users")
      .doc(driverUid)
      .collection("devices")
      .limit(5)
      .get();

    for (const dDoc of devicesSnap.docs) {
      const data = dDoc.data();
      const token = typeof data.fcmToken === "string" ? data.fcmToken.trim() : "";
      if (!token || seenTokens.has(token)) continue;
      seenTokens.add(token);
      resolved.push({
        uid: driverUid,
        token,
        platform: normalizePlatform(data.platform),
        source: "device",
        deviceId: dDoc.id,
      });
    }
  } catch (e) {
    logger.warn("Failed reading user devices subcollection", { driverUid, e: String(e) });
  }

  const presenceToken =
    typeof presenceData?.fcmToken === "string" ? presenceData.fcmToken.trim() : "";
  if (presenceToken && !seenTokens.has(presenceToken)) {
    seenTokens.add(presenceToken);
    resolved.push({
      uid: driverUid,
      token: presenceToken,
      platform: normalizePlatform(presenceData?.platform ?? driverData?.platform),
      source: "presence",
    });
  }

  const driverToken =
    typeof driverData?.fcmToken === "string" ? driverData.fcmToken.trim() : "";
  if (driverToken && !seenTokens.has(driverToken)) {
    seenTokens.add(driverToken);
    resolved.push({
      uid: driverUid,
      token: driverToken,
      platform: normalizePlatform(driverData?.platform ?? presenceData?.platform),
      source: "driver",
    });
  }

  return resolved;
}

async function loadDispatchConfig(): Promise<{
  settings: DispatchSettings;
  maxNegativeBalanceNaira: number;
}> {
  const db = getDb();
  const [dispatchSnap, driverSettingsSnap] = await Promise.all([
    db.collection("config").doc("dispatchSettings").get(),
    db.collection("config").doc("driverSettings").get(),
  ]);

  const raw = (dispatchSnap.data() ?? {}) as Record<string, unknown>;
  const tiersByRideType: Record<string, number[]> = {
    ...DEFAULT_DISPATCH_SETTINGS.tiersByRideType,
  };
  if (raw.tiersByRideType && typeof raw.tiersByRideType === "object") {
    for (const [k, v] of Object.entries(raw.tiersByRideType as Record<string, unknown>)) {
      if (Array.isArray(v)) {
        const parsed = v.map((n) => Number(n)).filter((n) => Number.isFinite(n) && n > 0);
        if (parsed.length > 0) {
          tiersByRideType[k.trim().toLowerCase()] = parsed;
        }
      }
    }
  }

  const tiersKm = Array.isArray(raw.tiersKm)
    ? (raw.tiersKm as unknown[])
        .map((n) => Number(n))
        .filter((n) => Number.isFinite(n) && n > 0)
    : DEFAULT_DISPATCH_SETTINGS.tiersKm;

  const maxDriversPerTier = Array.isArray(raw.maxDriversPerTier)
    ? (raw.maxDriversPerTier as unknown[])
        .map((n) => Number(n))
        .filter((n) => Number.isFinite(n) && n > 0)
    : DEFAULT_DISPATCH_SETTINGS.maxDriversPerTier;

  const settings: DispatchSettings = {
    tiersKm: tiersKm.length > 0 ? tiersKm : DEFAULT_DISPATCH_SETTINGS.tiersKm,
    tiersByRideType,
    minDriversForTier:
      typeof raw.minDriversForTier === "number" && raw.minDriversForTier > 0
        ? raw.minDriversForTier
        : DEFAULT_DISPATCH_SETTINGS.minDriversForTier,
    maxDriversPerTier:
      maxDriversPerTier.length > 0
        ? maxDriversPerTier
        : DEFAULT_DISPATCH_SETTINGS.maxDriversPerTier,
    rideExpirySeconds:
      typeof raw.rideExpirySeconds === "number" && raw.rideExpirySeconds >= 30
        ? raw.rideExpirySeconds
        : DEFAULT_DISPATCH_SETTINGS.rideExpirySeconds,
    alertTtlSeconds:
      typeof raw.alertTtlSeconds === "number" && raw.alertTtlSeconds >= 10
        ? raw.alertTtlSeconds
        : DEFAULT_DISPATCH_SETTINGS.alertTtlSeconds,
    maxHeartbeatAgeMinutes:
      typeof raw.maxHeartbeatAgeMinutes === "number" && raw.maxHeartbeatAgeMinutes >= 1
        ? raw.maxHeartbeatAgeMinutes
        : DEFAULT_DISPATCH_SETTINGS.maxHeartbeatAgeMinutes,
  };

  const rawMaxNeg = driverSettingsSnap.data()?.maxNegativeBalanceNaira;
  const maxNegativeBalanceNaira =
    typeof rawMaxNeg === "number" && Number.isFinite(rawMaxNeg) && rawMaxNeg >= 0
      ? rawMaxNeg
      : 3000;

  return { settings, maxNegativeBalanceNaira };
}

async function sendMessagesInChunks(
  items: Array<{ target: ResolvedTokenTarget; message: admin.messaging.Message }>
): Promise<void> {
  if (items.length === 0) return;
  const messaging = getMessaging();
  const chunkSize = 500;

  for (let i = 0; i < items.length; i += chunkSize) {
    const chunk = items.slice(i, i + chunkSize);
    const batchResp = await messaging.sendEach(chunk.map((item) => item.message));
    await pruneStaleTokens(
      chunk.map((item) => item.target),
      batchResp.responses
    );
  }
}

export const onRideCreatedDispatchDrivers = onDocumentCreated(
  { document: "rides/{rideId}", region: REGION_PRIMARY, maxInstances: 10 },
  async (event) => {
    const rideSnap = event.data;
    if (!rideSnap) return;
    const ride = rideSnap.data() as Record<string, unknown> | undefined;
    if (!ride) return;

    if (ride.status !== "requested") return;
    const pickupLat = ride.pickupLat;
    const pickupLng = ride.pickupLng;
    if (
      typeof pickupLat !== "number" ||
      typeof pickupLng !== "number" ||
      !Number.isFinite(pickupLat) ||
      !Number.isFinite(pickupLng)
    ) {
      logger.warn("Ride missing valid pickup coordinates; skipping dispatch", {
        rideId: event.params.rideId,
      });
      return;
    }

    const db = getDb();
    const rideId = event.params.rideId as string;
    const rideRef = rideSnap.ref;
    const { settings, maxNegativeBalanceNaira } = await loadDispatchConfig();

    const nowMs = Date.now();
    const existingExpiresMs = parseTimestampMillis(ride.expiresAt);
    const rideExpiresAtMs =
      existingExpiresMs && existingExpiresMs > nowMs
        ? existingExpiresMs
        : nowMs + settings.rideExpirySeconds * 1000;
    const pickupGeohash = geohashForLocation([pickupLat, pickupLng], 7);

    // Claim idempotent dispatch marker & stamp authoritative expiresAt/geohash
    const shouldDispatch = await db.runTransaction(async (tx) => {
      const fresh = await tx.get(rideRef);
      if (!fresh.exists) return false;
      const freshData = fresh.data() ?? {};
      if (freshData.status !== "requested" || freshData.dispatchStartedAt != null) {
        return false;
      }
      tx.update(rideRef, {
        dispatchStartedAt: admin.firestore.FieldValue.serverTimestamp(),
        ...(freshData.pickupGeohash ? {} : { pickupGeohash }),
        ...(freshData.expiresAt
          ? {}
          : {
              expiresAt: admin.firestore.Timestamp.fromMillis(rideExpiresAtMs),
            }),
      });
      return true;
    });

    if (!shouldDispatch) return;

    const tiersKm = resolveDispatchTiersKm(ride.rideType, settings);
    const maxRadiusKm = tiersKm[tiersKm.length - 1];
    const bounds = geohashQueryBounds([pickupLat, pickupLng], maxRadiusKm * 1000);
    const presenceCol = db.collection("driverPresence");

    const boundQueries = bounds.map((b) =>
      presenceCol
        .where("availabilityState", "==", "online")
        .where("isAvailableForRequests", "==", true)
        .orderBy("geohash")
        .startAt(b[0])
        .endAt(b[1])
        .get()
    );

    // Fallback for drivers running older clients without geohash field
    const legacyFallbackQuery = presenceCol
      .where("availabilityState", "==", "online")
      .where("isAvailableForRequests", "==", true)
      .limit(100)
      .get();

    const querySnaps = await Promise.all([...boundQueries, legacyFallbackQuery]);
    const uniquePresenceDocs = new Map<string, admin.firestore.QueryDocumentSnapshot>();
    for (const qSnap of querySnaps) {
      for (const doc of qSnap.docs) {
        if (!uniquePresenceDocs.has(doc.id)) {
          uniquePresenceDocs.set(doc.id, doc);
        }
      }
    }

    const customerUid = typeof ride.customerUid === "string" ? ride.customerUid : "";
    const normalizedRideType = normalizeRideType(ride.rideType);
    const heartbeatCutoffMs = nowMs - settings.maxHeartbeatAgeMinutes * 60_000;

    interface PreliminaryMatch {
      driverUid: string;
      distanceKm: number;
      presenceData: Record<string, unknown>;
    }

    const preliminary: PreliminaryMatch[] = [];
    for (const [driverUid, pDoc] of uniquePresenceDocs.entries()) {
      if (driverUid === customerUid) continue;
      const pData = pDoc.data() as Record<string, unknown>;
      if (pData.currentRideId) continue;

      const heartbeatMs =
        parseTimestampMillis(pData.lastHeartbeatAt) ?? parseTimestampMillis(pData.updatedAt);
      if (!heartbeatMs || heartbeatMs < heartbeatCutoffMs) continue;

      const driverLoc = parseGeoPoint(pData.lastLocation);
      if (!driverLoc) continue;

      const pVehicleType = normalizeRideType(pData.vehicleType);
      if (pVehicleType && normalizedRideType && pVehicleType !== normalizedRideType) {
        continue;
      }

      const distKm = distanceBetween([pickupLat, pickupLng], [driverLoc.lat, driverLoc.lng]);
      if (!Number.isFinite(distKm) || distKm > maxRadiusKm) continue;

      preliminary.push({ driverUid, distanceKm: distKm, presenceData: pData });
    }

    if (preliminary.length === 0) {
      logger.info("No nearby online drivers found for ride", { rideId, maxRadiusKm });
      return;
    }

    // Batch-fetch drivers/{uid} for authoritative approval & wallet debt validation
    const driverDataMap = new Map<string, Record<string, unknown>>();
    const driverRefs = preliminary.map((m) => db.collection("drivers").doc(m.driverUid));
    for (let i = 0; i < driverRefs.length; i += 100) {
      const snaps = await db.getAll(...driverRefs.slice(i, i + 100));
      for (const snap of snaps) {
        if (snap.exists) {
          driverDataMap.set(snap.id, (snap.data() ?? {}) as Record<string, unknown>);
        }
      }
    }

    // Fallback check for drivers missing presence.vehicleType
    const missingVehicleCheck = preliminary.filter(
      (m) => !normalizeRideType(m.presenceData.vehicleType) && normalizedRideType
    );
    const vehicleTypeMap = new Map<string, string>();
    if (missingVehicleCheck.length > 0) {
      const vRefs = missingVehicleCheck.map((m) =>
        db.collection("drivers").doc(m.driverUid).collection("vehicle").doc("info")
      );
      for (let i = 0; i < vRefs.length; i += 100) {
        const snaps = await db.getAll(...vRefs.slice(i, i + 100));
        for (const snap of snaps) {
          const parentId = snap.ref.parent.parent?.id;
          if (parentId && snap.exists) {
            vehicleTypeMap.set(parentId, normalizeRideType(snap.data()?.vehicleType));
          }
        }
      }
    }

    const eligible: EligibleDriverCandidate[] = [];
    for (const match of preliminary) {
      const dData = driverDataMap.get(match.driverUid);
      if (!dData) continue;
      if (dData.approvalStatus !== "approved") continue;

      const walletBalance = Number(dData.walletBalance) || 0;
      if (walletBalance <= -maxNegativeBalanceNaira) continue;

      const effectiveVehicleType =
        normalizeRideType(match.presenceData.vehicleType) ||
        vehicleTypeMap.get(match.driverUid) ||
        "";
      if (
        normalizedRideType &&
        effectiveVehicleType &&
        effectiveVehicleType !== normalizedRideType
      ) {
        continue;
      }

      eligible.push({
        driverUid: match.driverUid,
        distanceKm: match.distanceKm,
        presenceData: match.presenceData,
        driverData: dData,
      });
    }

    if (eligible.length === 0) {
      logger.info("No eligible drivers passed approval/debt/vehicle checks", { rideId });
      return;
    }

    const selection = selectDriversByAdaptiveTiers(
      eligible,
      tiersKm,
      settings.minDriversForTier,
      settings.maxDriversPerTier
    );

    const pickupLabel = String(ride.pickupLabel ?? ride.pickupName ?? "Pickup").trim();
    const dropoffLabel = String(ride.dropoffLabel ?? ride.dropoffName ?? "Destination").trim();
    const rideTypeDisplay = String(ride.rideType ?? "Regular").trim();
    const customerOffer = Number(ride.customerOffer ?? ride.amountNaira ?? 0) || 0;
    const paymentMethod = String(ride.paymentMethod ?? "cash").trim();
    const paymentLabel = paymentMethod.toLowerCase() === "wallet" ? "Wallet" : "Cash";
    const formattedOffer = formatNairaWhole(customerOffer);
    const apnsExpirySeconds = Math.floor(
      Math.min(rideExpiresAtMs, Date.now() + settings.alertTtlSeconds * 1000) / 1000
    );

    const tokenLists = await Promise.all(
      selection.selected.map(async (candidate) => ({
        candidate,
        targets: await resolveDriverTokens(
          candidate.driverUid,
          candidate.presenceData,
          candidate.driverData
        ),
      }))
    );

    const dispatchBatch = db.batch();
    const messagesToSend: Array<{
      target: ResolvedTokenTarget;
      message: admin.messaging.Message;
    }> = [];

    for (const { candidate, targets } of tokenLists) {
      const dispatchDocRef = rideRef.collection("dispatches").doc(candidate.driverUid);
      dispatchBatch.set(dispatchDocRef, {
        driverUid: candidate.driverUid,
        distanceKm: Number(candidate.distanceKm.toFixed(2)),
        tierIndex: selection.tierIndex,
        appliedRadiusKm: selection.appliedRadiusKm,
        platforms: Array.from(new Set(targets.map((t) => t.platform))),
        tokens: targets.map((t) => t.token),
        status: targets.length > 0 ? "sent" : "no_token",
        dispatchedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      const distText = candidate.distanceKm.toFixed(1);
      const dispatchId = `${rideId}_${candidate.driverUid}`;

      for (const target of targets) {
        const commonData: Record<string, string> = {
          type: "ride_request",
          rideId,
          pickupLabel,
          dropoffLabel,
          rideType: rideTypeDisplay,
          customerOffer: String(Math.round(customerOffer)),
          paymentMethod,
          distanceKm: distText,
          expiresAtMs: String(rideExpiresAtMs),
          dispatchId,
        };

        if (target.platform === "ios") {
          messagesToSend.push({
            target,
            message: {
              token: target.token,
              data: commonData,
              apns: {
                headers: {
                  "apns-push-type": "alert",
                  "apns-priority": "10",
                  "apns-expiration": String(apnsExpirySeconds),
                  "apns-collapse-id": `ride_${rideId}`,
                },
                payload: {
                  aps: {
                    alert: {
                      title: `New ${rideTypeDisplay} Ride • ₦${formattedOffer}`,
                      subtitle: `${distText} km away • ${paymentLabel}`,
                      body: `Pickup: ${pickupLabel} → ${dropoffLabel}`,
                    },
                    sound: "ride_ringtone.wav",
                    badge: 1,
                    category: "INCOMING_RIDE_REQUEST",
                    "interruption-level": "time-sensitive",
                    "relevance-score": 1.0,
                    "thread-id": "caride_ride_requests",
                    "mutable-content": 1,
                  },
                },
              },
            },
          });
        } else {
          // Android: data-only high-priority payload so native CarideFirebaseMessagingService
          // runs in foreground, background, and terminated states with FLAG_INSISTENT.
          messagesToSend.push({
            target,
            message: {
              token: target.token,
              data: commonData,
              android: {
                priority: "high",
                ttl: settings.alertTtlSeconds * 1000,
                collapseKey: `ride_${rideId}`,
              },
            },
          });
        }
      }
    }

    await dispatchBatch.commit();
    await sendMessagesInChunks(messagesToSend);

    logger.info("Dispatched ride alerts to eligible nearby drivers", {
      rideId,
      eligibleCount: eligible.length,
      selectedCount: selection.selected.length,
      tierIndex: selection.tierIndex,
      appliedRadiusKm: selection.appliedRadiusKm,
      pushCount: messagesToSend.length,
    });
  }
);

export const onRideUnavailableCancelAlerts = onDocumentUpdated(
  { document: "rides/{rideId}", region: REGION_PRIMARY, maxInstances: 10 },
  async (event) => {
    const before = event.data?.before.data() as Record<string, unknown> | undefined;
    const after = event.data?.after.data() as Record<string, unknown> | undefined;
    if (!before || !after) return;

    const beforeStatus = String(before.status ?? "");
    const afterStatus = String(after.status ?? "");
    const openStatuses = ["requested", "bidding"];
    if (!openStatuses.includes(beforeStatus) || openStatuses.includes(afterStatus)) {
      return;
    }

    const db = getDb();
    const rideId = event.params.rideId as string;
    const winningDriverUid =
      typeof after.driverUid === "string" ? after.driverUid.trim() : "";

    const dispatchesSnap = await db
      .collection("rides")
      .doc(rideId)
      .collection("dispatches")
      .get();

    if (dispatchesSnap.empty) return;

    const cancelItems: Array<{
      target: ResolvedTokenTarget;
      message: admin.messaging.Message;
    }> = [];

    for (const dDoc of dispatchesSnap.docs) {
      if (dDoc.id === winningDriverUid) continue;
      const dData = dDoc.data();
      const storedTokens = Array.isArray(dData.tokens) ? (dData.tokens as unknown[]) : [];
      if (storedTokens.length === 0) continue;

      const resolvedTargets = await resolveDriverTokens(dDoc.id);
      const targetByToken = new Map(resolvedTargets.map((t) => [t.token, t]));
      const fallbackPlatform = Array.isArray(dData.platforms) && dData.platforms.includes("ios")
        ? "ios"
        : "android";

      for (const rawToken of storedTokens) {
        if (typeof rawToken !== "string" || !rawToken.trim()) continue;
        const token = rawToken.trim();
        const target: ResolvedTokenTarget = targetByToken.get(token) ?? {
          uid: dDoc.id,
          token,
          platform: fallbackPlatform,
          source: "driver",
        };

        const cancelData: Record<string, string> = {
          type: "ride_alert_cancel",
          rideId,
          reason: afterStatus,
        };

        if (target.platform === "ios") {
          cancelItems.push({
            target,
            message: {
              token,
              data: cancelData,
              apns: {
                headers: {
                  "apns-push-type": "background",
                  "apns-priority": "5",
                  "apns-collapse-id": `ride_${rideId}`,
                },
                payload: {
                  aps: {
                    "content-available": 1,
                  },
                },
              },
            },
          });
        } else {
          // IMPORTANT: Normal priority on Android so Google FCM does not deprioritize
          // future high-priority incoming ride alerts due to silent pushes.
          cancelItems.push({
            target,
            message: {
              token,
              data: cancelData,
              android: {
                priority: "normal",
                ttl: 30_000,
                collapseKey: `ride_${rideId}`,
              },
            },
          });
        }
      }
    }

    await sendMessagesInChunks(cancelItems);
    logger.info("Sent ride alert cancellations", {
      rideId,
      reason: afterStatus,
      cancelPushCount: cancelItems.length,
    });
  }
);

export const expireStaleRideRequests = onSchedule(
  { schedule: "every 1 minutes", timeZone: "UTC", region: REGION_SCHEDULE, maxInstances: 1 },
  async () => {
    const db = getDb();
    const now = admin.firestore.Timestamp.now();
    const nowMs = now.toMillis();
    const ridesCol = db.collection("rides");

    const [expiredSnap, legacySnap] = await Promise.all([
      ridesCol
        .where("status", "in", ["requested", "bidding"])
        .where("expiresAt", "<=", now)
        .limit(100)
        .get(),
      ridesCol
        .where("status", "==", "requested")
        .where("createdAt", "<=", admin.firestore.Timestamp.fromMillis(nowMs - 5 * 60_000))
        .limit(50)
        .get(),
    ]);

    const candidateRefs = new Map<string, admin.firestore.DocumentReference>();
    for (const doc of expiredSnap.docs) {
      candidateRefs.set(doc.id, doc.ref);
    }
    for (const doc of legacySnap.docs) {
      if (!doc.data().expiresAt) {
        candidateRefs.set(doc.id, doc.ref);
      }
    }

    let expiredCount = 0;
    for (const [rideId, rideRef] of candidateRefs.entries()) {
      try {
        const didExpire = await db.runTransaction(async (tx) => {
          const fresh = await tx.get(rideRef);
          if (!fresh.exists) return false;
          const data = fresh.data() ?? {};
          if (!["requested", "bidding"].includes(String(data.status ?? ""))) return false;
          if (data.driverUid) return false;

          if (data.status === "bidding") {
            const offersSnap = await tx.get(
              db
                .collection("bids")
                .doc(rideId)
                .collection("offers")
                .where("status", "==", "pending")
                .limit(20)
            );
            const hasLiveOffer = offersSnap.docs.some((o) => {
              const expMs = parseTimestampMillis(o.data().expiresAt) ?? 0;
              return expMs > nowMs;
            });
            if (hasLiveOffer) return false;
          }

          tx.update(rideRef, {
            status: "expired",
            expiredAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          return true;
        });
        if (didExpire) expiredCount++;
      } catch (e) {
        logger.warn("Failed expiring stale ride", { rideId, e: String(e) });
      }
    }

    // Mark stale online presence documents offline (>20m without heartbeat)
    const stalePresenceCutoff = admin.firestore.Timestamp.fromMillis(nowMs - 20 * 60_000);
    const stalePresenceSnap = await db
      .collection("driverPresence")
      .where("availabilityState", "==", "online")
      .where("lastHeartbeatAt", "<=", stalePresenceCutoff)
      .limit(100)
      .get();

    if (!stalePresenceSnap.empty) {
      const batch = db.batch();
      for (const pDoc of stalePresenceSnap.docs) {
        batch.update(pDoc.ref, {
          availabilityState: "offline",
          isAvailableForRequests: false,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }

    if (expiredCount > 0 || !stalePresenceSnap.empty) {
      logger.info("Scheduled ride/presence expiration pass completed", {
        expiredRides: expiredCount,
        staleDriversOfflined: stalePresenceSnap.size,
      });
    }
  }
);
