import { useEffect, useState } from 'react';
import {
  collection,
  onSnapshot,
  orderBy,
  query,
  limit,
  Timestamp,
  where,
  getDocs,
  doc,
  updateDoc,
} from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import { db, functions, auth } from '../config/firebase';
import { formatNgn } from '../util/money';

// ─── Types ────────────────────────────────────────────────────────────────────

interface BankAccount {
  bankName: string;
  accountName: string;
  accountNumber: string;
  maskedAccountNumber: string;
  bankCode?: string;
}

interface DriverRecord {
  id: string;
  fullName: string;
  email: string;
  phone?: string;
  profilePhotoUrl?: string;
  tier?: string;
  walletBalance: number;
  vehicleInfo?: {
    make: string;
    model: string;
    plateNumber: string;
  };
  bankAccount?: BankAccount | null;
  lastWithdrawalAt?: Timestamp;
}

interface PayoutRecord {
  id: string;
  driverId: string;
  driverName?: string;
  amount: number;
  status: 'successful' | 'failed';
  transactpayPayoutReference?: string;
  payoutReference?: string;
  createdAt: Timestamp;
  processedBy: string;
  batchId?: string | null;
  reference?: string;
  failureReason?: string;
}

interface BatchRecord {
  id: string;
  driverCount: number;
  totalAmount: number;
  status: 'pending' | 'processing' | 'completed';
  createdAt: Timestamp;
  createdBy: string;
  successCount?: number;
  failedCount?: number;
}

interface BatchEntry {
  driverUid: string;
  fullName: string;
  email: string;
  phone?: string;
  walletBalance: number;
  status: 'pending' | 'successful' | 'failed';
  failureReason?: string;
  bankAccount: BankAccount | null;
}

