import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import {
  collection,
  doc,
  getDoc,
  getDocs,
  onSnapshot,
  orderBy,
  query,
  type DocumentData,
  type QuerySnapshot,
  type Timestamp,
} from 'firebase/firestore';
import { db } from '../config/firebase';
import { normalizeVehicleType, requiredDriverDocumentTypes } from '../constants/driverVerification';

interface PendingRow {
  uid: string;
  fullName: string;
  email: string;
  approvalStatus: string;
  createdAtMs: number;
  pendingDocsCount: number;
  rejectedDocsCount: number;
  missingDocsCount: number;
  vehicleStatus: string;
}

export function VerificationRequestsPage() {
  const [rows, setRows] = useState<PendingRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [activeTab, setActiveTab] = useState<'pending' | 'approved' | 'rejected' | 'all'>('pending');

  useEffect(() => {
    const q = query(
      collection(db, 'drivers'),
      orderBy('createdAt', 'desc'),
    );
    const unsub = onSnapshot(
      q,
      async (snap: QuerySnapshot<DocumentData>) => {
        try {
          const list = await Promise.all(
            snap.docs.map(async (d) => {
              const x = d.data();
              const ts = (x.applicationSubmittedAt as Timestamp | undefined) ?? (x.createdAt as Timestamp | undefined);
              const [docsSnap, vehicleReviewSnap, vehicleInfoSnap] = await Promise.all([
                getDocs(collection(db, 'drivers', d.id, 'documents')),
                getDoc(doc(db, 'drivers', d.id, 'vehicle', 'review')),
                getDoc(doc(db, 'drivers', d.id, 'vehicle', 'info')),
               ]);
              const vehicleReview = vehicleReviewSnap.exists() ? vehicleReviewSnap.data() : null;
              const vehicleInfo = vehicleInfoSnap.exists() ? vehicleInfoSnap.data() : null;
              const vehicleType = normalizeVehicleType(
                (vehicleReview?.newValues?.vehicleType as string | undefined) ??
                  (vehicleInfo?.vehicleType as string | undefined),
              );
              const requiredDocTypes = requiredDriverDocumentTypes(vehicleType);
              const docMap = new Map(
                docsSnap.docs.map((docSnap) => [docSnap.id, docSnap.data().status as string | undefined]),
              );
              return {
                uid: d.id,
                fullName: (x.fullName as string) || '',
                email: (x.email as string) || '',
                approvalStatus: (x.approvalStatus as string) || 'pending',
                createdAtMs: ts?.toMillis?.() ?? 0,
                pendingDocsCount: requiredDocTypes.filter((typeId) => docMap.get(typeId) === 'pending').length,
                rejectedDocsCount: requiredDocTypes.filter((typeId) => docMap.get(typeId) === 'rejected').length,
                missingDocsCount: requiredDocTypes.filter((typeId) => !docMap.has(typeId)).length,
                vehicleStatus: (vehicleReview?.status as string | undefined) ?? (vehicleInfo ? 'approved' : 'not_submitted'),
              } satisfies PendingRow;
            }),
          );
          setRows(list);
          setLoading(false);
          setError(null);
        } catch (e) {
          setError(e instanceof Error ? e.message : 'Unable to load verification queue.');
          setLoading(false);
        }
      },
      (e) => {
        setError(e.message);
        setLoading(false);
      },
    );
    return () => unsub();
  }, []);

  const pendingCount = rows.filter((r) => r.approvalStatus === 'pending').length;
  const approvedCount = rows.filter((r) => r.approvalStatus === 'approved').length;
  const rejectedCount = rows.filter((r) => r.approvalStatus === 'rejected').length;
  const allCount = rows.length;

  const tabFilteredRows = rows.filter((r) => {
    if (activeTab === 'pending') return r.approvalStatus === 'pending';
    if (activeTab === 'approved') return r.approvalStatus === 'approved';
    if (activeTab === 'rejected') return r.approvalStatus === 'rejected';
    return true;
  });

  const filteredRows = tabFilteredRows.filter(r => 
    r.fullName.toLowerCase().includes(searchTerm.toLowerCase()) ||
    r.email.toLowerCase().includes(searchTerm.toLowerCase()) ||
    r.uid.toLowerCase().includes(searchTerm.toLowerCase())
  );

  return (
    <div>
      <div style={{ marginBottom: 'var(--space-4)', display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 'var(--space-3)' }}>
        <p className="muted" style={{ margin: 0 }}>
          Manage driver onboarding applications and verification request reviews.
        </p>

        {/* Search */}
        <div className="app-topbar__search">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <circle cx="11" cy="11" r="8" /><line x1="21" y1="21" x2="16.65" y2="16.65" />
          </svg>
          <input 
            type="text" 
            placeholder="Search drivers..." 
            value={searchTerm} 
            onChange={e => setSearchTerm(e.target.value)} 
          />
        </div>
      </div>

      {/* Status Filter Tabs */}
      <div className="page-tabs">
        <button
          type="button"
          className={`page-tab-btn ${activeTab === 'pending' ? 'active' : ''}`}
          onClick={() => setActiveTab('pending')}
        >
          Pending Approval <span className="tab-badge tab-badge--warn">{pendingCount}</span>
        </button>
        <button
          type="button"
          className={`page-tab-btn ${activeTab === 'approved' ? 'active' : ''}`}
          onClick={() => setActiveTab('approved')}
        >
          Approved <span className="tab-badge tab-badge--ok">{approvedCount}</span>
        </button>
        <button
          type="button"
          className={`page-tab-btn ${activeTab === 'rejected' ? 'active' : ''}`}
          onClick={() => setActiveTab('rejected')}
        >
          Rejected <span className="tab-badge tab-badge--error">{rejectedCount}</span>
        </button>
        <button
          type="button"
          className={`page-tab-btn ${activeTab === 'all' ? 'active' : ''}`}
          onClick={() => setActiveTab('all')}
        >
          All Applications <span className="tab-badge">{allCount}</span>
        </button>
      </div>

      {error && <p className="field__error" style={{ marginBottom: 'var(--space-4)' }}>{error}</p>}

      {loading && rows.length === 0 ? (
        <div className="card" style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          {[1, 2, 3].map(idx => (
            <div key={idx} className="skeleton-row shimmer" style={{ height: 60 }} />
          ))}
        </div>
      ) : filteredRows.length === 0 ? (
        <div className="card">
          <div className="empty-state">
            <svg className="empty-state__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
            </svg>
            <h4 style={{ margin: 0 }}>No applications found</h4>
            <p className="muted" style={{ margin: 0, fontSize: '0.85rem' }}>
              No drivers match the current filter state ({activeTab}).
            </p>
          </div>
        </div>
      ) : (
        <div className="table-wrapper">
          <table className="table-premium">
            <thead>
              <tr>
                <th>Driver Candidate</th>
                <th>Applied Date</th>
                <th>Documents Summary</th>
                <th>Vehicle Review</th>
                <th>Status</th>
                <th>Action</th>
              </tr>
            </thead>
            <tbody>
              {filteredRows.map((r) => (
                <tr key={r.uid}>
                  <td>
                    <div>
                      <div style={{ fontWeight: 600 }}>{r.fullName || '(no name)'}</div>
                      <div className="muted" style={{ fontSize: '0.75rem', marginTop: 2 }}>{r.email}</div>
                    </div>
                  </td>
                  
                  <td style={{ fontSize: '0.8rem', color: 'var(--color-text-muted)' }}>
                    {r.createdAtMs ? new Date(r.createdAtMs).toLocaleString('en-NG') : '—'}
                  </td>

                  <td>
                    <div style={{ display: 'flex', gap: 8, flexWrap: 'wrap' }}>
                      <span className="badge badge--warn" style={{ fontSize: '0.7rem' }}>Pending: {r.pendingDocsCount}</span>
                      {r.rejectedDocsCount > 0 && <span className="badge badge--error" style={{ fontSize: '0.7rem' }}>Rejected: {r.rejectedDocsCount}</span>}
                      {r.missingDocsCount > 0 && <span className="badge" style={{ fontSize: '0.7rem', background: 'var(--color-bg-alt)', color: 'var(--color-text-muted)' }}>Missing: {r.missingDocsCount}</span>}
                    </div>
                  </td>

                  <td>
                    <span className={`badge badge--${r.vehicleStatus === 'approved' ? 'ok' : 'warn'}`}>
                      {r.vehicleStatus}
                    </span>
                  </td>

                  <td>
                    <span className={`badge badge--${r.approvalStatus === 'approved' ? 'ok' : r.approvalStatus === 'rejected' ? 'error' : 'warn'}`}>
                      {r.approvalStatus}
                    </span>
                  </td>

                  <td>
                    <Link to={`/admin/verification-requests/${r.uid}`} className="btn btn--primary" style={{ padding: '4px 12px', fontSize: '0.8rem', textDecoration: 'none' }}>
                      Review Driver
                    </Link>
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

