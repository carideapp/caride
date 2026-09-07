import { useEffect, useState } from 'react';
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
  const [windowHours, setWindowHours] = useState(24);
  const [commissionTotal, setCommissionTotal] = useState(0);
  const [movements, setMovements] = useState<
    { id: string; title: string; amount: number; method: string; uid: string }[]
  >([]);
  const [loadingAgg, setLoadingAgg] = useState(true);
  const [errorAgg, setErrorAgg] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState('');

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
          return {
            id: docSnap.id,
            title: (d.description as string) || type || 'Transaction',
            amount: signed,
            method: (d.method as string) || '—',
            uid: (d.uid as string) || '',
          };
        });
        setMovements(rows);
      },
      () => {
        /* movements subscription failed — leave empty */
      },
    );

    return () => unsub();
  }, []);

  const filteredMovements = movements.filter(m => 
    m.title.toLowerCase().includes(searchTerm.toLowerCase()) ||
    m.method.toLowerCase().includes(searchTerm.toLowerCase()) ||
    m.uid.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div>
      <div style={{ marginBottom: 'var(--space-5)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 'var(--space-3)' }}>
        <p className="muted" style={{ margin: 0 }}>
          Commission flow analysis and direct wallet transactions.
        </p>

        {/* Search */}
        <div className="app-topbar__search">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <circle cx="11" cy="11" r="8" /><line x1="21" y1="21" x2="16.65" y2="16.65" />
          </svg>
          <input 
            type="text" 
            placeholder="Search transaction description..." 
            value={searchTerm} 
            onChange={e => setSearchTerm(e.target.value)} 
          />
        </div>
      </div>

      {/* Grid containing Highlight Metrics and Timeframe Toggle */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr', gap: 'var(--space-4)', marginBottom: 'var(--space-5)' }} className="finance-grid">
        <style>{`
          @media (min-width: 768px) {
            .finance-grid {
              grid-template-columns: 1.5fr 1fr !important;
            }
          }
        `}</style>

        {/* Aggregated Commission Card */}
        <article className="card" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
          <div>
            <div className="muted" style={{ fontSize: '0.85rem', fontWeight: 600 }}>Commission Revenue Summary</div>
            <div style={{ fontSize: '2.25rem', fontWeight: 800, color: 'var(--color-text)', marginTop: '4px', letterSpacing: '-0.03em' }}>
              {loadingAgg ? '…' : errorAgg ? '—' : formatNgn(commissionTotal)}
            </div>
            {errorAgg && <p className="field__error" style={{ margin: '4px 0 0 0' }}>{errorAgg}</p>}
          </div>

          <div style={{ display: 'flex', gap: 'var(--space-2)' }}>
            {[24, 168].map((h) => (
              <button
                key={h}
                type="button"
                className={`btn ${windowHours === h ? 'btn--primary' : 'btn--ghost'}`}
                onClick={() => setWindowHours(h)}
                style={{ padding: '6px 12px', fontSize: '0.8rem' }}
              >
                {windowLabel(h)} Frame
              </button>
            ))}
          </div>
        </article>

        {/* Auxiliary Stats */}
        <article className="card" style={{ display: 'flex', flexDirection: 'column', justifyContent: 'center' }}>
          <span className="muted" style={{ fontSize: '0.85rem' }}>Transaction Volume (Last 100)</span>
          <span style={{ fontSize: '1.75rem', fontWeight: 800, marginTop: '4px' }}>{movements.length}</span>
          <span className="badge badge--ok" style={{ width: 'fit-content', marginTop: 'var(--space-2)' }}>Synced</span>
        </article>
      </div>

      {/* Movements Table */}
      <h3 style={{ fontSize: '1.05rem', fontWeight: 700, marginBottom: 'var(--space-3)' }}>Recent Wallet Movements</h3>
      
      <div className="table-wrapper">
        {filteredMovements.length === 0 ? (
          <div className="empty-state">
            <svg className="empty-state__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <rect x="2" y="4" width="20" height="16" rx="2" />
              <line x1="12" y1="10" x2="12" y2="10" />
            </svg>
            <h4 style={{ margin: 0 }}>No movements recorded</h4>
            <p className="muted" style={{ margin: 0, fontSize: '0.85rem' }}>No transaction fits this filter or has been registered in the system.</p>
          </div>
        ) : (
          <table className="table-premium">
            <thead>
              <tr>
                <th>Description</th>
                <th>User Reference</th>
                <th>Method</th>
                <th style={{ textAlign: 'right' }}>Amount</th>
              </tr>
            </thead>
            <tbody>
              {filteredMovements.map((m) => (
                <tr key={m.id}>
                  <td style={{ fontWeight: 600 }}>{m.title}</td>
                  <td>
                    {m.uid ? (
                      <code style={{ fontSize: '0.825rem' }}>{m.uid}</code>
                    ) : (
                      <span className="muted">—</span>
                    )}
                  </td>
                  <td>
                    <span className="badge badge--info">{m.method}</span>
                  </td>
                  <td style={{ 
                    textAlign: 'right', 
                    fontWeight: 700, 
                    color: m.amount < 0 ? 'var(--color-error)' : 'var(--color-primary)' 
                  }}>
                    {m.amount < 0 ? '−' : '+'}{formatNgn(Math.abs(m.amount))}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </div>
  );
}
