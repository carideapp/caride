"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.reconcileExpiredSecurityLocks = exports.listLockoutSupportChatsCallable = exports.getLockoutSupportChatCallable = exports.submitLockoutSupportMessageCallable = exports.adminUnrestrictIpCallable = exports.adminRestrictIpCallable = exports.adminManualLockAccountCallable = exports.adminUnlockAccountCallable = exports.reportLoginAttemptCallable = exports.checkAccountLockStatusCallable = exports.updateSecurityPolicyCallable = exports.getSecurityPolicyCallable = exports.DEFAULT_SECURITY_POLICY = void 0;
exports.durationToMilliseconds = durationToMilliseconds;
exports.sanitizeIp = sanitizeIp;
exports.sanitizeIpKey = sanitizeIpKey;
exports.extractClientIp = extractClientIp;
exports.isIpAllowlisted = isIpAllowlisted;
exports.getEffectiveSecurityPolicy = getEffectiveSecurityPolicy;
exports.logSecurityAuditEvent = logSecurityAuditEvent;
exports.assertAdminOrStaff = assertAdminOrStaff;
exports.checkAndEnforceIpRateLimit = checkAndEnforceIpRateLimit;
exports.resolveUser = resolveUser;
exports.determineNextLockoutStage = determineNextLockoutStage;
const admin = __importStar(require("firebase-admin"));
const logger = __importStar(require("firebase-functions/logger"));
const https_1 = require("firebase-functions/v2/https");
const scheduler_1 = require("firebase-functions/v2/scheduler");
const REGION_PRIMARY = "us-east1";
const REGION_SCHEDULE = "us-west1";
// ─── Default Policy ────────────────────────────────────────────────────────────
exports.DEFAULT_SECURITY_POLICY = {
    accountLockout: {
        enabled: true,
        progressiveLockoutEnabled: true,
        targetAccountTypes: ["customer", "driver", "fleet"],
        stages: [
            {
                id: "stage-1",
                name: "Stage 1",
                order: 1,
                attemptsRequired: 3,
                durationValue: 5,
                durationUnit: "minutes",
                isManualUnlock: false,
                enabled: true,
            },
            {
                id: "stage-2",
                name: "Stage 2",
                order: 2,
                attemptsRequired: 3,
                durationValue: 30,
                durationUnit: "minutes",
                isManualUnlock: false,
                enabled: true,
            },
            {
                id: "stage-3",
                name: "Stage 3",
                order: 3,
                attemptsRequired: 3,
                durationValue: 24,
                durationUnit: "hours",
                isManualUnlock: false,
                enabled: true,
            },
            {
                id: "stage-4",
                name: "Stage 4",
                order: 4,
                attemptsRequired: 3,
                durationValue: 0,
                durationUnit: "hours",
                isManualUnlock: true,
                enabled: true,
            },
        ],
        counterResetPolicy: {
            resetOnSuccessfulLogin: true,
            inactivityWindowMinutes: 60,
        },
        independentPerRole: false,
    },
    ipRateLimiting: {
        enabled: true,
        defaultWindowSeconds: 300,
        defaultMaxRequests: 30,
        defaultBlockDurationMinutes: 60,
        autoBlockEnabled: true,
        endpointRules: {
            login: { maxRequests: 15, windowSeconds: 300, blockDurationMinutes: 30, enabled: true },
            otp_request: { maxRequests: 5, windowSeconds: 300, blockDurationMinutes: 60, enabled: true },
            otp_verify: { maxRequests: 10, windowSeconds: 300, blockDurationMinutes: 60, enabled: true },
            password_reset: { maxRequests: 5, windowSeconds: 600, blockDurationMinutes: 60, enabled: true },
            registration: { maxRequests: 10, windowSeconds: 600, blockDurationMinutes: 30, enabled: true },
        },
        allowlist: [],
    },
    otpRecoveryProtection: {
        maxOtpRequestsPerWindow: 5,
        otpRequestWindowMinutes: 15,
        maxVerifyAttempts: 5,
        otpTtlMinutes: 10,
        resendCooldownSeconds: 60,
        maxPasswordResetsPerWindow: 5,
        passwordResetWindowMinutes: 30,
    },
};
// ─── Helpers ───────────────────────────────────────────────────────────────────
function durationToMilliseconds(val, unit) {
    if (val <= 0)
        return 0;
    switch (unit) {
        case "seconds":
            return val * 1000;
        case "minutes":
            return val * 60 * 1000;
        case "hours":
            return val * 60 * 60 * 1000;
        case "days":
            return val * 24 * 60 * 60 * 1000;
        default:
            return val * 60 * 1000;
    }
}
function sanitizeIp(rawIp) {
    if (!rawIp)
        return "127.0.0.1";
    let ip = rawIp.trim();
    if (ip.includes(",")) {
        ip = ip.split(",")[0].trim();
    }
    if (ip.startsWith("::ffff:")) {
        ip = ip.substring(7);
    }
    return ip || "127.0.0.1";
}
function sanitizeIpKey(ip) {
    // Replace characters not allowed in Firestore document IDs
    return ip.replace(/[^a-zA-Z0-9_-]/g, "_");
}
function extractClientIp(request) {
    const req = request.rawRequest;
    if (!req) {
        return sanitizeIp(request.data?.ip);
    }
    const xForwardedFor = req.headers["x-forwarded-for"];
    const forwardedIp = Array.isArray(xForwardedFor) ? xForwardedFor[0] : xForwardedFor;
    const directIp = req.ip || req.socket?.remoteAddress;
    return sanitizeIp(forwardedIp || directIp || request.data?.ip);
}
function isIpAllowlisted(ip, allowlist) {
    if (!allowlist || allowlist.length === 0)
        return false;
    const cleanIp = sanitizeIp(ip);
    if (cleanIp === "127.0.0.1" || cleanIp === "::1" || cleanIp === "localhost")
        return true;
    return allowlist.some((item) => {
        const trimmed = item.trim();
        if (trimmed === cleanIp)
            return true;
        if (trimmed.endsWith("*") && cleanIp.startsWith(trimmed.slice(0, -1)))
            return true;
        return false;
    });
}
async function getEffectiveSecurityPolicy(db) {
    try {
        const snap = await db.collection("config").doc("securityPolicy").get();
        if (snap.exists) {
            const data = snap.data();
            return {
                accountLockout: {
                    ...exports.DEFAULT_SECURITY_POLICY.accountLockout,
                    ...(data.accountLockout || {}),
                    stages: data.accountLockout?.stages?.length
                        ? data.accountLockout.stages
                        : exports.DEFAULT_SECURITY_POLICY.accountLockout.stages,
                },
                ipRateLimiting: {
                    ...exports.DEFAULT_SECURITY_POLICY.ipRateLimiting,
                    ...(data.ipRateLimiting || {}),
                    endpointRules: {
                        ...exports.DEFAULT_SECURITY_POLICY.ipRateLimiting.endpointRules,
                        ...(data.ipRateLimiting?.endpointRules || {}),
                    },
                },
                otpRecoveryProtection: {
                    ...exports.DEFAULT_SECURITY_POLICY.otpRecoveryProtection,
                    ...(data.otpRecoveryProtection || {}),
                },
                updatedAt: data.updatedAt,
                updatedBy: data.updatedBy,
                updatedByEmail: data.updatedByEmail,
            };
        }
    }
    catch (err) {
        logger.warn("Failed to load security policy from Firestore, using defaults", { error: err });
    }
    return exports.DEFAULT_SECURITY_POLICY;
}
async function logSecurityAuditEvent(db, event) {
    const docRef = db.collection("security_audit_logs").doc();
    const fullEvent = {
        ...event,
        id: docRef.id,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
    };
    await docRef.set(fullEvent);
    logger.info("Security audit log recorded", {
        id: docRef.id,
        eventType: event.eventType,
        severity: event.severity,
        targetUid: event.targetUid,
        ip: event.ip,
    });
    return docRef.id;
}
async function assertAdminOrStaff(request, requireFullAdmin = false) {
    if (!request.auth) {
        throw new https_1.HttpsError("unauthenticated", "Authentication required.");
    }
    const uid = request.auth.uid;
    const [adminSnap, staffSnap] = await Promise.all([
        admin.firestore().collection("admins").doc(uid).get(),
        admin.firestore().collection("staff").doc(uid).get(),
    ]);
    const isAdmin = adminSnap.exists;
    const isStaff = staffSnap.exists;
    if (requireFullAdmin && !isAdmin) {
        throw new https_1.HttpsError("permission-denied", "Unauthorized. Administrator privileges required.");
    }
    if (!isAdmin && !isStaff) {
        throw new https_1.HttpsError("permission-denied", "Unauthorized. Administrator or Staff access required.");
    }
    return {
        uid,
        email: request.auth.token.email,
        isAdmin,
        isStaff,
    };
}
// ─── IP Rate Limiting Enforcement ──────────────────────────────────────────────
async function checkAndEnforceIpRateLimit(db, rawIp, endpoint, policy) {
    if (!policy.ipRateLimiting.enabled) {
        return { allowed: true };
    }
    const ip = sanitizeIp(rawIp);
    if (isIpAllowlisted(ip, policy.ipRateLimiting.allowlist)) {
        return { allowed: true };
    }
    const ipKey = sanitizeIpKey(ip);
    const ipStatRef = db.collection("security_ip_stats").doc(ipKey);
    const now = Date.now();
    // 1. Check existing restriction on this IP
    const ipStatSnap = await ipStatRef.get();
    if (ipStatSnap.exists) {
        const data = ipStatSnap.data() || {};
        const status = data.status;
        if (status === "restricted" || status === "blocked_by_admin") {
            const expiresAt = data.expiresAt?.toDate?.()?.getTime();
            if (expiresAt && expiresAt <= now && status === "restricted") {
                // Restriction has naturally expired
                await ipStatRef.update({
                    status: "active",
                    restrictionType: "none",
                    unblockedAt: admin.firestore.FieldValue.serverTimestamp(),
                    unblockedReason: "automatic_expiration",
                });
                await logSecurityAuditEvent(db, {
                    eventType: "ip_unblocked",
                    severity: "low",
                    ip,
                    endpoint,
                    actionTaken: "automatic_unblock",
                    description: `Temporary IP restriction for ${ip} expired naturally and was lifted.`,
                });
            }
            else {
                // Still restricted
                return {
                    allowed: false,
                    restrictionReason: data.restrictionReason || "Access temporarily restricted due to suspicious activity.",
                };
            }
        }
    }
    // 2. Evaluate endpoint-specific or default rate limit rules
    const rule = policy.ipRateLimiting.endpointRules[endpoint] || {
        maxRequests: policy.ipRateLimiting.defaultMaxRequests,
        windowSeconds: policy.ipRateLimiting.defaultWindowSeconds,
        blockDurationMinutes: policy.ipRateLimiting.defaultBlockDurationMinutes,
        enabled: true,
    };
    if (!rule.enabled) {
        return { allowed: true };
    }
    const windowSeconds = rule.windowSeconds || 300;
    const maxRequests = rule.maxRequests || 30;
    const currentWindowKey = Math.floor(now / (windowSeconds * 1000));
    const windowDocRef = db.collection("security_ip_windows").doc(`${ipKey}_${endpoint}_${currentWindowKey}`);
    // Increment window counter atomically
    let requestCount = 1;
    await db.runTransaction(async (tx) => {
        const winSnap = await tx.get(windowDocRef);
        if (!winSnap.exists) {
            tx.set(windowDocRef, {
                ip,
                endpoint,
                count: 1,
                windowKey: currentWindowKey,
                expiresAt: admin.firestore.Timestamp.fromDate(new Date(now + windowSeconds * 2 * 1000)),
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            requestCount = 1;
        }
        else {
            const current = winSnap.data()?.count || 0;
            requestCount = current + 1;
            tx.update(windowDocRef, { count: requestCount });
        }
    });
    // Track overall IP activity
    await ipStatRef.set({
        ip,
        ipKey,
        totalRequests: admin.firestore.FieldValue.increment(1),
        lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
        targetedEndpoints: admin.firestore.FieldValue.arrayUnion(endpoint),
        ...(ipStatSnap.exists
            ? {}
            : {
                firstSeenAt: admin.firestore.FieldValue.serverTimestamp(),
                status: "active",
                severity: "low",
                failedAuthCount: 0,
                successAuthCount: 0,
                targetedAccounts: [],
            }),
    }, { merge: true });
    // If rate limit breached
    if (requestCount > maxRequests) {
        const blockDurationMs = (rule.blockDurationMinutes || 60) * 60 * 1000;
        const expiresAt = new Date(now + blockDurationMs);
        if (policy.ipRateLimiting.autoBlockEnabled) {
            await ipStatRef.set({
                status: "restricted",
                restrictionType: "temporary",
                restrictionReason: `Exceeded rate limit for ${endpoint} (${requestCount}/${maxRequests} req in ${windowSeconds}s)`,
                restrictedAt: admin.firestore.FieldValue.serverTimestamp(),
                expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
                severity: "high",
            }, { merge: true });
            await logSecurityAuditEvent(db, {
                eventType: "ip_rate_limit_triggered",
                severity: "high",
                ip,
                endpoint,
                actionTaken: "temporary_ip_restriction",
                description: `IP ${ip} exceeded rate limit on ${endpoint} (${requestCount} requests). Restricted for ${rule.blockDurationMinutes}m.`,
            });
        }
        return {
            allowed: false,
            restrictionReason: `Too many requests from your IP. Please try again in ${rule.blockDurationMinutes} minutes.`,
        };
    }
    return { allowed: true };
}
// ─── User Resolution Helper ────────────────────────────────────────────────────
async function resolveUser(db, identifier) {
    const clean = identifier.trim().toLowerCase();
    // Try Firebase Auth by email
    if (clean.includes("@")) {
        try {
            const user = await admin.auth().getUserByEmail(clean);
            if (user) {
                const [custDoc, driverDoc, fleetDoc] = await Promise.all([
                    db.collection("customers").doc(user.uid).get(),
                    db.collection("drivers").doc(user.uid).get(),
                    db.collection("fleet_managers").doc(user.uid).get(),
                ]);
                let accountType = "unknown";
                let fullName = user.displayName || "";
                let phone = user.phoneNumber || "";
                if (driverDoc.exists) {
                    accountType = "driver";
                    fullName = driverDoc.data()?.fullName || fullName;
                    phone = driverDoc.data()?.phone || phone;
                }
                else if (fleetDoc.exists) {
                    accountType = "fleet";
                    fullName = fleetDoc.data()?.fullName || fullName;
                    phone = fleetDoc.data()?.phone || phone;
                }
                else if (custDoc.exists) {
                    accountType = "customer";
                    fullName = custDoc.data()?.fullName || fullName;
                    phone = custDoc.data()?.phone || phone;
                }
                return {
                    uid: user.uid,
                    email: user.email || clean,
                    phone,
                    fullName,
                    accountType,
                };
            }
        }
        catch (_) { }
    }
    // Try searching customers, drivers, fleet_managers
    const collections = ["customers", "drivers", "fleet_managers"];
    for (const col of collections) {
        const qEmail = await db.collection(col).where("email", "==", clean).limit(1).get();
        if (!qEmail.empty) {
            const doc = qEmail.docs[0];
            const d = doc.data();
            const type = col === "drivers" ? "driver" : col === "fleet_managers" ? "fleet" : "customer";
            return {
                uid: doc.id,
                email: d.email || clean,
                phone: d.phone || "",
                fullName: d.fullName || d.displayName || "",
                accountType: type,
            };
        }
        const qPhone = await db.collection(col).where("phone", "==", identifier.trim()).limit(1).get();
        if (!qPhone.empty) {
            const doc = qPhone.docs[0];
            const d = doc.data();
            const type = col === "drivers" ? "driver" : col === "fleet_managers" ? "fleet" : "customer";
            return {
                uid: doc.id,
                email: d.email || "",
                phone: d.phone || identifier.trim(),
                fullName: d.fullName || d.displayName || "",
                accountType: type,
            };
        }
    }
    return null;
}
// ─── Progressive Lockout Stage Evaluator ───────────────────────────────────────
function determineNextLockoutStage(policy, currentAttempts, previousStageOrder = 0) {
    const activeStages = [...policy.stages]
        .filter((s) => s.enabled)
        .sort((a, b) => a.order - b.order);
    if (activeStages.length === 0) {
        return { isLockoutTriggered: false, stage: null, stageOrder: 0 };
    }
    if (policy.progressiveLockoutEnabled) {
        // Progressive mode: Each stage triggers after its own specified additional attempts
        // Or cumulative: sum of attemptsRequired up to stage N
        let cumulativeThreshold = 0;
        for (const stage of activeStages) {
            cumulativeThreshold += stage.attemptsRequired;
            if (currentAttempts >= cumulativeThreshold && stage.order > previousStageOrder) {
                return { isLockoutTriggered: true, stage, stageOrder: stage.order };
            }
        }
        // If beyond final stage, keep final stage or manual lock
        const finalStage = activeStages[activeStages.length - 1];
        if (currentAttempts >= cumulativeThreshold) {
            return { isLockoutTriggered: true, stage: finalStage, stageOrder: finalStage.order };
        }
    }
    else {
        // Non-progressive: uses first active stage
        const baseStage = activeStages[0];
        if (currentAttempts >= baseStage.attemptsRequired) {
            return { isLockoutTriggered: true, stage: baseStage, stageOrder: baseStage.order };
        }
    }
    return { isLockoutTriggered: false, stage: null, stageOrder: previousStageOrder };
}
// ─── Exported Cloud Functions ──────────────────────────────────────────────────
/**
 * Get current active security policy (Callable)
 */
exports.getSecurityPolicyCallable = (0, https_1.onCall)({ region: REGION_PRIMARY, maxInstances: 10, cors: true }, async (request) => {
    await assertAdminOrStaff(request, false);
    const db = admin.firestore();
    const policy = await getEffectiveSecurityPolicy(db);
    return { success: true, policy };
});
/**
 * Update security policy dynamically (Admin Only Callable)
 */
exports.updateSecurityPolicyCallable = (0, https_1.onCall)({ region: REGION_PRIMARY, maxInstances: 5, cors: true }, async (request) => {
    const adminUser = await assertAdminOrStaff(request, true);
    const db = admin.firestore();
    const newPolicy = request.data?.policy;
    if (!newPolicy) {
        throw new https_1.HttpsError("invalid-argument", "Missing policy payload.");
    }
    // Validation: Lockout stages
    if (newPolicy.accountLockout?.stages) {
        const stages = newPolicy.accountLockout.stages;
        if (!Array.isArray(stages) || stages.length === 0) {
            throw new https_1.HttpsError("invalid-argument", "At least one lockout stage must be configured.");
        }
        for (const stage of stages) {
            if (!stage.name || stage.name.trim() === "") {
                throw new https_1.HttpsError("invalid-argument", "Each stage must have a name.");
            }
            if (typeof stage.attemptsRequired !== "number" || stage.attemptsRequired <= 0) {
                throw new https_1.HttpsError("invalid-argument", `Stage ${stage.name} must require at least 1 failed attempt.`);
            }
            if (!stage.isManualUnlock && (typeof stage.durationValue !== "number" || stage.durationValue <= 0)) {
                throw new https_1.HttpsError("invalid-argument", `Stage ${stage.name} must have a positive duration or require manual unlock.`);
            }
        }
    }
    const mergedPolicy = {
        accountLockout: {
            ...exports.DEFAULT_SECURITY_POLICY.accountLockout,
            ...(newPolicy.accountLockout || {}),
        },
        ipRateLimiting: {
            ...exports.DEFAULT_SECURITY_POLICY.ipRateLimiting,
            ...(newPolicy.ipRateLimiting || {}),
        },
        otpRecoveryProtection: {
            ...exports.DEFAULT_SECURITY_POLICY.otpRecoveryProtection,
            ...(newPolicy.otpRecoveryProtection || {}),
        },
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedBy: adminUser.uid,
        updatedByEmail: adminUser.email || "admin@caride.com",
    };
    await db.collection("config").doc("securityPolicy").set(mergedPolicy);
    await logSecurityAuditEvent(db, {
        eventType: "security_settings_changed",
        severity: "medium",
        ip: extractClientIp(request),
        endpoint: "updateSecurityPolicy",
        actionTaken: "policy_update",
        description: `Security policy updated by Administrator ${adminUser.email || adminUser.uid}.`,
        adminId: adminUser.uid,
        adminEmail: adminUser.email,
    });
    return { success: true, message: "Security policy updated successfully.", policy: mergedPolicy };
});
/**
 * Check if an account or IP is locked before attempting login
 */
exports.checkAccountLockStatusCallable = (0, https_1.onCall)({ region: REGION_PRIMARY, maxInstances: 15, cors: true }, async (request) => {
    const db = admin.firestore();
    const identifier = String(request.data?.identifier || "").trim();
    const rawIp = extractClientIp(request);
    const policy = await getEffectiveSecurityPolicy(db);
    // 1. IP Check
    const ipCheck = await checkAndEnforceIpRateLimit(db, rawIp, "login", policy);
    if (!ipCheck.allowed) {
        return {
            isLocked: true,
            lockType: "ip_restriction",
            reason: ipCheck.restrictionReason || "Access restricted from this IP.",
            remainingSeconds: (policy.ipRateLimiting.defaultBlockDurationMinutes || 60) * 60,
        };
    }
    if (!identifier) {
        return { isLocked: false };
    }
    // 2. Account Check
    const user = await resolveUser(db, identifier);
    if (!user) {
        // Do not reveal that account doesn't exist
        return { isLocked: false };
    }
    const lockRef = db.collection("security_account_locks").doc(user.uid);
    const lockSnap = await lockRef.get();
    if (!lockSnap.exists) {
        return { isLocked: false };
    }
    const data = lockSnap.data() || {};
    const status = data.status;
    if (status !== "active") {
        return { isLocked: false };
    }
    const now = Date.now();
    const lockType = data.lockType;
    const expiresAtMs = data.expiresAt?.toDate?.()?.getTime();
    // Check natural expiration of temporary locks
    if (lockType === "temporary" && expiresAtMs && expiresAtMs <= now) {
        // Automatically unlock in Firebase Auth & Firestore
        try {
            await admin.auth().updateUser(user.uid, { disabled: false });
        }
        catch (err) {
            logger.warn("Failed to enable Firebase Auth user during auto-unlock", { uid: user.uid, error: err.message });
        }
        await lockRef.update({
            status: "expired",
            unlockedAt: admin.firestore.FieldValue.serverTimestamp(),
            unlockedReason: "automatic_expiration",
        });
        await logSecurityAuditEvent(db, {
            eventType: "auto_unlock",
            severity: "low",
            targetUid: user.uid,
            targetEmail: user.email,
            accountType: user.accountType,
            ip: rawIp,
            endpoint: "checkAccountLockStatus",
            actionTaken: "automatic_account_unlock",
            description: `Temporary lock for ${user.email || user.uid} expired and was automatically lifted.`,
        });
        return { isLocked: false };
    }
    // Active lock remains
    const remainingSeconds = expiresAtMs ? Math.max(0, Math.ceil((expiresAtMs - now) / 1000)) : null;
    return {
        isLocked: true,
        lockType,
        stageName: data.stageName || "Security Lockout",
        remainingSeconds,
        reason: lockType === "manual"
            ? "Your account has been locked for security. Please contact CaRide support."
            : `Too many failed login attempts. Your account is temporarily locked. Please try again in ${remainingSeconds ? Math.ceil(remainingSeconds / 60) : 5} minutes.`,
    };
});
/**
 * Report login attempt outcome (success or failure) to track attempts and trigger progressive lockouts
 */
exports.reportLoginAttemptCallable = (0, https_1.onCall)({ region: REGION_PRIMARY, maxInstances: 15, cors: true }, async (request) => {
    const db = admin.firestore();
    const identifier = String(request.data?.identifier || "").trim();
    const success = Boolean(request.data?.success);
    const errorCode = String(request.data?.errorCode || "");
    const role = String(request.data?.role || "");
    const rawIp = extractClientIp(request);
    const policy = await getEffectiveSecurityPolicy(db);
    const now = Date.now();
    const ipKey = sanitizeIpKey(rawIp);
    if (!identifier) {
        return { success: false, message: "Missing identifier." };
    }
    const user = await resolveUser(db, identifier);
    if (!user) {
        // Record failed IP attempt for unknown accounts (prevents scanning/enumeration)
        if (!success) {
            await db.collection("security_ip_stats").doc(ipKey).set({
                ip: rawIp,
                ipKey,
                failedAuthCount: admin.firestore.FieldValue.increment(1),
                lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
                targetedAccounts: admin.firestore.FieldValue.arrayUnion(identifier.slice(0, 50)),
            }, { merge: true });
        }
        return { success: true, processed: true };
    }
    const lockRef = db.collection("security_account_locks").doc(user.uid);
    const lockSnap = await lockRef.get();
    const lockData = lockSnap.exists ? lockSnap.data() || {} : {};
    if (success) {
        // Successful login
        const resetOnSuccess = policy.accountLockout.counterResetPolicy.resetOnSuccessfulLogin;
        await lockRef.set({
            uid: user.uid,
            email: user.email,
            phone: user.phone,
            fullName: user.fullName,
            accountType: user.accountType,
            lastSuccessfulLoginAt: admin.firestore.FieldValue.serverTimestamp(),
            lastSuccessfulIp: rawIp,
            ...(resetOnSuccess
                ? {
                    failedAttempts: 0,
                    stageOrder: 0,
                    status: lockData.status === "active" ? "unlocked" : (lockData.status || "unlocked"),
                }
                : {}),
        }, { merge: true });
        // Update IP stats
        await db.collection("security_ip_stats").doc(ipKey).set({
            ip: rawIp,
            ipKey,
            successAuthCount: admin.firestore.FieldValue.increment(1),
            lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
            targetedAccounts: admin.firestore.FieldValue.arrayUnion(user.email || user.uid),
        }, { merge: true });
        await logSecurityAuditEvent(db, {
            eventType: "successful_login",
            severity: "low",
            targetUid: user.uid,
            targetEmail: user.email,
            targetPhone: user.phone,
            accountType: user.accountType,
            ip: rawIp,
            endpoint: "login",
            actionTaken: "record_successful_login",
            description: `Successful login for ${user.email || user.uid} from ${rawIp}.`,
        });
        return { success: true, isLocked: false };
    }
    // Failed login attempt
    if (!policy.accountLockout.enabled) {
        return { success: true, isLocked: false };
    }
    // Target account type filter check
    if (policy.accountLockout.targetAccountTypes.length > 0 &&
        user.accountType !== "unknown" &&
        !policy.accountLockout.targetAccountTypes.includes(user.accountType)) {
        return { success: true, isLocked: false };
    }
    // Check inactivity window: if last failure was older than inactivityWindowMinutes, reset counter
    let currentFailedAttempts = (lockData.failedAttempts || 0);
    const lastFailedAt = lockData.lastFailedAt?.toDate?.()?.getTime();
    const inactivityMs = (policy.accountLockout.counterResetPolicy.inactivityWindowMinutes || 60) * 60 * 1000;
    if (lastFailedAt && now - lastFailedAt > inactivityMs && lockData.status !== "active") {
        currentFailedAttempts = 0;
    }
    currentFailedAttempts += 1;
    const previousStageOrder = (lockData.stageOrder || 0);
    // Evaluate progression
    const { isLockoutTriggered, stage, stageOrder } = determineNextLockoutStage(policy.accountLockout, currentFailedAttempts, previousStageOrder);
    let isLocked = false;
    let lockExpiresAt = null;
    let lockType = "temporary";
    if (isLockoutTriggered && stage) {
        isLocked = true;
        lockType = stage.isManualUnlock ? "manual" : "temporary";
        if (!stage.isManualUnlock) {
            const durationMs = durationToMilliseconds(stage.durationValue, stage.durationUnit);
            lockExpiresAt = new Date(now + durationMs);
        }
        // Disable user in Firebase Auth
        try {
            await admin.auth().updateUser(user.uid, { disabled: true });
            await admin.auth().revokeRefreshTokens(user.uid);
        }
        catch (err) {
            logger.error("Failed to disable user in Firebase Auth", { uid: user.uid, error: err.message });
        }
        await logSecurityAuditEvent(db, {
            eventType: stageOrder > previousStageOrder ? "lockout_escalated" : "account_lockout",
            severity: stage.isManualUnlock ? "critical" : "high",
            targetUid: user.uid,
            targetEmail: user.email,
            targetPhone: user.phone,
            accountType: user.accountType,
            ip: rawIp,
            endpoint: "login",
            actionTaken: stage.isManualUnlock ? "manual_security_lockout" : "temporary_security_lockout",
            description: `Account ${user.email || user.uid} reached ${stage.name} (${currentFailedAttempts} failed attempts). ${stage.isManualUnlock ? "Requires manual Admin unlock." : `Locked for ${stage.durationValue} ${stage.durationUnit}.`}`,
        });
    }
    // Save lock status
    await lockRef.set({
        uid: user.uid,
        email: user.email,
        phone: user.phone,
        fullName: user.fullName,
        accountType: user.accountType,
        failedAttempts: currentFailedAttempts,
        lastFailedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastAttemptIp: rawIp,
        lastErrorCode: errorCode,
        ...(isLocked
            ? {
                status: "active",
                lockType,
                stageOrder,
                stageName: stage?.name || "Lockout",
                lockedAt: admin.firestore.FieldValue.serverTimestamp(),
                expiresAt: lockExpiresAt ? admin.firestore.Timestamp.fromDate(lockExpiresAt) : null,
                lockReason: `Failed password attempts (${currentFailedAttempts} consecutive attempts)`,
                totalHistoricalLocks: admin.firestore.FieldValue.increment(1),
            }
            : {}),
    }, { merge: true });
    // Track IP failures
    await db.collection("security_ip_stats").doc(ipKey).set({
        ip: rawIp,
        ipKey,
        failedAuthCount: admin.firestore.FieldValue.increment(1),
        lastSeenAt: admin.firestore.FieldValue.serverTimestamp(),
        targetedAccounts: admin.firestore.FieldValue.arrayUnion(user.email || user.uid),
    }, { merge: true });
    await logSecurityAuditEvent(db, {
        eventType: "failed_login",
        severity: isLocked ? "high" : "medium",
        targetUid: user.uid,
        targetEmail: user.email,
        targetPhone: user.phone,
        accountType: user.accountType,
        ip: rawIp,
        endpoint: "login",
        actionTaken: isLocked ? "account_locked" : "attempt_recorded",
        description: `Failed login attempt for ${user.email || user.uid} from ${rawIp}. Attempt #${currentFailedAttempts}.`,
    });
    return {
        success: true,
        isLocked,
        lockType: isLocked ? lockType : null,
        stageName: stage?.name || null,
        remainingSeconds: lockExpiresAt ? Math.ceil((lockExpiresAt.getTime() - now) / 1000) : null,
        failedAttempts: currentFailedAttempts,
    };
});
/**
 * Admin: Manually unlock an account (Callable)
 */
exports.adminUnlockAccountCallable = (0, https_1.onCall)({ region: REGION_PRIMARY, maxInstances: 5, cors: true }, async (request) => {
    const adminUser = await assertAdminOrStaff(request, true);
    const db = admin.firestore();
    let uid = String(request.data?.uid || "").trim();
    const email = String(request.data?.email || "").trim().toLowerCase();
    const reason = String(request.data?.reason || "Admin manual unlock").trim();
    if (!uid && email) {
        try {
            const userRec = await admin.auth().getUserByEmail(email);
            uid = userRec.uid;
        }
        catch (err) {
            const snap = await db
                .collection("security_account_locks")
                .where("email", "==", email)
                .limit(1)
                .get();
            if (!snap.empty) {
                uid = snap.docs[0].id;
            }
        }
    }
    if (!uid) {
        throw new https_1.HttpsError("invalid-argument", "Missing user UID or registered email.");
    }
    const lockRef = db.collection("security_account_locks").doc(uid);
    const lockSnap = await lockRef.get();
    // 1. Re-enable user in Firebase Auth
    try {
        await admin.auth().updateUser(uid, { disabled: false });
    }
    catch (err) {
        logger.warn("Could not re-enable Firebase Auth user (may not exist in Auth):", err.message);
    }
    const targetEmail = email || (lockSnap.exists ? lockSnap.data()?.email : "");
    const targetType = lockSnap.exists ? lockSnap.data()?.accountType : "unknown";
    // 2. Update lock record in Firestore
    await lockRef.set({
        status: "unlocked_by_admin",
        failedAttempts: 0,
        stageOrder: 0,
        unlockedAt: admin.firestore.FieldValue.serverTimestamp(),
        unlockedBy: adminUser.uid,
        unlockedByEmail: adminUser.email || "admin@caride.com",
        unlockReason: reason,
    }, { merge: true });
    // 3. Clear failed login count in user/driver/fleet profile
    try {
        if (targetType === "driver" || !targetType) {
            await db.collection("drivers").doc(uid).set({ isLockedOut: false, failedLoginAttempts: 0 }, { merge: true });
        }
        if (targetType === "customer" || !targetType) {
            await db.collection("users").doc(uid).set({ isLockedOut: false, failedLoginAttempts: 0 }, { merge: true });
        }
        if (targetType === "fleet" || !targetType) {
            await db.collection("fleet_managers").doc(uid).set({ isLockedOut: false, failedLoginAttempts: 0 }, { merge: true });
        }
    }
    catch (clearErr) {
        logger.warn("Could not clear lock flags on profile doc:", clearErr.message);
    }
    // 4. Log audit event
    await logSecurityAuditEvent(db, {
        eventType: "manual_unlock",
        severity: "medium",
        targetUid: uid,
        targetEmail,
        accountType: targetType,
        ip: extractClientIp(request),
        endpoint: "adminUnlockAccount",
        actionTaken: "admin_manual_unlock",
        description: `Account ${targetEmail || uid} manually unlocked by Administrator ${adminUser.email || adminUser.uid}. Reason: ${reason}`,
        adminId: adminUser.uid,
        adminEmail: adminUser.email,
    });
    return { success: true, message: "Account successfully unlocked." };
});
/**
 * Admin: Manually place an account under lock (Callable)
 */
exports.adminManualLockAccountCallable = (0, https_1.onCall)({ region: REGION_PRIMARY, maxInstances: 5, cors: true }, async (request) => {
    const adminUser = await assertAdminOrStaff(request, true);
    const db = admin.firestore();
    const uid = String(request.data?.uid || "").trim();
    const reason = String(request.data?.reason || "Manual security suspension").trim();
    const durationMinutes = Number(request.data?.durationMinutes || 0);
    if (!uid) {
        throw new https_1.HttpsError("invalid-argument", "Missing user UID.");
    }
    // 1. Disable user in Firebase Auth & revoke tokens
    try {
        await admin.auth().updateUser(uid, { disabled: true });
        await admin.auth().revokeRefreshTokens(uid);
    }
    catch (err) {
        logger.warn("Could not disable Firebase Auth user:", err.message);
    }
    // 2. Fetch user details if not yet in locks
    const user = await resolveUser(db, uid);
    const lockRef = db.collection("security_account_locks").doc(uid);
    const isManual = durationMinutes <= 0;
    const expiresAt = isManual ? null : new Date(Date.now() + durationMinutes * 60 * 1000);
    await lockRef.set({
        uid,
        email: user?.email || "",
        phone: user?.phone || "",
        fullName: user?.fullName || "",
        accountType: user?.accountType || "unknown",
        status: "active",
        lockType: isManual ? "manual" : "temporary",
        stageName: isManual ? "Administrative Lock" : "Temporary Administrative Lock",
        lockedAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: expiresAt ? admin.firestore.Timestamp.fromDate(expiresAt) : null,
        lockReason: reason,
        lockedBy: adminUser.uid,
        lockedByEmail: adminUser.email || "admin@caride.com",
        totalHistoricalLocks: admin.firestore.FieldValue.increment(1),
    }, { merge: true });
    await logSecurityAuditEvent(db, {
        eventType: "manual_lock",
        severity: "high",
        targetUid: uid,
        targetEmail: user?.email,
        accountType: user?.accountType,
        ip: extractClientIp(request),
        endpoint: "adminManualLockAccount",
        actionTaken: "admin_manual_lock",
        description: `Account ${user?.email || uid} placed under administrative lock by ${adminUser.email || adminUser.uid}. Reason: ${reason}`,
        adminId: adminUser.uid,
        adminEmail: adminUser.email,
    });
    return { success: true, message: "Account successfully placed under lock." };
});
/**
 * Admin: Restrict or Block an IP address (Callable)
 */
exports.adminRestrictIpCallable = (0, https_1.onCall)({ region: REGION_PRIMARY, maxInstances: 5, cors: true }, async (request) => {
    const adminUser = await assertAdminOrStaff(request, true);
    const db = admin.firestore();
    const rawIp = String(request.data?.ip || "").trim();
    const reason = String(request.data?.reason || "Admin manual restriction").trim();
    const durationMinutes = Number(request.data?.durationMinutes || 0);
    if (!rawIp) {
        throw new https_1.HttpsError("invalid-argument", "Missing IP address.");
    }
    const ip = sanitizeIp(rawIp);
    const ipKey = sanitizeIpKey(ip);
    const isPermanent = durationMinutes <= 0;
    const expiresAt = isPermanent ? null : new Date(Date.now() + durationMinutes * 60 * 1000);
    await db.collection("security_ip_stats").doc(ipKey).set({
        ip,
        ipKey,
        status: "blocked_by_admin",
        restrictionType: isPermanent ? "manual" : "temporary",
        restrictionReason: reason,
        restrictedAt: admin.firestore.FieldValue.serverTimestamp(),
        expiresAt: expiresAt ? admin.firestore.Timestamp.fromDate(expiresAt) : null,
        restrictedBy: adminUser.uid,
        restrictedByEmail: adminUser.email || "admin@caride.com",
        severity: "high",
    }, { merge: true });
    await logSecurityAuditEvent(db, {
        eventType: "ip_blocked_manual",
        severity: "high",
        ip,
        endpoint: "adminRestrictIp",
        actionTaken: "manual_ip_block",
        description: `IP ${ip} blocked by Administrator ${adminUser.email || adminUser.uid}. Reason: ${reason}. Duration: ${isPermanent ? "Indefinite" : `${durationMinutes}m`}`,
        adminId: adminUser.uid,
        adminEmail: adminUser.email,
    });
    return { success: true, message: `IP ${ip} restricted successfully.` };
});
/**
 * Admin: Unrestrict or Unblock an IP address (Callable)
 */
exports.adminUnrestrictIpCallable = (0, https_1.onCall)({ region: REGION_PRIMARY, maxInstances: 5, cors: true }, async (request) => {
    const adminUser = await assertAdminOrStaff(request, true);
    const db = admin.firestore();
    const rawIp = String(request.data?.ip || "").trim();
    const reason = String(request.data?.reason || "Admin manual unblock").trim();
    if (!rawIp) {
        throw new https_1.HttpsError("invalid-argument", "Missing IP address.");
    }
    const ip = sanitizeIp(rawIp);
    const ipKey = sanitizeIpKey(ip);
    await db.collection("security_ip_stats").doc(ipKey).set({
        status: "active",
        restrictionType: "none",
        unblockedAt: admin.firestore.FieldValue.serverTimestamp(),
        unblockedBy: adminUser.uid,
        unblockedByEmail: adminUser.email || "admin@caride.com",
        unblockReason: reason,
    }, { merge: true });
    await logSecurityAuditEvent(db, {
        eventType: "ip_unblocked",
        severity: "medium",
        ip,
        endpoint: "adminUnrestrictIp",
        actionTaken: "manual_ip_unblock",
        description: `IP ${ip} unblocked by Administrator ${adminUser.email || adminUser.uid}. Reason: ${reason}`,
        adminId: adminUser.uid,
        adminEmail: adminUser.email,
    });
    return { success: true, message: `IP ${ip} unblocked successfully.` };
});
/**
 * Submit a lockout support chat message (Callable for unauthenticated/locked users)
 * - Customer messages route to collection `supportChats` with `userType: 'customer'` (shown in CustomerSupportPage)
 * - Driver messages route to collection `supportChats` with `userType: 'driver'` (shown in DriverSupportPage)
 * - Fleet manager messages route to collection `support_tickets` with `userType: 'fleet'` (shown in FleetSupportPage)
 */
exports.submitLockoutSupportMessageCallable = (0, https_1.onCall)({ region: REGION_PRIMARY, maxInstances: 10, cors: true }, async (request) => {
    const db = admin.firestore();
    const email = String(request.data?.email || "").trim().toLowerCase();
    const rawRole = String(request.data?.role || "customer").trim().toLowerCase();
    const role = rawRole === "driver" ? "driver" : rawRole === "fleet" ? "fleet" : "customer";
    const text = String(request.data?.message || "").trim();
    const subject = String(request.data?.subject || "Account Lockout Support Request").trim();
    const stageName = String(request.data?.stageName || "Final Lockout / Manual Unlock Required").trim();
    const existingChatId = String(request.data?.chatId || "").trim();
    if (!email) {
        throw new https_1.HttpsError("invalid-argument", "Email address is required.");
    }
    if (!text) {
        throw new https_1.HttpsError("invalid-argument", "Message cannot be empty.");
    }
    // Try finding user UID and name from Auth or Collections
    let userUid = "";
    let userName = "";
    try {
        const userRec = await admin.auth().getUserByEmail(email);
        userUid = userRec.uid;
        userName = userRec.displayName || "";
    }
    catch (_) {
        // User might not exist or auth lookup failed
    }
    if (!userName) {
        if (role === "driver" && userUid) {
            const dSnap = await db.collection("drivers").doc(userUid).get();
            if (dSnap.exists)
                userName = dSnap.data()?.fullName || dSnap.data()?.name || "";
        }
        else if (role === "fleet" && userUid) {
            const fSnap = await db.collection("fleet_managers").doc(userUid).get();
            if (fSnap.exists)
                userName = fSnap.data()?.companyName || fSnap.data()?.fullName || "";
        }
        else if (userUid) {
            const uSnap = await db.collection("users").doc(userUid).get();
            if (uSnap.exists)
                userName = uSnap.data()?.fullName || uSnap.data()?.name || "";
        }
    }
    if (!userName) {
        userName = email.split("@")[0];
    }
    const nowMs = Date.now();
    // ─── 1. Fleet Manager Support Tickets ──────────────────────────────
    if (role === "fleet") {
        let ticketId = existingChatId;
        if (ticketId) {
            const ticketRef = db.collection("support_tickets").doc(ticketId);
            const ticketSnap = await ticketRef.get();
            if (!ticketSnap.exists) {
                throw new https_1.HttpsError("not-found", "Support ticket not found.");
            }
            await ticketRef.collection("messages").add({
                senderUid: userUid || "locked-user",
                senderRole: "fleet",
                senderName: userName,
                text,
                createdAtMs: nowMs,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            await ticketRef.update({
                lastMessage: text,
                lastMessageAtMs: nowMs,
                updatedAtMs: nowMs,
                lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
                status: "open",
            });
            return { success: true, chatId: ticketId, role: "fleet" };
        }
        else {
            const ticketRef = db.collection("support_tickets").doc();
            ticketId = ticketRef.id;
            await ticketRef.set({
                ticketId,
                userId: userUid,
                userUid,
                userEmail: email,
                userName,
                userType: "fleet",
                subject,
                status: "open",
                isAccountLockout: true,
                lockoutStage: stageName,
                lastMessage: text,
                lastMessageAtMs: nowMs,
                updatedAtMs: nowMs,
                createdAtMs: nowMs,
                lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            await ticketRef.collection("messages").add({
                senderUid: userUid || "locked-user",
                senderRole: "fleet",
                senderName: userName,
                text,
                createdAtMs: nowMs,
                createdAt: admin.firestore.FieldValue.serverTimestamp(),
            });
            return { success: true, chatId: ticketId, role: "fleet" };
        }
    }
    // ─── 2. Customer & Driver Support Chats ────────────────────────────
    let chatId = existingChatId;
    if (chatId) {
        const chatRef = db.collection("supportChats").doc(chatId);
        const chatSnap = await chatRef.get();
        if (!chatSnap.exists) {
            throw new https_1.HttpsError("not-found", "Support chat not found.");
        }
        await chatRef.collection("messages").add({
            senderUid: userUid || "locked-user",
            senderRole: role,
            text,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        await chatRef.set({
            lastMessage: text,
            lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
            status: "active",
        }, { merge: true });
        return { success: true, chatId, role };
    }
    else {
        const chatRef = db.collection("supportChats").doc();
        chatId = chatRef.id;
        const chatDoc = {
            userType: role,
            subject,
            status: "active",
            isAccountLockout: true,
            lockoutStage: stageName,
            lastMessage: text,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
        };
        if (role === "driver") {
            chatDoc.driverUid = userUid;
            chatDoc.driverName = userName;
            chatDoc.driverEmail = email;
            chatDoc.userUid = userUid;
            chatDoc.userName = userName;
            chatDoc.userEmail = email;
        }
        else {
            chatDoc.userUid = userUid;
            chatDoc.userName = userName;
            chatDoc.userEmail = email;
            chatDoc.customerUid = userUid;
            chatDoc.customerName = userName;
            chatDoc.customerEmail = email;
        }
        await chatRef.set(chatDoc);
        await chatRef.collection("messages").add({
            senderUid: userUid || "locked-user",
            senderRole: role,
            text,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return { success: true, chatId, role };
    }
});
/**
 * Get messages and status for a locked-out user's support chat (Callable)
 */
exports.getLockoutSupportChatCallable = (0, https_1.onCall)({ region: REGION_PRIMARY, maxInstances: 10, cors: true }, async (request) => {
    const db = admin.firestore();
    const email = String(request.data?.email || "").trim().toLowerCase();
    const chatId = String(request.data?.chatId || "").trim();
    const rawRole = String(request.data?.role || "customer").trim().toLowerCase();
    const role = rawRole === "driver" ? "driver" : rawRole === "fleet" ? "fleet" : "customer";
    if (!chatId) {
        throw new https_1.HttpsError("invalid-argument", "Missing chatId parameter.");
    }
    if (role === "fleet") {
        const ticketRef = db.collection("support_tickets").doc(chatId);
        const ticketSnap = await ticketRef.get();
        if (!ticketSnap.exists) {
            throw new https_1.HttpsError("not-found", "Support ticket not found.");
        }
        const data = ticketSnap.data();
        // Security check: email must match if provided
        if (email && data.userEmail && String(data.userEmail).toLowerCase() !== email) {
            throw new https_1.HttpsError("permission-denied", "Access denied to this ticket.");
        }
        const msgsSnap = await ticketRef.collection("messages").orderBy("createdAtMs", "asc").get();
        const messages = msgsSnap.docs.map((doc) => {
            const m = doc.data();
            const createdAt = m.createdAt;
            return {
                id: doc.id,
                senderRole: m.senderRole || "fleet",
                senderName: m.senderName || "",
                text: m.text || "",
                imageUrl: m.imageUrl || null,
                createdAtMs: m.createdAtMs || (createdAt ? createdAt.toMillis() : Date.now()),
            };
        });
        return {
            id: ticketSnap.id,
            role: "fleet",
            subject: data.subject || "Fleet Support",
            status: data.status || "open",
            isAccountLockout: Boolean(data.isAccountLockout),
            lastMessage: data.lastMessage || "",
            messages,
        };
    }
    else {
        const chatRef = db.collection("supportChats").doc(chatId);
        const chatSnap = await chatRef.get();
        if (!chatSnap.exists) {
            throw new https_1.HttpsError("not-found", "Support chat not found.");
        }
        const data = chatSnap.data();
        const ticketEmail = String(data.userEmail || data.driverEmail || data.customerEmail || "").toLowerCase();
        if (email && ticketEmail && ticketEmail !== email) {
            throw new https_1.HttpsError("permission-denied", "Access denied to this chat.");
        }
        const msgsSnap = await chatRef.collection("messages").orderBy("createdAt", "asc").get();
        const messages = msgsSnap.docs.map((doc) => {
            const m = doc.data();
            const createdAt = m.createdAt;
            return {
                id: doc.id,
                senderRole: m.senderRole || (role === "driver" ? "driver" : "customer"),
                senderName: m.senderName || (m.senderRole === "admin" ? "CaRide Support" : "You"),
                text: m.text || "",
                imageUrl: m.imageUrl || null,
                createdAtMs: createdAt ? createdAt.toMillis() : (m.createdAtMs || Date.now()),
            };
        });
        return {
            id: chatSnap.id,
            role,
            subject: data.subject || (role === "driver" ? "Driver Support" : "Customer Support"),
            status: data.status || "active",
            isAccountLockout: Boolean(data.isAccountLockout),
            lastMessage: data.lastMessage || "",
            messages,
        };
    }
});
/**
 * List support chats/tickets for a locked-out user (Callable)
 */
exports.listLockoutSupportChatsCallable = (0, https_1.onCall)({ region: REGION_PRIMARY, maxInstances: 10, cors: true }, async (request) => {
    const db = admin.firestore();
    const email = String(request.data?.email || "").trim().toLowerCase();
    const rawRole = String(request.data?.role || "customer").trim().toLowerCase();
    const role = rawRole === "driver" ? "driver" : rawRole === "fleet" ? "fleet" : "customer";
    if (!email) {
        throw new https_1.HttpsError("invalid-argument", "Missing email parameter.");
    }
    if (role === "fleet") {
        const snap = await db
            .collection("support_tickets")
            .where("userEmail", "==", email)
            .limit(20)
            .get();
        const chats = snap.docs.map((d) => {
            const data = d.data();
            const createdAt = data.createdAt;
            const lastMessageAt = data.lastMessageAt;
            return {
                id: d.id,
                role: "fleet",
                subject: data.subject || "Fleet Support Inquiry",
                status: data.status || "open",
                isAccountLockout: Boolean(data.isAccountLockout),
                lastMessage: data.lastMessage || "",
                lastMessageAtMs: data.lastMessageAtMs || (lastMessageAt ? lastMessageAt.toMillis() : Date.now()),
                createdAtMs: data.createdAtMs || (createdAt ? createdAt.toMillis() : Date.now()),
            };
        });
        chats.sort((a, b) => b.lastMessageAtMs - a.lastMessageAtMs);
        return { chats };
    }
    else {
        const snap = await db
            .collection("supportChats")
            .where("userEmail", "==", email)
            .limit(20)
            .get();
        let docs = snap.docs;
        if (docs.length === 0 && role === "driver") {
            const driverSnap = await db
                .collection("supportChats")
                .where("driverEmail", "==", email)
                .limit(20)
                .get();
            docs = driverSnap.docs;
        }
        const chats = docs
            .map((d) => {
            const data = d.data();
            const createdAt = data.createdAt;
            const lastMessageAt = data.lastMessageAt;
            const userType = data.userType?.toLowerCase();
            return {
                id: d.id,
                role: userType === "driver" ? "driver" : "customer",
                subject: data.subject || "Support Inquiry",
                status: data.status || "active",
                isAccountLockout: Boolean(data.isAccountLockout),
                lastMessage: data.lastMessage || "",
                lastMessageAtMs: lastMessageAt ? lastMessageAt.toMillis() : Date.now(),
                createdAtMs: createdAt ? createdAt.toMillis() : Date.now(),
            };
        })
            .filter((c) => (role === "driver" ? c.role === "driver" : c.role === "customer"));
        chats.sort((a, b) => b.lastMessageAtMs - a.lastMessageAtMs);
        return { chats };
    }
});
/**
 * Scheduled task: Clean up expired locks & temporary IP restrictions
 */
exports.reconcileExpiredSecurityLocks = (0, scheduler_1.onSchedule)({
    schedule: "every 15 minutes",
    region: REGION_SCHEDULE,
    maxInstances: 1,
}, async () => {
    const db = admin.firestore();
    const now = admin.firestore.Timestamp.now();
    // 1. Expired Account Locks
    const expiredLocksSnap = await db
        .collection("security_account_locks")
        .where("status", "==", "active")
        .where("lockType", "==", "temporary")
        .where("expiresAt", "<=", now)
        .limit(50)
        .get();
    for (const doc of expiredLocksSnap.docs) {
        const data = doc.data();
        const uid = doc.id;
        try {
            await admin.auth().updateUser(uid, { disabled: false });
        }
        catch (err) {
            logger.warn("Reconciler failed to re-enable Auth user:", { uid, error: err.message });
        }
        await doc.ref.update({
            status: "expired",
            unlockedAt: admin.firestore.FieldValue.serverTimestamp(),
            unlockedReason: "scheduled_reconciliation_expiration",
        });
        await logSecurityAuditEvent(db, {
            eventType: "auto_unlock",
            severity: "low",
            targetUid: uid,
            targetEmail: data.email,
            accountType: data.accountType,
            ip: "system",
            endpoint: "reconcileExpiredSecurityLocks",
            actionTaken: "scheduled_auto_unlock",
            description: `Expired temporary lock for ${data.email || uid} cleared by scheduler.`,
        });
    }
    // 2. Expired IP Restrictions
    const expiredIpsSnap = await db
        .collection("security_ip_stats")
        .where("status", "==", "restricted")
        .where("restrictionType", "==", "temporary")
        .where("expiresAt", "<=", now)
        .limit(50)
        .get();
    for (const doc of expiredIpsSnap.docs) {
        const data = doc.data();
        await doc.ref.update({
            status: "active",
            restrictionType: "none",
            unblockedAt: admin.firestore.FieldValue.serverTimestamp(),
            unblockedReason: "scheduled_reconciliation_expiration",
        });
        await logSecurityAuditEvent(db, {
            eventType: "ip_unblocked",
            severity: "low",
            ip: data.ip || doc.id,
            endpoint: "reconcileExpiredSecurityLocks",
            actionTaken: "scheduled_ip_unblock",
            description: `Expired IP restriction for ${data.ip || doc.id} cleared by scheduler.`,
        });
    }
    logger.info("Security reconciliation finished", {
        reconciledLocks: expiredLocksSnap.size,
        reconciledIps: expiredIpsSnap.size,
    });
});
