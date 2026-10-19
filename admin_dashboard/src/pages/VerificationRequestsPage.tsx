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
import { normalizeVehicleType, requiredDriverDocumentTypes, vehicleTypeLabel } from '../constants/driverVerification';

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
  vehicleType: string;
  operatingState?: string;
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
              const operatingState = (x.state as string | undefined) ?? (x.operatingState as string | undefined);
              const requiredDocTypes = requiredDriverDocumentTypes(vehicleType, operatingState);
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
                vehicleType,
                operatingState,
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
      {/* Top Filter & Search Toolbar */}
      <div className="filter-toolbar" style={{ marginBottom: 20 }}>
        <div className="tab-bar-underline" style={{ margin: 0, borderBottom: 'none' }}>
          <button
            type="button"
            className={`tab-btn-underline ${activeTab === 'pending' ? 'active' : ''}`}
            onClick={() => setActiveTab('pending')}
          >
            Pending Approval <span className="tab-count-badge">{pendingCount}</span>
          </button>
          <button
            type="button"
            className={`tab-btn-underline ${activeTab === 'approved' ? 'active' : ''}`}
            onClick={() => setActiveTab('approved')}
          >
            Approved <span className="tab-count-badge">{approvedCount}</span>
          </button>
          <button
            type="button"
            className={`tab-btn-underline ${activeTab === 'rejected' ? 'active' : ''}`}
            onClick={() => setActiveTab('rejected')}
          >
            Rejected <span className="tab-count-badge">{rejectedCount}</span>
          </button>
          <button
            type="button"
            className={`tab-btn-underline ${activeTab === 'all' ? 'active' : ''}`}
            onClick={() => setActiveTab('all')}
          >
            All <span className="tab-count-badge">{allCount}</span>
          </button>
        </div>

        <div style={{ display: 'flex', gap: 12, alignItems: 'center', flexWrap: 'wrap' }}>
          <div className="search-pill-wrap">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <circle cx="11" cy="11" r="8" /><line x1="21" y1="21" x2="16.65" y2="16.65" />
            </svg>
            <input 
              type="text" 
              placeholder="Search driver candidates..." 
              value={searchTerm} 
              onChange={e => setSearchTerm(e.target.value)} 
            />
          </div>
        </div>
      </div>

      {error && (
        <div className="alert-banner-danger" style={{ marginBottom: 20 }}>
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <circle cx="12" cy="12" r="10" /><line x1="12" y1="8" x2="12" y2="12" /><line x1="12" y1="16" x2="12.01" y2="16" />
          </svg>
          <div style={{ flex: 1 }}>
            <strong>Action Required:</strong> {error}
          </div>
        </div>
      )}

      {loading && rows.length === 0 ? (
        <div className="table-card" style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 16 }}>
          {[1, 2, 3].map(idx => (
            <div key={idx} className="skeleton-row shimmer" style={{ height: 55, borderRadius: 12 }} />
          ))}
        </div>
      ) : filteredRows.length === 0 ? (
        <div className="table-card">
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
        <div className="table-card">
          <div className="table-card-header">
            <div>
              <h3 style={{ margin: 0, fontSize: '1rem', fontWeight: 700 }}>Verification Queue</h3>
              <p style={{ margin: '2px 0 0 0', fontSize: '0.8rem', color: 'var(--color-text-muted)' }}>
                Showing {filteredRows.length} applications requiring review
              </p>
            </div>
          </div>

          <div style={{ overflowX: 'auto' }}>
            <table className="table-premium">
              <thead>
                <tr>
                  <th>Driver Candidate</th>
                  <th>Applied Date</th>
                  <th>Documents Summary</th>
                  <th>Vehicle Review</th>
                  <th>Approval Status</th>
                  <th style={{ textAlign: 'right' }}>Action</th>
                </tr>
              </thead>
              <tbody>
                {filteredRows.map((r) => (
                  <tr key={r.uid}>
                    <td>
                      <div className="table-entity-cell">
                        <div className="table-avatar table-avatar--circle" style={{ background: 'rgba(59, 130, 246, 0.12)', color: '#2563eb' }}>
                          {(r.fullName || r.email || '?')[0].toUpperCase()}
                        </div>
                        <div>
                          <div className="table-entity-title">{r.fullName || '(no name)'}</div>
                          <div className="table-entity-sub">{r.email}</div>
                        </div>
                      </div>
                    </td>
                    
                    <td style={{ fontSize: '0.82rem', color: 'var(--color-text-muted)' }}>
                      {r.createdAtMs ? new Date(r.createdAtMs).toLocaleDateString('en-NG', { dateStyle: 'medium' }) : '—'}
                    </td>

                    <td>
                      <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                        <span className="status-pill status-pill--warning" style={{ fontSize: '0.72rem', padding: '3px 10px' }}>
                          Pending: {r.pendingDocsCount}
                        </span>
                        {r.rejectedDocsCount > 0 && (
                          <span className="status-pill status-pill--danger" style={{ fontSize: '0.72rem', padding: '3px 10px' }}>
                            Rejected: {r.rejectedDocsCount}
                          </span>
                        )}
                        {r.missingDocsCount > 0 && (
                          <span style={{ fontSize: '0.72rem', padding: '3px 10px', background: 'var(--color-bg-alt)', color: 'var(--color-text-muted)', borderRadius: 'var(--radius-full)', fontWeight: 600 }}>
                            Missing: {r.missingDocsCount}
                          </span>
                        )}
                      </div>
                    </td>

                    <td>
                      <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
                        <span className={`status-pill ${r.vehicleStatus === 'approved' ? 'status-pill--success' : 'status-pill--warning'}`}>
                          {r.vehicleStatus}
                        </span>
                        <span style={{ fontSize: '0.72rem', color: 'var(--color-text-muted)', fontWeight: 600 }}>
                          {r.vehicleType === 'tricycle' ? '🛺 Tricycle' : r.vehicleType === 'motorcycle' ? '🏍️ Motorcycle' : `🚗 ${vehicleTypeLabel(r.vehicleType)}`}
                          {r.operatingState ? ` • ${r.operatingState}` : ''}
                        </span>
                      </div>
                    </td>

                    <td>
                      <span className={`status-pill ${
                        r.approvalStatus === 'approved' 
                          ? 'status-pill--success' 
                          : r.approvalStatus === 'rejected' 
                          ? 'status-pill--danger' 
                          : 'status-pill--warning'
                      }`}>
                        {r.approvalStatus}
                      </span>
                    </td>

                    <td style={{ textAlign: 'right' }}>
                      <Link to={`/admin/verification-requests/${r.uid}?tab=documents`} className="btn-table-action btn-table-action--primary">
                        Review Documents →
                      </Link>
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

