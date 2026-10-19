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
      {/* Top Filter & Search Toolbar */}
      <div className="filter-toolbar" style={{ marginBottom: 20 }}>
        <div>
          <h2 style={{ margin: 0, fontSize: '1.25rem', fontWeight: 800 }}>Driver Referral Program</h2>
          <p className="muted" style={{ margin: '2px 0 0 0', fontSize: '0.85rem' }}>
            Drivers earn 4% commission on every ride completed by peers they onboarded.
          </p>
        </div>

        <div style={{ display: 'flex', gap: 12, alignItems: 'center', flexWrap: 'wrap' }}>
          <div className="search-pill-wrap">
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
      </div>

      {/* Summary stats: Dark Metric Cards */}
      <div className="card-grid" style={{ marginBottom: 24, gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))' }}>
        <article className="metric-card-dark">
          <div className="metric-card-dark__label">Total Referral Payouts</div>
          <div className="metric-card-dark__value">
            {formatNgn(totalEarnings)}
          </div>
          <div style={{ fontSize: '0.78rem', color: 'rgba(255,255,255,0.7)', marginTop: 4 }}>Cumulative rewards distributed</div>
        </article>
        
        <article className="metric-card-dark">
          <div className="metric-card-dark__label">Total Drivers Referred</div>
          <div className="metric-card-dark__value">
            {totalReferred}
          </div>
          <div style={{ fontSize: '0.78rem', color: 'rgba(255,255,255,0.7)', marginTop: 4 }}>Peer drivers onboarded</div>
        </article>
        
        <article className="metric-card-dark">
          <div className="metric-card-dark__label">Active Referrers</div>
          <div className="metric-card-dark__value">
            {activeReferrers}
          </div>
          <div style={{ fontSize: '0.78rem', color: 'rgba(255,255,255,0.7)', marginTop: 4 }}>Drivers with &gt;= 1 invite</div>
        </article>
      </div>

      {loading ? (
        <div className="table-card" style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 12 }}>
          {[1, 2, 3].map(i => <div key={i} className="skeleton-row shimmer" style={{ height: 50, borderRadius: 12 }} />)}
        </div>
      ) : filtered.length === 0 ? (
        <div className="table-card">
          <div className="empty-state">
            <h4 style={{ margin: 0 }}>No referrals matching criteria</h4>
            <p className="muted" style={{ margin: 0, fontSize: '0.85rem' }}>No records found corresponding to this query.</p>
          </div>
        </div>
      ) : (
        <div className="table-card">
          <div className="table-card-header">
            <div>
              <h3 style={{ margin: 0, fontSize: '1rem', fontWeight: 700 }}>Referral Roster</h3>
              <p style={{ margin: '2px 0 0 0', fontSize: '0.8rem', color: 'var(--color-text-muted)' }}>
                Showing {filtered.length} registered drivers
              </p>
            </div>
          </div>

          <div style={{ overflowX: 'auto' }}>
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
                          padding: '4px 10px',
                          borderRadius: 'var(--radius-full)',
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
                        <span className="status-pill status-pill--success" style={{ fontSize: '0.75rem', padding: '3px 10px' }}>
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
        </div>
      )}
    </div>
  );
}
