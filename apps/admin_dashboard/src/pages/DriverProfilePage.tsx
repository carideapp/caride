import { useEffect, useMemo, useState } from 'react';
import { Link, useLocation, useParams } from 'react-router-dom';
import {
  addDoc,
  collection,
  doc,
  getCountFromServer,
  limit,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
  where,
  type DocumentData,
  type QuerySnapshot,
  type Timestamp,
} from 'firebase/firestore';
import { auth, db } from '../config/firebase';
import { logStaffActivity } from '../utils/staffAuditLogger';
import {
  DRIVER_DOCUMENT_LABELS,
  normalizeVehicleType,
  requiredDriverDocumentTypes,
  vehicleTypeLabel,
} from '../constants/driverVerification';
import { formatNgn } from '../util/money';

type TabId = 'overview' | 'vehicle' | 'documents' | 'activity' | 'wallet';

interface DriverDocRow {
  typeId: string;
  fileUrl: string;
  status: string;
  rejectionReason?: string | null;
  uploadedAt?: Timestamp | null;
  reviewedAt?: Timestamp | null;
}

interface WalletTxRow {
  id: string;
  type: string;
  amountNaira: number;
  description: string;
  createdAtMs: number;
}

interface HistoryRow {
  id: string;
  type: string;
  createdAtMs: number;
  payload: Record<string, unknown>;
}

interface VehicleReviewRow {
  status: string;
  rejectionReason?: string | null;
  oldValues?: Record<string, unknown> | null;
  newValues?: Record<string, unknown> | null;
  submittedAt?: Timestamp | null;
  reviewedAt?: Timestamp | null;
  reviewedByAdminUid?: string | null;
}

function formatTs(ts: Timestamp | undefined | null): string {
  if (!ts?.toDate) return '—';
  try {
    return ts.toDate().toLocaleString('en-NG');
  } catch {
    return '—';
  }
}

function docStatusLabel(row: DriverDocRow): { label: string; tone: 'muted' | 'warn' | 'ok' | 'error' } {
  if (!row.fileUrl) return { label: 'Not uploaded', tone: 'muted' };
  if (row.status === 'approved') return { label: 'Approved', tone: 'ok' };
  if (row.status === 'rejected') return { label: 'Rejected', tone: 'error' };
  return { label: 'Pending', tone: 'warn' };
}

function vehicleStatusLabel(status?: string): { label: string; toneClass: string } {
  if (status === 'approved') return { label: 'Approved', toneClass: 'badge--ok' };
  if (status === 'rejected') return { label: 'Rejected', toneClass: 'badge--error' };
  if (status === 'pending') return { label: 'Pending', toneClass: 'badge--warn' };
  return { label: 'Not submitted', toneClass: '' };
}

function approvalBadgeClass(approval: string): string {
  if (approval === 'approved') return 'badge--ok';
  if (approval === 'rejected') return 'badge--error';
  return 'badge--warn';
}

function formatVehicleSummary(vehicle?: DocumentData | null): string {
  if (!vehicle) return '—';
  return `${vehicle.year ?? ''} ${vehicle.make ?? ''} ${vehicle.model ?? ''}`.trim() || '—';
}

