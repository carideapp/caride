import { useState, useEffect } from 'react';
import {
  collection,
  onSnapshot,
  query,
  orderBy,
  limit,
} from 'firebase/firestore';
import { db } from '../config/firebase';

interface RatingRow {
  rideId: string;
  driverUid: string;
  driverName: string;
  customerUid: string;
  customerName: string;
  driverRating: number;
  driverRatingComment: string;
  dropoffLabel: string;
  ratedAt: Date | null;
}

function StarRating({ rating }: { rating: number }) {
  return (
    <span style={{ display: 'inline-flex', gap: 2 }}>
      {Array.from({ length: 5 }, (_, i) => (
        <span key={i} style={{ color: i < rating ? 'var(--color-accent)' : 'var(--color-border)', fontSize: '0.95rem' }}>
          ★
        </span>
      ))}
    </span>
  );
}

function formatDate(date: Date | null): string {
  if (!date) return '—';
  const now = new Date();
  const diff = now.getTime() - date.getTime();
  const mins = Math.floor(diff / 60_000);
  const hours = Math.floor(diff / 3_600_000);
  const days = Math.floor(diff / 86_400_000);
  if (mins < 60) return `${mins}m ago`;
  if (hours < 24) return `${hours}h ago`;
  if (days === 1) return 'Yesterday';
  if (days < 7) return `${days} days ago`;
  return date.toLocaleDateString('en-NG');
}

