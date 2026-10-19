import { useState, useEffect } from 'react';
import { initializeApp, deleteApp } from 'firebase/app';
import { getAuth, createUserWithEmailAndPassword, signOut, sendPasswordResetEmail } from 'firebase/auth';
import {
  collection,
  doc,
  setDoc,
  updateDoc,
  deleteDoc,
  serverTimestamp,
  onSnapshot,
  query,
  orderBy,
  limit,
  getDocs,
  where,
} from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import { db, functions, firebaseConfig, auth } from '../config/firebase';

export const ALL_STAFF_PAGE_OPTIONS = [
  { id: 'announcements', label: 'Announcements & Popups', path: '/admin/announcements', icon: '📢' },
  { id: 'customer_support', label: 'Customer Support', path: '/admin/customer-support', icon: '💬' },
  { id: 'driver_support', label: 'Driver Support', path: '/admin/driver-support', icon: '🎧' },
  { id: 'promotion', label: 'Promotions', path: '/admin/promotion', icon: '🎁' },
  { id: 'offers', label: 'Special Offers', path: '/admin/offers', icon: '🏷️' },
  { id: 'verification', label: 'Verification Requests', path: '/admin/verification-requests', icon: '🛡️' },
] as const;

export interface StaffActivityRecord {
  id: string;
  staffUid: string;
  staffName: string;
  staffEmail: string;
  page: string;
  actionType: string;
  description: string;
  targetId?: string;
  timestamp?: any;
}

export interface StaffAccount {
  id: string;
  staffUid: string;
  staffId: string;
  firstName: string;
  lastName: string;
  fullName: string;
  email: string;
  phone: string;
  role: string;
  staffType: 'tracking' | 'commission';
  commissionRatePercent: number;
  allowedPages?: string[];
  referralCode: string;
  referralCodeLower?: string;
  referralLink: string;
  previousReferralCodes?: string[];
  accountStatus: 'active' | 'suspended' | 'disabled';
  wallet?: {
    availableBalance: number;
    pendingWithdrawals: number;
    totalEarned: number;
    totalWithdrawn: number;
  };
  bankDetails?: {
    bankName: string;
    accountName: string;
    accountNumber: string;
  };
  stats?: {
    totalReferrals: number;
    customersReferred: number;
    driversReferred: number;
    totalCompanyCommissionGenerated: number;
  };
  createdAt?: any;
}

export interface WithdrawalRequest {
  id: string;
  withdrawalId: string;
  staffId: string;
  staffName: string;
  staffEmail: string;
  amount: number;
  status: 'pending' | 'paid' | 'rejected';
  bankDetails?: {
    bankName?: string;
    accountName?: string;
    accountNumber?: string;
  };
  rejectionReason?: string;
  requestedAt?: any;
  processedAt?: any;
}

export interface StaffReferralUser {
  id: string;
  referredUid: string;
  userType: 'customer' | 'driver';
  email: string;
  fullName: string;
  referralCode: string;
  joinedAt?: any;
}

function formatNgn(amount: number) {
  return '₦' + (amount || 0).toLocaleString('en-NG', { minimumFractionDigits: 0, maximumFractionDigits: 0 });
}

function formatTs(ts: any) {
  if (!ts) return '—';
  try {
    const d = ts?.toDate ? ts.toDate() : new Date(ts);
    return d.toLocaleString('en-US', { month: 'short', day: 'numeric', year: 'numeric', hour: '2-digit', minute: '2-digit' });
  } catch {
    return '—';
  }
}

