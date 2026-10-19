import { useState, useEffect } from 'react';
import { NavLink, Outlet, useLocation } from 'react-router-dom';
import { collection, query, where, onSnapshot, doc } from 'firebase/firestore';
import { db, auth } from '../config/firebase';
import { useAuth } from '../auth/useAuth';
import logo from '../assets/caride_logo_2.png';

const sections = [
  {
    title: 'General',
    items: [
      { to: '/staff/dashboard', label: 'Staff Dashboard', icon: (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <rect x="2" y="3" width="20" height="14" rx="2" ry="2" />
          <line x1="8" y1="21" x2="16" y2="21" />
          <line x1="12" y1="17" x2="12" y2="21" />
        </svg>
      )},
      { to: '/admin/dashboard', label: 'Overview', icon: (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <rect x="3" y="3" width="7" height="9" rx="1" />
          <rect x="14" y="3" width="7" height="5" rx="1" />
          <rect x="14" y="12" width="7" height="9" rx="1" />
          <rect x="3" y="16" width="7" height="5" rx="1" />
        </svg>
      )},
      { to: '/admin/users', label: 'Users', icon: (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2" />
          <circle cx="9" cy="7" r="4" />
          <path d="M22 21v-2a4 4 0 0 0-3-3.87" />
          <path d="M16 3.13a4 4 0 0 1 0 7.75" />
        </svg>
      )},
      { to: '/admin/rides', label: 'Rides', icon: (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <rect x="1" y="3" width="15" height="13" rx="2" ry="2" />
          <polygon points="16 8 20 8 23 11 23 16 16 16 16 8" />
          <circle cx="5.5" cy="18.5" r="2.5" />
          <circle cx="18.5" cy="18.5" r="2.5" />
        </svg>
      )},
      { to: '/admin/finance', label: 'Finance', icon: (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <line x1="12" y1="1" x2="12" y2="23" />
          <path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6" />
        </svg>
      )},
      { to: '/admin/withdrawals', label: 'Withdrawals', icon: (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <line x1="7" y1="17" x2="17" y2="7" />
          <polyline points="7 7 17 7 17 17" />
        </svg>
      )},
      { to: '/admin/fraud', label: 'Fraud', icon: (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z" />
          <line x1="12" y1="9" x2="12" y2="13" />
          <line x1="12" y1="17" x2="12.01" y2="17" />
        </svg>
      )},
      { to: '/admin/announcements', label: 'Announcements', icon: (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9M13.73 21a2 2 0 0 1-3.46 0" />
          <path d="M2 10h3M19 10h3M21 14h1M2 14h1" />
        </svg>
      )},
      { to: '/admin/settings', label: 'Settings', icon: (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <circle cx="12" cy="12" r="3" />
          <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z" />
        </svg>
      )},
    ]
  },
  {
    title: 'Drivers',
    items: [
      { to: '/admin/verification-requests', label: 'Verification', icon: (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
        </svg>
      )},
      { to: '/admin/driver-support', label: 'Driver Support', icon: (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <circle cx="12" cy="12" r="10" />
          <circle cx="12" cy="12" r="3" />
          <path d="M12 2v8" />
          <path d="M12 14v8" />
          <path d="M2 12h8" />
          <path d="M14 12h8" />
        </svg>
      )},
      { to: '/admin/driver-tiers', label: 'Driver Tiers', icon: (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <circle cx="12" cy="8" r="7" />
          <polyline points="8.21 13.89 7 23 12 20 17 23 15.79 13.88" />
        </svg>
      )},
      { to: '/admin/driver-referrals', label: 'Driver Referrals', icon: (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
          <circle cx="9" cy="7" r="4" />
          <path d="M23 21v-2a4 4 0 0 0-3-3.87" />
          <path d="M16 3.13a4 4 0 0 1 0 7.75" />
        </svg>
      )},
      { to: '/admin/driver-ratings', label: 'Driver Ratings', icon: (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2" />
        </svg>
      )},
    ]
  },
  {
    title: 'Fleet Partners',
    items: [
      { to: '/admin/fleet-verification', label: 'Fleet Verification', icon: (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <rect x="1" y="3" width="15" height="13" />
          <polygon points="16 8 20 8 23 11 23 16 16 16 16 8" />
          <circle cx="5.5" cy="18.5" r="2.5" />
          <circle cx="18.5" cy="18.5" r="2.5" />
        </svg>
      )},
      { to: '/admin/fleet-support', label: 'Fleet Support', icon: (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
        </svg>
      )},
    ]
  },
  {
    title: 'Customers',
    items: [
      { to: '/admin/customer-support', label: 'Customer Support', icon: (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
        </svg>
      )},
      { to: '/admin/offers', label: 'Special Offers', icon: (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M20.59 13.41l-7.17 7.17a2 2 0 0 1-2.83 0L2 12V2h10l8.59 8.59a2 2 0 0 1 0 2.82z" />
          <line x1="7" y1="7" x2="7.01" y2="7" />
        </svg>
      )},
      { to: '/admin/promotion', label: 'Promotions', icon: (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <polyline points="20 12 20 22 4 22 4 12" />
          <rect x="2" y="7" width="20" height="5" />
          <line x1="12" y1="22" x2="12" y2="7" />
          <path d="M12 7H7.5a2.5 2.5 0 0 1 0-5C11 2 12 7 12 7z" />
          <path d="M12 7h4.5a2.5 2.5 0 0 0 0-5C13 2 12 7 12 7z" />
        </svg>
      )},
      { to: '/admin/for-you', label: 'For You (Blog)', icon: (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M4 19.5A2.5 2.5 0 0 1 6.5 17H20" />
          <path d="M6.5 2H20v20H6.5A2.5 2.5 0 0 1 4 19.5v-15A2.5 2.5 0 0 1 6.5 2z" />
          <line x1="9" y1="7" x2="15" y2="7" />
          <line x1="9" y1="11" x2="15" y2="11" />
        </svg>
      )},
      { to: '/admin/staff-management', label: 'Staff Management', icon: (
        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2" />
          <circle cx="8.5" cy="7" r="4" />
          <polyline points="17 11 19 13 23 9" />
        </svg>
      )},
    ]
  }
];

