import { useEffect, useState } from 'react';
import { Link } from 'react-router-dom';
import { collection, onSnapshot, orderBy, query, type QuerySnapshot, type DocumentData } from 'firebase/firestore';
import { db } from '../config/firebase';

type Tab = 'customers' | 'drivers';

interface CustomerRow {
  uid: string;
  fullName: string;
  email: string;
  phone?: string;
  walletBalance: number;
  createdAtMs: number;
  photoUrl?: string;
}

interface DriverRow {
  uid: string;
  fullName: string;
  email: string;
  phone?: string;
  approvalStatus: string;
  tier: string;
  photoUrl?: string;
}

export function UsersPage() {
  const [tab, setTab] = useState<Tab>('customers');
  const [customers, setCustomers] = useState<CustomerRow[]>([]);
  const [drivers, setDrivers] = useState<DriverRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);
  const [searchTerm, setSearchTerm] = useState('');
  const [currentPage, setCurrentPage] = useState(1);
  const [copiedUid, setCopiedUid] = useState<string | null>(null);
  const [userPhotos, setUserPhotos] = useState<Record<string, string>>({});
  const [selectedCustomer, setSelectedCustomer] = useState<CustomerRow | null>(null);
  const pageSize = 10;

  useEffect(() => {
    const unsubCustomers = onSnapshot(
      collection(db, 'customers'),
      (snap: QuerySnapshot<DocumentData>) => {
        const rows: CustomerRow[] = snap.docs.map((docSnap) => {
          const d = docSnap.data();
          const ts = d.createdAt as { toMillis?: () => number } | undefined;
          const createdAtMs = ts?.toMillis?.() ?? 0;
          const photoUrl =
            (d.photoUrl as string) ||
            (d.profilePhotoUrl as string) ||
            (d.avatarUrl as string) ||
            (d.photo as string) ||
            '';
          return {
            uid: docSnap.id,
            fullName: (d.fullName as string) || '',
            email: (d.email as string) || '',
            phone: (d.phone as string) || '',
            walletBalance: (d.walletBalance as number) || 0,
            createdAtMs,
            photoUrl,
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
          const photoUrl =
            (d.profilePhotoUrl as string) ||
            (d.photoUrl as string) ||
            (d.avatarUrl as string) ||
            (d.photo as string) ||
            '';
          return {
            uid: docSnap.id,
            fullName: (d.fullName as string) || '',
            email: (d.email as string) || '',
            phone: (d.phone as string) || '',
            approvalStatus: (d.approvalStatus as string) || 'pending',
            tier: (d.tier as string) || 'bronze',
            photoUrl,
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

    // Also watch users collection as fallback for photos
    const unsubUsers = onSnapshot(
      collection(db, 'users'),
      (snap: QuerySnapshot<DocumentData>) => {
        const map: Record<string, string> = {};
        snap.docs.forEach((docSnap) => {
          const d = docSnap.data();
          const p =
            (d.photoUrl as string) ||
            (d.profilePhotoUrl as string) ||
            (d.avatarUrl as string) ||
            (d.photo as string) ||
            '';
          if (p) map[docSnap.id] = p;
        });
        setUserPhotos(map);
      },
      () => {},
    );

    return () => {
      unsubCustomers();
      unsubDrivers();
      unsubUsers();
    };
  }, []);

  function getTierBadgeColor(tier: string) {
    switch (tier.toLowerCase()) {
      case 'gold': return '#fbbf24';
      case 'platinum': return '#a78bfa';
      case 'silver': return '#94a3b8';
      default: return '#b45309'; // bronze
    }
  }

  function handleCopy(uid: string) {
    void navigator.clipboard.writeText(uid);
    setCopiedUid(uid);
    setTimeout(() => setCopiedUid(null), 2000);
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

  // Pagination calculations
  const currentList = tab === 'customers' ? filteredCustomers : filteredDrivers;
  const totalItems = currentList.length;
  const totalPages = Math.max(1, Math.ceil(totalItems / pageSize));
  const startIndex = (currentPage - 1) * pageSize;
  const paginatedCustomers = filteredCustomers.slice(startIndex, startIndex + pageSize);
  const paginatedDrivers = filteredDrivers.slice(startIndex, startIndex + pageSize);

  // Stats calculation
  const totalWalletBalances = customers.reduce((sum, c) => sum + (c.walletBalance || 0), 0);
  const approvedDriversCount = drivers.filter(d => d.approvalStatus === 'approved').length;
  const pendingDriversCount = drivers.filter(d => d.approvalStatus === 'pending').length;

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 20 }}>
      {/* 4 Summary Stat Cards matching orders.png */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))', gap: 16 }}>
        <div className="card" style={{ padding: 20 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '0.825rem', fontWeight: 600, color: 'var(--color-text-muted)' }}>Registered Riders</span>
            <div style={{ width: 36, height: 36, borderRadius: '50%', background: 'rgba(22, 163, 74, 0.12)', color: '#16a34a', display: 'grid', placeItems: 'center' }}>
              <svg style={{ width: 18, height: 18 }} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
                <circle cx="9" cy="7" r="4" />
                <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
                <path d="M16 3.13a4 4 0 0 1 0 7.75" />
              </svg>
            </div>
          </div>
          <div style={{ fontSize: '1.9rem', fontWeight: 800, marginTop: 8 }}>{customers.length}</div>
          <span style={{ fontSize: '0.75rem', color: 'var(--color-text-muted)' }}>Total active customer accounts</span>
        </div>

        <div className="card" style={{ padding: 20 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '0.825rem', fontWeight: 600, color: 'var(--color-text-muted)' }}>Total Drivers</span>
            <div style={{ width: 36, height: 36, borderRadius: '50%', background: 'rgba(59, 130, 246, 0.12)', color: '#2563eb', display: 'grid', placeItems: 'center' }}>
              <svg style={{ width: 18, height: 18 }} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <rect x="1" y="3" width="15" height="13" rx="2" ry="2" />
                <polygon points="16 8 20 8 23 11 23 16 16 16 16 8" />
                <circle cx="5.5" cy="18.5" r="2.5" />
                <circle cx="18.5" cy="18.5" r="2.5" />
              </svg>
            </div>
          </div>
          <div style={{ fontSize: '1.9rem', fontWeight: 800, marginTop: 8 }}>{drivers.length}</div>
          <span style={{ fontSize: '0.75rem', color: 'var(--color-text-muted)' }}>
            <strong style={{ color: '#16a34a' }}>{approvedDriversCount}</strong> approved • <strong style={{ color: '#d97706' }}>{pendingDriversCount}</strong> pending
          </span>
        </div>

        <div className="card" style={{ padding: 20 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '0.825rem', fontWeight: 600, color: 'var(--color-text-muted)' }}>Customer Balances</span>
            <div style={{ width: 36, height: 36, borderRadius: '50%', background: 'rgba(16, 185, 129, 0.12)', color: '#059669', display: 'grid', placeItems: 'center' }}>
              <svg style={{ width: 18, height: 18 }} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <rect x="2" y="4" width="20" height="16" rx="2" />
                <line x1="12" y1="8" x2="12" y2="16" />
                <line x1="8" y1="12" x2="16" y2="12" />
              </svg>
            </div>
          </div>
          <div style={{ fontSize: '1.9rem', fontWeight: 800, marginTop: 8, color: '#16a34a' }}>
            ₦{totalWalletBalances.toLocaleString('en-NG')}
          </div>
          <span style={{ fontSize: '0.75rem', color: 'var(--color-text-muted)' }}>In-app customer wallet funds</span>
        </div>

        <div className="card" style={{ padding: 20 }}>
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <span style={{ fontSize: '0.825rem', fontWeight: 600, color: 'var(--color-text-muted)' }}>Verification Queue</span>
            <div style={{ width: 36, height: 36, borderRadius: '50%', background: '#FEF3C7', color: '#B45309', display: 'grid', placeItems: 'center' }}>
              <svg style={{ width: 18, height: 18 }} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <circle cx="12" cy="12" r="10" />
                <line x1="12" y1="8" x2="12" y2="12" />
                <line x1="12" y1="16" x2="12.01" y2="16" />
              </svg>
            </div>
          </div>
          <div style={{ fontSize: '1.9rem', fontWeight: 800, marginTop: 8 }}>{pendingDriversCount}</div>
          <span style={{ fontSize: '0.75rem', color: 'var(--color-text-muted)' }}>Awaiting review</span>
        </div>
      </div>

      {/* Underline Tabs matching orders.png */}
      <div className="tab-bar-underline">
        <button
          type="button"
          className={`tab-btn-underline ${tab === 'customers' ? 'active' : ''}`}
          onClick={() => { setTab('customers'); setSearchTerm(''); setCurrentPage(1); }}
        >
          <span>Customers</span>
          <span className="tab-count-badge">{customers.length}</span>
        </button>
        <button
          type="button"
          className={`tab-btn-underline ${tab === 'drivers' ? 'active' : ''}`}
          onClick={() => { setTab('drivers'); setSearchTerm(''); setCurrentPage(1); }}
        >
          <span>Drivers</span>
          <span className="tab-count-badge">{drivers.length}</span>
        </button>
      </div>

      {/* Filter & Search Toolbar matching orders.png */}
      <div className="filter-toolbar">
        <div className="filter-toolbar__group">
          <div className="search-pill-wrap">
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <circle cx="11" cy="11" r="8" /><line x1="21" y1="21" x2="16.65" y2="16.65" />
            </svg>
            <input 
              type="text" 
              placeholder={`Search ${tab === 'customers' ? 'customer' : 'driver'} name, email, or UID...`} 
              value={searchTerm} 
              onChange={e => { setSearchTerm(e.target.value); setCurrentPage(1); }} 
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

          <div className="filter-pill">
            <svg style={{ width: 14, height: 14 }} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <line x1="4" y1="21" x2="4" y2="14" />
              <line x1="4" y1="10" x2="4" y2="3" />
              <line x1="12" y1="21" x2="12" y2="12" />
              <line x1="12" y1="8" x2="12" y2="3" />
              <line x1="20" y1="21" x2="20" y2="16" />
              <line x1="20" y1="12" x2="20" y2="3" />
            </svg>
            <span>Sort: Latest</span>
          </div>
        </div>

        <div className="filter-toolbar__group">
          <button
            type="button"
            className="filter-pill"
            onClick={() => {
              const rowsToExport = tab === 'customers' 
                ? filteredCustomers.map(c => `"${c.uid}","${c.fullName}","${c.email}","${c.walletBalance}","${c.createdAtMs ? new Date(c.createdAtMs).toISOString() : ''}"`)
                : filteredDrivers.map(d => `"${d.uid}","${d.fullName}","${d.email}","${d.tier}","${d.approvalStatus}"`);
              const headers = tab === 'customers' 
                ? 'UID,Name,Email,WalletBalance,CreatedAt'
                : 'UID,Name,Email,Tier,ApprovalStatus';
              const csv = `data:text/csv;charset=utf-8,${headers}\n${rowsToExport.join('\n')}`;
              const link = document.createElement('a');
              link.setAttribute('href', encodeURI(csv));
              link.setAttribute('download', `caride_${tab}_${Date.now()}.csv`);
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

      {error && (
        <div className="alert-banner-danger">
          <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <circle cx="12" cy="12" r="10" /><line x1="12" y1="8" x2="12" y2="12" /><line x1="12" y1="16" x2="12.01" y2="16" />
          </svg>
          <div style={{ flex: 1 }}>
            <strong>Action Required:</strong> {error}
          </div>
        </div>
      )}

      {/* Main Table Card */}
      <div className="table-card">
        <div className="table-card-header">
          <div>
            <h3 className="table-card-title">
              {tab === 'customers' ? 'Customer Directory' : 'Driver Directory'}
            </h3>
            <p className="table-card-subtitle">
              Showing {currentList.length} registered {tab === 'customers' ? 'rider' : 'driver'} profiles
            </p>
          </div>
        </div>

        {loading && customers.length === 0 && drivers.length === 0 ? (
          <div style={{ padding: 24, display: 'flex', flexDirection: 'column', gap: 14 }}>
            {[1, 2, 3, 4, 5].map(idx => (
              <div key={idx} className="skeleton-row shimmer" style={{ height: 54, borderRadius: 14 }} />
            ))}
          </div>
        ) : tab === 'customers' ? (
          filteredCustomers.length === 0 ? (
            <div className="empty-state">
              <svg className="empty-state__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <circle cx="9" cy="7" r="4" /><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
              </svg>
              <h4 style={{ margin: 0 }}>No customers found</h4>
              <p className="muted" style={{ margin: 0, fontSize: '0.85rem' }}>No matching profiles correspond to this query.</p>
            </div>
          ) : (
            <div style={{ overflowX: 'auto' }}>
              <table className="table-premium">
                <thead>
                  <tr>
                    <th>User & Registered Date</th>
                    <th>Email Address</th>
                    <th>Wallet Balance</th>
                    <th>Account UID</th>
                    <th>Status</th>
                    <th style={{ textAlign: 'right' }}>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {paginatedCustomers.map((u) => {
                    const initials = (u.fullName || u.email || 'R')[0].toUpperCase();
                    const photo = u.photoUrl || userPhotos[u.uid];
                    return (
                      <tr key={u.uid}>
                        <td>
                          <div className="table-entity-cell">
                            <AvatarCell
                              photoUrl={photo}
                              name={u.fullName}
                              fallbackLetter={initials}
                              isDriver={false}
                            />
                            <div>
                              <div className="table-entity-title">
                                {u.fullName || '(No name set)'}
                              </div>
                              <div className="table-entity-sub">
                                {u.createdAtMs ? new Date(u.createdAtMs).toLocaleDateString('en-NG', { dateStyle: 'medium' }) : 'Active Customer'}
                              </div>
                            </div>
                          </div>
                        </td>
                        <td>
                          <span style={{ fontSize: '0.875rem', color: 'var(--color-text)' }}>
                            {u.email}
                          </span>
                        </td>
                        <td>
                          <div style={{ fontWeight: 800, fontSize: '0.95rem', color: u.walletBalance > 0 ? '#15803d' : 'var(--color-text)' }}>
                            ₦{u.walletBalance.toLocaleString('en-NG')}
                          </div>
                        </td>
                        <td>
                          <button
                            type="button"
                            className="uid-pill"
                            onClick={() => handleCopy(u.uid)}
                            title="Click to copy full UID"
                            style={{ cursor: 'pointer', border: 'none' }}
                          >
                            <span>#{u.uid.slice(0, 8)}...</span>
                            <svg style={{ width: 12, height: 12, opacity: 0.6 }} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                              <rect x="9" y="9" width="13" height="13" rx="2" ry="2" />
                              <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1" />
                            </svg>
                            {copiedUid === u.uid && (
                              <span style={{ fontSize: '0.65rem', color: '#16a34a', fontWeight: 700 }}>Copied!</span>
                            )}
                          </button>
                        </td>
                        <td>
                          <span className="status-pill status-pill--success">
                            Active
                          </span>
                        </td>
                        <td style={{ textAlign: 'right' }}>
                          <button
                            type="button"
                            className="btn-table-action"
                            onClick={() => setSelectedCustomer(u)}
                          >
                            View Details
                          </button>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )
        ) : (
          filteredDrivers.length === 0 ? (
            <div className="empty-state">
              <svg className="empty-state__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <circle cx="9" cy="7" r="4" /><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
              </svg>
              <h4 style={{ margin: 0 }}>No drivers found</h4>
              <p className="muted" style={{ margin: 0, fontSize: '0.85rem' }}>No drivers correspond to this search query.</p>
            </div>
          ) : (
            <div style={{ overflowX: 'auto' }}>
              <table className="table-premium">
                <thead>
                  <tr>
                    <th>Driver & UID</th>
                    <th>Email Address</th>
                    <th>Tier Rating</th>
                    <th>Approval Status</th>
                    <th style={{ textAlign: 'right' }}>Actions</th>
                  </tr>
                </thead>
                <tbody>
                  {paginatedDrivers.map((d) => {
                    const initials = (d.fullName || d.email || 'D')[0].toUpperCase();
                    const photo = d.photoUrl || userPhotos[d.uid];
                    const isApproved = d.approvalStatus.toLowerCase() === 'approved';
                    const isRejected = d.approvalStatus.toLowerCase() === 'rejected';

                    return (
                      <tr key={d.uid}>
                        <td>
                          <div className="table-entity-cell">
                            <AvatarCell
                              photoUrl={photo}
                              name={d.fullName}
                              fallbackLetter={initials}
                              isDriver={true}
                            />
                            <div>
                              <div className="table-entity-title">
                                {d.fullName || '(No name set)'}
                              </div>
                              <div className="table-entity-sub">
                                UID: #{d.uid.slice(0, 8)}...
                              </div>
                            </div>
                          </div>
                        </td>
                        <td>
                          <span style={{ fontSize: '0.875rem', color: 'var(--color-text)' }}>
                            {d.email}
                          </span>
                        </td>
                        <td>
                          <span style={{ 
                            display: 'inline-flex', 
                            alignItems: 'center', 
                            gap: 6, 
                            fontWeight: 700, 
                            fontSize: '0.75rem', 
                            textTransform: 'uppercase',
                            color: getTierBadgeColor(d.tier),
                            background: 'var(--color-bg-alt)',
                            padding: '4px 12px',
                            borderRadius: 'var(--radius-full)',
                            border: '1px solid var(--color-border)'
                          }}>
                            ★ {d.tier}
                          </span>
                        </td>
                        <td>
                          <span className={`status-pill ${
                            isApproved 
                              ? 'status-pill--success' 
                              : isRejected 
                              ? 'status-pill--danger' 
                              : 'status-pill--warning'
                          }`}>
                            {d.approvalStatus}
                          </span>
                        </td>
                        <td style={{ textAlign: 'right' }}>
                          <Link to={`/admin/drivers/${d.uid}`} className="btn-table-action btn-table-action--primary">
                            View Profile
                          </Link>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
          )
        )}

        {/* Circular Pagination matching orders.png */}
        {totalItems > 0 && (
          <div className="table-pagination">
            <span>
              Showing {Math.min(totalItems, startIndex + 1)} to {Math.min(totalItems, startIndex + pageSize)} of {totalItems} {tab}
            </span>
            <div className="table-pagination__controls">
              <button
                type="button"
                className="pagination-circle-btn"
                disabled={currentPage === 1}
                onClick={() => setCurrentPage(p => Math.max(1, p - 1))}
                aria-label="Previous Page"
              >
                ‹
              </button>
              {Array.from({ length: Math.min(5, totalPages) }, (_, i) => {
                const pageNum = i + 1;
                return (
                  <button
                    key={pageNum}
                    type="button"
                    className={`pagination-circle-btn ${currentPage === pageNum ? 'active' : ''}`}
                    onClick={() => setCurrentPage(pageNum)}
                  >
                    {pageNum}
                  </button>
                );
              })}
              {totalPages > 5 && <span style={{ padding: '0 4px' }}>...</span>}
              <button
                type="button"
                className="pagination-circle-btn"
                disabled={currentPage >= totalPages}
                onClick={() => setCurrentPage(p => Math.min(totalPages, p + 1))}
                aria-label="Next Page"
              >
                ›
              </button>
            </div>
          </div>
        )}
        {/* Customer Details Modal */}
        {selectedCustomer && (
          <div
            style={{
              position: 'fixed',
              inset: 0,
              background: 'rgba(15,23,42,0.5)',
              backdropFilter: 'blur(8px)',
              WebkitBackdropFilter: 'blur(8px)',
              display: 'grid',
              placeItems: 'center',
              zIndex: 1000,
              padding: 'var(--space-4)',
            }}
            role="dialog"
            aria-modal
          >
            <div
              className="card"
              style={{
                maxWidth: 440,
                width: '100%',
                borderRadius: 'var(--radius-xl)',
                boxShadow: '0 20px 40px rgba(0,0,0,0.2)',
              }}
            >
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 'var(--space-4)' }}>
                <h3 style={{ margin: 0, fontSize: '1.2rem', fontWeight: 800 }}>👤 Customer Profile</h3>
                <button
                  type="button"
                  className="btn btn--ghost"
                  style={{ padding: '4px 10px', fontSize: '1rem', borderRadius: 'var(--radius-full)' }}
                  onClick={() => setSelectedCustomer(null)}
                >
                  ✕
                </button>
              </div>

              <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', textAlign: 'center', marginBottom: 'var(--space-4)' }}>
                <div
                  style={{
                    width: 76,
                    height: 76,
                    borderRadius: '50%',
                    overflow: 'hidden',
                    background: 'linear-gradient(135deg, var(--color-primary), #059669)',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    boxShadow: '0 4px 12px rgba(0,0,0,0.12)',
                    border: '3px solid var(--color-surface)',
                    marginBottom: 12,
                  }}
                >
                  {(selectedCustomer.photoUrl || userPhotos[selectedCustomer.uid]) ? (
                    <img
                      src={selectedCustomer.photoUrl || userPhotos[selectedCustomer.uid]}
                      alt={selectedCustomer.fullName || 'Customer'}
                      style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                      onError={(e) => {
                        (e.currentTarget as HTMLImageElement).style.display = 'none';
                      }}
                    />
                  ) : (
                    <span style={{ fontSize: '1.85rem', fontWeight: 800, color: '#fff' }}>
                      {(selectedCustomer.fullName || selectedCustomer.email || 'R')[0]?.toUpperCase()}
                    </span>
                  )}
                </div>

                <h4 style={{ margin: '0 0 4px 0', fontSize: '1.15rem', fontWeight: 800 }}>
                  {selectedCustomer.fullName || '(No name set)'}
                </h4>
                <span className="muted" style={{ fontSize: '0.85rem' }}>
                  {selectedCustomer.email}
                </span>
              </div>

              <div style={{ background: 'var(--color-bg-alt)', borderRadius: 'var(--radius-lg)', padding: '16px', display: 'grid', gap: 12 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.85rem' }}>
                  <span className="muted" style={{ fontWeight: 600 }}>Phone:</span>
                  <span style={{ fontWeight: 600 }}>{selectedCustomer.phone || 'Not provided'}</span>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.85rem' }}>
                  <span className="muted" style={{ fontWeight: 600 }}>Wallet Balance:</span>
                  <span style={{ fontWeight: 800, color: '#15803d' }}>₦{selectedCustomer.walletBalance.toLocaleString('en-NG')}</span>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.85rem' }}>
                  <span className="muted" style={{ fontWeight: 600 }}>Registered:</span>
                  <span>{selectedCustomer.createdAtMs ? new Date(selectedCustomer.createdAtMs).toLocaleString('en-NG') : 'Active Customer'}</span>
                </div>
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: '0.85rem' }}>
                  <span className="muted" style={{ fontWeight: 600 }}>Account UID:</span>
                  <span style={{ fontFamily: 'monospace', fontSize: '0.8rem' }}>{selectedCustomer.uid}</span>
                </div>
              </div>

              <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: 'var(--space-4)' }}>
                <button
                  type="button"
                  className="btn btn--primary"
                  style={{ borderRadius: 'var(--radius-full)', padding: '8px 22px' }}
                  onClick={() => setSelectedCustomer(null)}
                >
                  Close
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}

function AvatarCell({
  photoUrl,
  name,
  fallbackLetter,
  isDriver,
}: {
  photoUrl?: string;
  name?: string;
  fallbackLetter: string;
  isDriver?: boolean;
}) {
  const [imageFailed, setImageFailed] = useState(false);

  useEffect(() => {
    setImageFailed(false);
  }, [photoUrl]);

  const showImage = Boolean(photoUrl && photoUrl.trim() && !imageFailed);

  return (
    <div
      className="table-avatar table-avatar--circle"
      style={{
        overflow: 'hidden',
        position: 'relative',
        width: 42,
        height: 42,
        borderRadius: '50%',
        flexShrink: 0,
        display: 'flex',
        alignItems: 'center',
        justifyContent: 'center',
        background: isDriver
          ? 'rgba(59, 130, 246, 0.12)'
          : 'rgba(22, 163, 74, 0.12)',
        color: isDriver ? '#2563eb' : '#15803d',
        border: isDriver
          ? '1px solid rgba(59, 130, 246, 0.25)'
          : '1px solid rgba(22, 163, 74, 0.25)',
      }}
    >
      {showImage ? (
        <img
          src={photoUrl}
          alt={name || 'Profile'}
          style={{
            width: '100%',
            height: '100%',
            objectFit: 'cover',
            display: 'block',
          }}
          onError={() => setImageFailed(true)}
          loading="lazy"
        />
      ) : (
        <span style={{ fontWeight: 800, fontSize: '0.95rem' }}>{fallbackLetter}</span>
      )}
    </div>
  );
}