export function DriverProfilePage() {
  const { driverId } = useParams<{ driverId: string }>();
  const location = useLocation();
  const verificationMode = location.pathname.startsWith('/admin/verification-requests');
  const uid = driverId ?? '';

  const [tab, setTab] = useState<TabId>(verificationMode ? 'vehicle' : 'overview');
  const [driver, setDriver] = useState<DocumentData | null>(null);
  const [driverMissing, setDriverMissing] = useState(false);
  const [documents, setDocuments] = useState<Record<string, DriverDocRow>>({});
  const [vehicle, setVehicle] = useState<DocumentData | null>(null);
  const [vehicleReview, setVehicleReview] = useState<VehicleReviewRow | null>(null);
  const [referralCount, setReferralCount] = useState<number | null>(null);
  const [walletTxs, setWalletTxs] = useState<WalletTxRow[]>([]);
  const [historyRows, setHistoryRows] = useState<HistoryRow[]>([]);
  const [error, setError] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [pendingAction, setPendingAction] = useState(false);

  const [rejectDocType, setRejectDocType] = useState<string | null>(null);
  const [rejectDocReason, setRejectDocReason] = useState('');
  const [rejectVehicleOpen, setRejectVehicleOpen] = useState(false);
  const [rejectVehicleReason, setRejectVehicleReason] = useState('');
  const [rejectDriverOpen, setRejectDriverOpen] = useState(false);
  const [rejectDriverReason, setRejectDriverReason] = useState('');

  const adminUid = auth.currentUser?.uid ?? '';

  useEffect(() => {
    if (!uid) return undefined;
    setDriverMissing(false);
    const dref = doc(db, 'drivers', uid);
    const unsubD = onSnapshot(
      dref,
      (snap) => {
        if (!snap.exists()) {
          setDriver(null);
          setDriverMissing(true);
        } else {
          setDriver(snap.data());
          setDriverMissing(false);
        }
        setError(null);
      },
      (e) => setError(e.message),
    );

    const docsCol = collection(db, 'drivers', uid, 'documents');
    const unsubDocs = onSnapshot(
      docsCol,
      (snap) => {
        const next: Record<string, DriverDocRow> = {};
        snap.docs.forEach((d) => {
          const x = d.data();
          next[d.id] = {
            typeId: d.id,
            fileUrl: (x.fileUrl as string) || '',
            status: (x.status as string) || 'pending',
            rejectionReason: x.rejectionReason as string | undefined,
            uploadedAt: x.uploadedAt as Timestamp | undefined,
            reviewedAt: x.reviewedAt as Timestamp | undefined,
          };
        });
        setDocuments(next);
      },
      (e) => setError(e.message),
    );

    const approvedVehicleRef = doc(db, 'drivers', uid, 'vehicle', 'info');
    const unsubVehicle = onSnapshot(
      approvedVehicleRef,
      (snap) => setVehicle(snap.exists() ? snap.data() : null),
      () => setVehicle(null),
    );

    const vehicleReviewRef = doc(db, 'drivers', uid, 'vehicle', 'review');
    const unsubVehicleReview = onSnapshot(
      vehicleReviewRef,
      (snap) => {
        if (!snap.exists()) {
          setVehicleReview(null);
          return;
        }
        const data = snap.data();
        setVehicleReview({
          status: (data.status as string) || 'pending',
          rejectionReason: data.rejectionReason as string | null | undefined,
          oldValues: (data.oldValues as Record<string, unknown> | undefined) ?? null,
          newValues: (data.newValues as Record<string, unknown> | undefined) ?? null,
          submittedAt: data.submittedAt as Timestamp | undefined,
          reviewedAt: data.reviewedAt as Timestamp | undefined,
          reviewedByAdminUid: data.reviewedByAdminUid as string | undefined,
        });
      },
      () => setVehicleReview(null),
    );

    const historyQuery = query(
      collection(db, 'drivers', uid, 'verificationHistory'),
      orderBy('createdAt', 'desc'),
      limit(50),
    );
    const unsubHistory = onSnapshot(
      historyQuery,
      (snap) => {
        setHistoryRows(
          snap.docs.map((docSnap) => {
            const data = docSnap.data();
            const created = data.createdAt as Timestamp | undefined;
            return {
              id: docSnap.id,
              type: (data.type as string) || 'activity',
              createdAtMs: created?.toMillis?.() ?? 0,
              payload: data as Record<string, unknown>,
            };
          }),
        );
      },
      (e) => setError(e.message),
    );

    let cancelled = false;
    (async () => {
      try {
        const c = await getCountFromServer(collection(db, 'drivers', uid, 'referrals'));
        if (!cancelled) setReferralCount(c.data().count);
      } catch {
        if (!cancelled) setReferralCount(null);
      }
    })();

    const txQ = query(
      collection(db, 'walletTransactions'),
      where('uid', '==', uid),
      orderBy('createdAt', 'desc'),
      limit(100),
    );
    const unsubTx = onSnapshot(
      txQ,
      (snap: QuerySnapshot<DocumentData>) => {
        setWalletTxs(
          snap.docs.map((d) => {
            const x = d.data();
            const created = x.createdAt as Timestamp | undefined;
            return {
              id: d.id,
              type: (x.type as string) || '',
              amountNaira: (x.amountNaira as number) ?? 0,
              description: (x.description as string) || '',
              createdAtMs: created?.toMillis?.() ?? 0,
            };
          }),
        );
      },
      (e) => setError(e.message),
    );

    return () => {
      cancelled = true;
      unsubD();
      unsubDocs();
      unsubVehicle();
      unsubVehicleReview();
      unsubHistory();
      unsubTx();
    };
  }, [uid]);

  const activeVehicleType = normalizeVehicleType(
    (vehicleReview?.newValues?.vehicleType as string | undefined) ??
      (vehicle?.vehicleType as string | undefined),
  );

  const requiredDocTypes = useMemo(
    () => requiredDriverDocumentTypes(activeVehicleType),
    [activeVehicleType],
  );

  const mergedDocRows: DriverDocRow[] = useMemo(() => {
    return requiredDocTypes.map((typeId) => {
      const existing = documents[typeId];
      if (existing) return existing;
      return { typeId, fileUrl: '', status: 'pending' };
    });
  }, [documents, requiredDocTypes]);

  const approvedDocsCount = mergedDocRows.filter((row) => row.status === 'approved').length;
  const pendingDocsCount = mergedDocRows.filter((row) => row.fileUrl && row.status === 'pending').length;
  const rejectedDocsCount = mergedDocRows.filter((row) => row.status === 'rejected').length;

  async function copyUid() {
    try {
      await navigator.clipboard.writeText(uid);
    } catch {
      /* ignore */
    }
  }

  async function checkAndAutoApprove(updatedDocsMap?: Record<string, DriverDocRow>, vehicleStatusOverride?: string) {
    if (!uid || !adminUid) return;
    const docsToUse = updatedDocsMap ?? documents;
    const vStatus = vehicleStatusOverride ?? vehicleReview?.status;
    const allDocsApproved = requiredDocTypes.every((t) => docsToUse[t]?.status === 'approved');
    const vehicleApproved = !vStatus || vStatus === 'approved';

    if (allDocsApproved && vehicleApproved) {
      await updateDoc(doc(db, 'drivers', uid), {
        approvalStatus: 'approved',
        rejectionReason: null,
        updatedAt: serverTimestamp(),
      });
      await setDoc(
        doc(db, 'driverPresence', uid),
        { approvalStatusSnapshot: 'approved', updatedAt: serverTimestamp() },
        { merge: true },
      );
      await addDoc(collection(db, 'drivers', uid, 'verificationHistory'), {
        type: 'driver_approved_auto',
        adminUid,
        createdAt: serverTimestamp(),
      });
    }
  }

  async function approveDriverProfile() {
    if (!uid || !adminUid) return;
    setActionError(null);
    setPendingAction(true);
    try {
      await updateDoc(doc(db, 'drivers', uid), {
        approvalStatus: 'approved',
        rejectionReason: null,
        updatedAt: serverTimestamp(),
      });
      await setDoc(
        doc(db, 'driverPresence', uid),
        { approvalStatusSnapshot: 'approved', updatedAt: serverTimestamp() },
        { merge: true },
      );
      await addDoc(collection(db, 'drivers', uid, 'verificationHistory'), {
        type: 'driver_approved',
        adminUid,
        createdAt: serverTimestamp(),
      });
      logStaffActivity({
        page: 'verification',
        actionType: 'Approved Driver Profile',
        description: `Approved driver verification profile for ${driver?.fullName || driver?.email || uid}`,
        targetId: uid,
      });
    } catch (e) {
      setActionError(e instanceof Error ? e.message : 'Approval failed');
    } finally {
      setPendingAction(false);
    }
  }

  async function submitRejectDriver() {
    if (!uid || !adminUid) return;
    const reason = rejectDriverReason.trim();
    if (!reason) {
      setActionError('Rejection reason is required.');
      return;
    }
    setActionError(null);
    setPendingAction(true);
    try {
      await updateDoc(doc(db, 'drivers', uid), {
        approvalStatus: 'rejected',
        rejectionReason: reason,
        updatedAt: serverTimestamp(),
      });
      await setDoc(
        doc(db, 'driverPresence', uid),
        { approvalStatusSnapshot: 'rejected', isAvailableForRequests: false, updatedAt: serverTimestamp() },
        { merge: true },
      );
      await addDoc(collection(db, 'drivers', uid, 'verificationHistory'), {
        type: 'driver_rejected',
        reason,
        adminUid,
        createdAt: serverTimestamp(),
      });
      logStaffActivity({
        page: 'verification',
        actionType: 'Rejected Driver Profile',
        description: `Rejected driver verification profile for ${driver?.fullName || driver?.email || uid}. Reason: ${reason}`,
        targetId: uid,
      });
      setRejectDriverOpen(false);
      setRejectDriverReason('');
    } catch (e) {
      setActionError(e instanceof Error ? e.message : 'Rejection failed');
    } finally {
      setPendingAction(false);
    }
  }

  async function approveDocument(typeId: string) {
    if (!uid || !adminUid) return;
    setActionError(null);
    setPendingAction(true);
    try {
      await updateDoc(doc(db, 'drivers', uid, 'documents', typeId), {
        status: 'approved',
        rejectionReason: null,
        reviewedAt: serverTimestamp(),
        reviewedByAdminUid: adminUid,
      });
      const nextMap = { ...documents, [typeId]: { ...documents[typeId], status: 'approved' } };
      await checkAndAutoApprove(nextMap);
    } catch (e) {
      setActionError(e instanceof Error ? e.message : 'Update failed');
    } finally {
      setPendingAction(false);
    }
  }

  async function submitRejectDocument() {
    if (!uid || !rejectDocType || !adminUid) return;
    const reason = rejectDocReason.trim();
    if (!reason) {
      setActionError('Rejection reason is required.');
      return;
    }
    setActionError(null);
    setPendingAction(true);
    try {
      await updateDoc(doc(db, 'drivers', uid, 'documents', rejectDocType), {
        status: 'rejected',
        rejectionReason: reason,
        reviewedAt: serverTimestamp(),
        reviewedByAdminUid: adminUid,
      });
      setRejectDocType(null);
      setRejectDocReason('');
    } catch (e) {
      setActionError(e instanceof Error ? e.message : 'Update failed');
    } finally {
      setPendingAction(false);
    }
  }

  async function approveVehicleReview() {
    if (!uid || !adminUid || !vehicleReview) return;
    setActionError(null);
    setPendingAction(true);
    try {
      await updateDoc(doc(db, 'drivers', uid, 'vehicle', 'review'), {
        status: 'approved',
        rejectionReason: null,
        reviewedAt: serverTimestamp(),
        reviewedByAdminUid: adminUid,
      });
      await checkAndAutoApprove(documents, 'approved');
    } catch (e) {
      setActionError(e instanceof Error ? e.message : 'Update failed');
    } finally {
      setPendingAction(false);
    }
  }

  async function submitRejectVehicle() {
    if (!uid || !adminUid || !vehicleReview) return;
    const reason = rejectVehicleReason.trim();
    if (!reason) {
      setActionError('Rejection reason is required.');
      return;
    }
    setActionError(null);
    setPendingAction(true);
    try {
      await updateDoc(doc(db, 'drivers', uid, 'vehicle', 'review'), {
        status: 'rejected',
        rejectionReason: reason,
        reviewedAt: serverTimestamp(),
        reviewedByAdminUid: adminUid,
      });
      setRejectVehicleOpen(false);
      setRejectVehicleReason('');
    } catch (e) {
      setActionError(e instanceof Error ? e.message : 'Update failed');
    } finally {
      setPendingAction(false);
    }
  }

  if (!uid) {
    return <p className="muted">Missing driver ID.</p>;
  }

  const name = (driver?.fullName as string) || '(no name)';
  const email = (driver?.email as string) || '';
  const tier = (driver?.tier as string) || 'bronze';
  const approval = (driver?.approvalStatus as string) || 'draft';
  const vehicleReviewStatus = vehicleStatusLabel(vehicleReview?.status);
  const tabs: TabId[] = ['overview', 'vehicle', 'documents', 'activity', 'wallet'];

  return (
    <div>
      <div style={{ marginBottom: 'var(--space-4)', display: 'flex', gap: 12 }}>
        <Link to="/admin/users" className="btn btn--ghost" style={{ padding: '6px 12px', fontSize: '0.8rem' }}>
          ← Back to Users
        </Link>
        {verificationMode && (
          <Link to="/admin/verification-requests" className="btn btn--ghost" style={{ padding: '6px 12px', fontSize: '0.8rem' }}>
            Verification Queue
          </Link>
        )}
      </div>

      {verificationMode && (
        <div className="card" style={{ marginBottom: 'var(--space-5)', borderLeft: '4px solid var(--color-primary)' }}>
          <strong style={{ fontSize: '1rem' }}>Verification Checklist Mode</strong>
          <p className="muted" style={{ margin: 'var(--space-2) 0' }}>
            Review vehicle details and each document. The driver profile is approved only when vehicle status and all documents are in the approved state.
          </p>
          <div style={{ display: 'flex', gap: 'var(--space-3)', flexWrap: 'wrap', marginTop: 'var(--space-2)' }}>
            <span className="badge badge--info">Pending Docs: {pendingDocsCount}</span>
            <span className="badge badge--error">Rejected Docs: {rejectedDocsCount}</span>
            <span className={`badge ${vehicleReviewStatus.toneClass}`}>Vehicle Status: {vehicleReviewStatus.label}</span>
          </div>
          {pendingDocsCount === 0 && rejectedDocsCount === 0 && (vehicleReviewStatus.label === 'Approved' || vehicleReviewStatus.label === 'Not submitted') && approval !== 'approved' && (
            <div style={{ marginTop: 'var(--space-3)', padding: 'var(--space-3)', background: 'var(--color-success-light, #ecfdf5)', border: '1px solid var(--color-success, #10b981)', borderRadius: 'var(--radius-md)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 12 }}>
              <div>
                <strong style={{ color: '#065f46' }}>✓ All verification requirements met!</strong>
                <div style={{ fontSize: '0.85rem', color: '#047857', marginTop: 2 }}>
                  All required documents and vehicle information are approved. Click to activate this driver account.
                </div>
              </div>
              <button type="button" className="btn btn--primary" disabled={pendingAction} onClick={approveDriverProfile}>
                Approve Driver Profile Now
              </button>
            </div>
          )}
        </div>
      )}

      {error && <div className="field__error" style={{ marginBottom: 'var(--space-3)' }}>{error}</div>}
      {actionError && <div className="field__error" style={{ marginBottom: 'var(--space-3)' }}>{actionError}</div>}

      {driverMissing ? (
        <p className="muted">No driver document exists for this ID.</p>
      ) : !driver ? (
        <p className="muted">Loading profile…</p>
      ) : (
        <>
          {/* Driver profile header */}
          <div className="card animate-fade-in" style={{ marginBottom: 'var(--space-5)' }}>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 'var(--space-4)', alignItems: 'center' }}>
              <div className="admin-avatar" style={{ width: 64, height: 64, fontSize: '1.75rem', borderRadius: 'var(--radius-md)', background: 'linear-gradient(135deg, var(--color-primary), #059669)' }}>
                {name[0].toUpperCase()}
              </div>

              <div style={{ flex: 1 }}>
                <h2 style={{ margin: 0, fontSize: '1.5rem', fontWeight: 800, letterSpacing: '-0.02em' }}>{name}</h2>
                <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-3)', marginTop: 4, flexWrap: 'wrap' }}>
                  <span className="muted">{email}</span>
                  <span className="muted" style={{ fontSize: '0.85rem' }}>
                    UID: <code>{uid}</code>{' '}
                    <button
                      type="button"
                      className="btn btn--ghost"
                      style={{ padding: '2px 8px', fontSize: '0.7rem', height: 'fit-content' }}
                      onClick={copyUid}
                    >
                      Copy
                    </button>
                  </span>
                </div>
              </div>

              <div style={{ display: 'flex', gap: 'var(--space-2)', alignItems: 'center', flexWrap: 'wrap' }}>
                <span className="badge badge--ok" style={{ textTransform: 'capitalize' }}>
                  ★ {tier}
                </span>
                <span className={`badge ${approvalBadgeClass(approval)}`} style={{ textTransform: 'capitalize' }}>
                  {approval}
                </span>
                {approval !== 'approved' && (
                  <button
                    type="button"
                    className="btn btn--primary"
                    style={{ padding: '6px 14px', fontSize: '0.85rem' }}
                    disabled={pendingAction}
                    onClick={approveDriverProfile}
                  >
                    Approve Driver
                  </button>
                )}
                {approval !== 'rejected' && (
                  <button
                    type="button"
                    className="btn btn--ghost"
                    style={{ padding: '6px 14px', fontSize: '0.85rem' }}
                    disabled={pendingAction}
                    onClick={() => setRejectDriverOpen(true)}
                  >
                    Reject Driver
                  </button>
                )}
              </div>
            </div>
            {driver.rejectionReason && (
              <div style={{ 
                marginTop: 'var(--space-4)', 
                background: 'var(--color-error-light)', 
                color: 'var(--color-error)', 
                padding: 'var(--space-3)', 
                borderRadius: 'var(--radius-md)',
                fontSize: '0.85rem',
                fontWeight: 500
              }}>
                Current onboarding block: {String(driver.rejectionReason)}
              </div>
            )}
          </div>

          {/* Styled Tab Bar */}
          <div style={{ display: 'flex', gap: 'var(--space-2)', marginBottom: 'var(--space-5)', flexWrap: 'wrap', borderBottom: '1px solid var(--color-border)', paddingBottom: 'var(--space-3)' }}>
            {tabs.map((t) => (
              <button
                key={t}
                type="button"
                className={`btn ${tab === t ? 'btn--primary' : 'btn--ghost'}`}
                onClick={() => setTab(t)}
                style={{ textTransform: 'capitalize' }}
              >
                {t === 'activity' ? 'Verification Activity' : t}
              </button>
            ))}
          </div>

          {/* TAB 1: Overview */}
          {tab === 'overview' && (
            <div style={{ display: 'grid', gap: 'var(--space-5)' }}>
              <div
                className="card"
                style={{
                  display: 'grid',
                  gap: 'var(--space-4)',
                  gridTemplateColumns: 'repeat(auto-fill, minmax(200px, 1fr))',
                }}
              >
                <Stat label="Completed Rides" value={String(driver.completedRides ?? 0)} />
                <Stat label="Average Rating" value={(driver.averageRating as number)?.toFixed(2) ?? '0.00'} />
                <Stat label="Total Ratings" value={String(driver.totalRatings ?? 0)} />
                <Stat label="Wallet Balance" value={formatNgn((driver.walletBalance as number) ?? 0)} />
                <Stat label="Referral Code" value={(driver.referralCode as string) || '—'} />
                <Stat label="Referral Earnings" value={formatNgn((driver.referralEarnings as number) ?? 0)} />
                <Stat label="Drivers Referred" value={referralCount !== null ? String(referralCount) : '…'} />
                <Stat label="Documents Approved" value={`${approvedDocsCount}/${requiredDocTypes.length}`} />
                <Stat label="Vehicle Status" value={vehicleReviewStatus.label} />
                <Stat label="Profile Created" value={formatTs(driver.createdAt as Timestamp)} />
              </div>

              <div className="card">
                <h3 style={{ marginTop: 0, fontSize: '1.1rem', fontWeight: 700 }}>Approved Vehicle Details</h3>
                {!vehicle ? (
                  <p className="muted" style={{ margin: 0 }}>No approved vehicle info on file yet.</p>
                ) : (
                  <dl style={{ display: 'grid', gap: 'var(--space-2)', margin: 0 }}>
                    <Dd label="Summary" value={formatVehicleSummary(vehicle)} />
                    <Dd label="Plate Number" value={String(vehicle.plateNumber ?? '—')} />
                    <Dd label="Color & Style" value={`${vehicle.color ?? '—'} · ${vehicleTypeLabel(vehicle.vehicleType as string)}`} />
                    <Dd label="Seat Capacity" value={String(vehicle.seatCount ?? '—')} />
                  </dl>
                )}
              </div>
            </div>
          )}

          {/* TAB 2: Vehicle Info Review */}
          {tab === 'vehicle' && (
            <div style={{ display: 'grid', gap: 'var(--space-5)' }}>
              <div className="card">
                <div style={{ display: 'flex', justifyContent: 'space-between', gap: 'var(--space-3)', flexWrap: 'wrap', marginBottom: 'var(--space-4)' }}>
                  <div>
                    <h3 style={{ marginTop: 0, marginBottom: '4px', fontSize: '1.1rem', fontWeight: 700 }}>Vehicle Review</h3>
                    <p className="muted" style={{ margin: 0, fontSize: '0.85rem' }}>
                      Review updates and verify physical specifications.
                    </p>
                  </div>
                  <span className={`badge ${vehicleReviewStatus.toneClass}`}>{vehicleReviewStatus.label}</span>
                </div>
                
                {!vehicleReview ? (
                  <p className="muted" style={{ marginBottom: 0 }}>
                    No pending vehicle changes submitted. Current details are shown below.
                  </p>
                ) : (
                  <>
                    <div className="muted" style={{ fontSize: '0.8rem', marginBottom: 'var(--space-3)' }}>
                      Submitted: {formatTs(vehicleReview.submittedAt)} · Reviewed: {formatTs(vehicleReview.reviewedAt)}
                    </div>
                    {vehicleReview.rejectionReason && (
                      <div className="field__error" style={{ marginBottom: 'var(--space-3)' }}>{vehicleReview.rejectionReason}</div>
                    )}
                    
                    <VehicleDiffCard oldValues={vehicleReview.oldValues ?? null} newValues={vehicleReview.newValues ?? null} />
                    
                    {verificationMode && vehicleReview.status === 'pending' && (
                      <div style={{ display: 'flex', gap: 'var(--space-2)', marginTop: 'var(--space-4)' }}>
                        <button type="button" className="btn btn--primary" disabled={pendingAction} onClick={approveVehicleReview}>
                          Approve Vehicle Info
                        </button>
                        <button type="button" className="btn btn--ghost" disabled={pendingAction} onClick={() => setRejectVehicleOpen(true)}>
                          Reject Changes
                        </button>
                      </div>
                    )}
                  </>
                )}
              </div>

              <div className="card">
                <h3 style={{ marginTop: 0, fontSize: '1.1rem', fontWeight: 700 }}>Approved Vehicle Details</h3>
                {!vehicle ? (
                  <p className="muted" style={{ margin: 0 }}>No approved vehicle info on file.</p>
                ) : (
                  <dl style={{ display: 'grid', gap: 'var(--space-2)', margin: 0 }}>
                    <Dd label="Summary" value={formatVehicleSummary(vehicle)} />
                    <Dd label="Plate" value={String(vehicle.plateNumber ?? '—')} />
                    <Dd label="Color" value={String(vehicle.color ?? '—')} />
                    <Dd label="Vehicle Type" value={vehicleTypeLabel(vehicle.vehicleType as string)} />
                    <Dd label="Seats" value={String(vehicle.seatCount ?? '—')} />
                  </dl>
                )}
              </div>
            </div>
          )}

          {/* TAB 3: Documents Review */}
          {tab === 'documents' && (
            <div className="card" style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-2)' }}>
              <div style={{ borderBottom: '1px solid var(--color-border)', paddingBottom: 'var(--space-3)', marginBottom: 'var(--space-3)' }}>
                <span className="badge badge--info">
                  Required: {vehicleTypeLabel(activeVehicleType)} ({requiredDocTypes.length} Items)
                </span>
              </div>
              
              {mergedDocRows.map((row) => {
                const { label, tone } = docStatusLabel(row);
                const badgeClass = tone === 'ok' ? 'badge--ok' : tone === 'error' ? 'badge--error' : 'badge--warn';
                const human = DRIVER_DOCUMENT_LABELS[row.typeId] ?? row.typeId;
                const showActions = verificationMode && (row.fileUrl || row.typeId === 'guarantor_info') && row.status === 'pending';
                
                return (
                  <div key={row.typeId} className="table-row" style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 16 }}>
                    <div style={{ flex: 1, minWidth: 260 }}>
                      <div style={{ fontWeight: 700, fontSize: '0.95rem' }}>{human}</div>
                      <div className="muted" style={{ fontSize: '0.8rem', marginTop: 4 }}>
                        Uploaded: {formatTs(row.uploadedAt)} · Reviewed: {formatTs(row.reviewedAt)}
                      </div>
                      {row.rejectionReason && (
                        <div style={{ color: 'var(--color-error)', fontSize: '0.8rem', marginTop: 4, fontWeight: 500 }}>
                          Reason: {String(row.rejectionReason)}
                        </div>
                      )}
                      {row.typeId === 'guarantor_info' && driver && (driver.guarantorName || (row as any).fullName) ? (
                        <div style={{ background: 'var(--color-bg-subtle, #f8f9fc)', padding: '8px 12px', borderRadius: '6px', marginTop: 8, fontSize: '0.8rem', border: '1px solid var(--color-border)' }}>
                          <div><strong>Guarantor:</strong> {driver.guarantorName || (row as any).fullName || '—'}</div>
                          <div><strong>Phone:</strong> {driver.guarantorPhone || (row as any).phone || '—'}</div>
                          <div><strong>Relationship:</strong> {driver.guarantorRelationship || (row as any).relationship || '—'}</div>
                          <div><strong>Address:</strong> {driver.guarantorAddress || (row as any).address || '—'}</div>
                        </div>
                      ) : null}
                      <div style={{ marginTop: 8 }}>
                        {row.fileUrl ? (
                          <a href={row.fileUrl} target="_blank" rel="noreferrer" className="btn btn--ghost" style={{ padding: '4px 10px', fontSize: '0.75rem' }}>
                            View Uploaded Document
                          </a>
                        ) : row.typeId === 'guarantor_info' && (driver?.guarantorName || (row as any).fullName) ? (
                          <span style={{ fontSize: '0.8rem', color: 'var(--color-success)', fontWeight: 600 }}>Form Details Submitted</span>
                        ) : (
                          <span className="muted" style={{ fontSize: '0.8rem' }}>Not uploaded</span>
                        )}
                      </div>
                    </div>
                    
                    <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-3)' }}>
                      <span className={`badge ${badgeClass}`}>{label}</span>
                      
                      {showActions && (
                        <div style={{ display: 'flex', gap: 'var(--space-1)' }}>
                          <button
                            type="button"
                            className="btn btn--primary"
                            style={{ padding: '4px 10px', fontSize: '0.8rem' }}
                            disabled={pendingAction}
                            onClick={() => approveDocument(row.typeId)}
                          >
                            Approve
                          </button>
                          <button
                            type="button"
                            className="btn btn--ghost"
                            style={{ padding: '4px 10px', fontSize: '0.8rem' }}
                            disabled={pendingAction}
                            onClick={() => setRejectDocType(row.typeId)}
                          >
                            Reject
                          </button>
                        </div>
                      )}
                    </div>
                  </div>
                );
              })}
            </div>
          )}

          {/* TAB 4: Verification Activity */}
          {tab === 'activity' && (
            <div className="card" style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              {historyRows.length === 0 ? (
                <p className="muted" style={{ margin: 0 }}>No verification history found.</p>
              ) : (
                historyRows.map((row) => <HistoryEntry key={row.id} row={row} />)
              )}
            </div>
          )}

          {/* TAB 5: Wallet Transactions */}
          {tab === 'wallet' && (
            <div className="card" style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              {walletTxs.length === 0 ? (
                <p className="muted" style={{ margin: 0 }}>No wallet transactions logged.</p>
              ) : (
                walletTxs.map((tx) => (
                  <div key={tx.id} className="table-row" style={{ flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' }}>
                    <div style={{ flex: 1 }}>
                      <div style={{ fontWeight: 600 }}>{tx.description || tx.type}</div>
                      <div className="muted" style={{ fontSize: '0.8rem', marginTop: 2 }}>
                        {tx.type} · {new Date(tx.createdAtMs).toLocaleString('en-NG')}
                      </div>
                    </div>
                    <span style={{ fontWeight: 700, color: tx.amountNaira < 0 ? 'var(--color-error)' : 'var(--color-primary)' }}>
                      {tx.amountNaira < 0 ? '' : '+'}{formatNgn(tx.amountNaira)}
                    </span>
                  </div>
                ))
              )}
            </div>
          )}
        </>
      )}

      {/* Reject Document dialog modal */}
      {rejectDocType && (
        <div
          style={{
            position: 'fixed',
            inset: 0,
            background: 'rgba(15,23,42,0.45)',
            backdropFilter: 'blur(8px)',
            WebkitBackdropFilter: 'blur(8px)',
            display: 'grid',
            placeItems: 'center',
            zIndex: 1000,
            padding: 'var(--space-4)',
          }}
          role="dialog"
          aria-modal
        >
          <div className="card" style={{ maxWidth: 440, width: '100%' }}>
            <h3 style={{ marginTop: 0, fontSize: '1.1rem', fontWeight: 700 }}>Reject Document</h3>
            <p className="muted" style={{ fontSize: '0.85rem' }}>{DRIVER_DOCUMENT_LABELS[rejectDocType] ?? rejectDocType}</p>
            
            <div className="field">
              <label htmlFor="rejectDocReason">Rejection Reason</label>
              <textarea
                id="rejectDocReason"
                rows={3}
                placeholder="Indicate why this document is invalid or blurry..."
                value={rejectDocReason}
                onChange={(e) => setRejectDocReason(e.target.value)}
              />
            </div>
            <div style={{ display: 'flex', gap: 'var(--space-2)', justifyContent: 'flex-end', marginTop: 'var(--space-4)' }}>
              <button
                type="button"
                className="btn btn--ghost"
                onClick={() => {
                  setRejectDocType(null);
                  setRejectDocReason('');
                }}
              >
                Cancel
              </button>
              <button type="button" className="btn btn--primary" disabled={pendingAction} onClick={submitRejectDocument}>
                Reject Document
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Reject Vehicle dialog modal */}
      {rejectVehicleOpen && (
        <div
          style={{
            position: 'fixed',
            inset: 0,
            background: 'rgba(15,23,42,0.45)',
            backdropFilter: 'blur(8px)',
            WebkitBackdropFilter: 'blur(8px)',
            display: 'grid',
            placeItems: 'center',
            zIndex: 1000,
            padding: 'var(--space-4)',
          }}
          role="dialog"
          aria-modal
        >
          <div className="card" style={{ maxWidth: 440, width: '100%' }}>
            <h3 style={{ marginTop: 0, fontSize: '1.1rem', fontWeight: 700 }}>Reject Vehicle Info</h3>
            
            <div className="field">
              <label htmlFor="rejectVehicleReason">Rejection Reason</label>
              <textarea
                id="rejectVehicleReason"
                rows={3}
                placeholder="Describe specifications discrepancies (e.g. invalid plate)..."
                value={rejectVehicleReason}
                onChange={(e) => setRejectVehicleReason(e.target.value)}
              />
            </div>
            
            <div style={{ display: 'flex', gap: 'var(--space-2)', justifyContent: 'flex-end', marginTop: 'var(--space-4)' }}>
              <button
                type="button"
                className="btn btn--ghost"
                onClick={() => {
                  setRejectVehicleOpen(false);
                  setRejectVehicleReason('');
                }}
              >
                Cancel
              </button>
              <button type="button" className="btn btn--primary" disabled={pendingAction} onClick={submitRejectVehicle}>
                Reject Vehicle Info
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Reject Driver Profile dialog modal */}
      {rejectDriverOpen && (
        <div
          style={{
            position: 'fixed',
            inset: 0,
            background: 'rgba(15,23,42,0.45)',
            backdropFilter: 'blur(8px)',
            WebkitBackdropFilter: 'blur(8px)',
            display: 'grid',
            placeItems: 'center',
            zIndex: 1000,
            padding: 'var(--space-4)',
          }}
          role="dialog"
          aria-modal
        >
          <div className="card" style={{ maxWidth: 440, width: '100%' }}>
            <h3 style={{ marginTop: 0, fontSize: '1.1rem', fontWeight: 700 }}>Reject Driver Onboarding Profile</h3>
            
            <div className="field">
              <label htmlFor="rejectDriverReason">Rejection Reason</label>
              <textarea
                id="rejectDriverReason"
                rows={3}
                placeholder="Explain why the driver onboarding application is rejected..."
                value={rejectDriverReason}
                onChange={(e) => setRejectDriverReason(e.target.value)}
              />
            </div>
            
            <div style={{ display: 'flex', gap: 'var(--space-2)', justifyContent: 'flex-end', marginTop: 'var(--space-4)' }}>
              <button
                type="button"
                className="btn btn--ghost"
                onClick={() => {
                  setRejectDriverOpen(false);
                  setRejectDriverReason('');
                }}
              >
                Cancel
              </button>
              <button type="button" className="btn btn--primary" disabled={pendingAction} onClick={submitRejectDriver}>
                Reject Driver Profile
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

// ─── Sub-components ───────────────────────────────────────────────────────────

function Stat({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
      <div className="muted" style={{ fontSize: '0.75rem', fontWeight: 600 }}>
        {label}
      </div>
      <div style={{ fontSize: '1.1rem', fontWeight: 700 }}>{value}</div>
    </div>
  );
}

function Dd({ label, value }: { label: string; value: string }) {
  return (
    <div style={{ display: 'grid', gridTemplateColumns: '140px 1fr', gap: 'var(--space-2)', borderBottom: '1px solid var(--color-border)', padding: '8px 0' }}>
      <dt className="muted" style={{ margin: 0, fontWeight: 600, fontSize: '0.85rem' }}>
        {label}
      </dt>
      <dd style={{ margin: 0, fontWeight: 500, fontSize: '0.85rem' }}>{value}</dd>
    </div>
  );
}

function VehicleDiffCard({
  oldValues,
  newValues,
}: {
  oldValues: Record<string, unknown> | null;
  newValues: Record<string, unknown> | null;
}) {
  const rows: Array<[string, unknown, unknown]> = [
    ['Make', oldValues?.['make'], newValues?.['make']] as [string, unknown, unknown],
    ['Model', oldValues?.['model'], newValues?.['model']] as [string, unknown, unknown],
    ['Year', oldValues?.['year'], newValues?.['year']] as [string, unknown, unknown],
    ['Color', oldValues?.['color'], newValues?.['color']] as [string, unknown, unknown],
    ['Plate Number', oldValues?.['plateNumber'], newValues?.['plateNumber']] as [string, unknown, unknown],
    ['Vehicle Type', oldValues?.['vehicleType'], newValues?.['vehicleType']] as [string, unknown, unknown],
    ['Seat Count', oldValues?.['seatCount'], newValues?.['seatCount']] as [string, unknown, unknown],
  ].filter(([, , next]) => next != null);

  return (
    <div style={{ display: 'grid', gap: 'var(--space-1)', background: 'var(--color-bg-alt)', padding: '16px', borderRadius: 'var(--radius-md)', border: '1px solid var(--color-border)' }}>
      {rows.map(([label, previousValue, nextValue]) => (
        <div
          key={String(label)}
          style={{
            display: 'grid',
            gridTemplateColumns: '140px 1fr',
            gap: 'var(--space-2)',
            padding: 'var(--space-2) 0',
            borderBottom: '1px solid var(--color-border)',
          }}
        >
          <div className="muted" style={{ fontSize: '0.8rem', fontWeight: 600 }}>{label}</div>
          <div style={{ fontSize: '0.85rem' }}>
            {previousValue != null && (
              <>
                <span style={{ textDecoration: 'line-through', color: 'var(--color-text-muted)' }}>{String(previousValue)}</span>
                <span className="muted" style={{ fontSize: '0.75rem' }}> (Old)</span>
                <span className="muted"> → </span>
              </>
            )}
            <span style={{ fontWeight: 600, color: 'var(--color-primary-active)' }}>{String(nextValue)}</span>
            <span className="muted" style={{ fontSize: '0.75rem' }}> (New)</span>
          </div>
        </div>
      ))}
    </div>
  );
}

function HistoryEntry({ row }: { row: HistoryRow }) {
  const rejectionReason = row.payload.rejectionReason as string | undefined;
  const documentType = row.payload.documentType as string | undefined;
  const bankName = row.payload.bankName as string | undefined;

  return (
    <div className="table-row" style={{ flexDirection: 'row', alignItems: 'flex-start', gap: 12 }}>
      <div style={{ width: 8, height: 8, borderRadius: '50%', background: 'var(--color-primary)', marginTop: 6 }} />
      <div style={{ flex: 1 }}>
        <div style={{ fontWeight: 700, fontSize: '0.9rem' }}>{row.type.replaceAll('_', ' ')}</div>
        <div className="muted" style={{ fontSize: '0.75rem', marginTop: 2 }}>
          {new Date(row.createdAtMs).toLocaleString('en-NG')}
        </div>
        {documentType && <div className="muted" style={{ fontSize: '0.8rem', marginTop: 4 }}>Document: {DRIVER_DOCUMENT_LABELS[documentType] ?? documentType}</div>}
        {bankName && <div className="muted" style={{ fontSize: '0.8rem', marginTop: 4 }}>Bank: {bankName}</div>}
        {rejectionReason && (
          <div style={{ color: 'var(--color-error)', fontSize: '0.8rem', marginTop: 4, fontWeight: 500 }}>
            Rejection: {rejectionReason}
          </div>
        )}
      </div>
    </div>
  );
}
