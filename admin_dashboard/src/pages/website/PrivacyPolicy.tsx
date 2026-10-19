import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import './website.css';

export function PrivacyPolicy() {
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
              <li><Link to="/privacy-policy" className="active" onClick={() => setNavOpen(false)}>Privacy Policy</Link></li>
              <li><Link to="/account-deletion" onClick={() => setNavOpen(false)}>Account Deletion</Link></li>
              <li><Link to="/support" className="nav-cta" onClick={() => setNavOpen(false)}>Contact Support</Link></li>
            </ul>
          </div>
        </div>
      </nav>

      {/* HEADER HERO */}
      <header className="page-hero">
        <div className="container">
          <nav className="breadcrumb" aria-label="Breadcrumb">
            <Link to="/">Home</Link><span className="bc-sep">›</span><span>Privacy Policy</span>
          </nav>
          <span className="label label-green" style={{ marginBottom: '16px' }}>
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>
            Legal Document
          </span>
          <h1>Privacy Policy</h1>
          <p>We are committed to protecting your personal data and your right to privacy.</p>
          <div className="hero-meta">
            <span className="hero-meta-item">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><rect x="3" y="4" width="18" height="18" rx="2"/><line x1="16" y1="2" x2="16" y2="6"/><line x1="8" y1="2" x2="8" y2="6"/><line x1="3" y1="10" x2="21" y2="10"/></svg>
              Effective: June 1, 2025
            </span>
            <span className="hero-meta-item">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>
              Updated: June 19, 2026
            </span>
            <span className="hero-meta-item">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M12 20h9"/><path d="M16.5 3.5a2.121 2.121 0 013 3L7 19l-4 1 1-4L16.5 3.5z"/></svg>
              ~8 min read
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
                    <li><a href="#overview">1. Overview</a></li>
                    <li><a href="#information-we-collect">2. Information We Collect</a></li>
                    <li><a href="#how-we-use">3. How We Use Your Data</a></li>
                    <li><a href="#sharing">4. Sharing of Data</a></li>
                    <li><a href="#location">5. Location Data</a></li>
                    <li><a href="#data-retention">6. Data Retention</a></li>
                    <li><a href="#security">7. Data Security</a></li>
                    <li><a href="#your-rights">8. Your Rights</a></li>
                    <li><a href="#children">9. Children's Privacy</a></li>
                    <li><a href="#third-party">10. Third-Party Services</a></li>
                    <li><a href="#changes">11. Policy Changes</a></li>
                    <li><a href="#contact">12. Contact Us</a></li>
                  </ul>
                </div>
              </aside>

              <article className="prose-card">
                <div className="prose-inner">
                  <div className="info-box">
                    <span style={{ display: 'flex', alignItems: 'center', flexShrink: 0, color: 'var(--green)' }}>
                      <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0110 0v4"/></svg>
                    </span>
                    <p><strong>Your privacy matters.</strong> This Privacy Policy explains how CaRide ("we", "our", "us") collects, uses, shares, and protects your information. By using CaRide, you agree to the terms described here.</p>
                  </div>

                  <div className="prose-section" id="overview">
                    <h2 className="prose-title">1. Overview</h2>
                    <p>CaRide is a ride-hailing platform connecting passengers ("Customers") with independent drivers ("Drivers") across Nigeria. We operate the Customer mobile application, Driver mobile application, and supporting backend infrastructure.</p>
                    <p>This Privacy Policy applies to all users and complies with the Nigeria Data Protection Regulation (NDPR) and the Nigeria Data Protection Act (NDPA) 2023.</p>
                  </div>

                  <hr className="prose-divider" />

                  <div className="prose-section" id="information-we-collect">
                    <h2 className="prose-title">2. Information We Collect</h2>
                    <h3>2.1 Information You Provide</h3>
                    <ul>
                      <li><strong>Account Registration:</strong> Name, email address, phone number, and password.</li>
                      <li><strong>Profile:</strong> Profile photo, gender (optional), and contact preferences.</li>
                      <li><strong>Driver Onboarding:</strong> Government-issued ID, driver's licence, vehicle registration documents, vehicle details, and bank account details.</li>
                      <li><strong>Payment Information:</strong> Card details (tokenised via PCI-DSS compliant processors), bank transfer info.</li>
                      <li><strong>Communications:</strong> Messages sent via in-app chat or to our support team.</li>
                    </ul>
                    <h3>2.2 Information Generated Through Use</h3>
                    <ul>
                      <li><strong>Location Data:</strong> Precise GPS location while the app is actively in use (foreground only for Customers).</li>
                      <li><strong>Ride Data:</strong> Pickup/destination, route, duration, distance, fare, and status updates.</li>
                      <li><strong>Device Information:</strong> Device type, OS version, unique identifiers, IP address, and app version.</li>
                      <li><strong>Usage Data:</strong> Feature interactions, session times, error logs, and crash reports.</li>
                      <li><strong>Transaction Records:</strong> Wallet balances, payment history, and commission records.</li>
                      <li><strong>Ratings &amp; Reviews:</strong> Ratings and feedback you give or receive.</li>
                    </ul>
                    <h3>2.3 Information from Third Parties</h3>
                    <ul>
                      <li>Payment verification data from processors (TransactPay).</li>
                      <li>Map and routing data from Google Maps Platform.</li>
                      <li>Identity verification data from KYC providers (for Drivers).</li>
                    </ul>
                  </div>

                  <hr className="prose-divider" />

                  <div className="prose-section" id="how-we-use">
                    <h2 className="prose-title">3. How We Use Your Data</h2>
                    <ul>
                      <li><strong>Service Delivery:</strong> Match Customers with Drivers, process requests, enable navigation, and complete trips.</li>
                      <li><strong>Payments:</strong> Process payments, manage wallets, disburse driver earnings.</li>
                      <li><strong>Account Management:</strong> Create, verify, and manage accounts; authenticate identity on login.</li>
                      <li><strong>Safety &amp; Security:</strong> Detect and prevent fraud, investigate suspicious activity, enforce anti-fraud policies.</li>
                      <li><strong>Customer Support:</strong> Respond to inquiries, resolve disputes, and handle reports.</li>
                      <li><strong>Notifications:</strong> Push notifications and emails for ride status, bids, driver arrival, and platform news.</li>
                      <li><strong>Platform Improvement:</strong> Analyse usage patterns, diagnose technical issues, improve performance.</li>
                      <li><strong>Legal Compliance:</strong> Comply with applicable laws and enforce our terms of service.</li>
                      <li><strong>Promotions:</strong> Manage referral codes, promo credits, and reward distributions.</li>
                    </ul>
                  </div>

                  <hr className="prose-divider" />

                  <div className="prose-section" id="sharing">
                    <h2 className="prose-title">4. Sharing of Data</h2>
                    <p>We do <strong>not sell</strong> your personal data. We share data only in these limited circumstances:</p>
                    <ul>
                      <li><strong>Between Customers and Drivers:</strong> Driver name, photo, vehicle details, and rating shared with matched Customer. Phone numbers shared in masked format only.</li>
                      <li><strong>Service Providers:</strong> Trusted third-party vendors (cloud hosting, payment, mapping, analytics, KYC) — contractually bound to handle data securely.</li>
                      <li><strong>Legal Requirements:</strong> Disclosure to law enforcement or courts when required by law.</li>
                      <li><strong>Business Transfers:</strong> In the event of a merger or acquisition, subject to equivalent privacy protections.</li>
                    </ul>
                  </div>

                  <hr className="prose-divider" />

                  <div className="prose-section" id="location">
                    <h2 className="prose-title">5. Location Data</h2>
                    <ul>
                      <li><strong>Customers:</strong> Precise location accessed only while the app is in the foreground (active use). We do <strong>not</strong> collect background location data from the Customer app.</li>
                      <li><strong>Drivers:</strong> Foreground location accessed while logged in and active. Background location may be requested only when the Driver enables "Online" mode and explicitly grants permission.</li>
                      <li>Location data is transmitted securely and retained only as long as needed to complete and verify the trip.</li>
                      <li>You may revoke location permissions at any time in device settings, though this will prevent core functionality.</li>
                    </ul>
                  </div>

                  <hr className="prose-divider" />

                  <div className="prose-section" id="data-retention">
                    <h2 className="prose-title">6. Data Retention</h2>
                    <ul>
                      <li><strong>Account Data:</strong> Retained for the lifetime of your account and up to 6 months post-deletion.</li>
                      <li><strong>Trip Records:</strong> Retained for up to 3 years for financial audit and dispute resolution.</li>
                      <li><strong>Payment Data:</strong> Retained per financial regulations and PCI-DSS requirements.</li>
                      <li><strong>Driver Verification Docs:</strong> Retained for up to 5 years per Nigerian transport regulatory obligations.</li>
                    </ul>
                    <p>When data is no longer required, it is securely deleted or anonymised.</p>
                  </div>

                  <hr className="prose-divider" />

                  <div className="prose-section" id="security">
                    <h2 className="prose-title">7. Data Security</h2>
                    <ul>
                      <li>All data transmitted over HTTPS with TLS encryption.</li>
                      <li>Passwords stored using strong one-way hashing.</li>
                      <li>Payment card data tokenised and processed by PCI-DSS compliant providers.</li>
                      <li>Internal access to personal data restricted to authorised personnel on a need-to-know basis.</li>
                      <li>Regular security reviews and audits conducted.</li>
                    </ul>
                    <p>In the event of a breach, we will notify affected users promptly in accordance with applicable law.</p>
                  </div>

                  <hr className="prose-divider" />

                  <div className="prose-section" id="your-rights">
                    <h2 className="prose-title">8. Your Rights</h2>
                    <p>Under the Nigeria Data Protection Act (NDPA) 2023, you have the right to:</p>
                    <ul>
                      <li><strong>Access</strong> — Request a copy of your personal data.</li>
                      <li><strong>Correction</strong> — Request correction of inaccurate or incomplete data.</li>
                      <li><strong>Deletion</strong> — Request deletion of your account. See our <Link to="/account-deletion">Account Deletion page</Link>.</li>
                      <li><strong>Objection</strong> — Object to processing activities such as marketing.</li>
                      <li><strong>Restriction</strong> — Request restricted processing in certain circumstances.</li>
                      <li><strong>Portability</strong> — Request your data in a structured, machine-readable format.</li>
                      <li><strong>Withdraw Consent</strong> — Withdraw consent at any time where processing is consent-based.</li>
                    </ul>
                    <p>Contact <a href="mailto:privacy@caride.ng">privacy@caride.ng</a> to exercise your rights. We'll respond within 30 days.</p>
                  </div>

                  <hr className="prose-divider" />

                  <div className="prose-section" id="children">
                    <h2 className="prose-title">9. Children's Privacy</h2>
                    <p>CaRide is not intended for persons under 18. We do not knowingly collect data from minors. If we discover a minor has registered, their account and data will be promptly deleted. Contact <a href="mailto:privacy@caride.ng">privacy@caride.ng</a> if you believe a minor has registered.</p>
                  </div>

                  <hr className="prose-divider" />

                  <div className="prose-section" id="third-party">
                    <h2 className="prose-title">10. Third-Party Services</h2>
                    <ul>
                      <li><strong>Google Maps Platform</strong> — mapping and routing. <a href="https://policies.google.com/privacy" target="_blank" rel="noopener noreferrer">Google Privacy Policy ↗</a></li>
                      <li><strong>Firebase (Google)</strong> — cloud infrastructure and authentication. <a href="https://firebase.google.com/support/privacy" target="_blank" rel="noopener noreferrer">Firebase Privacy ↗</a></li>
                      <li><strong>TransactPay</strong> — payment processing and virtual accounts. <a href="https://transactpay.ai" target="_blank" rel="noopener noreferrer">TransactPay Privacy ↗</a></li>
                      <li><strong>Stripe</strong> — international card processing. <a href="https://stripe.com/privacy" target="_blank" rel="noopener noreferrer">Stripe Privacy ↗</a></li>
                    </ul>
                  </div>

                  <hr className="prose-divider" />

                  <div className="prose-section" id="changes">
                    <h2 className="prose-title">11. Policy Changes</h2>
                    <p>We may update this policy to reflect changes in our practices or applicable law. Material changes will be communicated via push notification, email, and an in-app notice. Continued use after the effective date constitutes acceptance.</p>
                  </div>

                  <hr className="prose-divider" />

                  <div className="prose-section" id="contact">
                    <h2 className="prose-title">12. Contact Us</h2>
                    <ul>
                      <li><strong>Privacy:</strong> <a href="mailto:privacy@caride.ng">privacy@caride.ng</a></li>
                      <li><strong>Support:</strong> <a href="mailto:support@caride.ng">support@caride.ng</a></li>
                      <li><strong>Website:</strong> <a href="https://www.caride.ng">www.caride.ng</a></li>
                      <li><strong>Address:</strong> CaRide Technologies, Lagos, Nigeria.</li>
                    </ul>
                  </div>

                  <div className="contact-cta">
                    <h3>Have a privacy question?</h3>
                    <p>Our team responds within 24–48 hours.</p>
                    <a href="mailto:privacy@caride.ng">
                      <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/><polyline points="22,6 12,13 2,6"/></svg>
                      Email Privacy Team
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
