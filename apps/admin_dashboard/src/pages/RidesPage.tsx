import { useEffect, useState } from 'react';
import {
  collection,
  limit,
  onSnapshot,
  orderBy,
  query,
  type QuerySnapshot,
  type DocumentData,
} from 'firebase/firestore';
import { db } from '../config/firebase';

interface RideRow {
  id: string;
  status: string;
  customerUid: string;
  customerName: string;
  driverUid: string;
  driverName: string;
  pickupLabel: string;
  dropoffLabel: string;
  finalFare: number;
  paymentMethod: string;
  updatedAt: Date | null;
}

function badgeTone(status: string): 'ok' | 'warn' | 'error' | 'info' {
  switch (status.toLowerCase()) {
    case 'completed': return 'ok';
    case 'cancelled': return 'error';
    case 'requested': return 'info';
    case 'driverenroute':
    case 'ridestarted':
    case 'bidding': return 'warn';
    default: return 'info';
  }
}

export function RidesPage() {
  const [rides, setRides] = useState<RideRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [filterStatus, setFilterStatus] = useState<string>('all');
  const [searchTerm, setSearchTerm] = useState('');

  useEffect(() => {
    const q = query(collection(db, 'rides'), orderBy('updatedAt', 'desc'), limit(50));

    const unsub = onSnapshot(
      q,
      (snap: QuerySnapshot<DocumentData>) => {
        const rows: RideRow[] = snap.docs.map((docSnap) => {
          const d = docSnap.data();
          const updatedAt = (d.updatedAt as { toDate?: () => Date } | undefined)?.toDate?.() ?? null;
          return {
            id: docSnap.id,
            status: (d.status as string) || 'unknown',
            customerUid: (d.customerUid as string) || '',
            customerName: (d.customerName as string) || '',
            driverUid: (d.driverUid as string) || '',
            driverName: (d.driverName as string) || '',
            pickupLabel: (d.pickupLabel as string) || (d.pickup as string) || '—',
            dropoffLabel: (d.dropoffLabel as string) || '—',
            finalFare: (d.finalFare as number) ?? (d.amountNaira as number) ?? 0,
            paymentMethod: (d.paymentMethod as string) || '—',
            updatedAt,
          };
        });
        setRides(rows);
        setLoading(false);
        setError(null);
      },
      (e) => {
        setError(e.message);
        setLoading(false);
      },
    );

    return () => unsub();
  }, []);

  const filteredRides = rides.filter(r => {
    const matchesSearch = 
      r.id.toLowerCase().includes(searchTerm.toLowerCase()) ||
      r.customerName.toLowerCase().includes(searchTerm.toLowerCase()) ||
      r.driverName.toLowerCase().includes(searchTerm.toLowerCase()) ||
      r.pickupLabel.toLowerCase().includes(searchTerm.toLowerCase()) ||
      r.dropoffLabel.toLowerCase().includes(searchTerm.toLowerCase());
    
    if (filterStatus === 'all') return matchesSearch;
    return matchesSearch && r.status.toLowerCase() === filterStatus.toLowerCase();
  });

  return (
    <div>
      <div style={{ marginBottom: 'var(--space-5)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 'var(--space-3)' }}>
        <p className="muted" style={{ margin: 0 }}>
          Live logs showing the last 50 rides processed by the marketplace.
        </p>

        {/* Filter controls */}
        <div style={{ display: 'flex', gap: 'var(--space-3)', alignItems: 'center', flexWrap: 'wrap' }}>
          <div className="app-topbar__search">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <circle cx="11" cy="11" r="8" /><line x1="21" y1="21" x2="16.65" y2="16.65" />
            </svg>
            <input 
              type="text" 
              placeholder="Search rider, driver, route..." 
              value={searchTerm} 
              onChange={e => setSearchTerm(e.target.value)} 
            />
          </div>

          <div className="field" style={{ margin: 0, flexDirection: 'row', alignItems: 'center', gap: 8 }}>
            <select value={filterStatus} onChange={e => setFilterStatus(e.target.value)} style={{ padding: '8px 12px' }}>
              <option value="all">All Statuses</option>
              <option value="completed">Completed</option>
              <option value="cancelled">Cancelled</option>
              <option value="requested">Requested</option>
              <option value="rideStarted">In Progress</option>
            </select>
          </div>
        </div>
      </div>

      {error && <p className="field__error" style={{ marginBottom: 'var(--space-4)' }}>{error}</p>}

      {loading && rides.length === 0 ? (
        <div className="card" style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          {[1, 2, 3, 4].map(idx => (
            <div key={idx} className="skeleton-row shimmer" style={{ height: 62 }} />
          ))}
        </div>
      ) : filteredRides.length === 0 ? (
        <div className="card">
          <div className="empty-state">
            <svg className="empty-state__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <rect x="1" y="3" width="15" height="13" rx="2" ry="2" />
              <polygon points="16 8 20 8 23 11 23 16 16 16 16 8" />
              <circle cx="5.5" cy="18.5" r="2.5" />
              <circle cx="18.5" cy="18.5" r="2.5" />
            </svg>
            <h4 style={{ margin: 0 }}>No rides logged</h4>
            <p className="muted" style={{ margin: 0, fontSize: '0.85rem' }}>Either Firestore has no records or no rides matched your active filter.</p>
          </div>
        </div>
      ) : (
        <div className="table-wrapper">
          <table className="table-premium">
            <thead>
              <tr>
                <th>Ride ID</th>
                <th>Route</th>
                <th>Users Involved</th>
                <th>Price & Fare</th>
                <th>Date / Time</th>
                <th>Status</th>
              </tr>
            </thead>
            <tbody>
              {filteredRides.map((r) => (
                <tr key={r.id}>
                  <td>
                    <code style={{ fontSize: '0.85rem', fontWeight: 600 }}>{r.id.slice(0, 10)}...</code>
                  </td>
                  <td>
                    <div>
                      <div style={{ fontWeight: 600 }}>{r.pickupLabel}</div>
                      <div style={{ fontSize: '0.75rem', color: 'var(--color-text-muted)', marginTop: 2 }}>
                        → {r.dropoffLabel}
                      </div>
                    </div>
                  </td>
                  <td>
                    <div style={{ fontSize: '0.825rem' }}>
                      <div>Rider: <b>{r.customerName || '—'}</b></div>
                      <div style={{ color: 'var(--color-text-muted)', fontSize: '0.75rem', marginTop: 2 }}>
                        Driver: {r.driverName || '—'}
                      </div>
                    </div>
                  </td>
                  <td>
                    <div>
                      <span style={{ fontWeight: 700, color: 'var(--color-primary-active)' }}>
                        ₦{r.finalFare.toLocaleString('en-NG')}
                      </span>
                      <div style={{ fontSize: '0.7rem', color: 'var(--color-text-muted)' }}>
                        {r.paymentMethod}
                      </div>
                    </div>
                  </td>
                  <td style={{ fontSize: '0.8rem', color: 'var(--color-text-muted)' }}>
                    {r.updatedAt ? r.updatedAt.toLocaleString('en-NG') : '—'}
                  </td>
                  <td>
                    <span className={`badge badge--${badgeTone(r.status)}`}>
                      {r.status}
                    </span>
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
