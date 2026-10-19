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
  firstRideCashbackAmount: number;
  isFirstRideCashbackActive: boolean;
  isTripCashbackActive?: boolean;
  tripCashbackPercent?: number;
  tripCashbackMinFare?: number;
  tripCashbackDestination?: 'main_wallet' | 'subsidy_wallet';
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
    firstRideCashbackAmount: 500,
    isFirstRideCashbackActive: true,
    isTripCashbackActive: true,
    tripCashbackPercent: 5,
    tripCashbackMinFare: 5000,
    tripCashbackDestination: 'main_wallet',
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
            firstRideCashbackAmount: d.firstRideCashbackAmount !== undefined ? Number(d.firstRideCashbackAmount) : 500,
            isFirstRideCashbackActive: d.isFirstRideCashbackActive !== false,
            isTripCashbackActive: d.isTripCashbackActive !== false,
            tripCashbackPercent: d.tripCashbackPercent !== undefined ? Number(d.tripCashbackPercent) : 5,
            tripCashbackMinFare: d.tripCashbackMinFare !== undefined ? Number(d.tripCashbackMinFare) : 5000,
            tripCashbackDestination: (d.tripCashbackDestination as 'main_wallet' | 'subsidy_wallet') || 'main_wallet',
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

    if (settings.firstRideCashbackAmount < 0) {
      setSaveError('First ride cashback amount cannot be negative.');
      return;
    }

    if ((settings.tripCashbackPercent ?? 0) < 0 || (settings.tripCashbackPercent ?? 0) > 100) {
      setSaveError('Trip cashback percentage must be between 0% and 100%.');
      return;
    }

    if ((settings.tripCashbackMinFare ?? 0) < 0) {
      setSaveError('Trip minimum fare cannot be negative.');
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
          firstRideCashbackAmount: settings.firstRideCashbackAmount,
          isFirstRideCashbackActive: settings.isFirstRideCashbackActive,
          isTripCashbackActive: settings.isTripCashbackActive !== false,
          tripCashbackPercent: settings.tripCashbackPercent ?? 5,
          tripCashbackMinFare: settings.tripCashbackMinFare ?? 5000,
          tripCashbackDestination: settings.tripCashbackDestination || 'main_wallet',
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
      {/* Top Filter & Tab Bar Toolbar */}
      <div className="filter-toolbar" style={{ marginBottom: 20 }}>
        <div className="tab-bar-underline" style={{ margin: 0, borderBottom: 'none' }}>
          <button
            type="button"
            className={`tab-btn-underline ${tab === 'settings' ? 'active' : ''}`}
            onClick={() => setTab('settings')}
          >
            Promotion Settings
          </button>
          <button
            type="button"
            className={`tab-btn-underline ${tab === 'history' ? 'active' : ''}`}
            onClick={() => setTab('history')}
          >
            Activity & History <span className="tab-count-badge">{creditTxs.length}</span>
          </button>
        </div>

        {tab === 'history' && (
          <div className="search-pill-wrap">
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
        )}
      </div>

      {/* Summary KPI Cards: Solid Dark Metric Cards */}
      <div className="card-grid" style={{ marginBottom: 24, gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))' }}>
        <article className="metric-card-dark">
          <div className="metric-card-dark__label">Trip Cashback (₦5k+)</div>
          <div className="metric-card-dark__value">
            {settings.tripCashbackPercent ?? 5}%
          </div>
          <div style={{ fontSize: '0.78rem', color: settings.isTripCashbackActive ? '#10B981' : 'rgba(255,255,255,0.5)', marginTop: 4, display: 'flex', alignItems: 'center', gap: 6 }}>
            <span style={{ width: 8, height: 8, borderRadius: '50%', background: settings.isTripCashbackActive ? '#10B981' : '#6B7280', display: 'inline-block' }} />
            {settings.isTripCashbackActive 
              ? `Active • ${settings.tripCashbackDestination === 'subsidy_wallet' ? 'Subsidy Wallet' : 'Main Wallet'}` 
              : 'Disabled'}
          </div>
        </article>

        <article className="metric-card-dark">
          <div className="metric-card-dark__label">First Ride Cashback</div>
          <div className="metric-card-dark__value">
            {formatNgn(settings.firstRideCashbackAmount)}
          </div>
          <div style={{ fontSize: '0.78rem', color: settings.isFirstRideCashbackActive ? '#10B981' : 'rgba(255,255,255,0.5)', marginTop: 4, display: 'flex', alignItems: 'center', gap: 6 }}>
            <span style={{ width: 8, height: 8, borderRadius: '50%', background: settings.isFirstRideCashbackActive ? '#10B981' : '#6B7280', display: 'inline-block' }} />
            {settings.isFirstRideCashbackActive ? 'Active • Credited on 1st ride' : 'Disabled'}
          </div>
        </article>

        <article className="metric-card-dark">
          <div className="metric-card-dark__label">Referral Credit Bonus</div>
          <div className="metric-card-dark__value">
            {formatNgn(settings.creditAmount)}
          </div>
          <div style={{ fontSize: '0.78rem', color: 'rgba(255,255,255,0.7)', marginTop: 4 }}>Awarded per valid referral</div>
        </article>

        <article className="metric-card-dark">
          <div className="metric-card-dark__label">Max Fare Coverage Cap</div>
          <div className="metric-card-dark__value">
            {settings.creditAmountChargePercent}%
          </div>
          <div style={{ fontSize: '0.78rem', color: 'rgba(255,255,255,0.7)', marginTop: 4 }}>Max ride fare covered by wallet</div>
        </article>

        <article className="metric-card-dark">
          <div className="metric-card-dark__label">Total Credits Awarded</div>
          <div className="metric-card-dark__value">
            {formatNgn(totalCreditsAwarded)}
          </div>
          <div style={{ fontSize: '0.78rem', color: 'rgba(255,255,255,0.7)', marginTop: 4 }}>All-time referral rewards</div>
        </article>

        <article className="metric-card-dark">
          <div className="metric-card-dark__label">Total Credits Redeemed</div>
          <div className="metric-card-dark__value">
            {formatNgn(totalCreditsUsed)}
          </div>
          <div style={{ fontSize: '0.78rem', color: 'rgba(255,255,255,0.7)', marginTop: 4 }}>Redeemed on passenger rides</div>
        </article>
      </div>

      {/* TAB 1: Promotion Settings Form */}
      {tab === 'settings' && (
        <div className="table-card" style={{ maxWidth: 640, padding: 28 }}>
          <div style={{ marginBottom: 20 }}>
            <h3 style={{ margin: 0, fontSize: '1.1rem', fontWeight: 700 }}>
              Configure Promotion & Cashback Rules
            </h3>
            <p style={{ margin: '4px 0 0 0', fontSize: '0.82rem', color: 'var(--color-text-muted)' }}>
              Set customer first ride cashback reward and referral discount rules.
            </p>
          </div>

          {saveSuccess && (
            <div style={{ background: 'rgba(16, 185, 129, 0.1)', color: '#10B981', padding: '12px 16px', borderRadius: 16, marginBottom: 20, fontSize: '0.85rem', fontWeight: 600, border: '1px solid rgba(16, 185, 129, 0.2)' }}>
              ✓ {saveSuccess}
            </div>
          )}

          {saveError && (
            <div className="alert-banner-danger" style={{ marginBottom: 20 }}>
              <div style={{ flex: 1 }}>{saveError}</div>
            </div>
          )}

          <form onSubmit={handleSaveSettings} style={{ display: 'grid', gap: 24 }}>
            {/* FIRST RIDE CASHBACK SECTION */}
            <div style={{ background: 'var(--color-bg-alt)', padding: '20px', borderRadius: '16px', border: '1px solid var(--color-border)' }}>
              <div style={{ marginBottom: 16 }}>
                <h4 style={{ margin: 0, fontSize: '1rem', fontWeight: 700, display: 'flex', alignItems: 'center', gap: 8 }}>
                  <span>🎁</span> Customer First Ride Cashback
                </h4>
                <p style={{ margin: '4px 0 0 0', fontSize: '0.8rem', color: 'var(--color-text-muted)' }}>
                  A fixed amount credited directly into customer's wallet balance when they complete their first ride booking.
                </p>
              </div>

              <div>
                <label style={{ display: 'block', fontWeight: 600, fontSize: '0.85rem', marginBottom: 8 }}>
                  Cashback Amount (₦)
                </label>
                <div style={{ display: 'flex', gap: 10, marginBottom: 10 }}>
                  <input
                    type="number"
                    min="0"
                    step="50"
                    style={{ 
                      width: '100%', 
                      height: 48, 
                      borderRadius: 'var(--radius-full)', 
                      padding: '0 20px', 
                      border: '1px solid var(--color-border)',
                      background: 'var(--color-bg)',
                      color: 'var(--color-text)',
                      outline: 'none',
                      fontSize: '1rem',
                      fontWeight: 700
                    }}
                    value={settings.firstRideCashbackAmount}
                    onChange={(e) => setSettings({ ...settings, firstRideCashbackAmount: Number(e.target.value) })}
                    placeholder="500"
                    required
                  />
                </div>

                {/* Quick preset amount pills */}
                <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginBottom: 12 }}>
                  {[500, 1000, 1500, 2000].map((amt) => (
                    <button
                      key={amt}
                      type="button"
                      onClick={() => setSettings({ ...settings, firstRideCashbackAmount: amt })}
                      style={{
                        padding: '6px 14px',
                        borderRadius: 16,
                        border: settings.firstRideCashbackAmount === amt ? '1.5px solid var(--color-primary)' : '1px solid var(--color-border)',
                        background: settings.firstRideCashbackAmount === amt ? 'rgba(16, 185, 129, 0.12)' : 'var(--color-bg)',
                        color: settings.firstRideCashbackAmount === amt ? 'var(--color-primary)' : 'var(--color-text)',
                        fontSize: '0.8rem',
                        fontWeight: 700,
                        cursor: 'pointer',
                        transition: 'all 0.15s ease'
                      }}
                    >
                      ₦{amt.toLocaleString()}
                    </button>
                  ))}
                </div>

                <span className="muted" style={{ fontSize: '0.75rem', marginTop: 4, display: 'block' }}>
                  This exact amount will be credited to the customer's wallet upon their first completed ride.
                </span>
              </div>

              <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginTop: 14 }}>
                <input
                  type="checkbox"
                  id="isFirstRideCashbackActive"
                  checked={settings.isFirstRideCashbackActive}
                  onChange={(e) => setSettings({ ...settings, isFirstRideCashbackActive: e.target.checked })}
                  style={{ width: 18, height: 18, cursor: 'pointer', accentColor: 'var(--color-primary)' }}
                />
                <label htmlFor="isFirstRideCashbackActive" style={{ fontWeight: 600, fontSize: '0.88rem', cursor: 'pointer' }}>
                  Enable First Ride Cashback Reward
                </label>
              </div>
            </div>

            {/* % TRIP CASHBACK SECTION (₦5,000+ TRIPS) */}
            <div style={{ background: 'var(--color-bg-alt)', padding: '20px', borderRadius: '16px', border: '1px solid var(--color-border)' }}>
              <div style={{ marginBottom: 16 }}>
                <h4 style={{ margin: 0, fontSize: '1rem', fontWeight: 700, display: 'flex', alignItems: 'center', gap: 8 }}>
                  <span>💸</span> Trip Percentage (%) Cashback (₦5,000 & Above)
                </h4>
                <p style={{ margin: '4px 0 0 0', fontSize: '0.8rem', color: 'var(--color-text-muted)' }}>
                  Automatically calculate and award a configurable cashback percentage on every completed customer trip with fare reaching the minimum threshold.
                </p>
              </div>

              {/* Percentage Input */}
              <div style={{ marginBottom: 16 }}>
                <label style={{ display: 'block', fontWeight: 600, fontSize: '0.85rem', marginBottom: 8 }}>
                  Cashback Percentage (%)
                </label>
                <div style={{ display: 'flex', gap: 10, marginBottom: 10 }}>
                  <input
                    type="number"
                    min="0"
                    max="100"
                    step="0.5"
                    style={{ 
                      width: '100%', 
                      height: 48, 
                      borderRadius: 'var(--radius-full)', 
                      padding: '0 20px', 
                      border: '1px solid var(--color-border)',
                      background: 'var(--color-bg)',
                      color: 'var(--color-text)',
                      outline: 'none',
                      fontSize: '1rem',
                      fontWeight: 700
                    }}
                    value={settings.tripCashbackPercent ?? 5}
                    onChange={(e) => setSettings({ ...settings, tripCashbackPercent: Number(e.target.value) })}
                    placeholder="5"
                    required
                  />
                </div>

                {/* Quick preset percentage pills */}
                <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap', marginBottom: 6 }}>
                  {[2, 3, 5, 7.5, 10].map((pct) => (
                    <button
                      key={pct}
                      type="button"
                      onClick={() => setSettings({ ...settings, tripCashbackPercent: pct })}
                      style={{
                        padding: '6px 14px',
                        borderRadius: 16,
                        border: settings.tripCashbackPercent === pct ? '1.5px solid var(--color-primary)' : '1px solid var(--color-border)',
                        background: settings.tripCashbackPercent === pct ? 'rgba(16, 185, 129, 0.12)' : 'var(--color-bg)',
                        color: settings.tripCashbackPercent === pct ? 'var(--color-primary)' : 'var(--color-text)',
                        fontSize: '0.8rem',
                        fontWeight: 700,
                        cursor: 'pointer',
                        transition: 'all 0.15s ease'
                      }}
                    >
                      {pct}%
                    </button>
                  ))}
                </div>
              </div>

              {/* Minimum Trip Fare Threshold */}
              <div style={{ marginBottom: 18 }}>
                <label style={{ display: 'block', fontWeight: 600, fontSize: '0.85rem', marginBottom: 8 }}>
                  Minimum Trip Fare (₦)
                </label>
                <input
                  type="number"
                  min="0"
                  step="500"
                  style={{ 
                    width: '100%', 
                    height: 48, 
                    borderRadius: 'var(--radius-full)', 
                    padding: '0 20px', 
                    border: '1px solid var(--color-border)',
                    background: 'var(--color-bg)',
                    color: 'var(--color-text)',
                    outline: 'none',
                    fontSize: '1rem',
                    fontWeight: 700
                  }}
                  value={settings.tripCashbackMinFare ?? 5000}
                  onChange={(e) => setSettings({ ...settings, tripCashbackMinFare: Number(e.target.value) })}
                  placeholder="5000"
                  required
                />
                <span className="muted" style={{ fontSize: '0.75rem', marginTop: 4, display: 'block' }}>
                  Trips with fare equal to or greater than this amount qualify for the cashback percentage.
                </span>
              </div>

              {/* Cashback Destination Switch */}
              <div style={{ marginBottom: 18 }}>
                <label style={{ display: 'block', fontWeight: 600, fontSize: '0.85rem', marginBottom: 8 }}>
                  Credit Cashback Destination Wallet
                </label>
                <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
                  {/* Option 1: Customer Main Wallet Balance */}
                  <div
                    onClick={() => setSettings({ ...settings, tripCashbackDestination: 'main_wallet' })}
                    style={{
                      border: settings.tripCashbackDestination === 'main_wallet'
                        ? '2px solid var(--color-primary)'
                        : '1px solid var(--color-border)',
                      background: settings.tripCashbackDestination === 'main_wallet'
                        ? 'rgba(16, 185, 129, 0.08)'
                        : 'var(--color-bg)',
                      borderRadius: 14,
                      padding: '14px 16px',
                      cursor: 'pointer',
                      display: 'flex',
                      flexDirection: 'column',
                      gap: 4,
                      transition: 'all 0.15s ease'
                    }}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                      <input
                        type="radio"
                        id="dest_main_wallet"
                        name="tripCashbackDestination"
                        checked={settings.tripCashbackDestination === 'main_wallet'}
                        onChange={() => setSettings({ ...settings, tripCashbackDestination: 'main_wallet' })}
                        style={{ accentColor: 'var(--color-primary)', cursor: 'pointer' }}
                      />
                      <label htmlFor="dest_main_wallet" style={{ fontWeight: 700, fontSize: '0.88rem', cursor: 'pointer' }}>
                        Customer Wallet Balance
                      </label>
                    </div>
                    <span style={{ fontSize: '0.75rem', color: 'var(--color-text-muted)', paddingLeft: 22 }}>
                      Credited directly to main balance in Wallet Screen. Spendable or withdrawable.
                    </span>
                  </div>

                  {/* Option 2: CaRide Subsidy Wallet */}
                  <div
                    onClick={() => setSettings({ ...settings, tripCashbackDestination: 'subsidy_wallet' })}
                    style={{
                      border: settings.tripCashbackDestination === 'subsidy_wallet'
                        ? '2px solid var(--color-primary)'
                        : '1px solid var(--color-border)',
                      background: settings.tripCashbackDestination === 'subsidy_wallet'
                        ? 'rgba(16, 185, 129, 0.08)'
                        : 'var(--color-bg)',
                      borderRadius: 14,
                      padding: '14px 16px',
                      cursor: 'pointer',
                      display: 'flex',
                      flexDirection: 'column',
                      gap: 4,
                      transition: 'all 0.15s ease'
                    }}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                      <input
                        type="radio"
                        id="dest_subsidy_wallet"
                        name="tripCashbackDestination"
                        checked={settings.tripCashbackDestination === 'subsidy_wallet'}
                        onChange={() => setSettings({ ...settings, tripCashbackDestination: 'subsidy_wallet' })}
                        style={{ accentColor: 'var(--color-primary)', cursor: 'pointer' }}
                      />
                      <label htmlFor="dest_subsidy_wallet" style={{ fontWeight: 700, fontSize: '0.88rem', cursor: 'pointer' }}>
                        CaRide Subsidy Wallet
                      </label>
                    </div>
                    <span style={{ fontSize: '0.75rem', color: 'var(--color-text-muted)', paddingLeft: 22 }}>
                      Credited to credit balance in Subsidy Wallet (Referral Screen) to discount future rides.
                    </span>
                  </div>
                </div>
              </div>

              {/* Enable/Disable Toggle */}
              <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginTop: 14 }}>
                <input
                  type="checkbox"
                  id="isTripCashbackActive"
                  checked={settings.isTripCashbackActive !== false}
                  onChange={(e) => setSettings({ ...settings, isTripCashbackActive: e.target.checked })}
                  style={{ width: 18, height: 18, cursor: 'pointer', accentColor: 'var(--color-primary)' }}
                />
                <label htmlFor="isTripCashbackActive" style={{ fontWeight: 600, fontSize: '0.88rem', cursor: 'pointer' }}>
                  Enable Percentage Cashback on Eligible Trips (≥ ₦{settings.tripCashbackMinFare?.toLocaleString() ?? '5,000'})
                </label>
              </div>
            </div>

            {/* REFERRAL PROMOTION SECTION */}
            <div>
              <label style={{ display: 'block', fontWeight: 600, fontSize: '0.85rem', marginBottom: 6 }}>
                Referral Credit Reward (creditAmount in ₦)
              </label>
              <input
                type="number"
                min="0"
                step="100"
                style={{ 
                  width: '100%', 
                  height: 48, 
                  borderRadius: 'var(--radius-full)', 
                  padding: '0 20px', 
                  border: '1px solid var(--color-border)',
                  background: 'var(--color-bg-alt)',
                  color: 'var(--color-text)',
                  outline: 'none',
                  fontSize: '0.9rem'
                }}
                value={settings.creditAmount}
                onChange={(e) => setSettings({ ...settings, creditAmount: Number(e.target.value) })}
                placeholder="1000"
                required
              />
              <span className="muted" style={{ fontSize: '0.75rem', marginTop: 6, display: 'block' }}>
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
                style={{ 
                  width: '100%', 
                  height: 48, 
                  borderRadius: 'var(--radius-full)', 
                  padding: '0 20px', 
                  border: '1px solid var(--color-border)',
                  background: 'var(--color-bg-alt)',
                  color: 'var(--color-text)',
                  outline: 'none',
                  fontSize: '0.9rem'
                }}
                value={settings.creditAmountChargePercent}
                onChange={(e) => setSettings({ ...settings, creditAmountChargePercent: Number(e.target.value) })}
                placeholder="10"
                required
              />
              <span className="muted" style={{ fontSize: '0.75rem', marginTop: 6, display: 'block' }}>
                The maximum percentage of a final ride fare that the Credit Wallet can cover (e.g. 10% on a ₦2,500 ride covers up to ₦250).
              </span>
            </div>

            <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginTop: 4 }}>
              <input
                type="checkbox"
                id="isPromotionActive"
                checked={settings.isPromotionActive}
                onChange={(e) => setSettings({ ...settings, isPromotionActive: e.target.checked })}
                style={{ width: 18, height: 18, cursor: 'pointer', accentColor: 'var(--color-primary)' }}
              />
              <label htmlFor="isPromotionActive" style={{ fontWeight: 600, fontSize: '0.9rem', cursor: 'pointer' }}>
                Enable Referral Credit Promotion System
              </label>
            </div>

            <div style={{ marginTop: 12 }}>
              <button 
                type="submit" 
                className="btn btn--primary" 
                style={{ borderRadius: 'var(--radius-full)', padding: '12px 28px', height: 48 }}
                disabled={saving || loadingConfig}
              >
                {saving ? 'Saving Settings...' : 'Save Promotion Settings'}
              </button>
            </div>
          </form>
        </div>
      )}

      {/* TAB 2: Promotion Activity & History */}
      {tab === 'history' && (
        <div className="table-card">
          <div className="table-card-header">
            <div>
              <h3 style={{ margin: 0, fontSize: '1rem', fontWeight: 700 }}>Referral & Credit Audit History</h3>
              <p style={{ margin: '2px 0 0 0', fontSize: '0.8rem', color: 'var(--color-text-muted)' }}>
                Showing {filteredTxs.length} credit ledger transactions
              </p>
            </div>
          </div>

          {loadingTxs ? (
            <div style={{ padding: 24 }}>
              <p className="muted" style={{ margin: 0 }}>Loading credit transactions...</p>
            </div>
          ) : filteredTxs.length === 0 ? (
            <div className="empty-state">
              <h4 style={{ margin: 0 }}>No transactions found</h4>
              <p className="muted" style={{ margin: 0, fontSize: '0.85rem' }}>No credit transactions recorded yet.</p>
            </div>
          ) : (
            <div style={{ overflowX: 'auto' }}>
              <table className="table-premium">
                <thead>
                  <tr>
                    <th>Date / Time</th>
                    <th>Type</th>
                    <th>User ID</th>
                    <th>Referral Code</th>
                    <th>Amount</th>
                    <th>Description / Reference</th>
                  </tr>
                </thead>
                <tbody>
                  {filteredTxs.map((tx) => {
                    const isCredit = tx.type === 'referral_reward';
                    return (
                      <tr key={tx.id}>
                        <td style={{ whiteSpace: 'nowrap', fontSize: '0.82rem', color: 'var(--color-text-muted)' }}>{formatTs(tx.createdAt)}</td>
                        <td>
                          <span className={`status-pill ${isCredit ? 'status-pill--success' : 'status-pill--warning'}`}>
                            {tx.type}
                          </span>
                        </td>
                        <td><code style={{ fontSize: '0.78rem', background: 'var(--color-bg-alt)', padding: '3px 8px', borderRadius: 6 }}>{tx.uid.slice(0, 10)}...</code></td>
                        <td style={{ fontWeight: 700 }}>{tx.referralCode || '—'}</td>
                        <td style={{ fontWeight: 800, color: isCredit ? 'var(--color-primary)' : 'var(--color-warning)' }}>
                          {isCredit ? '+' : '-'}{formatNgn(tx.amountNaira)}
                        </td>
                        <td style={{ color: 'var(--color-text-muted)', fontSize: '0.85rem' }}>
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
