import { useEffect, useState } from 'react';
import {
  collection,
  onSnapshot,
  orderBy,
  query,
  where,
  type QuerySnapshot,
  type DocumentData,
} from 'firebase/firestore';
import { auth, db } from '../config/firebase';

interface PendingDriver {
  uid: string;
  email: string;
  fullName: string;
  createdAt: Date | null;
}

export function FraudPage() {
  const [pending, setPending] = useState<PendingDriver[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (!auth.currentUser) {
      setLoading(false);
      return;
    }

    const q = query(
      collection(db, 'drivers'),
      where('approvalStatus', '==', 'pending'),
      orderBy('createdAt', 'desc'),
    );

    const unsub = onSnapshot(
      q,
      (snap: QuerySnapshot<DocumentData>) => {
        const rows: PendingDriver[] = snap.docs.map((docSnap) => {
          const d = docSnap.data();
          const createdAt = (d.createdAt as { toDate?: () => Date } | undefined)?.toDate?.() ?? null;
          return {
            uid: docSnap.id,
            email: (d.email as string) || '',
            fullName: (d.fullName as string) || '',
            createdAt,
          };
        });
        setPending(rows);
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

  return (
    <div>
      <div style={{ marginBottom: 'var(--space-5)' }}>
        <p className="muted" style={{ margin: 0 }}>
          Review pending driver applications, monitor suspicious transaction flags, and manage safety alerts.
        </p>
      </div>

      {error && <p className="field__error" style={{ marginBottom: 'var(--space-4)' }}>{error}</p>}

      <div style={{ display: 'grid', gridTemplateColumns: '1fr', gap: 'var(--space-5)' }} className="fraud-grid">
        <style>{`
          @media (min-width: 900px) {
            .fraud-grid {
              grid-template-columns: 1.5fr 1fr !important;
            }
          }
        `}</style>

        {/* Pending driver applications list */}
        <div>
          <h3 style={{ fontSize: '1.05rem', fontWeight: 700, marginBottom: 'var(--space-3)' }}>
            Applications under review ({pending.length})
          </h3>
          
          {loading && pending.length === 0 ? (
            <div className="card" style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              {[1, 2].map(i => <div key={i} className="skeleton-row shimmer" style={{ height: 60 }} />)}
            </div>
          ) : pending.length === 0 ? (
            <article className="card">
              <p className="muted" style={{ marginBottom: 0 }}>
                No pending driver applications found in review.
              </p>
            </article>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-3)' }}>
              {pending.map((d) => (
                <article key={d.uid} className="card">
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: 12 }}>
                    <div>
                      <div style={{ fontWeight: 700, fontSize: '0.95rem' }}>{d.fullName || '(no name)'}</div>
                      <div className="muted" style={{ fontSize: '0.8rem', marginTop: 2 }}>{d.email}</div>
                      <div className="muted" style={{ fontSize: '0.75rem', marginTop: 4 }}>
                        UID: <code style={{ fontSize: '0.75rem' }}>{d.uid}</code>
                        {d.createdAt ? ` · Applied ${d.createdAt.toLocaleString('en-NG')}` : ''}
                      </div>
                    </div>
                    <span className="badge badge--warn">Pending Review</span>
                  </div>
                  <div style={{ marginTop: 'var(--space-4)' }}>
                    <button type="button" className="btn btn--ghost" style={{ padding: '6px 12px', fontSize: '0.8rem' }} disabled>
                      Review specifications
                    </button>
                  </div>
                </article>
              ))}
            </div>
          )}
        </div>

        {/* Automated Alert panel */}
        <div>
          <h3 style={{ fontSize: '1.05rem', fontWeight: 700, marginBottom: 'var(--space-3)' }}>
            Automated Signals
          </h3>
          <article className="card" style={{ borderLeft: '4px solid var(--color-accent)' }}>
            <div style={{ display: 'flex', gap: 12, alignItems: 'flex-start' }}>
              <svg style={{ width: 24, height: 24, color: 'var(--color-accent)', flexShrink: 0 }} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z" />
                <line x1="12" y1="9" x2="12" y2="13" /><line x1="12" y1="17" x2="12.01" y2="17" />
              </svg>
              <div>
                <strong style={{ fontSize: '0.9rem' }}>No telemetry alerts</strong>
                <p className="muted" style={{ margin: '4px 0 0 0', fontSize: '0.85rem' }}>
                  Signals are normal. Cloud Functions can evaluate transaction velocities and publish to <code>adminAlerts</code> when rules trigger.
                </p>
              </div>
            </div>
          </article>
        </div>
      </div>
    </div>
  );
}
