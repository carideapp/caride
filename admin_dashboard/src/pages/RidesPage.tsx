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
    if (filterStatus === 'inprogress') {
      return matchesSearch && ['driverenroute', 'ridestarted', 'bidding', 'requested'].includes(r.status.toLowerCase());
    }
    return matchesSearch && r.status.toLowerCase() === filterStatus.toLowerCase();
  });

  const totalCompleted = rides.filter(r => r.status.toLowerCase() === 'completed').length;
  const totalInProgress = rides.filter(r => ['driverenroute', 'ridestarted', 'bidding', 'requested'].includes(r.status.toLowerCase())).length;
  const totalCancelled = rides.filter(r => r.status.toLowerCase() === 'cancelled').length;

  return (
    <div>
      {/* Top Filter Toolbar (Matching orders.png) */}
      <div className="filter-toolbar">
        <div className="filter-toolbar__group">
          <div className="search-pill-wrap">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <circle cx="11" cy="11" r="8" /><line x1="21" y1="21" x2="16.65" y2="16.65" />
            </svg>
            <input 
              type="text" 
              placeholder="Search rider, driver, route, ID..." 
              value={searchTerm} 
              onChange={e => setSearchTerm(e.target.value)} 
            />
          </div>

          <div className="filter-pill">
            <svg style={{ width: 14, height: 14 }} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <rect x="3" y="4" width="18" height="18" rx="2" ry="2" />
              <line x1="16" y1="2" x2="16" y2="6" />
              <line x1="8" y1="2" x2="8" y2="6" />
              <line x1="3" y1="10" x2="21" y2="10" />
            </svg>
            <span>All Time</span>
          </div>
        </div>

        <div className="filter-toolbar__group">
          <button
            type="button"
            className="filter-pill"
            onClick={() => {
              const csvContent = "data:text/csv;charset=utf-8," 
                + ["RideID,Customer,Driver,Pickup,Dropoff,Fare,Status,Date"].join(",") + "\n"
                + filteredRides.map(r => `"${r.id}","${r.customerName}","${r.driverName}","${r.pickupLabel}","${r.dropoffLabel}","${r.finalFare}","${r.status}","${r.updatedAt?.toISOString() || ''}"`).join("\n");
              const encodedUri = encodeURI(csvContent);
              const link = document.createElement("a");
              link.setAttribute("href", encodedUri);
              link.setAttribute("download", `caride_rides_${Date.now()}.csv`);
              document.body.appendChild(link);
              link.click();
              document.body.removeChild(link);
            }}
          >
            <svg style={{ width: 14, height: 14 }} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
              <polyline points="7 10 12 15 17 10" />
              <line x1="12" y1="15" x2="12" y2="3" />
            </svg>
            <span>Export CSV</span>
          </button>
        </div>
      </div>

      {/* 4 Summary Stat Cards (Matching orders.png) */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 16, marginBottom: 24 }}>
        <div className="card" style={{ padding: 20 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span className="muted" style={{ fontSize: '0.825rem', fontWeight: 600 }}>Total Logged</span>
            <div style={{ width: 34, height: 34, borderRadius: '50%', background: 'rgba(22, 163, 74, 0.12)', color: '#16a34a', display: 'grid', placeItems: 'center' }}>
              <svg style={{ width: 18, height: 18 }} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <rect x="1" y="3" width="15" height="13" rx="2" ry="2" />
                <polygon points="16 8 20 8 23 11 23 16 16 16 16 8" />
                <circle cx="5.5" cy="18.5" r="2.5" />
                <circle cx="18.5" cy="18.5" r="2.5" />
              </svg>
            </div>
          </div>
          <div style={{ fontSize: '1.9rem', fontWeight: 800, marginTop: 8 }}>{rides.length}</div>
          <span className="muted" style={{ fontSize: '0.75rem' }}>Recent ride records</span>
        </div>

        <div className="card" style={{ padding: 20 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span className="muted" style={{ fontSize: '0.825rem', fontWeight: 600 }}>Completed</span>
            <div style={{ width: 34, height: 34, borderRadius: '50%', background: '#DCFCE7', color: '#15803D', display: 'grid', placeItems: 'center' }}>
              <svg style={{ width: 18, height: 18 }} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <polyline points="20 6 9 17 4 12" />
              </svg>
            </div>
          </div>
          <div style={{ fontSize: '1.9rem', fontWeight: 800, marginTop: 8 }}>{totalCompleted}</div>
          <span className="muted" style={{ fontSize: '0.75rem' }}>Successfully delivered</span>
        </div>

        <div className="card" style={{ padding: 20 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span className="muted" style={{ fontSize: '0.825rem', fontWeight: 600 }}>In Progress</span>
            <div style={{ width: 34, height: 34, borderRadius: '50%', background: '#E0F2FE', color: '#0369A1', display: 'grid', placeItems: 'center' }}>
              <svg style={{ width: 18, height: 18 }} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <circle cx="12" cy="12" r="10" />
                <polyline points="12 6 12 12 16 14" />
              </svg>
            </div>
          </div>
          <div style={{ fontSize: '1.9rem', fontWeight: 800, marginTop: 8 }}>{totalInProgress}</div>
          <span className="muted" style={{ fontSize: '0.75rem' }}>Active or en route</span>
        </div>

        <div className="card" style={{ padding: 20 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span className="muted" style={{ fontSize: '0.825rem', fontWeight: 600 }}>Cancelled</span>
            <div style={{ width: 34, height: 34, borderRadius: '50%', background: '#FEE2E2', color: '#B91C1C', display: 'grid', placeItems: 'center' }}>
              <svg style={{ width: 18, height: 18 }} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <line x1="18" y1="6" x2="6" y2="18" />
                <line x1="6" y1="6" x2="18" y2="18" />
              </svg>
            </div>
          </div>
          <div style={{ fontSize: '1.9rem', fontWeight: 800, marginTop: 8 }}>{totalCancelled}</div>
          <span className="muted" style={{ fontSize: '0.75rem' }}>Terminated by parties</span>
        </div>
      </div>

      {/* Underline Tabs (Matching orders (1).png) */}
      <div className="tab-bar-underline">
        <button
          type="button"
          className={`tab-btn-underline ${filterStatus === 'all' ? 'active' : ''}`}
          onClick={() => setFilterStatus('all')}
        >
          <span>All Rides</span>
          <span className="tab-count-badge">{rides.length}</span>
        </button>
        <button
          type="button"
          className={`tab-btn-underline ${filterStatus === 'completed' ? 'active' : ''}`}
          onClick={() => setFilterStatus('completed')}
        >
          <span>Completed</span>
          <span className="tab-count-badge">{totalCompleted}</span>
        </button>
        <button
          type="button"
          className={`tab-btn-underline ${filterStatus === 'inprogress' ? 'active' : ''}`}
          onClick={() => setFilterStatus('inprogress')}
        >
          <span>In Progress</span>
          <span className="tab-count-badge">{totalInProgress}</span>
        </button>
        <button
          type="button"
          className={`tab-btn-underline ${filterStatus === 'cancelled' ? 'active' : ''}`}
          onClick={() => setFilterStatus('cancelled')}
        >
          <span>Cancelled</span>
          <span className="tab-count-badge">{totalCancelled}</span>
        </button>
      </div>

      {error && <p className="field__error" style={{ marginBottom: 'var(--space-4)' }}>{error}</p>}

      {/* Table Card (Matching orders (1).png) */}
      <div className="table-card">
        {loading && rides.length === 0 ? (
          <div style={{ display: 'flex', flexDirection: 'column', gap: 16, padding: 24 }}>
            {[1, 2, 3, 4].map(idx => (
              <div key={idx} className="skeleton-row shimmer" style={{ height: 50 }} />
            ))}
          </div>
        ) : filteredRides.length === 0 ? (
          <div className="empty-state">
            <svg className="empty-state__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <rect x="1" y="3" width="15" height="13" rx="2" ry="2" />
              <polygon points="16 8 20 8 23 11 23 16 16 16 16 8" />
              <circle cx="5.5" cy="18.5" r="2.5" />
              <circle cx="18.5" cy="18.5" r="2.5" />
            </svg>
            <h4 style={{ margin: 0 }}>No matching rides</h4>
            <p className="muted" style={{ margin: 0, fontSize: '0.85rem' }}>No ride records matched your search query or selected tab filter.</p>
          </div>
        ) : (
          <div style={{ overflowX: 'auto' }}>
            <table className="table-premium" style={{ margin: 0 }}>
              <thead>
                <tr>
                  <th>Order / Ride ID</th>
                  <th>Customer & Driver</th>
                  <th>Pickup & Destination</th>
                  <th>Fare & Payment</th>
                  <th>Timestamp</th>
                  <th>Status</th>
                  <th style={{ textAlign: 'right' }}>Action</th>
                </tr>
              </thead>
              <tbody>
                {filteredRides.map((r) => {
                  const status = r.status.toLowerCase();
                  const isCompleted = status === 'completed';
                  const isCancelled = status === 'cancelled';
                  const isPending = ['requested', 'bidding'].includes(status);

                  return (
                    <tr key={r.id}>
                      <td>
                        <div style={{ display: 'flex', alignItems: 'center', gap: 6 }}>
                          <span className="uid-pill">#{r.id.slice(0, 8)}</span>
                        </div>
                        <span style={{ fontSize: '0.72rem', color: 'var(--color-text-muted)', display: 'block', marginTop: 4 }}>
                          CaRide Dispatch
                        </span>
                      </td>
                      <td>
                        <div className="table-entity-cell">
                          <div className="table-avatar table-avatar--circle">
                            {(r.customerName || 'C')[0].toUpperCase()}
                          </div>
                          <div>
                            <div className="table-entity-title">{r.customerName || 'Customer'}</div>
                            <div className="table-entity-sub">Driver: {r.driverName || 'Pending Assignment'}</div>
                          </div>
                        </div>
                      </td>
                      <td>
                        <div style={{ maxWidth: 240 }}>
                          <div style={{ fontWeight: 600, fontSize: '0.825rem', whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                            {r.pickupLabel}
                          </div>
                          <div style={{ fontSize: '0.75rem', color: 'var(--color-text-muted)', marginTop: 2, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>
                            → {r.dropoffLabel}
                          </div>
                        </div>
                      </td>
                      <td>
                        <div style={{ fontWeight: 800, fontSize: '0.925rem', color: '#15803d' }}>
                          ₦{r.finalFare.toLocaleString('en-NG')}
                        </div>
                        <span style={{ fontSize: '0.72rem', color: 'var(--color-text-muted)', textTransform: 'capitalize' }}>
                          {r.paymentMethod}
                        </span>
                      </td>
                      <td style={{ fontSize: '0.8rem', color: 'var(--color-text-muted)' }}>
                        {r.updatedAt ? r.updatedAt.toLocaleString('en-NG', { dateStyle: 'medium', timeStyle: 'short' }) : '—'}
                      </td>
                      <td>
                        <span className={`status-pill ${
                          isCompleted ? 'status-pill--completed' :
                          isCancelled ? 'status-pill--cancelled' :
                          isPending ? 'status-pill--pending' : 'status-pill--enroute'
                        }`}>
                          {r.status}
                        </span>
                      </td>
                      <td style={{ textAlign: 'right' }}>
                        <button
                          type="button"
                          className="btn-table-action"
                          onClick={() => alert(`Ride Details for #${r.id}\nCustomer: ${r.customerName}\nDriver: ${r.driverName}\nFare: ₦${r.finalFare}\nStatus: ${r.status}`)}
                        >
                          View Details
                        </button>
                      </td>
                    </tr>
                  );
                })}
              </tbody>
            </table>

            {/* Pagination Footer */}
            <div className="table-pagination">
              <span>Showing {filteredRides.length} of {rides.length} records</span>
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
