import { useState, useEffect, type FormEvent } from 'react';
import { Link } from 'react-router-dom';
import './website.css';

export function Support() {
  const [navOpen, setNavOpen] = useState(false);
  const [theme, setTheme] = useState<'light' | 'dark'>(() => {
    const saved = localStorage.getItem('website-theme');
    if (saved === 'light' || saved === 'dark') return saved;
    const systemDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
    return systemDark ? 'dark' : 'light';
  });

  // Form states
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [phone, setPhone] = useState('');
  const [userType, setUserType] = useState<'rider' | 'driver' | 'general'>('rider');
  const [category, setCategory] = useState('Ride & Trip Issue');
  const [subject, setSubject] = useState('');
  const [message, setMessage] = useState('');

  // Submission status
  const [submitted, setSubmitted] = useState(false);
  const [ticketId, setTicketId] = useState('');
  const [copied, setCopied] = useState(false);

  useEffect(() => {
    localStorage.setItem('website-theme', theme);
  }, [theme]);

  const toggleTheme = () => {
    setTheme(prev => (prev === 'light' ? 'dark' : 'light'));
  };

  const handleSubmit = (e: FormEvent) => {
    e.preventDefault();

    if (!name.trim() || !email.trim() || !subject.trim() || !message.trim()) {
      alert('Please fill out all required fields.');
      return;
    }

    const generatedTicket = `CR-SUP-${Math.floor(100000 + Math.random() * 900000)}`;
    setTicketId(generatedTicket);

    const emailBody = 
`Ticket Reference: ${generatedTicket}
Name: ${name.trim()}
Email: ${email.trim()}
Phone: ${phone.trim() || 'N/A'}
User Category: ${userType.toUpperCase()}
Issue Category: ${category}
Subject: ${subject.trim()}

Message Details:
${message.trim()}

---
Sent via CaRide Support Portal (caride.ng)`;

    const mailtoUrl = `mailto:support@caride.ng?subject=${encodeURIComponent(
      `[Support Request ${generatedTicket}] ${subject.trim()}`
    )}&body=${encodeURIComponent(emailBody)}`;

    // Open mail client
    window.location.href = mailtoUrl;

    // Show success screen
    setSubmitted(true);
  };

  const handleReset = () => {
    setName('');
    setEmail('');
    setPhone('');
    setUserType('rider');
    setCategory('Ride & Trip Issue');
    setSubject('');
    setMessage('');
    setSubmitted(false);
  };

  const copySupportEmail = () => {
    navigator.clipboard.writeText('support@caride.ng');
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  return (
    <div className={`website-root support-body ${theme === 'dark' ? 'dark' : ''}`}>
      {/* NAVBAR */}
      <nav className="navbar scrolled" id="navbar">
        <div className="container">
          <div className="navbar-inner">
            <Link to="/" className="navbar-logo">
              Ca<span>Ride</span>
            </Link>
            <button
              className={`hamburger ${navOpen ? 'open' : ''}`}
              onClick={() => setNavOpen(!navOpen)}
              aria-label="Toggle menu"
              aria-expanded={navOpen}
            >
              <span></span>
              <span></span>
              <span></span>
            </button>
            <ul className={`navbar-links ${navOpen ? 'open' : ''}`} id="nav-links">
              <li>
                <Link to="/" onClick={() => setNavOpen(false)}>
                  Home
                </Link>
              </li>
              <li>
                <Link to="/privacy-policy" onClick={() => setNavOpen(false)}>
                  Privacy Policy
                </Link>
              </li>
              <li>
                <Link to="/account-deletion" onClick={() => setNavOpen(false)}>
                  Account Deletion
                </Link>
              </li>
              <li>
                <Link to="/support" className="active nav-cta" onClick={() => setNavOpen(false)}>
                  Contact Support
                </Link>
              </li>
            </ul>
          </div>
        </div>
      </nav>

      {/* PAGE HERO */}
      <header className="page-hero">
        <div className="container">
          <nav className="breadcrumb" aria-label="Breadcrumb">
            <Link to="/">Home</Link>
            <span className="bc-sep">›</span>
            <span>Support & Help Center</span>
          </nav>
          <span className="label label-green" style={{ marginBottom: '16px' }}>
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5">
              <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
            </svg>
            24/7 Support Portal
          </span>
          <h1>How can we help you?</h1>
          <p>
            Need assistance with a trip, payment, or driver account? Fill in the form below and your inquiry will be routed directly to{' '}
            <strong style={{ color: 'var(--green)' }}>support@caride.ng</strong>.
          </p>
          <div className="hero-meta">
            <span className="hero-meta-item">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <circle cx="12" cy="12" r="10" />
                <polyline points="12 6 12 12 16 14" />
              </svg>
              Fast Turnaround (~24h response)
            </span>
            <span className="hero-meta-item">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z" />
                <polyline points="22,6 12,13 2,6" />
              </svg>
              Direct to support@caride.ng
            </span>
            <span className="hero-meta-item">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
              </svg>
              Encrypted & Safe
            </span>
          </div>
        </div>
      </header>

      {/* MAIN CONTENT SECTION */}
      <main className="section" style={{ paddingTop: '50px' }}>
        <div className="container">
          <div className="support-grid">
            {/* LEFT COLUMN: SUPPORT FORM / SUCCESS CARD */}
            <div className="support-card glass">
              {!submitted ? (
                <>
                  <div className="support-card-header">
                    <h2>Send Us a Message</h2>
                    <p>Fill out the form below to dispatch your support inquiry to support@caride.ng.</p>
                  </div>

                  <form onSubmit={handleSubmit} className="support-form">
                    {/* User Type Selection */}
                    <div className="form-group">
                      <label className="form-label">I am a...</label>
                      <div className="role-pill-group">
                        <button
                          type="button"
                          className={`role-pill ${userType === 'rider' ? 'active' : ''}`}
                          onClick={() => setUserType('rider')}
                          style={{ display: 'inline-flex', alignItems: 'center', gap: '8px' }}
                        >
                          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M19 17h2c.6 0 1-.4 1-1v-3c0-.9-.7-1.7-1.5-1.9C18.7 10.6 16 10 16 10s-1.3-1.4-2.2-2.3c-.5-.4-1.1-.7-1.8-.7H5c-.6 0-1.1.4-1.4.9l-1.5 3.1C1.4 11.4 1 12.2 1 13v3c0 .6.4 1 1 1h2"/><circle cx="7" cy="17" r="2"/><circle cx="17" cy="17" r="2"/></svg>
                          Rider / Passenger
                        </button>
                        <button
                          type="button"
                          className={`role-pill ${userType === 'driver' ? 'active' : ''}`}
                          onClick={() => setUserType('driver')}
                          style={{ display: 'inline-flex', alignItems: 'center', gap: '8px' }}
                        >
                          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><circle cx="12" cy="12" r="10"/><polygon points="12 8 8 16 16 16 12 8"/></svg>
                          CaRide Driver
                        </button>
                        <button
                          type="button"
                          className={`role-pill ${userType === 'general' ? 'active' : ''}`}
                          onClick={() => setUserType('general')}
                          style={{ display: 'inline-flex', alignItems: 'center', gap: '8px' }}
                        >
                          <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/></svg>
                          General Inquiry
                        </button>
                      </div>
                    </div>

                    {/* Row 1: Name & Email */}
                    <div className="form-row">
                      <div className="form-group">
                        <label htmlFor="name" className="form-label">
                          Full Name <span className="required">*</span>
                        </label>
                        <input
                          id="name"
                          type="text"
                          className="form-input"
                          placeholder="e.g. Chukwuma Adebayo"
                          value={name}
                          onChange={e => setName(e.target.value)}
                          required
                        />
                      </div>
                      <div className="form-group">
                        <label htmlFor="email" className="form-label">
                          Email Address <span className="required">*</span>
                        </label>
                        <input
                          id="email"
                          type="email"
                          className="form-input"
                          placeholder="name@example.com"
                          value={email}
                          onChange={e => setEmail(e.target.value)}
                          required
                        />
                      </div>
                    </div>

                    {/* Row 2: Phone & Category */}
                    <div className="form-row">
                      <div className="form-group">
                        <label htmlFor="phone" className="form-label">
                          Phone Number <span className="optional">(Optional)</span>
                        </label>
                        <input
                          id="phone"
                          type="tel"
                          className="form-input"
                          placeholder="+234 800 000 0000"
                          value={phone}
                          onChange={e => setPhone(e.target.value)}
                        />
                      </div>
                      <div className="form-group">
                        <label htmlFor="category" className="form-label">
                          Support Category <span className="required">*</span>
                        </label>
                        <select
                          id="category"
                          className="form-select"
                          value={category}
                          onChange={e => setCategory(e.target.value)}
                        >
                          <option value="Ride & Trip Issue">Ride & Trip Issue</option>
                          <option value="Fare Bidding & Pricing">Fare Bidding & Pricing</option>
                          <option value="Payment, Wallet & Refunds">Payment, Wallet & Refunds</option>
                          <option value="Account & Profile">Account & Profile</option>
                          <option value="Driver Application & Onboarding">Driver Application & Verification</option>
                          <option value="Safety & Security Concern">Safety & Security Concern</option>
                          <option value="App Bug / Technical Issue">App Bug / Technical Issue</option>
                          <option value="Other Inquiry">Other Inquiry</option>
                        </select>
                      </div>
                    </div>

                    {/* Subject */}
                    <div className="form-group">
                      <label htmlFor="subject" className="form-label">
                        Subject / Brief Title <span className="required">*</span>
                      </label>
                      <input
                        id="subject"
                        type="text"
                        className="form-input"
                        placeholder="e.g. Fare dispute on ride #10492"
                        value={subject}
                        onChange={e => setSubject(e.target.value)}
                        required
                      />
                    </div>

                    {/* Message */}
                    <div className="form-group">
                      <label htmlFor="message" className="form-label">
                        Detailed Description <span className="required">*</span>
                      </label>
                      <textarea
                        id="message"
                        rows={5}
                        className="form-textarea"
                        placeholder="Please describe your issue or question in detail. Include trip IDs, transaction references, or screenshots description if applicable..."
                        value={message}
                        onChange={e => setMessage(e.target.value)}
                        required
                      ></textarea>
                    </div>

                    {/* Submit Button */}
                    <button type="submit" className="btn btn-primary submit-btn">
                      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                        <line x1="22" y1="2" x2="11" y2="13"></line>
                        <polygon points="22 2 15 22 11 13 2 9 22 2"></polygon>
                      </svg>
                      Send Message to support@caride.ng
                    </button>
                  </form>
                </>
              ) : (
                <div className="success-state">
                  <div className="success-icon" style={{ display: 'flex', justifyContent: 'center', marginBottom: '16px' }}>
                    <svg width="56" height="56" viewBox="0 0 24 24" fill="none" stroke="var(--green)" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round"><path d="M22 11.08V12a10 10 0 1 1-5.93-9.14"/><polyline points="22 4 12 14.01 9 11.01"/></svg>
                  </div>
                  <h2>Support Request Prepared!</h2>
                  <p>
                    Your message details have been formatted and dispatched. Your email app should launch automatically to send the message directly to <strong style={{ color: 'var(--green)' }}>support@caride.ng</strong>.
                  </p>

                  <div className="ticket-badge">
                    <span className="ticket-label">Ticket Reference Code:</span>
                    <span className="ticket-code">{ticketId}</span>
                  </div>

                  <div className="summary-box">
                    <h4>Submitted Details:</h4>
                    <ul>
                      <li><strong>Name:</strong> {name}</li>
                      <li><strong>Email:</strong> {email}</li>
                      {phone && <li><strong>Phone:</strong> {phone}</li>}
                      <li><strong>User Type:</strong> {userType.toUpperCase()}</li>
                      <li><strong>Category:</strong> {category}</li>
                      <li><strong>Subject:</strong> {subject}</li>
                    </ul>
                  </div>

                  <div className="success-actions">
                    <button type="button" className="btn btn-ghost" onClick={handleReset}>
                      Send Another Message
                    </button>
                    <Link to="/" className="btn btn-primary">
                      Return to Home
                    </Link>
                  </div>
                </div>
              )}
            </div>

            {/* RIGHT COLUMN: CONTACT INFO & QUICK FAQS */}
            <div className="support-sidebar">
              {/* Direct Contact Card */}
              <div className="sidebar-card glass">
                <div className="sidebar-icon" style={{ color: 'var(--green)', display: 'flex', marginBottom: '12px' }}>
                  <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z"/><polyline points="22,6 12,13 2,6"/></svg>
                </div>
                <h3>Direct Email Support</h3>
                <p>You can also email our support team directly from your preferred email client.</p>
                <div className="email-copy-box">
                  <code>support@caride.ng</code>
                  <button type="button" className="copy-btn" onClick={copySupportEmail}>
                    {copied ? '✓ Copied' : 'Copy'}
                  </button>
                </div>
              </div>

              {/* Office & Availability Card */}
              <div className="sidebar-card glass">
                <div className="sidebar-icon" style={{ color: 'var(--green)', display: 'flex', marginBottom: '12px' }}>
                  <svg width="28" height="28" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0118 0z"/><circle cx="12" cy="10" r="3"/></svg>
                </div>
                <h3>Office Location & Hours</h3>
                <p className="sidebar-text">
                  <strong>Headquarters:</strong> Lagos, Nigeria<br />
                  <strong>Operating Hours:</strong> 24/7 Monitoring & Support Response
                </p>
              </div>

              {/* FAQ Accordion Preview */}
              <div className="sidebar-card glass">
                <h3>Frequently Asked Questions</h3>
                <div className="faq-mini-list">
                  <details className="faq-item">
                    <summary>How does the price bidding work?</summary>
                    <p>
                      When you set your ride destination, you choose the fare you wish to pay. Drivers nearby review your offer and can either accept or counter-bid. You pick the driver that suits your budget and rating.
                    </p>
                  </details>
                  <details className="faq-item">
                    <summary>How do refunds work for canceled trips?</summary>
                    <p>
                      If a driver cancels or a trip is terminated prematurely due to app failure, wallet deductions are automatically refunded to your CaRide wallet within 5 minutes.
                    </p>
                  </details>
                  <details className="faq-item">
                    <summary>How do I sign up as a driver?</summary>
                    <p>
                      Download the CaRide Driver app from Google Play, submit your identity document and vehicle papers for verification, and start driving once approved!
                    </p>
                  </details>
                </div>
              </div>
            </div>
          </div>
        </div>
      </main>

      {/* FOOTER */}
      <footer className="footer">
        <div className="container">
          <div className="footer-grid">
            <div>
              <div className="footer-logo">
                Ca<span>Ride</span>
              </div>
              <p className="footer-desc">
                Nigeria's smart ride-hailing platform — connecting passengers with trusted drivers nationwide. Fast. Safe. Affordable.
              </p>
            </div>
            <div className="footer-col">
              <h4>Company</h4>
              <ul className="footer-links">
                <li>
                  <Link to="/">Home</Link>
                </li>
                <li>
                  <a href="/#features">Features</a>
                </li>
                <li>
                  <a href="/#drivers">Drive with Us</a>
                </li>
                <li>
                  <Link to="/support">Support</Link>
                </li>
              </ul>
            </div>
            <div className="footer-col">
              <h4>Legal</h4>
              <ul className="footer-links">
                <li>
                  <Link to="/privacy-policy">Privacy Policy</Link>
                </li>
                <li>
                  <Link to="/account-deletion">Account Deletion</Link>
                </li>
                <li>
                  <Link to="/support">Terms of Service</Link>
                </li>
              </ul>
            </div>
          </div>
          <div className="footer-bottom">
            <p>&copy; 2025 CaRide Technologies. All rights reserved. Lagos, Nigeria.</p>
            <ul className="footer-bottom-links">
              <li>
                <Link to="/privacy-policy">Privacy</Link>
              </li>
              <li>
                <Link to="/account-deletion">Account Deletion</Link>
              </li>
              <li>
                <Link to="/support">Support</Link>
              </li>
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
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              d="M21.752 15.002A9.718 9.718 0 0118 15.75c-5.385 0-9.75-4.365-9.75-9.75 0-1.33.266-2.597.748-3.752A9.753 9.753 0 003 11.25C3 16.635 7.365 21 12.75 21a9.753 9.753 0 009.002-5.998z"
            />
          </svg>
        ) : (
          <svg fill="none" stroke="currentColor" strokeWidth="2.5" viewBox="0 0 24 24">
            <path
              strokeLinecap="round"
              strokeLinejoin="round"
              d="M12 3v2.25m0 13.5V21m9.75-9h-2.25M4.25 12H2M18.364 5.636l-1.591 1.591M8.227 15.773l-1.591 1.591M18.364 18.364l-1.591-1.591M8.227 8.227L6.636 6.636M12 9a3 3 0 100 6 3 3 0 000-6z"
            />
          </svg>
        )}
      </button>
    </div>
  );
}
