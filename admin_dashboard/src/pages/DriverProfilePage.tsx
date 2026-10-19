import { useEffect, useMemo, useState } from 'react';
import { Link, useLocation, useParams, useSearchParams } from 'react-router-dom';
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
  Timestamp,
  type DocumentData,
  type QuerySnapshot,
} from 'firebase/firestore';
import { getDownloadURL, ref, uploadBytesResumable } from 'firebase/storage';
import { auth, db, storage } from '../config/firebase';
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
  reviewedByAdminUid?: string | null;
}

const QUICK_REJECTION_REASONS = [
  'Blurry or unreadable document photo',
  'Document has expired',
  'Name does not match driver account profile',
  'Incorrect document type uploaded',
  'Document edges cut off / incomplete image',
  'Document appears altered or invalid',
  'Vehicle details do not match registration',
];

function isDocSubmitted(row: DriverDocRow, driverData: DocumentData | null): boolean {
  if (row.fileUrl) return true;
  if (row.typeId === 'guarantor_info' && (driverData?.guarantorName || (driverData as any)?.guarantorFullName || (row as any).fullName)) {
    return true;
  }
  return false;
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
  const [searchParams, setSearchParams] = useSearchParams();
  const verificationMode = location.pathname.startsWith('/admin/verification-requests');
  const uid = driverId ?? '';

  const queryTab = searchParams.get('tab') as TabId | null;
  const initialTab: TabId = (queryTab && ['overview', 'vehicle', 'documents', 'activity', 'wallet'].includes(queryTab))
    ? queryTab
    : (verificationMode ? 'documents' : 'overview');

  const [tab, setTab] = useState<TabId>(initialTab);
  const [docFilter, setDocFilter] = useState<'all' | 'pending' | 'approved' | 'rejected' | 'missing'>('all');
  const [previewDoc, setPreviewDoc] = useState<{
    typeId: string;
    fileUrl: string;
    title: string;
    status: string;
    rejectionReason?: string | null;
    uploadedAt?: Timestamp | null;
  } | null>(null);
  const [confirmForceApproveOpen, setConfirmForceApproveOpen] = useState(false);
  const [confirmBulkApproveOpen, setConfirmBulkApproveOpen] = useState(false);

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

  // Admin editing of driver profile
  const [editProfileOpen, setEditProfileOpen] = useState(false);
  const [editFullName, setEditFullName] = useState('');
  const [editPhone, setEditPhone] = useState('');
  const [editPhotoUrl, setEditPhotoUrl] = useState('');
  const [newPhotoFile, setNewPhotoFile] = useState<File | null>(null);
  const [previewPhotoUrl, setPreviewPhotoUrl] = useState<string | null>(null);
  const [editSaving, setEditSaving] = useState(false);
  const [editError, setEditError] = useState<string | null>(null);
  const [editSuccess, setEditSuccess] = useState<string | null>(null);

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
    () =>
      requiredDriverDocumentTypes(
        activeVehicleType,
        (driver?.state as string | undefined) ?? (driver as any)?.operatingState,
      ),
    [activeVehicleType, driver?.state, (driver as any)?.operatingState],
  );

  const mergedDocRows: DriverDocRow[] = useMemo(() => {
    return requiredDocTypes.map((typeId) => {
      const existing = documents[typeId];
      if (existing) return existing;
      return { typeId, fileUrl: '', status: 'pending' };
    });
  }, [documents, requiredDocTypes]);

  const approvedDocsCount = mergedDocRows.filter((row) => row.status === 'approved').length;
  const pendingDocsCount = mergedDocRows.filter((row) => isDocSubmitted(row, driver) && row.status === 'pending').length;
  const rejectedDocsCount = mergedDocRows.filter((row) => row.status === 'rejected').length;
  const missingDocsCount = mergedDocRows.filter((row) => !isDocSubmitted(row, driver)).length;

  const filteredDocRows = useMemo(() => {
    let list = mergedDocRows;
    if (docFilter === 'pending') {
      list = list.filter((r) => isDocSubmitted(r, driver) && r.status === 'pending');
    } else if (docFilter === 'approved') {
      list = list.filter((r) => r.status === 'approved');
    } else if (docFilter === 'rejected') {
      list = list.filter((r) => r.status === 'rejected');
    } else if (docFilter === 'missing') {
      list = list.filter((r) => !isDocSubmitted(r, driver));
    }
    // Sort: Pending documents at the top, then rejected, then approved, then not uploaded
    return [...list].sort((a, b) => {
      const aSubmitted = isDocSubmitted(a, driver);
      const bSubmitted = isDocSubmitted(b, driver);
      const aScore = aSubmitted && a.status === 'pending' ? 0 : a.status === 'rejected' ? 1 : aSubmitted ? 2 : 3;
      const bScore = bSubmitted && b.status === 'pending' ? 0 : b.status === 'rejected' ? 1 : bSubmitted ? 2 : 3;
      return aScore - bScore;
    });
  }, [mergedDocRows, docFilter, driver]);

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
      setConfirmForceApproveOpen(false);
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
      await addDoc(collection(db, 'drivers', uid, 'verificationHistory'), {
        type: 'document_approved',
        documentType: typeId,
        adminUid,
        createdAt: serverTimestamp(),
      });
      logStaffActivity({
        page: 'verification',
        actionType: 'Approved Driver Document',
        description: `Approved document "${DRIVER_DOCUMENT_LABELS[typeId] || typeId}" for driver ${driver?.fullName || driver?.email || uid}`,
        targetId: uid,
      });
      const nextMap = {
        ...documents,
        [typeId]: {
          ...documents[typeId],
          typeId,
          fileUrl: documents[typeId]?.fileUrl || '',
          status: 'approved',
          rejectionReason: null,
          reviewedAt: Timestamp.now(),
        },
      };
      setDocuments(nextMap);
      if (previewDoc && previewDoc.typeId === typeId) {
        setPreviewDoc((prev) => (prev ? { ...prev, status: 'approved', rejectionReason: null } : null));
      }
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
      await addDoc(collection(db, 'drivers', uid, 'verificationHistory'), {
        type: 'document_rejected',
        documentType: rejectDocType,
        reason,
        adminUid,
        createdAt: serverTimestamp(),
      });
      logStaffActivity({
        page: 'verification',
        actionType: 'Rejected Driver Document',
        description: `Rejected document "${DRIVER_DOCUMENT_LABELS[rejectDocType] || rejectDocType}" for driver ${driver?.fullName || driver?.email || uid}. Reason: ${reason}`,
        targetId: uid,
      });
      const nextMap = {
        ...documents,
        [rejectDocType]: {
          ...documents[rejectDocType],
          typeId: rejectDocType,
          fileUrl: documents[rejectDocType]?.fileUrl || '',
          status: 'rejected',
          rejectionReason: reason,
          reviewedAt: Timestamp.now(),
        },
      };
      setDocuments(nextMap);
      if (previewDoc && previewDoc.typeId === rejectDocType) {
        setPreviewDoc((prev) => (prev ? { ...prev, status: 'rejected', rejectionReason: reason } : null));
      }
      setRejectDocType(null);
      setRejectDocReason('');
    } catch (e) {
      setActionError(e instanceof Error ? e.message : 'Update failed');
    } finally {
      setPendingAction(false);
    }
  }

  async function bulkApprovePendingDocs() {
    if (!uid || !adminUid) return;
    setActionError(null);
    setPendingAction(true);
    try {
      const pendingRows = mergedDocRows.filter((r) => isDocSubmitted(r, driver) && r.status === 'pending');
      const nextMap = { ...documents };
      for (const r of pendingRows) {
        await updateDoc(doc(db, 'drivers', uid, 'documents', r.typeId), {
          status: 'approved',
          rejectionReason: null,
          reviewedAt: serverTimestamp(),
          reviewedByAdminUid: adminUid,
        });
        await addDoc(collection(db, 'drivers', uid, 'verificationHistory'), {
          type: 'document_approved',
          documentType: r.typeId,
          adminUid,
          createdAt: serverTimestamp(),
        });
        nextMap[r.typeId] = {
          ...(nextMap[r.typeId] || r),
          status: 'approved',
          rejectionReason: null,
          reviewedAt: Timestamp.now(),
        };
      }
      logStaffActivity({
        page: 'verification',
        actionType: 'Bulk Approved Documents',
        description: `Bulk approved ${pendingRows.length} documents for driver ${driver?.fullName || driver?.email || uid}`,
        targetId: uid,
      });
      setDocuments(nextMap);
      setConfirmBulkApproveOpen(false);
      await checkAndAutoApprove(nextMap);
    } catch (e) {
      setActionError(e instanceof Error ? e.message : 'Bulk approval failed');
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

  function openEditModal() {
    const currentName = (driver?.fullName as string) || '';
    const currentPhone = (driver?.phone as string) || '';
    const currentPhoto = (driver?.profilePhotoUrl as string) || '';
    setEditFullName(currentName);
    setEditPhone(currentPhone);
    setEditPhotoUrl(currentPhoto);
    setPreviewPhotoUrl(currentPhoto);
    setNewPhotoFile(null);
    setEditError(null);
    setEditSuccess(null);
    setEditProfileOpen(true);
  }

  function handlePhotoFileChange(e: React.ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    if (!file) return;

    if (!file.type.startsWith('image/')) {
      setEditError('Please select a valid image file (PNG, JPG, WebP).');
      return;
    }
    if (file.size > 10 * 1024 * 1024) {
      setEditError('Image size exceeds 10MB. Please select a smaller image.');
      return;
    }

    setNewPhotoFile(file);
    setPreviewPhotoUrl(URL.createObjectURL(file));
    setEditError(null);
  }

  function handleRemovePhoto() {
    setNewPhotoFile(null);
    setPreviewPhotoUrl('');
    setEditPhotoUrl('');
  }

  async function submitEditProfile(e?: React.FormEvent) {
    if (e) e.preventDefault();
    if (!uid) return;
    const trimmedName = editFullName.trim();
    const trimmedPhone = editPhone.trim();

    if (!trimmedName) {
      setEditError('Driver full name is required.');
      return;
    }

    setEditSaving(true);
    setEditError(null);

    try {
      let finalPhotoUrl = editPhotoUrl.trim();

      // If an image file was selected, upload to Firebase Storage
      if (newPhotoFile) {
        const photoRef = ref(storage, `driver_profile_photos/${uid}/profile_${Date.now()}.jpg`);
        const uploadTask = await uploadBytesResumable(photoRef, newPhotoFile);
        finalPhotoUrl = await getDownloadURL(uploadTask.ref);
      }

      // Update primary driver document in Firestore
      await updateDoc(doc(db, 'drivers', uid), {
        fullName: trimmedName,
        phone: trimmedPhone,
        profilePhotoUrl: finalPhotoUrl,
        updatedAt: serverTimestamp(),
      });

      // Synchronize driver verification document for profile_photo
      if (finalPhotoUrl) {
        try {
          await setDoc(
            doc(db, 'drivers', uid, 'documents', 'profile_photo'),
            {
              typeId: 'profile_photo',
              fileUrl: finalPhotoUrl,
              status: 'approved',
              reviewedAt: serverTimestamp(),
              reviewedByAdminUid: adminUid || 'admin',
              updatedAt: serverTimestamp(),
            },
            { merge: true },
          );
        } catch (err) {
          console.warn('Could not update documents/profile_photo record:', err);
        }
      }

      // Sync with users collection if exists
      try {
        await setDoc(
          doc(db, 'users', uid),
          {
            fullName: trimmedName,
            phone: trimmedPhone,
            photoUrl: finalPhotoUrl,
            updatedAt: serverTimestamp(),
          },
          { merge: true },
        );
      } catch (err) {
        console.warn('Sync to users doc warning:', err);
      }

      // Sync with customers collection if exists
      try {
        await updateDoc(doc(db, 'customers', uid), {
          fullName: trimmedName,
          phone: trimmedPhone,
          photoUrl: finalPhotoUrl,
          updatedAt: serverTimestamp(),
        });
      } catch {
        /* ignore */
      }

      // Log staff activity audit
      try {
        await logStaffActivity({
          page: 'verification',
          actionType: 'Updated Driver Profile',
          description: `Updated profile details for driver ${trimmedName} (${uid}). Phone: ${trimmedPhone || 'none'}, Photo updated: ${Boolean(newPhotoFile || finalPhotoUrl !== driver?.profilePhotoUrl)}.`,
          targetId: uid,
        });
      } catch (err) {
        console.warn('Audit log error:', err);
      }

      // Record in verification history
      try {
        await addDoc(collection(db, 'drivers', uid, 'verificationHistory'), {
          type: 'profile_updated_by_admin',
          createdAt: serverTimestamp(),
          adminUid: adminUid || 'admin',
          payload: {
            fullName: trimmedName,
            phone: trimmedPhone,
            hasPhoto: Boolean(finalPhotoUrl),
          },
        });
      } catch (err) {
        console.warn('History log error:', err);
      }

      setEditSuccess('Driver profile updated successfully!');
      setTimeout(() => {
        setEditProfileOpen(false);
      }, 700);
    } catch (err) {
      setEditError(err instanceof Error ? err.message : 'Failed to update profile');
    } finally {
      setEditSaving(false);
    }
  }

  if (!uid) {
    return <p className="muted">Missing driver ID.</p>;
  }

  const name = (driver?.fullName as string) || '(no name)';
  const email = (driver?.email as string) || '';
  const phone = (driver?.phone as string) || '';
  const photoUrl = (driver?.profilePhotoUrl as string) || '';
  const tier = (driver?.tier as string) || 'bronze';
  const approval = (driver?.approvalStatus as string) || 'draft';
  const state = (driver?.state as string) || (driver as any)?.operatingState || '';
  const vehicleReviewStatus = vehicleStatusLabel(vehicleReview?.status);
  const tabs: TabId[] = ['overview', 'vehicle', 'documents', 'activity', 'wallet'];

  return (
    <div>
      <div style={{ marginBottom: 'var(--space-4)', display: 'flex', gap: 12 }}>
        <Link to="/admin/users" className="btn btn--ghost" style={{ padding: '6px 14px', fontSize: '0.8rem', borderRadius: 'var(--radius-full)' }}>
          ← Back to Users
        </Link>
        {verificationMode && (
          <Link to="/admin/verification-requests" className="btn btn--ghost" style={{ padding: '6px 14px', fontSize: '0.8rem', borderRadius: 'var(--radius-full)' }}>
            Verification Queue
          </Link>
        )}
      </div>

      {/* Verification Checklist / Status Banner */}
      {(verificationMode || approval !== 'approved') && (
        <div
          className="card"
          style={{
            marginBottom: 'var(--space-5)',
            borderLeft: '4px solid var(--color-primary)',
            borderRadius: 'var(--radius-xl)',
            background: 'var(--color-surface)',
          }}
        >
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: 12 }}>
            <div>
              <strong style={{ fontSize: '1rem', display: 'flex', alignItems: 'center', gap: 8 }}>
                <span>🛡️ Driver Verification Checklist</span>
                <span className={`badge ${approvalBadgeClass(approval)}`} style={{ fontSize: '0.75rem' }}>
                  Account: {approval}
                </span>
              </strong>
              <p className="muted" style={{ margin: '6px 0 0 0', fontSize: '0.85rem' }}>
                Review individual documents and vehicle specifications. Account is verified only when vehicle status and all required documents are approved.
              </p>
            </div>
            {pendingDocsCount > 0 && (
              <button
                type="button"
                className="btn btn--primary"
                style={{ padding: '6px 14px', fontSize: '0.8rem', borderRadius: 'var(--radius-full)' }}
                onClick={() => {
                  setTab('documents');
                  setDocFilter('pending');
                  setSearchParams({ tab: 'documents' }, { replace: true });
                }}
              >
                Review {pendingDocsCount} Pending Documents →
              </button>
            )}
          </div>

          <div style={{ display: 'flex', gap: 'var(--space-2)', flexWrap: 'wrap', marginTop: 'var(--space-3)' }}>
            <button
              type="button"
              className="btn btn--ghost"
              style={{
                padding: '4px 10px',
                fontSize: '0.8rem',
                borderRadius: 'var(--radius-full)',
                background: pendingDocsCount > 0 ? 'rgba(245, 158, 11, 0.15)' : 'var(--color-bg-alt)',
                color: pendingDocsCount > 0 ? '#b45309' : 'var(--color-text-muted)',
                border: pendingDocsCount > 0 ? '1px solid rgba(245, 158, 11, 0.4)' : '1px solid var(--color-border)',
                fontWeight: 600,
                cursor: 'pointer',
              }}
              onClick={() => {
                setTab('documents');
                setDocFilter('pending');
                setSearchParams({ tab: 'documents' }, { replace: true });
              }}
            >
              ⏳ Pending Docs: {pendingDocsCount}
            </button>
            <button
              type="button"
              className="btn btn--ghost"
              style={{
                padding: '4px 10px',
                fontSize: '0.8rem',
                borderRadius: 'var(--radius-full)',
                background: approvedDocsCount === requiredDocTypes.length ? 'rgba(16, 185, 129, 0.15)' : 'var(--color-bg-alt)',
                color: approvedDocsCount === requiredDocTypes.length ? '#059669' : 'var(--color-text-muted)',
                border: '1px solid var(--color-border)',
                fontWeight: 600,
                cursor: 'pointer',
              }}
              onClick={() => {
                setTab('documents');
                setDocFilter('approved');
                setSearchParams({ tab: 'documents' }, { replace: true });
              }}
            >
              ✓ Approved Docs: {approvedDocsCount}/{requiredDocTypes.length}
            </button>
            {rejectedDocsCount > 0 && (
              <button
                type="button"
                className="btn btn--ghost"
                style={{
                  padding: '4px 10px',
                  fontSize: '0.8rem',
                  borderRadius: 'var(--radius-full)',
                  background: 'rgba(239, 68, 68, 0.12)',
                  color: '#dc2626',
                  border: '1px solid rgba(239, 68, 68, 0.3)',
                  fontWeight: 600,
                  cursor: 'pointer',
                }}
                onClick={() => {
                  setTab('documents');
                  setDocFilter('rejected');
                  setSearchParams({ tab: 'documents' }, { replace: true });
                }}
              >
                ✕ Rejected Docs: {rejectedDocsCount}
              </button>
            )}
            {missingDocsCount > 0 && (
              <button
                type="button"
                className="btn btn--ghost"
                style={{
                  padding: '4px 10px',
                  fontSize: '0.8rem',
                  borderRadius: 'var(--radius-full)',
                  background: 'var(--color-bg-alt)',
                  color: 'var(--color-text-muted)',
                  border: '1px solid var(--color-border)',
                  fontWeight: 600,
                  cursor: 'pointer',
                }}
                onClick={() => {
                  setTab('documents');
                  setDocFilter('missing');
                  setSearchParams({ tab: 'documents' }, { replace: true });
                }}
              >
                📁 Missing Docs: {missingDocsCount}
              </button>
            )}
            <button
              type="button"
              className="btn btn--ghost"
              style={{
                padding: '4px 10px',
                fontSize: '0.8rem',
                borderRadius: 'var(--radius-full)',
                background: vehicleReviewStatus.toneClass === 'badge--ok' ? 'rgba(16, 185, 129, 0.12)' : 'rgba(245, 158, 11, 0.15)',
                color: vehicleReviewStatus.toneClass === 'badge--ok' ? '#059669' : '#b45309',
                border: '1px solid var(--color-border)',
                fontWeight: 600,
                cursor: 'pointer',
              }}
              onClick={() => {
                setTab('vehicle');
                setSearchParams({ tab: 'vehicle' }, { replace: true });
              }}
            >
              🚗 Vehicle Review: {vehicleReviewStatus.label}
            </button>
          </div>

          {pendingDocsCount === 0 && rejectedDocsCount === 0 && missingDocsCount === 0 && (vehicleReviewStatus.label === 'Approved' || vehicleReviewStatus.label === 'Not submitted') && approval !== 'approved' && (
            <div
              style={{
                marginTop: 'var(--space-3)',
                padding: 'var(--space-3)',
                background: 'var(--color-success-light, #ecfdf5)',
                border: '1px solid var(--color-success, #10b981)',
                borderRadius: 'var(--radius-lg)',
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
                flexWrap: 'wrap',
                gap: 12,
              }}
            >
              <div>
                <strong style={{ color: '#065f46' }}>✓ All verification requirements met!</strong>
                <div style={{ fontSize: '0.85rem', color: '#047857', marginTop: 2 }}>
                  All required documents and vehicle information are approved. Click to activate this driver account.
                </div>
              </div>
              <button
                type="button"
                className="btn btn--primary"
                style={{ borderRadius: 'var(--radius-full)' }}
                disabled={pendingAction}
                onClick={approveDriverProfile}
              >
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
          <div className="card animate-fade-in" style={{ marginBottom: 'var(--space-5)', borderRadius: 'var(--radius-xl)' }}>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 'var(--space-4)', alignItems: 'center' }}>
              {/* Profile Photo Avatar with Hover/Click to Edit */}
              <div
                style={{
                  position: 'relative',
                  width: 72,
                  height: 72,
                  borderRadius: '50%',
                  overflow: 'hidden',
                  flexShrink: 0,
                  boxShadow: '0 4px 14px rgba(0,0,0,0.12)',
                  border: '2px solid var(--color-surface)',
                  background: 'linear-gradient(135deg, var(--color-primary), #059669)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                }}
              >
                {photoUrl ? (
                  <img
                    src={photoUrl}
                    alt={name}
                    style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                    onError={(e) => {
                      (e.currentTarget as HTMLImageElement).style.display = 'none';
                    }}
                  />
                ) : (
                  <span style={{ fontSize: '1.85rem', fontWeight: 800, color: '#ffffff' }}>
                    {name[0]?.toUpperCase() || 'D'}
                  </span>
                )}
                <button
                  type="button"
                  title="Change profile photo"
                  onClick={openEditModal}
                  style={{
                    position: 'absolute',
                    bottom: 0,
                    right: 0,
                    left: 0,
                    background: 'rgba(15, 23, 42, 0.72)',
                    border: 'none',
                    color: '#ffffff',
                    fontSize: '0.62rem',
                    padding: '2px 0',
                    cursor: 'pointer',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    fontWeight: 600,
                  }}
                >
                  Edit
                </button>
              </div>

              <div style={{ flex: 1, minWidth: 260 }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
                  <h2 style={{ margin: 0, fontSize: '1.5rem', fontWeight: 800, letterSpacing: '-0.02em' }}>
                    {name}
                  </h2>
                  <button
                    type="button"
                    className="btn btn--ghost"
                    style={{
                      padding: '4px 12px',
                      fontSize: '0.78rem',
                      borderRadius: 'var(--radius-full)',
                      display: 'inline-flex',
                      alignItems: 'center',
                      gap: 4,
                      background: 'var(--color-bg-alt)',
                      border: '1px solid var(--color-border)',
                      fontWeight: 600,
                    }}
                    onClick={openEditModal}
                  >
                    ✏️ Edit Profile
                  </button>
                </div>

                <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-3)', marginTop: 6, flexWrap: 'wrap', fontSize: '0.88rem' }}>
                  <span style={{ display: 'inline-flex', alignItems: 'center', gap: 4, fontWeight: phone ? 600 : 400, color: phone ? 'var(--color-text)' : 'var(--color-text-muted)' }}>
                    <span>📞</span>
                    {phone ? (
                      <a href={`tel:${phone}`} style={{ color: 'inherit', textDecoration: 'none' }}>
                        {phone}
                      </a>
                    ) : (
                      <em>No phone number</em>
                    )}
                  </span>

                  <span className="muted" style={{ display: 'inline-flex', alignItems: 'center', gap: 4 }}>
                    <span>✉️</span> {email || <em>No email</em>}
                  </span>

                  {state && (
                    <span className="badge badge--neutral" style={{ fontSize: '0.75rem', padding: '2px 8px' }}>
                      📍 {state}
                    </span>
                  )}

                  <span className="muted" style={{ fontSize: '0.82rem' }}>
                    UID: <code>{uid}</code>{' '}
                    <button
                      type="button"
                      className="btn btn--ghost"
                      style={{ padding: '2px 8px', fontSize: '0.7rem', height: 'fit-content', borderRadius: 'var(--radius-full)' }}
                      onClick={copyUid}
                    >
                      Copy
                    </button>
                  </span>
                </div>
              </div>

              <div style={{ display: 'flex', gap: 'var(--space-2)', alignItems: 'center', flexWrap: 'wrap' }}>
                <span className="badge badge--ok" style={{ textTransform: 'capitalize', borderRadius: 'var(--radius-full)' }}>
                  ★ {tier}
                </span>
                <span className={`badge ${approvalBadgeClass(approval)}`} style={{ textTransform: 'capitalize', borderRadius: 'var(--radius-full)' }}>
                  {approval}
                </span>
                {approval !== 'approved' && (
                  pendingDocsCount === 0 && rejectedDocsCount === 0 && missingDocsCount === 0 ? (
                    <button
                      type="button"
                      className="btn btn--primary"
                      style={{ padding: '8px 18px', fontSize: '0.85rem', borderRadius: 'var(--radius-full)' }}
                      disabled={pendingAction}
                      onClick={approveDriverProfile}
                    >
                      ✓ Approve Driver Profile
                    </button>
                  ) : (
                    <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                      {pendingDocsCount > 0 && (
                        <button
                          type="button"
                          className="btn btn--primary"
                          style={{
                            padding: '8px 16px',
                            fontSize: '0.85rem',
                            borderRadius: 'var(--radius-full)',
                            background: 'linear-gradient(135deg, #f59e0b, #d97706)',
                          }}
                          onClick={() => {
                            setTab('documents');
                            setDocFilter('pending');
                            setSearchParams({ tab: 'documents' }, { replace: true });
                          }}
                        >
                          Review {pendingDocsCount} Pending Doc{pendingDocsCount > 1 ? 's' : ''} →
                        </button>
                      )}
                      <button
                        type="button"
                        className="btn btn--ghost"
                        style={{
                          padding: '8px 12px',
                          fontSize: '0.8rem',
                          borderRadius: 'var(--radius-full)',
                          color: 'var(--color-text-muted)',
                          border: '1px solid var(--color-border)',
                        }}
                        title="Force approve driver without verifying all documents"
                        disabled={pendingAction}
                        onClick={() => setConfirmForceApproveOpen(true)}
                      >
                        Force Approve...
                      </button>
                    </div>
                  )
                )}
                {approval !== 'rejected' && (
                  <button
                    type="button"
                    className="btn btn--ghost"
                    style={{ padding: '8px 18px', fontSize: '0.85rem', borderRadius: 'var(--radius-full)', color: 'var(--color-error)' }}
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
                borderRadius: 'var(--radius-lg)',
                fontSize: '0.85rem',
                fontWeight: 500
              }}>
                Current onboarding block: {String(driver.rejectionReason)}
              </div>
            )}
          </div>

          {/* Styled Tab Bar Underline */}
          <div className="tab-bar-underline" style={{ marginBottom: 'var(--space-5)' }}>
            {tabs.map((t) => {
              let badge = null;
              if (t === 'documents') {
                badge = pendingDocsCount > 0 ? (
                  <span
                    className="tab-count-badge"
                    style={{
                      background: '#f59e0b',
                      color: '#ffffff',
                      fontWeight: 700,
                      padding: '2px 8px',
                      borderRadius: 'var(--radius-full)',
                      fontSize: '0.75rem',
                      marginLeft: 6,
                    }}
                  >
                    {pendingDocsCount} pending
                  </span>
                ) : approvedDocsCount === requiredDocTypes.length ? (
                  <span
                    className="tab-count-badge"
                    style={{
                      background: 'rgba(16, 185, 129, 0.15)',
                      color: '#059669',
                      fontWeight: 700,
                      padding: '2px 8px',
                      borderRadius: 'var(--radius-full)',
                      fontSize: '0.75rem',
                      marginLeft: 6,
                    }}
                  >
                    ✓ All Approved
                  </span>
                ) : null;
              } else if (t === 'vehicle') {
                if (vehicleReview?.status === 'pending') {
                  badge = (
                    <span
                      className="tab-count-badge"
                      style={{
                        background: '#f59e0b',
                        color: '#ffffff',
                        fontWeight: 700,
                        padding: '2px 8px',
                        borderRadius: 'var(--radius-full)',
                        fontSize: '0.75rem',
                        marginLeft: 6,
                      }}
                    >
                      Pending
                    </span>
                  );
                }
              }
              return (
                <button
                  key={t}
                  type="button"
                  className={`tab-btn-underline ${tab === t ? 'active' : ''}`}
                  onClick={() => {
                    setTab(t);
                    setSearchParams({ tab: t }, { replace: true });
                  }}
                  style={{ textTransform: 'capitalize' }}
                >
                  {t === 'activity' ? 'Verification Activity' : t}
                  {badge}
                </button>
              );
            })}
          </div>

          {/* TAB 1: Overview */}
          {tab === 'overview' && (
            <div style={{ display: 'grid', gap: 'var(--space-5)' }}>
              {/* Driver Contact & Profile Card */}
              <div className="card" style={{ borderRadius: 'var(--radius-xl)' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 'var(--space-3)', flexWrap: 'wrap', gap: 10 }}>
                  <h3 style={{ margin: 0, fontSize: '1.1rem', fontWeight: 700 }}>
                    Driver Personal & Contact Details
                  </h3>
                  <button
                    type="button"
                    className="btn btn--primary"
                    style={{ padding: '6px 14px', fontSize: '0.8rem', borderRadius: 'var(--radius-full)' }}
                    onClick={openEditModal}
                  >
                    ✏️ Edit Full Name, Phone & Photo
                  </button>
                </div>
                <div
                  style={{
                    display: 'grid',
                    gridTemplateColumns: 'repeat(auto-fill, minmax(220px, 1fr))',
                    gap: 'var(--space-4)',
                    padding: 'var(--space-3) 0 0 0',
                    borderTop: '1px solid var(--color-border)',
                  }}
                >
                  <div>
                    <div className="muted" style={{ fontSize: '0.75rem', fontWeight: 600 }}>FULL NAME</div>
                    <div style={{ fontSize: '1.05rem', fontWeight: 700, marginTop: 4 }}>{name}</div>
                  </div>
                  <div>
                    <div className="muted" style={{ fontSize: '0.75rem', fontWeight: 600 }}>PHONE NUMBER</div>
                    <div style={{ fontSize: '1.05rem', fontWeight: 700, marginTop: 4 }}>
                      {phone ? (
                        <a href={`tel:${phone}`} style={{ color: 'var(--color-primary-active)', textDecoration: 'none' }}>
                          {phone}
                        </a>
                      ) : (
                        <span className="muted" style={{ fontWeight: 400 }}>Not provided</span>
                      )}
                    </div>
                  </div>
                  <div>
                    <div className="muted" style={{ fontSize: '0.75rem', fontWeight: 600 }}>EMAIL ADDRESS</div>
                    <div style={{ fontSize: '0.95rem', fontWeight: 600, marginTop: 4 }}>{email || '—'}</div>
                  </div>
                  <div>
                    <div className="muted" style={{ fontSize: '0.75rem', fontWeight: 600 }}>OPERATING STATE</div>
                    <div style={{ fontSize: '0.95rem', fontWeight: 600, marginTop: 4 }}>{state || 'Nationwide / Not set'}</div>
                  </div>
                  <div>
                    <div className="muted" style={{ fontSize: '0.75rem', fontWeight: 600 }}>PROFILE PHOTO</div>
                    <div style={{ marginTop: 4, display: 'flex', alignItems: 'center', gap: 8 }}>
                      {photoUrl ? (
                        <>
                          <img
                            src={photoUrl}
                            alt={name}
                            style={{ width: 34, height: 34, borderRadius: '50%', objectFit: 'cover', border: '1px solid var(--color-border)' }}
                          />
                          <span className="badge badge--ok" style={{ fontSize: '0.75rem' }}>Uploaded</span>
                        </>
                      ) : (
                        <span className="badge badge--warn" style={{ fontSize: '0.75rem' }}>No Photo</span>
                      )}
                    </div>
                  </div>
                </div>
              </div>

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
                        <button type="button" className="btn btn--primary" style={{ borderRadius: 'var(--radius-full)' }} disabled={pendingAction} onClick={approveVehicleReview}>
                          Approve Vehicle Info
                        </button>
                        <button type="button" className="btn btn--ghost" style={{ borderRadius: 'var(--radius-full)', color: 'var(--color-error)' }} disabled={pendingAction} onClick={() => setRejectVehicleOpen(true)}>
                          Reject Changes
                        </button>
                      </div>
                    )}
                  </>
                )}
              </div>

              <div className="card" style={{ borderRadius: 'var(--radius-xl)' }}>
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
            <div style={{ display: 'grid', gap: 'var(--space-4)' }}>
              {/* Toolbar and filter pills card */}
              <div className="card" style={{ borderRadius: 'var(--radius-xl)' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 14, marginBottom: 'var(--space-3)' }}>
                  <div>
                    <h3 style={{ margin: 0, fontSize: '1.1rem', fontWeight: 700 }}>Driver Verification Documents</h3>
                    <p className="muted" style={{ margin: '4px 0 0 0', fontSize: '0.85rem' }}>
                      Required list for {vehicleTypeLabel(activeVehicleType)} Driver ({requiredDocTypes.length} total requirements)
                    </p>
                  </div>
                  {pendingDocsCount > 1 && (
                    <button
                      type="button"
                      className="btn btn--primary"
                      style={{ borderRadius: 'var(--radius-full)', padding: '6px 16px', fontSize: '0.82rem' }}
                      disabled={pendingAction}
                      onClick={() => setConfirmBulkApproveOpen(true)}
                    >
                      ✓ Approve All Pending ({pendingDocsCount})
                    </button>
                  )}
                </div>

                {/* Filter Pills */}
                <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', paddingTop: 8, borderTop: '1px solid var(--color-border)' }}>
                  <button
                    type="button"
                    className={`btn ${docFilter === 'all' ? 'btn--primary' : 'btn--ghost'}`}
                    style={{ padding: '4px 14px', fontSize: '0.8rem', borderRadius: 'var(--radius-full)' }}
                    onClick={() => setDocFilter('all')}
                  >
                    All Documents ({mergedDocRows.length})
                  </button>
                  <button
                    type="button"
                    className={`btn ${docFilter === 'pending' ? 'btn--primary' : 'btn--ghost'}`}
                    style={{
                      padding: '4px 14px',
                      fontSize: '0.8rem',
                      borderRadius: 'var(--radius-full)',
                      background: docFilter === 'pending' ? '#f59e0b' : undefined,
                      borderColor: docFilter === 'pending' ? '#f59e0b' : undefined,
                      color: docFilter === 'pending' ? '#ffffff' : (pendingDocsCount > 0 ? '#b45309' : undefined),
                      fontWeight: 600,
                    }}
                    onClick={() => setDocFilter('pending')}
                  >
                    ⏳ Pending Review ({pendingDocsCount})
                  </button>
                  <button
                    type="button"
                    className={`btn ${docFilter === 'approved' ? 'btn--primary' : 'btn--ghost'}`}
                    style={{
                      padding: '4px 14px',
                      fontSize: '0.8rem',
                      borderRadius: 'var(--radius-full)',
                      color: docFilter === 'approved' ? '#ffffff' : '#059669',
                      fontWeight: 600,
                    }}
                    onClick={() => setDocFilter('approved')}
                  >
                    ✓ Approved ({approvedDocsCount})
                  </button>
                  <button
                    type="button"
                    className={`btn ${docFilter === 'rejected' ? 'btn--primary' : 'btn--ghost'}`}
                    style={{
                      padding: '4px 14px',
                      fontSize: '0.8rem',
                      borderRadius: 'var(--radius-full)',
                      color: docFilter === 'rejected' ? '#ffffff' : (rejectedDocsCount > 0 ? '#dc2626' : undefined),
                      fontWeight: 600,
                    }}
                    onClick={() => setDocFilter('rejected')}
                  >
                    ✕ Rejected ({rejectedDocsCount})
                  </button>
                  <button
                    type="button"
                    className={`btn ${docFilter === 'missing' ? 'btn--primary' : 'btn--ghost'}`}
                    style={{ padding: '4px 14px', fontSize: '0.8rem', borderRadius: 'var(--radius-full)' }}
                    onClick={() => setDocFilter('missing')}
                  >
                    📁 Not Uploaded ({missingDocsCount})
                  </button>
                </div>
              </div>

              {/* Documents Card Grid / List */}
              {filteredDocRows.length === 0 ? (
                <div className="card" style={{ padding: '32px 20px', textAlign: 'center', borderRadius: 'var(--radius-xl)' }}>
                  <div style={{ fontSize: '2rem', marginBottom: 8 }}>📄</div>
                  <h4 style={{ margin: '0 0 6px 0' }}>No documents in this view</h4>
                  <p className="muted" style={{ margin: '0 0 16px 0', fontSize: '0.85rem' }}>
                    There are no documents matching the &ldquo;{docFilter}&rdquo; filter.
                  </p>
                  <button
                    type="button"
                    className="btn btn--ghost"
                    style={{ borderRadius: 'var(--radius-full)', fontSize: '0.8rem' }}
                    onClick={() => setDocFilter('all')}
                  >
                    Show All Documents
                  </button>
                </div>
              ) : (
                <div style={{ display: 'grid', gap: 'var(--space-3)' }}>
                  {filteredDocRows.map((row) => {
                    const submitted = isDocSubmitted(row, driver);
                    const human = DRIVER_DOCUMENT_LABELS[row.typeId] ?? row.typeId;
                    const isPending = submitted && row.status === 'pending';
                    const isApproved = submitted && row.status === 'approved';
                    const isRejected = submitted && row.status === 'rejected';

                    return (
                      <div
                        key={row.typeId}
                        className="card"
                        style={{
                          borderRadius: 'var(--radius-xl)',
                          border: isPending
                            ? '1.5px solid rgba(245, 158, 11, 0.5)'
                            : isRejected
                            ? '1.5px solid rgba(239, 68, 68, 0.4)'
                            : '1px solid var(--color-border)',
                          background: isPending
                            ? 'rgba(245, 158, 11, 0.03)'
                            : isRejected
                            ? 'rgba(239, 68, 68, 0.02)'
                            : 'var(--color-surface)',
                          padding: '16px 20px',
                          display: 'flex',
                          flexDirection: 'column',
                          gap: 12,
                          transition: 'all 0.2s ease',
                        }}
                      >
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: 16 }}>
                          <div style={{ flex: 1, minWidth: 260 }}>
                            <div style={{ display: 'flex', alignItems: 'center', gap: 10, flexWrap: 'wrap' }}>
                              <h4 style={{ margin: 0, fontSize: '1rem', fontWeight: 700 }}>{human}</h4>
                              {isPending && (
                                <span className="status-pill status-pill--warning" style={{ fontSize: '0.75rem', padding: '3px 10px' }}>
                                  ⏳ Pending Review
                                </span>
                              )}
                              {isApproved && (
                                <span className="status-pill status-pill--success" style={{ fontSize: '0.75rem', padding: '3px 10px' }}>
                                  ✓ Approved
                                </span>
                              )}
                              {isRejected && (
                                <span className="status-pill status-pill--danger" style={{ fontSize: '0.75rem', padding: '3px 10px' }}>
                                  ✕ Rejected
                                </span>
                              )}
                              {!submitted && (
                                <span style={{ fontSize: '0.75rem', padding: '3px 10px', background: 'var(--color-bg-alt)', color: 'var(--color-text-muted)', borderRadius: 'var(--radius-full)', fontWeight: 600 }}>
                                  Not Uploaded
                                </span>
                              )}
                            </div>

                            <div className="muted" style={{ fontSize: '0.8rem', marginTop: 4 }}>
                              {row.uploadedAt ? (
                                <>Uploaded: {formatTs(row.uploadedAt)}</>
                              ) : (
                                <>Awaiting upload by driver</>
                              )}
                              {row.reviewedAt ? <> · Reviewed: {formatTs(row.reviewedAt)}</> : null}
                            </div>

                            {/* Rejection Alert */}
                            {row.rejectionReason && (
                              <div
                                style={{
                                  background: 'var(--color-error-light, #fef2f2)',
                                  color: 'var(--color-error, #dc2626)',
                                  border: '1px solid rgba(239, 68, 68, 0.25)',
                                  padding: '8px 12px',
                                  borderRadius: 'var(--radius-md)',
                                  fontSize: '0.82rem',
                                  marginTop: 8,
                                  fontWeight: 500,
                                }}
                              >
                                <strong>Rejection Reason:</strong> {String(row.rejectionReason)}
                              </div>
                            )}

                            {/* Guarantor Details Form Data */}
                            {row.typeId === 'guarantor_info' && driver && (driver.guarantorName || (row as any).fullName) ? (
                              <div
                                style={{
                                  background: 'var(--color-bg-alt)',
                                  padding: '10px 14px',
                                  borderRadius: 'var(--radius-md)',
                                  marginTop: 8,
                                  fontSize: '0.82rem',
                                  border: '1px solid var(--color-border)',
                                  display: 'grid',
                                  gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
                                  gap: 6,
                                }}
                              >
                                <div><strong>Guarantor:</strong> {driver.guarantorName || (row as any).fullName || '—'}</div>
                                <div><strong>Phone:</strong> {driver.guarantorPhone || (row as any).phone || '—'}</div>
                                <div><strong>Relationship:</strong> {driver.guarantorRelationship || (row as any).relationship || '—'}</div>
                                <div><strong>Address:</strong> {driver.guarantorAddress || (row as any).address || '—'}</div>
                              </div>
                            ) : null}

                            {/* Document File / Preview Actions */}
                            <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 10, flexWrap: 'wrap' }}>
                              {row.fileUrl ? (
                                <>
                                  <button
                                    type="button"
                                    className="btn btn--ghost"
                                    style={{
                                      padding: '4px 14px',
                                      fontSize: '0.8rem',
                                      borderRadius: 'var(--radius-full)',
                                      display: 'inline-flex',
                                      alignItems: 'center',
                                      gap: 6,
                                      border: '1px solid var(--color-border)',
                                    }}
                                    onClick={() =>
                                      setPreviewDoc({
                                        typeId: row.typeId,
                                        fileUrl: row.fileUrl,
                                        title: human,
                                        status: row.status,
                                        rejectionReason: row.rejectionReason,
                                        uploadedAt: row.uploadedAt,
                                      })
                                    }
                                  >
                                    <span>👁️ Quick Preview</span>
                                  </button>
                                  <a
                                    href={row.fileUrl}
                                    target="_blank"
                                    rel="noreferrer"
                                    className="btn btn--ghost"
                                    style={{
                                      padding: '4px 12px',
                                      fontSize: '0.78rem',
                                      borderRadius: 'var(--radius-full)',
                                      color: 'var(--color-primary)',
                                    }}
                                  >
                                    Open Full Size ↗
                                  </a>
                                </>
                              ) : row.typeId === 'guarantor_info' && (driver?.guarantorName || (row as any).fullName) ? (
                                <span style={{ fontSize: '0.8rem', color: 'var(--color-success)', fontWeight: 600 }}>
                                  ✓ Guarantor Form Submitted
                                </span>
                              ) : (
                                <span className="muted" style={{ fontSize: '0.8rem' }}>
                                  Document not yet uploaded by candidate
                                </span>
                              )}
                            </div>
                          </div>

                          {/* Approval and Rejection Action Buttons */}
                          <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
                            {submitted ? (
                              isPending ? (
                                <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                                  <button
                                    type="button"
                                    className="btn btn--primary"
                                    style={{
                                      padding: '7px 18px',
                                      fontSize: '0.85rem',
                                      borderRadius: 'var(--radius-full)',
                                      display: 'inline-flex',
                                      alignItems: 'center',
                                      gap: 6,
                                    }}
                                    disabled={pendingAction}
                                    onClick={() => approveDocument(row.typeId)}
                                  >
                                    ✓ Approve
                                  </button>
                                  <button
                                    type="button"
                                    className="btn btn--ghost"
                                    style={{
                                      padding: '7px 16px',
                                      fontSize: '0.85rem',
                                      borderRadius: 'var(--radius-full)',
                                      color: 'var(--color-error)',
                                      border: '1px solid rgba(239, 68, 68, 0.3)',
                                      display: 'inline-flex',
                                      alignItems: 'center',
                                      gap: 6,
                                    }}
                                    disabled={pendingAction}
                                    onClick={() => {
                                      setRejectDocType(row.typeId);
                                      setRejectDocReason('');
                                    }}
                                  >
                                    ✕ Reject
                                  </button>
                                </div>
                              ) : isApproved ? (
                                <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                                  <span style={{ fontSize: '0.8rem', color: '#059669', fontWeight: 600, display: 'inline-flex', alignItems: 'center', gap: 4 }}>
                                    ✓ Verified
                                  </span>
                                  <button
                                    type="button"
                                    className="btn btn--ghost"
                                    style={{
                                      padding: '4px 12px',
                                      fontSize: '0.78rem',
                                      borderRadius: 'var(--radius-full)',
                                      color: 'var(--color-error)',
                                      border: '1px solid rgba(239, 68, 68, 0.25)',
                                    }}
                                    disabled={pendingAction}
                                    onClick={() => {
                                      setRejectDocType(row.typeId);
                                      setRejectDocReason('');
                                    }}
                                  >
                                    Revoke / Reject
                                  </button>
                                </div>
                              ) : isRejected ? (
                                <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                                  <button
                                    type="button"
                                    className="btn btn--ghost"
                                    style={{
                                      padding: '5px 14px',
                                      fontSize: '0.8rem',
                                      borderRadius: 'var(--radius-full)',
                                      color: 'var(--color-success)',
                                      border: '1px solid rgba(16, 185, 129, 0.3)',
                                    }}
                                    disabled={pendingAction}
                                    onClick={() => approveDocument(row.typeId)}
                                  >
                                    ✓ Re-approve
                                  </button>
                                  <button
                                    type="button"
                                    className="btn btn--ghost"
                                    style={{
                                      padding: '5px 12px',
                                      fontSize: '0.8rem',
                                      borderRadius: 'var(--radius-full)',
                                      color: 'var(--color-text-muted)',
                                      border: '1px solid var(--color-border)',
                                    }}
                                    disabled={pendingAction}
                                    onClick={() => {
                                      setRejectDocType(row.typeId);
                                      setRejectDocReason(row.rejectionReason || '');
                                    }}
                                  >
                                    Edit Reason
                                  </button>
                                </div>
                              ) : null
                            ) : (
                              <span style={{ fontSize: '0.8rem', color: 'var(--color-text-muted)', fontStyle: 'italic' }}>
                                Waiting for upload
                              </span>
                            )}
                          </div>
                        </div>
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          )}

          {/* TAB 4: Verification Activity */}
          {tab === 'activity' && (
            <div className="card" style={{ display: 'flex', flexDirection: 'column', gap: 12, borderRadius: 'var(--radius-xl)' }}>
              {historyRows.length === 0 ? (
                <p className="muted" style={{ margin: 0 }}>No verification history found.</p>
              ) : (
                historyRows.map((row) => <HistoryEntry key={row.id} row={row} />)
              )}
            </div>
          )}

          {/* TAB 5: Wallet Transactions */}
          {tab === 'wallet' && (
            <div className="card" style={{ display: 'flex', flexDirection: 'column', gap: 12, borderRadius: 'var(--radius-xl)' }}>
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

      {/* Document Quick Preview Lightbox Modal */}
      {previewDoc && (
        <div
          style={{
            position: 'fixed',
            inset: 0,
            background: 'rgba(15, 23, 42, 0.75)',
            backdropFilter: 'blur(8px)',
            WebkitBackdropFilter: 'blur(8px)',
            display: 'grid',
            placeItems: 'center',
            zIndex: 1050,
            padding: 'var(--space-4)',
          }}
          role="dialog"
          aria-modal
          onClick={() => setPreviewDoc(null)}
        >
          <div
            className="card"
            style={{
              maxWidth: 750,
              width: '100%',
              maxHeight: '90vh',
              display: 'flex',
              flexDirection: 'column',
              borderRadius: 'var(--radius-xl)',
              padding: 0,
              overflow: 'hidden',
              boxShadow: '0 25px 50px -12px rgba(0, 0, 0, 0.25)',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            {/* Modal Header */}
            <div
              style={{
                padding: '16px 20px',
                borderBottom: '1px solid var(--color-border)',
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
                background: 'var(--color-surface)',
              }}
            >
              <div>
                <h3 style={{ margin: 0, fontSize: '1.05rem', fontWeight: 700 }}>{previewDoc.title}</h3>
                <div style={{ fontSize: '0.8rem', color: 'var(--color-text-muted)', marginTop: 2 }}>
                  {previewDoc.uploadedAt ? <>Uploaded: {formatTs(previewDoc.uploadedAt)}</> : 'Uploaded document'}
                </div>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                {previewDoc.status === 'pending' && (
                  <span className="status-pill status-pill--warning" style={{ fontSize: '0.75rem', padding: '3px 10px' }}>
                    ⏳ Pending Review
                  </span>
                )}
                {previewDoc.status === 'approved' && (
                  <span className="status-pill status-pill--success" style={{ fontSize: '0.75rem', padding: '3px 10px' }}>
                    ✓ Approved
                  </span>
                )}
                {previewDoc.status === 'rejected' && (
                  <span className="status-pill status-pill--danger" style={{ fontSize: '0.75rem', padding: '3px 10px' }}>
                    ✕ Rejected
                  </span>
                )}
                <button
                  type="button"
                  className="btn btn--ghost"
                  style={{ borderRadius: '50%', width: 32, height: 32, padding: 0, display: 'grid', placeItems: 'center' }}
                  onClick={() => setPreviewDoc(null)}
                >
                  ✕
                </button>
              </div>
            </div>

            {/* Modal Body / Image Viewer */}
            <div
              style={{
                flex: 1,
                overflow: 'auto',
                background: '#090d16',
                display: 'grid',
                placeItems: 'center',
                padding: 16,
                minHeight: 350,
                maxHeight: '60vh',
              }}
            >
              <img
                src={previewDoc.fileUrl}
                alt={previewDoc.title}
                style={{
                  maxWidth: '100%',
                  maxHeight: '55vh',
                  objectFit: 'contain',
                  borderRadius: 8,
                  boxShadow: '0 4px 12px rgba(0,0,0,0.5)',
                }}
                onError={(e) => {
                  (e.target as HTMLElement).style.display = 'none';
                  const parent = (e.target as HTMLElement).parentElement;
                  if (parent && !parent.querySelector('.preview-fallback')) {
                    const fallback = document.createElement('div');
                    fallback.className = 'preview-fallback';
                    fallback.style.color = '#fff';
                    fallback.style.textAlign = 'center';
                    fallback.innerHTML = `<p>Unable to preview this file inline.</p><a href="${previewDoc.fileUrl}" target="_blank" rel="noreferrer" style="color: #3b82f6; text-decoration: underline;">Open original file in new tab ↗</a>`;
                    parent.appendChild(fallback);
                  }
                }}
              />
            </div>

            {/* Rejection notice inside preview if rejected */}
            {previewDoc.rejectionReason && (
              <div style={{ padding: '10px 20px', background: 'var(--color-error-light, #fef2f2)', color: 'var(--color-error, #dc2626)', fontSize: '0.85rem', borderTop: '1px solid rgba(239, 68, 68, 0.2)' }}>
                <strong>Rejection Reason:</strong> {previewDoc.rejectionReason}
              </div>
            )}

            {/* Modal Footer with Actions */}
            <div
              style={{
                padding: '14px 20px',
                borderTop: '1px solid var(--color-border)',
                display: 'flex',
                justifyContent: 'space-between',
                alignItems: 'center',
                background: 'var(--color-surface)',
                flexWrap: 'wrap',
                gap: 10,
              }}
            >
              <a
                href={previewDoc.fileUrl}
                target="_blank"
                rel="noreferrer"
                className="btn btn--ghost"
                style={{ fontSize: '0.8rem', padding: '6px 14px', borderRadius: 'var(--radius-full)' }}
              >
                Open in Full Window ↗
              </a>

              <div style={{ display: 'flex', gap: 8, alignItems: 'center' }}>
                <button
                  type="button"
                  className="btn btn--ghost"
                  style={{
                    padding: '6px 16px',
                    fontSize: '0.82rem',
                    borderRadius: 'var(--radius-full)',
                    color: 'var(--color-error)',
                    border: '1px solid rgba(239, 68, 68, 0.3)',
                  }}
                  disabled={pendingAction}
                  onClick={() => {
                    setRejectDocType(previewDoc.typeId);
                    setRejectDocReason(previewDoc.rejectionReason || '');
                  }}
                >
                  ✕ Reject Document...
                </button>
                <button
                  type="button"
                  className="btn btn--primary"
                  style={{ padding: '6px 18px', fontSize: '0.82rem', borderRadius: 'var(--radius-full)' }}
                  disabled={pendingAction || previewDoc.status === 'approved'}
                  onClick={() => approveDocument(previewDoc.typeId)}
                >
                  ✓ Approve Document
                </button>
              </div>
            </div>
          </div>
        </div>
      )}

      {/* Reject Document dialog modal with Quick-Select Reasons */}
      {rejectDocType && (
        <div
          style={{
            position: 'fixed',
            inset: 0,
            background: 'rgba(15,23,42,0.55)',
            backdropFilter: 'blur(8px)',
            WebkitBackdropFilter: 'blur(8px)',
            display: 'grid',
            placeItems: 'center',
            zIndex: 1100,
            padding: 'var(--space-4)',
          }}
          role="dialog"
          aria-modal
        >
          <div className="card" style={{ maxWidth: 500, width: '100%', borderRadius: 'var(--radius-xl)' }}>
            <h3 style={{ marginTop: 0, fontSize: '1.15rem', fontWeight: 700, color: 'var(--color-error)' }}>
              Reject Document
            </h3>
            <p className="muted" style={{ fontSize: '0.85rem', marginTop: -4 }}>
              {DRIVER_DOCUMENT_LABELS[rejectDocType] ?? rejectDocType}
            </p>

            {/* Quick Reason Chips */}
            <div style={{ marginBottom: 14 }}>
              <label style={{ fontSize: '0.78rem', fontWeight: 600, color: 'var(--color-text-muted)', display: 'block', marginBottom: 6 }}>
                Common Reasons (click to select):
              </label>
              <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
                {QUICK_REJECTION_REASONS.map((chip) => (
                  <button
                    key={chip}
                    type="button"
                    style={{
                      background: rejectDocReason === chip ? 'var(--color-error)' : 'var(--color-bg-alt)',
                      color: rejectDocReason === chip ? '#ffffff' : 'var(--color-text)',
                      border: '1px solid var(--color-border)',
                      borderRadius: 'var(--radius-full)',
                      padding: '3px 10px',
                      fontSize: '0.75rem',
                      cursor: 'pointer',
                      fontWeight: 500,
                      transition: 'all 0.15s ease',
                    }}
                    onClick={() => setRejectDocReason(chip)}
                  >
                    {chip}
                  </button>
                ))}
              </div>
            </div>

            <div className="field">
              <label htmlFor="rejectDocReason" style={{ fontWeight: 600 }}>Rejection Reason / Notes for Driver</label>
              <textarea
                id="rejectDocReason"
                rows={3}
                placeholder="Indicate clearly why this document is rejected so candidate can rectify..."
                value={rejectDocReason}
                onChange={(e) => setRejectDocReason(e.target.value)}
              />
            </div>

            <div style={{ display: 'flex', gap: 'var(--space-2)', justifyContent: 'flex-end', marginTop: 'var(--space-4)' }}>
              <button
                type="button"
                className="btn btn--ghost"
                style={{ borderRadius: 'var(--radius-full)' }}
                onClick={() => {
                  setRejectDocType(null);
                  setRejectDocReason('');
                }}
              >
                Cancel
              </button>
              <button
                type="button"
                className="btn btn--primary"
                style={{ borderRadius: 'var(--radius-full)', background: 'var(--color-error)', borderColor: 'var(--color-error)' }}
                disabled={pendingAction || !rejectDocReason.trim()}
                onClick={submitRejectDocument}
              >
                Confirm Reject Document
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Confirm Bulk Approve Modal */}
      {confirmBulkApproveOpen && (
        <div
          style={{
            position: 'fixed',
            inset: 0,
            background: 'rgba(15,23,42,0.55)',
            backdropFilter: 'blur(8px)',
            WebkitBackdropFilter: 'blur(8px)',
            display: 'grid',
            placeItems: 'center',
            zIndex: 1100,
            padding: 'var(--space-4)',
          }}
          role="dialog"
          aria-modal
        >
          <div className="card" style={{ maxWidth: 460, width: '100%', borderRadius: 'var(--radius-xl)' }}>
            <h3 style={{ marginTop: 0, fontSize: '1.15rem', fontWeight: 700 }}>
              Approve All Pending Documents?
            </h3>
            <p className="muted" style={{ fontSize: '0.85rem' }}>
              You are about to approve {pendingDocsCount} uploaded documents for {name}:
            </p>
            <div style={{ background: 'var(--color-bg-alt)', borderRadius: 'var(--radius-md)', padding: 12, marginBottom: 16 }}>
              {mergedDocRows
                .filter((r) => isDocSubmitted(r, driver) && r.status === 'pending')
                .map((r) => (
                  <div key={r.typeId} style={{ fontSize: '0.82rem', padding: '3px 0', display: 'flex', alignItems: 'center', gap: 6 }}>
                    <span style={{ color: '#059669' }}>✓</span> {DRIVER_DOCUMENT_LABELS[r.typeId] ?? r.typeId}
                  </div>
                ))}
            </div>
            <div style={{ display: 'flex', gap: 'var(--space-2)', justifyContent: 'flex-end' }}>
              <button
                type="button"
                className="btn btn--ghost"
                style={{ borderRadius: 'var(--radius-full)' }}
                onClick={() => setConfirmBulkApproveOpen(false)}
              >
                Cancel
              </button>
              <button
                type="button"
                className="btn btn--primary"
                style={{ borderRadius: 'var(--radius-full)' }}
                disabled={pendingAction}
                onClick={bulkApprovePendingDocs}
              >
                Yes, Approve All ({pendingDocsCount})
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Confirm Force Approve Driver Profile Modal */}
      {confirmForceApproveOpen && (
        <div
          style={{
            position: 'fixed',
            inset: 0,
            background: 'rgba(15,23,42,0.55)',
            backdropFilter: 'blur(8px)',
            WebkitBackdropFilter: 'blur(8px)',
            display: 'grid',
            placeItems: 'center',
            zIndex: 1100,
            padding: 'var(--space-4)',
          }}
          role="dialog"
          aria-modal
        >
          <div className="card" style={{ maxWidth: 480, width: '100%', borderRadius: 'var(--radius-xl)' }}>
            <h3 style={{ marginTop: 0, fontSize: '1.15rem', fontWeight: 700, color: '#d97706' }}>
              ⚠️ Incomplete Document Verification
            </h3>
            <p className="muted" style={{ fontSize: '0.85rem' }}>
              This driver account does not have all required documents verified:
            </p>
            <div style={{ background: 'rgba(245, 158, 11, 0.08)', border: '1px solid rgba(245, 158, 11, 0.3)', borderRadius: 'var(--radius-md)', padding: 14, marginBottom: 16, fontSize: '0.85rem' }}>
              <ul style={{ margin: 0, paddingLeft: 20 }}>
                {pendingDocsCount > 0 && <li><strong>{pendingDocsCount}</strong> document{pendingDocsCount > 1 ? 's' : ''} currently pending review</li>}
                {missingDocsCount > 0 && <li><strong>{missingDocsCount}</strong> document{missingDocsCount > 1 ? 's' : ''} not yet uploaded</li>}
                {rejectedDocsCount > 0 && <li><strong>{rejectedDocsCount}</strong> document{rejectedDocsCount > 1 ? 's' : ''} currently rejected</li>}
                {vehicleReviewStatus.label !== 'Approved' && <li>Vehicle review status is <strong>{vehicleReviewStatus.label}</strong></li>}
              </ul>
            </div>
            <p style={{ fontSize: '0.85rem', color: 'var(--color-text)' }}>
              Approving this profile now will allow the driver to access the platform without verified documents. Are you sure you wish to override?
            </p>
            <div style={{ display: 'flex', gap: 'var(--space-2)', justifyContent: 'flex-end', marginTop: 'var(--space-4)' }}>
              <button
                type="button"
                className="btn btn--ghost"
                style={{ borderRadius: 'var(--radius-full)' }}
                onClick={() => setConfirmForceApproveOpen(false)}
              >
                Cancel
              </button>
              <button
                type="button"
                className="btn btn--primary"
                style={{ borderRadius: 'var(--radius-full)', background: '#d97706', borderColor: '#d97706' }}
                disabled={pendingAction}
                onClick={approveDriverProfile}
              >
                Confirm Force Approval
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
          <div className="card" style={{ maxWidth: 440, width: '100%', borderRadius: 'var(--radius-xl)' }}>
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
                style={{ borderRadius: 'var(--radius-full)' }}
                onClick={() => {
                  setRejectVehicleOpen(false);
                  setRejectVehicleReason('');
                }}
              >
                Cancel
              </button>
              <button type="button" className="btn btn--primary" style={{ borderRadius: 'var(--radius-full)' }} disabled={pendingAction} onClick={submitRejectVehicle}>
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
          <div className="card" style={{ maxWidth: 440, width: '100%', borderRadius: 'var(--radius-xl)' }}>
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
                style={{ borderRadius: 'var(--radius-full)' }}
                onClick={() => {
                  setRejectDriverOpen(false);
                  setRejectDriverReason('');
                }}
              >
                Cancel
              </button>
              <button type="button" className="btn btn--primary" style={{ borderRadius: 'var(--radius-full)' }} disabled={pendingAction} onClick={submitRejectDriver}>
                Reject Driver Profile
              </button>
            </div>
          </div>
        </div>
      )}
      {/* Edit Driver Profile Modal */}
      {editProfileOpen && (
        <div
          style={{
            position: 'fixed',
            inset: 0,
            background: 'rgba(15,23,42,0.5)',
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
          <div
            className="card"
            style={{
              maxWidth: 520,
              width: '100%',
              borderRadius: 'var(--radius-xl)',
              maxHeight: '90vh',
              overflowY: 'auto',
              boxShadow: '0 20px 40px rgba(0,0,0,0.2)',
            }}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 'var(--space-4)' }}>
              <div>
                <h3 style={{ margin: 0, fontSize: '1.25rem', fontWeight: 800 }}>✏️ Edit Driver Profile</h3>
                <p className="muted" style={{ margin: '4px 0 0 0', fontSize: '0.85rem' }}>
                  Update full name, phone number, and profile picture for this driver.
                </p>
              </div>
              <button
                type="button"
                className="btn btn--ghost"
                style={{ padding: '4px 10px', fontSize: '1rem', borderRadius: 'var(--radius-full)' }}
                onClick={() => !editSaving && setEditProfileOpen(false)}
                disabled={editSaving}
              >
                ✕
              </button>
            </div>

            {editError && (
              <div className="field__error" style={{ marginBottom: 'var(--space-3)' }}>
                {editError}
              </div>
            )}

            {editSuccess && (
              <div
                style={{
                  marginBottom: 'var(--space-3)',
                  padding: '10px 14px',
                  background: 'rgba(16, 185, 129, 0.15)',
                  color: '#059669',
                  borderRadius: 'var(--radius-md)',
                  fontWeight: 600,
                  fontSize: '0.85rem',
                }}
              >
                ✓ {editSuccess}
              </div>
            )}

            <form onSubmit={submitEditProfile}>
              {/* Profile Photo Section */}
              <div style={{ marginBottom: 'var(--space-4)' }}>
                <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 600, marginBottom: 8 }}>
                  Driver Profile Photo
                </label>
                <div style={{ display: 'flex', alignItems: 'center', gap: 16, background: 'var(--color-bg-alt)', padding: 14, borderRadius: 'var(--radius-lg)' }}>
                  <div
                    style={{
                      width: 76,
                      height: 76,
                      borderRadius: '50%',
                      overflow: 'hidden',
                      flexShrink: 0,
                      background: 'linear-gradient(135deg, var(--color-primary), #059669)',
                      border: '3px solid var(--color-surface)',
                      boxShadow: '0 4px 10px rgba(0,0,0,0.1)',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                    }}
                  >
                    {previewPhotoUrl ? (
                      <img
                        src={previewPhotoUrl}
                        alt="Preview"
                        style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                      />
                    ) : (
                      <span style={{ fontSize: '1.85rem', fontWeight: 800, color: '#fff' }}>
                        {(editFullName || name)[0]?.toUpperCase() || 'D'}
                      </span>
                    )}
                  </div>

                  <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 8, alignItems: 'flex-start' }}>
                    <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                      <label
                        className="btn btn--primary"
                        style={{
                          padding: '6px 14px',
                          fontSize: '0.8rem',
                          borderRadius: 'var(--radius-full)',
                          cursor: editSaving ? 'not-allowed' : 'pointer',
                          display: 'inline-flex',
                          alignItems: 'center',
                          gap: 6,
                          margin: 0,
                        }}
                      >
                        <span>📁</span> Upload Image
                        <input
                          type="file"
                          accept="image/*"
                          style={{ display: 'none' }}
                          disabled={editSaving}
                          onChange={handlePhotoFileChange}
                        />
                      </label>

                      {previewPhotoUrl && (
                        <button
                          type="button"
                          className="btn btn--ghost"
                          style={{
                            padding: '6px 12px',
                            fontSize: '0.8rem',
                            borderRadius: 'var(--radius-full)',
                            color: 'var(--color-error)',
                            border: '1px solid rgba(239, 68, 68, 0.3)',
                          }}
                          disabled={editSaving}
                          onClick={handleRemovePhoto}
                        >
                          Remove Photo
                        </button>
                      )}
                    </div>
                    {newPhotoFile && (
                      <span style={{ fontSize: '0.75rem', color: '#059669', fontWeight: 600 }}>
                        ✓ New file: {newPhotoFile.name} ({(newPhotoFile.size / 1024).toFixed(0)} KB)
                      </span>
                    )}
                    <span className="muted" style={{ fontSize: '0.75rem' }}>
                      Supports PNG, JPG, WebP (up to 10MB)
                    </span>
                  </div>
                </div>

                {/* Direct Image URL input */}
                <div style={{ marginTop: 10 }}>
                  <label htmlFor="editPhotoUrl" className="muted" style={{ fontSize: '0.75rem', fontWeight: 500, display: 'block', marginBottom: 4 }}>
                    Or paste direct image URL:
                  </label>
                  <input
                    id="editPhotoUrl"
                    type="url"
                    placeholder="https://..."
                    value={editPhotoUrl}
                    disabled={editSaving || Boolean(newPhotoFile)}
                    onChange={(e) => {
                      setEditPhotoUrl(e.target.value);
                      setPreviewPhotoUrl(e.target.value.trim());
                    }}
                    style={{
                      width: '100%',
                      padding: '8px 12px',
                      borderRadius: 'var(--radius-md)',
                      border: '1px solid var(--color-border)',
                      background: Boolean(newPhotoFile) ? 'var(--color-bg-alt)' : 'var(--color-surface)',
                      color: 'var(--color-text)',
                      fontSize: '0.85rem',
                      boxSizing: 'border-box',
                    }}
                  />
                </div>
              </div>

              {/* Full Name Field */}
              <div className="field" style={{ marginBottom: 'var(--space-3)' }}>
                <label htmlFor="editFullName" style={{ fontWeight: 600, fontSize: '0.85rem', display: 'block', marginBottom: 6 }}>
                  Driver Full Name <span style={{ color: 'var(--color-error)' }}>*</span>
                </label>
                <input
                  id="editFullName"
                  type="text"
                  required
                  placeholder="e.g. Chukwuma Adebayo"
                  value={editFullName}
                  disabled={editSaving}
                  onChange={(e) => setEditFullName(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '10px 14px',
                    borderRadius: 'var(--radius-md)',
                    border: '1px solid var(--color-border)',
                    background: 'var(--color-surface)',
                    color: 'var(--color-text)',
                    fontSize: '0.9rem',
                    boxSizing: 'border-box',
                  }}
                />
              </div>

              {/* Phone Number Field */}
              <div className="field" style={{ marginBottom: 'var(--space-4)' }}>
                <label htmlFor="editPhone" style={{ fontWeight: 600, fontSize: '0.85rem', display: 'block', marginBottom: 6 }}>
                  Phone Number
                </label>
                <input
                  id="editPhone"
                  type="tel"
                  placeholder="e.g. +234 801 234 5678"
                  value={editPhone}
                  disabled={editSaving}
                  onChange={(e) => setEditPhone(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '10px 14px',
                    borderRadius: 'var(--radius-md)',
                    border: '1px solid var(--color-border)',
                    background: 'var(--color-surface)',
                    color: 'var(--color-text)',
                    fontSize: '0.9rem',
                    boxSizing: 'border-box',
                  }}
                />
                <span className="muted" style={{ fontSize: '0.75rem', display: 'block', marginTop: 4 }}>
                  Include country code or local Nigerian number (e.g. 08012345678 or +2348012345678)
                </span>
              </div>

              {/* Action buttons */}
              <div style={{ display: 'flex', gap: 'var(--space-2)', justifyContent: 'flex-end', marginTop: 'var(--space-4)', paddingTop: 'var(--space-3)', borderTop: '1px solid var(--color-border)' }}>
                <button
                  type="button"
                  className="btn btn--ghost"
                  style={{ borderRadius: 'var(--radius-full)', padding: '8px 18px' }}
                  disabled={editSaving}
                  onClick={() => setEditProfileOpen(false)}
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="btn btn--primary"
                  style={{ borderRadius: 'var(--radius-full)', padding: '8px 22px' }}
                  disabled={editSaving}
                >
                  {editSaving ? 'Saving Changes...' : 'Save Driver Profile'}
                </button>
              </div>
            </form>
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
