import { useState, useEffect } from 'react';
import {
  doc,
  setDoc,
  collection,
  onSnapshot,
  query,
  orderBy,
  limit,
  serverTimestamp,
} from 'firebase/firestore';
import { db } from '../config/firebase';

interface PromotionSettings {
  creditAmount: number;
  creditAmountChargePercent: number;
  driverReferralPercent: number;
  customerReferralPercent: number;
  isPromotionActive: boolean;
  updatedAt?: any;
  updatedByAdminUid?: string;
}

interface CreditTransactionRow {
  id: string;
  uid: string;
  type: string;
  amountNaira: number;
  referralCode?: string;
  referredUserUid?: string;
  rideId?: string;
  description?: string;
  createdAt?: any;
}

function formatNgn(amount: number) {
  return '₦' + amount.toLocaleString('en-NG', { minimumFractionDigits: 0, maximumFractionDigits: 0 });
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

export function PromotionPage() {
  const [tab, setTab] = useState<'settings' | 'history'>('settings');

  const [settings, setSettings] = useState<PromotionSettings>({
    creditAmount: 1000,
    creditAmountChargePercent: 10,
    driverReferralPercent: 2,
    customerReferralPercent: 2,
    isPromotionActive: true,
  });
  const [loadingConfig, setLoadingConfig] = useState(true);
  const [saving, setSaving] = useState(false);
  const [saveSuccess, setSaveSuccess] = useState<string | null>(null);
  const [saveError, setSaveError] = useState<string | null>(null);

  const [creditTxs, setCreditTxs] = useState<CreditTransactionRow[]>([]);
  const [loadingTxs, setLoadingTxs] = useState(true);
  const [search, setSearch] = useState('');

  // 1. Fetch live promo configuration
  useEffect(() => {
    const ref = doc(db, 'config', 'referralSettings');
    const unsub = onSnapshot(
      ref,
      (snap) => {
        if (snap.exists()) {
          const d = snap.data();
          setSettings({
            creditAmount: Number(d.creditAmount) || 1000,
            creditAmountChargePercent: Number(d.creditAmountChargePercent) || 10,
            driverReferralPercent: Number(d.driverReferralPercent) || 2,
            customerReferralPercent: Number(d.customerReferralPercent) || 2,
            isPromotionActive: d.isPromotionActive !== false,
          });
        }
        setLoadingConfig(false);
      },
      () => setLoadingConfig(false),
    );
    return () => unsub();
  }, []);

  // 2. Fetch live credit transaction history
  useEffect(() => {
    const unsub = onSnapshot(
      query(collection(db, 'credit_transactions'), orderBy('createdAt', 'desc'), limit(100)),
      (snap) => {
        const rows: CreditTransactionRow[] = snap.docs.map((docSnap) => {
          const d = docSnap.data();
          return {
            id: docSnap.id,
            uid: (d.uid as string) || '',
            type: (d.type as string) || 'referral_reward',
            amountNaira: (d.amountNaira as number) || 0,
            referralCode: d.referralCode as string | undefined,
            referredUserUid: d.referredUserUid as string | undefined,
            rideId: d.rideId as string | undefined,
            description: d.description as string | undefined,
            createdAt: d.createdAt,
          };
        });
        setCreditTxs(rows);
        setLoadingTxs(false);
      },
      () => setLoadingTxs(false),
    );
    return () => unsub();
  }, []);

  // Handle saving promotion configuration
  async function handleSaveSettings(e: React.FormEvent) {
    e.preventDefault();
    setSaveSuccess(null);
    setSaveError(null);

    if (settings.creditAmount <= 0) {
      setSaveError('Credit amount must be greater than zero.');
      return;
    }
    if (settings.creditAmountChargePercent <= 0 || settings.creditAmountChargePercent > 100) {
      setSaveError('Credit coverage percentage must be between 1% and 100%.');
      return;
    }

    setSaving(true);
    try {
      await setDoc(
        doc(db, 'config', 'referralSettings'),
        {
          creditAmount: settings.creditAmount,
          creditAmountChargePercent: settings.creditAmountChargePercent,
          driverReferralPercent: settings.driverReferralPercent,
          customerReferralPercent: settings.customerReferralPercent,
          isPromotionActive: settings.isPromotionActive,
          updatedAt: serverTimestamp(),
          updatedByAdminUid: 'admin',
        },
        { merge: true },
      );
      setSaveSuccess('Promotion settings updated successfully!');
    } catch (err: any) {
      setSaveError(err.message || 'Failed to update promotion settings.');
    } finally {
      setSaving(false);
    }
  }

  const totalCreditsAwarded = creditTxs
    .filter((tx) => tx.type === 'referral_reward')
    .reduce((acc, tx) => acc + tx.amountNaira, 0);

  const totalCreditsUsed = creditTxs
    .filter((tx) => tx.type === 'credit_used')
    .reduce((acc, tx) => acc + tx.amountNaira, 0);

  const filteredTxs = creditTxs.filter(
    (tx) =>
      !search ||
      tx.id.toLowerCase().includes(search.toLowerCase()) ||
      tx.uid.toLowerCase().includes(search.toLowerCase()) ||
      (tx.referralCode && tx.referralCode.toLowerCase().includes(search.toLowerCase())) ||
      (tx.description && tx.description.toLowerCase().includes(search.toLowerCase())),
  );

  return (
    <div>
      {/* Top Header */}
      <div style={{ marginBottom: 'var(--space-5)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 'var(--space-3)' }}>
        <div>
          <h2 style={{ margin: 0, fontSize: '1.4rem', fontWeight: 800 }}>Referral Credit & Promotion System</h2>
          <p className="muted" style={{ margin: '4px 0 0', fontSize: '0.85rem' }}>
            Configure referral promotional credits and monitor credit usage across rides.
          </p>
        </div>

        {/* Tab Toggle Buttons */}
        <div style={{ display: 'flex', gap: 'var(--space-2)' }}>
          <button
            type="button"
            className={`btn ${tab === 'settings' ? 'btn--primary' : 'btn--ghost'}`}
            onClick={() => setTab('settings')}
          >
            Promotion Settings
          </button>
          <button
            type="button"
            className={`btn ${tab === 'history' ? 'btn--primary' : 'btn--ghost'}`}
            onClick={() => setTab('history')}
          >
            Activity & History ({creditTxs.length})
          </button>
        </div>
      </div>

      {/* Summary KPI Cards */}
      <div className="card-grid" style={{ marginBottom: 'var(--space-5)' }}>
        <article className="card">
          <div className="muted" style={{ fontSize: '0.85rem', fontWeight: 600 }}>Referral Credit Bonus</div>
          <div style={{ fontSize: '2rem', fontWeight: 800, color: 'var(--color-primary)', marginTop: 4 }}>
            {formatNgn(settings.creditAmount)}
          </div>
          <div className="muted" style={{ fontSize: '0.75rem', marginTop: 4 }}>Awarded per valid referral</div>
        </article>

        <article className="card">
          <div className="muted" style={{ fontSize: '0.85rem', fontWeight: 600 }}>Max Fare Coverage Cap</div>
          <div style={{ fontSize: '2rem', fontWeight: 800, color: '#10B981', marginTop: 4 }}>
            {settings.creditAmountChargePercent}%
          </div>
          <div className="muted" style={{ fontSize: '0.75rem', marginTop: 4 }}>Max ride fare covered by Credit Wallet</div>
        </article>

        <article className="card">
          <div className="muted" style={{ fontSize: '0.85rem', fontWeight: 600 }}>Total Credits Awarded</div>
          <div style={{ fontSize: '2rem', fontWeight: 800, color: '#6366F1', marginTop: 4 }}>
            {formatNgn(totalCreditsAwarded)}
          </div>
          <div className="muted" style={{ fontSize: '0.75rem', marginTop: 4 }}>All-time referral rewards</div>
        </article>

        <article className="card">
          <div className="muted" style={{ fontSize: '0.85rem', fontWeight: 600 }}>Total Credits Redeemed</div>
          <div style={{ fontSize: '2rem', fontWeight: 800, color: '#F59E0B', marginTop: 4 }}>
            {formatNgn(totalCreditsUsed)}
          </div>
          <div className="muted" style={{ fontSize: '0.75rem', marginTop: 4 }}>Redeemed on passenger rides</div>
        </article>
      </div>

      {/* TAB 1: Promotion Settings Form */}
      {tab === 'settings' && (
        <div className="card" style={{ maxWidth: 640 }}>
          <h3 style={{ marginTop: 0, marginBottom: 'var(--space-4)', fontSize: '1.1rem', fontWeight: 700 }}>
            Configure Referral Promotion Rules
          </h3>

          {saveSuccess && (
            <div style={{ background: 'rgba(16, 185, 129, 0.1)', color: '#10B981', padding: '10px 14px', borderRadius: 8, marginBottom: 'var(--space-4)', fontSize: '0.85rem', fontWeight: 600 }}>
              {saveSuccess}
            </div>
          )}

          {saveError && (
            <div style={{ background: 'rgba(239, 68, 68, 0.1)', color: '#EF4444', padding: '10px 14px', borderRadius: 8, marginBottom: 'var(--space-4)', fontSize: '0.85rem', fontWeight: 600 }}>
              {saveError}
            </div>
          )}

          <form onSubmit={handleSaveSettings} style={{ display: 'grid', gap: 'var(--space-4)' }}>
            <div>
              <label style={{ display: 'block', fontWeight: 600, fontSize: '0.85rem', marginBottom: 6 }}>
                Referral Credit Reward (creditAmount in ₦)
              </label>
              <input
                type="number"
                min="0"
                step="100"
                className="input"
                style={{ width: '100%' }}
                value={settings.creditAmount}
                onChange={(e) => setSettings({ ...settings, creditAmount: Number(e.target.value) })}
                placeholder="1000"
                required
              />
              <span className="muted" style={{ fontSize: '0.75rem', marginTop: 4, display: 'block' }}>
                Amount of promotional credit added to a user's Credit Wallet upon applying a valid referral code.
              </span>
            </div>

            <div>
              <label style={{ display: 'block', fontWeight: 600, fontSize: '0.85rem', marginBottom: 6 }}>
                Max Fare Coverage (creditAmountChargePercent %)
              </label>
              <input
                type="number"
                min="1"
                max="100"
                step="1"
                className="input"
                style={{ width: '100%' }}
                value={settings.creditAmountChargePercent}
                onChange={(e) => setSettings({ ...settings, creditAmountChargePercent: Number(e.target.value) })}
                placeholder="10"
                required
              />
              <span className="muted" style={{ fontSize: '0.75rem', marginTop: 4, display: 'block' }}>
                The maximum percentage of a final ride fare that the Credit Wallet can cover (e.g. 10% on a ₦2,500 ride covers up to ₦250).
              </span>
            </div>

            <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-3)', marginTop: 'var(--space-2)' }}>
              <input
                type="checkbox"
                id="isPromotionActive"
                checked={settings.isPromotionActive}
                onChange={(e) => setSettings({ ...settings, isPromotionActive: e.target.checked })}
                style={{ width: 18, height: 18, cursor: 'pointer' }}
              />
              <label htmlFor="isPromotionActive" style={{ fontWeight: 600, fontSize: '0.9rem', cursor: 'pointer' }}>
                Enable Referral Credit Promotion System
              </label>
            </div>

            <div style={{ marginTop: 'var(--space-3)' }}>
              <button type="submit" className="btn btn--primary" disabled={saving || loadingConfig}>
                {saving ? 'Saving Settings...' : 'Save Promotion Settings'}
              </button>
            </div>
          </form>
        </div>
      )}

      {/* TAB 2: Promotion Activity & History */}
      {tab === 'history' && (
        <div className="card">
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 'var(--space-3)', marginBottom: 'var(--space-4)' }}>
            <h3 style={{ margin: 0, fontSize: '1.1rem', fontWeight: 700 }}>Referral & Credit Audit History</h3>

            <div className="app-topbar__search">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <circle cx="11" cy="11" r="8" /><line x1="21" y1="21" x2="16.65" y2="16.65" />
              </svg>
              <input
                type="text"
                placeholder="Search UID, code, desc..."
                value={search}
                onChange={(e) => setSearch(e.target.value)}
              />
            </div>
          </div>

          {loadingTxs ? (
            <p className="muted">Loading credit transactions...</p>
          ) : filteredTxs.length === 0 ? (
            <p className="muted">No credit transactions recorded yet.</p>
          ) : (
            <div style={{ overflowX: 'auto' }}>
              <table style={{ width: '100%', borderCollapse: 'collapse', fontSize: '0.85rem' }}>
                <thead>
                  <tr style={{ borderBottom: '1px solid var(--color-border)', textAlign: 'left' }}>
                    <th style={{ padding: '10px 12px' }}>Date / Time</th>
                    <th style={{ padding: '10px 12px' }}>Type</th>
                    <th style={{ padding: '10px 12px' }}>User ID</th>
                    <th style={{ padding: '10px 12px' }}>Referral Code</th>
                    <th style={{ padding: '10px 12px' }}>Amount</th>
                    <th style={{ padding: '10px 12px' }}>Description / Reference</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredTxs.map((tx) => {
                    const isCredit = tx.type === 'referral_reward';
                    return (
                      <tr key={tx.id} style={{ borderBottom: '1px solid var(--color-border)' }}>
                        <td style={{ padding: '10px 12px', whiteSpace: 'nowrap' }}>{formatTs(tx.createdAt)}</td>
                        <td style={{ padding: '10px 12px' }}>
                          <span className={`badge ${isCredit ? 'badge--ok' : 'badge--warn'}`}>
                            {tx.type}
                          </span>
                        </td>
                        <td style={{ padding: '10px 12px', fontFamily: 'monospace' }}>{tx.uid.slice(0, 10)}...</td>
                        <td style={{ padding: '10px 12px', fontWeight: 700 }}>{tx.referralCode || '—'}</td>
                        <td style={{ padding: '10px 12px', fontWeight: 800, color: isCredit ? '#10B981' : '#F59E0B' }}>
                          {isCredit ? '+' : '-'}{formatNgn(tx.amountNaira)}
                        </td>
                        <td style={{ padding: '10px 12px', color: 'var(--color-text-muted)' }}>
                          {tx.description || tx.rideId || '—'}
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
    </div>
  );
}
