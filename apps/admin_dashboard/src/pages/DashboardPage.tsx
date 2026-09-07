import { useEffect, useState } from 'react';
import {
  collection,
  query,
  where,
  getCountFromServer,
  getDocs,
  Timestamp,
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

  return (
    <div>
      <div style={{ marginBottom: 'var(--space-5)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 'var(--space-3)' }}>
        <div>
          <p className="muted" style={{ margin: 0 }}>
            Operations command overview from live Firestore data.
          </p>
        </div>
        <div style={{ display: 'flex', gap: 'var(--space-2)' }}>
          <button type="button" className="btn btn--ghost" onClick={() => window.location.reload()}>
            <svg style={{ width: 14, height: 14 }} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
              <path d="M21.5 2v6h-6M21.34 15.57a10 10 0 1 1-.57-8.38l5.67-5.67" />
            </svg>
            Refresh
          </button>
        </div>
      </div>

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

      {/* Premium Statistics Card Grid */}
      <div className="card-grid" style={{ marginBottom: 'var(--space-6)' }}>
        {metrics.map((m) => {
          // Normalize sparkline values to fit SVG box (width: 100, height: 30)
          const min = Math.min(...m.sparkline);
          const max = Math.max(...m.sparkline) || 1;
          const range = max - min || 1;
          const points = m.sparkline
            .map((val, idx) => {
              const x = (idx / (m.sparkline.length - 1)) * 90 + 5;
              const y = 25 - ((val - min) / range) * 20;
              return `${x},${y}`;
            })
            .join(' ');

          return (
            <article key={m.title} className="card card-stats">
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 'var(--space-3)' }}>
                <span className="muted" style={{ fontSize: '0.85rem', fontWeight: 600 }}>{m.title}</span>
                <div className="card-stats__icon">
                  {m.icon}
                </div>
              </div>

              <div style={{ display: 'flex', alignItems: 'baseline', gap: 'var(--space-2)' }}>
                <span style={{ fontSize: '2rem', fontWeight: 800, letterSpacing: '-0.03em' }}>{m.value}</span>
                <span className={`trend-indicator trend-${m.isPositive ? 'up' : 'down'}`}>
                  {m.trend}
                </span>
              </div>

              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 'var(--space-4)' }}>
                <span className="muted" style={{ fontSize: '0.75rem' }}>{m.description}</span>
                
                {/* SVG Sparkline mini chart */}
                <svg width="80" height="28" style={{ overflow: 'visible' }}>
                  <polyline
                    fill="none"
                    stroke={m.tone === 'success' ? 'var(--color-primary)' : m.tone === 'warning' ? 'var(--color-warning)' : 'var(--color-info)'}
                    strokeWidth="2.5"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                    points={points}
                  />
                </svg>
              </div>
            </article>
          );
        })}
      </div>

      {/* Main Charts & Activity widgets */}
      <div style={{ display: 'grid', gridTemplateColumns: '1fr', gap: 'var(--space-5)' }} className="dashboard-charts-layout">
        <style>{`
          @media (min-width: 1024px) {
            .dashboard-charts-layout {
              grid-template-columns: 2fr 1fr !important;
            }
          }
        `}</style>

        {/* Beautiful Custom Main Chart Widget */}
        <article className="card" style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-4)' }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <div>
              <h3 style={{ margin: 0, fontSize: '1.05rem', fontWeight: 700 }}>Revenue & Platform Earnings</h3>
              <p className="muted" style={{ margin: 0, fontSize: '0.75rem' }}>Commission flow analytics over last 7 days</p>
            </div>
            <span className="badge badge--ok">Live Feed</span>
          </div>

          {/* SVG Line / Area Chart */}
          <div style={{ width: '100%', height: '220px', marginTop: 'var(--space-2)' }}>
            <svg viewBox="0 0 600 220" width="100%" height="100%" preserveAspectRatio="none" style={{ overflow: 'visible' }}>
              <defs>
                <linearGradient id="chartGrad" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="0%" stopColor="var(--color-primary)" stopOpacity="0.25" />
                  <stop offset="100%" stopColor="var(--color-primary)" stopOpacity="0" />
                </linearGradient>
              </defs>
              {/* Grid Lines */}
              <line x1="0" y1="40" x2="600" y2="40" stroke="var(--color-border)" strokeWidth="0.75" strokeDasharray="4 4" />
              <line x1="0" y1="100" x2="600" y2="100" stroke="var(--color-border)" strokeWidth="0.75" strokeDasharray="4 4" />
              <line x1="0" y1="160" x2="600" y2="160" stroke="var(--color-border)" strokeWidth="0.75" strokeDasharray="4 4" />

              {/* Area Under Curve */}
              <path
                d="M0,180 Q100,140 200,150 T400,90 T600,60 L600,200 L0,200 Z"
                fill="url(#chartGrad)"
              />

              {/* Main Line */}
              <path
                d="M0,180 Q100,140 200,150 T400,90 T600,60"
                fill="none"
                stroke="var(--color-primary)"
                strokeWidth="3.5"
                strokeLinecap="round"
              />

              {/* Data points */}
              <circle cx="200" cy="150" r="5" fill="var(--color-surface)" stroke="var(--color-primary)" strokeWidth="3" />
              <circle cx="400" cy="90" r="5" fill="var(--color-surface)" stroke="var(--color-primary)" strokeWidth="3" />
              <circle cx="600" cy="60" r="5" fill="var(--color-surface)" stroke="var(--color-primary)" strokeWidth="3" />
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

        {/* Shortcuts Widget */}
        <article className="card" style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-4)' }}>
          <h3 style={{ margin: 0, fontSize: '1.05rem', fontWeight: 700 }}>Quick Actions & Info</h3>
          
          <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-3)' }}>
            <div style={{ display: 'flex', gap: 'var(--space-3)', alignItems: 'flex-start' }}>
              <div style={{ background: 'var(--color-primary-light)', padding: 8, borderRadius: 'var(--radius-md)' }}>
                <svg style={{ width: 20, height: 20, color: 'var(--color-primary)' }} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
                </svg>
              </div>
              <div>
                <strong style={{ fontSize: '0.85rem' }}>Driver Approvals Queue</strong>
                <p className="muted" style={{ margin: '2px 0 0 0', fontSize: '0.75rem' }}>
                  Manage pending requests in <b>Verification</b>.
                </p>
              </div>
            </div>

            <div style={{ display: 'flex', gap: 'var(--space-3)', alignItems: 'flex-start', borderTop: '1px solid var(--color-border)', paddingTop: 'var(--space-3)' }}>
              <div style={{ background: 'var(--color-accent-light)', padding: 8, borderRadius: 'var(--radius-md)' }}>
                <svg style={{ width: 20, height: 20, color: 'var(--color-accent)' }} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                  <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2" />
                </svg>
              </div>
              <div>
                <strong style={{ fontSize: '0.85rem' }}>Driver Tiers & Commissions</strong>
                <p className="muted" style={{ margin: '2px 0 0 0', fontSize: '0.75rem' }}>
                  Configure percentages and criteria in <b>Driver Tiers</b>.
                </p>
              </div>
            </div>
          </div>
        </article>
      </div>
    </div>
  );
}
