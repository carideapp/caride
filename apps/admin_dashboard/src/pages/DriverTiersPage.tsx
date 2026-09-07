import { useState, useEffect } from 'react';
import {
  collection,
  onSnapshot,
  doc,
  query,
  orderBy,
  writeBatch,
} from 'firebase/firestore';
import { db } from '../config/firebase';

interface DriverRow {
  uid: string;
  fullName: string;
  email: string;
  tier: string;
  completedRides: number;
  averageRating: number;
  totalRatings: number;
}

interface TierSetting {
  id: string;
  name: string;
  commissionPercent: number;
  minTrips: number;
  maxTrips: number | null;
  minRating: number;
  order: number;
}

const TIER_COLORS: Record<string, string> = {
  bronze: '#CD7F32',
  silver: '#94a3b8',
  gold: '#fbbf24',
  platinum: '#a78bfa',
};

const DEFAULT_TIER_SETTINGS: TierSetting[] = [
  { id: 'bronze', name: 'Bronze', commissionPercent: 20, minTrips: 0, maxTrips: 49, minRating: 0, order: 1 },
  { id: 'silver', name: 'Silver', commissionPercent: 19, minTrips: 50, maxTrips: 149, minRating: 4.0, order: 2 },
  { id: 'gold', name: 'Gold', commissionPercent: 18, minTrips: 150, maxTrips: 299, minRating: 4.5, order: 3 },
  { id: 'platinum', name: 'Platinum', commissionPercent: 17, minTrips: 300, maxTrips: null, minRating: 4.7, order: 4 },
];

function TierBadge({ tier }: { tier: string }) {
  const color = TIER_COLORS[tier] ?? TIER_COLORS.bronze;
  return (
    <span
      style={{
        display: 'inline-flex',
        alignItems: 'center',
        gap: 4,
        padding: '3px 10px',
        borderRadius: 'var(--radius-full)',
        fontSize: '0.7rem',
        fontWeight: 700,
        color: '#fff',
        background: color,
        letterSpacing: '0.04em',
        textTransform: 'uppercase',
      }}
    >
      ★ {tier}
    </span>
  );
}

function ProgressBar({ value }: { value: number }) {
  const pct = Math.min(100, Math.max(0, Math.round(value * 100)));
  return (
    <div
      style={{
        height: 6,
        background: 'var(--color-border)',
        borderRadius: 'var(--radius-full)',
        overflow: 'hidden',
        minWidth: 80,
      }}
    >
      <div
        style={{
          height: '100%',
          width: `${pct}%`,
          background: 'var(--color-primary)',
          borderRadius: 'var(--radius-full)',
          transition: 'width 0.3s',
        }}
      />
    </div>
  );
}

