import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import './website.css';

export function AccountDeletion() {
  const [navOpen, setNavOpen] = useState(false);
  const [theme, setTheme] = useState<'light' | 'dark'>(() => {
    const saved = localStorage.getItem('website-theme');
    if (saved === 'light' || saved === 'dark') return saved;
    const systemDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    return systemDark ? 'dark' : 'light';
  });

  useEffect(() => {
    localStorage.setItem('website-theme', theme);
  }, [theme]);

  const toggleTheme = () => {
    setTheme(prev => prev === 'light' ? 'dark' : 'light');
  };

  useEffect(() => {
    // TOC active highlight scroll spy logic
    const tocLinks = document.querySelectorAll('#toc-list a');
    const sections = document.querySelectorAll('.prose-section[id]');
    
    if (tocLinks.length && sections.length) {
      const tocObserver = new IntersectionObserver((entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            tocLinks.forEach((l) => l.classList.remove('active'));
            const active = document.querySelector(`#toc-list a[href="#${entry.target.id}"]`);
            if (active) active.classList.add('active');
          }
        });
      }, { rootMargin: '-80px 0px -60% 0px' });
      
      sections.forEach((s) => tocObserver.observe(s));
      return () => tocObserver.disconnect();
    }
  }, []);

  return (
    <div className={`website-root legal-body ${theme === 'dark' ? 'dark' : ''}`}>
      {/* NAVBAR */}
      <nav className="navbar scrolled" id="navbar">
        <div className="container">
          <div className="navbar-inner">
            <Link to="/" className="navbar-logo">Ca<span>Ride</span></Link>
            <button
              className={`hamburger ${navOpen ? 'open' : ''}`}
              onClick={() => setNavOpen(!navOpen)}
              aria-label="Toggle menu"
              aria-expanded={navOpen}
            >
              <span></span><span></span><span></span>
            </button>
            <ul className={`navbar-links ${navOpen ? 'open' : ''}`} id="nav-links">
              <li><Link to="/" onClick={() => setNavOpen(false)}>Home</Link></li>
              <li><Link to="/privacy-policy" onClick={() => setNavOpen(false)}>Privacy Policy</Link></li>
              <li><Link to="/account-deletion" className="active" onClick={() => setNavOpen(false)}>Account Deletion</Link></li>
              <li><Link to="/support" className="nav-cta" onClick={() => setNavOpen(false)}>Contact Support</Link></li>
            </ul>
          </div>
        </div>
      </nav>

      {/* HEADER HERO */}
      <header className="page-hero">
        <div className="container">
          <nav className="breadcrumb" aria-label="Breadcrumb">
            <Link to="/">Home</Link><span className="bc-sep">›</span><span>Account Deletion</span>
          </nav>
          <span className="label label-yellow" style={{ marginBottom: '16px' }}>
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14H6L5 6"/><path d="M10 11v6M14 11v6"/><path d="M9 6V4h6v2"/></svg>
            Account Management
          </span>
          <h1>Account Deletion</h1>
          <p>We respect your right to control your data. Here's everything you need to know about deleting your CaRide account.</p>
          <div className="hero-meta">
            <span className="hero-meta-item">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
              Takes ~2 minutes
            </span>
            <span className="hero-meta-item">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
              NDPA 2023 Compliant
            </span>
            <span className="hero-meta-item">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><rect x="3" y="4" width="18" height="18" rx="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>
              Updated: June 19, 2026
            </span>
          </div>
        </div>
      </header>

      {/* MAIN LEGAL CONTENT */}
      <main>
        <section className="section" style={{ paddingTop: '60px' }}>
          <div className="container">
            <div className="legal-layout">
              <aside>
                <div className="toc-card">
                  <p className="toc-title">On This Page</p>
                  <ul className="toc-list" id="toc-list">
                    <li><a href="#overview">Overview</a></li>
                    <li><a href="#before-delete">Before You Delete</a></li>
                    <li><a href="#in-app">Delete In-App</a></li>
                    <li><a href="#by-email">Delete by Email</a></li>
                    <li><a href="#what-deleted">What Gets Deleted</a></li>
                    <li><a href="#what-retained">What Is Retained</a></li>
                    <li><a href="#wallet">Wallet Balance</a></li>
                    <li><a href="#reactivation">Reactivation</a></li>
                    <li><a href="#contact">Contact Us</a></li>
                  </ul>
                </div>
              </aside>

              <article className="prose-card">
                <div className="prose-inner">
                  <div className="prose-section" id="overview">
                    <h2 className="prose-title">Overview</h2>
                    <p>CaRide is committed to your right to data privacy and control. You may permanently delete your CaRide account at any time — directly within the app or by contacting our support team. Once confirmed, your account is deactivated immediately and permanently removed within <strong>30 days</strong>.</p>
                  </div>

                  <hr className="prose-divider" />

                  <div className="prose-section" id="before-delete">
                    <h2 className="prose-title">Before You Delete</h2>
                    <p>Please take care of the following before initiating deletion:</p>
                    <div className="steps-grid">
                      <div className="step-card">
                        <div className="num">1</div>
                        <h4>Complete Active Trips</h4>
                        <p>No ongoing or accepted rides. Deletion is blocked while a trip is in progress.</p>
                      </div>
                      <div className="step-card">
                        <div className="num">2</div>
                        <h4>Withdraw Wallet Balance</h4>
                        <p>Funds cannot be recovered after deletion. Withdraw to your bank first.</p>
                      </div>
                      <div className="step-card">
                        <div className="num">3</div>
                        <h4>Resolve Disputes</h4>
                        <p>Open disputes, rating appeals, or unresolved refund requests must be settled first.</p>
                      </div>
                      <div className="step-card">
                        <div className="num">4</div>
                        <h4>Download Your Data</h4>
                        <p>Request a copy of your data before deletion via <a href="mailto:privacy@caride.ng">privacy@caride.ng</a>.</p>
                      </div>
                    </div>
                    <div className="warn-box" style={{ marginTop: '8px' }}>
                      <span style={{ display: 'flex', alignItems: 'center', flexShrink: 0, color: 'var(--yellow)' }}>
                        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>
                      </span>
                      <p><strong>Permanent & irreversible.</strong> Once processed, you cannot recover your account, ride history, saved locations, or wallet balance.</p>
                    </div>
                  </div>

                  <hr className="prose-divider" />

                  <div className="prose-section" id="in-app">
                    <h2 className="prose-title">How to Delete In-App</h2>
                    <p>The fastest way — directly from the CaRide app:</p>
                    <div className="steps-grid" style={{ gridTemplateColumns: 'repeat(auto-fit,minmax(170px,1fr))' }}>
                      <div className="step-card">
                        <div className="num">1</div>
                        <h4>Open the App</h4>
                        <p>Log into the account you wish to delete.</p>
                      </div>
                      <div className="step-card">
                        <div className="num">2</div>
                        <h4>Go to Account</h4>
                        <p>Tap the <strong>Account</strong> tab on the bottom navigation.</p>
                      </div>
                      <div className="step-card">
                        <div className="num">3</div>
                        <h4>Open Settings</h4>
                        <p>Scroll to <strong>Settings → Privacy &amp; Security</strong>.</p>
                      </div>
                      <div className="step-card">
                        <div className="num">4</div>
                        <h4>Delete Account</h4>
                        <p>Tap <strong>"Delete My Account"</strong> and follow the prompts.</p>
                      </div>
                      <div className="step-card">
                        <div className="num">5</div>
                        <h4>Confirm via OTP</h4>
                        <p>An OTP is sent to your registered phone number to confirm.</p>
                      </div>
                      <div className="step-card">
                        <div className="num">6</div>
                        <h4>Done</h4>
                        <p>Account deactivated immediately. Permanently deleted within <strong>30 days</strong>.</p>
                      </div>
                    </div>
                  </div>

                  <hr className="prose-divider" />

                  <div className="prose-section" id="by-email">
                    <h2 className="prose-title">Delete by Email Request</h2>
                    <p>If you can't access the app, submit a deletion request by email:</p>
                    <div className="info-box">
                      <span style={{ display: 'flex', alignItems: 'center', flexShrink: 0, color: 'var(--green)' }}>
                        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/><polyline points="22,6 12,13 2,6"/></svg>
                      </span>
                      <div>
                        <p><strong>Email:</strong> <a href="mailto:privacy@caride.ng">privacy@caride.ng</a></p>
                        <p><strong>Subject:</strong> Account Deletion Request</p>
                        <p style={{ marginTop: '8px' }}><strong>Include:</strong></p>
                        <ul style={{ marginTop: '6px', paddingLeft: '18px' }}>
                          <li>Your full name</li>
                          <li>Registered email or phone number</li>
                          <li>Reason for deletion (optional)</li>
                          <li>Confirmation that you understand deletion is irreversible</li>
                        </ul>
                      </div>
                    </div>
                    <p>We'll verify your identity and respond within <strong>5 business days</strong>. Your account will be deactivated and deleted within 30 days of confirmation.</p>
                  </div>

                  <hr className="prose-divider" />

                  <div className="prose-section" id="what-deleted">
                    <h2 className="prose-title">What Gets Deleted</h2>
                    <ul>
                      <li>Name, email address, and phone number</li>
                      <li>Profile photo and personal preferences</li>
                      <li>Saved locations and favourite addresses</li>
                      <li>Saved payment methods and tokenised card data</li>
                      <li>Wallet balance (ensure withdrawal before deletion)</li>
                      <li>In-app chat messages and support ticket history</li>
                      <li>Notification preferences and device tokens</li>
                      <li>Referral codes and reward credits</li>
                      <li>Driver profile, vehicle information, and uploaded documents (subject to retention requirements)</li>
                    </ul>
                  </div>

                  <hr className="prose-divider" />

                  <div className="prose-section" id="what-retained">
                    <h2 className="prose-title">What Is Retained After Deletion</h2>
                    <p>Certain data must be retained to comply with legal and financial obligations. This data is anonymised where possible and never used for marketing:</p>
                    <ul>
                      <li><strong>Transaction Records (3 years)</strong> — required for financial auditing and tax compliance.</li>
                      <li><strong>Safety &amp; Fraud Logs (6 months)</strong> — anonymised logs of flags or violations to protect other users.</li>
                      <li><strong>Driver Verification Documents (5 years)</strong> — required by Nigerian regulatory obligations for transport operators.</li>
                      <li><strong>Anonymised Trip Data (indefinitely)</strong> — aggregated statistics that cannot be linked to you individually.</li>
                    </ul>
                  </div>

                  <hr className="prose-divider" />

                  <div className="prose-section" id="wallet">
                    <h2 className="prose-title">Your Wallet Balance</h2>
                    <p>Your CaRide wallet balance is <strong>non-transferable and non-refundable</strong> after deletion.</p>
                    <p>Withdraw before deleting: <strong>Account → Wallet → Withdraw Funds</strong>. Allow up to 3 business days for the transfer.</p>
                    <div className="warn-box">
                      <span style={{ display: 'flex', alignItems: 'center', flexShrink: 0, color: 'var(--yellow)' }}>
                        <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>
                      </span>
                      <p>Any wallet balance remaining at the time of deletion will be <strong>forfeited</strong>. If you believe you are owed a refund, contact <a href="mailto:support@caride.ng">support@caride.ng</a> before proceeding.</p>
                    </div>
                  </div>

                  <hr className="prose-divider" />

                  <div className="prose-section" id="reactivation">
                    <h2 className="prose-title">Reactivation</h2>
                    <p>After confirming deletion, you have a <strong>30-day grace period</strong> to cancel the request. During this period, your account is deactivated but not yet permanently erased.</p>
                    <p>To cancel within the grace period, email <a href="mailto:support@caride.ng">support@caride.ng</a> with subject: <strong>"Cancel Account Deletion Request"</strong> and your registered email or phone number.</p>
                    <p>After 30 days, deletion is permanent and irreversible. A new account would need to be created to use CaRide again.</p>
                  </div>

                  <hr className="prose-divider" />

                  <div className="prose-section" id="contact">
                    <h2 className="prose-title">Need Help?</h2>
                    <ul>
                      <li><strong>Privacy Requests:</strong> <a href="mailto:privacy@caride.ng">privacy@caride.ng</a></li>
                      <li><strong>General Support:</strong> <a href="mailto:support@caride.ng">support@caride.ng</a></li>
                      <li><strong>Response Time:</strong> Within 5 business days for deletion; 24–48 hrs for general support.</li>
                    </ul>
                  </div>

                  <div className="contact-cta">
                    <h3>Ready to delete your account?</h3>
                    <p>Use the in-app flow for the fastest experience, or email us and we'll handle it for you.</p>
                    <a href="mailto:privacy@caride.ng">
                      <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/><polyline points="22,6 12,13 2,6"/></svg>
                      Submit Deletion Request
                    </a>
                  </div>
                </div>
              </article>
            </div>
          </div>
        </section>
      </main>

      {/* FOOTER */}
      <footer className="footer">
        <div className="container">
          <div className="footer-grid">
            <div>
              <div className="footer-logo">Ca<span>Ride</span></div>
              <p className="footer-desc">Nigeria's smart ride-hailing platform — fast, safe, and affordable rides nationwide.</p>
            </div>
            <div className="footer-col">
              <h4>Company</h4>
              <ul className="footer-links">
                <li><Link to="/">Home</Link></li>
                <li><Link to="/support">Contact Support</Link></li>
              </ul>
            </div>
            <div className="footer-col">
              <h4>Legal</h4>
              <ul className="footer-links">
                <li><Link to="/privacy-policy">Privacy Policy</Link></li>
                <li><Link to="/account-deletion">Account Deletion</Link></li>
              </ul>
            </div>
          </div>
          <div className="footer-bottom">
            <p>&copy; 2025 CaRide Technologies. All rights reserved.</p>
            <ul className="footer-bottom-links">
              <li><Link to="/privacy-policy">Privacy</Link></li>
              <li><Link to="/account-deletion">Account Deletion</Link></li>
              <li><Link to="/support">Support</Link></li>
            </ul>
          </div>
        </div>
      </footer>

      {/* FLOATING THEME TOGGLE */}
      <button
        type="button"
        className="theme-toggle-floating"
        onClick={toggleTheme}
        aria-label="Toggle light/dark theme"
      >
        {theme === 'light' ? (
          <svg fill="none" stroke="currentColor" strokeWidth="2.5" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" d="M21.752 15.002A9.718 9.718 0 0118 15.75c-5.385 0-9.75-4.365-9.75-9.75 0-1.33.266-2.597.748-3.752A9.753 9.753 0 003 11.25C3 16.635 7.365 21 12.75 21a9.753 9.753 0 009.002-5.998z" />
          </svg>
        ) : (
          <svg fill="none" stroke="currentColor" strokeWidth="2.5" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" d="M12 3v2.25m0 13.5V21m9.75-9h-2.25M4.25 12H2M18.364 5.636l-1.591 1.591M8.227 15.773l-1.591 1.591M18.364 18.364l-1.591-1.591M8.227 8.227L6.636 6.636M12 9a3 3 0 100 6 3 3 0 000-6z" />
          </svg>
        )}
      </button>
    </div>
  );
}
