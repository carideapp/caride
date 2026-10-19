import { useState, useEffect } from 'react';
import { Link } from 'react-router-dom';
import './website.css';

export function WebsiteHome() {
  const [scrolled, setScrolled] = useState(false);
  const [navOpen, setNavOpen] = useState(false);
  const [activeModal, setActiveModal] = useState<'android' | 'ios' | null>(null);
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
    const handleScroll = () => {
      setScrolled(window.scrollY > 20);
    };
    window.addEventListener('scroll', handleScroll, { passive: true });
    return () => window.removeEventListener('scroll', handleScroll);
  }, []);

  // Intersection-observer reveal animations
  useEffect(() => {
    const revealEls = document.querySelectorAll('[data-reveal]');
    const io = new IntersectionObserver((entries) => {
      entries.forEach((e) => {
        if (e.isIntersecting) {
          e.target.classList.add('revealed');
          io.unobserve(e.target);
        }
      });
    }, { threshold: 0.12 });
    revealEls.forEach((el) => io.observe(el));
    return () => io.disconnect();
  }, []);

  // Counter animations
  useEffect(() => {
    const counters = document.querySelectorAll('[data-target]');
    
    function animateCounter(el: HTMLElement) {
      const target = parseInt(el.dataset.target || '0', 10);
      const suffix = el.dataset.suffix || '';
      const duration = 1800;
      const start = performance.now();
      const update = (now: number) => {
        const progress = Math.min((now - start) / duration, 1);
        const eased = 1 - Math.pow(1 - progress, 3);
        el.textContent = Math.floor(eased * target).toLocaleString() + suffix;
        if (progress < 1) requestAnimationFrame(update);
      };
      requestAnimationFrame(update);
    }

    const counterObserver = new IntersectionObserver((entries) => {
      entries.forEach((e) => {
        if (e.isIntersecting) {
          animateCounter(e.target as HTMLElement);
          counterObserver.unobserve(e.target);
        }
      });
    }, { threshold: 0.5 });

    counters.forEach((c) => counterObserver.observe(c));
    return () => counterObserver.disconnect();
  }, []);

  return (
    <div className={`website-root ${theme === 'dark' ? 'dark' : ''}`}>
      {/* NAVBAR */}
      <nav className={`navbar ${scrolled || navOpen ? 'scrolled' : ''}`} id="navbar">
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
              <li><Link to="/" className="active" onClick={() => setNavOpen(false)}>Home</Link></li>
              <li><a href="#features" onClick={() => setNavOpen(false)}>Features</a></li>
              <li><a href="#how-it-works" onClick={() => setNavOpen(false)}>How It Works</a></li>
              <li><a href="#drivers" onClick={() => setNavOpen(false)}>Drivers</a></li>
              <li><Link to="/support" className="nav-cta" onClick={() => setNavOpen(false)}>Contact Support</Link></li>
            </ul>
          </div>
        </div>
      </nav>

      {/* HERO */}
      <section className="hero">
        <div className="container hero-container">
          {/* Left */}
          <div className="hero-left">
            <h1 data-reveal data-reveal-delay="1">
              Your Ride.<br /><em>Your Price.</em><br />Your Choice.
            </h1>
            <p className="hero-desc" data-reveal data-reveal-delay="2">
              CaRide is Nigeria's smart ride-hailing platform where you set the fare. Drivers compete for your ride — you always win.
            </p>
            <div className="hero-actions" data-reveal data-reveal-delay="3">
              <a
                href="https://apps.apple.com/ng/app/caride-ride-delivery/id6802303889"
                target="_blank"
                rel="noopener noreferrer"
                className="btn btn-primary"
              >
                <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor"><path d="M17.05 20.28c-.98.95-2.05.8-3.08.35-1.09-.46-2.09-.48-3.24 0-1.44.62-2.2.44-3.06-.35C2.79 15.25 3.51 7.7 9.05 7.41c1.27.07 2.18.77 2.93.8.86-.02 2.04-.83 3.08-.73 1.41.13 2.46.67 3.17 1.67-2.99 1.8-2.5 5.77.53 6.88-.47 1.38-1.08 2.74-1.71 4.25zM12.03 7.25c-.15-2.23 1.66-4.07 3.74-4.25.29 2.58-2.34 4.5-3.74 4.25z"/></svg>
                Download on iOS
              </a>
              <a href="#" className="btn btn-ghost" onClick={(e) => { e.preventDefault(); setActiveModal('android'); }}>
                <svg width="18" height="18" viewBox="0 0 24 24" fill="currentColor"><path d="M3.18 23.76c.37.21.82.21 1.21.01l11.75-6.76-2.46-2.46L3.18 23.76zm16.56-9.09L17.3 13.2 14.74 10.62l2.02-2.02 1.98 1.14c.95.55.95 2.38 0 2.93zM3.15.24C2.78.45 2.5.86 2.5 1.4v21.2c0 .54.28.95.65 1.16L14.1 12 3.15.24zm10.1 10.89L3.18.21l10.5 10.5-2.46 2.46-2.03-2.04z"/></svg>
                Get on Android
              </a>
            </div>
            <div className="hero-trust" data-reveal data-reveal-delay="4">
              <div className="trust-avatars">
                <span>E</span><span>A</span><span>O</span><span>C</span><span>+</span>
              </div>
              <p className="trust-text"><strong>10,000+ riders</strong> already on board</p>
            </div>
          </div>

          {/* Right – Phone */}
          <div className="hero-right" style={{ position: 'relative', display: 'flex', justifyContent: 'center', alignItems: 'center' }}>
            <div className="phone-glow" style={{ position: 'absolute', inset: '-20%', borderRadius: '50%', background: 'radial-gradient(circle,rgba(22,163,74,0.2) 0%,transparent 65%)', zIndex: 0 }}></div>
            <div className="hero-phone-wrap" data-reveal data-reveal-delay="2">
              <img src="/phone_hero.png" alt="CaRide app showing live map with driver tracking" />

              {/* Floating chips */}
              <div className="float-chip chip-tl" style={{ top: '10%', left: '-85px' }}>
                <p className="chip-label">Driver matched</p>
                <p className="chip-val">Emmanuel A. 4.9 ★</p>
                <p className="chip-sub chip-green">En route · 3 min</p>
              </div>
              <div className="float-chip chip-br delay-1" style={{ bottom: '12%', right: '-90px' }}>
                <p className="chip-label">Your bid</p>
                <p className="chip-val chip-green">₦1,800</p>
                <p className="chip-sub">Lekki → Victoria Island</p>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* STATS STRIP */}
      <section className="stats-section section" style={{ padding: 0 }}>
        <div className="container">
          <div className="stats-strip">
            <div className="stat-cell">
              <div className="stat-val"><span data-target="10000" data-suffix="+">0</span></div>
              <div className="stat-lbl">Happy Riders</div>
            </div>
            <div className="stat-cell">
              <div className="stat-val"><span data-target="500" data-suffix="+">0</span></div>
              <div className="stat-lbl">Active Drivers</div>
            </div>
            <div className="stat-cell">
              <div className="stat-val">4.8 / 5.0</div>
              <div className="stat-lbl">App Store Rating</div>
            </div>
            <div className="stat-cell">
              <div className="stat-val"><span data-target="50" data-suffix="K+">0</span></div>
              <div className="stat-lbl">Trips Completed</div>
            </div>
          </div>
        </div>
      </section>

      {/* FEATURES */}
      <section className="features-section section" id="features">
        <div className="container">
          <div className="section-header">
            <span className="label label-green" data-reveal>Why CaRide</span>
            <h2 data-reveal data-reveal-delay="1">Everything you need.<br />Nothing you don't.</h2>
            <p data-reveal data-reveal-delay="2">Designed for the modern Nigerian — fast, transparent, and built on real trust.</p>
          </div>

          <div className="bento-grid">
            <div className="bento-cell bento-dark bento-a big glass-hover" data-reveal>
              <span className="label label-yellow" style={{ marginBottom: '18px', display: 'inline-flex', alignItems: 'center', gap: '6px' }}>
                <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/></svg>
                Signature Feature
              </span>
              <h3 style={{ fontSize: '1.5rem', marginBottom: '10px' }}>Set Your Own Price</h3>
              <p style={{ maxWidth: '340px' }}>Unlike fixed-fare apps, CaRide puts you in control. Set your fare — drivers near you compete for your ride. The best offer wins.</p>
              <div className="bento-big-val" style={{ position: 'absolute', bottom: '28px', right: '32px', opacity: 0.5 }}>₦</div>
            </div>
            <div className="bento-cell bento-green bento-b big glass-hover" data-reveal data-reveal-delay="1">
              <div className="feature-icon" style={{ width: '44px', height: '44px', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: '14px' }}>
                <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><path d="M21 10c0 7-9 13-9 13s-9-6-9-13a9 9 0 0118 0z"/><circle cx="12" cy="10" r="3"/></svg>
              </div>
              <h3>Live Tracking</h3>
              <p>Watch your driver move toward you in real time on the map — from acceptance to arrival.</p>
            </div>
            <div className="bento-cell bento-dark bento-c sm glass-hover" data-reveal data-reveal-delay="2">
              <div className="feature-icon" style={{ width: '40px', height: '40px', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: '12px' }}>
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><rect x="3" y="11" width="18" height="11" rx="2" ry="2"/><path d="M7 11V7a5 5 0 0110 0v4"/></svg>
              </div>
              <h3 style={{ fontSize: '0.95rem' }}>Verified Drivers</h3>
              <p style={{ fontSize: '0.85rem' }}>Every driver is ID-verified and vehicle-checked before going online.</p>
            </div>
            <div className="bento-cell bento-dark bento-d sm glass-hover" data-reveal data-reveal-delay="3">
              <div className="feature-icon" style={{ width: '40px', height: '40px', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: '12px' }}>
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><rect x="1" y="4" width="22" height="16" rx="2" ry="2"/><line x1="1" y1="10" x2="23" y2="10"/></svg>
              </div>
              <h3 style={{ fontSize: '0.95rem' }}>Flex Payments</h3>
              <p style={{ fontSize: '0.85rem' }}>Wallet, card, bank transfer, or crypto (USDT). You choose.</p>
            </div>
            <div className="bento-cell bento-dark bento-e sm glass-hover" data-reveal data-reveal-delay="4">
              <div className="feature-icon" style={{ width: '40px', height: '40px', display: 'flex', alignItems: 'center', justifyContent: 'center', marginBottom: '12px' }}>
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2"><polyline points="20 12 20 22 4 22 4 12"/><rect x="2" y="7" width="20" height="5"/><line x1="12" y1="22" x2="12" y2="7"/><path d="M12 7H7.5a2.5 2.5 0 010-5C11 2 12 7 12 7z"/><path d="M12 7h4.5a2.5 2.5 0 000-5C13 2 12 7 12 7z"/></svg>
              </div>
              <h3 style={{ fontSize: '0.95rem' }}>Earn Referrals</h3>
              <p style={{ fontSize: '0.85rem' }}>Share your code. Earn ₦100 wallet credit per referred ride.</p>
            </div>
          </div>
        </div>
      </section>

      {/* HOW IT WORKS */}
      <section className="hiw-section section" id="how-it-works">
        <div className="container">
          <div className="section-header">
            <span className="label label-white" data-reveal>How It Works</span>
            <h2 data-reveal data-reveal-delay="1">Book a ride in minutes</h2>
            <p data-reveal data-reveal-delay="2">From opening the app to arriving at your destination — it's that simple.</p>
          </div>

          <div className="steps-row" data-reveal data-reveal-delay="2">
            <div className="step-item step-connector">
              <div className="step-num">1</div>
              <h3>Enter Destination</h3>
              <p>Open CaRide, pin your pickup and drop-off. We'll show a smart price range based on demand.</p>
            </div>
            <div className="step-item step-connector">
              <div className="step-num">2</div>
              <h3>Set Your Price</h3>
              <p>Pick the suggested fare or enter your own custom bid. Your ride, your rules.</p>
            </div>
            <div className="step-item step-connector">
              <div className="step-num">3</div>
              <h3>Pick Your Driver</h3>
              <p>Review driver profiles, ratings, and counter-offers. Select the best fit.</p>
            </div>
            <div className="step-item">
              <div className="step-num">4</div>
              <h3>Ride & Pay</h3>
              <p>Track live, arrive safely. Payment is automatic when the ride ends in-app.</p>
            </div>
          </div>

          <div className="hiw-phones" data-reveal data-reveal-delay="3">
            <div className="hiw-phone">
              <span className="hiw-phone-badge">Step 1 & 2</span>
              <img src="/set_destination_price.png" alt="CaRide app - set your destination and price screen" />
              <p className="hiw-phone-label">Set Destination & Price</p>
            </div>
            <div className="hiw-phone" style={{ marginTop: '32px' }}>
              <span className="hiw-phone-badge">Step 3 & 4</span>
              <img src="/track_ride.png" alt="CaRide app - driver tracking screen" />
              <p className="hiw-phone-label">Track & Ride</p>
            </div>
          </div>
        </div>
      </section>

      {/* DRIVERS */}
      <section className="driver-section section" id="drivers">
        <div className="container">
          <div className="driver-band">
            <div className="driver-band-inner">
              <div>
                <span className="label label-yellow" data-reveal style={{ display: 'inline-flex', alignItems: 'center', gap: '6px' }}>
                  <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5"><path d="M19 17h2c.6 0 1-.4 1-1v-3c0-.9-.7-1.7-1.5-1.9C18.7 10.6 16 10 16 10s-1.3-1.4-2.2-2.3c-.5-.4-1.1-.7-1.8-.7H5c-.6 0-1.1.4-1.4.9l-1.5 3.1C1.4 11.4 1 12.2 1 13v3c0 .6.4 1 1 1h2"/><circle cx="7" cy="17" r="2"/><circle cx="17" cy="17" r="2"/></svg>
                  Become a Driver
                </span>
                <h2 data-reveal data-reveal-delay="1" style={{ color: 'var(--white)', margin: '16px 0 12px' }}>
                  Drive with CaRide.<br />Earn on your terms.
                </h2>
                <p data-reveal data-reveal-delay="2" style={{ maxWidth: '380px' }}>
                  Join hundreds of drivers earning on the CaRide platform. Flexible hours, competitive commissions, and a ranking system that rewards your dedication.
                </p>
                <div className="driver-rank-cards" data-reveal data-reveal-delay="3">
                  <div className="rank-card">
                    <span className="rank-icon" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#94a3b8" strokeWidth="2"><circle cx="12" cy="8" r="7"/><polyline points="8.21 13.89 7 23 12 20 17 23 15.79 13.88"/></svg>
                    </span>
                    <div className="rank-info"><h4>Silver</h4><p>Starting tier — standard commission</p></div>
                  </div>
                  <div className="rank-card">
                    <span className="rank-icon" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#eab308" strokeWidth="2"><circle cx="12" cy="8" r="7"/><polyline points="8.21 13.89 7 23 12 20 17 23 15.79 13.88"/></svg>
                    </span>
                    <div className="rank-info"><h4>Gold</h4><p>50+ trips — reduced commission deduction</p></div>
                  </div>
                  <div className="rank-card">
                    <span className="rank-icon" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#38bdf8" strokeWidth="2"><path d="M6 3h12l4 6-10 12L2 9z"/></svg>
                    </span>
                    <div className="rank-info"><h4>Diamond</h4><p>200+ trips — priority dispatch + perks</p></div>
                  </div>
                  <div className="rank-card">
                    <span className="rank-icon" style={{ display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                      <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#f59e0b" strokeWidth="2"><path d="M6 9H4.5a2.5 2.5 0 010-5H6"/><path d="M18 9h1.5a2.5 2.5 0 000-5H18"/><path d="M4 22h16"/><path d="M10 14.66V17c0 .55-.45 1-1 1H8v4h8v-4h-1c-.55 0-1-.45-1-1v-2.34"/><path d="M18 4H6v7a6 6 0 0012 0V4z"/></svg>
                    </span>
                    <div className="rank-info"><h4>Platinum</h4><p>500+ trips — lowest commission + bonuses</p></div>
                  </div>
                </div>
                <div style={{ marginTop: '28px' }} data-reveal data-reveal-delay="4">
                  <a href="#" className="btn btn-primary">Sign Up as Driver</a>
                </div>
              </div>
              <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '16px' }} data-reveal data-reveal-delay="2">
                <div className="phone-frame" style={{ width: '260px', position: 'relative' }}>
                  <div className="phone-glow"></div>
                  <img src="/phone_driver.png" alt="CaRide driver app showing earnings dashboard" />
                </div>
                <div style={{ background: 'rgba(22,163,74,0.12)', border: '1px solid rgba(22,163,74,0.25)', borderRadius: 'var(--r-lg)', padding: '18px 28px', textAlign: 'center' }}>
                  <p style={{ fontSize: '0.75rem', color: 'rgba(255,255,255,0.45)', marginBottom: '4px' }}>Avg. monthly earnings</p>
                  <p style={{ fontSize: '2rem', fontWeight: 900, color: '#4ade80', letterSpacing: '-1px', margin: 0 }}>₦85,000+</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* TESTIMONIALS */}
      <section className="testi-section section">
        <div className="container">
          <div className="section-header">
            <span className="label label-green" data-reveal>Loved by Users</span>
            <h2 data-reveal data-reveal-delay="1">Real riders. Real stories.</h2>
          </div>
          <div className="testimonials-grid">
            <div className="testi-card glass" data-reveal>
              <div className="stars">★★★★★</div>
              <p className="testi-body">"Finally an app where I control my own fare. Got a driver in under 3 minutes during rush hour. The bidding system is a game-changer."</p>
              <div className="testi-author"><div className="testi-avatar">AC</div><div><p className="testi-name">Adaeze C.</p><p className="testi-role">Rider · Lagos</p></div></div>
            </div>
            <div className="testi-card glass" data-reveal data-reveal-delay="1">
              <div className="stars">★★★★★</div>
              <p className="testi-body">"I've been a CaRide driver for 3 months now. Earning consistently and the Gold tier perks really make a difference. Highly recommend."</p>
              <div className="testi-author"><div className="testi-avatar">EM</div><div><p className="testi-name">Emmanuel M.</p><p className="testi-role">Driver · Lagos</p></div></div>
            </div>
            <div className="testi-card glass" data-reveal data-reveal-delay="2">
              <div className="stars">★★★★★</div>
              <p className="testi-body">"The live tracking is super accurate and the in-app chat saved me once when I couldn't reach the driver. Great experience overall."</p>
              <div className="testi-author"><div className="testi-avatar">OB</div><div><p className="testi-name">Oluwaseun B.</p><p className="testi-role">Rider · Abuja</p></div></div>
            </div>
          </div>
        </div>
      </section>

      {/* CTA */}
      <section className="cta-section">
        <div className="container">
          <span className="label label-green" data-reveal>Get Started Today</span>
          <h2 data-reveal data-reveal-delay="1">Ready to ride smarter?</h2>
          <p data-reveal data-reveal-delay="2">Download CaRide and take control of your journeys across Nigeria. Your first ride awaits.</p>
          <div className="cta-actions" data-reveal data-reveal-delay="3">
            <a
              href="https://apps.apple.com/ng/app/caride-ride-delivery/id6802303889"
              target="_blank"
              rel="noopener noreferrer"
              className="store-btn"
            >
              <svg viewBox="0 0 24 24" fill="currentColor"><path d="M17.05 20.28c-.98.95-2.05.8-3.08.35-1.09-.46-2.09-.48-3.24 0-1.44.62-2.2.44-3.06-.35C2.79 15.25 3.51 7.7 9.05 7.41c1.27.07 2.18.77 2.93.8.86-.02 2.04-.83 3.08-.73 1.41.13 2.46.67 3.17 1.67-2.99 1.8-2.5 5.77.53 6.88-.47 1.38-1.08 2.74-1.71 4.25zM12.03 7.25c-.15-2.23 1.66-4.07 3.74-4.25.29 2.58-2.34 4.5-3.74 4.25z"/></svg>
              <div className="store-btn-text"><small>Download on the</small>App Store</div>
            </a>
            <a href="#" className="store-btn" onClick={(e) => { e.preventDefault(); setActiveModal('android'); }}>
              <svg viewBox="0 0 24 24" fill="currentColor"><path d="M3.18 23.76c.37.21.82.21 1.21.01l11.75-6.76-2.46-2.46L3.18 23.76zm16.56-9.09L17.3 13.2 14.74 10.62l2.02-2.02 1.98 1.14c.95.55.95 2.38 0 2.93zM3.15.24C2.78.45 2.5.86 2.5 1.4v21.2c0 .54.28.95.65 1.16L14.1 12 3.15.24zm10.1 10.89L3.18.21l10.5 10.5-2.46 2.46-2.03-2.04z"/></svg>
              <div className="store-btn-text"><small>Get it on</small>Google Play</div>
            </a>
            <Link to="/support" className="btn btn-outline-green">Contact Us</Link>
          </div>
        </div>
      </section>

      {/* FOOTER */}
      <footer className="footer">
        <div className="container">
          <div className="footer-grid">
            <div>
              <div className="footer-logo">Ca<span>Ride</span></div>
              <p className="footer-desc">Nigeria's smart ride-hailing platform — connecting passengers with trusted drivers nationwide. Fast. Safe. Affordable.</p>
            </div>
            <div className="footer-col">
              <h4>Company</h4>
              <ul className="footer-links">
                <li><Link to="/">Home</Link></li>
                <li><a href="#features">Features</a></li>
                <li><a href="#drivers">Drive with Us</a></li>
                <li><Link to="/support">Support</Link></li>
              </ul>
            </div>
            <div className="footer-col">
              <h4>Legal</h4>
              <ul className="footer-links">
                <li><Link to="/privacy-policy">Privacy Policy</Link></li>
                <li><Link to="/account-deletion">Account Deletion</Link></li>
                <li><Link to="/support">Terms of Service</Link></li>
              </ul>
            </div>
          </div>
          <div className="footer-bottom">
            <p>&copy; 2025 CaRide Technologies. All rights reserved. Lagos, Nigeria.</p>
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

      {/* DOWNLOAD MODALS */}
      {activeModal && (
        <div className="modal-overlay" onClick={() => setActiveModal(null)}>
          <div className="modal-card glass" onClick={(e) => e.stopPropagation()}>
            <button className="modal-close" onClick={() => setActiveModal(null)} aria-label="Close modal">×</button>
            {activeModal === 'android' ? (
              <>
                <div className="modal-icon" style={{ display: 'flex', justifyContent: 'center', marginBottom: '16px' }}>
                  <svg width="48" height="48" viewBox="0 0 24 24" fill="var(--green)"><path d="M3.18 23.76c.37.21.82.21 1.21.01l11.75-6.76-2.46-2.46L3.18 23.76zm16.56-9.09L17.3 13.2 14.74 10.62l2.02-2.02 1.98 1.14c.95.55.95 2.38 0 2.93zM3.15.24C2.78.45 2.5.86 2.5 1.4v21.2c0 .54.28.95.65 1.16L14.1 12 3.15.24zm10.1 10.89L3.18.21l10.5 10.5-2.46 2.46-2.03-2.04z"/></svg>
                </div>
                <h3>Get CaRide on Android</h3>
                <p>Choose your download option below to get started on Google Play.</p>
                <div className="modal-buttons">
                  <a
                    href="https://play.google.com/store/apps/details?id=com.caride.app&pcampaignid=web_share"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="btn btn-primary"
                  >
                    Download CaRide App
                  </a>
                  <a
                    href="https://play.google.com/store/apps/details?id=com.caride.driver.driver_app&pcampaignid=web_share"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="btn btn-ghost"
                  >
                    Download CaRide Driver
                  </a>
                </div>
              </>
            ) : (
              <>
                <div className="modal-icon" style={{ display: 'flex', justifyContent: 'center', marginBottom: '16px' }}>
                  <svg width="48" height="48" viewBox="0 0 24 24" fill="var(--text)"><path d="M17.05 20.28c-.98.95-2.05.8-3.08.35-1.09-.46-2.09-.48-3.24 0-1.44.62-2.2.44-3.06-.35C2.79 15.25 3.51 7.7 9.05 7.41c1.27.07 2.18.77 2.93.8.86-.02 2.04-.83 3.08-.73 1.41.13 2.46.67 3.17 1.67-2.99 1.8-2.5 5.77.53 6.88-.47 1.38-1.08 2.74-1.71 4.25zM12.03 7.25c-.15-2.23 1.66-4.07 3.74-4.25.29 2.58-2.34 4.5-3.74 4.25z"/></svg>
                </div>
                <h3>Get CaRide on iOS</h3>
                <p>Download CaRide now directly from the Apple App Store.</p>
                <div className="modal-buttons">
                  <a
                    href="https://apps.apple.com/ng/app/caride-ride-delivery/id6802303889"
                    target="_blank"
                    rel="noopener noreferrer"
                    className="btn btn-primary"
                  >
                    Download on the App Store
                  </a>
                </div>
              </>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
