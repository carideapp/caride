import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { collection, onSnapshot, orderBy, query, type QuerySnapshot, type DocumentData } from 'firebase/firestore';
import { db } from '../config/firebase';

type Tab = 'customers' | 'drivers';

interface CustomerRow {
  uid: string;
  fullName: string;
  email: string;
  walletBalance: number;
  createdAtMs: number;
}

interface DriverRow {
  uid: string;
  fullName: string;
  email: string;
  approvalStatus: string;
  tier: string;
}

export function UsersPage() {
  const [tab, setTab] = useState<Tab>('customers');
  const [customers, setCustomers] = useState<CustomerRow[]>([]);
  const [drivers, setDrivers] = useState<DriverRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState('');

  useEffect(() => {
    const unsubCustomers = onSnapshot(
      collection(db, 'customers'),
      (snap: QuerySnapshot<DocumentData>) => {
        const rows: CustomerRow[] = snap.docs.map((docSnap) => {
          const d = docSnap.data();
          const ts = d.createdAt as { toMillis?: () => number } | undefined;
          const createdAtMs = ts?.toMillis?.() ?? 0;
          return {
            uid: docSnap.id,
            fullName: (d.fullName as string) || '',
            email: (d.email as string) || '',
            walletBalance: (d.walletBalance as number) || 0,
            createdAtMs,
          };
        });
        rows.sort((a, b) => b.createdAtMs - a.createdAtMs || a.email.localeCompare(b.email));
        setCustomers(rows);
        setLoading(false);
        setError(null);
      },
      (e) => {
        setError(e.message);
        setLoading(false);
      },
    );

    const driversQ = query(collection(db, 'drivers'), orderBy('updatedAt', 'desc'));
    const unsubDrivers = onSnapshot(
      driversQ,
      (snap: QuerySnapshot<DocumentData>) => {
        const rows: DriverRow[] = snap.docs.map((docSnap) => {
          const d = docSnap.data();
          return {
            uid: docSnap.id,
            fullName: (d.fullName as string) || '',
            email: (d.email as string) || '',
            approvalStatus: (d.approvalStatus as string) || 'pending',
            tier: (d.tier as string) || 'bronze',
          };
        });
        setDrivers(rows);
        setLoading(false);
        setError(null);
      },
      (e) => {
        setError(e.message);
        setLoading(false);
      },
    );

    return () => {
      unsubCustomers();
      unsubDrivers();
    };
  }, []);

  function toneForApproval(status: string): 'ok' | 'warn' | 'error' {
    if (status === 'approved') return 'ok';
    if (status === 'rejected') return 'error';
    return 'warn';
  }

  function getTierBadgeColor(tier: string) {
    switch (tier.toLowerCase()) {
      case 'gold': return '#fbbf24';
      case 'platinum': return '#a78bfa';
      case 'silver': return '#94a3b8';
      default: return '#b45309'; // bronze
    }
  }

  const filteredCustomers = customers.filter(c => 
    c.fullName.toLowerCase().includes(searchTerm.toLowerCase()) ||
    c.email.toLowerCase().includes(searchTerm.toLowerCase()) ||
    c.uid.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const filteredDrivers = drivers.filter(d => 
    d.fullName.toLowerCase().includes(searchTerm.toLowerCase()) ||
    d.email.toLowerCase().includes(searchTerm.toLowerCase()) ||
    d.uid.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div>
      <div style={{ marginBottom: 'var(--space-5)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 'var(--space-3)' }}>
        <p className="muted" style={{ margin: 0 }}>
          Manage customers and registered driver accounts.
        </p>

        {/* Tab & Search controls */}
        <div style={{ display: 'flex', gap: 'var(--space-3)', alignItems: 'center', flexWrap: 'wrap' }}>
          <div className="app-topbar__search">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <circle cx="11" cy="11" r="8" /><line x1="21" y1="21" x2="16.65" y2="16.65" />
            </svg>
            <input 
              type="text" 
              placeholder="Search user name or ID..." 
              value={searchTerm} 
              onChange={e => setSearchTerm(e.target.value)} 
            />
          </div>
        </div>
      </div>

      {error && <p className="field__error" style={{ marginBottom: 'var(--space-4)' }}>{error}</p>}

      {/* Tabs */}
      <div style={{ display: 'flex', gap: 'var(--space-2)', marginBottom: 'var(--space-4)', borderBottom: '1px solid var(--color-border)', paddingBottom: 'var(--space-3)' }}>
        <button
          type="button"
          className={`btn ${tab === 'customers' ? 'btn--primary' : 'btn--ghost'}`}
          onClick={() => { setTab('customers'); setSearchTerm(''); }}
        >
          Customers ({customers.length})
        </button>
        <button
          type="button"
          className={`btn ${tab === 'drivers' ? 'btn--primary' : 'btn--ghost'}`}
          onClick={() => { setTab('drivers'); setSearchTerm(''); }}
        >
          Drivers ({drivers.length})
        </button>
      </div>

      {loading && customers.length === 0 && drivers.length === 0 ? (
        <div className="card" style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          {[1, 2, 3, 4].map(idx => (
            <div key={idx} className="skeleton-row shimmer" style={{ height: 60 }} />
          ))}
        </div>
      ) : tab === 'customers' ? (
        <div className="table-wrapper">
          {filteredCustomers.length === 0 ? (
            <div className="empty-state">
              <svg className="empty-state__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <circle cx="9" cy="7" r="4" /><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
              </svg>
              <h4 style={{ margin: 0 }}>No customers found</h4>
              <p className="muted" style={{ margin: 0, fontSize: '0.85rem' }}>No matching profiles correspond to this query.</p>
            </div>
          ) : (
            <table className="table-premium">
              <thead>
                <tr>
                  <th>User</th>
                  <th>Email</th>
                  <th>Wallet Balance</th>
                  <th>ID / UID</th>
                  <th>Role</th>
                </tr>
              </thead>
              <tbody>
                {filteredCustomers.map((u) => (
                  <tr key={u.uid}>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                        <div className="admin-avatar">
                          {(u.fullName || u.email || '?')[0].toUpperCase()}
                        </div>
                        <div style={{ fontWeight: 600 }}>{u.fullName || '(no name)'}</div>
                      </div>
                    </td>
                    <td>{u.email}</td>
                    <td style={{ fontWeight: 600, color: 'var(--color-primary-active)' }}>
                      ₦{u.walletBalance.toLocaleString('en-NG')}
                    </td>
                    <td><code style={{ fontSize: '0.8rem' }}>{u.uid}</code></td>
                    <td><span className="badge badge--ok">Customer</span></td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      ) : (
        <div className="table-wrapper">
          {filteredDrivers.length === 0 ? (
            <div className="empty-state">
              <svg className="empty-state__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <circle cx="9" cy="7" r="4" /><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
              </svg>
              <h4 style={{ margin: 0 }}>No drivers found</h4>
              <p className="muted" style={{ margin: 0, fontSize: '0.85rem' }}>No drivers correspond to this search query.</p>
            </div>
          ) : (
            <table className="table-premium">
              <thead>
                <tr>
                  <th>Driver</th>
                  <th>Email</th>
                  <th>Tier</th>
                  <th>Approval Status</th>
                  <th>Actions</th>
                </tr>
              </thead>
              <tbody>
                {filteredDrivers.map((d) => (
                  <tr key={d.uid}>
                    <td>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                        <div className="admin-avatar" style={{ background: 'linear-gradient(135deg, #10b981, #059669)' }}>
                          {(d.fullName || d.email || '?')[0].toUpperCase()}
                        </div>
                        <div style={{ fontWeight: 600 }}>{d.fullName || '(no name)'}</div>
                      </div>
                    </td>
                    <td>{d.email}</td>
                    <td>
                      <span style={{ 
                        display: 'inline-flex', 
                        alignItems: 'center', 
                        gap: 6, 
                        fontWeight: 700, 
                        fontSize: '0.75rem', 
                        textTransform: 'uppercase',
                        color: getTierBadgeColor(d.tier)
                      }}>
                        ★ {d.tier}
                      </span>
                    </td>
                    <td>
                      <span className={`badge badge--${toneForApproval(d.approvalStatus)}`}>
                        {d.approvalStatus}
                      </span>
                    </td>
                    <td>
                      <Link to={`/admin/drivers/${d.uid}`} className="btn btn--ghost" style={{ padding: '4px 12px', fontSize: '0.8rem' }}>
                        View Profile
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      )}
    </div>
  );
}