export function StaffManagementPage() {
  const [tab, setTab] = useState<'all' | 'tracking' | 'commission' | 'withdrawals'>('all');

  const [staffList, setStaffList] = useState<StaffAccount[]>([]);
  const [withdrawals, setWithdrawals] = useState<WithdrawalRequest[]>([]);
  const [loadingStaff, setLoadingStaff] = useState(true);
  const [loadingWithdrawals, setLoadingWithdrawals] = useState(true);
  const [search, setSearch] = useState('');

  // Modals state
  const [showCreateModal, setShowCreateModal] = useState(false);
  const [showEditModal, setShowEditModal] = useState(false);
  const [selectedStaff, setSelectedStaff] = useState<StaffAccount | null>(null);

  const [showProcessWdModal, setShowProcessWdModal] = useState(false);
  const [selectedWd, setSelectedWd] = useState<WithdrawalRequest | null>(null);
  const [wdAction, setWdAction] = useState<'paid' | 'reject'>('paid');
  const [rejectionReason, setRejectionReason] = useState('');
  const [processingWd, setProcessingWd] = useState(false);

  // Create Form State
  const [createForm, setCreateForm] = useState({
    firstName: '',
    lastName: '',
    email: '',
    phone: '',
    staffId: '',
    password: '',
    staffType: 'commission' as 'tracking' | 'commission',
    commissionRatePercent: 50,
    referralCode: '',
    allowedPages: ['announcements', 'customer_support', 'driver_support', 'promotion', 'offers', 'verification'] as string[],
  });
  const [creating, setCreating] = useState(false);
  const [formError, setFormError] = useState<string | null>(null);
  const [showPassword, setShowPassword] = useState(false);

  // Edit Form State
  const [editForm, setEditForm] = useState({
    firstName: '',
    lastName: '',
    phone: '',
    staffType: 'commission' as 'tracking' | 'commission',
    commissionRatePercent: 50,
    referralCode: '',
    accountStatus: 'active' as 'active' | 'suspended' | 'disabled',
    allowedPages: ['announcements', 'customer_support', 'driver_support', 'promotion', 'offers', 'verification'] as string[],
  });
  const [updating, setUpdating] = useState(false);
  const [editError, setEditError] = useState<string | null>(null);

  // View Staff Modal State
  const [showViewModal, setShowViewModal] = useState(false);
  const [viewStaffAccount, setViewStaffAccount] = useState<StaffAccount | null>(null);
  const [viewTab, setViewTab] = useState<'overview' | 'referrals' | 'activities'>('overview');
  const [viewReferrals, setViewReferrals] = useState<StaffReferralUser[]>([]);
  const [loadingReferrals, setLoadingReferrals] = useState(false);
  const [staffActivities, setStaffActivities] = useState<StaffActivityRecord[]>([]);
  const [loadingActivities, setLoadingActivities] = useState(false);
  const [referralSearch, setReferralSearch] = useState('');
  const [referralFilter, setReferralFilter] = useState<'all' | 'customer' | 'driver'>('all');
  const [sendingReset, setSendingReset] = useState(false);
  const [copyFeedback, setCopyFeedback] = useState<string | null>(null);

  async function handleSendPasswordReset() {
    if (!viewStaffAccount?.email) return;
    setSendingReset(true);
    try {
      await sendPasswordResetEmail(auth, viewStaffAccount.email.trim());
      setCopyFeedback(`Password reset email successfully sent to ${viewStaffAccount.email}!`);
      setTimeout(() => setCopyFeedback(null), 4000);
    } catch (err: any) {
      alert(err?.message || 'Failed to send password reset email.');
    } finally {
      setSendingReset(false);
    }
  }

  // Delete / Disable Staff State
  const [showDeleteModal, setShowDeleteModal] = useState(false);
  const [targetStaff, setTargetStaff] = useState<StaffAccount | null>(null);
  const [deletingStaff, setDeletingStaff] = useState(false);
  const [deleteAction, setDeleteAction] = useState<'disable' | 'permanent'>('disable');

  function openDeleteStaff(staff: StaffAccount) {
    setTargetStaff(staff);
    setDeleteAction('disable');
    setShowDeleteModal(true);
  }

  async function handleConfirmDeleteStaff(e: React.FormEvent) {
    e.preventDefault();
    if (!targetStaff) return;
    setDeletingStaff(true);

    try {
      if (deleteAction === 'disable') {
        const newStatus = targetStaff.accountStatus === 'disabled' ? 'active' : 'disabled';
        try {
          const updateFn = httpsCallable(functions, 'updateStaffProfile');
          await updateFn({
            staffUid: targetStaff.id,
            accountStatus: newStatus,
          });
        } catch (_) {}

        try {
          await updateDoc(doc(db, 'staff', targetStaff.id), {
            accountStatus: newStatus,
            updatedAt: serverTimestamp(),
          });
        } catch (_) {}

        setShowDeleteModal(false);
        if (showViewModal) setShowViewModal(false);
      } else {
        // Permanent Delete via Cloud Function
        try {
          const deleteFn = httpsCallable(functions, 'deleteStaffAccount');
          await deleteFn({ staffUid: targetStaff.id });
        } catch (err: any) {
          const isCorsOrInternal =
            err?.message === 'internal' ||
            err?.code === 'functions/internal' ||
            err?.message?.includes?.('CORS') ||
            err?.message?.includes?.('fetch');

          if (isCorsOrInternal) {
            console.warn('deleteStaffAccount Cloud Function unavailable. Fallback: Deleting Firestore document directly.');
            await deleteDoc(doc(db, 'staff', targetStaff.id));
          } else {
            throw err;
          }
        }

        setShowDeleteModal(false);
        if (showViewModal) setShowViewModal(false);
      }
    } catch (err: any) {
      alert(err?.message || 'Failed to complete action.');
    } finally {
      setDeletingStaff(false);
    }
  }

  // Subscribe to staff referrals subcollection and external collections
  useEffect(() => {
    if (!showViewModal || !viewStaffAccount) {
      setViewReferrals([]);
      return undefined;
    }

    setLoadingReferrals(true);
    const staffUid = viewStaffAccount.id;
    const refCodeUpper = (viewStaffAccount.referralCode || '').trim().toUpperCase();

    const loadExternal = async (subRows: StaffReferralUser[]) => {
      try {
        const [custSnap, driverSnap] = await Promise.all([
          getDocs(query(collection(db, 'customers'), where('referredByCode', '==', refCodeUpper))),
          getDocs(query(collection(db, 'drivers'), where('referredByCode', '==', refCodeUpper))),
        ]);

        const externalRows: StaffReferralUser[] = [];
        custSnap.forEach((docSnap) => {
          const d = docSnap.data();
          externalRows.push({
            id: docSnap.id,
            referredUid: docSnap.id,
            userType: 'customer',
            email: d.email || '',
            fullName: d.fullName || `${d.firstName || ''} ${d.lastName || ''}`.trim() || 'Customer',
            referralCode: d.referredByCode || refCodeUpper,
            joinedAt: d.createdAt,
          });
        });

        driverSnap.forEach((docSnap) => {
          const d = docSnap.data();
          externalRows.push({
            id: docSnap.id,
            referredUid: docSnap.id,
            userType: 'driver',
            email: d.email || '',
            fullName: d.fullName || `${d.firstName || ''} ${d.lastName || ''}`.trim() || 'Driver',
            referralCode: d.referredByCode || refCodeUpper,
            joinedAt: d.createdAt,
          });
        });

        // Merge & deduplicate by ID
        const combinedMap = new Map<string, StaffReferralUser>();
        subRows.forEach((r) => combinedMap.set(r.id, r));
        externalRows.forEach((r) => {
          if (!combinedMap.has(r.id)) {
            combinedMap.set(r.id, r);
          }
        });

        const mergedList = Array.from(combinedMap.values());
        mergedList.sort((a, b) => {
          const aTime = a.joinedAt?.toMillis ? a.joinedAt.toMillis() : (a.joinedAt ? new Date(a.joinedAt).getTime() : 0);
          const bTime = b.joinedAt?.toMillis ? b.joinedAt.toMillis() : (b.joinedAt ? new Date(b.joinedAt).getTime() : 0);
          return bTime - aTime;
        });

        setViewReferrals(mergedList);
      } catch (e) {
        console.error('Error fetching external referrals:', e);
        setViewReferrals(subRows);
      } finally {
        setLoadingReferrals(false);
      }
    };

    // 1. Listen to staff subcollection staff/{staffUid}/referrals
    const unsubSub = onSnapshot(
      collection(db, 'staff', staffUid, 'referrals'),
      (snap) => {
        const subRows: StaffReferralUser[] = snap.docs.map((docSnap) => {
          const d = docSnap.data();
          return {
            id: docSnap.id,
            referredUid: d.referredUid || docSnap.id,
            userType: d.userType === 'driver' ? 'driver' : 'customer',
            email: d.email || '',
            fullName: d.fullName || '',
            referralCode: d.referralCode || refCodeUpper,
            joinedAt: d.joinedAt || d.createdAt,
          };
        });

        loadExternal(subRows);
      },
      (err) => {
        console.warn('Subcollection listener fallback:', err?.message);
        loadExternal([]);
      }
    );

    return () => unsubSub();
  }, [showViewModal, viewStaffAccount]);

  // Listen to staff activities audit log
  useEffect(() => {
    if (!showViewModal || !viewStaffAccount) {
      setStaffActivities([]);
      return undefined;
    }

    setLoadingActivities(true);
    const staffUid = viewStaffAccount.staffUid || viewStaffAccount.id;
    const unsub = onSnapshot(
      query(collection(db, 'staff_activities'), where('staffUid', '==', staffUid)),
      (snap) => {
        const rows: StaffActivityRecord[] = snap.docs.map((docSnap) => ({
          id: docSnap.id,
          ...(docSnap.data() as any),
        }));

        rows.sort((a, b) => {
          const aTime = a.timestamp?.toMillis ? a.timestamp.toMillis() : (a.timestamp ? new Date(a.timestamp).getTime() : 0);
          const bTime = b.timestamp?.toMillis ? b.timestamp.toMillis() : (b.timestamp ? new Date(b.timestamp).getTime() : 0);
          return bTime - aTime;
        });

        setStaffActivities(rows);
        setLoadingActivities(false);
      },
      (err) => {
        console.warn('Failed to load staff activities:', err?.message);
        setStaffActivities([]);
        setLoadingActivities(false);
      }
    );
    return () => unsub();
  }, [showViewModal, viewStaffAccount]);

  function openViewStaff(staff: StaffAccount) {
    setViewStaffAccount(staff);
    setViewTab('overview');
    setShowViewModal(true);
    setReferralSearch('');
    setReferralFilter('all');
  }

  // 1. Fetch live staff list
  useEffect(() => {
    const unsub = onSnapshot(
      collection(db, 'staff'),
      (snap) => {
        const rows: StaffAccount[] = snap.docs.map((docSnap) => {
          const data = docSnap.data() as any;
          const createdAt = data.createdAt;
          const createdAtMs = createdAt?.toMillis ? createdAt.toMillis() : (createdAt ? new Date(createdAt).getTime() : 0);
          return {
            id: docSnap.id,
            ...data,
            fullName: data.fullName || `${data.firstName || ''} ${data.lastName || ''}`.trim() || 'Staff Member',
            email: data.email || '',
            staffId: data.staffId || 'STF-00000',
            referralCode: data.referralCode || '',
            staffType: data.staffType || 'commission',
            commissionRatePercent: data.commissionRatePercent ?? 50,
            accountStatus: data.accountStatus || 'active',
            createdAtMs,
          };
        });
        rows.sort((a: any, b: any) => (b.createdAtMs || 0) - (a.createdAtMs || 0));
        setStaffList(rows);
        setLoadingStaff(false);
      },
      (err) => {
        console.error('Failed to fetch staff list:', err);
        setFormError(`Failed to load staff list: ${err.message}`);
        setLoadingStaff(false);
      },
    );
    return () => unsub();
  }, []);

  // 2. Fetch live withdrawal requests
  useEffect(() => {
    const unsub = onSnapshot(
      query(collection(db, 'staff_withdrawal_requests'), orderBy('requestedAt', 'desc'), limit(100)),
      (snap) => {
        const rows: WithdrawalRequest[] = snap.docs.map((docSnap) => ({
          id: docSnap.id,
          ...(docSnap.data() as any),
        }));
        setWithdrawals(rows);
        setLoadingWithdrawals(false);
      },
      () => setLoadingWithdrawals(false),
    );
    return () => unsub();
  }, []);

  // Auto-generate referral code when names change in create form
  useEffect(() => {
    if (createForm.firstName || createForm.lastName) {
      const code = `CARIDE-${(createForm.firstName || createForm.lastName).toUpperCase().replace(/[^A-Z0-9]/g, '')}`;
      setCreateForm((prev) => ({ ...prev, referralCode: code }));
    }
  }, [createForm.firstName, createForm.lastName]);

  // Handle Staff Creation
  async function handleCreateStaff(e: React.FormEvent) {
    e.preventDefault();
    setFormError(null);
    setCreating(true);

    try {
      try {
        const createFn = httpsCallable(functions, 'createStaffAccount');
        await createFn(createForm);
      } catch (err: any) {
        const isCorsOrInternal =
          err?.message === 'internal' ||
          err?.code === 'functions/internal' ||
          err?.message?.includes?.('CORS') ||
          err?.message?.includes?.('fetch') ||
          err?.message?.includes?.('Failed');

        if (isCorsOrInternal) {
          console.warn('Cloud Function unavailable/CORS blocked. Provisioning staff via direct Firebase fallback.');

          const appName = `temp-staff-app-${Date.now()}`;
          const tempApp = initializeApp(firebaseConfig, appName);
          const tempAuth = getAuth(tempApp);

          try {
            const userCred = await createUserWithEmailAndPassword(tempAuth, createForm.email.trim(), createForm.password);
            const uid = userCred.user.uid;
            const staffId = `STF-${Math.floor(10000 + Math.random() * 90000)}`;
            const fullName = `${createForm.firstName.trim()} ${createForm.lastName.trim()}`;

            await setDoc(doc(db, 'staff', uid), {
              staffUid: uid,
              staffId,
              firstName: createForm.firstName.trim(),
              lastName: createForm.lastName.trim(),
              fullName,
              email: createForm.email.trim(),
              phone: createForm.phone.trim(),
              role: 'staff',
              staffType: createForm.staffType,
              commissionRatePercent: createForm.staffType === 'commission' ? Number(createForm.commissionRatePercent) : 0,
              referralCode: createForm.referralCode.trim().toUpperCase(),
              referralCodeLower: createForm.referralCode.trim().toLowerCase(),
              referralLink: `https://caride.app/ref/${createForm.referralCode.trim().toUpperCase()}`,
              accountStatus: 'active',
              wallet: {
                availableBalance: 0,
                pendingWithdrawals: 0,
                totalEarned: 0,
                totalWithdrawn: 0,
              },
              stats: {
                totalReferrals: 0,
                customersReferred: 0,
                driversReferred: 0,
                totalCompanyCommissionGenerated: 0,
              },
              createdAt: serverTimestamp(),
            });
          } finally {
            await signOut(tempAuth).catch(() => {});
            await deleteApp(tempApp).catch(() => {});
          }
        } else {
          throw err;
        }
      }

      setShowCreateModal(false);
      setCreateForm({
        firstName: '',
        lastName: '',
        email: '',
        phone: '',
        staffId: '',
        password: '',
        staffType: 'commission',
        commissionRatePercent: 50,
        referralCode: '',
        allowedPages: ['announcements', 'customer_support', 'driver_support', 'promotion', 'offers', 'verification'],
      });
    } catch (err: any) {
      setFormError(err?.message || 'Failed to create staff account.');
    } finally {
      setCreating(false);
    }
  }

  // Open Edit Modal
  function openEdit(staff: StaffAccount) {
    setSelectedStaff(staff);
    setEditForm({
      firstName: staff.firstName || '',
      lastName: staff.lastName || '',
      phone: staff.phone || '',
      staffType: staff.staffType || 'commission',
      commissionRatePercent: staff.commissionRatePercent || 50,
      referralCode: staff.referralCode || '',
      accountStatus: staff.accountStatus || 'active',
      allowedPages: Array.isArray(staff.allowedPages)
        ? staff.allowedPages
        : ['announcements', 'customer_support', 'driver_support', 'promotion', 'offers', 'verification'],
    });
    setEditError(null);
    setShowEditModal(true);
  }

  // Handle Staff Edit
  async function handleUpdateStaff(e: React.FormEvent) {
    e.preventDefault();
    if (!selectedStaff) return;
    setEditError(null);
    setUpdating(true);

    try {
      try {
        const updateFn = httpsCallable(functions, 'updateStaffProfile');
        await updateFn({
          staffUid: selectedStaff.id,
          ...editForm,
        });
      } catch (_) {}

      await updateDoc(doc(db, 'staff', selectedStaff.id), {
        firstName: editForm.firstName.trim(),
        lastName: editForm.lastName.trim(),
        fullName: `${editForm.firstName.trim()} ${editForm.lastName.trim()}`,
        phone: editForm.phone.trim(),
        staffType: editForm.staffType,
        commissionRatePercent: editForm.staffType === 'commission' ? Number(editForm.commissionRatePercent) : 0,
        referralCode: editForm.referralCode.trim().toUpperCase(),
        accountStatus: editForm.accountStatus,
        allowedPages: editForm.allowedPages,
        updatedAt: serverTimestamp(),
      });

      setShowEditModal(false);
    } catch (err: any) {
      setEditError(err?.message || 'Failed to update staff profile.');
    } finally {
      setUpdating(false);
    }
  }

  // Handle Withdrawal Processing
  async function handleProcessWithdrawal(e: React.FormEvent) {
    e.preventDefault();
    if (!selectedWd) return;
    setProcessingWd(true);

    try {
      const processFn = httpsCallable(functions, 'processStaffWithdrawal');
      await processFn({
        withdrawalDocId: selectedWd.id,
        action: wdAction,
        rejectionReason: wdAction === 'reject' ? rejectionReason : undefined,
      });
      setShowProcessWdModal(false);
      setRejectionReason('');
    } catch (err: any) {
      const msg =
        err?.message === 'internal' || err?.code === 'functions/internal'
          ? 'Cloud Function error (internal/CORS). Please ensure the "processStaffWithdrawal" Cloud Function is deployed to Firebase with { cors: true } enabled.'
          : err?.message || 'Failed to process withdrawal.';
      alert(msg);
    } finally {
      setProcessingWd(false);
    }
  }

  const trackingCount = staffList.filter((s) => s.staffType === 'tracking').length;
  const commissionCount = staffList.filter((s) => s.staffType === 'commission').length;
  const totalEarnedSum = staffList.reduce((acc, s) => acc + (s.wallet?.totalEarned || 0), 0);
  const pendingWdSum = withdrawals.filter((w) => w.status === 'pending').reduce((acc, w) => acc + w.amount, 0);

  const filteredStaff = staffList.filter((s) => {
    if (tab === 'tracking' && s.staffType !== 'tracking') return false;
    if (tab === 'commission' && s.staffType !== 'commission') return false;
    if (!search) return true;
    const q = search.toLowerCase();
    const name = (s.fullName || `${s.firstName || ''} ${s.lastName || ''}`).toLowerCase();
    const email = (s.email || '').toLowerCase();
    const staffId = (s.staffId || '').toLowerCase();
    const refCode = (s.referralCode || '').toLowerCase();
    return name.includes(q) || email.includes(q) || staffId.includes(q) || refCode.includes(q);
  });

  return (
    <div>
      {/* Top Header */}
      <div style={{ marginBottom: 'var(--space-5)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 'var(--space-3)' }}>
        <div>
          <h2 style={{ margin: 0, fontSize: '1.4rem', fontWeight: 800 }}>Staff Referral & Commission Management</h2>
          <p className="muted" style={{ margin: '4px 0 0', fontSize: '0.85rem' }}>
            Create and manage Tracking Staff and Commission Staff accounts and process manual withdrawal requests.
          </p>
        </div>

        <div style={{ display: 'flex', gap: 'var(--space-2)' }}>
          <button type="button" className="btn btn--primary" style={{ borderRadius: 'var(--radius-full)', padding: '10px 22px' }} onClick={() => setShowCreateModal(true)}>
            + Create Staff Account
          </button>
        </div>
      </div>

      {/* Summary KPI Cards */}
      <div className="card-grid" style={{ marginBottom: 'var(--space-5)' }}>
        <article className="card" style={{ borderRadius: 'var(--radius-xl)' }}>
          <div className="muted" style={{ fontSize: '0.85rem', fontWeight: 600 }}>Total Staff</div>
          <div style={{ fontSize: '2rem', fontWeight: 800, color: 'var(--color-primary)', marginTop: 4 }}>
            {staffList.length}
          </div>
          <div className="muted" style={{ fontSize: '0.75rem', marginTop: 4 }}>Registered staff members</div>
        </article>

        <article className="card" style={{ borderRadius: 'var(--radius-xl)' }}>
          <div className="muted" style={{ fontSize: '0.85rem', fontWeight: 600 }}>Tracking / Commission</div>
          <div style={{ fontSize: '2rem', fontWeight: 800, color: 'var(--color-primary)', marginTop: 4 }}>
            {trackingCount} / {commissionCount}
          </div>
          <div className="muted" style={{ fontSize: '0.75rem', marginTop: 4 }}>Tracking / Commission count</div>
        </article>

        <article className="card" style={{ borderRadius: 'var(--radius-xl)' }}>
          <div className="muted" style={{ fontSize: '0.85rem', fontWeight: 600 }}>Total Staff Earnings</div>
          <div style={{ fontSize: '2rem', fontWeight: 800, color: 'var(--color-primary)', marginTop: 4 }}>
            {formatNgn(totalEarnedSum)}
          </div>
          <div className="muted" style={{ fontSize: '0.75rem', marginTop: 4 }}>All-time earned by Commission Staff</div>
        </article>

        <article className="card" style={{ borderRadius: 'var(--radius-xl)' }}>
          <div className="muted" style={{ fontSize: '0.85rem', fontWeight: 600 }}>Pending Withdrawals</div>
          <div style={{ fontSize: '2rem', fontWeight: 800, color: '#F59E0B', marginTop: 4 }}>
            {formatNgn(pendingWdSum)}
          </div>
          <div className="muted" style={{ fontSize: '0.75rem', marginTop: 4 }}>{withdrawals.filter((w) => w.status === 'pending').length} requests pending review</div>
        </article>
      </div>

      {/* Navigation Tabs Underline */}
      <div className="tab-bar-underline" style={{ marginBottom: 'var(--space-5)' }}>
        <button
          type="button"
          className={`tab-bar-underline__btn ${tab === 'all' ? 'active' : ''}`}
          onClick={() => setTab('all')}
        >
          All Staff <span className="tab-bar-underline__badge">{staffList.length}</span>
        </button>
        <button
          type="button"
          className={`tab-bar-underline__btn ${tab === 'tracking' ? 'active' : ''}`}
          onClick={() => setTab('tracking')}
        >
          Tracking Staff <span className="tab-bar-underline__badge">{trackingCount}</span>
        </button>
        <button
          type="button"
          className={`tab-bar-underline__btn ${tab === 'commission' ? 'active' : ''}`}
          onClick={() => setTab('commission')}
        >
          Commission Staff <span className="tab-bar-underline__badge">{commissionCount}</span>
        </button>
        <button
          type="button"
          className={`tab-bar-underline__btn ${tab === 'withdrawals' ? 'active' : ''}`}
          onClick={() => setTab('withdrawals')}
        >
          Withdrawal Requests <span className="tab-bar-underline__badge">{withdrawals.filter((w) => w.status === 'pending').length}</span>
        </button>
      </div>

      {/* TAB: Staff List */}
      {(tab === 'all' || tab === 'tracking' || tab === 'commission') && (
        <div className="table-card">
          <div style={{ padding: 'var(--space-4)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 'var(--space-3)', borderBottom: '1px solid var(--color-border)' }}>
            <h3 style={{ margin: 0, fontSize: '1.1rem', fontWeight: 700 }}>
              {tab === 'all' ? 'Staff Directory' : tab === 'tracking' ? 'Tracking Staff Directory' : 'Commission Staff Directory'}
            </h3>

            <div className="search-pill-wrap" style={{ width: '100%', maxWidth: 360 }}>
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <circle cx="11" cy="11" r="8" /><line x1="21" y1="21" x2="16.65" y2="16.65" />
              </svg>
              <input
                type="text"
                placeholder="Search staff name, email, code..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
              />
            </div>
          </div>

          {loadingStaff ? (
            <div style={{ padding: 'var(--space-6)', textAlign: 'center' }}>
              <p className="muted">Loading staff accounts...</p>
            </div>
          ) : filteredStaff.length === 0 ? (
            <div style={{ padding: 'var(--space-6)', textAlign: 'center' }}>
              <p className="muted">No staff accounts found.</p>
            </div>
          ) : (
            <div style={{ overflowX: 'auto' }}>
              <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '0.85rem' }}>
                <thead>
                  <tr style={{ borderBottom: '1px solid var(--color-border)', textAlign: 'left', background: 'var(--color-bg-alt)' }}>
                    <th style={{ padding: '12px 16px' }}>Staff Member</th>
                    <th style={{ padding: '12px 16px' }}>Staff ID</th>
                    <th style={{ padding: '12px 16px' }}>Staff Type</th>
                    <th style={{ padding: '12px 16px' }}>Commission Rate</th>
                    <th style={{ padding: '12px 16px' }}>Referral Code</th>
                    <th style={{ padding: '12px 16px' }}>Total Referrals</th>
                    <th style={{ padding: '12px 16px' }}>Wallet / Earnings</th>
                    <th style={{ padding: '12px 16px' }}>Status</th>
                    <th style={{ padding: '12px 16px' }}>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredStaff.map((staff) => {
                    const isCommission = staff.staffType === 'commission';
                    return (
                      <tr key={staff.id} style={{ borderBottom: '1px solid var(--color-border)' }}>
                        <td style={{ padding: '12px 16px' }}>
                          <div style={{ fontWeight: 700 }}>{staff.fullName}</div>
                          <div className="muted" style={{ fontSize: '0.75rem' }}>{staff.email}</div>
                        </td>
                        <td style={{ padding: '12px 16px', fontFamily: 'monospace' }}>{staff.staffId}</td>
                        <td style={{ padding: '12px 16px' }}>
                          <span className={`badge ${isCommission ? 'badge--ok' : 'badge--info'}`} style={{ borderRadius: 'var(--radius-full)' }}>
                            {isCommission ? 'Commission Staff' : 'Tracking Staff'}
                          </span>
                        </td>
                        <td style={{ padding: '12px 16px', fontWeight: 700 }}>
                          {isCommission ? (
                            <div>
                              <div>{staff.commissionRatePercent}%</div>
                              <div className="muted" style={{ fontSize: '0.70rem' }}>of CaRide Comm.</div>
                            </div>
                          ) : (
                            <span className="muted">₦0 (Tracking)</span>
                          )}
                        </td>
                        <td style={{ padding: '12px 16px', fontWeight: 800, color: 'var(--color-primary)' }}>
                          <span style={{ background: 'var(--color-bg-alt)', padding: '3px 8px', borderRadius: 'var(--radius-full)', border: '1px solid var(--color-border)' }}>
                            {staff.referralCode}
                          </span>
                        </td>
                        <td style={{ padding: '12px 16px' }}>
                          <strong>{staff.stats?.totalReferrals || 0}</strong>
                          <span className="muted" style={{ fontSize: '0.75rem', marginLeft: 4 }}>
                            ({staff.stats?.customersReferred || 0} CUST / {staff.stats?.driversReferred || 0} DRV)
                          </span>
                        </td>
                        <td style={{ padding: '12px 16px' }}>
                          {isCommission ? (
                            <div>
                              <div style={{ fontWeight: 800, color: 'var(--color-primary)' }}>
                                Avail: {formatNgn(staff.wallet?.availableBalance || 0)}
                              </div>
                              <div className="muted" style={{ fontSize: '0.75rem' }}>
                                Earned: {formatNgn(staff.wallet?.totalEarned || 0)}
                              </div>
                            </div>
                          ) : (
                            <span className="muted">₦0 (No Wallet)</span>
                          )}
                        </td>
                        <td style={{ padding: '12px 16px' }}>
                          <span className={`badge ${staff.accountStatus === 'active' ? 'badge--ok' : 'badge--warn'}`} style={{ borderRadius: 'var(--radius-full)' }}>
                            {staff.accountStatus}
                          </span>
                        </td>
                        <td style={{ padding: '12px 16px' }}>
                          <div style={{ display: 'flex', gap: 6, flexWrap: 'nowrap' }}>
                            <button
                              type="button"
                              className="btn btn--primary"
                              style={{ padding: '6px 14px', fontSize: '0.75rem', borderRadius: 'var(--radius-full)' }}
                              onClick={() => openViewStaff(staff)}
                            >
                              View Staff
                            </button>
                            <button
                              type="button"
                              className="btn btn--ghost"
                              style={{ padding: '6px 14px', fontSize: '0.75rem', borderRadius: 'var(--radius-full)' }}
                              onClick={() => openEdit(staff)}
                            >
                              Edit
                            </button>
                            <button
                              type="button"
                              className="btn btn--ghost"
                              style={{ padding: '6px 14px', fontSize: '0.75rem', borderRadius: 'var(--radius-full)', color: '#EF4444' }}
                              onClick={() => openDeleteStaff(staff)}
                            >
                              Delete
                            </button>
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}

      {/* TAB: Withdrawal Requests */}
      {tab === 'withdrawals' && (
        <div className="table-card">
          <div style={{ padding: 'var(--space-4)', borderBottom: '1px solid var(--color-border)' }}>
            <h3 style={{ margin: 0, fontSize: '1.1rem', fontWeight: 700 }}>
              Staff Withdrawal Requests (Manual Bank Transfer)
            </h3>
          </div>

          {loadingWithdrawals ? (
            <div style={{ padding: 'var(--space-6)', textAlign: 'center' }}>
              <p className="muted">Loading withdrawal requests...</p>
            </div>
          ) : withdrawals.length === 0 ? (
            <div style={{ padding: 'var(--space-6)', textAlign: 'center' }}>
              <p className="muted">No withdrawal requests found.</p>
            </div>
          ) : (
            <div style={{ overflowX: 'auto' }}>
              <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '0.85rem' }}>
                <thead>
                  <tr style={{ borderBottom: '1px solid var(--color-border)', textAlign: 'left', background: 'var(--color-bg-alt)' }}>
                    <th style={{ padding: '12px 16px' }}>Requested Date</th>
                    <th style={{ padding: '12px 16px' }}>Reference ID</th>
                    <th style={{ padding: '12px 16px' }}>Staff Name</th>
                    <th style={{ padding: '12px 16px' }}>Amount</th>
                    <th style={{ padding: '12px 16px' }}>Bank Account Details</th>
                    <th style={{ padding: '12px 16px' }}>Status</th>
                    <th style={{ padding: '12px 16px' }}>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {withdrawals.map((wd) => {
                    const isPending = wd.status === 'pending';
                    const isPaid = wd.status === 'paid';
                    return (
                      <tr key={wd.id} style={{ borderBottom: '1px solid var(--color-border)' }}>
                        <td style={{ padding: '12px 16px', whiteSpace: 'nowrap' }}>{formatTs(wd.requestedAt)}</td>
                        <td style={{ padding: '12px 16px', fontFamily: 'monospace', fontWeight: 700 }}>{wd.withdrawalId}</td>
                        <td style={{ padding: '12px 16px' }}>
                          <div style={{ fontWeight: 700 }}>{wd.staffName}</div>
                          <div className="muted" style={{ fontSize: '0.75rem' }}>{wd.staffEmail}</div>
                        </td>
                        <td style={{ padding: '12px 16px', fontWeight: 800, fontSize: '1rem', color: isPaid ? '#10B981' : isPending ? '#F59E0B' : '#EF4444' }}>
                          {formatNgn(wd.amount)}
                        </td>
                        <td style={{ padding: '12px 16px' }}>
                          {wd.bankDetails?.bankName ? (
                            <div>
                              <div style={{ fontWeight: 600 }}>{wd.bankDetails.bankName} - {wd.bankDetails.accountNumber}</div>
                              <div className="muted" style={{ fontSize: '0.75rem' }}>{wd.bankDetails.accountName}</div>
                            </div>
                          ) : (
                            <span className="muted">No bank details provided</span>
                          )}
                        </td>
                        <td style={{ padding: '12px 16px' }}>
                          <span className={`badge ${isPaid ? 'badge--ok' : isPending ? 'badge--warn' : 'badge--info'}`} style={{ borderRadius: 'var(--radius-full)' }}>
                            {wd.status}
                          </span>
                          {wd.rejectionReason && (
                            <div className="muted" style={{ fontSize: '0.70rem', color: '#EF4444', marginTop: 2 }}>
                              {wd.rejectionReason}
                            </div>
                          )}
                        </td>
                        <td style={{ padding: '12px 16px' }}>
                          {isPending ? (
                            <div style={{ display: 'flex', gap: 6 }}>
                              <button
                                type="button"
                                className="btn btn--primary"
                                style={{ padding: '6px 14px', fontSize: '0.75rem', background: '#10B981', borderRadius: 'var(--radius-full)' }}
                                onClick={() => {
                                  setSelectedWd(wd);
                                  setWdAction('paid');
                                  setShowProcessWdModal(true);
                                }}
                              >
                                Mark Paid
                              </button>
                              <button
                                type="button"
                                className="btn btn--ghost"
                                style={{ padding: '6px 14px', fontSize: '0.75rem', color: '#EF4444', borderRadius: 'var(--radius-full)' }}
                                onClick={() => {
                                  setSelectedWd(wd);
                                  setWdAction('reject');
                                  setShowProcessWdModal(true);
                                }}
                              >
                                Reject
                              </button>
                            </div>
                          ) : (
                            <span className="muted" style={{ fontSize: '0.75rem' }}>Processed</span>
                          )}
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}

      {/* CREATE STAFF MODAL */}
      {showCreateModal && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.5)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100, padding: 16 }}>
          <div className="card" style={{ maxWidth: 540, width: '100%', maxHeight: '90vh', overflowY: 'auto', borderRadius: 'var(--radius-xl)' }}>
            <h3 style={{ marginTop: 0, marginBottom: 'var(--space-3)' }}>Create New Staff Account</h3>

            {formError && (
              <div style={{ background: 'rgba(239, 68, 68, 0.1)', color: '#EF4444', padding: '10px 16px', borderRadius: 'var(--radius-lg)', marginBottom: 12, fontSize: '0.85rem' }}>
                {formError}
              </div>
            )}

            <form onSubmit={handleCreateStaff} style={{ display: 'grid', gap: 'var(--space-3)' }}>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
                <div>
                  <label style={{ display: 'block', fontWeight: 600, fontSize: '0.8rem', marginBottom: 4 }}>First Name</label>
                  <input type="text" className="input" style={{ width: '100%', borderRadius: 'var(--radius-full)' }} value={createForm.firstName} onChange={(e) => setCreateForm({ ...createForm, firstName: e.target.value })} required />
                </div>
                <div>
                  <label style={{ display: 'block', fontWeight: 600, fontSize: '0.8rem', marginBottom: 4 }}>Last Name</label>
                  <input type="text" className="input" style={{ width: '100%', borderRadius: 'var(--radius-full)' }} value={createForm.lastName} onChange={(e) => setCreateForm({ ...createForm, lastName: e.target.value })} required />
                </div>
              </div>

              <div>
                <label style={{ display: 'block', fontWeight: 600, fontSize: '0.8rem', marginBottom: 4 }}>Email Address</label>
                <input type="email" className="input" style={{ width: '100%', borderRadius: 'var(--radius-full)' }} value={createForm.email} onChange={(e) => setCreateForm({ ...createForm, email: e.target.value })} required />
              </div>

              <div>
                <label style={{ display: 'block', fontWeight: 600, fontSize: '0.8rem', marginBottom: 4 }}>Phone Number</label>
                <input type="tel" className="input" style={{ width: '100%', borderRadius: 'var(--radius-full)' }} value={createForm.phone} onChange={(e) => setCreateForm({ ...createForm, phone: e.target.value })} placeholder="+234..." />
              </div>

              <div>
                <label style={{ display: 'block', fontWeight: 600, fontSize: '0.8rem', marginBottom: 4 }}>Staff Password</label>
                <div style={{ position: 'relative' }}>
                  <input
                    type={showPassword ? 'text' : 'password'}
                    className="input"
                    style={{ width: '100%', paddingRight: '40px', borderRadius: 'var(--radius-full)' }}
                    value={createForm.password}
                    onChange={(e) => setCreateForm({ ...createForm, password: e.target.value })}
                    minLength={6}
                    required
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword((prev) => !prev)}
                    style={{
                      position: 'absolute',
                      right: '12px',
                      top: '50%',
                      transform: 'translateY(-50%)',
                      background: 'none',
                      border: 'none',
                      cursor: 'pointer',
                      color: 'var(--color-text-muted)',
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'center',
                      padding: '4px',
                    }}
                    title={showPassword ? 'Hide password' : 'Show password'}
                  >
                    {showPassword ? (
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" width="18" height="18">
                        <path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24" />
                        <line x1="1" y1="1" x2="23" y2="23" />
                      </svg>
                    ) : (
                      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" width="18" height="18">
                        <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
                        <circle cx="12" cy="12" r="3" />
                      </svg>
                    )}
                  </button>
                </div>
              </div>

              <div>
                <label style={{ display: 'block', fontWeight: 600, fontSize: '0.8rem', marginBottom: 4 }}>Staff Type</label>
                <select className="input" style={{ width: '100%', borderRadius: 'var(--radius-full)' }} value={createForm.staffType} onChange={(e) => setCreateForm({ ...createForm, staffType: e.target.value as any })}>
                  <option value="commission">Commission Staff (Earns % of CaRide Commission)</option>
                  <option value="tracking">Tracking Staff (Track Referrals Only - ₦0 Comm.)</option>
                </select>
              </div>

              {createForm.staffType === 'commission' && (
                <div>
                  <label style={{ display: 'block', fontWeight: 600, fontSize: '0.8rem', marginBottom: 4 }}>
                    Staff Share of CaRide Commission (%)
                  </label>
                  <input type="number" min="0" max="100" className="input" style={{ width: '100%', borderRadius: 'var(--radius-full)' }} value={createForm.commissionRatePercent} onChange={(e) => setCreateForm({ ...createForm, commissionRatePercent: Number(e.target.value) })} required />
                  <span className="muted" style={{ fontSize: '0.75rem', marginTop: 4, display: 'block' }}>
                    Staff commission is calculated as a percentage of CaRide's company commission from eligible rides, not from the total ride fare.
                  </span>
                </div>
              )}

              <div>
                <label style={{ display: 'block', fontWeight: 600, fontSize: '0.8rem', marginBottom: 4 }}>Unique Referral Code</label>
                <input type="text" className="input" style={{ width: '100%', borderRadius: 'var(--radius-full)' }} value={createForm.referralCode} onChange={(e) => setCreateForm({ ...createForm, referralCode: e.target.value.toUpperCase() })} required />
              </div>

              {/* Page Permissions / Access Control */}
              <div style={{ border: '1px solid var(--color-border)', borderRadius: 'var(--radius-lg)', padding: 14, background: 'var(--color-bg-subtle, rgba(0,0,0,0.02))' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
                  <label style={{ fontWeight: 700, fontSize: '0.85rem' }}>
                    🔐 Page Permissions & Sidebar Access
                  </label>
                  <div style={{ display: 'flex', gap: 6 }}>
                    <button
                      type="button"
                      className="btn btn--ghost"
                      style={{ fontSize: '0.7rem', padding: '4px 10px', borderRadius: 'var(--radius-full)' }}
                      onClick={() => setCreateForm({ ...createForm, allowedPages: ALL_STAFF_PAGE_OPTIONS.map(p => p.id) })}
                    >
                      Select All
                    </button>
                    <button
                      type="button"
                      className="btn btn--ghost"
                      style={{ fontSize: '0.7rem', padding: '4px 10px', borderRadius: 'var(--radius-full)' }}
                      onClick={() => setCreateForm({ ...createForm, allowedPages: [] })}
                    >
                      Clear All
                    </button>
                  </div>
                </div>
                <p className="muted" style={{ fontSize: '0.75rem', marginTop: 0, marginBottom: 12 }}>
                  Select the pages this staff member can access in their sidebar and manage as staff.
                </p>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
                  {ALL_STAFF_PAGE_OPTIONS.map((pageOpt) => {
                    const checked = createForm.allowedPages.includes(pageOpt.id);
                    return (
                      <label
                        key={pageOpt.id}
                        style={{
                          display: 'flex',
                          alignItems: 'center',
                          gap: 8,
                          padding: '8px 12px',
                          borderRadius: 'var(--radius-md)',
                          background: checked ? 'var(--color-primary-light, rgba(22, 163, 74, 0.08))' : 'var(--color-bg)',
                          border: `1px solid ${checked ? 'var(--color-primary)' : 'var(--color-border)'}`,
                          cursor: 'pointer',
                          fontSize: '0.8rem',
                          fontWeight: checked ? 600 : 400,
                        }}
                      >
                        <input
                          type="checkbox"
                          checked={checked}
                          onChange={(e) => {
                            const newPages = e.target.checked
                              ? [...createForm.allowedPages, pageOpt.id]
                              : createForm.allowedPages.filter(p => p !== pageOpt.id);
                            setCreateForm({ ...createForm, allowedPages: newPages });
                          }}
                        />
                        <span>{pageOpt.icon} {pageOpt.label}</span>
                      </label>
                    );
                  })}
                </div>
              </div>

              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10, marginTop: 12 }}>
                <button type="button" className="btn btn--ghost" style={{ borderRadius: 'var(--radius-full)', padding: '8px 18px' }} onClick={() => setShowCreateModal(false)}>Cancel</button>
                <button type="submit" className="btn btn--primary" style={{ borderRadius: 'var(--radius-full)', padding: '8px 20px' }} disabled={creating}>
                  {creating ? 'Creating Account...' : 'Create Staff'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* EDIT STAFF MODAL */}
      {showEditModal && selectedStaff && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.5)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100, padding: 16 }}>
          <div className="card" style={{ maxWidth: 540, width: '100%', maxHeight: '90vh', overflowY: 'auto', borderRadius: 'var(--radius-xl)' }}>
            <h3 style={{ marginTop: 0, marginBottom: 'var(--space-3)' }}>Edit Staff Profile ({selectedStaff.staffId})</h3>

            {editError && (
              <div style={{ background: 'rgba(239, 68, 68, 0.1)', color: '#EF4444', padding: '10px 16px', borderRadius: 'var(--radius-lg)', marginBottom: 12, fontSize: '0.85rem' }}>
                {editError}
              </div>
            )}

            <form onSubmit={handleUpdateStaff} style={{ display: 'grid', gap: 'var(--space-3)' }}>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
                <div>
                  <label style={{ display: 'block', fontWeight: 600, fontSize: '0.8rem', marginBottom: 4 }}>First Name</label>
                  <input type="text" className="input" style={{ width: '100%', borderRadius: 'var(--radius-full)' }} value={editForm.firstName} onChange={(e) => setEditForm({ ...editForm, firstName: e.target.value })} required />
                </div>
                <div>
                  <label style={{ display: 'block', fontWeight: 600, fontSize: '0.8rem', marginBottom: 4 }}>Last Name</label>
                  <input type="text" className="input" style={{ width: '100%', borderRadius: 'var(--radius-full)' }} value={editForm.lastName} onChange={(e) => setEditForm({ ...editForm, lastName: e.target.value })} required />
                </div>
              </div>

              <div>
                <label style={{ display: 'block', fontWeight: 600, fontSize: '0.8rem', marginBottom: 4 }}>Staff Type</label>
                <select className="input" style={{ width: '100%', borderRadius: 'var(--radius-full)' }} value={editForm.staffType} onChange={(e) => setEditForm({ ...editForm, staffType: e.target.value as any })}>
                  <option value="commission">Commission Staff (Earns % of CaRide Commission)</option>
                  <option value="tracking">Tracking Staff (Track Referrals Only - ₦0 Comm.)</option>
                </select>
              </div>

              {editForm.staffType === 'commission' && (
                <div>
                  <label style={{ display: 'block', fontWeight: 600, fontSize: '0.8rem', marginBottom: 4 }}>Staff Share of CaRide Commission (%)</label>
                  <input type="number" min="0" max="100" className="input" style={{ width: '100%', borderRadius: 'var(--radius-full)' }} value={editForm.commissionRatePercent} onChange={(e) => setEditForm({ ...editForm, commissionRatePercent: Number(e.target.value) })} required />
                  <span className="muted" style={{ fontSize: '0.75rem', marginTop: 4, display: 'block' }}>
                    Note: Updating commission percentage applies to qualifying activity occurring AFTER this change.
                  </span>
                </div>
              )}

              <div>
                <label style={{ display: 'block', fontWeight: 600, fontSize: '0.8rem', marginBottom: 4 }}>Referral Code</label>
                <input type="text" className="input" style={{ width: '100%', borderRadius: 'var(--radius-full)' }} value={editForm.referralCode} onChange={(e) => setEditForm({ ...editForm, referralCode: e.target.value.toUpperCase() })} required />
              </div>

              <div>
                <label style={{ display: 'block', fontWeight: 600, fontSize: '0.8rem', marginBottom: 4 }}>Account Status</label>
                <select className="input" style={{ width: '100%', borderRadius: 'var(--radius-full)' }} value={editForm.accountStatus} onChange={(e) => setEditForm({ ...editForm, accountStatus: e.target.value as any })}>
                  <option value="active">Active</option>
                  <option value="suspended">Suspended</option>
                  <option value="disabled">Disabled</option>
                </select>
              </div>

              {/* Page Permissions / Access Control */}
              <div style={{ border: '1px solid var(--color-border)', borderRadius: 'var(--radius-lg)', padding: 14, background: 'var(--color-bg-subtle, rgba(0,0,0,0.02))' }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
                  <label style={{ fontWeight: 700, fontSize: '0.85rem' }}>
                    🔐 Page Permissions & Sidebar Access
                  </label>
                  <div style={{ display: 'flex', gap: 6 }}>
                    <button
                      type="button"
                      className="btn btn--ghost"
                      style={{ fontSize: '0.7rem', padding: '4px 10px', borderRadius: 'var(--radius-full)' }}
                      onClick={() => setEditForm({ ...editForm, allowedPages: ALL_STAFF_PAGE_OPTIONS.map(p => p.id) })}
                    >
                      Select All
                    </button>
                    <button
                      type="button"
                      className="btn btn--ghost"
                      style={{ fontSize: '0.7rem', padding: '4px 10px', borderRadius: 'var(--radius-full)' }}
                      onClick={() => setEditForm({ ...editForm, allowedPages: [] })}
                    >
                      Clear All
                    </button>
                  </div>
                </div>
                <p className="muted" style={{ fontSize: '0.75rem', marginTop: 0, marginBottom: 12 }}>
                  Select the pages this staff member can access in their sidebar and manage as staff.
                </p>

                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 8 }}>
                  {ALL_STAFF_PAGE_OPTIONS.map((pageOpt) => {
                    const checked = editForm.allowedPages.includes(pageOpt.id);
                    return (
                      <label
                        key={pageOpt.id}
                        style={{
                          display: 'flex',
                          alignItems: 'center',
                          gap: 8,
                          padding: '8px 12px',
                          borderRadius: 'var(--radius-md)',
                          background: checked ? 'var(--color-primary-light, rgba(22, 163, 74, 0.08))' : 'var(--color-bg)',
                          border: `1px solid ${checked ? 'var(--color-primary)' : 'var(--color-border)'}`,
                          cursor: 'pointer',
                          fontSize: '0.8rem',
                          fontWeight: checked ? 600 : 400,
                        }}
                      >
                        <input
                          type="checkbox"
                          checked={checked}
                          onChange={(e) => {
                            const newPages = e.target.checked
                              ? [...editForm.allowedPages, pageOpt.id]
                              : editForm.allowedPages.filter(p => p !== pageOpt.id);
                            setEditForm({ ...editForm, allowedPages: newPages });
                          }}
                        />
                        <span>{pageOpt.icon} {pageOpt.label}</span>
                      </label>
                    );
                  })}
                </div>
              </div>

              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10, marginTop: 12 }}>
                <button type="button" className="btn btn--ghost" style={{ borderRadius: 'var(--radius-full)', padding: '8px 18px' }} onClick={() => setShowEditModal(false)}>Cancel</button>
                <button type="submit" className="btn btn--primary" style={{ borderRadius: 'var(--radius-full)', padding: '8px 20px' }} disabled={updating}>
                  {updating ? 'Updating...' : 'Save Changes'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* PROCESS WITHDRAWAL MODAL */}
      {showProcessWdModal && selectedWd && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.5)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100, padding: 16 }}>
          <div className="card" style={{ maxWidth: 480, width: '100%', borderRadius: 'var(--radius-xl)' }}>
            <h3 style={{ marginTop: 0, marginBottom: 'var(--space-3)' }}>
              {wdAction === 'paid' ? 'Mark Withdrawal as Paid' : 'Reject Withdrawal Request'}
            </h3>

            <p style={{ fontSize: '0.9rem', marginBottom: 12 }}>
              Staff Member: <strong>{selectedWd.staffName}</strong><br />
              Amount Requested: <strong style={{ color: 'var(--color-primary)' }}>{formatNgn(selectedWd.amount)}</strong><br />
              Reference ID: <code style={{ fontFamily: 'monospace' }}>{selectedWd.withdrawalId}</code>
            </p>

            {wdAction === 'paid' ? (
              <p className="muted" style={{ fontSize: '0.85rem', marginBottom: 16 }}>
                Please confirm that you have manually transferred {formatNgn(selectedWd.amount)} to the staff member's bank account.
              </p>
            ) : (
              <div style={{ marginBottom: 16 }}>
                <label style={{ display: 'block', fontWeight: 600, fontSize: '0.85rem', marginBottom: 4 }}>Rejection Reason (Required)</label>
                <textarea
                  className="input"
                  style={{ width: '100%', height: 80, borderRadius: 'var(--radius-md)' }}
                  value={rejectionReason}
                  onChange={(e) => setRejectionReason(e.target.value)}
                  placeholder="e.g. Bank details could not be verified..."
                  required
                />
              </div>
            )}

            <form onSubmit={handleProcessWithdrawal} style={{ display: 'flex', justifyContent: 'flex-end', gap: 10 }}>
              <button type="button" className="btn btn--ghost" style={{ borderRadius: 'var(--radius-full)' }} onClick={() => setShowProcessWdModal(false)}>Cancel</button>
              <button
                type="submit"
                className={`btn ${wdAction === 'paid' ? 'btn--primary' : 'btn--ghost'}`}
                style={{ borderRadius: 'var(--radius-full)', ...(wdAction === 'paid' ? { background: '#10B981' } : { color: '#EF4444' }) }}
                disabled={processingWd}
              >
                {processingWd ? 'Processing...' : wdAction === 'paid' ? 'Confirm Paid' : 'Confirm Rejection'}
              </button>
            </form>
          </div>
        </div>
      )}

      {/* VIEW STAFF DETAILS MODAL */}
      {showViewModal && viewStaffAccount && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.6)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100, padding: 16 }}>
          <div className="card" style={{ maxWidth: 860, width: '100%', maxHeight: '90vh', overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 20, borderRadius: 'var(--radius-xl)' }}>
            {/* Modal Header */}
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', borderBottom: '1px solid var(--color-border)', paddingBottom: 14 }}>
              <div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                  <h3 style={{ margin: 0, fontSize: '1.3rem', fontWeight: 800 }}>{viewStaffAccount.fullName}</h3>
                  <span className={`badge ${viewStaffAccount.accountStatus === 'active' ? 'badge--ok' : 'badge--warn'}`} style={{ borderRadius: 'var(--radius-full)' }}>
                    {viewStaffAccount.accountStatus.toUpperCase()}
                  </span>
                  <span className={`badge ${viewStaffAccount.staffType === 'commission' ? 'badge--info' : 'badge--neutral'}`} style={{ borderRadius: 'var(--radius-full)' }}>
                    {viewStaffAccount.staffType.toUpperCase()}
                  </span>
                </div>
                <div className="muted" style={{ fontSize: '0.85rem', marginTop: 4 }}>
                  Staff ID: <strong style={{ fontFamily: 'monospace' }}>{viewStaffAccount.staffId || viewStaffAccount.id}</strong>
                </div>
              </div>
              <button
                type="button"
                className="btn btn--ghost"
                style={{ fontSize: '1.2rem', padding: '2px 8px', borderRadius: 'var(--radius-full)' }}
                onClick={() => setShowViewModal(false)}
              >
                ✕
              </button>
            </div>

            {/* Quick Copy Feedback Toast */}
            {copyFeedback && (
              <div style={{ background: 'rgba(16, 185, 129, 0.15)', color: '#10B981', border: '1px solid rgba(16, 185, 129, 0.3)', padding: '6px 14px', borderRadius: 'var(--radius-full)', fontSize: '0.85rem' }}>
                {copyFeedback}
              </div>
            )}

            {/* Core Info Grid */}
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: 12 }}>
              <div style={{ background: 'var(--color-bg-subtle, rgba(0,0,0,0.03))', padding: 14, borderRadius: 'var(--radius-lg)', border: '1px solid var(--color-border)' }}>
                <div className="muted" style={{ fontSize: '0.75rem', textTransform: 'uppercase', fontWeight: 700 }}>Contact Info</div>
                <div style={{ fontWeight: 600, fontSize: '0.85rem', marginTop: 4 }}>📧 {viewStaffAccount.email}</div>
                <div style={{ fontWeight: 600, fontSize: '0.85rem', marginTop: 2 }}>📞 {viewStaffAccount.phone || 'No phone'}</div>
              </div>

              <div style={{ background: 'var(--color-bg-subtle, rgba(0,0,0,0.03))', padding: 14, borderRadius: 'var(--radius-lg)', border: '1px solid var(--color-border)' }}>
                <div className="muted" style={{ fontSize: '0.75rem', textTransform: 'uppercase', fontWeight: 700 }}>Referral Code & Link</div>
                <div style={{ display: 'flex', alignItems: 'center', gap: 6, marginTop: 4 }}>
                  <code style={{ fontSize: '0.95rem', fontWeight: 800, color: 'var(--color-primary)' }}>{viewStaffAccount.referralCode}</code>
                  <button
                    type="button"
                    className="btn btn--ghost"
                    style={{ padding: '2px 10px', fontSize: '0.7rem', borderRadius: 'var(--radius-full)' }}
                    onClick={() => {
                      navigator.clipboard.writeText(viewStaffAccount.referralCode);
                      setCopyFeedback('Referral code copied to clipboard!');
                      setTimeout(() => setCopyFeedback(null), 2500);
                    }}
                  >
                    Copy
                  </button>
                </div>
                <div style={{ fontSize: '0.75rem', marginTop: 4, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }} className="muted">
                  Link: {viewStaffAccount.referralLink || `https://caride.app/ref/${viewStaffAccount.referralCode}`}
                </div>
              </div>

              <div style={{ background: 'var(--color-bg-subtle, rgba(0,0,0,0.03))', padding: 14, borderRadius: 'var(--radius-lg)', border: '1px solid var(--color-border)' }}>
                <div className="muted" style={{ fontSize: '0.75rem', textTransform: 'uppercase', fontWeight: 700 }}>Commission & Type</div>
                <div style={{ fontWeight: 700, fontSize: '0.9rem', marginTop: 4 }}>
                  {viewStaffAccount.staffType === 'commission' ? `${viewStaffAccount.commissionRatePercent ?? 50}% Commission` : 'Tracking Only'}
                </div>
                <div className="muted" style={{ fontSize: '0.75rem', marginTop: 2 }}>
                  Joined: {formatTs(viewStaffAccount.createdAt)}
                </div>
              </div>
            </div>

            {/* Wallet & Bank Details (If Commission Staff) */}
            {viewStaffAccount.staffType === 'commission' && (
              <div style={{ background: 'rgba(16, 185, 129, 0.05)', padding: 16, borderRadius: 'var(--radius-lg)', border: '1px solid rgba(16, 185, 129, 0.2)' }}>
                <h4 style={{ margin: '0 0 10px 0', fontSize: '0.9rem', color: '#10B981', fontWeight: 700 }}>
                  💰 Commission Wallet & Earnings Summary
                </h4>
                <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(160px, 1fr))', gap: 10 }}>
                  <div>
                    <div className="muted" style={{ fontSize: '0.75rem' }}>Available Balance</div>
                    <div style={{ fontSize: '1.1rem', fontWeight: 800, color: '#10B981' }}>
                      {formatNgn(viewStaffAccount.wallet?.availableBalance || 0)}
                    </div>
                  </div>
                  <div>
                    <div className="muted" style={{ fontSize: '0.75rem' }}>Total Earned</div>
                    <div style={{ fontSize: '1rem', fontWeight: 700 }}>
                      {formatNgn(viewStaffAccount.wallet?.totalEarned || 0)}
                    </div>
                  </div>
                  <div>
                    <div className="muted" style={{ fontSize: '0.75rem' }}>Pending Withdrawals</div>
                    <div style={{ fontSize: '1rem', fontWeight: 700, color: '#F59E0B' }}>
                      {formatNgn(viewStaffAccount.wallet?.pendingWithdrawals || 0)}
                    </div>
                  </div>
                  <div>
                    <div className="muted" style={{ fontSize: '0.75rem' }}>Total Withdrawn</div>
                    <div style={{ fontSize: '1rem', fontWeight: 700 }}>
                      {formatNgn(viewStaffAccount.wallet?.totalWithdrawn || 0)}
                    </div>
                  </div>
                </div>

                {viewStaffAccount.bankDetails && (
                  <div style={{ marginTop: 12, paddingTop: 10, borderTop: '1px solid rgba(16, 185, 129, 0.2)', fontSize: '0.8rem' }}>
                    <strong>Bank Account:</strong> {viewStaffAccount.bankDetails.bankName || 'N/A'} — {viewStaffAccount.bankDetails.accountNumber || 'N/A'} ({viewStaffAccount.bankDetails.accountName || 'N/A'})
                  </div>
                )}
              </div>
            )}

            {/* View Modal Navigation Sub-Tabs */}
            <div style={{ display: 'flex', gap: 8, borderBottom: '1px solid var(--color-border)', paddingBottom: 8 }}>
              <button
                type="button"
                className={`btn ${viewTab === 'overview' ? 'btn--primary' : 'btn--ghost'}`}
                style={{ padding: '6px 16px', fontSize: '0.85rem', borderRadius: 'var(--radius-full)' }}
                onClick={() => setViewTab('overview')}
              >
                👥 Overview & Referrals ({viewReferrals.length})
              </button>
              <button
                type="button"
                className={`btn ${viewTab === 'activities' ? 'btn--primary' : 'btn--ghost'}`}
                style={{ padding: '6px 16px', fontSize: '0.85rem', borderRadius: 'var(--radius-full)' }}
                onClick={() => setViewTab('activities')}
              >
                📜 Staff Activities Audit Log ({staffActivities.length})
              </button>
            </div>

            {/* TAB 1: Overview & Referred Users */}
            {viewTab === 'overview' && (
              <div>
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 10, marginBottom: 12 }}>
                  <h4 style={{ margin: 0, fontSize: '1rem', fontWeight: 800 }}>
                    Referred Accounts Downline ({viewReferrals.length})
                  </h4>

                <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                  <button
                    type="button"
                    className={`btn ${referralFilter === 'all' ? 'btn--primary' : 'btn--ghost'}`}
                    style={{ padding: '4px 12px', fontSize: '0.75rem', borderRadius: 'var(--radius-full)' }}
                    onClick={() => setReferralFilter('all')}
                  >
                    All ({viewReferrals.length})
                  </button>
                  <button
                    type="button"
                    className={`btn ${referralFilter === 'customer' ? 'btn--primary' : 'btn--ghost'}`}
                    style={{ padding: '4px 12px', fontSize: '0.75rem', background: referralFilter === 'customer' ? '#10B981' : undefined, borderRadius: 'var(--radius-full)' }}
                    onClick={() => setReferralFilter('customer')}
                  >
                    👤 Customers ({viewReferrals.filter(r => r.userType === 'customer').length})
                  </button>
                  <button
                    type="button"
                    className={`btn ${referralFilter === 'driver' ? 'btn--primary' : 'btn--ghost'}`}
                    style={{ padding: '4px 12px', fontSize: '0.75rem', background: referralFilter === 'driver' ? 'var(--color-primary)' : undefined, borderRadius: 'var(--radius-full)' }}
                    onClick={() => setReferralFilter('driver')}
                  >
                    🚗 Drivers ({viewReferrals.filter(r => r.userType === 'driver').length})
                  </button>
                </div>
              </div>

              {/* Search Referral Field */}
              <div style={{ marginBottom: 12 }}>
                <input
                  type="text"
                  className="input"
                  style={{ width: '100%', fontSize: '0.85rem', borderRadius: 'var(--radius-full)' }}
                  placeholder="Search referred user name, email, or code..."
                  value={referralSearch}
                  onChange={(e) => setReferralSearch(e.target.value)}
                />
              </div>

              {/* Referred Users Table */}
              {loadingReferrals ? (
                <p className="muted" style={{ fontSize: '0.85rem' }}>Loading registered users...</p>
              ) : (() => {
                const filtered = viewReferrals.filter((r) => {
                  if (referralFilter === 'customer' && r.userType !== 'customer') return false;
                  if (referralFilter === 'driver' && r.userType !== 'driver') return false;
                  if (!referralSearch) return true;
                  const q = referralSearch.toLowerCase();
                  return (
                    (r.fullName || '').toLowerCase().includes(q) ||
                    (r.email || '').toLowerCase().includes(q) ||
                    (r.referralCode || '').toLowerCase().includes(q)
                  );
                });

                if (filtered.length === 0) {
                  return (
                    <div style={{ padding: '24px 12px', textAlign: 'center', background: 'var(--color-bg-subtle, rgba(0,0,0,0.02))', borderRadius: 'var(--radius-lg)', border: '1px solid var(--color-border)' }}>
                      <p className="muted" style={{ margin: 0, fontSize: '0.85rem' }}>
                        No referred users found matching the selected filter/search.
                      </p>
                    </div>
                  );
                }

                return (
                  <div style={{ overflowX: 'auto', maxHeight: 300 }}>
                    <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '0.85rem' }}>
                      <thead style={{ position: 'sticky', top: 0, background: 'var(--color-bg)' }}>
                        <tr style={{ borderBottom: '2px solid var(--color-border)', textAlign: 'left' }}>
                          <th style={{ padding: '8px 12px' }}>User Details</th>
                          <th style={{ padding: '8px 12px' }}>User Type</th>
                          <th style={{ padding: '8px 12px' }}>Joined Date</th>
                          <th style={{ padding: '8px 12px' }}>Referral Code Used</th>
                        </tr>
                      </thead>
                      <tbody>
                        {filtered.map((refUser) => (
                          <tr key={refUser.id} style={{ borderBottom: '1px solid var(--color-border)' }}>
                            <td style={{ padding: '10px 12px' }}>
                              <div style={{ fontWeight: 700 }}>{refUser.fullName || 'User'}</div>
                              <div className="muted" style={{ fontSize: '0.75rem' }}>{refUser.email || 'No email registered'}</div>
                            </td>
                            <td style={{ padding: '10px 12px' }}>
                              {refUser.userType === 'driver' ? (
                                <span className="badge" style={{ background: 'rgba(22, 163, 74, 0.12)', color: 'var(--color-primary)', border: '1px solid rgba(22, 163, 74, 0.3)', borderRadius: 'var(--radius-full)' }}>
                                  🚗 DRIVER
                                </span>
                              ) : (
                                <span className="badge" style={{ background: 'rgba(16, 185, 129, 0.15)', color: '#10B981', border: '1px solid rgba(16, 185, 129, 0.3)', borderRadius: 'var(--radius-full)' }}>
                                  👤 CUSTOMER (RIDER)
                                </span>
                              )}
                            </td>
                            <td style={{ padding: '10px 12px', whiteSpace: 'nowrap' }}>
                              {formatTs(refUser.joinedAt)}
                            </td>
                            <td style={{ padding: '10px 12px', fontFamily: 'monospace', fontWeight: 700 }}>
                              {refUser.referralCode || viewStaffAccount.referralCode}
                            </td>
                          </tr>
                        ))}
                      </tbody>
                    </table>
                  </div>
                );
              })()}
              </div>
            )}

            {/* TAB 2: Staff Activities Log */}
            {viewTab === 'activities' && (
              <div>
                <h4 style={{ margin: '0 0 12px 0', fontSize: '1rem', fontWeight: 800 }}>
                  📜 Staff Activities Real-Time Audit Log
                </h4>

                {loadingActivities ? (
                  <p className="muted" style={{ fontSize: '0.85rem' }}>Loading activity logs...</p>
                ) : staffActivities.length === 0 ? (
                  <div style={{ padding: '24px 12px', textAlign: 'center', background: 'var(--color-bg-subtle, rgba(0,0,0,0.02))', borderRadius: 'var(--radius-lg)', border: '1px solid var(--color-border)' }}>
                    <p className="muted" style={{ margin: 0, fontSize: '0.85rem' }}>
                      No activity logs recorded for this staff member yet.
                    </p>
                  </div>
                ) : (
                  <div style={{ overflowX: 'auto', maxHeight: 350 }}>
                    <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '0.85rem' }}>
                      <thead style={{ position: 'sticky', top: 0, background: 'var(--color-bg)' }}>
                        <tr style={{ borderBottom: '2px solid var(--color-border)', textAlign: 'left' }}>
                          <th style={{ padding: '8px 12px' }}>Timestamp</th>
                          <th style={{ padding: '8px 12px' }}>Module / Page</th>
                          <th style={{ padding: '8px 12px' }}>Action Performed</th>
                          <th style={{ padding: '8px 12px' }}>Details / Target</th>
                        </tr>
                      </thead>
                      <tbody>
                        {staffActivities.map((act) => {
                          const pageOpt = ALL_STAFF_PAGE_OPTIONS.find(p => p.id === act.page);
                          return (
                            <tr key={act.id} style={{ borderBottom: '1px solid var(--color-border)' }}>
                              <td style={{ padding: '10px 12px', whiteSpace: 'nowrap' }}>
                                {formatTs(act.timestamp)}
                              </td>
                              <td style={{ padding: '10px 12px' }}>
                                <span className="badge" style={{ background: 'rgba(22, 163, 74, 0.1)', color: 'var(--color-primary)', border: '1px solid rgba(22, 163, 74, 0.3)', borderRadius: 'var(--radius-full)' }}>
                                  {pageOpt?.icon || '⚙️'} {pageOpt?.label || act.page}
                                </span>
                              </td>
                              <td style={{ padding: '10px 12px', fontWeight: 700 }}>
                                {act.actionType}
                              </td>
                              <td style={{ padding: '10px 12px' }}>
                                <div>{act.description}</div>
                                {act.targetId && (
                                  <div className="muted" style={{ fontSize: '0.75rem', fontFamily: 'monospace', marginTop: 2 }}>
                                    ID: {act.targetId}
                                  </div>
                                )}
                              </td>
                            </tr>
                          );
                        })}
                      </tbody>
                    </table>
                  </div>
                )}
              </div>
            )}

            {/* Modal Footer */}
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 10, paddingTop: 12, borderTop: '1px solid var(--color-border)' }}>
              <div style={{ display: 'flex', gap: 10, flexWrap: 'wrap' }}>
                <button
                  type="button"
                  className="btn btn--ghost"
                  style={{ color: '#EF4444', borderRadius: 'var(--radius-full)' }}
                  onClick={() => openDeleteStaff(viewStaffAccount)}
                >
                  🗑️ Manage / Delete Staff
                </button>
                <button
                  type="button"
                  className="btn btn--ghost"
                  style={{ color: 'var(--color-primary)', border: '1px solid var(--color-primary)', borderRadius: 'var(--radius-full)' }}
                  onClick={handleSendPasswordReset}
                  disabled={sendingReset}
                >
                  🔑 {sendingReset ? 'Sending Reset Link...' : 'Send Password Reset Email'}
                </button>
              </div>
              <button type="button" className="btn btn--ghost" style={{ borderRadius: 'var(--radius-full)' }} onClick={() => setShowViewModal(false)}>
                Close
              </button>
            </div>
          </div>
        </div>
      )}

      {/* DELETE / DISABLE CONFIRMATION MODAL */}
      {showDeleteModal && targetStaff && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.6)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 110, padding: 16 }}>
          <div className="card" style={{ maxWidth: 500, width: '100%', borderRadius: 'var(--radius-xl)' }}>
            <h3 style={{ marginTop: 0, color: '#EF4444', marginBottom: 10 }}>
              Manage Staff Account: {targetStaff.fullName}
            </h3>

            <p style={{ fontSize: '0.85rem', marginBottom: 16 }}>
              Choose an action for staff member <strong>{targetStaff.fullName}</strong> (<code style={{ fontFamily: 'monospace' }}>{targetStaff.referralCode}</code>):
            </p>

            <form onSubmit={handleConfirmDeleteStaff} style={{ display: 'grid', gap: 14 }}>
              {/* Option Selector Cards */}
              <div
                style={{
                  border: `2px solid ${deleteAction === 'disable' ? 'var(--color-primary)' : 'var(--color-border)'}`,
                  background: deleteAction === 'disable' ? 'var(--color-primary-light, rgba(22, 163, 74, 0.05))' : 'var(--color-bg-subtle, rgba(0,0,0,0.02))',
                  padding: 14,
                  borderRadius: 'var(--radius-lg)',
                  cursor: 'pointer',
                }}
                onClick={() => setDeleteAction('disable')}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <input
                    type="radio"
                    name="deleteAction"
                    checked={deleteAction === 'disable'}
                    onChange={() => setDeleteAction('disable')}
                  />
                  <strong style={{ fontSize: '0.9rem' }}>
                    {targetStaff.accountStatus === 'disabled' ? 'Re-enable Staff Account' : 'Disable Account (Recommended)'}
                  </strong>
                </div>
                <p className="muted" style={{ margin: '4px 0 0 24px', fontSize: '0.78rem' }}>
                  {targetStaff.accountStatus === 'disabled'
                    ? 'Re-activates staff login and restores referral capabilities.'
                    : 'Immediately revokes login access and stops referral earnings, while preserving historical downline and transaction records for accounting.'}
                </p>
              </div>

              <div
                style={{
                  border: `2px solid ${deleteAction === 'permanent' ? '#EF4444' : 'var(--color-border)'}`,
                  background: deleteAction === 'permanent' ? 'rgba(239, 68, 68, 0.05)' : 'var(--color-bg-subtle, rgba(0,0,0,0.02))',
                  padding: 14,
                  borderRadius: 'var(--radius-lg)',
                  cursor: 'pointer',
                }}
                onClick={() => setDeleteAction('permanent')}
              >
                <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                  <input
                    type="radio"
                    name="deleteAction"
                    checked={deleteAction === 'permanent'}
                    onChange={() => setDeleteAction('permanent')}
                  />
                  <strong style={{ fontSize: '0.9rem', color: '#EF4444' }}>
                    Permanently Delete Account
                  </strong>
                </div>
                <p className="muted" style={{ margin: '4px 0 0 24px', fontSize: '0.78rem' }}>
                  Permanently deletes the Firebase Authentication user and removes all profile records from Firestore. <strong>This action cannot be undone.</strong>
                </p>
              </div>

              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10, marginTop: 10 }}>
                <button type="button" className="btn btn--ghost" style={{ borderRadius: 'var(--radius-full)' }} onClick={() => setShowDeleteModal(false)} disabled={deletingStaff}>
                  Cancel
                </button>
                <button
                  type="submit"
                  className="btn"
                  style={{
                    background: deleteAction === 'permanent' ? '#EF4444' : 'var(--color-primary)',
                    color: '#FFF',
                    borderRadius: 'var(--radius-full)',
                    padding: '8px 20px',
                  }}
                  disabled={deletingStaff}
                >
                  {deletingStaff
                    ? 'Processing...'
                    : deleteAction === 'permanent'
                    ? 'Confirm Permanent Deletion'
                    : targetStaff.accountStatus === 'disabled'
                    ? 'Confirm Re-enable'
                    : 'Confirm Disable Account'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