const allNavItems = sections.flatMap((s) => s.items);

function titleForPath(pathname: string): string {
  if (pathname.includes('/fleet-verification')) return 'Fleet Partner Verification';
  if (pathname.includes('verification-requests')) return 'Verification';
  if (pathname.includes('/drivers/')) return 'Driver Profile';
  if (pathname.includes('/staff/dashboard') || pathname.includes('/staff-dashboard')) return 'Staff Dashboard';
  const hit = allNavItems.find((n) => pathname.startsWith(n.to));
  return hit?.label ?? 'Portal';
}

export function AdminLayout() {
  const { signOut } = useAuth();
  const location = useLocation();
  const title = titleForPath(location.pathname);
  const [collapsed] = useState(false);
  const [mobileOpen, setMobileOpen] = useState(false);
  const [dropdownOpen, setDropdownOpen] = useState(false);

  const [isStaff, setIsStaff] = useState(false);
  const [allowedPages, setAllowedPages] = useState<string[]>([]);

  const [counts, setCounts] = useState<{
    verification: number;
    fleetVerification: number;
    driverSupport: number;
    customerSupport: number;
  }>({
    verification: 0,
    fleetVerification: 0,
    driverSupport: 0,
    customerSupport: 0,
  });

  useEffect(() => {
    const user = auth.currentUser;
    if (!user) return;
    const unsub = onSnapshot(doc(db, 'staff', user.uid), (snap) => {
      if (snap.exists()) {
        setIsStaff(true);
        const data = snap.data();
        setAllowedPages(
          Array.isArray(data.allowedPages)
            ? data.allowedPages
            : ['announcements', 'customer_support', 'driver_support', 'promotion', 'offers', 'verification', 'fleet_verification']
        );
      } else {
        setIsStaff(false);
      }
    });
    return () => unsub();
  }, []);

  useEffect(() => {
    const unsubVerification = onSnapshot(
      query(collection(db, 'drivers'), where('approvalStatus', '==', 'pending')),
      (snap) => {
        setCounts((prev) => ({ ...prev, verification: snap.docs.length }));
      },
      () => {},
    );

    const unsubFleetVerification = onSnapshot(
      query(collection(db, 'fleets'), where('verificationStatus', '==', 'pending')),
      (snap) => {
        setCounts((prev) => ({ ...prev, fleetVerification: snap.docs.length }));
      },
      () => {},
    );

    const unsubSupport = onSnapshot(
      collection(db, 'supportChats'),
      (snap) => {
        let driverCount = 0;
        let customerCount = 0;
        snap.docs.forEach((docSnap) => {
          const data = docSnap.data();
          const status = (data.status as string) || 'active';
          const userType = (data.userType as string) || 'driver';
          if (status !== 'resolved') {
            if (userType === 'customer') {
              customerCount++;
            } else {
              driverCount++;
            }
          }
        });
        setCounts((prev) => ({
          ...prev,
          driverSupport: driverCount,
          customerSupport: customerCount,
        }));
      },
      () => {},
    );

    return () => {
      unsubVerification();
      unsubFleetVerification();
      unsubSupport();
    };
  }, []);

  // Auto-close sidebar on route change
  useEffect(() => {
    setMobileOpen(false);
  }, [location.pathname]);

  function cycleTheme() {
    const root = document.documentElement;
    if (root.dataset.theme === 'dark') {
      delete root.dataset.theme;
    } else {
      root.dataset.theme = 'dark';
    }
  }

  const itemBadges: Record<string, number> = {
    '/admin/verification-requests': counts.verification,
    '/admin/fleet-verification': counts.fleetVerification,
    '/admin/driver-support': counts.driverSupport,
    '/admin/customer-support': counts.customerSupport,
  };

  const routeToPageKey: Record<string, string> = {
    '/admin/announcements': 'announcements',
    '/admin/customer-support': 'customer_support',
    '/admin/driver-support': 'driver_support',
    '/admin/promotion': 'promotion',
    '/admin/offers': 'offers',
    '/admin/verification-requests': 'verification',
    '/admin/fleet-verification': 'fleet_verification',
  };

  const filteredSections = sections.map((sec) => ({
    ...sec,
    items: sec.items.filter((item) => {
      if (isStaff) {
        if (item.to === '/admin/dashboard') return false; // Staff sees Staff Dashboard instead of Admin Overview
        if (item.to === '/staff/dashboard' || item.to === '/admin/staff-dashboard') return true;
        const key = routeToPageKey[item.to];
        return key ? allowedPages.includes(key) : false;
      }
      // Admins see everything except dedicated /staff/dashboard link
      if (item.to === '/staff/dashboard') return false;
      return true;
    }),
  })).filter((sec) => sec.items.length > 0);

  return (
    <div className="app-shell">
      {/* Backdrop overlay for mobile drawer */}
      {mobileOpen && (
        <div
          className="app-shell__backdrop"
          onClick={() => setMobileOpen(false)}
          aria-hidden="true"
          style={{
            position: 'fixed',
            inset: 0,
            background: 'rgba(0, 0, 0, 0.4)',
            backdropFilter: 'blur(4px)',
            WebkitBackdropFilter: 'blur(4px)',
            zIndex: 95,
          }}
        />
      )}

      {/* Sidebar / Navigation Rail */}
      <aside className={`app-shell__rail ${collapsed ? 'collapsed' : ''} ${mobileOpen ? 'mobile-open' : ''}`}>
        <div className="app-shell__brand">
          <img src={logo} alt="CaRide Logo" style={{ height: 32, width: 32, objectFit: 'contain', borderRadius: 'var(--radius-md)' }} />
          <span className="app-shell__brand-text">{isStaff ? 'CaRide Staff' : 'CaRide Admin'}</span>
        </div>
        
        <nav className="app-shell__nav" aria-label="Main Navigation">
          {filteredSections.map((sec) => (
            <div key={sec.title} className="app-shell__nav-section">
              {!collapsed && <div className="app-shell__nav-section-title">{sec.title}</div>}
              <div className="app-shell__nav-section-items">
                {sec.items.map((item) => {
                  const badgeVal = itemBadges[item.to];
                  return (
                    <NavLink
                      key={item.to}
                      to={item.to}
                      onClick={() => setMobileOpen(false)}
                      className={({ isActive }) => (isActive ? 'active' : '')}
                    >
                      {item.icon}
                      <span>{item.label}</span>
                      {badgeVal !== undefined && badgeVal > 0 && (
                        <span className="nav-badge">{badgeVal}</span>
                      )}
                    </NavLink>
                  );
                })}
              </div>
            </div>
          ))}
        </nav>

        <div className="app-shell__rail-footer">
          <button type="button" className="btn btn--ghost" onClick={cycleTheme} style={{ width: '100%', justifyContent: 'flex-start' }}>
            <svg style={{ width: 16, height: 16 }} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <circle cx="12" cy="12" r="5" />
              <path d="M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42" />
            </svg>
            {!collapsed && <span style={{ marginLeft: 8 }}>Toggle Theme</span>}
          </button>
          <button type="button" className="btn btn--logout" onClick={signOut} style={{ width: '100%', justifyContent: 'flex-start' }}>
            <svg style={{ width: 16, height: 16 }} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
              <path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4M16 17l5-5-5-5M21 12H9" />
            </svg>
            {!collapsed && <span style={{ marginLeft: 8 }}>Sign out</span>}
          </button>
        </div>
      </aside>

      {/* Main Panel */}
      <div className="app-shell__main">
        <header className="app-topbar">
          <div className="app-topbar__left">
            <button
              type="button"
              className="mobile-menu-btn"
              onClick={() => setMobileOpen(!mobileOpen)}
              aria-label="Toggle Navigation Menu"
            >
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" style={{ width: 22, height: 22 }}>
                <line x1="3" y1="12" x2="21" y2="12" />
                <line x1="3" y1="6" x2="21" y2="6" />
                <line x1="3" y1="18" x2="21" y2="18" />
              </svg>
            </button>
            
            <div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                <h1 style={{ margin: 0, fontSize: '1.25rem', fontWeight: 800, letterSpacing: '-0.02em' }}>
                  {new Date().getHours() < 12 ? 'Good Morning' : new Date().getHours() < 18 ? 'Good Afternoon' : 'Good Evening'}, {isStaff ? 'Staff Member' : 'Admin'}
                </h1>
                <span className="status-pill status-pill--completed desktop-only" style={{ padding: '3px 10px', fontSize: '0.7rem' }}>
                  <span style={{ width: 6, height: 6, borderRadius: '50%', background: '#16a34a', display: 'inline-block' }} />
                  Operational
                </span>
              </div>
              <p className="desktop-only" style={{ margin: '2px 0 0 0', fontSize: '0.78rem', color: 'var(--color-text-muted)' }}>
                {title} • CaRide Command Center Nigeria
              </p>
            </div>
          </div>

          <div className="app-topbar__actions">
            {/* Quick Actions Dropdown */}
            <div className="quick-action-menu">
              <button
                type="button"
                className="icon-btn"
                onClick={() => setDropdownOpen(!dropdownOpen)}
                aria-label="Notifications"
                style={{ borderRadius: '50%' }}
              >
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" style={{ width: 18, height: 18 }}>
                  <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9M13.73 21a2 2 0 0 1-3.46 0" />
                </svg>
                {(counts.verification + counts.fleetVerification + counts.driverSupport + counts.customerSupport) > 0 && (
                  <span className="icon-btn__badge" />
                )}
              </button>

              {dropdownOpen && (
                <div className="dropdown-pane" style={{ borderRadius: 16, padding: '8px 0', minWidth: 260 }}>
                  <div style={{ padding: '8px 16px', fontWeight: 700, fontSize: '0.85rem', borderBottom: '1px solid var(--color-border)' }}>
                    Action Items
                  </div>
                  {counts.verification > 0 && (
                    <NavLink to="/admin/verification-requests" onClick={() => setDropdownOpen(false)}>
                      <span className="status-pill status-pill--pending" style={{ fontSize: '0.7rem' }}>{counts.verification}</span>
                      <span style={{ marginLeft: 8 }}>Driver verifications pending</span>
                    </NavLink>
                  )}
                  {counts.fleetVerification > 0 && (
                    <NavLink to="/admin/fleet-verification" onClick={() => setDropdownOpen(false)}>
                      <span className="status-pill status-pill--pending" style={{ fontSize: '0.7rem' }}>{counts.fleetVerification}</span>
                      <span style={{ marginLeft: 8 }}>Fleet verifications pending</span>
                    </NavLink>
                  )}
                  {counts.driverSupport > 0 && (
                    <NavLink to="/admin/driver-support" onClick={() => setDropdownOpen(false)}>
                      <span className="status-pill status-pill--enroute" style={{ fontSize: '0.7rem' }}>{counts.driverSupport}</span>
                      <span style={{ marginLeft: 8 }}>Driver support tickets</span>
                    </NavLink>
                  )}
                  {counts.customerSupport > 0 && (
                    <NavLink to="/admin/customer-support" onClick={() => setDropdownOpen(false)}>
                      <span className="status-pill status-pill--enroute" style={{ fontSize: '0.7rem' }}>{counts.customerSupport}</span>
                      <span style={{ marginLeft: 8 }}>Customer support tickets</span>
                    </NavLink>
                  )}
                  {counts.verification === 0 && counts.fleetVerification === 0 && counts.driverSupport === 0 && counts.customerSupport === 0 && (
                    <div style={{ padding: '12px 16px', fontSize: '0.825rem', color: 'var(--color-text-muted)' }}>
                      All systems normal. No pending urgent items.
                    </div>
                  )}
                </div>
              )}
            </div>

            <div className="admin-avatar-menu" style={{ borderRadius: 'var(--radius-full)', padding: '4px 12px 4px 4px' }}>
              <div className="admin-avatar">{isStaff ? 'ST' : 'AD'}</div>
              <div style={{ fontSize: '0.85rem', fontWeight: 700 }}>{isStaff ? 'Staff' : 'Admin'}</div>
            </div>
          </div>
        </header>

        <main className="app-content">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
