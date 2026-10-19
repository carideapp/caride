import { FirebaseError } from 'firebase/app';
import { type FormEvent, useEffect, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { signInWithEmailAndPassword, signOut as firebaseSignOut } from 'firebase/auth';
import { doc, getDoc } from 'firebase/firestore';
import { auth, db } from '../config/firebase';
import { useAuth } from '../auth/useAuth';
import logo from '../assets/caride_logo_2.png';

function mapAuthError(err: unknown): string {
  if (typeof navigator !== 'undefined' && !navigator.onLine) {
    return 'No internet connection detected. Please check your network connection and try again.';
  }
  if (err instanceof FirebaseError) {
    switch (err.code) {
      case 'auth/invalid-email':
        return 'The email address entered is not valid. Please check for typos and try again.';
      case 'auth/user-disabled':
        return 'This Administrator account has been disabled. Please contact system support.';
      case 'auth/user-not-found':
      case 'auth/wrong-password':
      case 'auth/invalid-credential':
        return 'Incorrect email or password. Please verify your Administrator credentials and try again.';
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
        return err.message || 'Sign-in failed. Please try again.';
    }
  }
  if (err instanceof Error) return err.message;
  return 'Sign-in failed. Please try again.';
}

export function LoginPage() {
  const { isAuthenticated } = useAuth();
  const navigate = useNavigate();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    if (isAuthenticated) {
      navigate('/admin/dashboard', { replace: true });
    }
  }, [isAuthenticated, navigate]);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    setError(null);
    setLoading(true);
    try {
      const userCred = await signInWithEmailAndPassword(auth, email.trim(), password);
      const uid = userCred.user.uid;

      // Verify admin role in 'admins' collection
      const adminSnap = await getDoc(doc(db, 'admins', uid));
      if (!adminSnap.exists()) {
        await firebaseSignOut(auth);
        setError('Access denied. Only registered Administrators can sign in here. If you are a Staff member, please use the Staff Login page.');
        return;
      }

      navigate('/admin/dashboard', { replace: true });
    } catch (err) {
      setError(mapAuthError(err));
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="login-page">
      {/* Left side: Premium Hero Banner */}
      <div className="login-side-hero">
        <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
          <img src={logo} alt="CaRide Logo" style={{ height: 40, width: 40, objectFit: 'contain', borderRadius: 'var(--radius-md)' }} />
          <span style={{ fontWeight: 800, fontSize: '1.35rem', letterSpacing: '-0.03em' }}>CaRide Command</span>
        </div>
        
        <div style={{ maxWidth: 460, margin: 'auto 0' }}>
          <h1 style={{ color: '#fff', fontSize: '2.5rem', fontWeight: 800, lineHeight: 1.15, marginBottom: '1rem', letterSpacing: '-0.03em' }}>
            Empower mobility. Manage operations.
          </h1>
          <p style={{ color: '#ffffff', fontSize: '1.1rem', lineHeight: 1.6, margin: 0 }}>
            Log in to access the real-time operational dashboard, monitor rides, onboard drivers, approve financial withdrawals, and secure the marketplace.
          </p>
        </div>

        <div className="desktop-only" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', fontSize: '0.85rem', color: 'var(--color-text-light)', width: '100%' }}>
          <span>© 2026 CaRide Inc.</span>
          <span>v2.1.0</span>
        </div>
      </div>

      {/* Right side: Login form */}
      <div className="login-form-container">
        <div className="login-card" style={{ borderRadius: 24, padding: '36px 32px' }}>
          <div style={{ marginBottom: '1.75rem' }}>
            <h2 style={{ fontSize: '1.65rem', fontWeight: 800, margin: '0 0 0.5rem 0', letterSpacing: '-0.02em' }}>Welcome back!</h2>
            <p style={{ color: 'var(--color-text-muted)', fontSize: '0.885rem', margin: 0 }}>
              Please enter your admin credentials to sign in
            </p>
          </div>

          <form onSubmit={onSubmit}>
            <div className="field">
              <label htmlFor="email">Work Email</label>
              <div style={{ position: 'relative', display: 'flex', alignItems: 'center' }}>
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" style={{ position: 'absolute', left: 16, width: 18, height: 18, color: 'var(--color-text-light)' }}>
                  <path d="M4 4h16c1.1 0 2 .9 2 2v12c0 1.1-.9 2-2 2H4c-1.1 0-2-.9-2-2V6c0-1.1.9-2 2-2z" />
                  <polyline points="22,6 12,13 2,6" />
                </svg>
                <input
                  id="email"
                  type="email"
                  placeholder="admin@caride.com"
                  autoComplete="username"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  style={{ width: '100%', paddingLeft: 46 }}
                  required
                />
              </div>
            </div>

            <div className="field">
              <label htmlFor="password">Password</label>
              <div style={{ position: 'relative', display: 'flex', alignItems: 'center' }}>
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" style={{ position: 'absolute', left: 16, width: 18, height: 18, color: 'var(--color-text-light)' }}>
                  <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
                  <path d="M7 11V7a5 5 0 0 1 10 0v4" />
                </svg>
                <input
                  id="password"
                  type={showPassword ? 'text' : 'password'}
                  placeholder="••••••••"
                  autoComplete="current-password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  style={{ width: '100%', paddingLeft: 46, paddingRight: 46 }}
                  minLength={8}
                  required
                />
                <button
                  type="button"
                  onClick={() => setShowPassword((prev) => !prev)}
                  style={{
                    position: 'absolute',
                    right: 14,
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

            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', margin: '14px 0 20px 0', fontSize: '0.85rem' }}>
              <label style={{ display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer', color: 'var(--color-text-muted)' }}>
                <input type="checkbox" style={{ accentColor: 'var(--color-primary)' }} defaultChecked />
                <span>Remember me</span>
              </label>
              <span style={{ color: 'var(--color-primary)', fontWeight: 600, cursor: 'pointer' }}>
                Forgot Password?
              </span>
            </div>
            
            {error && (
              <div style={{ 
                background: '#FEF2F2', 
                border: '1px solid #FECACA', 
                color: '#991B1B', 
                padding: '12px 16px', 
                borderRadius: 16, 
                fontSize: '0.85rem',
                fontWeight: 500,
                marginBottom: '1.5rem'
              }}>
                {error}
              </div>
            )}

            <button type="submit" className="btn btn--primary" disabled={loading} style={{ width: '100%', height: 48, fontSize: '0.95rem', borderRadius: 'var(--radius-full)', fontWeight: 700 }}>
              {loading ? (
                <>
                  <svg className="animate-spin" style={{ width: 18, height: 18, marginRight: 8, animation: 'spin 1s linear infinite' }} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="3">
                    <circle cx="12" cy="12" r="10" opacity="0.25" />
                    <path d="M4 12a8 8 0 0 1 8-8V0C5.373 0 0 5.373 0 12h4z" />
                  </svg>
                  <span>Signing in…</span>
                </>
              ) : (
                'Sign In'
              )}
            </button>
          </form>

          <div style={{ marginTop: '1.75rem', textAlign: 'center', fontSize: '0.85rem' }}>
            <span style={{ color: 'var(--color-text-muted)' }}>Are you a staff member? </span>
            <button
              type="button"
              style={{ background: 'none', border: 'none', color: 'var(--color-primary)', fontWeight: 700, cursor: 'pointer', padding: 0 }}
              onClick={() => navigate('/staff/login')}
            >
              Go to Staff Login →
            </button>
          </div>
        </div>
      </div>

      <div className="mobile-only" style={{ padding: '0 var(--space-6) var(--space-6) var(--space-6)', textAlign: 'center', fontSize: '0.85rem', color: 'rgba(255, 255, 255, 0.6)', zIndex: 10 }}>
        <div>© 2026 CaRide Inc. · v2.1.0</div>
      </div>
      
      {/* Dynamic Keyframe style helper for login spinner */}
      <style>{`
        @keyframes spin {
          to { transform: rotate(360deg); }
        }
      `}</style>
    </div>
  );
}