interface AuditRecord {
  id: string;
  adminId: string;
  action: string;
  amount?: number;
  batchId?: string;
  driverId?: string;
  reason?: string;
  createdAt: Timestamp;
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

function initials(name: string) {
  return name
    .split(' ')
    .map((w) => w[0])
    .join('')
    .toUpperCase()
    .slice(0, 2);
}

export function WithdrawalsPage() {
  // Tabs: Balances, Batches, Payout History, Audit Logs
  const [activeTab, setActiveTab] = useState<'balances' | 'batches' | 'payouts' | 'audits'>('balances');

  // Core Data Lists
  const [drivers, setDrivers] = useState<DriverRecord[]>([]);
  const [payouts, setPayouts] = useState<PayoutRecord[]>([]);
  const [batches, setBatches] = useState<BatchRecord[]>([]);
  const [audits, setAudits] = useState<AuditRecord[]>([]);

  // Loaders
  const [loadingDrivers, setLoadingDrivers] = useState(true);
  const [loadingPayouts, setLoadingPayouts] = useState(true);
  const [loadingBatches, setLoadingBatches] = useState(true);
  const [loadingAudits, setLoadingAudits] = useState(true);

  // Search & Filters
  const [searchQuery, setSearchQuery] = useState('');
  const [tierFilter, setTierFilter] = useState('all');
  const [statusFilter, setStatusFilter] = useState('all');

  // Selection states & modals
  const [selectedDriver, setSelectedDriver] = useState<DriverRecord | null>(null);
  const [confirmPayoutDriver, setConfirmPayoutDriver] = useState<DriverRecord | null>(null);
  const [batchEntries, setBatchEntries] = useState<BatchEntry[]>([]);
  const [loadingBatchEntries, setLoadingBatchEntries] = useState(false);
  const [showReviewBatch, setShowReviewBatch] = useState<BatchRecord | null>(null);

  // Call state management
  const [actionProcessing, setActionProcessing] = useState(false);
  const [actionError, setActionError] = useState<string | null>(null);
  const [actionSuccess, setActionSuccess] = useState<string | null>(null);

  // ── 1. Listen for Driver Wallets (positive balances & general details)
  useEffect(() => {
    if (!auth.currentUser) return;
    const unsub = onSnapshot(collection(db, 'drivers'), async (snap) => {
      const list: DriverRecord[] = [];
      await Promise.all(
        snap.docs.map(async (dDoc) => {
          const dData = dDoc.data();
          // Fetch default bank account for this driver
          const bankSnap = await getDocs(
            query(collection(db, 'drivers', dDoc.id, 'bankAccounts'), where('isDefault', '==', true), limit(1))
          );
          const bank = bankSnap.empty ? null : (bankSnap.docs[0].data() as BankAccount);

          // Get vehicle info if any
          const vehicleSnap = await getDocs(collection(db, 'drivers', dDoc.id, 'vehicle'));
          const vehicle = vehicleSnap.empty ? undefined : (vehicleSnap.docs[0].data() as any);

          list.push({
            id: dDoc.id,
            fullName: (dData.fullName as string) ?? '',
            email: (dData.email as string) ?? '',
            phone: (dData.phone as string) ?? '',
            profilePhotoUrl: (dData.profilePhotoUrl as string) ?? '',
            tier: (dData.tier as string) ?? 'bronze',
            walletBalance: (dData.walletBalance as number) ?? 0,
            bankAccount: bank,
            vehicleInfo: vehicle
              ? {
                  make: vehicle.make ?? '',
                  model: vehicle.model ?? '',
                  plateNumber: vehicle.plateNumber ?? '',
                }
              : undefined,
          });
        })
      );
      setDrivers(list.sort((a, b) => b.walletBalance - a.walletBalance));
      setLoadingDrivers(false);
    });
    return () => unsub();
  }, []);

  // ── 2. Listen for Individual Payout Records
  useEffect(() => {
    if (!auth.currentUser) return;
    const q = query(collection(db, 'driverPayouts'), orderBy('createdAt', 'desc'));
    const unsub = onSnapshot(q, (snap) => {
      const list = snap.docs.map((d) => ({
        id: d.id,
        ...(d.data() as Omit<PayoutRecord, 'id'>),
      }));
      setPayouts(list);
      setLoadingPayouts(false);
    });
    return () => unsub();
  }, []);

  // ── 3. Listen for Withdrawal Batches
  useEffect(() => {
    if (!auth.currentUser) return;
    const q = query(collection(db, 'withdrawalBatches'), orderBy('createdAt', 'desc'));
    const unsub = onSnapshot(q, (snap) => {
      const list = snap.docs.map((d) => ({
        id: d.id,
        ...(d.data() as Omit<BatchRecord, 'id'>),
      }));
      setBatches(list);
      setLoadingBatches(false);

      // Check if there is an active pending batch to display in review panel
      const pendingBatch = list.find((b) => b.status === 'pending');
      if (pendingBatch && !showReviewBatch) {
        loadBatchEntries(pendingBatch);
      }
    });
    return () => unsub();
  }, [showReviewBatch]);

  // ── 4. Listen for Admin Audit Logs
  useEffect(() => {
    if (!auth.currentUser) return;
    const q = query(collection(db, 'adminAuditLogs'), orderBy('createdAt', 'desc'));
    const unsub = onSnapshot(q, (snap) => {
      const list = snap.docs.map((d) => ({
        id: d.id,
        ...(d.data() as Omit<AuditRecord, 'id'>),
      }));
      setAudits(list);
      setLoadingAudits(false);
    });
    return () => unsub();
  }, []);

  // Helper to load subcollection entries for a settlement batch
  const loadBatchEntries = async (batch: BatchRecord) => {
    setLoadingBatchEntries(true);
    setShowReviewBatch(batch);
    try {
      const entriesSnap = await getDocs(collection(db, 'withdrawalBatches', batch.id, 'entries'));
      const list = entriesSnap.docs.map((d) => d.data() as BatchEntry);
      setBatchEntries(list);
    } catch (e) {
      console.error(e);
    } finally {
      setLoadingBatchEntries(false);
    }
  };

  // ── 5. Trigger Single Payout API
  const handleSinglePayout = async (driver: DriverRecord) => {
    setActionProcessing(true);
    setActionError(null);
    setActionSuccess(null);
    try {
      const fn = httpsCallable<{ driverId: string; amount: number }, any>(functions, 'adminProcessSinglePayout');
      const res = await fn({ driverId: driver.id, amount: driver.walletBalance });
      if (res.data.success) {
        setActionSuccess(`Payout of ${formatNgn(driver.walletBalance)} to ${driver.fullName} successful!`);
        setConfirmPayoutDriver(null);
      } else {
        setActionError(res.data.failureReason || 'Transfer execution failed.');
      }
    } catch (e: any) {
      setActionError(e.message || 'Error occurred while processing payout.');
    } finally {
      setActionProcessing(false);
    }
  };

  // ── 6. Generate Settlement Batch (Snapshot Wallets)
  const handleGenerateBatch = async () => {
    setActionProcessing(true);
    setActionError(null);
    setActionSuccess(null);
    try {
      const fn = httpsCallable<void, any>(functions, 'adminCreateSettlementBatch');
      const res = await fn();
      if (res.data.success) {
        setActionSuccess('Settlement batch generated successfully!');
      } else {
        setActionError(res.data.message || 'No drivers with positive wallet balance to snapshot.');
      }
    } catch (e: any) {
      setActionError(e.message || 'Failed to create settlement batch.');
    } finally {
      setActionProcessing(false);
    }
  };

  // ── 7. Execute Batch Payouts
  const handleExecuteBatch = async (batchId: string) => {
    setActionProcessing(true);
    setActionError(null);
    setActionSuccess(null);
    try {
      const fn = httpsCallable<{ batchId: string }, any>(functions, 'adminExecuteSettlementBatch');
      const res = await fn({ batchId });
      if (res.data.success) {
        setActionSuccess(`Batch payouts processed! Success: ${res.data.successCount}, Failed: ${res.data.failedCount}`);
        setShowReviewBatch(null);
      } else {
        setActionError(res.data.message || 'Failed to execute payouts.');
      }
    } catch (e: any) {
      setActionError(e.message || 'Failed to execute payouts.');
    } finally {
      setActionProcessing(false);
    }
  };

  // ── 8. Cancel Batch
  const handleCancelBatch = async (batchId: string) => {
    setActionProcessing(true);
    setActionError(null);
    setActionSuccess(null);
    try {
      const batchRef = doc(db, 'withdrawalBatches', batchId);
      await updateDoc(batchRef, { status: 'cancelled' });
      setActionSuccess('Settlement batch cancelled successfully.');
      setShowReviewBatch(null);
    } catch (e: any) {
      setActionError(e.message || 'Failed to cancel settlement batch.');
    } finally {
      setActionProcessing(false);
    }
  };

  // ── 9. Retry Payout (Individual or Batch)
  const handleRetryPayout = async (payoutId: string) => {
    setActionProcessing(true);
    setActionError(null);
    setActionSuccess(null);
    try {
      const fn = httpsCallable<{ payoutId: string }, any>(functions, 'adminRetryFailedPayout');
      const res = await fn({ payoutId });
      if (res.data.success) {
        setActionSuccess('Payout retry executed successfully!');
      } else {
        setActionError(res.data.failureReason || 'Payout retry failed.');
      }
    } catch (e: any) {
      setActionError(e.message || 'Failed to retry payout.');
    } finally {
      setActionProcessing(false);
    }
  };

  const handleRetryBatch = async (batchId: string) => {
    setActionProcessing(true);
    setActionError(null);
    setActionSuccess(null);
    try {
      const fn = httpsCallable<{ batchId: string }, any>(functions, 'adminRetryFailedPayout');
      const res = await fn({ batchId });
      if (res.data.success) {
        setActionSuccess(`Retried failed payouts in batch! Recipient retry success: ${res.data.retrySuccessCount}`);
      } else {
        setActionError('Failed to retry batch transfers.');
      }
    } catch (e: any) {
      setActionError(e.message || 'Failed to execute retry.');
    } finally {
      setActionProcessing(false);
    }
  };

  // ── 10. Export CSV
  const handleExportCSV = () => {
    const headers = ['Driver Name', 'Amount', 'Status', 'Date', 'Reference', 'Batch ID', 'Admin ID'];
    const rows = payouts.map((p) => [
      drivers.find((d) => d.id === p.driverId)?.fullName || p.driverId,
      p.amount,
      p.status,
      p.createdAt.toDate().toLocaleString('en-NG'),
      p.reference || '',
      p.batchId || '',
      p.processedBy,
    ]);

    const csvContent =
      'data:text/csv;charset=utf-8,' +
      [headers.join(','), ...rows.map((e) => e.map((val) => `"${val}"`).join(','))].join('\n');

    const encodedUri = encodeURI(csvContent);
    const link = document.createElement('a');
    link.setAttribute('href', encodedUri);
    link.setAttribute('download', `caride_payouts_export_${Date.now()}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
  };

  // Calculations for Statistics Cards
  const totalWalletLiability = drivers.reduce((sum, d) => sum + d.walletBalance, 0);

  const now = new Date();
  const startOfToday = new Date(now.getFullYear(), now.getMonth(), now.getDate());
  const startOfWeek = new Date(now.setDate(now.getDate() - now.getDay()));
  const startOfMonth = new Date(now.getFullYear(), now.getMonth(), 1);

  const paidToday = payouts
    .filter((p) => p.status === 'successful' && p.createdAt.toDate() >= startOfToday)
    .reduce((sum, p) => sum + p.amount, 0);

  const paidThisWeek = payouts
    .filter((p) => p.status === 'successful' && p.createdAt.toDate() >= startOfWeek)
    .reduce((sum, p) => sum + p.amount, 0);

  const paidThisMonth = payouts
    .filter((p) => p.status === 'successful' && p.createdAt.toDate() >= startOfMonth)
    .reduce((sum, p) => sum + p.amount, 0);

  const pendingWithdrawalsCount = drivers.filter((d) => d.walletBalance > 0).length;

  const failedPayoutsList = payouts.filter((p) => p.status === 'failed');
  const failedPayoutsCount = failedPayoutsList.length;
  const failedPayoutsAmount = failedPayoutsList.reduce((sum, p) => sum + p.amount, 0);

  const totalPayoutAttempts = payouts.length;
  const successPayoutsCount = payouts.filter((p) => p.status === 'successful').length;
  const settlementSuccessRate = totalPayoutAttempts > 0 ? (successPayoutsCount / totalPayoutAttempts) * 100 : 100;

  // Filter lists based on Search & Tiers
  const filteredDrivers = drivers.filter((d) => {
    const matchesSearch =
      d.fullName.toLowerCase().includes(searchQuery.toLowerCase()) ||
      d.id.toLowerCase().includes(searchQuery.toLowerCase()) ||
      d.email.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesTier = tierFilter === 'all' || d.tier?.toLowerCase() === tierFilter.toLowerCase();
    return matchesSearch && matchesTier;
  });

  const filteredPayouts = payouts.filter((p) => {
    const dName = drivers.find((d) => d.id === p.driverId)?.fullName || p.driverId;
    const matchesSearch =
      dName.toLowerCase().includes(searchQuery.toLowerCase()) ||
      p.id.toLowerCase().includes(searchQuery.toLowerCase()) ||
      (p.reference || '').toLowerCase().includes(searchQuery.toLowerCase());
    const matchesStatus = statusFilter === 'all' || p.status === statusFilter;
    return matchesSearch && matchesStatus;
  });

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-6)' }}>
      {/* Toast Alert Feedback */}
      {actionSuccess && (
        <div className="alert alert--success" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <span>✅ {actionSuccess}</span>
          <button type="button" className="btn btn--ghost" onClick={() => setActionSuccess(null)} style={{ color: 'inherit', padding: 0 }}>✕</button>
        </div>
      )}
      {actionError && (
        <div className="alert alert--error" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <span>⚠️ {actionError}</span>
          <button type="button" className="btn btn--ghost" onClick={() => setActionError(null)} style={{ color: 'inherit', padding: 0 }}>✕</button>
        </div>
      )}

      {/* ── Dashboard Statistics Cards ── */}
      <section
        className="responsive-grid-4"
        style={{
          display: 'grid',
          gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))',
          gap: 'var(--space-4)',
        }}
      >
        <article className="card" style={{ padding: 'var(--space-5)', display: 'flex', flexDirection: 'column', gap: '4px' }}>
          <span className="muted" style={{ fontSize: '0.75rem', fontWeight: 600 }}>Wallet Liability</span>
          <h2 style={{ fontSize: '1.75rem', fontWeight: 800, margin: 0 }}>{formatNgn(totalWalletLiability)}</h2>
          <span className="muted" style={{ fontSize: '0.725rem' }}>Owed to {pendingWithdrawalsCount} active drivers</span>
        </article>

        <article className="card" style={{ padding: 'var(--space-5)', display: 'flex', flexDirection: 'column', gap: '4px' }}>
          <span className="muted" style={{ fontSize: '0.75rem', fontWeight: 600 }}>Total Settled</span>
          <h2 style={{ fontSize: '1.75rem', fontWeight: 800, margin: 0 }}>{formatNgn(paidThisMonth)}</h2>
          <div className="muted" style={{ fontSize: '0.725rem', display: 'flex', gap: '12px' }}>
            <span>Today: {formatNgn(paidToday)}</span>
            <span>Week: {formatNgn(paidThisWeek)}</span>
          </div>
        </article>

        <article className="card" style={{ padding: 'var(--space-5)', display: 'flex', flexDirection: 'column', gap: '4px' }}>
          <span className="muted" style={{ fontSize: '0.75rem', fontWeight: 600 }}>Settlement Success Rate</span>
          <h2 style={{ fontSize: '1.75rem', fontWeight: 800, margin: 0, color: 'var(--color-primary-active)' }}>
            {settlementSuccessRate.toFixed(1)}%
          </h2>
          <span className="muted" style={{ fontSize: '0.725rem' }}>Across {totalPayoutAttempts} attempts</span>
        </article>

        <article className="card" style={{ padding: 'var(--space-5)', display: 'flex', flexDirection: 'column', gap: '4px' }}>
          <span className="muted" style={{ fontSize: '0.75rem', fontWeight: 600 }}>Failed Settlements</span>
          <h2 style={{ fontSize: '1.75rem', fontWeight: 800, margin: 0, color: 'var(--color-error)' }}>
            {formatNgn(failedPayoutsAmount)}
          </h2>
          <span className="muted" style={{ fontSize: '0.725rem' }}>{failedPayoutsCount} unsuccessful payouts</span>
        </article>
      </section>

      {/* ── Bulk Settlement Review Screen (If Batch is Pending) ── */}
      {showReviewBatch && (
        <section className="card" style={{ border: '2px solid var(--color-primary-light)', padding: 'var(--space-6)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 'var(--space-4)', flexWrap: 'wrap', gap: 'var(--space-3)' }}>
            <div>
              <span className="badge badge--warn" style={{ marginBottom: 'var(--space-2)' }}>Settlement Review Pending</span>
              <h3 style={{ margin: 0, fontSize: '1.25rem', fontWeight: 800 }}>Settlement Batch Summary</h3>
            </div>
            <div style={{ display: 'flex', gap: 'var(--space-2)' }}>
              <button
                type="button"
                className="btn btn--ghost"
                onClick={() => handleCancelBatch(showReviewBatch.id)}
                disabled={actionProcessing}
              >
                Discard Batch
              </button>
              <button
                type="button"
                className="btn btn--primary"
                onClick={() => handleExecuteBatch(showReviewBatch.id)}
                disabled={actionProcessing}
              >
                {actionProcessing ? 'Executing Payouts...' : 'Execute Payouts'}
              </button>
            </div>
          </div>

          <div
            style={{
              display: 'grid',
              gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
              gap: 'var(--space-4)',
              background: 'var(--color-bg-alt)',
              padding: 'var(--space-4)',
              borderRadius: 'var(--radius-lg)',
              marginBottom: 'var(--space-5)',
            }}
          >
            <div>
              <div className="muted" style={{ fontSize: '0.75rem', fontWeight: 600 }}>Drivers Count</div>
              <div style={{ fontSize: '1.25rem', fontWeight: 800 }}>{showReviewBatch.driverCount}</div>
            </div>
            <div>
              <div className="muted" style={{ fontSize: '0.75rem', fontWeight: 600 }}>Total Payout Amount</div>
              <div style={{ fontSize: '1.25rem', fontWeight: 800 }}>{formatNgn(showReviewBatch.totalAmount)}</div>
            </div>
            <div>
              <div className="muted" style={{ fontSize: '0.75rem', fontWeight: 600 }}>Average Payout</div>
              <div style={{ fontSize: '1.25rem', fontWeight: 800 }}>
                {formatNgn(showReviewBatch.driverCount > 0 ? showReviewBatch.totalAmount / showReviewBatch.driverCount : 0)}
              </div>
            </div>
            {batchEntries.length > 0 && (
              <>
                <div>
                  <div className="muted" style={{ fontSize: '0.75rem', fontWeight: 600 }}>Largest Payout</div>
                  <div style={{ fontSize: '1.25rem', fontWeight: 800 }}>
                    {formatNgn(Math.max(...batchEntries.map((e) => e.walletBalance)))}
                  </div>
                </div>
                <div>
                  <div className="muted" style={{ fontSize: '0.75rem', fontWeight: 600 }}>Smallest Payout</div>
                  <div style={{ fontSize: '1.25rem', fontWeight: 800 }}>
                    {formatNgn(Math.min(...batchEntries.map((e) => e.walletBalance)))}
                  </div>
                </div>
              </>
            )}
          </div>

          <div className="table-wrapper" style={{ maxHeight: '300px', overflowY: 'auto' }}>
            {loadingBatchEntries ? (
              <div style={{ padding: 'var(--space-4)' }} className="skeleton-row shimmer" />
            ) : (
              <table className="table-premium">
                <thead>
                  <tr>
                    <th>Driver</th>
                    <th>Bank details</th>
                    <th>Payout Balance</th>
                  </tr>
                </thead>
                <tbody>
                  {batchEntries.map((entry) => (
                    <tr key={entry.driverUid}>
                      <td>{entry.fullName}</td>
                      <td>
                        {entry.bankAccount ? (
                          <span>{entry.bankAccount.bankName} · {entry.bankAccount.maskedAccountNumber}</span>
                        ) : (
                          <span className="badge badge--error">No Linked Bank Account</span>
                        )}
                      </td>
                      <td style={{ fontWeight: 700 }}>{formatNgn(entry.walletBalance)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        </section>
      )}

      {/* ── Tabbed View Controls ── */}
      <section className="card" style={{ padding: 'var(--space-5)' }}>
        <div
          style={{
            display: 'flex',
            justifyContent: 'space-between',
            alignItems: 'center',
            borderBottom: '1px solid var(--color-border)',
            paddingBottom: 'var(--space-4)',
            marginBottom: 'var(--space-5)',
            flexWrap: 'wrap',
            gap: 'var(--space-4)',
          }}
        >
          <div className="tab-bar-underline" style={{ margin: 0, border: 'none' }}>
            {[
              { id: 'balances', label: 'Wallet Balances', count: pendingWithdrawalsCount },
              { id: 'batches', label: 'Settlement Batches', count: batches.length },
              { id: 'payouts', label: 'Payout History', count: payouts.length },
              { id: 'audits', label: 'Audit Logs', count: audits.length },
            ].map((tab) => (
              <button
                key={tab.id}
                type="button"
                className={`tab-btn-underline ${activeTab === tab.id ? 'active' : ''}`}
                onClick={() => {
                  setActiveTab(tab.id as any);
                  setSearchQuery('');
                }}
              >
                <span>{tab.label}</span>
                <span className="tab-count-badge">{tab.count}</span>
              </button>
            ))}
          </div>

          <div style={{ display: 'flex', gap: 'var(--space-2)', alignItems: 'center' }}>
            {activeTab === 'balances' && (
              <button
                type="button"
                className="btn btn--primary"
                onClick={handleGenerateBatch}
                disabled={actionProcessing || pendingWithdrawalsCount === 0}
              >
                Generate Settlement Batch
              </button>
            )}
            {activeTab === 'payouts' && (
              <button type="button" className="filter-pill" onClick={handleExportCSV}>
                <svg style={{ width: 14, height: 14 }} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
                  <polyline points="7 10 12 15 17 10" />
                  <line x1="12" y1="15" x2="12" y2="3" />
                </svg>
                <span>Export CSV</span>
              </button>
            )}
          </div>
        </div>

        {/* ── Search & Filter Controls ── */}
        <div style={{ display: 'flex', gap: 'var(--space-3)', marginBottom: 'var(--space-5)', flexWrap: 'wrap', alignItems: 'center' }}>
          <div className="search-pill-wrap">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <circle cx="11" cy="11" r="8" /><line x1="21" y1="21" x2="16.65" y2="16.65" />
            </svg>
            <input
              type="text"
              placeholder={`Search ${activeTab === 'balances' ? 'drivers by name, ID...' : 'payouts or reference'}...`}
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              style={{ width: 280 }}
            />
          </div>

          {activeTab === 'balances' && (
            <select
              className="select"
              value={tierFilter}
              onChange={(e) => setTierFilter(e.target.value)}
              style={{ width: '150px' }}
            >
              <option value="all">All Tiers</option>
              <option value="bronze">★ Bronze</option>
              <option value="silver">★ Silver</option>
              <option value="gold">★ Gold</option>
              <option value="platinum">★ Platinum</option>
            </select>
          )}

          {activeTab === 'payouts' && (
            <select
              className="select"
              value={statusFilter}
              onChange={(e) => setStatusFilter(e.target.value)}
              style={{ width: '150px' }}
            >
              <option value="all">All Statuses</option>
              <option value="successful">Successful</option>
              <option value="failed">Failed</option>
            </select>
          )}
        </div>

        {/* ── Tab: Balances (Active wallets) ── */}
        {activeTab === 'balances' && (
          <>
            {/* Desktop Table view */}
            <div className="table-wrapper desktop-only">
              {loadingDrivers ? (
                <div style={{ padding: 'var(--space-5)' }} className="skeleton-row shimmer" />
              ) : filteredDrivers.length === 0 ? (
                <div className="empty-state">
                  <h4>No active wallet balances</h4>
                  <p className="muted">Currently, no drivers have positive wallet liabilities.</p>
                </div>
              ) : (
                <table className="table-premium">
                  <thead>
                    <tr>
                      <th>Driver</th>
                      <th>Wallet Balance</th>
                      <th>Bank Details</th>
                      <th>Tier</th>
                      <th style={{ textAlign: 'right' }}>Action</th>
                    </tr>
                  </thead>
                  <tbody>
                    {filteredDrivers.map((driver) => (
                      <tr key={driver.id}>
                        <td>
                          <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-3)' }}>
                            <div
                              style={{
                                width: 36,
                                height: 36,
                                borderRadius: '50%',
                                background: 'var(--color-primary-light)',
                                color: 'var(--color-primary)',
                                display: 'flex',
                                alignItems: 'center',
                                justifyContent: 'center',
                                fontSize: '0.75rem',
                                fontWeight: 700,
                                flexShrink: 0,
                                overflow: 'hidden',
                              }}
                            >
                              {driver.profilePhotoUrl ? (
                                <img
                                  src={driver.profilePhotoUrl}
                                  alt={driver.fullName}
                                  style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                                />
                              ) : (
                                initials(driver.fullName || 'DX')
                              )}
                            </div>
                            <div>
                              <div style={{ fontWeight: 600 }}>{driver.fullName || '—'}</div>
                              <div className="muted" style={{ fontSize: '0.75rem' }}>{driver.id}</div>
                            </div>
                          </div>
                        </td>
                        <td style={{ fontWeight: 700, color: 'var(--color-primary-active)' }}>
                          {formatNgn(driver.walletBalance)}
                        </td>
                        <td>
                          {driver.bankAccount ? (
                            <div>
                              <div style={{ fontWeight: 600, fontSize: '0.8rem' }}>{driver.bankAccount.bankName}</div>
                              <div className="muted" style={{ fontSize: '0.75rem' }}>
                                {driver.bankAccount.accountName} · {driver.bankAccount.maskedAccountNumber}
                              </div>
                            </div>
                          ) : (
                            <span className="badge badge--error">No Bank account</span>
                          )}
                        </td>
                        <td>
                          <span style={{ fontWeight: 700, fontSize: '0.75rem', textTransform: 'uppercase' }}>
                            ★ {driver.tier ?? 'bronze'}
                          </span>
                        </td>
                        <td style={{ textAlign: 'right' }}>
                          <div style={{ display: 'flex', gap: 'var(--space-2)', justifyContent: 'flex-end' }}>
                            <button
                              type="button"
                              className="btn btn--ghost"
                              onClick={() => setSelectedDriver(driver)}
                            >
                              Details
                            </button>
                            {driver.walletBalance > 0 && (
                              <button
                                type="button"
                                className="btn btn--primary"
                                disabled={!driver.bankAccount}
                                onClick={() => setConfirmPayoutDriver(driver)}
                              >
                                Pay Driver
                              </button>
                            )}
                          </div>
                        </td>
                      </tr>
                    ))}
                  </tbody>
                </table>
              )}
            </div>

            {/* Mobile Card view */}
            {!loadingDrivers && filteredDrivers.length > 0 && (
              <div className="mobile-only" style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-3)' }}>
                {filteredDrivers.map((driver) => (
                  <article key={driver.id} className="card" style={{ padding: 'var(--space-4)' }}>
                    <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 'var(--space-3)' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-3)' }}>
                        <div
                          style={{
                            width: 32,
                            height: 32,
                            borderRadius: '50%',
                            background: 'var(--color-primary-light)',
                            color: 'var(--color-primary)',
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            fontSize: '0.75rem',
                            fontWeight: 700,
                            overflow: 'hidden',
                          }}
                        >
                          {driver.profilePhotoUrl ? (
                            <img src={driver.profilePhotoUrl} alt={driver.fullName} style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                          ) : (
                            initials(driver.fullName || 'DX')
                          )}
                        </div>
                        <div>
                          <div style={{ fontWeight: 600, fontSize: '0.9rem' }}>{driver.fullName || '—'}</div>
                          <span style={{ fontSize: '0.7rem', textTransform: 'uppercase', color: 'var(--color-text-muted)', fontWeight: 700 }}>
                            ★ {driver.tier ?? 'bronze'}
                          </span>
                        </div>
                      </div>
                      <div style={{ fontWeight: 800, color: 'var(--color-primary-active)' }}>
                        {formatNgn(driver.walletBalance)}
                      </div>
                    </div>

                    <div style={{ borderTop: '1px solid var(--color-border)', paddingTop: 'var(--space-3)', marginBottom: 'var(--space-3)' }}>
                      {driver.bankAccount ? (
                        <div style={{ fontSize: '0.8rem' }}>
                          <strong>{driver.bankAccount.bankName}</strong> · <span className="muted">{driver.bankAccount.maskedAccountNumber}</span>
                        </div>
                      ) : (
                        <span className="badge badge--error">No Bank account</span>
                      )}
                    </div>

                    <div style={{ display: 'flex', gap: 'var(--space-2)', justifyContent: 'flex-end' }}>
                      <button type="button" className="btn btn--ghost" onClick={() => setSelectedDriver(driver)} style={{ padding: '6px 12px', fontSize: '0.8rem' }}>
                        Details
                      </button>
                      {driver.walletBalance > 0 && (
                        <button
                          type="button"
                          className="btn btn--primary"
                          disabled={!driver.bankAccount}
                          onClick={() => setConfirmPayoutDriver(driver)}
                          style={{ padding: '6px 12px', fontSize: '0.8rem' }}
                        >
                          Pay
                        </button>
                      )}
                    </div>
                  </article>
                ))}
              </div>
            )}
          </>
        )}

        {/* ── Tab: Batches (Settlement History) ── */}
        {activeTab === 'batches' && (
          <div className="table-wrapper">
            {loadingBatches ? (
              <div style={{ padding: 'var(--space-5)' }} className="skeleton-row shimmer" />
            ) : batches.length === 0 ? (
              <div className="empty-state">
                <h4>No batches found</h4>
                <p className="muted">Use the "Generate Settlement Batch" button to create one.</p>
              </div>
            ) : (
              <table className="table-premium">
                <thead>
                  <tr>
                    <th>Batch ID</th>
                    <th>Drivers count</th>
                    <th>Total Settlement</th>
                    <th>Success / Fail</th>
                    <th>Status</th>
                    <th>Created Date</th>
                    <th style={{ textAlign: 'right' }}>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {batches.map((batch) => (
                    <tr key={batch.id}>
                      <td><span style={{ fontFamily: 'monospace', fontWeight: 600 }}>{batch.id}</span></td>
                      <td>{batch.driverCount} drivers</td>
                      <td style={{ fontWeight: 700 }}>{formatNgn(batch.totalAmount)}</td>
                      <td>
                        {batch.status === 'completed' ? (
                          <span style={{ fontSize: '0.85rem' }}>
                            ✅ {batch.successCount ?? 0} &nbsp;&nbsp; ❌ {batch.failedCount ?? 0}
                          </span>
                        ) : (
                          <span className="muted">—</span>
                        )}
                      </td>
                      <td>
                        <span
                          className={`badge badge--${
                            batch.status === 'completed'
                              ? 'ok'
                              : batch.status === 'processing'
                              ? 'info'
                              : 'warn'
                          }`}
                        >
                          {batch.status}
                        </span>
                      </td>
                      <td>{batch.createdAt?.toDate().toLocaleString('en-NG')}</td>
                      <td style={{ textAlign: 'right' }}>
                        <div style={{ display: 'flex', gap: 'var(--space-2)', justifyContent: 'flex-end' }}>
                          <button
                            type="button"
                            className="btn btn--ghost"
                            onClick={() => loadBatchEntries(batch)}
                          >
                            View Entries
                          </button>
                          {batch.status === 'completed' && (batch.failedCount ?? 0) > 0 && (
                            <button
                              type="button"
                              className="btn btn--primary"
                              onClick={() => handleRetryBatch(batch.id)}
                              disabled={actionProcessing}
                            >
                              Retry Failed Payouts
                            </button>
                          )}
                        </div>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        )}

        {/* ── Tab: Payout History (Individual Transfers) ── */}
        {activeTab === 'payouts' && (
          <div className="table-wrapper">
            {loadingPayouts ? (
              <div style={{ padding: 'var(--space-5)' }} className="skeleton-row shimmer" />
            ) : filteredPayouts.length === 0 ? (
              <div className="empty-state">
                <h4>No payouts matched your query</h4>
              </div>
            ) : (
              <table className="table-premium">
                <thead>
                  <tr>
                    <th>Driver</th>
                    <th>Reference</th>
                    <th>Settlement Amount</th>
                    <th>Status</th>
                    <th>Processed Date</th>
                    <th>Failed Reason</th>
                    <th style={{ textAlign: 'right' }}>Action</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredPayouts.map((p) => (
                    <tr key={p.id}>
                      <td>
                        <div style={{ fontWeight: 600 }}>
                          {drivers.find((d) => d.id === p.driverId)?.fullName || p.driverId}
                        </div>
                      </td>
                      <td><span style={{ fontFamily: 'monospace', fontSize: '0.8rem' }}>{p.reference || p.id}</span></td>
                      <td style={{ fontWeight: 700 }}>{formatNgn(p.amount)}</td>
                      <td>
                        <span className={`badge badge--${p.status === 'successful' ? 'ok' : 'error'}`}>
                          {p.status}
                        </span>
                      </td>
                      <td>{p.createdAt?.toDate().toLocaleString('en-NG')}</td>
                      <td style={{ color: 'var(--color-error)', fontSize: '0.8rem' }}>
                        {p.failureReason || '—'}
                      </td>
                      <td style={{ textAlign: 'right' }}>
                        {p.status === 'failed' && (
                          <button
                            type="button"
                            className="btn btn--ghost"
                            onClick={() => handleRetryPayout(p.id)}
                            disabled={actionProcessing}
                          >
                            Retry
                          </button>
                        )}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        )}

        {/* ── Tab: Audit Logs ── */}
        {activeTab === 'audits' && (
          <div className="table-wrapper">
            {loadingAudits ? (
              <div style={{ padding: 'var(--space-5)' }} className="skeleton-row shimmer" />
            ) : audits.length === 0 ? (
              <div className="empty-state">
                <h4>No audit logs found</h4>
              </div>
            ) : (
              <table className="table-premium">
                <thead>
                  <tr>
                    <th>Admin</th>
                    <th>Action</th>
                    <th>Batch ID</th>
                    <th>Driver ID</th>
                    <th>Amount</th>
                    <th>Date</th>
                  </tr>
                </thead>
                <tbody>
                  {audits.map((a) => (
                    <tr key={a.id}>
                      <td><span style={{ fontWeight: 600 }}>{a.adminId}</span></td>
                      <td><span className="badge badge--info" style={{ textTransform: 'uppercase', fontSize: '0.7rem' }}>{a.action}</span></td>
                      <td>{a.batchId || '—'}</td>
                      <td>{a.driverId || '—'}</td>
                      <td style={{ fontWeight: 700 }}>{a.amount ? formatNgn(a.amount) : '—'}</td>
                      <td>{a.createdAt?.toDate().toLocaleString('en-NG')}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        )}
      </section>

      {/* ── Detail Modal ── */}
      {selectedDriver && (
        <Modal onClose={() => setSelectedDriver(null)} title="Driver Portfolio">
          <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-4)', marginBottom: 'var(--space-4)' }}>
            <div
              style={{
                width: 56,
                height: 56,
                borderRadius: '50%',
                background: 'var(--color-primary-light)',
                color: 'var(--color-primary)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                fontSize: '1.1rem',
                fontWeight: 700,
                flexShrink: 0,
                overflow: 'hidden',
              }}
            >
              {selectedDriver.profilePhotoUrl ? (
                <img
                  src={selectedDriver.profilePhotoUrl}
                  alt={selectedDriver.fullName}
                  style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                />
              ) : (
                initials(selectedDriver.fullName || 'DX')
              )}
            </div>
            <div>
              <div style={{ fontWeight: 700, fontSize: '1.1rem' }}>{selectedDriver.fullName}</div>
              <div className="muted" style={{ fontSize: '0.85rem' }}>{selectedDriver.email}</div>
              {selectedDriver.phone && <div className="muted" style={{ fontSize: '0.85rem' }}>{selectedDriver.phone}</div>}
            </div>
          </div>

          <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 'var(--space-3)', marginBottom: 'var(--space-4)' }}>
            <DetailRow label="Wallet Balance" value={formatNgn(selectedDriver.walletBalance)} />
            <DetailRow label="Tier Level" value={selectedDriver.tier} />
            {selectedDriver.vehicleInfo && (
              <>
                <DetailRow label="Vehicle make/model" value={`${selectedDriver.vehicleInfo.make} ${selectedDriver.vehicleInfo.model}`} />
                <DetailRow label="Plate Number" value={selectedDriver.vehicleInfo.plateNumber} />
              </>
            )}
          </div>

          {selectedDriver.bankAccount ? (
            <div style={{ borderTop: '1px solid var(--color-border)', paddingTop: 'var(--space-3)' }}>
              <div style={{ fontSize: '0.75rem', fontWeight: 700, color: 'var(--color-text-muted)', textTransform: 'uppercase', marginBottom: 'var(--space-2)' }}>
                Bank Destination Details
              </div>
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 'var(--space-3)' }}>
                <DetailRow label="Bank Name" value={selectedDriver.bankAccount.bankName} />
                <DetailRow label="Recipient Name" value={selectedDriver.bankAccount.accountName} />
                <DetailRow label="Account Number" value={selectedDriver.bankAccount.maskedAccountNumber} />
              </div>
            </div>
          ) : (
            <div className="alert alert--error" style={{ fontSize: '0.85rem' }}>
              ⚠️ No linked bank details found. Outbound settlement is blocked.
            </div>
          )}
        </Modal>
      )}

      {/* ── Single Driver Payout Confirmation Modal ── */}
      {confirmPayoutDriver && (
        <Modal onClose={() => setConfirmPayoutDriver(null)} title="Execute Single Payout">
          <p>
            You are about to execute a transfer of{' '}
            <strong style={{ color: 'var(--color-primary-active)' }}>
              {formatNgn(confirmPayoutDriver.walletBalance)}
            </strong>{' '}
            to driver <strong>{confirmPayoutDriver.fullName}</strong>.
          </p>

          {confirmPayoutDriver.bankAccount && (
            <div
              style={{
                background: 'var(--color-bg-alt)',
                border: '1px solid var(--color-border)',
                borderRadius: 'var(--radius-lg)',
                padding: 'var(--space-3)',
                marginBottom: 'var(--space-4)',
              }}
            >
              <div style={{ fontWeight: 700 }}>{confirmPayoutDriver.bankAccount.bankName}</div>
              <div className="muted" style={{ fontSize: '0.85rem' }}>
                {confirmPayoutDriver.bankAccount.accountName} · {confirmPayoutDriver.bankAccount.maskedAccountNumber}
              </div>
            </div>
          )}

          <div style={{ display: 'flex', gap: 'var(--space-2)', justifyContent: 'flex-end', marginTop: 'var(--space-4)' }}>
            <button
              type="button"
              className="btn btn--ghost"
              onClick={() => setConfirmPayoutDriver(null)}
              disabled={actionProcessing}
            >
              Cancel
            </button>
            <button
              type="button"
              className="btn btn--primary"
              onClick={() => handleSinglePayout(confirmPayoutDriver)}
              disabled={actionProcessing}
            >
              {actionProcessing ? 'Executing...' : 'Confirm Payout'}
            </button>
          </div>
        </Modal>
      )}
    </div>
  );
}

// ─── Modal Sub-component ───

function Modal({
  title,
  children,
  onClose,
}: {
  title: string;
  children: React.ReactNode;
  onClose: () => void;
}) {
  return (
    <div
      style={{
        position: 'fixed',
        inset: 0,
        background: 'rgba(0,0,0,0.5)',
        backdropFilter: 'blur(8px)',
        WebkitBackdropFilter: 'blur(8px)',
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        zIndex: 1000,
        padding: 'var(--space-4)',
      }}
      onClick={(e) => {
        if (e.target === e.currentTarget) onClose();
      }}
    >
      <div
        style={{
          background: 'var(--color-surface)',
          borderRadius: 'var(--radius-lg)',
          border: '1px solid var(--color-border)',
          padding: 'var(--space-6)',
          width: '100%',
          maxWidth: 520,
          maxHeight: '90vh',
          overflowY: 'auto',
        }}
      >
        <div
          style={{
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            marginBottom: 'var(--space-5)',
          }}
        >
          <h3 style={{ margin: 0, fontSize: '1.2rem', fontWeight: 800 }}>{title}</h3>
          <button
            type="button"
            onClick={onClose}
            style={{
              background: 'none',
              border: 'none',
              cursor: 'pointer',
              fontSize: '1.2rem',
              color: 'var(--color-text-muted)',
              padding: 4,
            }}
          >
            ✕
          </button>
        </div>
        {children}
      </div>
    </div>
  );
}

function DetailRow({ label, value }: { label: string; value: React.ReactNode }) {
  return (
    <div>
      <dt style={{ fontSize: '0.725rem', color: 'var(--color-text-muted)', marginBottom: 2, fontWeight: 600, textTransform: 'uppercase' }}>
        {label}
      </dt>
      <dd style={{ margin: 0, fontSize: '0.875rem', color: 'var(--color-text)', fontWeight: 600 }}>{value || '—'}</dd>
    </div>
  );
}