export function DriverRatingsPage() {
  const [ratings, setRatings] = useState<RatingRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [search, setSearch] = useState('');
  const [filterStar, setFilterStar] = useState<number | null>(null);

  useEffect(() => {
    const q = query(
      collection(db, 'rides'),
      orderBy('updatedAt', 'desc'),
      limit(200)
    );

    const unsub = onSnapshot(
      q,
      (snap) => {
        const rows: RatingRow[] = snap.docs
          .map((docSnap) => {
            const d = docSnap.data();
            const ratedAtTs = d.ratedAt ?? d.updatedAt ?? null;
            return {
              rideId: docSnap.id,
              driverUid: (d.driverUid as string) || '',
              driverName: (d.driverName as string) || 'Driver',
              customerUid: (d.customerUid as string) || '',
              customerName: (d.customerName as string) || 'Passenger',
              driverRating: (d.driverRating as number) || 0,
              driverRatingComment: (d.driverRatingComment as string) || '',
              dropoffLabel: (d.dropoffLabel as string) || '',
              ratedAt: ratedAtTs?.toDate() ?? null,
            };
          })
          .filter((row) => row.driverRating > 0);

        // Sort by ratedAt descending client-side (compound index workaround)
        rows.sort((a, b) => {
          if (!a.ratedAt) return 1;
          if (!b.ratedAt) return -1;
          return b.ratedAt.getTime() - a.ratedAt.getTime();
        });
        setRatings(rows);
        setLoading(false);
      },
      (error) => {
        console.error("Firestore onSnapshot error:", error);
        setLoading(false);
      },
    );
    return () => unsub();
  }, []);

  const totalRatings = ratings.length;
  const avgRating = totalRatings > 0
    ? ratings.reduce((acc, r) => acc + r.driverRating, 0) / totalRatings
    : 0;
  const fiveStarCount = ratings.filter((r) => r.driverRating === 5).length;

  const filtered = ratings.filter((r) => {
    const matchSearch =
      !search ||
      r.driverName.toLowerCase().includes(search.toLowerCase()) ||
      r.customerName.toLowerCase().includes(search.toLowerCase()) ||
      r.dropoffLabel.toLowerCase().includes(search.toLowerCase());
    const matchStar = filterStar == null || r.driverRating === filterStar;
    return matchSearch && matchStar;
  });

  return (
    <div>
      <div style={{ marginBottom: 'var(--space-5)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 'var(--space-3)' }}>
        <p className="muted" style={{ margin: 0 }}>
          All driver ratings and customer feedback submitted by passengers.
        </p>

        {/* Search */}
        <div className="app-topbar__search">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <circle cx="11" cy="11" r="8" /><line x1="21" y1="21" x2="16.65" y2="16.65" />
          </svg>
          <input
            type="text"
            placeholder="Search driver, passenger..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
          />
        </div>
      </div>

      {/* Summary stats */}
      <div className="card-grid" style={{ marginBottom: 'var(--space-5)' }}>
        <article className="card animate-fade-in">
          <div className="muted" style={{ fontSize: '0.85rem', fontWeight: 600 }}>Total Ratings Received</div>
          <div style={{ fontSize: '2rem', fontWeight: 800, marginTop: 4, letterSpacing: '-0.02em' }}>{totalRatings}</div>
        </article>
        
        <article className="card animate-fade-in">
          <div className="muted" style={{ fontSize: '0.85rem', fontWeight: 600 }}>Average Score</div>
          <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginTop: 4 }}>
            <span style={{ fontSize: '2rem', fontWeight: 800, letterSpacing: '-0.02em' }}>
              {avgRating > 0 ? avgRating.toFixed(2) : '—'}
            </span>
            {avgRating > 0 && <StarRating rating={Math.round(avgRating)} />}
          </div>
        </article>
        
        <article className="card animate-fade-in">
          <div className="muted" style={{ fontSize: '0.85rem', fontWeight: 600 }}>5-Star Percentage</div>
          <div style={{ fontSize: '2rem', fontWeight: 800, marginTop: 4, letterSpacing: '-0.02em' }}>
            {totalRatings > 0 ? `${Math.round((fiveStarCount / totalRatings) * 100)}%` : '—'}
          </div>
          <div className="muted" style={{ fontSize: '0.75rem', marginTop: 2 }}>{fiveStarCount} perfect reviews</div>
        </article>
      </div>

      {/* Star filters bar */}
      <div style={{ display: 'flex', gap: 6, marginBottom: 'var(--space-4)', flexWrap: 'wrap', alignItems: 'center' }}>
        <span className="muted" style={{ fontSize: '0.85rem', marginRight: 8, fontWeight: 600 }}>Filter Score:</span>
        {([null, 5, 4, 3, 2, 1] as const).map((star) => (
          <button
            key={star ?? 'all'}
            type="button"
            className={`btn ${filterStar === star ? 'btn--primary' : 'btn--ghost'}`}
            style={{ padding: '6px 12px', fontSize: '0.8rem' }}
            onClick={() => setFilterStar(star)}
          >
            {star == null ? 'All Scores' : `${star} ★`}
          </button>
        ))}
      </div>

      {loading ? (
        <div className="card" style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
          {[1, 2, 3].map(i => <div key={i} className="skeleton-row shimmer" style={{ height: 60 }} />)}
        </div>
      ) : filtered.length === 0 ? (
        <div className="card">
          <div className="empty-state">
            <h4 style={{ margin: 0 }}>No matching reviews</h4>
            <p className="muted" style={{ margin: 0, fontSize: '0.85rem' }}>No passenger reviews match the active filters.</p>
          </div>
        </div>
      ) : (
        <div className="table-wrapper animate-fade-in">
          <table className="table-premium">
            <thead>
              <tr>
                <th>Driver</th>
                <th>Passenger</th>
                <th>Destination</th>
                <th>Star Review</th>
                <th style={{ textAlign: 'right' }}>Submitted</th>
              </tr>
            </thead>
            <tbody>
              {filtered.map((row) => (
                <tr key={row.rideId}>
                  <td>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                      <div className="admin-avatar" style={{ background: 'var(--color-primary-light)', color: 'var(--color-primary)', width: 32, height: 32, fontSize: '0.8rem' }}>
                        {row.driverName[0]?.toUpperCase()}
                      </div>
                      <div>
                        <div style={{ fontWeight: 700, fontSize: '0.9rem' }}>{row.driverName}</div>
                        <div className="muted" style={{ fontSize: '0.75rem' }}>{row.driverUid.slice(0, 10)}…</div>
                      </div>
                    </div>
                  </td>
                  <td>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                      <div className="admin-avatar" style={{ background: 'rgba(99,102,241,0.12)', color: '#6366f1', width: 32, height: 32, fontSize: '0.8rem' }}>
                        {row.customerName[0]?.toUpperCase()}
                      </div>
                      <div>
                        <div style={{ fontWeight: 700, fontSize: '0.9rem' }}>{row.customerName}</div>
                        <div className="muted" style={{ fontSize: '0.75rem' }}>{row.customerUid.slice(0, 10)}…</div>
                      </div>
                    </div>
                  </td>
                  <td>
                    <span style={{ fontSize: '0.85rem' }}>{row.dropoffLabel || '—'}</span>
                  </td>
                  <td>
                    <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                      <strong style={{ fontSize: '0.9rem' }}>{row.driverRating}</strong>
                      <StarRating rating={row.driverRating} />
                    </div>
                    {row.driverRatingComment && (
                      <div className="muted" style={{ fontSize: '0.75rem', marginTop: 4, fontStyle: 'italic', maxWidth: '250px', whiteSpace: 'normal', wordBreak: 'break-word' }}>
                        "{row.driverRatingComment}"
                      </div>
                    )}
                  </td>
                  <td style={{ textAlign: 'right', fontSize: '0.8rem', color: 'var(--color-text-muted)' }}>
                    {formatDate(row.ratedAt)}
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
