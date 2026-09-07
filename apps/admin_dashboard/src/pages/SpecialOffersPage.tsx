import { useEffect, useState } from 'react';
import {
  collection,
  onSnapshot,
  orderBy,
  query,
  addDoc,
  updateDoc,
  deleteDoc,
  doc,
  serverTimestamp,
  type QuerySnapshot,
  type DocumentData,
} from 'firebase/firestore';
import { db } from '../config/firebase';

interface Promo {
  id: string;
  code: string;
  discountType: 'percentage' | 'flat';
  discountValue: number;
  minFare: number;
  maxCap: number;
  isActive: boolean;
  expiryDate: string | null;
  usageLimitPerCustomer: number;
  createdAt: any;
}

export function SpecialOffersPage() {
  const [promos, setPromos] = useState<Promo[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Form State
  const [code, setCode] = useState('');
  const [discountType, setDiscountType] = useState<'percentage' | 'flat'>('percentage');
  const [discountValue, setDiscountValue] = useState(0);
  const [minFare, setMinFare] = useState(0);
  const [maxCap, setMaxCap] = useState(0);
  const [expiryDate, setExpiryDate] = useState('');
  const [isActive, setIsActive] = useState(true);
  const [usageLimitPerCustomer, setUsageLimitPerCustomer] = useState(0);
  const [editingPromoId, setEditingPromoId] = useState<string | null>(null);

  useEffect(() => {
    const q = query(collection(db, 'promos'), orderBy('createdAt', 'desc'));
    const unsub = onSnapshot(
      q,
      (snap: QuerySnapshot<DocumentData>) => {
        const rows: Promo[] = snap.docs.map((docSnap) => {
          const d = docSnap.data();
          return {
            id: docSnap.id,
            code: d.code || '',
            discountType: d.discountType || 'percentage',
            discountValue: Number(d.discountValue) || 0,
            minFare: Number(d.minFare) || 0,
            maxCap: Number(d.maxCap) || 0,
            isActive: !!d.isActive,
            expiryDate: d.expiryDate ? (d.expiryDate instanceof Date ? d.expiryDate.toISOString().split('T')[0] : (typeof d.expiryDate === 'string' ? d.expiryDate.split('T')[0] : d.expiryDate.toDate?.().toISOString().split('T')[0] || null)) : null,
            usageLimitPerCustomer: Number(d.usageLimitPerCustomer) || 0,
            createdAt: d.createdAt,
          };
        });
        setPromos(rows);
        setLoading(false);
      },
      (err) => {
        setError(err.message);
        setLoading(false);
      }
    );

    return () => unsub();
  }, []);

  const handleCreate = async (e: React.FormEvent) => {
    e.preventDefault();
    setError(null);

    const uppercaseCode = code.trim().toUpperCase();
    if (!uppercaseCode) {
      setError('Promo code is required');
      return;
    }

    // Exclude currently editing promo from duplicate code check
    if (promos.some(p => p.code === uppercaseCode && p.id !== editingPromoId)) {
      setError('Promo code already exists');
      return;
    }

    if (discountValue <= 0) {
      setError('Discount value must be greater than zero');
      return;
    }

    try {
      if (editingPromoId) {
        const docRef = doc(db, 'promos', editingPromoId);
        await updateDoc(docRef, {
          code: uppercaseCode,
          discountType,
          discountValue: Number(discountValue),
          minFare: Number(minFare),
          maxCap: Number(maxCap),
          isActive,
          expiryDate: expiryDate ? new Date(expiryDate) : null,
          usageLimitPerCustomer: Number(usageLimitPerCustomer),
        });
        setEditingPromoId(null);
      } else {
        await addDoc(collection(db, 'promos'), {
          code: uppercaseCode,
          discountType,
          discountValue: Number(discountValue),
          minFare: Number(minFare),
          maxCap: Number(maxCap),
          isActive,
          expiryDate: expiryDate ? new Date(expiryDate) : null,
          usageLimitPerCustomer: Number(usageLimitPerCustomer),
          createdAt: serverTimestamp(),
        });
      }

      // Clear Form
      setCode('');
      setDiscountValue(0);
      setMinFare(0);
      setMaxCap(0);
      setExpiryDate('');
      setIsActive(true);
      setUsageLimitPerCustomer(0);
    } catch (err: any) {
      setError(err.message);
    }
  };

  const toggleActive = async (id: string, currentStatus: boolean) => {
    try {
      const docRef = doc(db, 'promos', id);
      await updateDoc(docRef, { isActive: !currentStatus });
    } catch (err: any) {
      setError(err.message);
    }
  };

  const handleDelete = async (id: string) => {
    if (!window.confirm('Are you sure you want to delete this promo?')) return;
    try {
      const docRef = doc(db, 'promos', id);
      await deleteDoc(docRef);
    } catch (err: any) {
      setError(err.message);
    }
  };

  return (
    <div>
      <div style={{ marginBottom: 'var(--space-5)' }}>
        <p className="muted" style={{ margin: 0 }}>
          Create and manage promotional discount codes that riders can apply to their rides.
        </p>
      </div>

      {error && (
        <p className="field__error" style={{ marginBottom: 'var(--space-4)', color: 'var(--color-error)' }}>
          {error}
        </p>
      )}

      <div style={{ display: 'grid', gridTemplateColumns: '1fr', gap: 'var(--space-5)' }} className="offers-grid">
        <style>{`
          @media (min-width: 900px) {
            .offers-grid {
              grid-template-columns: 1.5fr 1fr !important;
            }
          }
        `}</style>

        {/* Promos List */}
        <div>
          <h3 style={{ fontSize: '1.05rem', fontWeight: 700, marginBottom: 'var(--space-3)' }}>
            Active & Available Offers ({promos.length})
          </h3>

          {loading && promos.length === 0 ? (
            <div className="card" style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
              {[1, 2].map((i) => (
                <div key={i} className="skeleton-row shimmer" style={{ height: 60 }} />
              ))}
            </div>
          ) : promos.length === 0 ? (
            <article className="card">
              <p className="muted" style={{ marginBottom: 0 }}>
                No promotional offers found. Create one on the right.
              </p>
            </article>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-3)' }}>
              {promos.map((p) => (
                <article key={p.id} className="card" style={{ padding: 'var(--space-4)' }}>
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: 8 }}>
                    <div>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                        <span style={{ fontSize: '1.15rem', fontWeight: 800, color: 'var(--color-primary)' }}>
                          {p.code}
                        </span>
                        <span className={`badge badge--${p.isActive ? 'ok' : 'info'}`}>
                          {p.isActive ? 'Active' : 'Inactive'}
                        </span>
                      </div>
                      <p style={{ margin: 'var(--space-2) 0', fontSize: '0.9rem' }}>
                        {p.discountType === 'percentage' ? `${p.discountValue}% Off` : `₦${p.discountValue} Flat Discount`}
                        {p.minFare > 0 && ` (Min Fare: ₦${p.minFare})`}
                        {p.maxCap > 0 && ` (Max Cap: ₦${p.maxCap})`}
                      </p>
                      <div style={{ display: 'flex', flexDirection: 'column', gap: 2 }}>
                        {p.usageLimitPerCustomer > 0 && (
                          <p className="muted" style={{ margin: 0, fontSize: '0.8rem', fontWeight: 600 }}>
                            Usage limit per customer: {p.usageLimitPerCustomer} {p.usageLimitPerCustomer === 1 ? 'use' : 'uses'}
                          </p>
                        )}
                        {p.expiryDate && (
                          <p className="muted" style={{ margin: 0, fontSize: '0.8rem' }}>
                            Expires: {new Date(p.expiryDate).toLocaleDateString()}
                          </p>
                        )}
                      </div>
                    </div>
                    <div style={{ display: 'flex', gap: 8 }}>
                      <button
                        type="button"
                        className="btn btn--sm btn--primary"
                        onClick={() => {
                          setEditingPromoId(p.id);
                          setCode(p.code);
                          setDiscountType(p.discountType);
                          setDiscountValue(p.discountValue);
                          setMinFare(p.minFare);
                          setMaxCap(p.maxCap);
                          setExpiryDate(p.expiryDate || '');
                          setIsActive(p.isActive);
                          setUsageLimitPerCustomer(p.usageLimitPerCustomer);
                          window.scrollTo({ top: 0, behavior: 'smooth' });
                        }}
                      >
                        Edit
                      </button>
                      <button
                        type="button"
                        className={`btn btn--sm btn--${p.isActive ? 'ghost' : 'primary'}`}
                        onClick={() => toggleActive(p.id, p.isActive)}
                      >
                        {p.isActive ? 'Deactivate' : 'Activate'}
                      </button>
                      <button
                        type="button"
                        className="btn btn--sm btn--ghost"
                        onClick={() => handleDelete(p.id)}
                        style={{ color: 'var(--color-error)' }}
                      >
                        Delete
                      </button>
                    </div>
                  </div>
                </article>
              ))}
            </div>
          )}
        </div>

        {/* Create Form */}
        <div>
          <article className="card" style={{ padding: 'var(--space-4)' }}>
            <h3 style={{ fontSize: '1.05rem', fontWeight: 700, marginBottom: 'var(--space-4)' }}>
              {editingPromoId ? 'Edit Special Offer' : 'Create Special Offer'}
            </h3>
            <form onSubmit={handleCreate} style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-4)' }}>
              <div className="field">
                <label className="field__label">Promo Code</label>
                <input
                  type="text"
                  className="field__input"
                  placeholder="e.g. SAVE10"
                  value={code}
                  onChange={(e) => setCode(e.target.value)}
                  required
                />
              </div>

              <div className="field">
                <label className="field__label">Discount Type</label>
                <select
                  className="field__input"
                  value={discountType}
                  onChange={(e) => setDiscountType(e.target.value as any)}
                >
                  <option value="percentage">Percentage (%)</option>
                  <option value="flat">Flat Amount (₦)</option>
                </select>
              </div>

              <div className="field">
                <label className="field__label">Discount Value</label>
                <input
                  type="number"
                  className="field__input"
                  min="0"
                  value={discountValue}
                  onChange={(e) => setDiscountValue(Number(e.target.value))}
                  required
                />
              </div>

              <div className="field">
                <label className="field__label">Minimum Fare to Qualify (₦)</label>
                <input
                  type="number"
                  className="field__input"
                  min="0"
                  value={minFare}
                  onChange={(e) => setMinFare(Number(e.target.value))}
                />
              </div>

              {discountType === 'percentage' && (
                <div className="field">
                  <label className="field__label">Max Discount Cap (₦)</label>
                  <input
                    type="number"
                    className="field__input"
                    min="0"
                    value={maxCap}
                    onChange={(e) => setMaxCap(Number(e.target.value))}
                  />
                </div>
              )}

              <div className="field">
                <label className="field__label">Expiry Date</label>
                <input
                  type="date"
                  className="field__input"
                  value={expiryDate}
                  onChange={(e) => setExpiryDate(e.target.value)}
                />
              </div>

              <div className="field">
                <label className="field__label">NO of Usage per customer</label>
                <input
                  type="number"
                  className="field__input"
                  min="0"
                  placeholder="0 for unlimited"
                  value={usageLimitPerCustomer}
                  onChange={(e) => setUsageLimitPerCustomer(Number(e.target.value))}
                />
                <small className="muted" style={{ fontSize: '0.75rem', marginTop: 4, display: 'block' }}>
                  Determines how many times each customer can apply this offer. Leave as 0 for unlimited.
                </small>
              </div>

              <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginTop: 'var(--space-2)' }}>
                <input
                  type="checkbox"
                  id="isActive"
                  checked={isActive}
                  onChange={(e) => setIsActive(e.target.checked)}
                />
                <label htmlFor="isActive" style={{ fontWeight: 600, fontSize: '0.9rem' }}>
                  Make active immediately
                </label>
              </div>

              <div style={{ display: 'flex', gap: 12, marginTop: 'var(--space-3)' }}>
                <button type="submit" className="btn btn--primary" style={{ flex: 1 }}>
                  {editingPromoId ? 'Save Changes' : 'Create Offer'}
                </button>
                {editingPromoId && (
                  <button
                    type="button"
                    className="btn btn--ghost"
                    onClick={() => {
                      setEditingPromoId(null);
                      setCode('');
                      setDiscountValue(0);
                      setMinFare(0);
                      setMaxCap(0);
                      setExpiryDate('');
                      setIsActive(true);
                      setUsageLimitPerCustomer(0);
                    }}
                  >
                    Cancel
                  </button>
                )}
              </div>
            </form>
          </article>
        </div>
      </div>
    </div>
  );
}
