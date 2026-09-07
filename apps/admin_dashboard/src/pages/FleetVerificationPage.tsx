import { useEffect, useState } from 'react';
import {
  collection,
  doc,
  onSnapshot,
  orderBy,
  query,
  updateDoc,
  serverTimestamp,
  type DocumentData,
  type QuerySnapshot,
  type Timestamp,
} from 'firebase/firestore';
import { db } from '../config/firebase';

interface FleetPartnerRow {
  fleetId: string;
  ownerUid: string;
  businessName: string;
  fullName: string;
  phone: string;
  email: string;
  businessType: 'individual' | 'company' | string;
  registrationNumber: string;
  address: string;
  state: string;
  operatingStates: string[];
  gender?: string;
  profilePictureUrl?: string;
  logoUrl?: string;
  identityDocumentType?: string;
  identityDocumentUrl?: string;
  cacDocumentUrl?: string;
  verificationStatus: 'pending' | 'approved' | 'rejected' | string;
  isVerified: boolean;
  rejectionReason?: string;
  createdAtMs: number;
  updatedAtMs: number;
}

export function FleetVerificationPage() {
  const [rows, setRows] = useState<FleetPartnerRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [activeTab, setActiveTab] = useState<'pending' | 'approved' | 'rejected' | 'all'>('pending');
  const [entityFilter, setEntityFilter] = useState<'all' | 'individual' | 'company'>('all');

  // Modal / Review drawer state
  const [selectedFleet, setSelectedFleet] = useState<FleetPartnerRow | null>(null);
  const [rejectionReasonInput, setRejectionReasonInput] = useState('');
  const [showRejectForm, setShowRejectForm] = useState(false);
  const [processing, setProcessing] = useState(false);
  const [actionSuccess, setActionSuccess] = useState<string | null>(null);
  const [previewImage, setPreviewImage] = useState<{ url: string; title: string } | null>(null);

  useEffect(() => {
    const q = query(collection(db, 'fleets'), orderBy('updatedAt', 'desc'));
    const unsub = onSnapshot(
      q,
      (snap: QuerySnapshot<DocumentData>) => {
        try {
          const list: FleetPartnerRow[] = snap.docs.map((d) => {
            const data = d.data();
            const createdTs = data.createdAt as Timestamp | undefined;
            const updatedTs = data.updatedAt as Timestamp | undefined;
            const rawStates = (data.operatingStates as string[]) ||
              (data.operatingCities as string[]) ||
              (data.state ? [data.state] : (data.city ? [data.city] : ['FCT (Abuja)']));

            return {
              fleetId: d.id,
              ownerUid: (data.ownerUid as string) || '',
              businessName: (data.businessName as string) || (data.fullName as string) || 'Fleet Partner',
              fullName: (data.fullName as string) || '',
              phone: (data.phone as string) || '',
              email: (data.email as string) || '',
              businessType: (data.businessType as string) || 'individual',
              registrationNumber: (data.registrationNumber as string) || '',
              address: (data.address as string) || '',
              state: (data.state as string) || (data.city as string) || 'FCT (Abuja)',
              operatingStates: rawStates,
              gender: data.gender as string | undefined,
              profilePictureUrl: (data.profilePictureUrl as string) || (data.photoUrl as string),
              logoUrl: (data.logoUrl as string) || (data.companyLogoUrl as string) || undefined,
              identityDocumentType: (data.identityDocumentType as string) || 'NIN Slip',
              identityDocumentUrl: data.identityDocumentUrl as string | undefined,
              cacDocumentUrl: data.cacDocumentUrl as string | undefined,
              verificationStatus: (data.verificationStatus as string) || (data.isVerified ? 'approved' : 'pending'),
              isVerified: Boolean(data.isVerified),
              rejectionReason: data.rejectionReason as string | undefined,
              createdAtMs: createdTs?.toMillis?.() ?? (createdTs ? new Date(createdTs as any).getTime() : 0),
              updatedAtMs: updatedTs?.toMillis?.() ?? (updatedTs ? new Date(updatedTs as any).getTime() : 0),
            };
          });

          setRows(list);
          setLoading(false);
          setError(null);
        } catch (e) {
          setError(e instanceof Error ? e.message : 'Unable to load fleet partners queue.');
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

  // Filtered rows
  const pendingCount = rows.filter((r) => r.verificationStatus === 'pending' && !r.isVerified).length;
  const approvedCount = rows.filter((r) => r.verificationStatus === 'approved' || r.isVerified).length;
  const rejectedCount = rows.filter((r) => r.verificationStatus === 'rejected').length;
  const allCount = rows.length;

  const filteredRows = rows.filter((r) => {
    // Status tab filter
    if (activeTab === 'pending' && (r.verificationStatus !== 'pending' || r.isVerified)) return false;
    if (activeTab === 'approved' && r.verificationStatus !== 'approved' && !r.isVerified) return false;
    if (activeTab === 'rejected' && r.verificationStatus !== 'rejected') return false;

    // Entity structure filter
    if (entityFilter !== 'all' && r.businessType !== entityFilter) return false;

    // Search query
    if (searchTerm.trim()) {
      const q = searchTerm.toLowerCase();
      const matchName = r.businessName.toLowerCase().includes(q) || r.fullName.toLowerCase().includes(q);
      const matchEmail = r.email.toLowerCase().includes(q);
      const matchPhone = r.phone.toLowerCase().includes(q);
      const matchRc = r.registrationNumber.toLowerCase().includes(q);
      const matchState = r.state.toLowerCase().includes(q) || r.operatingStates.some((s) => s.toLowerCase().includes(q));
      return matchName || matchEmail || matchPhone || matchRc || matchState;
    }

    return true;
  });

  // Action: Approve Fleet Partner
  async function handleApprove(fleet: FleetPartnerRow) {
    if (!window.confirm(`Are you sure you want to approve "${fleet.businessName}" as a verified Fleet Partner?`)) {
      return;
    }

    setProcessing(true);
    setActionSuccess(null);
    try {
      // 1. Update fleet doc
      await updateDoc(doc(db, 'fleets', fleet.fleetId), {
        verificationStatus: 'approved',
        isVerified: true,
        rejectionReason: null,
        approvedAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });

      // 2. Update fleet_managers doc if ownerUid exists
      if (fleet.ownerUid) {
        try {
          await updateDoc(doc(db, 'fleet_managers', fleet.ownerUid), {
            verificationStatus: 'approved',
            isVerified: true,
            rejectionReason: null,
            updatedAt: serverTimestamp(),
          });
        } catch (_) {}

        // 3. Update users doc
        try {
          await updateDoc(doc(db, 'users', fleet.ownerUid), {
            isVerified: true,
            updatedAt: serverTimestamp(),
          });
        } catch (_) {}
      }

      setActionSuccess(`"${fleet.businessName}" has been successfully approved!`);
      setSelectedFleet(null);
      setShowRejectForm(false);
    } catch (e: any) {
      alert(e.message || 'Failed to approve fleet partner.');
    } finally {
      setProcessing(false);
    }
  }

  // Action: Reject Fleet Partner
  async function handleReject(fleet: FleetPartnerRow) {
    if (!rejectionReasonInput.trim()) {
      alert('Please provide a reason for rejecting this fleet verification request.');
      return;
    }

    setProcessing(true);
    setActionSuccess(null);
    try {
      // 1. Update fleet doc
      await updateDoc(doc(db, 'fleets', fleet.fleetId), {
        verificationStatus: 'rejected',
        isVerified: false,
        rejectionReason: rejectionReasonInput.trim(),
        rejectedAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });

      // 2. Update fleet_managers doc
      if (fleet.ownerUid) {
        try {
          await updateDoc(doc(db, 'fleet_managers', fleet.ownerUid), {
            verificationStatus: 'rejected',
            isVerified: false,
            rejectionReason: rejectionReasonInput.trim(),
            updatedAt: serverTimestamp(),
          });
        } catch (_) {}
      }

      setActionSuccess(`"${fleet.businessName}" has been marked as Rejected.`);
      setSelectedFleet(null);
      setShowRejectForm(false);
      setRejectionReasonInput('');
    } catch (e: any) {
      alert(e.message || 'Failed to reject fleet partner.');
    } finally {
      setProcessing(false);
    }
  }

  return (
    <div>
      <div style={{ marginBottom: 'var(--space-4)' }}>
        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: 'var(--space-2)' }}>
          <div>
            <h2 style={{ margin: 0, fontWeight: 700 }}>👔 Fleet Partner Verifications</h2>
            <p className="muted" style={{ margin: '4px 0 0 0', fontSize: '0.9rem' }}>
              Review submitted business identity, CAC documents, and approve or reject fleet operator credentials.
            </p>
          </div>
        </div>
      </div>

      {actionSuccess && (
        <div className="alert alert--success" style={{ marginBottom: 'var(--space-4)' }}>
          <span>✓ {actionSuccess}</span>
          <button
            type="button"
            onClick={() => setActionSuccess(null)}
            style={{ background: 'none', border: 'none', cursor: 'pointer', float: 'right', fontWeight: 700 }}
          >
            ✕
          </button>
        </div>
      )}

      {error && (
        <div className="alert alert--danger" style={{ marginBottom: 'var(--space-4)' }}>
          <span>{error}</span>
        </div>
      )}

      {/* Tabs */}
      <div
        className="tab-nav"
        style={{
          display: 'flex',
          gap: 'var(--space-2)',
          marginBottom: 'var(--space-4)',
          borderBottom: '1px solid var(--color-border)',
          paddingBottom: 'var(--space-2)',
          flexWrap: 'wrap',
        }}
      >
        <button
          className={`tab-btn ${activeTab === 'pending' ? 'active' : ''}`}
          onClick={() => setActiveTab('pending')}
          style={{
            background: 'none',
            border: 'none',
            padding: 'var(--space-2) var(--space-4)',
            cursor: 'pointer',
            fontSize: '0.95rem',
            fontWeight: 700,
            color: activeTab === 'pending' ? 'var(--color-primary)' : 'var(--color-text-muted)',
            borderBottom: activeTab === 'pending' ? '2px solid var(--color-primary)' : 'none',
            display: 'flex',
            alignItems: 'center',
            gap: 8,
          }}
        >
          🟡 Pending Review
          <span className="badge badge--warning" style={{ borderRadius: 12, padding: '2px 8px', fontSize: '0.75rem' }}>
            {pendingCount}
          </span>
        </button>

        <button
          className={`tab-btn ${activeTab === 'approved' ? 'active' : ''}`}
          onClick={() => setActiveTab('approved')}
          style={{
            background: 'none',
            border: 'none',
            padding: 'var(--space-2) var(--space-4)',
            cursor: 'pointer',
            fontSize: '0.95rem',
            fontWeight: 700,
            color: activeTab === 'approved' ? 'var(--color-primary)' : 'var(--color-text-muted)',
            borderBottom: activeTab === 'approved' ? '2px solid var(--color-primary)' : 'none',
            display: 'flex',
            alignItems: 'center',
            gap: 8,
          }}
        >
          🟢 Approved
          <span className="badge badge--success" style={{ borderRadius: 12, padding: '2px 8px', fontSize: '0.75rem' }}>
            {approvedCount}
          </span>
        </button>

        <button
          className={`tab-btn ${activeTab === 'rejected' ? 'active' : ''}`}
          onClick={() => setActiveTab('rejected')}
          style={{
            background: 'none',
            border: 'none',
            padding: 'var(--space-2) var(--space-4)',
            cursor: 'pointer',
            fontSize: '0.95rem',
            fontWeight: 700,
            color: activeTab === 'rejected' ? 'var(--color-primary)' : 'var(--color-text-muted)',
            borderBottom: activeTab === 'rejected' ? '2px solid var(--color-primary)' : 'none',
            display: 'flex',
            alignItems: 'center',
            gap: 8,
          }}
        >
          🔴 Rejected
          <span className="badge badge--danger" style={{ borderRadius: 12, padding: '2px 8px', fontSize: '0.75rem' }}>
            {rejectedCount}
          </span>
        </button>

        <button
          className={`tab-btn ${activeTab === 'all' ? 'active' : ''}`}
          onClick={() => setActiveTab('all')}
          style={{
            background: 'none',
            border: 'none',
            padding: 'var(--space-2) var(--space-4)',
            cursor: 'pointer',
            fontSize: '0.95rem',
            fontWeight: 700,
            color: activeTab === 'all' ? 'var(--color-primary)' : 'var(--color-text-muted)',
            borderBottom: activeTab === 'all' ? '2px solid var(--color-primary)' : 'none',
            display: 'flex',
            alignItems: 'center',
            gap: 8,
          }}
        >
          ⚪ All
          <span className="badge" style={{ borderRadius: 12, padding: '2px 8px', fontSize: '0.75rem' }}>
            {allCount}
          </span>
        </button>
      </div>

      {/* Filter bar */}
      <div style={{ display: 'flex', gap: 'var(--space-3)', marginBottom: 'var(--space-4)', flexWrap: 'wrap' }}>
        <input
          type="text"
          className="field__input"
          placeholder="Search by name, company, email, RC number or city..."
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
          style={{ flex: 1, minWidth: 260 }}
        />

        <select
          className="field__input"
          value={entityFilter}
          onChange={(e) => setEntityFilter(e.target.value as any)}
          style={{ width: 220 }}
        >
          <option value="all">All Entity Types</option>
          <option value="individual">Individual Operator</option>
          <option value="company">Registered Company</option>
        </select>
      </div>

      {/* Table */}
      {loading ? (
        <div className="card" style={{ padding: 'var(--space-5)', textAlign: 'center' }}>
          <p className="muted">Loading fleet partners queue...</p>
        </div>
      ) : filteredRows.length === 0 ? (
        <div className="card" style={{ padding: 'var(--space-6)', textAlign: 'center' }}>
          <p style={{ fontSize: '1.5rem', margin: 0 }}>📭</p>
          <h4 style={{ margin: 'var(--space-2) 0 0 0' }}>No Fleet Partners Found</h4>
          <p className="muted" style={{ fontSize: '0.85rem' }}>
            {searchTerm ? 'No results matched your search query.' : 'There are currently no fleet partners in this category.'}
          </p>
        </div>
      ) : (
        <div className="card" style={{ padding: 0, overflowX: 'auto' }}>
          <table className="table" style={{ width: '100%', borderCollapse: 'collapse', textAlign: 'left' }}>
            <thead>
              <tr style={{ borderBottom: '1px solid var(--color-border)', background: 'var(--color-bg-alt)' }}>
                <th style={{ padding: '12px 16px' }}>Business / Partner</th>
                <th style={{ padding: '12px 16px' }}>Entity Type</th>
                <th style={{ padding: '12px 16px' }}>Registration / RC</th>
                <th style={{ padding: '12px 16px' }}>Operating State(s)</th>
                <th style={{ padding: '12px 16px' }}>Documents</th>
                <th style={{ padding: '12px 16px' }}>Status</th>
                <th style={{ padding: '12px 16px', textAlign: 'right' }}>Actions</th>
              </tr>
            </thead>
            <tbody>
              {filteredRows.map((fleet) => {
                const isApproved = fleet.verificationStatus === 'approved' || fleet.isVerified;
                const isPending = fleet.verificationStatus === 'pending' && !fleet.isVerified;
                const isRejected = fleet.verificationStatus === 'rejected';

                return (
                  <tr key={fleet.fleetId} style={{ borderBottom: '1px solid var(--color-border)' }}>
                    {/* Partner Name & Email */}
                    <td style={{ padding: '14px 16px' }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                        <div
                          style={{
                            width: 40,
                            height: 40,
                            borderRadius: '50%',
                            background: 'var(--color-primary-light)',
                            display: 'flex',
                            alignItems: 'center',
                            justifyContent: 'center',
                            fontWeight: 700,
                            color: 'var(--color-primary)',
                            overflow: 'hidden',
                          }}
                        >
                          {fleet.logoUrl || fleet.profilePictureUrl ? (
                            <img src={fleet.logoUrl || fleet.profilePictureUrl} alt="" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                          ) : (
                            fleet.businessName.charAt(0).toUpperCase()
                          )}
                        </div>
                        <div>
                          <div style={{ fontWeight: 700, fontSize: '0.95rem' }}>{fleet.businessName}</div>
                          <div className="muted" style={{ fontSize: '0.8rem' }}>
                            {fleet.fullName && fleet.fullName !== fleet.businessName ? `${fleet.fullName} • ` : ''}
                            {fleet.email || fleet.phone}
                          </div>
                        </div>
                      </div>
                    </td>

                    {/* Entity Type */}
                    <td style={{ padding: '14px 16px' }}>
                      <span
                        className={`badge ${fleet.businessType === 'company' ? 'badge--info' : 'badge--neutral'}`}
                        style={{ borderRadius: 12, padding: '4px 10px', fontSize: '0.8rem', fontWeight: 600 }}
                      >
                        {fleet.businessType === 'company' ? '🏢 Company' : '👤 Individual'}
                      </span>
                    </td>

                    {/* Registration / RC */}
                    <td style={{ padding: '14px 16px', fontSize: '0.85rem' }}>
                      {fleet.registrationNumber ? (
                        <span style={{ fontFamily: 'monospace', fontWeight: 600 }}>{fleet.registrationNumber}</span>
                      ) : (
                        <span className="muted">N/A</span>
                      )}
                    </td>

                    {/* Location & Operating States */}
                    <td style={{ padding: '14px 16px', fontSize: '0.85rem' }}>
                      <div style={{ display: 'flex', gap: 4, flexWrap: 'wrap', maxWidth: 220 }}>
                        {fleet.operatingStates && fleet.operatingStates.length > 0 ? (
                          fleet.operatingStates.map((s, i) => (
                            <span
                              key={i}
                              style={{
                                background: 'var(--color-bg-alt)',
                                border: '1px solid var(--color-border)',
                                borderRadius: 6,
                                padding: '1px 6px',
                                fontSize: '0.75rem',
                                fontWeight: 600,
                              }}
                            >
                              📍 {s}
                            </span>
                          ))
                        ) : (
                          <div>{fleet.state}</div>
                        )}
                      </div>
                      {fleet.address && (
                        <div className="muted" style={{ fontSize: '0.75rem', maxWidth: 180, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap', marginTop: 4 }}>
                          {fleet.address}
                        </div>
                      )}
                    </td>

                    {/* Documents */}
                    <td style={{ padding: '14px 16px' }}>
                      <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap' }}>
                        {fleet.identityDocumentUrl ? (
                          <span
                            onClick={() => setPreviewImage({ url: fleet.identityDocumentUrl!, title: `Identity Document (${fleet.identityDocumentType || 'ID'})` })}
                            style={{
                              cursor: 'pointer',
                              padding: '2px 8px',
                              background: 'var(--color-primary-light)',
                              color: 'var(--color-primary-active)',
                              borderRadius: 8,
                              fontSize: '0.75rem',
                              fontWeight: 600,
                            }}
                            title="Click to preview ID document"
                          >
                            🪪 ID Attached
                          </span>
                        ) : (
                          <span style={{ padding: '2px 8px', background: 'var(--color-bg-alt)', borderRadius: 8, fontSize: '0.75rem', color: 'var(--color-text-muted)' }}>
                            No ID
                          </span>
                        )}

                        {fleet.businessType === 'company' && fleet.logoUrl && (
                          <span
                            onClick={() => setPreviewImage({ url: fleet.logoUrl!, title: `${fleet.businessName} Company Logo` })}
                            style={{
                              cursor: 'pointer',
                              padding: '2px 8px',
                              background: '#FDF2F8',
                              color: '#DB2777',
                              borderRadius: 8,
                              fontSize: '0.75rem',
                              fontWeight: 600,
                            }}
                            title="Click to preview company logo"
                          >
                            🏢 Logo Attached
                          </span>
                        )}

                        {fleet.businessType === 'company' && (
                          fleet.cacDocumentUrl ? (
                            <span
                              onClick={() => setPreviewImage({ url: fleet.cacDocumentUrl!, title: 'CAC Certificate Document' })}
                              style={{
                                cursor: 'pointer',
                                padding: '2px 8px',
                                background: '#E0F2FE',
                                color: '#0369A1',
                                borderRadius: 8,
                                fontSize: '0.75rem',
                                fontWeight: 600,
                              }}
                              title="Click to preview CAC document"
                            >
                              📜 CAC Attached
                            </span>
                          ) : (
                            <span style={{ padding: '2px 8px', background: 'var(--color-bg-alt)', borderRadius: 8, fontSize: '0.75rem', color: 'var(--color-text-muted)' }}>
                              No CAC
                            </span>
                          )
                        )}
                      </div>
                    </td>

                    {/* Status */}
                    <td style={{ padding: '14px 16px' }}>
                      {isApproved && <span className="badge badge--success" style={{ borderRadius: 12, padding: '4px 10px', fontSize: '0.8rem' }}>Approved</span>}
                      {isPending && <span className="badge badge--warning" style={{ borderRadius: 12, padding: '4px 10px', fontSize: '0.8rem' }}>Pending</span>}
                      {isRejected && (
                        <span
                          className="badge badge--danger"
                          style={{ borderRadius: 12, padding: '4px 10px', fontSize: '0.8rem' }}
                          title={fleet.rejectionReason}
                        >
                          Rejected
                        </span>
                      )}
                    </td>

                    {/* Actions */}
                    <td style={{ padding: '14px 16px', textAlign: 'right' }}>
                      <button
                        type="button"
                        className="btn btn--secondary"
                        style={{ padding: '6px 14px', fontSize: '0.85rem' }}
                        onClick={() => {
                          setSelectedFleet(fleet);
                          setShowRejectForm(false);
                          setRejectionReasonInput(fleet.rejectionReason || '');
                        }}
                      >
                        Review
                      </button>
                    </td>
                  </tr>
                );
              })}
            </tbody>
          </table>
        </div>
      )}

      {/* Review Modal */}
      {selectedFleet && (
        <div
          style={{
            position: 'fixed',
            inset: 0,
            background: 'rgba(0, 0, 0, 0.5)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 1000,
            padding: 'var(--space-4)',
          }}
          onClick={() => setSelectedFleet(null)}
        >
          <div
            className="card"
            style={{
              width: '100%',
              maxWidth: 680,
              maxHeight: '90vh',
              overflowY: 'auto',
              display: 'flex',
              flexDirection: 'column',
              gap: 'var(--space-4)',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            {/* Modal Header */}
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '1px solid var(--color-border)', paddingBottom: 'var(--space-3)' }}>
              <div>
                <h3 style={{ margin: 0, fontWeight: 700 }}>👔 Review Fleet Partner Application</h3>
                <p className="muted" style={{ margin: 0, fontSize: '0.85rem' }}>
                  ID: {selectedFleet.fleetId}
                </p>
              </div>
              <button
                type="button"
                onClick={() => setSelectedFleet(null)}
                style={{ background: 'none', border: 'none', fontSize: '1.2rem', cursor: 'pointer' }}
              >
                ✕
              </button>
            </div>

            {/* Profile & Business Info */}
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 'var(--space-3)' }}>
              <div>
                <label className="muted" style={{ fontSize: '0.75rem', fontWeight: 700 }}>BUSINESS NAME</label>
                <div style={{ fontWeight: 700, fontSize: '0.95rem' }}>{selectedFleet.businessName}</div>
              </div>

              <div>
                <label className="muted" style={{ fontSize: '0.75rem', fontWeight: 700 }}>ENTITY TYPE</label>
                <div>{selectedFleet.businessType === 'company' ? 'Registered Company' : 'Individual Operator'}</div>
              </div>

              <div>
                <label className="muted" style={{ fontSize: '0.75rem', fontWeight: 700 }}>REPRESENTATIVE / OWNER</label>
                <div style={{ fontWeight: 600 }}>{selectedFleet.fullName || 'N/A'}</div>
              </div>

              <div>
                <label className="muted" style={{ fontSize: '0.75rem', fontWeight: 700 }}>PHONE NUMBER</label>
                <div>{selectedFleet.phone || 'N/A'}</div>
              </div>

              <div>
                <label className="muted" style={{ fontSize: '0.75rem', fontWeight: 700 }}>EMAIL ADDRESS</label>
                <div>{selectedFleet.email || 'N/A'}</div>
              </div>

              <div>
                <label className="muted" style={{ fontSize: '0.75rem', fontWeight: 700 }}>RC / REGISTRATION NUMBER</label>
                <div style={{ fontFamily: 'monospace', fontWeight: 700 }}>{selectedFleet.registrationNumber || 'N/A'}</div>
              </div>

              <div style={{ gridColumn: '1 / -1' }}>
                <label className="muted" style={{ fontSize: '0.75rem', fontWeight: 700 }}>OPERATING STATES FOR VEHICLE DISPATCH</label>
                <div style={{ display: 'flex', gap: 6, flexWrap: 'wrap', marginTop: 4 }}>
                  {selectedFleet.operatingStates && selectedFleet.operatingStates.length > 0 ? (
                    selectedFleet.operatingStates.map((s, i) => (
                      <span
                        key={i}
                        className="badge badge--success"
                        style={{ borderRadius: 12, padding: '4px 10px', fontSize: '0.8rem', fontWeight: 700 }}
                      >
                        📍 {s}
                      </span>
                    ))
                  ) : (
                    <span className="muted">{selectedFleet.state}</span>
                  )}
                </div>
              </div>

              <div style={{ gridColumn: '1 / -1' }}>
                <label className="muted" style={{ fontSize: '0.75rem', fontWeight: 700 }}>REGISTERED ADDRESS</label>
                <div>{selectedFleet.address || 'N/A'}</div>
              </div>
            </div>

            {/* Verification Documents Section */}
            <div style={{ borderTop: '1px solid var(--color-border)', paddingTop: 'var(--space-3)' }}>
              <h4 style={{ margin: '0 0 var(--space-2) 0', fontWeight: 700 }}>Uploaded Documents</h4>
              <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: 'var(--space-3)' }}>
                {/* ID Doc */}
                <div style={{ border: '1px solid var(--color-border)', borderRadius: 'var(--radius-md)', padding: 'var(--space-3)', background: 'var(--color-bg-alt)' }}>
                  <div style={{ fontWeight: 700, fontSize: '0.85rem', marginBottom: 4 }}>
                    🪪 {selectedFleet.identityDocumentType || 'Identity Document'}
                  </div>
                  {selectedFleet.identityDocumentUrl ? (
                    <div>
                      <img
                        src={selectedFleet.identityDocumentUrl}
                        alt="ID Document"
                        style={{ width: '100%', height: 130, objectFit: 'cover', borderRadius: 6, cursor: 'pointer', marginBottom: 8 }}
                        onClick={() => setPreviewImage({ url: selectedFleet.identityDocumentUrl!, title: selectedFleet.identityDocumentType || 'Identity Document' })}
                      />
                      <button
                        type="button"
                        className="btn btn--secondary"
                        style={{ width: '100%', padding: '4px 8px', fontSize: '0.75rem' }}
                        onClick={() => setPreviewImage({ url: selectedFleet.identityDocumentUrl!, title: selectedFleet.identityDocumentType || 'Identity Document' })}
                      >
                        🔍 Zoom Image
                      </button>
                    </div>
                  ) : (
                    <p className="muted" style={{ fontSize: '0.8rem', margin: 0 }}>No identity document uploaded.</p>
                  )}
                </div>

                {/* CAC Doc if company */}
                {selectedFleet.businessType === 'company' && (
                  <>
                    <div style={{ border: '1px solid var(--color-border)', borderRadius: 'var(--radius-md)', padding: 'var(--space-3)', background: 'var(--color-bg-alt)' }}>
                      <div style={{ fontWeight: 700, fontSize: '0.85rem', marginBottom: 4 }}>
                        🏢 Official Company Logo
                      </div>
                      {selectedFleet.logoUrl ? (
                        <div>
                          <img
                            src={selectedFleet.logoUrl}
                            alt="Company Logo"
                            style={{ width: '100%', height: 130, objectFit: 'contain', background: '#fff', borderRadius: 6, cursor: 'pointer', marginBottom: 8, padding: 4 }}
                            onClick={() => setPreviewImage({ url: selectedFleet.logoUrl!, title: `${selectedFleet.businessName} Company Logo` })}
                          />
                          <button
                            type="button"
                            className="btn btn--secondary"
                            style={{ width: '100%', padding: '4px 8px', fontSize: '0.75rem' }}
                            onClick={() => setPreviewImage({ url: selectedFleet.logoUrl!, title: `${selectedFleet.businessName} Company Logo` })}
                          >
                            🔍 Zoom Image
                          </button>
                        </div>
                      ) : (
                        <p className="muted" style={{ fontSize: '0.8rem', margin: 0 }}>No company logo uploaded.</p>
                      )}
                    </div>

                    <div style={{ border: '1px solid var(--color-border)', borderRadius: 'var(--radius-md)', padding: 'var(--space-3)', background: 'var(--color-bg-alt)' }}>
                      <div style={{ fontWeight: 700, fontSize: '0.85rem', marginBottom: 4 }}>
                        📜 CAC Registration Document
                      </div>
                      {selectedFleet.cacDocumentUrl ? (
                        <div>
                          <img
                            src={selectedFleet.cacDocumentUrl}
                            alt="CAC Document"
                            style={{ width: '100%', height: 130, objectFit: 'cover', borderRadius: 6, cursor: 'pointer', marginBottom: 8 }}
                            onClick={() => setPreviewImage({ url: selectedFleet.cacDocumentUrl!, title: 'CAC Document' })}
                          />
                          <button
                            type="button"
                            className="btn btn--secondary"
                            style={{ width: '100%', padding: '4px 8px', fontSize: '0.75rem' }}
                            onClick={() => setPreviewImage({ url: selectedFleet.cacDocumentUrl!, title: 'CAC Document' })}
                          >
                            🔍 Zoom Image
                          </button>
                        </div>
                      ) : (
                        <p className="muted" style={{ fontSize: '0.8rem', margin: 0 }}>No CAC document uploaded.</p>
                      )}
                    </div>
                  </>
                )}
              </div>
            </div>

            {/* Current Status Info */}
            {selectedFleet.rejectionReason && (
              <div className="alert alert--danger" style={{ margin: 0, fontSize: '0.85rem' }}>
                <strong>Current Rejection Reason:</strong> {selectedFleet.rejectionReason}
              </div>
            )}

            {/* Reject Reason Form if opened */}
            {showRejectForm && (
              <div style={{ border: '1px solid var(--color-danger)', borderRadius: 'var(--radius-md)', padding: 'var(--space-3)', background: '#FEF2F2' }}>
                <label style={{ fontWeight: 700, fontSize: '0.85rem', color: '#991B1B' }}>
                  Reason for Rejection (Displayed to partner):
                </label>
                <textarea
                  className="field__input"
                  rows={3}
                  value={rejectionReasonInput}
                  onChange={(e) => setRejectionReasonInput(e.target.value)}
                  placeholder="e.g. Identity document photo is blurry, CAC certificate name does not match, etc."
                  style={{ marginTop: 6, resize: 'vertical' }}
                />
                <div style={{ display: 'flex', gap: 'var(--space-2)', marginTop: 8, justifyContent: 'flex-end' }}>
                  <button
                    type="button"
                    className="btn btn--secondary"
                    onClick={() => setShowRejectForm(false)}
                    disabled={processing}
                  >
                    Cancel
                  </button>
                  <button
                    type="button"
                    className="btn btn--danger"
                    onClick={() => handleReject(selectedFleet)}
                    disabled={processing}
                  >
                    {processing ? 'Rejecting...' : 'Confirm Rejection'}
                  </button>
                </div>
              </div>
            )}

            {/* Decision Buttons */}
            {!showRejectForm && (
              <div style={{ display: 'flex', gap: 'var(--space-3)', justifyContent: 'flex-end', borderTop: '1px solid var(--color-border)', paddingTop: 'var(--space-3)' }}>
                <button
                  type="button"
                  className="btn btn--secondary"
                  onClick={() => setSelectedFleet(null)}
                  disabled={processing}
                >
                  Close
                </button>

                {selectedFleet.verificationStatus !== 'rejected' && (
                  <>
                    <button
                      type="button"
                      className="btn btn--danger"
                      onClick={() => setShowRejectForm(true)}
                      disabled={processing}
                    >
                      Reject Application
                    </button>

                    <button
                      type="button"
                      className="btn btn--primary"
                      onClick={() => handleApprove(selectedFleet)}
                      disabled={processing}
                    >
                      {processing ? 'Approving...' : 'Approve Partner'}
                    </button>
                  </>
                )}
              </div>
            )}
          </div>
        </div>
      )}

      {/* Image Zoom Preview Modal */}
      {previewImage && (
        <div
          style={{
            position: 'fixed',
            inset: 0,
            background: 'rgba(0, 0, 0, 0.85)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            zIndex: 1100,
            padding: 'var(--space-4)',
          }}
          onClick={() => setPreviewImage(null)}
        >
          <div
            style={{
              position: 'relative',
              maxWidth: '90vw',
              maxHeight: '90vh',
              background: '#fff',
              borderRadius: 'var(--radius-lg)',
              overflow: 'hidden',
              display: 'flex',
              flexDirection: 'column',
            }}
            onClick={(e) => e.stopPropagation()}
          >
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '12px 20px', borderBottom: '1px solid #E5E7EB' }}>
              <div style={{ fontWeight: 700, fontSize: '0.95rem' }}>{previewImage.title}</div>
              <button
                type="button"
                onClick={() => setPreviewImage(null)}
                style={{ background: 'none', border: 'none', fontSize: '1.2rem', cursor: 'pointer' }}
              >
                ✕
              </button>
            </div>
            <div style={{ padding: 'var(--space-3)', overflow: 'auto', textAlign: 'center' }}>
              <img
                src={previewImage.url}
                alt={previewImage.title}
                style={{ maxWidth: '100%', maxHeight: '75vh', objectFit: 'contain', borderRadius: 8 }}
              />
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