function DriversTab({ drivers, tierSettings }: { drivers: DriverRow[]; tierSettings: TierSetting[] }) {
  const sortedTiers = [...tierSettings].sort((a, b) => a.order - b.order);

  function getNextTier(currentTier: string): TierSetting | null {
    const currentIdx = sortedTiers.findIndex((t) => t.id === currentTier);
    if (currentIdx === -1 || currentIdx === sortedTiers.length - 1) return null;
    return sortedTiers[currentIdx + 1];
  }

  function getProgress(driver: DriverRow): number {
    const next = getNextTier(driver.tier);
    if (!next) return 1;
    const current = sortedTiers.find((t) => t.id === driver.tier);
    const minTrips = current?.minTrips ?? 0;
    const span = next.minTrips - minTrips;
    if (span <= 0) return 1;
    return (driver.completedRides - minTrips) / span;
  }

  if (drivers.length === 0) {
    return (
      <div className="empty-state">
        <p className="muted">No drivers found.</p>
      </div>
    );
  }

  return (
    <div className="card" style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-2)' }}>
      {drivers.map((driver) => {
        const next = getNextTier(driver.tier);
        const progress = getProgress(driver);
        return (
          <div key={driver.uid} className="table-row" style={{ flexDirection: 'column', alignItems: 'stretch', gap: 12, padding: '16px 0' }}>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 12 }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                <div className="admin-avatar" style={{ background: 'var(--color-primary-light)', color: 'var(--color-primary)', width: 38, height: 38 }}>
                  {(driver.fullName || driver.email)[0].toUpperCase()}
                </div>
                <div>
                  <div style={{ fontWeight: 700, fontSize: '0.95rem' }}>{driver.fullName || '(no name)'}</div>
                  <div className="muted" style={{ fontSize: '0.8rem' }}>{driver.email}</div>
                </div>
              </div>
              
              <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-4)', flexWrap: 'wrap' }}>
                <TierBadge tier={driver.tier} />
                <div style={{ textAlign: 'right' }}>
                  <div style={{ fontWeight: 700, fontSize: '0.9rem' }}>{driver.completedRides} Trips</div>
                  <div className="muted" style={{ fontSize: '0.78rem', marginTop: 2 }}>
                    ★ {driver.averageRating > 0 ? driver.averageRating.toFixed(1) : '—'}
                    {driver.totalRatings > 0 ? ` (${driver.totalRatings})` : ''}
                  </div>
                </div>
              </div>
            </div>

            {next ? (
              <div style={{ width: '100%', marginTop: 4 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 6 }}>
                  <span className="muted" style={{ fontSize: '0.75rem', fontWeight: 600 }}>
                    Progress to {next.name} ({next.minTrips - driver.completedRides > 0 ? `${next.minTrips - driver.completedRides} trips to go` : 'Goal met!'})
                  </span>
                  <span className="muted" style={{ fontSize: '0.75rem', fontWeight: 600 }}>
                    {Math.min(100, Math.round(progress * 100))}%
                  </span>
                </div>
                <ProgressBar value={progress} />
              </div>
            ) : (
              <div style={{ marginTop: 4 }}>
                <span className="badge badge--ok" style={{ fontSize: '0.7rem' }}>Top Tier Achieved</span>
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}

function TierSettingsTab({ tierSettings }: { tierSettings: TierSetting[] }) {
  const [editing, setEditing] = useState<Record<string, TierSetting>>({});
  const [saving, setSaving] = useState<boolean>(false);
  const [saved, setSaved] = useState<boolean>(false);

  const sorted = [...tierSettings].sort((a, b) => a.order - b.order);

  function getEditing(tier: TierSetting): TierSetting {
    return editing[tier.id] ?? tier;
  }

  function updateField(tierId: string, field: keyof TierSetting, value: string | number | null) {
    setEditing((prev) => ({
      ...prev,
      [tierId]: { ...(prev[tierId] ?? tierSettings.find((t) => t.id === tierId)!), [field]: value },
    }));
  }

  const isDirty = Object.keys(editing).length > 0;

  async function saveAllTiers() {
    setSaving(true);
    try {
      const batch = writeBatch(db);
      
      // Save all 4 tiers (with edits applied) to Firestore
      sorted.forEach((tier) => {
        const data = getEditing(tier);
        const tierRef = doc(db, 'tierSettings', tier.id);
        batch.set(tierRef, {
          name: data.name,
          commissionPercent: Number(data.commissionPercent),
          minTrips: Number(data.minTrips),
          maxTrips: data.maxTrips != null ? Number(data.maxTrips) : null,
          minRating: Number(data.minRating),
          order: data.order,
        });
      });

      await batch.commit();
      setEditing({});
      setSaved(true);
      setTimeout(() => setSaved(false), 2000);
    } catch (e) {
      console.error('Failed to save tiers', e);
      alert('Failed to save. Check console for details.');
    } finally {
      setSaving(false);
    }
  }

  function resetAllToSystemDefaults() {
    const defaults: Record<string, TierSetting> = {};
    DEFAULT_TIER_SETTINGS.forEach((t) => {
      defaults[t.id] = t;
    });
    setEditing(defaults);
  }

  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-4)' }}>
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', flexWrap: 'wrap', gap: 16 }}>
        <p className="muted" style={{ margin: 0 }}>
          Updates are applied live. Commission parameters take effect on a driver's next completed ride.
        </p>
        <div style={{ display: 'flex', gap: 'var(--space-2)', alignItems: 'center' }}>
          {saved && <span className="badge badge--ok">All Saved ✓</span>}
          <button
            type="button"
            className="btn btn--primary"
            disabled={!isDirty || saving}
            onClick={saveAllTiers}
          >
            {saving ? 'Saving…' : 'Save All Changes'}
          </button>
          {isDirty && (
            <button
              type="button"
              className="btn btn--ghost"
              onClick={() => setEditing({})}
            >
              Discard Changes
            </button>
          )}
          <button
            type="button"
            className="btn btn--ghost"
            onClick={resetAllToSystemDefaults}
          >
            Reset All to Defaults
          </button>
        </div>
      </div>
      
      {sorted.map((tier) => {
        const data = getEditing(tier);
        return (
          <div
            key={tier.id}
            className="card"
            style={{ borderLeft: `4px solid ${TIER_COLORS[tier.id] ?? '#ccc'}`, padding: 'var(--space-5)' }}
          >
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 'var(--space-4)' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-3)' }}>
                <div
                  style={{
                    width: 14,
                    height: 14,
                    borderRadius: '50%',
                    background: TIER_COLORS[tier.id] ?? '#ccc',
                  }}
                />
                <strong style={{ fontSize: '1.15rem', fontWeight: 800 }}>{tier.name} Tier Settings</strong>
              </div>
            </div>
            
            <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(200px, 1fr))', gap: 'var(--space-4)' }}>
              <div className="field">
                <label>Tier Name</label>
                <input
                  type="text"
                  value={data.name}
                  onChange={(e) => updateField(tier.id, 'name', e.target.value)}
                />
              </div>
              <div className="field">
                <label>Commission Percentage (%)</label>
                <input
                  type="number"
                  min={0}
                  max={100}
                  step={0.5}
                  value={data.commissionPercent}
                  onChange={(e) => updateField(tier.id, 'commissionPercent', parseFloat(e.target.value))}
                />
              </div>
              <div className="field">
                <label>Min Trips</label>
                <input
                  type="number"
                  min={0}
                  value={data.minTrips}
                  onChange={(e) => updateField(tier.id, 'minTrips', parseInt(e.target.value, 10))}
                />
              </div>
              <div className="field">
                <label>Max Trips (blank = unlimited)</label>
                <input
                  type="number"
                  min={0}
                  value={data.maxTrips ?? ''}
                  placeholder="Unlimited"
                  onChange={(e) =>
                    updateField(tier.id, 'maxTrips', e.target.value === '' ? null : parseInt(e.target.value, 10))
                  }
                />
              </div>
              <div className="field">
                <label>Min Rating (0 = none)</label>
                <input
                  type="number"
                  min={0}
                  max={5}
                  step={0.1}
                  value={data.minRating}
                  onChange={(e) => updateField(tier.id, 'minRating', parseFloat(e.target.value))}
                />
              </div>
            </div>
          </div>
        );
      })}
    </div>
  );
}

