import { useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';

const PLAY_STORE_URL = 'https://play.google.com/store/apps/details?id=com.caride.app';
const APP_STORE_URL  = 'https://apps.apple.com/ng/app/caride-ride-delivery/id6802303889';
const REDIRECT_DELAY_MS = 2500;

type DeviceType = 'android' | 'ios' | 'other';

function detectDevice(): DeviceType {
  const ua = navigator.userAgent.toLowerCase();
  if (/android/.test(ua)) return 'android';
  if (/iphone|ipad|ipod/.test(ua)) return 'ios';
  return 'other';
}

function getLinkLabel(type: string | undefined): string {
  if (type === 'referral') return 'Referral Invitation';
  if (type === 'trip')     return 'Shared Trip';
  return 'CaRide Link';
}

function getDescription(type: string | undefined, code: string | undefined): string {
  if (type === 'referral' && code) return `You were invited to join CaRide with referral code ${code}. Download the app to complete your registration.`;
  if (type === 'trip' && code)     return `Someone shared a live CaRide trip with you (code: ${code}). Download the app to monitor the journey.`;
  return 'Download CaRide to continue.';
}

export function AppDeepLinkPage() {
  const { type, code } = useParams<{ type?: string; code?: string }>();
  const [device] = useState<DeviceType>(detectDevice);
  const [countdown, setCountdown] = useState(Math.floor(REDIRECT_DELAY_MS / 1000));
  const [attempted, setAttempted] = useState(false);

  const storeUrl = device === 'ios' ? APP_STORE_URL : PLAY_STORE_URL;
  const customScheme = type && code ? `caride://app/${type}/${code}` : 'caride://app';
  const linkLabel = getLinkLabel(type);
  const description = getDescription(type, code);

  useEffect(() => {
    // Attempt to open the app via custom scheme
    if (!attempted) {
      setAttempted(true);
      window.location.href = customScheme;
    }

    // Countdown ticker
    const interval = setInterval(() => {
      setCountdown(prev => {
        if (prev <= 1) {
          clearInterval(interval);
          // Redirect to store if app didn't open
          if (device !== 'other') {
            window.location.href = storeUrl;
          }
          return 0;
        }
        return prev - 1;
      });
    }, 1000);

    return () => clearInterval(interval);
  }, []); // eslint-disable-line react-hooks/exhaustive-deps

  return (
    <div style={styles.root}>
      <div style={styles.card}>
        {/* Logo */}
        <div style={styles.logoWrap}>
          <img src="/caride_logo.png" alt="CaRide" style={styles.logo} onError={(e) => { (e.target as HTMLImageElement).style.display = 'none'; }} />
          <span style={styles.logoText}>CaRide</span>
        </div>

        {/* Icon */}
        <div style={styles.iconWrap}>
          {type === 'referral' ? (
            <svg style={styles.icon} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
              <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/>
              <circle cx="9" cy="7" r="4"/>
              <path d="M23 21v-2a4 4 0 0 0-3-3.87"/>
              <path d="M16 3.13a4 4 0 0 1 0 7.75"/>
            </svg>
          ) : type === 'trip' ? (
            <svg style={styles.icon} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
              <circle cx="12" cy="12" r="10"/>
              <polyline points="12 6 12 12 16 14"/>
            </svg>
          ) : (
            <svg style={styles.icon} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth={2} strokeLinecap="round" strokeLinejoin="round">
              <path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>
            </svg>
          )}
        </div>

        <h1 style={styles.title}>{linkLabel}</h1>
        <p style={styles.desc}>{description}</p>

        {/* Code badge */}
        {code && (
          <div style={styles.codeBadge}>
            <span style={styles.codeLabel}>Code:</span>
            <span style={styles.codeValue}>{code}</span>
          </div>
        )}

        {/* Status */}
        {device !== 'other' ? (
          <>
            <p style={styles.status}>
              Opening CaRide app… redirecting to{' '}
              <strong style={{ color: '#FFFFFF' }}>{device === 'ios' ? 'App Store' : 'Google Play'}</strong> in {countdown}s
            </p>

            <a href={storeUrl} style={styles.storeBtn}>
              {device === 'ios' ? (
                <>
                  <svg style={{ width: 18, height: 18, marginRight: 8 }} viewBox="0 0 24 24" fill="currentColor">
                    <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.8-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M13 3.5c.73-.83 1.94-1.46 2.94-1.5.13 1.17-.34 2.35-1.04 3.19-.69.85-1.83 1.51-2.95 1.42-.15-1.15.41-2.35 1.05-3.11z"/>
                  </svg>
                  Download on the App Store
                </>
              ) : (
                <>
                  <svg style={{ width: 18, height: 18, marginRight: 8 }} viewBox="0 0 24 24" fill="currentColor">
                    <path d="M3.18 23.76c.27.15.58.2.9.15l12.18-7.03-2.5-2.5-10.58 9.38zm16.7-10.26L5.66 5.96l-2.5 2.5L15.34 16l4.54-2.5zm0 0"/>
                    <path d="M2.28 1.09C2.1 1.33 2 1.65 2 2.03v19.94c0 .38.1.7.28.94l.05.05 11.16-11.16v-.27L2.33 1.04l-.05.05z"/>
                    <path d="M19.88 13.5l-2.5-1.44-2.5 2.5 2.5 2.52-1.45c.72-.42.72-1.11-.02-1.61z"/>
                  </svg>
                  Get it on Google Play
                </>
              )}
            </a>

            <a href={customScheme} style={styles.openBtn}>
              Open in CaRide App
            </a>
          </>
        ) : (
          <div style={styles.desktopNote}>
            <p style={{ color: 'rgba(255,255,255,0.7)', fontSize: '0.9rem', marginBottom: 16 }}>
              Open this link on your Android or iPhone to download CaRide.
            </p>
            <div style={styles.storeRow}>
              <a href={PLAY_STORE_URL} style={styles.storeBtn}>
                Google Play
              </a>
              <a href={APP_STORE_URL} style={styles.storeBtn}>
                App Store
              </a>
            </div>
          </div>
        )}

        <p style={styles.footer}>
          CaRide &bull; Premium ride-hailing in Nigeria
        </p>
      </div>
    </div>
  );
}

// ── Inline styles (Minimal, flat, zero shadow, pill geometry) ─────────────────

const styles: Record<string, React.CSSProperties> = {
  root: {
    minHeight: '100vh',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    background: '#0B0F19',
    padding: '24px',
    position: 'relative',
    fontFamily: "'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif",
  },
  card: {
    background: '#111827',
    border: '1px solid rgba(255, 255, 255, 0.1)',
    borderRadius: '24px',
    padding: '40px 32px',
    maxWidth: '440px',
    width: '100%',
    textAlign: 'center',
    boxShadow: 'none',
  },
  logoWrap: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    gap: '10px',
    marginBottom: '24px',
  },
  logo: {
    width: 36,
    height: 36,
    objectFit: 'contain',
  },
  logoText: {
    fontSize: '20px',
    fontWeight: 800,
    color: '#FFFFFF',
    letterSpacing: '-0.5px',
  },
  iconWrap: {
    width: 68,
    height: 68,
    borderRadius: '50%',
    background: 'rgba(22, 163, 74, 0.12)',
    border: '1px solid rgba(22, 163, 74, 0.25)',
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    margin: '0 auto 20px',
  },
  icon: {
    width: 32,
    height: 32,
    color: '#16A34A',
  },
  title: {
    fontSize: '22px',
    fontWeight: 800,
    color: '#FFFFFF',
    margin: '0 0 10px',
    letterSpacing: '-0.5px',
  },
  desc: {
    fontSize: '14px',
    color: 'rgba(255, 255, 255, 0.65)',
    lineHeight: 1.6,
    margin: '0 0 20px',
  },
  codeBadge: {
    display: 'inline-flex',
    alignItems: 'center',
    gap: 8,
    background: 'rgba(22, 163, 74, 0.12)',
    border: '1px solid rgba(22, 163, 74, 0.3)',
    borderRadius: '9999px',
    padding: '8px 20px',
    marginBottom: '20px',
  },
  codeLabel: {
    fontSize: '13px',
    color: 'rgba(255, 255, 255, 0.5)',
    fontWeight: 600,
  },
  codeValue: {
    fontSize: '17px',
    fontWeight: 800,
    color: '#22C55E',
    letterSpacing: '2px',
  },
  status: {
    fontSize: '13px',
    color: 'rgba(255, 255, 255, 0.5)',
    margin: '0 0 18px',
  },
  storeBtn: {
    display: 'inline-flex',
    alignItems: 'center',
    justifyContent: 'center',
    background: '#16A34A',
    color: '#FFFFFF',
    padding: '14px 28px',
    borderRadius: '9999px',
    fontWeight: 700,
    fontSize: '15px',
    textDecoration: 'none',
    width: '100%',
    marginBottom: '12px',
    boxSizing: 'border-box',
    border: 'none',
    boxShadow: 'none',
    cursor: 'pointer',
    transition: 'background 0.2s',
  },
  openBtn: {
    display: 'block',
    background: 'transparent',
    color: 'rgba(255, 255, 255, 0.85)',
    border: '1px solid rgba(255, 255, 255, 0.18)',
    padding: '13px 28px',
    borderRadius: '9999px',
    fontWeight: 600,
    fontSize: '14px',
    textDecoration: 'none',
    width: '100%',
    boxSizing: 'border-box',
    boxShadow: 'none',
  },
  desktopNote: {
    marginBottom: 12,
  },
  storeRow: {
    display: 'flex',
    gap: 12,
    marginTop: 12,
  },
  footer: {
    fontSize: '12px',
    color: 'rgba(255, 255, 255, 0.35)',
    marginTop: '28px',
  },
};
