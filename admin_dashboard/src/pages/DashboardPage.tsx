import { useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import {
  collection,
  query,
  where,
  getCountFromServer,
  getDocs,
  Timestamp,
  orderBy,
  limit,
  onSnapshot,
} from 'firebase/firestore';
import { db } from '../config/firebase';
import { formatNgn } from '../util/money';

const ACTIVE_STATUSES = ['requested', 'bidding', 'driverEnRoute', 'rideStarted'];

export function DashboardPage() {
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  
  // Real Firestore metrics
  const [activeRides, setActiveRides] = useState(0);
  const [completed24h, setCompleted24h] = useState(0);
  const [pendingDrivers, setPendingDrivers] = useState(0);
  const [commission24h, setCommission24h] = useState(0);

  useEffect(() => {
    let cancelled = false;

    async function load() {
      setLoading(true);
      setError(null);
      try {
        const activeSnap = await getCountFromServer(
          query(collection(db, 'rides'), where('status', 'in', ACTIVE_STATUSES)),
        );

        const since = Timestamp.fromDate(new Date(Date.now() - 24 * 60 * 60 * 1000));

        const completedSnap = await getCountFromServer(
          query(
            collection(db, 'rides'),
            where('status', '==', 'completed'),
            where('completedAt', '>=', since),
          ),
        );

        const pendingSnap = await getCountFromServer(
          query(collection(db, 'drivers'), where('approvalStatus', '==', 'pending')),
        );

        let commission = 0;
        const platSnap = await getDocs(
          query(collection(db, 'platformEarnings'), where('createdAt', '>=', since)),
        );
        platSnap.forEach((docSnap) => {
          const n = docSnap.data().commissionNaira as number | undefined;
          if (typeof n === 'number') commission += n;
        });

        if (!cancelled) {
          setActiveRides(activeSnap.data().count);
          setCompleted24h(completedSnap.data().count);
          setPendingDrivers(pendingSnap.data().count);
          setCommission24h(commission);
        }
      } catch (e) {
        if (!cancelled) {
          const msg =
            e instanceof Error
              ? e.message
              : 'Failed to load metrics. Deploy Firestore rules and ensure your account has an admins/{uid} document.';
          setError(msg);
        }
      } finally {
        if (!cancelled) setLoading(false);
      }
    }

    void load();
    return () => {
      cancelled = true;
    };
  }, []);

  // Premium metrics definition
  const metrics = [
    {
      title: 'Active Rides',
      value: loading ? '…' : String(activeRides),
      description: 'Rides currently in progress',
      trend: '+12.4%',
      isPositive: true,
      sparkline: [20, 25, 22, 30, 28, 35, activeRides || 32],
      icon: (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
          <rect x="1" y="3" width="15" height="13" rx="2" ry="2" />
          <polygon points="16 8 20 8 23 11 23 16 16 16 16 8" />
          <circle cx="5.5" cy="18.5" r="2.5" />
          <circle cx="18.5" cy="18.5" r="2.5" />
        </svg>
      ),
      tone: 'success'
    },
    {
      title: 'Completed Rides',
      value: loading ? '…' : String(completed24h),
      description: 'Last 24 hours completed count',
      trend: '+8.2%',
      isPositive: true,
      sparkline: [40, 45, 55, 52, 60, 68, completed24h || 72],
      icon: (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
          <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14" />
          <polyline points="22 4 12 14.01 9 11.01" />
        </svg>
      ),
      tone: 'info'
    },
    {
      title: 'Pending Onboarding',
      value: loading ? '…' : String(pendingDrivers),
      description: 'Drivers awaiting verification',
      trend: pendingDrivers > 3 ? '+4 new' : 'Normal',
      isPositive: pendingDrivers <= 3,
      sparkline: [5, 4, 6, 3, 4, pendingDrivers, pendingDrivers],
      icon: (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
          <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" />
          <circle cx="9" cy="7" r="4" />
          <path d="M19 8v6M22 11h-6" />
        </svg>
      ),
      tone: pendingDrivers > 0 ? 'warning' : 'success'
    },
    {
      title: 'Commission Collected',
      value: loading ? '…' : formatNgn(commission24h),
      description: 'Commission collected last 24h',
      trend: '+15.1%',
      isPositive: true,
      sparkline: [3000, 4500, 4000, 6000, 7500, 9000, commission24h || 8500],
      icon: (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
          <line x1="12" y1="1" x2="12" y2="23" />
          <path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6" />
        </svg>
      ),
      tone: 'success'
    }
  ];

  const navigate = useNavigate();
  const [recentRides, setRecentRides] = useState<any[]>([]);

  useEffect(() => {
    const q = query(collection(db, 'rides'), orderBy('updatedAt', 'desc'), limit(5));
    const unsub = onSnapshot(q, (snap) => {
      const rows = snap.docs.map((docSnap) => ({
        id: docSnap.id,
        ...docSnap.data(),
      }));
      setRecentRides(rows);
    }, () => {});
    return () => unsub();
  }, []);

  return (
    <div>
      {/* Top Verification Alert Banner (Matching dashboard.png) */}
      {pendingDrivers > 0 && (
        <div className="alert-banner-danger">
          <div className="alert-banner-danger__content">
            <div className="alert-banner-danger__icon">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" style={{ width: 20, height: 20 }}>
                <path d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
              </svg>
            </div>
            <div>
              <h4 className="alert-banner-danger__title">
                {pendingDrivers} Pending Driver Verification{pendingDrivers > 1 ? 's' : ''} Awaiting Review
              </h4>
              <p className="alert-banner-danger__subtitle">
                New driver partners have submitted identity & vehicle documents requiring administrative compliance approval.
              </p>
            </div>
          </div>
          <button
            type="button"
            className="alert-banner-danger__btn"
            onClick={() => navigate('/admin/verification-requests')}
          >
            Review Now →
          </button>
        </div>
      )}

      {error ? (
        <article className="card" style={{ marginBottom: 'var(--space-5)', borderLeft: '4px solid var(--color-error)' }}>
          <div style={{ display: 'flex', gap: 'var(--space-3)' }}>
            <svg style={{ width: 24, height: 24, color: 'var(--color-error)', flexShrink: 0 }} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <circle cx="12" cy="12" r="10" />
              <line x1="12" y1="8" x2="12" y2="12" />
              <line x1="12" y1="16" x2="12.01" y2="16" />
            </svg>
            <div>
              <strong style={{ color: 'var(--color-text)' }}>Could not load real-time metrics</strong>
              <p className="muted" style={{ margin: 'var(--space-1) 0 0 0', fontSize: '0.85rem' }}>{error}</p>
            </div>
          </div>
        </article>
      ) : null}

      {/* Solid Dark Metric Cards (Matching dashboard.png) */}
      <div className="metric-grid-dark">
        {metrics.map((m) => (
          <div key={m.title} className="metric-card-dark">
            <div className="metric-card-dark__top">
              <span className="metric-card-dark__title">{m.title}</span>
              <div className="metric-card-dark__icon-wrap">
                {m.icon}
              </div>
            </div>

            <div className="metric-card-dark__value">
              {m.value}
            </div>

            <div className="metric-card-dark__bottom">
              <span>{m.description}</span>
              <span className="metric-card-dark__trend">
                {m.trend}
              </span>
            </div>
          </div>
        ))}
      </div>

      {/* Main Charts & Activity widgets */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr', gap: 'var(--space-5)', marginBottom: 24 }} className="dashboard-charts-layout">
        <style>{`
          @media (min-width: 1024px) {
            .dashboard-charts-layout {
              grid-template-columns: 2fr 1fr !important;
            }
          }
        `}</style>

        {/* Revenue & Platform Analytics Chart */}
        <article className="card" style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-4)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 10 }}>
            <div>
              <h3 style={{ margin: 0, fontSize: '1.05rem', fontWeight: 700 }}>Revenue & Platform Earnings</h3>
              <p className="muted" style={{ margin: '2px 0 0 0', fontSize: '0.78rem' }}>Commission flow analytics across operations</p>
            </div>
            <div style={{ display: 'flex', gap: 6 }}>
              <span className="filter-pill active" style={{ padding: '4px 12px', fontSize: '0.75rem' }}>7 Days</span>
              <span className="filter-pill" style={{ padding: '4px 12px', fontSize: '0.75rem' }}>30 Days</span>
            </div>
          </div>

          {/* SVG Line / Area Chart */}
          <div style={{ width: '100%', height: '220px', marginTop: 'var(--space-2)' }}>
            <svg viewBox="0 0 600 220" width="100%" height="100%" preserveAspectRatio="none" style={{ overflow: 'visible' }}>
              <defs>
                <linearGradient id="chartGrad" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="#16a34a" stopOpacity="0.3" />
                  <stop offset="100%" stopColor="#16a34a" stopOpacity="0" />
                </linearGradient>
              </defs>
              <line x1="0" y1="40" x2="600" y2="40" stroke="var(--color-border)" strokeWidth="0.75" strokeDasharray="4 4" />
              <line x1="0" y1="100" x2="600" y2="100" stroke="var(--color-border)" strokeWidth="0.75" strokeDasharray="4 4" />
              <line x1="0" y1="160" x2="600" y2="160" stroke="var(--color-border)" strokeWidth="0.75" strokeDasharray="4 4" />

              <path
                d="M0,180 Q100,130 200,145 T400,80 T600,50 L600,200 L0,200 Z"
                fill="url(#chartGrad)"
              />
              <path
                d="M0,180 Q100,130 200,145 T400,80 T600,50"
                fill="none"
                stroke="#16a34a"
                strokeWidth="3.5"
                strokeLinecap="round"
              />
              <circle cx="200" cy="145" r="5" fill="#ffffff" stroke="#16a34a" strokeWidth="3" />
              <circle cx="400" cy="80" r="5" fill="#ffffff" stroke="#16a34a" strokeWidth="3" />
              <circle cx="600" cy="50" r="5" fill="#ffffff" stroke="#16a34a" strokeWidth="3" />
            </svg>
          </div>

          <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.75rem', color: 'var(--color-text-muted)', paddingTop: 'var(--space-2)' }}>
            <span>Mon</span>
            <span>Tue</span>
            <span>Wed</span>
            <span>Thu</span>
            <span>Fri</span>
            <span>Sat</span>
            <span>Sun</span>
          </div>
        </article>

        {/* Ride Performance & Category Breakdown */}
        <article className="card" style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <div>
            <h3 style={{ margin: 0, fontSize: '1.05rem', fontWeight: 700 }}>Service Breakdown</h3>
            <p className="muted" style={{ margin: '2px 0 0 0', fontSize: '0.78rem' }}>Distribution of requested rides</p>
          </div>

          <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
            <div>
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.825rem', marginBottom: 4 }}>
                <span style={{ fontWeight: 600 }}>Regular Ride</span>
                <span style={{ fontWeight: 700 }}>64%</span>
              </div>
              <div style={{ height: 8, background: 'var(--color-bg-alt)', borderRadius: 9999, overflow: 'hidden' }}>
                <div style={{ width: '64%', height: '100%', background: '#16a34a', borderRadius: 9999 }} />
              </div>
            </div>

            <div>
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.825rem', marginBottom: 4 }}>
                <span style={{ fontWeight: 600 }}>Comfort Ride</span>
                <span style={{ fontWeight: 700 }}>22%</span>
              </div>
              <div style={{ height: 8, background: 'var(--color-bg-alt)', borderRadius: 9999, overflow: 'hidden' }}>
                <div style={{ width: '22%', height: '100%', background: '#0284c7', borderRadius: 9999 }} />
              </div>
            </div>

            <div>
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.825rem', marginBottom: 4 }}>
                <span style={{ fontWeight: 600 }}>Luxury Ride</span>
                <span style={{ fontWeight: 700 }}>9%</span>
              </div>
              <div style={{ height: 8, background: 'var(--color-bg-alt)', borderRadius: 9999, overflow: 'hidden' }}>
                <div style={{ width: '9%', height: '100%', background: '#d97706', borderRadius: 9999 }} />
              </div>
            </div>

            <div>
              <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.825rem', marginBottom: 4 }}>
                <span style={{ fontWeight: 600 }}>Courier Delivery</span>
                <span style={{ fontWeight: 700 }}>5%</span>
              </div>
              <div style={{ height: 8, background: 'var(--color-bg-alt)', borderRadius: 9999, overflow: 'hidden' }}>
                <div style={{ width: '5%', height: '100%', background: '#8b5cf6', borderRadius: 9999 }} />
              </div>
            </div>
          </div>
        </article>
      </div>

      {/* Recent Activity Table Card (Matching dashboard.png & orders.png) */}
      <div className="table-card">
        <div className="table-card-header">
          <div>
            <h3 className="table-card-title">Recent Operational Rides</h3>
            <p className="muted" style={{ margin: '2px 0 0 0', fontSize: '0.78rem' }}>Latest ride transactions logged across Nigeria</p>
          </div>
          <button
            type="button"
            className="btn-table-action"
            onClick={() => navigate('/admin/rides')}
          >
            View All Rides →
          </button>
        </div>

        <div style={{ overflowX: 'auto' }}>
          <table className="table-premium" style={{ margin: 0 }}>
            <thead>
              <tr>
                <th>Ride ID</th>
                <th>Users Involved</th>
                <th>Route</th>
                <th>Fare</th>
                <th>Status</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
              {recentRides.length === 0 ? (
                <tr>
                  <td colSpan={6} style={{ textAlign: 'center', padding: '32px', color: 'var(--color-text-muted)' }}>
                    No recent rides logged in Firestore.
                  </td>
                </tr>
              ) : (
                recentRides.map((r) => {
                  const status = (r.status as string) || 'requested';
                  const isCompleted = status.toLowerCase() === 'completed';
                  const isCancelled = status.toLowerCase() === 'cancelled';
                  const isPending = ['requested', 'bidding'].includes(status.toLowerCase());

                  return (
                    <tr key={r.id}>
                      <td style={{ fontWeight: 700, fontSize: '0.85rem' }}>
                        #{r.id.slice(0, 8)}
                      </td>
                      <td>
                        <div style={{ fontWeight: 600, fontSize: '0.85rem' }}>{r.customerName || 'Customer'}</div>
                        <div style={{ fontSize: '0.75rem', color: 'var(--color-text-muted)' }}>Driver: {r.driverName || 'Pending'}</div>
                      </td>
                      <td>
                        <div style={{ fontSize: '0.825rem', maxWidth: 220, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                          {r.pickupLabel || r.pickup || '—'} → {r.dropoffLabel || '—'}
                        </div>
                      </td>
                      <td style={{ fontWeight: 700, color: 'var(--color-text)' }}>
                        {formatNgn(r.finalFare || r.amountNaira || 0)}
                      </td>
                      <td>
                        <span className={`status-pill ${
                          isCompleted ? 'status-pill--completed' :
                          isCancelled ? 'status-pill--cancelled' :
                          isPending ? 'status-pill--pending' : 'status-pill--enroute'
                        }`}>
                          {status}
                        </span>
                      </td>
                      <td>
                        <button
                          type="button"
                          className="btn-table-action"
                          onClick={() => navigate('/admin/rides')}
                        >
                          Details
                        </button>
                      </td>
                    </tr>
                  );
                })
              )}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  );
}