export function DriverTiersPage() {
  const [activeTab, setActiveTab] = useState<'drivers' | 'settings'>('drivers');
  const [drivers, setDrivers] = useState<DriverRow[]>([]);
  const [tierSettings, setTierSettings] = useState<TierSetting[]>(DEFAULT_TIER_SETTINGS);
  const [loadingDrivers, setLoadingDrivers] = useState(true);
  const [loadingTiers, setLoadingTiers] = useState(true);

  useEffect(() => {
    const unsub = onSnapshot(
      query(collection(db, 'drivers'), orderBy('completedRides', 'desc')),
      (snap) => {
        const rows: DriverRow[] = snap.docs.map((docSnap) => {
          const d = docSnap.data();
          return {
            uid: docSnap.id,
            fullName: (d.fullName as string) || '',
            email: (d.email as string) || '',
            tier: (d.tier as string) || 'bronze',
            completedRides: (d.completedRides as number) || 0,
            averageRating: (d.averageRating as number) || 0,
            totalRatings: (d.totalRatings as number) || 0,
          };
        });
        setDrivers(rows);
        setLoadingDrivers(false);
      },
      () => setLoadingDrivers(false),
    );
    return () => unsub();
  }, []);

  useEffect(() => {
    const unsub = onSnapshot(
      query(collection(db, 'tierSettings'), orderBy('order')),
      (snap) => {
        const rows: TierSetting[] = DEFAULT_TIER_SETTINGS.map((def) => {
          const docSnap = snap.docs.find((d) => d.id === def.id);
          if (docSnap) {
            const d = docSnap.data();
            return {
              id: docSnap.id,
              name: (d.name as string) || docSnap.id,
              commissionPercent: d.commissionPercent !== undefined ? (d.commissionPercent as number) : def.commissionPercent,
              minTrips: d.minTrips !== undefined ? (d.minTrips as number) : def.minTrips,
              maxTrips: d.maxTrips !== undefined ? (d.maxTrips as number | null) : def.maxTrips,
              minRating: d.minRating !== undefined ? (d.minRating as number) : def.minRating,
              order: d.order !== undefined ? (d.order as number) : def.order,
            };
          }
          return def;
        });
        setTierSettings(rows);
        setLoadingTiers(false);
      },
      () => setLoadingTiers(false),
    );
    return () => unsub();
  }, []);

  return (
    <div>
      <div style={{ marginBottom: 'var(--space-5)' }}>
        <p className="muted" style={{ margin: 0 }}>
          Manage driver advancement criteria, minimum rating constraints, and commission collection scales.
        </p>
      </div>

      {/* Driver Tier counts overview cards */}
      <div className="card-grid" style={{ marginBottom: 'var(--space-5)' }}>
        {(['bronze', 'silver', 'gold', 'platinum'] as const).map((tier) => {
          const count = drivers.filter((d) => d.tier === tier).length;
          return (
            <article key={tier} className="card">
              <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-2)', marginBottom: 'var(--space-2)' }}>
                <div style={{ width: 10, height: 10, borderRadius: '50%', background: TIER_COLORS[tier] }} />
                <span className="muted" style={{ fontSize: '0.85rem', textTransform: 'capitalize', fontWeight: 600 }}>{tier} Tier</span>
              </div>
              <div style={{ fontSize: '2rem', fontWeight: 800, letterSpacing: '-0.02em' }}>{count}</div>
              <div className="muted" style={{ fontSize: '0.75rem' }}>active driver{count !== 1 ? 's' : ''}</div>
            </article>
          );
        })}
      </div>

      {/* Toggles */}
      <div style={{ display: 'flex', gap: 'var(--space-2)', borderBottom: '1px solid var(--color-border)', paddingBottom: 'var(--space-3)', marginBottom: 'var(--space-5)' }}>
        <button
          type="button"
          className={`btn ${activeTab === 'drivers' ? 'btn--primary' : 'btn--ghost'}`}
          onClick={() => setActiveTab('drivers')}
        >
          Drivers
        </button>
        <button
          type="button"
          className={`btn ${activeTab === 'settings' ? 'btn--primary' : 'btn--ghost'}`}
          onClick={() => setActiveTab('settings')}
        >
          Tier Configuration
        </button>
      </div>

      {activeTab === 'drivers' && (
        loadingDrivers
          ? <div className="card"><p className="muted">Loading drivers…</p></div>
          : <DriversTab drivers={drivers} tierSettings={tierSettings} />
      )}

      {activeTab === 'settings' && (
        loadingTiers
          ? <div className="card"><p className="muted">Loading configurations…</p></div>
          : <TierSettingsTab tierSettings={tierSettings} />
      )}
    </div>
  );
}
