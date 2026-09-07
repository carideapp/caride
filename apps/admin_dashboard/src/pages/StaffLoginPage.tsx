import { FirebaseError } from 'firebase/app';
import { type FormEvent, useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { signInWithEmailAndPassword, signOut } from 'firebase/auth';
import { doc, getDoc } from 'firebase/firestore';
import { auth, db } from '../config/firebase';
import logo from '../assets/caride_logo_2.png';

function mapStaffAuthError(err: unknown): string {
  if (typeof navigator !== 'undefined' && !navigator.onLine) {
    return 'No internet connection detected. Please check your network connection and try again.';
  }
  if (err instanceof FirebaseError) {
    switch (err.code) {
      case 'auth/invalid-email':
        return 'The email address entered is not valid. Please check for typos and try again.';
      case 'auth/user-disabled':
        return 'This staff account has been disabled by Administrator. Please contact support.';
      case 'auth/user-not-found':
      case 'auth/wrong-password':
      case 'auth/invalid-credential':
        return 'Incorrect staff email or password. Please verify your credentials and try again.';
      case 'auth/too-many-requests':
        return 'Too many failed login attempts. For security reasons, please wait a few minutes before trying again.';
      case 'auth/network-request-failed':
        return 'No internet connection or network failure. Please verify your connection and try again.';
      case 'auth/invalid-api-key':
      case 'auth/configuration-not-found':
        return 'Firebase Authentication is misconfigured. Please check environment settings.';
      case 'auth/quota-exceeded':
        return 'Authentication quota exceeded. Please try again later.';
      default:
        return err.message || 'Staff sign-in failed. Please try again.';
    }
  }
  if (err instanceof Error) return err.message;
  return 'Staff sign-in failed. Please try again.';
}

export function StaffLoginPage() {
  const navigate = useNavigate();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    // Check if user is already authenticated as staff
    const user = auth.currentUser;
    if (user) {
      getDoc(doc(db, 'staff', user.uid)).then((snap) => {
        if (snap.exists() && snap.data()?.accountStatus !== 'disabled') {
          navigate('/staff/dashboard', { replace: true });
        }
      });
    }
  }, [navigate]);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);

    try {
      const userCred = await signInWithEmailAndPassword(auth, email.trim(), password);
      const uid = userCred.user.uid;

      // 1. Verify staff existence in 'staff' collection
      const staffSnap = await getDoc(doc(db, 'staff', uid));
      if (!staffSnap.exists()) {
        await signOut(auth);
        setError('Access denied. Only registered staff members can sign in here. If you are an administrator, please use the Admin Login page.');
        return;
      }

      // 2. Check account status
      const staffData = staffSnap.data();
      if (staffData?.accountStatus === 'disabled' || staffData?.accountStatus === 'suspended') {
        await signOut(auth);
        setError('Your staff account has been disabled or suspended. Please contact Administrator.');
        return;
      }

      // 3. Successful Staff Login -> Navigate to Staff Dashboard
      navigate('/staff/dashboard', { replace: true });
    } catch (err) {
      setError(mapStaffAuthError(err));
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="login-page">
      {/* Left side: Hero Banner */}
      <div className="login-side-hero" style={{ background: 'linear-gradient(135deg, #0F172A 0%, #1E1B4B 100%)' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <img src={logo} alt="CaRide Logo" style={{ height: 40, width: 40, objectFit: 'contain', borderRadius: 'var(--radius-md)' }} />
          <span style={{ fontWeight: 800, fontSize: '1.35rem', letterSpacing: '-0.03em' }}>CaRide Staff Portal</span>
        </div>
        
        <div style={{ maxWidth: 460, margin: 'auto 0' }}>
          <div style={{ background: 'rgba(99, 102, 241, 0.2)', color: '#818CF8', border: '1px solid rgba(99, 102, 241, 0.4)', padding: '4px 12px', borderRadius: 20, fontSize: '0.8rem', fontWeight: 700, display: 'inline-block', marginBottom: 16 }}>
            STAFF REFERRAL & COMMISSION PORTAL
          </div>
          <h1 style={{ color: '#fff', fontSize: '2.4rem', fontWeight: 800, lineHeight: 1.15, marginBottom: '1rem', letterSpacing: '-0.03em' }}>
            Track referrals. Monitor earnings.
          </h1>
          <p style={{ color: '#ffffff', fontSize: '1.05rem', lineHeight: 1.6, margin: 0 }}>
            Log in to view your referral code & link, track riders and drivers joining through your downline, check your commission wallet, and request bank payouts.
          </p>
        </div>

        <div className="desktop-only" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: '0.85rem', color: 'var(--color-text-light)', width: '100%' }}>
          <span>© 2026 CaRide Inc.</span>
          <span>Staff Portal v1.0</span>
        </div>
      </div>

      {/* Right side: Login Form */}
      <div className="login-form-container">
        <div className="login-card">
          <div style={{ marginBottom: '2rem' }}>
            <h2 style={{ fontSize: '1.5rem', fontWeight: 700, margin: '0 0 0.5rem 0', letterSpacing: '-0.02em' }}>Staff Sign In</h2>
            <p style={{ color: 'var(--color-text-muted)', fontSize: '0.875rem', margin: 0 }}>
              Enter your registered staff email and password to access your portal
            </p>
          </div>

          <form onSubmit={onSubmit}>
            <div className="field">
              <label htmlFor="staff-email">Staff Email</label>
              <input
                id="staff-email"
                type="email"
                placeholder="staff@caride.com"
                autoComplete="username"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                required
              />
            </div>
            <div className="field">
              <label htmlFor="staff-password">Password</label>
              <div style={{ position: 'relative' }}>
                <input
                  id="staff-password"
                  type={showPassword ? 'text' : 'password'}
                  placeholder="••••••••"
                  autoComplete="current-password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  style={{ width: '100%', paddingRight: 40 }}
                  required
                />
                <button
                  type="button"
                  onClick={() => setShowPassword((prev) => !prev)}
                  style={{
                    position: 'absolute',
                    right: 10,
                    top: '50%',
                    transform: 'translateY(-50%)',
                    background: 'none',
                    border: 'none',
                    cursor: 'pointer',
                    color: 'var(--color-text-muted)',
                    display: 'flex',
                    alignItems: 'center',
                    justifyContent: 'center',
                    padding: 4,
                  }}
                  title={showPassword ? 'Hide password' : 'Show password'}
                >
                  {showPassword ? (
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" width="18" height="18" strokeLinecap="round" strokeLinejoin="round">
                      <path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24" />
                      <line x1="1" y1="1" x2="23" y2="23" />
                    </svg>
                  ) : (
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" width="18" height="18" strokeLinecap="round" strokeLinejoin="round">
                      <path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" />
                      <circle cx="12" cy="12" r="3" />
                    </svg>
                  )}
                </button>
              </div>
            </div>
            
            {error && (
              <div style={{ 
                background: 'var(--color-error-light)', 
                border: '1px solid var(--color-error)', 
                color: 'var(--color-error)', 
                padding: 'var(--space-3)', 
                borderRadius: 'var(--radius-md)', 
                fontSize: '0.85rem',
                fontWeight: 500,
                marginBottom: '1.5rem'
              }}>
                {error}
              </div>
            )}

            <button type="submit" className="btn btn--primary" disabled={loading} style={{ width: '100%', height: 44, fontSize: '0.95rem', background: '#6366F1' }}>
              {loading ? (
                <>
                  <svg className="animate-spin" style={{ width: 18, height: 18, marginRight: 8, animation: 'spin 1s linear infinite' }} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3">
                    <circle cx="12" cy="12" r="10" opacity="0.25" />
                    <path d="M4 12a8 8 0 0 1 8-8V0C5.373 0 0 5.373 0 12h4z" />
                  </svg>
                  <span>Signing in as Staff…</span>
                </>
              ) : (
                'Sign in to Staff Portal'
              )}
            </button>
          </form>

          <div style={{ marginTop: '1.5rem', textAlign: 'center', fontSize: '0.85rem' }}>
            <span style={{ color: 'var(--color-text-muted)' }}>Are you an Admin? </span>
            <button
              type="button"
              style={{ background: 'none', border: 'none', color: 'var(--color-primary)', fontWeight: 600, cursor: 'pointer', padding: 0 }}
              onClick={() => navigate('/admin/login')}
            >
              Go to Admin Login Page →
            </button>
          </div>
        </div>
      </div>

      <div className="mobile-only" style={{ padding: '0 var(--space-6) var(--space-6) var(--space-6)', textAlign: 'center', fontSize: '0.85rem', color: 'rgba(255, 255, 255, 0.6)', zIndex: 10 }}>
        <div>© 2026 CaRide Inc. · Staff Portal</div>
      </div>
      
      <style>{`
        @keyframes spin {
          to { transform: rotate(360deg); }
        }
      `}</style>
    </div>
  );
}
