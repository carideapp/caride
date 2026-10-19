import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { signOut } from 'firebase/auth';
import {
  doc,
  onSnapshot,
  collection,
  query,
  where,
  limit,
  updateDoc,
} from 'firebase/firestore';
import { httpsCallable } from 'firebase/functions';
import { db, functions, auth } from '../config/firebase';

interface StaffData {
  staffUid: string;
  staffId: string;
  firstName: string;
  lastName: string;
  fullName: string;
  email: string;
  phone: string;
  staffType: 'tracking' | 'commission';
  commissionRatePercent: number;
  referralCode: string;
  referralLink: string;
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
}

interface StaffReferralRecord {
  id: string;
  referredUid: string;
  userType: 'customer' | 'driver';
  email: string;
  fullName: string;
  referralCode: string;
  joinedAt: any;
}

interface StaffCommissionTx {
  id: string;
  rideId: string;
  rideFare: number;
  companyCommission: number;
  staffCommissionRate: number;
  staffCommissionAmount: number;
  createdAt: any;
}

interface StaffWithdrawalRow {
  id: string;
  withdrawalId: string;
  amount: number;
  status: 'pending' | 'paid' | 'rejected';
  rejectionReason?: string;
  requestedAt: any;
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

export function StaffDashboardPage() {
  const navigate = useNavigate();
  const staffUid = auth.currentUser?.uid;

  const [staff, setStaff] = useState<StaffData | null>(null);
  const [loadingStaff, setLoadingStaff] = useState(true);

  const [referrals, setReferrals] = useState<StaffReferralRecord[]>([]);
  const [earnings, setEarnings] = useState<StaffCommissionTx[]>([]);
  const [withdrawals, setWithdrawals] = useState<StaffWithdrawalRow[]>([]);

  const [activeTab, setActiveTab] = useState<'referrals' | 'earnings' | 'withdrawals'>('referrals');

  // Withdrawal modal state
  const [showWithdrawModal, setShowWithdrawModal] = useState(false);
  const [withdrawAmount, setWithdrawAmount] = useState('');
  const [submittingWd, setSubmittingWd] = useState(false);
  const [wdError, setWdError] = useState<string | null>(null);
  const [wdSuccess, setWdSuccess] = useState<string | null>(null);

  // Bank Details Editing
  const [editingBank, setEditingBank] = useState(false);
  const [bankForm, setBankForm] = useState({ bankName: '', accountName: '', accountNumber: '' });
  const [savingBank, setSavingBank] = useState(false);

  // Redirect to staff login if not authenticated
  useEffect(() => {
    if (!auth.currentUser && !loadingStaff) {
      navigate('/staff/login', { replace: true });
    }
  }, [navigate, loadingStaff]);

  async function handleSignOut() {
    try {
      await signOut(auth);
    } catch (err) {
      console.error('Sign out error:', err);
    } finally {
      navigate('/staff/login', { replace: true });
    }
  }

  // 1. Listen to staff document
  useEffect(() => {
    if (!staffUid) return;
    const unsub = onSnapshot(
      doc(db, 'staff', staffUid),
      (snap) => {
        if (snap.exists()) {
          const d = snap.data() as StaffData;
          setStaff(d);
          setBankForm({
            bankName: d.bankDetails?.bankName || '',
            accountName: d.bankDetails?.accountName || '',
            accountNumber: d.bankDetails?.accountNumber || '',
          });
        }
        setLoadingStaff(false);
      },
      (err) => {
        if (!auth.currentUser) return;
        console.warn('Failed to load staff profile:', err?.message);
        setLoadingStaff(false);
      }
    );
    return () => unsub();
  }, [staffUid]);

  // 2. Listen to staff referrals subcollection
  useEffect(() => {
    if (!staffUid) return;
    const unsub = onSnapshot(
      query(collection(db, 'staff', staffUid, 'referrals'), limit(100)),
      (snap) => {
        const rows: StaffReferralRecord[] = snap.docs.map((d) => ({
          id: d.id,
          ...(d.data() as any),
        }));
        rows.sort((a, b) => {
          const aTime = a.joinedAt?.toMillis ? a.joinedAt.toMillis() : (a.joinedAt ? new Date(a.joinedAt).getTime() : 0);
          const bTime = b.joinedAt?.toMillis ? b.joinedAt.toMillis() : (b.joinedAt ? new Date(b.joinedAt).getTime() : 0);
          return bTime - aTime;
        });
        setReferrals(rows);
      },
      (err) => {
        if (!auth.currentUser) return;
        console.warn('Failed to load staff referrals:', err?.message);
        setReferrals([]);
      }
    );
    return () => unsub();
  }, [staffUid]);

  // 3. Listen to staff commission transactions
  useEffect(() => {
    if (!staffUid) return;
    const unsub = onSnapshot(
      query(collection(db, 'staff_commission_transactions'), where('staffId', '==', staffUid)),
      (snap) => {
        const rows: StaffCommissionTx[] = snap.docs.map((d) => ({
          id: d.id,
          ...(d.data() as any),
        }));
        rows.sort((a, b) => {
          const aTime = a.createdAt?.toMillis ? a.createdAt.toMillis() : (a.createdAt ? new Date(a.createdAt).getTime() : 0);
          const bTime = b.createdAt?.toMillis ? b.createdAt.toMillis() : (b.createdAt ? new Date(b.createdAt).getTime() : 0);
          return bTime - aTime;
        });
        setEarnings(rows);
      },
      (err) => {
        if (!auth.currentUser) return;
        console.warn('Failed to load commission transactions:', err?.message);
        setEarnings([]);
      }
    );
    return () => unsub();
  }, [staffUid]);

  // 4. Listen to staff withdrawal requests
  useEffect(() => {
    if (!staffUid) return;
    const unsub = onSnapshot(
      query(collection(db, 'staff_withdrawal_requests'), where('staffId', '==', staffUid)),
      (snap) => {
        const rows: StaffWithdrawalRow[] = snap.docs.map((d) => ({
          id: d.id,
          ...(d.data() as any),
        }));
        rows.sort((a, b) => {
          const aTime = a.requestedAt?.toMillis ? a.requestedAt.toMillis() : (a.requestedAt ? new Date(a.requestedAt).getTime() : 0);
          const bTime = b.requestedAt?.toMillis ? b.requestedAt.toMillis() : (b.requestedAt ? new Date(b.requestedAt).getTime() : 0);
          return bTime - aTime;
        });
        setWithdrawals(rows);
      },
      (err) => {
        if (!auth.currentUser) return;
        console.warn('Failed to load withdrawal requests:', err?.message);
        setWithdrawals([]);
      }
    );
    return () => unsub();
  }, [staffUid]);

  // Handle Withdrawal Request
  async function handleRequestWithdrawal(e: React.FormEvent) {
    e.preventDefault();
    setWdError(null);
    setWdSuccess(null);

    const amt = Number(withdrawAmount);
    if (isNaN(amt) || amt <= 0) {
      setWdError('Please enter a valid withdrawal amount.');
      return;
    }

    const avail = staff?.wallet?.availableBalance || 0;
    if (amt > avail) {
      setWdError(`Amount exceeds available balance (${formatNgn(avail)}).`);
      return;
    }

    setSubmittingWd(true);
    try {
      const wdFn = httpsCallable(functions, 'requestStaffWithdrawal');
      const res: any = await wdFn({ amount: amt });
      setWdSuccess(res.data?.message || 'Withdrawal request submitted successfully.');
      setShowWithdrawModal(false);
      setWithdrawAmount('');
    } catch (err: any) {
      setWdError(err.message || 'Failed to submit withdrawal request.');
    } finally {
      setSubmittingWd(false);
    }
  }

  // Save Bank Details
  async function handleSaveBankDetails(e: React.FormEvent) {
    e.preventDefault();
    if (!staffUid) return;
    setSavingBank(true);
    try {
      await updateDoc(doc(db, 'staff', staffUid), {
        bankDetails: bankForm,
      });
      setEditingBank(false);
    } catch (err: any) {
      alert(err.message || 'Failed to save bank details.');
    } finally {
      setSavingBank(false);
    }
  }

  if (loadingStaff) {
    return <div style={{ padding: 24, textAlign: 'center' }}>Loading Staff Dashboard...</div>;
  }

  if (!staff) {
    return <div style={{ padding: 24, color: 'red' }}>Staff account profile not found. Please contact Administrator.</div>;
  }

  const isCommission = staff.staffType === 'commission';
  const availBalance = staff.wallet?.availableBalance || 0;
  const pendingWd = staff.wallet?.pendingWithdrawals || 0;
  const totalEarned = staff.wallet?.totalEarned || 0;
  const totalWithdrawn = staff.wallet?.totalWithdrawn || 0;

  return (
    <div style={{ maxWidth: 1200, margin: '0 auto', padding: '12px' }}>
      {/* Top Banner Header */}
      <div
        className="table-card"
        style={{
          marginBottom: 20,
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          flexWrap: 'wrap',
          gap: 16,
          padding: 20,
        }}
      >
        <div>
          <h2 style={{ margin: 0, fontSize: '1.35rem', fontWeight: 800 }}>Welcome, {staff.fullName}</h2>
          <div style={{ display: 'flex', alignItems: 'center', flexWrap: 'wrap', gap: 8, marginTop: 6 }}>
            <span className={`status-pill ${isCommission ? 'status-pill--success' : 'status-pill--neutral'}`}>
              {isCommission ? 'Commission Staff' : 'Tracking Staff'}
            </span>
            <span className="muted" style={{ fontSize: '0.85rem' }}>
              Staff ID: <strong style={{ fontFamily: 'monospace' }}>{staff.staffId}</strong>
            </span>
          </div>
        </div>

        <div style={{ display: 'flex', gap: 10, alignItems: 'center', flexWrap: 'wrap', width: '100%', maxWidth: 'fit-content' }}>
          {isCommission && (
            <button
              type="button"
              className="btn btn--primary"
              style={{ padding: '8px 20px', fontSize: '0.85rem', borderRadius: 'var(--radius-full)' }}
              onClick={() => setShowWithdrawModal(true)}
            >
              💰 Withdraw Earnings
            </button>
          )}
          <button
            type="button"
            className="btn btn--ghost"
            style={{ padding: '8px 20px', fontSize: '0.85rem', borderRadius: 'var(--radius-full)' }}
            onClick={handleSignOut}
          >
            Sign Out
          </button>
        </div>
      </div>

      {wdSuccess && (
        <div
          style={{
            background: 'rgba(16, 185, 129, 0.1)',
            color: '#10B981',
            border: '1px solid rgba(16, 185, 129, 0.3)',
            padding: '12px 16px',
            borderRadius: 16,
            marginBottom: 20,
            fontSize: '0.85rem',
            fontWeight: 600,
          }}
        >
          ✓ {wdSuccess}
        </div>
      )}

      {/* Referral Code & Link Card */}
      <div
        className="table-card"
        style={{
          marginBottom: 20,
          padding: 20,
        }}
      >
        <h3 style={{ marginTop: 0, marginBottom: 14, fontSize: '1rem', fontWeight: 700 }}>
          🔗 Your Staff Referral Code & Link
        </h3>

        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(240px, 1fr))', gap: 16 }}>
          <div style={{ background: 'var(--color-bg-alt)', padding: 14, borderRadius: 16, border: '1px solid var(--color-border)' }}>
            <label className="muted" style={{ fontSize: '0.75rem', fontWeight: 700, letterSpacing: 0.5, textTransform: 'uppercase' }}>
              Referral Code
            </label>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8, marginTop: 4 }}>
              <span style={{ fontSize: '1.25rem', fontWeight: 900, color: 'var(--color-primary)', letterSpacing: 1, fontFamily: 'monospace', wordBreak: 'break-all' }}>
                {staff.referralCode}
              </span>
              <button
                type="button"
                className="btn btn--ghost"
                style={{ padding: '4px 14px', fontSize: '0.75rem', whiteSpace: 'nowrap', borderRadius: 'var(--radius-full)' }}
                onClick={() => {
                  navigator.clipboard.writeText(staff.referralCode);
                  alert('Referral code copied!');
                }}
              >
                Copy
              </button>
            </div>
          </div>

          <div style={{ background: 'var(--color-bg-alt)', padding: 14, borderRadius: 16, border: '1px solid var(--color-border)' }}>
            <label className="muted" style={{ fontSize: '0.75rem', fontWeight: 700, letterSpacing: 0.5, textTransform: 'uppercase' }}>
              Referral Link
            </label>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', gap: 8, marginTop: 4 }}>
              <span className="muted" style={{ fontSize: '0.8rem', fontFamily: 'monospace', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', maxWidth: '100%' }}>
                {staff.referralLink || `https://caride.app/ref/${staff.referralCode}`}
              </span>
              <button
                type="button"
                className="btn btn--ghost"
                style={{ padding: '4px 14px', fontSize: '0.75rem', whiteSpace: 'nowrap', borderRadius: 'var(--radius-full)' }}
                onClick={() => {
                  navigator.clipboard.writeText(staff.referralLink || `https://caride.app/ref/${staff.referralCode}`);
                  alert('Referral link copied!');
                }}
              >
                Copy
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* KPI Cards Grid: Solid Dark Metric Cards */}
      {isCommission ? (
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 16, marginBottom: 20 }}>
          <article className="metric-card-dark">
            <div className="metric-card-dark__label">Available Balance</div>
            <div className="metric-card-dark__value">
              {formatNgn(availBalance)}
            </div>
            <button
              type="button"
              className="btn"
              style={{ marginTop: 10, padding: '6px 14px', fontSize: '0.78rem', width: '100%', background: '#ffffff', color: '#064E3B', fontWeight: 700, borderRadius: 'var(--radius-full)' }}
              onClick={() => setShowWithdrawModal(true)}
            >
              Withdraw
            </button>
          </article>

          <article className="metric-card-dark">
            <div className="metric-card-dark__label">Pending Withdrawals</div>
            <div className="metric-card-dark__value">
              {formatNgn(pendingWd)}
            </div>
            <div style={{ fontSize: '0.75rem', color: 'rgba(255,255,255,0.7)', marginTop: 4 }}>Locked in processing</div>
          </article>

          <article className="metric-card-dark">
            <div className="metric-card-dark__label">Total Earned</div>
            <div className="metric-card-dark__value">
              {formatNgn(totalEarned)}
            </div>
            <div style={{ fontSize: '0.75rem', color: 'rgba(255,255,255,0.7)', marginTop: 4 }}>All-time commission earned</div>
          </article>

          <article className="metric-card-dark">
            <div className="metric-card-dark__label">Total Withdrawn</div>
            <div className="metric-card-dark__value">
              {formatNgn(totalWithdrawn)}
            </div>
            <div style={{ fontSize: '0.75rem', color: 'rgba(255,255,255,0.7)', marginTop: 4 }}>Total paid out to bank</div>
          </article>

          <article className="metric-card-dark">
            <div className="metric-card-dark__label">Commission Share</div>
            <div className="metric-card-dark__value">
              {staff.commissionRatePercent}%
            </div>
            <div style={{ fontSize: '0.75rem', color: 'rgba(255,255,255,0.7)', marginTop: 4 }}>Share of CaRide fee</div>
          </article>
        </div>
      ) : (
        /* KPI Cards for Tracking Staff */
        <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))', gap: 16, marginBottom: 20 }}>
          <article className="metric-card-dark">
            <div className="metric-card-dark__label">Total Referrals</div>
            <div className="metric-card-dark__value">
              {staff.stats?.totalReferrals || referrals.length}
            </div>
          </article>

          <article className="metric-card-dark">
            <div className="metric-card-dark__label">Customers Referred</div>
            <div className="metric-card-dark__value">
              {staff.stats?.customersReferred || referrals.filter(r => r.userType === 'customer').length}
            </div>
          </article>

          <article className="metric-card-dark">
            <div className="metric-card-dark__label">Drivers Referred</div>
            <div className="metric-card-dark__value">
              {staff.stats?.driversReferred || referrals.filter(r => r.userType === 'driver').length}
            </div>
          </article>

          <article className="metric-card-dark">
            <div className="metric-card-dark__label">Commission Status</div>
            <div style={{ fontSize: '1.2rem', fontWeight: 800, color: 'rgba(255,255,255,0.85)', marginTop: 8 }}>
              Tracking Only
            </div>
            <div style={{ fontSize: '0.75rem', color: 'rgba(255,255,255,0.65)', marginTop: 4 }}>Fixed salaried staff</div>
          </article>
        </div>
      )}

      {/* Bank Account Details Card for Commission Staff */}
      {isCommission && (
        <div className="table-card" style={{ marginBottom: 20, padding: 20 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 8, marginBottom: 12 }}>
            <h3 style={{ margin: 0, fontSize: '0.95rem', fontWeight: 700 }}>🏦 Your Bank Account Details (Payouts)</h3>
            <button type="button" className="btn btn--ghost" style={{ padding: '6px 14px', fontSize: '0.78rem', borderRadius: 'var(--radius-full)' }} onClick={() => setEditingBank(!editingBank)}>
              {editingBank ? 'Cancel' : 'Edit Bank Details'}
            </button>
          </div>

          {editingBank ? (
            <form onSubmit={handleSaveBankDetails} style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 12, marginTop: 8 }}>
              <div>
                <label className="muted" style={{ fontSize: '0.75rem', fontWeight: 600 }}>Bank Name</label>
                <input
                  type="text"
                  placeholder="e.g. Access Bank"
                  value={bankForm.bankName}
                  onChange={(e) => setBankForm({ ...bankForm, bankName: e.target.value })}
                  style={{ width: '100%', borderRadius: 'var(--radius-full)', padding: '10px 16px', border: '1px solid var(--color-border)', background: 'var(--color-bg-alt)' }}
                  required
                />
              </div>
              <div>
                <label className="muted" style={{ fontSize: '0.75rem', fontWeight: 600 }}>Account Name</label>
                <input
                  type="text"
                  placeholder="e.g. John Doe"
                  value={bankForm.accountName}
                  onChange={(e) => setBankForm({ ...bankForm, accountName: e.target.value })}
                  style={{ width: '100%', borderRadius: 'var(--radius-full)', padding: '10px 16px', border: '1px solid var(--color-border)', background: 'var(--color-bg-alt)' }}
                  required
                />
              </div>
              <div>
                <label className="muted" style={{ fontSize: '0.75rem', fontWeight: 600 }}>Account Number</label>
                <input
                  type="text"
                  placeholder="10 digits"
                  maxLength={10}
                  value={bankForm.accountNumber}
                  onChange={(e) => setBankForm({ ...bankForm, accountNumber: e.target.value })}
                  style={{ width: '100%', borderRadius: 'var(--radius-full)', padding: '10px 16px', border: '1px solid var(--color-border)', background: 'var(--color-bg-alt)' }}
                  required
                />
              </div>
              <div style={{ display: 'flex', alignItems: 'flex-end', gap: 8 }}>
                <button type="submit" className="btn btn--primary" style={{ padding: '10px 20px', fontSize: '0.85rem', borderRadius: 'var(--radius-full)' }} disabled={savingBank}>
                  {savingBank ? 'Saving...' : 'Save Details'}
                </button>
              </div>
            </form>
          ) : staff.bankDetails?.accountNumber ? (
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 24, fontSize: '0.85rem' }}>
              <div><span className="muted">Bank:</span> <strong>{staff.bankDetails.bankName}</strong></div>
              <div><span className="muted">Account Name:</span> <strong>{staff.bankDetails.accountName}</strong></div>
              <div><span className="muted">Account Number:</span> <strong style={{ fontFamily: 'monospace' }}>{staff.bankDetails.accountNumber}</strong></div>
            </div>
          ) : (
            <p className="muted" style={{ fontSize: '0.85rem', margin: 0 }}>
              ⚠️ No bank account registered yet. Please click "Edit Bank Details" to configure where withdrawal payouts are sent.
            </p>
          )}
        </div>
      )}

      {/* Tabs Bar: Underline Tabs */}
      <div className="tab-bar-underline" style={{ marginBottom: 20 }}>
        <button
          type="button"
          className={`tab-btn-underline ${activeTab === 'referrals' ? 'active' : ''}`}
          onClick={() => setActiveTab('referrals')}
        >
          👥 Referred Users <span className="tab-count-badge">{referrals.length}</span>
        </button>
        {isCommission && (
          <>
            <button
              type="button"
              className={`tab-btn-underline ${activeTab === 'earnings' ? 'active' : ''}`}
              onClick={() => setActiveTab('earnings')}
            >
              📈 Earnings History <span className="tab-count-badge">{earnings.length}</span>
            </button>
            <button
              type="button"
              className={`tab-btn-underline ${activeTab === 'withdrawals' ? 'active' : ''}`}
              onClick={() => setActiveTab('withdrawals')}
            >
              💳 Withdrawal History <span className="tab-count-badge">{withdrawals.length}</span>
            </button>
          </>
        )}
      </div>

      {/* TAB 1: Referrals Directory */}
      {activeTab === 'referrals' && (
        <div className="card" style={{ padding: 16 }}>
          <h3 style={{ marginTop: 0, marginBottom: 12, fontSize: '0.95rem', fontWeight: 700 }}>Referred Users Directory</h3>
          {referrals.length === 0 ? (
            <p className="muted" style={{ fontSize: '0.85rem' }}>No users registered with your referral code yet.</p>
          ) : (
            <div style={{ overflowX: 'auto', WebkitOverflowScrolling: 'touch' }}>
              <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '0.8rem', minWidth: 500 }}>
                <thead>
                  <tr style={{ borderBottom: '1px solid var(--color-border)', textAlign: 'left' }}>
                    <th style={{ padding: '10px 12px', whiteSpace: 'nowrap' }}>Joined Date</th>
                    <th style={{ padding: '10px 12px', whiteSpace: 'nowrap' }}>User Type</th>
                    <th style={{ padding: '10px 12px', whiteSpace: 'nowrap' }}>Name</th>
                    <th style={{ padding: '10px 12px', whiteSpace: 'nowrap' }}>Email</th>
                    <th style={{ padding: '10px 12px', whiteSpace: 'nowrap' }}>Code Used</th>
                  </tr>
                </thead>
                <tbody>
                  {referrals.map((ref) => (
                    <tr key={ref.id} style={{ borderBottom: '1px solid var(--color-border)' }}>
                      <td style={{ padding: '10px 12px', whiteSpace: 'nowrap' }}>{formatTs(ref.joinedAt)}</td>
                      <td style={{ padding: '10px 12px', whiteSpace: 'nowrap' }}>
                        <span className={`badge ${ref.userType === 'customer' ? 'badge--info' : 'badge--ok'}`}>
                          {ref.userType.toUpperCase()}
                        </span>
                      </td>
                      <td style={{ padding: '10px 12px', fontWeight: 700, whiteSpace: 'nowrap' }}>{ref.fullName || '—'}</td>
                      <td style={{ padding: '10px 12px', whiteSpace: 'nowrap' }}>{ref.email || '—'}</td>
                      <td style={{ padding: '10px 12px', fontWeight: 800, whiteSpace: 'nowrap' }}>{ref.referralCode}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}

      {/* TAB 2: Earnings History */}
      {activeTab === 'earnings' && isCommission && (
        <div className="card" style={{ padding: 16 }}>
          <h3 style={{ marginTop: 0, marginBottom: 12, fontSize: '0.95rem', fontWeight: 700 }}>Commission Earnings Ledger</h3>
          {earnings.length === 0 ? (
            <p className="muted" style={{ fontSize: '0.85rem' }}>No commission earnings generated yet.</p>
          ) : (
            <div style={{ overflowX: 'auto', WebkitOverflowScrolling: 'touch' }}>
              <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '0.8rem', minWidth: 600 }}>
                <thead>
                  <tr style={{ borderBottom: '1px solid var(--color-border)', textAlign: 'left' }}>
                    <th style={{ padding: '10px 12px', whiteSpace: 'nowrap' }}>Date</th>
                    <th style={{ padding: '10px 12px', whiteSpace: 'nowrap' }}>Ride ID</th>
                    <th style={{ padding: '10px 12px', whiteSpace: 'nowrap' }}>Ride Fare</th>
                    <th style={{ padding: '10px 12px', whiteSpace: 'nowrap' }}>Company Comm.</th>
                    <th style={{ padding: '10px 12px', whiteSpace: 'nowrap' }}>Your Rate (%)</th>
                    <th style={{ padding: '10px 12px', whiteSpace: 'nowrap' }}>Your Earnings</th>
                  </tr>
                </thead>
                <tbody>
                  {earnings.map((tx) => (
                    <tr key={tx.id} style={{ borderBottom: '1px solid var(--color-border)' }}>
                      <td style={{ padding: '10px 12px', whiteSpace: 'nowrap' }}>{formatTs(tx.createdAt)}</td>
                      <td style={{ padding: '10px 12px', fontFamily: 'monospace', whiteSpace: 'nowrap' }}>{tx.rideId}</td>
                      <td style={{ padding: '10px 12px', whiteSpace: 'nowrap' }}>{formatNgn(tx.rideFare)}</td>
                      <td style={{ padding: '10px 12px', whiteSpace: 'nowrap' }}>{formatNgn(tx.companyCommission)}</td>
                      <td style={{ padding: '10px 12px', fontWeight: 700, whiteSpace: 'nowrap' }}>{tx.staffCommissionRate}%</td>
                      <td style={{ padding: '10px 12px', fontWeight: 800, color: '#10B981', whiteSpace: 'nowrap' }}>
                        +{formatNgn(tx.staffCommissionAmount)}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}

      {/* TAB 3: Withdrawal History */}
      {activeTab === 'withdrawals' && isCommission && (
        <div className="card" style={{ padding: 16 }}>
          <h3 style={{ marginTop: 0, marginBottom: 12, fontSize: '0.95rem', fontWeight: 700 }}>Withdrawal Request Log</h3>
          {withdrawals.length === 0 ? (
            <p className="muted" style={{ fontSize: '0.85rem' }}>No withdrawal requests submitted yet.</p>
          ) : (
            <div style={{ overflowX: 'auto', WebkitOverflowScrolling: 'touch' }}>
              <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '0.8rem', minWidth: 550 }}>
                <thead>
                  <tr style={{ borderBottom: '1px solid var(--color-border)', textAlign: 'left' }}>
                    <th style={{ padding: '10px 12px', whiteSpace: 'nowrap' }}>Requested Date</th>
                    <th style={{ padding: '10px 12px', whiteSpace: 'nowrap' }}>Reference ID</th>
                    <th style={{ padding: '10px 12px', whiteSpace: 'nowrap' }}>Amount</th>
                    <th style={{ padding: '10px 12px', whiteSpace: 'nowrap' }}>Status</th>
                    <th style={{ padding: '10px 12px', whiteSpace: 'nowrap' }}>Details / Reason</th>
                  </tr>
                </thead>
                <tbody>
                  {withdrawals.map((wd) => (
                    <tr key={wd.id} style={{ borderBottom: '1px solid var(--color-border)' }}>
                      <td style={{ padding: '10px 12px', whiteSpace: 'nowrap' }}>{formatTs(wd.requestedAt)}</td>
                      <td style={{ padding: '10px 12px', fontFamily: 'monospace', fontWeight: 700, whiteSpace: 'nowrap' }}>{wd.withdrawalId}</td>
                      <td style={{ padding: '10px 12px', fontWeight: 800, color: wd.status === 'paid' ? '#10B981' : wd.status === 'pending' ? '#F59E0B' : '#EF4444', whiteSpace: 'nowrap' }}>
                        {formatNgn(wd.amount)}
                      </td>
                      <td style={{ padding: '10px 12px', whiteSpace: 'nowrap' }}>
                        <span className={`badge ${wd.status === 'paid' ? 'badge--ok' : wd.status === 'pending' ? 'badge--warn' : 'badge--info'}`}>
                          {wd.status}
                        </span>
                      </td>
                      <td style={{ padding: '10px 12px', color: 'var(--color-text-muted)' }}>
                        {wd.rejectionReason || '—'}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          )}
        </div>
      )}

      {/* WITHDRAWAL REQUEST MODAL */}
      {showWithdrawModal && (
        <div style={{ position: 'fixed', inset: 0, background: 'rgba(0,0,0,0.6)', display: 'flex', alignItems: 'center', justifyContent: 'center', zIndex: 100, padding: 16 }}>
          <div className="card" style={{ maxWidth: 440, width: '100%', maxHeight: '90vh', overflowY: 'auto' }}>
            <h3 style={{ marginTop: 0, marginBottom: 12, fontSize: '1.1rem' }}>Request Earnings Withdrawal</h3>

            <div style={{ background: 'rgba(16, 185, 129, 0.08)', padding: '12px 14px', borderRadius: 8, marginBottom: 16 }}>
              <div className="muted" style={{ fontSize: '0.8rem', fontWeight: 600 }}>Available Balance for Withdrawal</div>
              <div style={{ fontSize: '1.5rem', fontWeight: 900, color: '#10B981', marginTop: 2 }}>
                {formatNgn(availBalance)}
              </div>
            </div>

            {wdError && (
              <div style={{ background: 'rgba(239, 68, 68, 0.1)', color: '#EF4444', padding: '8px 12px', borderRadius: 6, marginBottom: 12, fontSize: '0.85rem' }}>
                {wdError}
              </div>
            )}

            <form onSubmit={handleRequestWithdrawal} style={{ display: 'grid', gap: 12 }}>
              <div>
                <label style={{ display: 'block', fontWeight: 600, fontSize: '0.85rem', marginBottom: 6 }}>
                  Withdrawal Amount (₦)
                </label>
                <input
                  type="number"
                  min="1"
                  max={availBalance}
                  className="input"
                  style={{ width: '100%' }}
                  value={withdrawAmount}
                  onChange={(e) => setWithdrawAmount(e.target.value)}
                  placeholder="e.g. 10000"
                  required
                />
              </div>

              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
                <button
                  type="button"
                  className="btn btn--ghost"
                  style={{ padding: '4px 8px', fontSize: '0.75rem' }}
                  onClick={() => setWithdrawAmount(String(availBalance))}
                >
                  Withdraw Entire Balance ({formatNgn(availBalance)})
                </button>
              </div>

              <div style={{ display: 'flex', justifyContent: 'flex-end', gap: 10, marginTop: 12 }}>
                <button type="button" className="btn btn--ghost" onClick={() => setShowWithdrawModal(false)}>Cancel</button>
                <button type="submit" className="btn btn--primary" disabled={submittingWd || availBalance <= 0}>
                  {submittingWd ? 'Submitting...' : 'Confirm Withdrawal Request'}
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  );
}
