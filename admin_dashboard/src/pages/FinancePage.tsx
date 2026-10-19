import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  collection,
  getDocs,
  limit,
  orderBy,
  query,
  Timestamp,
  where,
  onSnapshot,
  type QuerySnapshot,
  type DocumentData,
} from 'firebase/firestore';
import { db, auth } from '../config/firebase';
import { formatNgn } from '../util/money';

function windowLabel(hours: number): string {
  if (hours >= 168) return '7d';
  if (hours >= 24) return '24h';
  return `${hours}h`;
}

export function FinancePage() {
  const navigate = useNavigate();
  const [windowHours, setWindowHours] = useState(24);
  const [commissionTotal, setCommissionTotal] = useState(0);
  const [movements, setMovements] = useState<
    { id: string; title: string; amount: number; method: string; uid: string; date?: string }[]
  >([]);
  const [loadingAgg, setLoadingAgg] = useState(true);
  const [errorAgg, setErrorAgg] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [hideBalance, setHideBalance] = useState(false);
  const [activeTab, setActiveTab] = useState<'all' | 'inflow' | 'outflow'>('all');

  useEffect(() => {
    if (!auth.currentUser) {
      setLoadingAgg(false);
      return;
    }
    let cancelled = false;

    async function loadCommission() {
      setLoadingAgg(true);
      setErrorAgg(null);
      try {
        const since = Timestamp.fromDate(new Date(Date.now() - windowHours * 60 * 60 * 1000));
        const platSnap = await getDocs(
          query(collection(db, 'platformEarnings'), where('createdAt', '>=', since)),
        );
        let sum = 0;
        platSnap.forEach((docSnap) => {
          const n = docSnap.data().commissionNaira as number | undefined;
          if (typeof n === 'number') sum += n;
        });
        if (!cancelled) setCommissionTotal(sum);
      } catch (e) {
        if (!cancelled) {
          setErrorAgg(e instanceof Error ? e.message : 'Could not load commission data.');
          setCommissionTotal(0);
        }
      } finally {
        if (!cancelled) setLoadingAgg(false);
      }
    }

    void loadCommission();
    return () => {
      cancelled = true;
    };
  }, [windowHours]);

  useEffect(() => {
    if (!auth.currentUser) return;
    const q = query(collection(db, 'walletTransactions'), orderBy('createdAt', 'desc'), limit(100));

    const unsub = onSnapshot(
      q,
      (snap: QuerySnapshot<DocumentData>) => {
        const rows = snap.docs.map((docSnap) => {
          const d = docSnap.data();
          const amount = (d.amountNaira as number) ?? 0;
          const type = (d.type as string) || '';
          const signed = type === 'debit' || type === 'commission_debit' ? -Math.abs(amount) : Math.abs(amount);
          const createdAt = (d.createdAt as { toDate?: () => Date } | undefined)?.toDate?.();
          return {
            id: docSnap.id,
            title: (d.description as string) || type || 'Transaction',
            amount: signed,
            method: (d.method as string) || 'Wallet Transfer',
            uid: (d.uid as string) || '',
            date: createdAt ? createdAt.toLocaleString('en-NG', { dateStyle: 'medium', timeStyle: 'short' }) : '—',
          };
        });
        setMovements(rows);
      },
      () => {},
    );

    return () => unsub();
  }, []);

  const totalInflow = movements.filter(m => m.amount > 0).reduce((acc, curr) => acc + curr.amount, 0);
  const totalOutflow = movements.filter(m => m.amount < 0).reduce((acc, curr) => acc + Math.abs(curr.amount), 0);

  const filteredMovements = movements.filter(m => {
    const matchesSearch = 
      m.title.toLowerCase().includes(searchTerm.toLowerCase()) ||
      m.method.toLowerCase().includes(searchTerm.toLowerCase()) ||
      m.uid.toLowerCase().includes(searchTerm.toLowerCase());
    
    if (activeTab === 'all') return matchesSearch;
    if (activeTab === 'inflow') return matchesSearch && m.amount > 0;
    if (activeTab === 'outflow') return matchesSearch && m.amount < 0;
    return matchesSearch;
  });

  return (
    <div>
      {/* Wallet Hero Gradient Card (Matching wallet (1).png) */}
      <div className="wallet-hero-card">
        <div>
          <div className="wallet-hero-card__label">
            <span>Available Platform Balance</span>
            <button
              type="button"
              className="wallet-hero-card__eye"
              onClick={() => setHideBalance(!hideBalance)}
              title={hideBalance ? 'Show balance' : 'Hide balance'}
            >
              {hideBalance ? (
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
          <div className="wallet-hero-card__balance">
            {hideBalance ? '₦ ••••••••' : loadingAgg ? '…' : errorAgg ? '—' : formatNgn(commissionTotal)}
          </div>
          <p style={{ margin: '8px 0 0 0', fontSize: '0.825rem', opacity: 0.85 }}>
            Real-time balance accrued from marketplace commissions & driver wallet sweeps.
          </p>
        </div>

        <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
          <button
            type="button"
            className="btn--payout"
            onClick={() => navigate('/admin/withdrawals')}
          >
            <svg style={{ width: 16, height: 16 }} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
              <line x1="12" y1="1" x2="12" y2="23" />
              <path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6" />
            </svg>
            <span>Withdrawals & Payouts →</span>
          </button>
        </div>
      </div>

      {/* 4 Summary Stat Cards (Matching wallet (1).png) */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(210px, 1fr))', gap: 16, marginBottom: 24 }}>
        <div className="card" style={{ padding: 20 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span className="muted" style={{ fontSize: '0.825rem', fontWeight: 600 }}>Commission Revenue</span>
            <div style={{ width: 34, height: 34, borderRadius: '50%', background: '#DCFCE7', color: '#15803D', display: 'grid', placeItems: 'center' }}>
              ★
            </div>
          </div>
          <div style={{ fontSize: '1.75rem', fontWeight: 800, marginTop: 8 }}>
            {formatNgn(commissionTotal)}
          </div>
          <div style={{ display: 'flex', gap: 6, marginTop: 10 }}>
            {[24, 168].map(h => (
              <button
                key={h}
                type="button"
                className={`filter-pill ${windowHours === h ? 'active' : ''}`}
                style={{ padding: '3px 10px', fontSize: '0.725rem' }}
                onClick={() => setWindowHours(h)}
              >
                {windowLabel(h)} Frame
              </button>
            ))}
          </div>
        </div>

        <div className="card" style={{ padding: 20 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span className="muted" style={{ fontSize: '0.825rem', fontWeight: 600 }}>Total Inflows</span>
            <div style={{ width: 34, height: 34, borderRadius: '50%', background: '#DCFCE7', color: '#15803D', display: 'grid', placeItems: 'center', fontWeight: 800 }}>
              ↓
            </div>
          </div>
          <div style={{ fontSize: '1.75rem', fontWeight: 800, marginTop: 8, color: '#16a34a' }}>
            +{formatNgn(totalInflow)}
          </div>
          <span className="muted" style={{ fontSize: '0.75rem' }}>Credits & driver deposits</span>
        </div>

        <div className="card" style={{ padding: 20 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span className="muted" style={{ fontSize: '0.825rem', fontWeight: 600 }}>Total Outflows</span>
            <div style={{ width: 34, height: 34, borderRadius: '50%', background: '#FEE2E2', color: '#B91C1C', display: 'grid', placeItems: 'center', fontWeight: 800 }}>
              ↑
            </div>
          </div>
          <div style={{ fontSize: '1.75rem', fontWeight: 800, marginTop: 8, color: '#dc2626' }}>
            −{formatNgn(totalOutflow)}
          </div>
          <span className="muted" style={{ fontSize: '0.75rem' }}>Debits & withdrawals</span>
        </div>

        <div className="card" style={{ padding: 20 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span className="muted" style={{ fontSize: '0.825rem', fontWeight: 600 }}>Recorded Volume</span>
            <div style={{ width: 34, height: 34, borderRadius: '50%', background: '#E0F2FE', color: '#0369A1', display: 'grid', placeItems: 'center', fontWeight: 800 }}>
              ⇅
            </div>
          </div>
          <div style={{ fontSize: '1.75rem', fontWeight: 800, marginTop: 8 }}>
            {movements.length}
          </div>
          <span className="muted" style={{ fontSize: '0.75rem' }}>Recent transactions synced</span>
        </div>
      </div>

      {/* Filter Toolbar & Search */}
      <div className="filter-toolbar">
        {/* Underline Tab Bar */}
        <div className="tab-bar-underline" style={{ margin: 0, border: 'none' }}>
          <button
            type="button"
            className={`tab-btn-underline ${activeTab === 'all' ? 'active' : ''}`}
            onClick={() => setActiveTab('all')}
          >
            <span>All Ledger</span>
            <span className="tab-count-badge">{movements.length}</span>
          </button>
          <button
            type="button"
            className={`tab-btn-underline ${activeTab === 'inflow' ? 'active' : ''}`}
            onClick={() => setActiveTab('inflow')}
          >
            <span>Credits (+)</span>
            <span className="tab-count-badge">{movements.filter(m => m.amount > 0).length}</span>
          </button>
          <button
            type="button"
            className={`tab-btn-underline ${activeTab === 'outflow' ? 'active' : ''}`}
            onClick={() => setActiveTab('outflow')}
          >
            <span>Debits (−)</span>
            <span className="tab-count-badge">{movements.filter(m => m.amount < 0).length}</span>
          </button>
        </div>

        <div className="search-pill-wrap">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <circle cx="11" cy="11" r="8" /><line x1="21" y1="21" x2="16.65" y2="16.65" />
          </svg>
          <input 
            type="text" 
            placeholder="Search transactions, UID..." 
            value={searchTerm} 
            onChange={e => setSearchTerm(e.target.value)} 
          />
        </div>
      </div>

      {/* Transactions Table Card (Matching wallet (1).png) */}
      <div className="table-card">
        {filteredMovements.length === 0 ? (
          <div className="empty-state">
            <svg className="empty-state__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <rect x="2" y="4" width="20" height="16" rx="2" />
              <line x1="12" y1="10" x2="12" y2="10" />
            </svg>
            <h4 style={{ margin: 0 }}>No movements recorded</h4>
            <p className="muted" style={{ margin: 0, fontSize: '0.85rem' }}>No transaction matched your active search or tab filter.</p>
          </div>
        ) : (
          <div style={{ overflowX: 'auto' }}>
            <table className="table-premium" style={{ margin: 0 }}>
              <thead>
                <tr>
                  <th>Transaction Description</th>
                  <th>User / Driver UID</th>
                  <th>Channel / Method</th>
                  <th>Timestamp</th>
                  <th style={{ textAlign: 'right' }}>Amount</th>
                  <th>Status</th>
                </tr>
              </thead>
              <tbody>
                {filteredMovements.map((m) => {
                  const isPositive = m.amount > 0;
                  return (
                    <tr key={m.id}>
                      <td>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                          <div style={{ 
                            width: 32, 
                            height: 32, 
                            borderRadius: '50%', 
                            background: isPositive ? '#DCFCE7' : '#FEE2E2', 
                            color: isPositive ? '#15803D' : '#B91C1C', 
                            display: 'grid', 
                            placeItems: 'center',
                            fontWeight: 800,
                            fontSize: '0.85rem'
                          }}>
                            {isPositive ? '↓' : '↑'}
                          </div>
                          <div>
                            <div style={{ fontWeight: 600, fontSize: '0.885rem' }}>{m.title}</div>
                            <span className="muted" style={{ fontSize: '0.72rem' }}>ID: #{m.id.slice(0, 8)}</span>
                          </div>
                        </div>
                      </td>
                      <td>
                        {m.uid ? (
                          <code style={{ fontSize: '0.8rem', background: 'var(--color-bg-alt)', padding: '2px 6px', borderRadius: 6 }}>
                            {m.uid.slice(0, 10)}…
                          </code>
                        ) : (
                          <span className="muted">—</span>
                        )}
                      </td>
                      <td>
                        <span className="filter-pill" style={{ padding: '3px 10px', fontSize: '0.75rem', cursor: 'default' }}>
                          {m.method}
                        </span>
                      </td>
                      <td style={{ fontSize: '0.8rem', color: 'var(--color-text-muted)' }}>
                        {m.date}
                      </td>
                      <td style={{ 
                        textAlign: 'right', 
                        fontWeight: 800, 
                        fontSize: '0.95rem',
                        color: isPositive ? '#16a34a' : '#dc2626' 
                      }}>
                        {isPositive ? '+' : '−'}{formatNgn(Math.abs(m.amount))}
                      </td>
                      <td>
                        <span className={`status-pill ${isPositive ? 'status-pill--completed' : 'status-pill--paid'}`}>
                          Success
                        </span>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>

            {/* Pagination Footer */}
            <div className="table-pagination">
              <span>Showing {filteredMovements.length} of {movements.length} transactions</span>
              <div className="table-pagination__controls">
                <button type="button" className="pagination-circle-btn" disabled>
                  ‹
                </button>
                <button type="button" className="pagination-circle-btn active">
                  1
                </button>
                <button type="button" className="pagination-circle-btn" disabled>
                  ›
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
