import { useState, useEffect } from 'react';
import { collection, onSnapshot, query, orderBy } from 'firebase/firestore';
import { db } from '../config/firebase';

interface DriverReferralRow {
  uid: string;
  fullName: string;
  email: string;
  referralCode: string;
  referralEarnings: number;
  referredCount: number;
  tier: string;
}

function formatNgn(amount: number) {
  return '₦' + amount.toLocaleString('en-NG', { minimumFractionDigits: 0, maximumFractionDigits: 0 });
}

export function DriverReferralsPage() {
  const [drivers, setDrivers] = useState<DriverReferralRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');

  useEffect(() => {
    const unsub = onSnapshot(
      query(collection(db, 'drivers'), orderBy('referralEarnings', 'desc')),
      async (snap) => {
        const rows: DriverReferralRow[] = await Promise.all(
          snap.docs.map(async (docSnap) => {
            const d = docSnap.data();
            // Count referrals subcollection size
            let referredCount = 0;
            try {
              const { getDocs, collection: col } = await import('firebase/firestore');
              const refSnap = await getDocs(col(db, 'drivers', docSnap.id, 'referrals'));
              referredCount = refSnap.size;
            } catch {
              referredCount = 0;
            }
            return {
              uid: docSnap.id,
              fullName: (d.fullName as string) || '',
              email: (d.email as string) || '',
              referralCode: (d.referralCode as string) || '—',
              referralEarnings: (d.referralEarnings as number) || 0,
              referredCount,
              tier: (d.tier as string) || 'bronze',
            };
          }),
        );
        setDrivers(rows);
        setLoading(false);
      },
      () => setLoading(false),
    );
    return () => unsub();
  }, []);

  const totalEarnings = drivers.reduce((acc, d) => acc + d.referralEarnings, 0);
  const totalReferred = drivers.reduce((acc, d) => acc + d.referredCount, 0);
  const activeReferrers = drivers.filter((d) => d.referredCount > 0).length;

  const filtered = drivers.filter(
    (d) =>
      !search ||
      d.fullName.toLowerCase().includes(search.toLowerCase()) ||
      d.email.toLowerCase().includes(search.toLowerCase()) ||
      d.referralCode.toLowerCase().includes(search.toLowerCase()),
  );

  return (
    <div>
      <div style={{ marginBottom: 'var(--space-5)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 'var(--space-3)' }}>
        <p className="muted" style={{ margin: 0 }}>
          Driver referral program — drivers earn 4% of each trip completed by drivers they refer.
        </p>

        {/* Search */}
        <div className="app-topbar__search">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <circle cx="11" cy="11" r="8" /><line x1="21" y1="21" x2="16.65" y2="16.65" />
          </svg>
          <input
            type="text"
            placeholder="Search code, name..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>
      </div>

      {/* Summary stats */}
      <div className="card-grid" style={{ marginBottom: 'var(--space-5)' }}>
        <article className="card">
          <div className="muted" style={{ fontSize: '0.85rem', fontWeight: 600 }}>Total Referral Payouts</div>
          <div style={{ fontSize: '2rem', fontWeight: 800, color: 'var(--color-primary)', marginTop: 4, letterSpacing: '-0.02em' }}>
            {formatNgn(totalEarnings)}
          </div>
        </article>
        
        <article className="card">
          <div className="muted" style={{ fontSize: '0.85rem', fontWeight: 600 }}>Total Drivers Referred</div>
          <div style={{ fontSize: '2rem', fontWeight: 800, marginTop: 4, letterSpacing: '-0.02em' }}>
            {totalReferred}
          </div>
        </article>
        
        <article className="card">
          <div className="muted" style={{ fontSize: '0.85rem', fontWeight: 600 }}>Active Referrers</div>
          <div style={{ fontSize: '2rem', fontWeight: 800, marginTop: 4, letterSpacing: '-0.02em' }}>
            {activeReferrers}
          </div>
        </article>
      </div>

      {loading ? (
        <div className="card" style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {[1, 2, 3].map(i => <div key={i} className="skeleton-row shimmer" style={{ height: 60 }} />)}
        </div>
      ) : filtered.length === 0 ? (
        <div className="card">
          <div className="empty-state">
            <h4 style={{ margin: 0 }}>No referrals matching criteria</h4>
            <p className="muted" style={{ margin: 0, fontSize: '0.85rem' }}>No records found corresponding to this query.</p>
          </div>
        </div>
      ) : (
        <div className="table-wrapper animate-fade-in">
          <table className="table-premium">
            <thead>
              <tr>
                <th>Driver</th>
                <th>Referral Code</th>
                <th>Referred Count</th>
                <th style={{ textAlign: 'right' }}>Total Earnings</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((driver) => (
                <tr key={driver.uid}>
                  <td>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                      <div className="admin-avatar" style={{ background: 'var(--color-primary-light)', color: 'var(--color-primary)', width: 34, height: 34, fontSize: '0.85rem' }}>
                        {(driver.fullName || driver.email)[0]?.toUpperCase()}
                      </div>
                      <div>
                        <div style={{ fontWeight: 700, fontSize: '0.95rem' }}>{driver.fullName || '(no name)'}</div>
                        <div className="muted" style={{ fontSize: '0.78rem' }}>{driver.email}</div>
                      </div>
                    </div>
                  </td>
                  <td>
                    <code
                      style={{
                        background: 'var(--color-bg-alt)',
                        padding: '4px 8px',
                        borderRadius: 'var(--radius-sm)',
                        fontSize: '0.8rem',
                        fontWeight: 700,
                        color: 'var(--color-text)',
                        border: '1px solid var(--color-border)'
                      }}
                    >
                      {driver.referralCode}
                    </code>
                  </td>
                  <td>
                    {driver.referredCount > 0 ? (
                      <span className="badge badge--ok" style={{ fontSize: '0.75rem' }}>
                        {driver.referredCount} driver{driver.referredCount !== 1 ? 's' : ''}
                      </span>
                    ) : (
                      <span className="muted">—</span>
                    )}
                  </td>
                  <td style={{ 
                    textAlign: 'right', 
                    fontWeight: 700, 
                    color: driver.referralEarnings > 0 ? 'var(--color-primary)' : 'var(--color-text-muted)' 
                  }}>
                    {driver.referralEarnings > 0 ? formatNgn(driver.referralEarnings) : '₦0'}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
    </div>
  );
}
