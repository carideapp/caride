import React, { useEffect, useState } from 'react';
import { doc, getDoc, setDoc, collection, getDocs, deleteDoc } from 'firebase/firestore';
import { db } from '../config/firebase';

interface PricingDetails {
  baseFare: number;
  perKmRate: number;
  perMinuteRate: number;
}

interface PricingConfig {
  regular: PricingDetails;
  comfort: PricingDetails;
  luxury: PricingDetails;
  courier: PricingDetails;
}

const defaultPricing: PricingConfig = {
  regular: { baseFare: 800, perKmRate: 250, perMinuteRate: 50 },
  comfort: { baseFare: 1200, perKmRate: 350, perMinuteRate: 70 },
  luxury: { baseFare: 2500, perKmRate: 600, perMinuteRate: 120 },
  courier: { baseFare: 600, perKmRate: 200, perMinuteRate: 40 },
};

interface AppUpdateConfig {
  isEnabled: boolean;
  title: string;
  message: string;
  latestVersion: string;
  isMandatory: boolean;
  platform: 'all' | 'android' | 'ios';
  androidUrl: string;
  iosUrl: string;
}

const defaultAppUpdate: AppUpdateConfig = {
  isEnabled: false,
  title: 'New Update Available',
  message: 'A new version of CaRide is available. Please update your app to enjoy the latest improvements and features.',
  latestVersion: '1.0.0',
  isMandatory: false,
  platform: 'all',
  androidUrl: 'https://play.google.com/store/apps/details?id=com.caride.app',
  iosUrl: 'https://apps.apple.com/app/caride/id123456789',
};

interface LegalConfig {
  riderTerms: string;
  riderPrivacy: string;
  driverTerms: string;
  driverPrivacy: string;
  fleetTerms: string;
  fleetPrivacy: string;
  fleetRentalProtocol: string;
  fleetInsurancePolicy: string;
}

const defaultLegal: LegalConfig = {
  riderTerms: '',
  riderPrivacy: '',
  driverTerms: '',
  driverPrivacy: '',
  fleetTerms: '',
  fleetPrivacy: '',
  fleetRentalProtocol: '',
  fleetInsurancePolicy: '',
};

export interface FaqItem {
  id: string;
  question: string;
  answer: string;
  category: 'fleet' | 'customer' | 'driver' | 'general';
  order: number;
  createdAtMs?: number;
}

type Tab = 'ride-fare' | 'referral' | 'support' | 'app-update' | 'legal-settings' | 'faqs';
type LegalCategory = 'rider' | 'driver' | 'fleet';
type LegalSubTab = 'terms' | 'privacy' | 'protocol' | 'insurance';

export function SettingsPage() {
  const [activeTab, setActiveTab] = useState<Tab>('ride-fare');
  const [legalCategory, setLegalCategory] = useState<LegalCategory>('rider');
  const [legalSubTab, setLegalSubTab] = useState<LegalSubTab>('terms');
  const [pricing, setPricing] = useState<PricingConfig>(defaultPricing);
  const [customerReferralPercent, setCustomerReferralPercent] = useState<number>(2);
  const [driverReferralPercent, setDriverReferralPercent] = useState<number>(2);
  const [website, setWebsite] = useState<string>('https://www.caride.ng');
  const [supportEmail, setSupportEmail] = useState<string>('support@caride.ng');
  const [supportPhone, setSupportPhone] = useState<string>('+234 800 CARIDE');
  const [appUpdate, setAppUpdate] = useState<AppUpdateConfig>(defaultAppUpdate);
  const [legalConfig, setLegalConfig] = useState<LegalConfig>(defaultLegal);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  // FAQs Management State
  const [faqs, setFaqs] = useState<FaqItem[]>([]);
  const [faqCategoryFilter, setFaqCategoryFilter] = useState<'all' | 'fleet' | 'customer' | 'driver' | 'general'>('all');
  const [faqModalOpen, setFaqModalOpen] = useState(false);
  const [editingFaq, setEditingFaq] = useState<FaqItem | null>(null);
  const [faqForm, setFaqForm] = useState<{
    question: string;
    answer: string;
    category: 'fleet' | 'customer' | 'driver' | 'general';
    order: number;
  }>({
    question: '',
    answer: '',
    category: 'fleet',
    order: 1,
  });

  const fetchFaqs = async () => {
    try {
      const snap = await getDocs(collection(db, 'faqs'));
      const items: FaqItem[] = [];
      snap.forEach((d) => {
        const data = d.data();
        items.push({
          id: d.id,
          question: data.question || '',
          answer: data.answer || '',
          category: data.category || 'fleet',
          order: data.order || 1,
          createdAtMs: data.createdAtMs || 0,
        });
      });
      items.sort((a, b) => (a.order || 0) - (b.order || 0) || (b.createdAtMs || 0) - (a.createdAtMs || 0));
      setFaqs(items);
    } catch (e: any) {
      console.error('Error fetching FAQs:', e);
    }
  };

  useEffect(() => {
    async function fetchConfig() {
      try {
        await fetchFaqs();
        const docRef = doc(db, 'config', 'ridePricing');
        const snap = await getDoc(docRef);
        if (snap.exists()) {
          const data = snap.data() as Partial<PricingConfig>;
          setPricing({
            regular: { ...defaultPricing.regular, ...data.regular },
            comfort: { ...defaultPricing.comfort, ...data.comfort },
            luxury: { ...defaultPricing.luxury, ...data.luxury },
            courier: { ...defaultPricing.courier, ...data.courier },
          });
        }

        const refRef = doc(db, 'config', 'referralSettings');
        const refSnap = await getDoc(refRef);
        if (refSnap.exists()) {
          const refData = refSnap.data();
          if (refData.customerReferralPercent !== undefined) {
            setCustomerReferralPercent(refData.customerReferralPercent);
          }
          if (refData.driverReferralPercent !== undefined) {
            setDriverReferralPercent(refData.driverReferralPercent);
          }
        }

        const supportRef = doc(db, 'config', 'appSupport');
        const supportSnap = await getDoc(supportRef);
        if (supportSnap.exists()) {
          const sData = supportSnap.data();
          if (sData.website) setWebsite(sData.website);
          if (sData.supportEmail) setSupportEmail(sData.supportEmail);
          if (sData.supportPhone) setSupportPhone(sData.supportPhone);
        }

        const updateRef = doc(db, 'config', 'appUpdate');
        const updateSnap = await getDoc(updateRef);
        if (updateSnap.exists()) {
          const uData = updateSnap.data();
          setAppUpdate({
            ...defaultAppUpdate,
            ...uData,
          });
        }

        const legalRef = doc(db, 'config', 'legalSettings');
        const legalSnap = await getDoc(legalRef);
        if (legalSnap.exists()) {
          const lData = legalSnap.data();
          setLegalConfig({
            riderTerms: lData.riderTerms || '',
            riderPrivacy: lData.riderPrivacy || '',
            driverTerms: lData.driverTerms || '',
            driverPrivacy: lData.driverPrivacy || '',
            fleetTerms: lData.fleetTerms || '',
            fleetPrivacy: lData.fleetPrivacy || '',
            fleetRentalProtocol: lData.fleetRentalProtocol || '',
            fleetInsurancePolicy: lData.fleetInsurancePolicy || '',
          });
        }

        setLoading(false);
      } catch (e: any) {
        setError(e.message || 'Failed to load config');
        setLoading(false);
      }
    }
    fetchConfig();
  }, []);

  const handleOpenAddFaq = () => {
    setEditingFaq(null);
    setFaqForm({
      question: '',
      answer: '',
      category: 'fleet',
      order: faqs.length + 1,
    });
    setFaqModalOpen(true);
  };

  const handleOpenEditFaq = (faq: FaqItem) => {
    setEditingFaq(faq);
    setFaqForm({
      question: faq.question,
      answer: faq.answer,
      category: faq.category,
      order: faq.order,
    });
    setFaqModalOpen(true);
  };

  const handleDeleteFaq = async (id: string) => {
    if (!window.confirm('Are you sure you want to delete this FAQ?')) return;
    setSaving(true);
    setError(null);
    try {
      const updatedList = faqs.filter((f) => f.id !== id);

      // Primary: Save updated array to config/faqs document
      await setDoc(doc(db, 'config', 'faqs'), { items: updatedList }, { merge: true });

      // Secondary: Try deleting from faqs collection
      try {
        await deleteDoc(doc(db, 'faqs', id));
      } catch (e) {
        console.warn('Secondary faqs collection delete warning:', e);
      }

      setFaqs(updatedList);
      setSuccess('FAQ deleted successfully!');
    } catch (e: any) {
      setError(e.message || 'Failed to delete FAQ');
    } finally {
      setSaving(false);
    }
  };

  const handleSaveFaq = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!faqForm.question.trim() || !faqForm.answer.trim()) {
      setError('Please enter both question and answer.');
      return;
    }

    setSaving(true);
    setError(null);
    try {
      const targetId = editingFaq ? editingFaq.id : 'faq_' + Date.now();
      const payloadItem: FaqItem = {
        id: targetId,
        question: faqForm.question.trim(),
        answer: faqForm.answer.trim(),
        category: faqForm.category,
        order: Number(faqForm.order) || 1,
        createdAtMs: editingFaq?.createdAtMs || Date.now(),
      };

      let updatedList: FaqItem[];
      if (editingFaq) {
        updatedList = faqs.map((f) => (f.id === targetId ? payloadItem : f));
      } else {
        updatedList = [...faqs, payloadItem];
      }

      // Primary: Save to config/faqs document (uses config collection permissions)
      await setDoc(doc(db, 'config', 'faqs'), { items: updatedList }, { merge: true });

      // Secondary: Try saving to faqs collection
      try {
        await setDoc(doc(db, 'faqs', targetId), {
          question: payloadItem.question,
          answer: payloadItem.answer,
          category: payloadItem.category,
          order: payloadItem.order,
          createdAtMs: payloadItem.createdAtMs,
          updatedAtMs: Date.now(),
        }, { merge: true });
      } catch (e) {
        console.warn('Secondary faqs collection write warning:', e);
      }

      setFaqs(updatedList);
      setSuccess(editingFaq ? 'FAQ updated successfully!' : 'FAQ created successfully!');
      setFaqModalOpen(false);
    } catch (e: any) {
      setError(e.message || 'Failed to save FAQ');
    } finally {
      setSaving(false);
    }
  };

  const handleRateChange = (
    category: keyof PricingConfig,
    field: keyof PricingDetails,
    val: string
  ) => {
    const numericValue = parseFloat(val) || 0;
    setPricing((prev) => ({
      ...prev,
      [category]: {
        ...prev[category],
        [field]: numericValue,
      },
    }));
  };

  const handleSave = async (e: React.FormEvent) => {
    e.preventDefault();
    setSaving(true);
    setError(null);
    setSuccess(null);
    try {
      if (activeTab === 'ride-fare') {
        const docRef = doc(db, 'config', 'ridePricing');
        await setDoc(docRef, {
          regular: pricing.regular,
          comfort: pricing.comfort,
          luxury: pricing.luxury,
          courier: pricing.courier,
        }, { merge: true });
        setSuccess('Pricing settings saved successfully!');
      } else if (activeTab === 'referral') {
        const docRef = doc(db, 'config', 'referralSettings');
        await setDoc(docRef, {
          customerReferralPercent,
          driverReferralPercent,
        }, { merge: true });
        setSuccess('Referral settings saved successfully!');
      } else if (activeTab === 'support') {
        const docRef = doc(db, 'config', 'appSupport');
        await setDoc(docRef, {
          website,
          supportEmail,
          supportPhone,
        }, { merge: true });
        setSuccess('Support & Contact settings saved successfully!');
      } else if (activeTab === 'app-update') {
        const docRef = doc(db, 'config', 'appUpdate');
        await setDoc(docRef, appUpdate, { merge: true });
        setSuccess('App Update settings saved successfully!');
      } else if (activeTab === 'legal-settings') {
        const docRef = doc(db, 'config', 'legalSettings');
        await setDoc(docRef, legalConfig, { merge: true });
        setSuccess('Legal settings saved successfully!');
      }
    } catch (e: any) {
      setError(e.message || 'Failed to save settings');
    } finally {
      setSaving(false);
    }
  };

  if (loading) {
    return (
      <div className="card" style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
        <div className="skeleton-row shimmer" style={{ height: 60 }} />
        <div className="skeleton-row shimmer" style={{ height: 180 }} />
      </div>
    );
  }

  return (
    <div>
      <div style={{ marginBottom: 'var(--space-5)' }}>
        <p className="muted" style={{ margin: 0 }}>
          Manage global configurations, pricing controls, and system parameters.
        </p>
      </div>

      {/* Tabs */}
      <div className="tab-nav" style={{ display: 'flex', gap: 'var(--space-3)', marginBottom: 'var(--space-5)', borderBottom: '1px solid var(--color-border)', paddingBottom: 'var(--space-2)' }}>
        <button
          className={`tab-btn ${activeTab === 'ride-fare' ? 'active' : ''}`}
          onClick={() => setActiveTab('ride-fare')}
          style={{
            background: 'none',
            border: 'none',
            padding: 'var(--space-2) var(--space-4)',
            cursor: 'pointer',
            fontSize: '1rem',
            fontWeight: 600,
            color: activeTab === 'ride-fare' ? 'var(--color-primary)' : 'var(--color-text-muted)',
            borderBottom: activeTab === 'ride-fare' ? '2px solid var(--color-primary)' : 'none',
          }}
        >
          Ride Fare & Pricing
        </button>
        <button
          className={`tab-btn ${activeTab === 'referral' ? 'active' : ''}`}
          onClick={() => setActiveTab('referral')}
          style={{
            background: 'none',
            border: 'none',
            padding: 'var(--space-2) var(--space-4)',
            cursor: 'pointer',
            fontSize: '1rem',
            fontWeight: 600,
            color: activeTab === 'referral' ? 'var(--color-primary)' : 'var(--color-text-muted)',
            borderBottom: activeTab === 'referral' ? '2px solid var(--color-primary)' : 'none',
          }}
        >
          Referral Settings
        </button>
        <button
          className={`tab-btn ${activeTab === 'support' ? 'active' : ''}`}
          onClick={() => setActiveTab('support')}
          style={{
            background: 'none',
            border: 'none',
            padding: 'var(--space-2) var(--space-4)',
            cursor: 'pointer',
            fontSize: '1rem',
            fontWeight: 600,
            color: activeTab === 'support' ? 'var(--color-primary)' : 'var(--color-text-muted)',
            borderBottom: activeTab === 'support' ? '2px solid var(--color-primary)' : 'none',
          }}
        >
          Support & Contact
        </button>
        <button
          className={`tab-btn ${activeTab === 'app-update' ? 'active' : ''}`}
          onClick={() => setActiveTab('app-update')}
          style={{
            background: 'none',
            border: 'none',
            padding: 'var(--space-2) var(--space-4)',
            cursor: 'pointer',
            fontSize: '1rem',
            fontWeight: 600,
            color: activeTab === 'app-update' ? 'var(--color-primary)' : 'var(--color-text-muted)',
            borderBottom: activeTab === 'app-update' ? '2px solid var(--color-primary)' : 'none',
          }}
        >
          🚀 App Update
        </button>
        <button
          className={`tab-btn ${activeTab === 'legal-settings' ? 'active' : ''}`}
          onClick={() => setActiveTab('legal-settings')}
          style={{
            background: 'none',
            border: 'none',
            padding: 'var(--space-2) var(--space-4)',
            cursor: 'pointer',
            fontSize: '1rem',
            fontWeight: 600,
            color: activeTab === 'legal-settings' ? 'var(--color-primary)' : 'var(--color-text-muted)',
            borderBottom: activeTab === 'legal-settings' ? '2px solid var(--color-primary)' : 'none',
          }}
        >
          ⚖️ Legal Settings
        </button>
        <button
          className={`tab-btn ${activeTab === 'faqs' ? 'active' : ''}`}
          onClick={() => setActiveTab('faqs')}
          style={{
            background: 'none',
            border: 'none',
            padding: 'var(--space-2) var(--space-4)',
            cursor: 'pointer',
            fontSize: '1rem',
            fontWeight: 600,
            color: activeTab === 'faqs' ? 'var(--color-primary)' : 'var(--color-text-muted)',
            borderBottom: activeTab === 'faqs' ? '2px solid var(--color-primary)' : 'none',
          }}
        >
          ❓ FAQs Management
        </button>
      </div>

      {error && <p className="field__error" style={{ marginBottom: 'var(--space-4)' }}>{error}</p>}
      {success && <p className="success-message" style={{ color: 'var(--success-color, #2e7d32)', marginBottom: 'var(--space-4)', fontWeight: 600 }}>{success}</p>}

      {activeTab === 'ride-fare' && (
        <form onSubmit={handleSave}>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: 'var(--space-5)', marginBottom: 'var(--space-5)' }}>
            
            {/* Category: Regular */}
            <article className="card" style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-3)' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-2)' }}>
                <span style={{ fontSize: '1.5rem' }}>🚗</span>
                <h3 style={{ margin: 0, fontWeight: 700 }}>Regular Ride</h3>
              </div>
              <p className="muted" style={{ fontSize: '0.85rem', margin: 0 }}>Standard passenger transportation fare rates.</p>
              
              <div className="field">
                <label className="field__label">Base Fare (₦)</label>
                <input
                  type="number"
                  className="field__input"
                  value={pricing.regular.baseFare}
                  onChange={(e) => handleRateChange('regular', 'baseFare', e.target.value)}
                  min="0"
                  required
                />
              </div>

              <div className="field">
                <label className="field__label">Per Kilometer Rate (₦)</label>
                <input
                  type="number"
                  className="field__input"
                  value={pricing.regular.perKmRate}
                  onChange={(e) => handleRateChange('regular', 'perKmRate', e.target.value)}
                  min="0"
                  required
                />
              </div>

              <div className="field">
                <label className="field__label">Per Minute Rate (₦)</label>
                <input
                  type="number"
                  className="field__input"
                  value={pricing.regular.perMinuteRate}
                  onChange={(e) => handleRateChange('regular', 'perMinuteRate', e.target.value)}
                  min="0"
                  required
                />
              </div>
            </article>

            {/* Category: Comfort */}
            <article className="card" style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-3)' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-2)' }}>
                <span style={{ fontSize: '1.5rem' }}>🛋️</span>
                <h3 style={{ margin: 0, fontWeight: 700 }}>Comfort Ride</h3>
              </div>
              <p className="muted" style={{ fontSize: '0.85rem', margin: 0 }}>Spacious premium cars with top-rated drivers.</p>
              
              <div className="field">
                <label className="field__label">Base Fare (₦)</label>
                <input
                  type="number"
                  className="field__input"
                  value={pricing.comfort.baseFare}
                  onChange={(e) => handleRateChange('comfort', 'baseFare', e.target.value)}
                  min="0"
                  required
                />
              </div>

              <div className="field">
                <label className="field__label">Per Kilometer Rate (₦)</label>
                <input
                  type="number"
                  className="field__input"
                  value={pricing.comfort.perKmRate}
                  onChange={(e) => handleRateChange('comfort', 'perKmRate', e.target.value)}
                  min="0"
                  required
                />
              </div>

              <div className="field">
                <label className="field__label">Per Minute Rate (₦)</label>
                <input
                  type="number"
                  className="field__input"
                  value={pricing.comfort.perMinuteRate}
                  onChange={(e) => handleRateChange('comfort', 'perMinuteRate', e.target.value)}
                  min="0"
                  required
                />
              </div>
            </article>

            {/* Category: Luxury */}
            <article className="card" style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-3)' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-2)' }}>
                <span style={{ fontSize: '1.5rem' }}>✨</span>
                <h3 style={{ margin: 0, fontWeight: 700 }}>Luxury Ride</h3>
              </div>
              <p className="muted" style={{ fontSize: '0.85rem', margin: 0 }}>High-end luxury vehicles and executive service.</p>
              
              <div className="field">
                <label className="field__label">Base Fare (₦)</label>
                <input
                  type="number"
                  className="field__input"
                  value={pricing.luxury.baseFare}
                  onChange={(e) => handleRateChange('luxury', 'baseFare', e.target.value)}
                  min="0"
                  required
                />
              </div>

              <div className="field">
                <label className="field__label">Per Kilometer Rate (₦)</label>
                <input
                  type="number"
                  className="field__input"
                  value={pricing.luxury.perKmRate}
                  onChange={(e) => handleRateChange('luxury', 'perKmRate', e.target.value)}
                  min="0"
                  required
                />
              </div>

              <div className="field">
                <label className="field__label">Per Minute Rate (₦)</label>
                <input
                  type="number"
                  className="field__input"
                  value={pricing.luxury.perMinuteRate}
                  onChange={(e) => handleRateChange('luxury', 'perMinuteRate', e.target.value)}
                  min="0"
                  required
                />
              </div>
            </article>

            {/* Category: Courier */}
            <article className="card" style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-3)' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-2)' }}>
                <span style={{ fontSize: '1.5rem' }}>📦</span>
                <h3 style={{ margin: 0, fontWeight: 700 }}>Courier Delivery</h3>
              </div>
              <p className="muted" style={{ fontSize: '0.85rem', margin: 0 }}>Package delivery, courier and shipping services.</p>
              
              <div className="field">
                <label className="field__label">Base Fare (₦)</label>
                <input
                  type="number"
                  className="field__input"
                  value={pricing.courier.baseFare}
                  onChange={(e) => handleRateChange('courier', 'baseFare', e.target.value)}
                  min="0"
                  required
                />
              </div>

              <div className="field">
                <label className="field__label">Per Kilometer Rate (₦)</label>
                <input
                  type="number"
                  className="field__input"
                  value={pricing.courier.perKmRate}
                  onChange={(e) => handleRateChange('courier', 'perKmRate', e.target.value)}
                  min="0"
                  required
                />
              </div>

              <div className="field">
                <label className="field__label">Per Minute Rate (₦)</label>
                <input
                  type="number"
                  className="field__input"
                  value={pricing.courier.perMinuteRate}
                  onChange={(e) => handleRateChange('courier', 'perMinuteRate', e.target.value)}
                  min="0"
                  required
                />
              </div>
            </article>

          </div>

          <button type="submit" className="btn btn--primary" disabled={saving}>
            {saving ? 'Saving...' : 'Save Settings'}
          </button>
        </form>
      )}

      {activeTab === 'referral' && (
        <form onSubmit={handleSave}>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(280px, 1fr))', gap: 'var(--space-5)', marginBottom: 'var(--space-5)' }}>
            <article className="card" style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-3)' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-2)' }}>
                <span style={{ fontSize: '1.5rem' }}>👥</span>
                <h3 style={{ margin: 0, fontWeight: 700 }}>Referral Percentages</h3>
              </div>
              <p className="muted" style={{ fontSize: '0.85rem', margin: 0 }}>Configure how much commission referrers earn.</p>
              
              <div className="field">
                <label className="field__label">Customer Referral Commission (%)</label>
                <input
                  type="number"
                  className="field__input"
                  value={customerReferralPercent}
                  onChange={(e) => setCustomerReferralPercent(parseFloat(e.target.value) || 0)}
                  min="0"
                  max="100"
                  step="0.1"
                  required
                />
              </div>

              <div className="field">
                <label className="field__label">Driver Referral Commission (%)</label>
                <input
                  type="number"
                  className="field__input"
                  value={driverReferralPercent}
                  onChange={(e) => setDriverReferralPercent(parseFloat(e.target.value) || 0)}
                  min="0"
                  max="100"
                  step="0.1"
                  required
                />
              </div>
            </article>
          </div>

          <button type="submit" className="btn btn--primary" disabled={saving}>
            {saving ? 'Saving...' : 'Save Settings'}
          </button>
        </form>
      )}

      {activeTab === 'support' && (
        <form onSubmit={handleSave}>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: 'var(--space-5)', marginBottom: 'var(--space-5)' }}>
            <article className="card" style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-3)' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-2)' }}>
                <span style={{ fontSize: '1.5rem' }}>🎧</span>
                <h3 style={{ margin: 0, fontWeight: 700 }}>Support & Contact Info</h3>
              </div>
              <p className="muted" style={{ fontSize: '0.85rem', margin: 0 }}>Configure company website, support email, and phone line displayed across mobile apps.</p>
              
              <div className="field">
                <label className="field__label">Company Website URL</label>
                <input
                  type="text"
                  className="field__input"
                  value={website}
                  onChange={(e) => setWebsite(e.target.value)}
                  placeholder="https://www.caride.ng"
                  required
                />
              </div>

              <div className="field">
                <label className="field__label">Support Email Address</label>
                <input
                  type="email"
                  className="field__input"
                  value={supportEmail}
                  onChange={(e) => setSupportEmail(e.target.value)}
                  placeholder="support@caride.ng"
                  required
                />
              </div>

              <div className="field">
                <label className="field__label">Support Phone Line</label>
                <input
                  type="text"
                  className="field__input"
                  value={supportPhone}
                  onChange={(e) => setSupportPhone(e.target.value)}
                  placeholder="+234 800 CARIDE"
                  required
                />
              </div>
            </article>
          </div>

          <button type="submit" className="btn btn--primary" disabled={saving}>
            {saving ? 'Saving...' : 'Save Support Info'}
          </button>
        </form>
      )}

      {activeTab === 'app-update' && (
        <form onSubmit={handleSave}>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(320px, 1fr))', gap: 'var(--space-5)', marginBottom: 'var(--space-5)' }}>
            <article className="card" style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-4)' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-2)' }}>
                <span style={{ fontSize: '1.5rem' }}>🚀</span>
                <h3 style={{ margin: 0, fontWeight: 700 }}>App Update Notification</h3>
              </div>
              <p className="muted" style={{ fontSize: '0.85rem', margin: 0 }}>
                Configure in-app update prompts for Customer and Driver mobile applications.
              </p>

              {/* Toggles */}
              <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-3)', background: 'rgba(0,0,0,0.03)', padding: 'var(--space-3)', borderRadius: '8px' }}>
                <label style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-2)', cursor: 'pointer', fontWeight: 600 }}>
                  <input
                    type="checkbox"
                    checked={appUpdate.isEnabled}
                    onChange={(e) => setAppUpdate((prev) => ({ ...prev, isEnabled: e.target.checked }))}
                    style={{ width: 18, height: 18, cursor: 'pointer' }}
                  />
                  Enable Update Notification Prompt
                </label>

                <label style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-2)', cursor: 'pointer', fontWeight: 600 }}>
                  <input
                    type="checkbox"
                    checked={appUpdate.isMandatory}
                    onChange={(e) => setAppUpdate((prev) => ({ ...prev, isMandatory: e.target.checked }))}
                    style={{ width: 18, height: 18, cursor: 'pointer' }}
                  />
                  Mandatory Update (Removes "Later" button, forces update)
                </label>
              </div>

              {/* Version & Target Platform */}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 'var(--space-3)' }}>
                <div className="field">
                  <label className="field__label">Latest App Version</label>
                  <input
                    type="text"
                    className="field__input"
                    value={appUpdate.latestVersion}
                    onChange={(e) => setAppUpdate((prev) => ({ ...prev, latestVersion: e.target.value }))}
                    placeholder="e.g. 1.0.1"
                    required
                  />
                </div>

                <div className="field">
                  <label className="field__label">Target Platform</label>
                  <select
                    className="field__input"
                    value={appUpdate.platform}
                    onChange={(e) => setAppUpdate((prev) => ({ ...prev, platform: e.target.value as any }))}
                    style={{ background: 'var(--card-bg, #fff)' }}
                  >
                    <option value="all">All Platforms (Android & iOS)</option>
                    <option value="android">Android Only</option>
                    <option value="ios">iOS Only</option>
                  </select>
                </div>
              </div>

              {/* Title */}
              <div className="field">
                <label className="field__label">Update Popup Title</label>
                <input
                  type="text"
                  className="field__input"
                  value={appUpdate.title}
                  onChange={(e) => setAppUpdate((prev) => ({ ...prev, title: e.target.value }))}
                  placeholder="New Update Available"
                  required
                />
              </div>

              {/* Message */}
              <div className="field">
                <label className="field__label">Update Message</label>
                <textarea
                  className="field__input"
                  rows={3}
                  value={appUpdate.message}
                  onChange={(e) => setAppUpdate((prev) => ({ ...prev, message: e.target.value }))}
                  placeholder="A new version of CaRide is available..."
                  required
                  style={{ resize: 'vertical' }}
                />
              </div>

              {/* Google Play Store Link */}
              <div className="field">
                <label className="field__label">Google Play Store URL (Android)</label>
                <input
                  type="url"
                  className="field__input"
                  value={appUpdate.androidUrl}
                  onChange={(e) => setAppUpdate((prev) => ({ ...prev, androidUrl: e.target.value }))}
                  placeholder="https://play.google.com/store/apps/details?id=com.caride.app"
                  required
                />
              </div>

              {/* Apple App Store Link */}
              <div className="field">
                <label className="field__label">Apple App Store URL (iOS)</label>
                <input
                  type="url"
                  className="field__input"
                  value={appUpdate.iosUrl}
                  onChange={(e) => setAppUpdate((prev) => ({ ...prev, iosUrl: e.target.value }))}
                  placeholder="https://apps.apple.com/app/caride/id123456789"
                  required
                />
              </div>
            </article>
          </div>

          <button type="submit" className="btn btn--primary" disabled={saving}>
            {saving ? 'Saving...' : 'Save App Update Settings'}
          </button>
        </form>
      )}

      {activeTab === 'legal-settings' && (
        <form onSubmit={handleSave}>
          <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-4)', marginBottom: 'var(--space-5)' }}>
            <article className="card" style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-4)' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-2)' }}>
                <span style={{ fontSize: '1.5rem' }}>⚖️</span>
                <h3 style={{ margin: 0, fontWeight: 700 }}>Legal Documents & Policy Settings</h3>
              </div>
              <p className="muted" style={{ fontSize: '0.85rem', margin: 0 }}>
                Configure the Terms of Use and Privacy Policy displayed in the Rider and Driver mobile applications.
              </p>

              {/* Category Selector: Rider / Driver / Fleet */}
              <div style={{ display: 'flex', gap: 'var(--space-2)', borderBottom: '1px solid var(--color-border)', paddingBottom: 'var(--space-3)', flexWrap: 'wrap' }}>
                <button
                  type="button"
                  onClick={() => {
                    setLegalCategory('rider');
                    if (legalSubTab !== 'terms' && legalSubTab !== 'privacy') {
                      setLegalSubTab('terms');
                    }
                  }}
                  style={{
                    padding: 'var(--space-2) var(--space-4)',
                    borderRadius: 'var(--radius-md)',
                    border: '1px solid ' + (legalCategory === 'rider' ? 'var(--color-primary)' : 'var(--color-border)'),
                    background: legalCategory === 'rider' ? 'var(--color-primary-light)' : 'var(--color-surface)',
                    color: legalCategory === 'rider' ? 'var(--color-primary-active)' : 'var(--color-text-muted)',
                    fontWeight: 700,
                    cursor: 'pointer',
                    transition: 'all var(--transition-fast)',
                  }}
                >
                  🚴 Rider Legal Settings
                </button>
                <button
                  type="button"
                  onClick={() => {
                    setLegalCategory('driver');
                    if (legalSubTab !== 'terms' && legalSubTab !== 'privacy') {
                      setLegalSubTab('terms');
                    }
                  }}
                  style={{
                    padding: 'var(--space-2) var(--space-4)',
                    borderRadius: 'var(--radius-md)',
                    border: '1px solid ' + (legalCategory === 'driver' ? 'var(--color-primary)' : 'var(--color-border)'),
                    background: legalCategory === 'driver' ? 'var(--color-primary-light)' : 'var(--color-surface)',
                    color: legalCategory === 'driver' ? 'var(--color-primary-active)' : 'var(--color-text-muted)',
                    fontWeight: 700,
                    cursor: 'pointer',
                    transition: 'all var(--transition-fast)',
                  }}
                >
                  🚗 Driver Legal Settings
                </button>
                <button
                  type="button"
                  onClick={() => {
                    setLegalCategory('fleet');
                    if (legalSubTab !== 'terms' && legalSubTab !== 'privacy' && legalSubTab !== 'protocol' && legalSubTab !== 'insurance') {
                      setLegalSubTab('terms');
                    }
                  }}
                  style={{
                    padding: 'var(--space-2) var(--space-4)',
                    borderRadius: 'var(--radius-md)',
                    border: '1px solid ' + (legalCategory === 'fleet' ? 'var(--color-primary)' : 'var(--color-border)'),
                    background: legalCategory === 'fleet' ? 'var(--color-primary-light)' : 'var(--color-surface)',
                    color: legalCategory === 'fleet' ? 'var(--color-primary-active)' : 'var(--color-text-muted)',
                    fontWeight: 700,
                    cursor: 'pointer',
                    transition: 'all var(--transition-fast)',
                  }}
                >
                  👔 Fleet Partner Legal Settings
                </button>
              </div>

              {/* Sub-tabs Selector */}
              <div style={{ display: 'flex', gap: 'var(--space-2)', marginTop: 'var(--space-2)', flexWrap: 'wrap' }}>
                <button
                  type="button"
                  onClick={() => setLegalSubTab('terms')}
                  style={{
                    padding: 'var(--space-2) var(--space-4)',
                    borderRadius: 'var(--radius-md)',
                    border: '1px solid ' + (legalSubTab === 'terms' ? 'var(--color-primary)' : 'var(--color-border)'),
                    background: legalSubTab === 'terms' ? 'var(--color-primary)' : 'var(--color-bg-alt)',
                    color: legalSubTab === 'terms' ? '#ffffff' : 'var(--color-text)',
                    fontWeight: 700,
                    fontSize: '0.9rem',
                    cursor: 'pointer',
                    boxShadow: legalSubTab === 'terms' ? 'var(--shadow-sm)' : 'none',
                    transition: 'all var(--transition-fast)',
                  }}
                >
                  📜 Terms of Use
                </button>
                {legalCategory === 'fleet' && (
                  <>
                    <button
                      type="button"
                      onClick={() => setLegalSubTab('protocol')}
                      style={{
                        padding: 'var(--space-2) var(--space-4)',
                        borderRadius: 'var(--radius-md)',
                        border: '1px solid ' + (legalSubTab === 'protocol' ? 'var(--color-primary)' : 'var(--color-border)'),
                        background: legalSubTab === 'protocol' ? 'var(--color-primary)' : 'var(--color-bg-alt)',
                        color: legalSubTab === 'protocol' ? '#ffffff' : 'var(--color-text)',
                        fontWeight: 700,
                        fontSize: '0.9rem',
                        cursor: 'pointer',
                        boxShadow: legalSubTab === 'protocol' ? 'var(--shadow-sm)' : 'none',
                        transition: 'all var(--transition-fast)',
                      }}
                    >
                      🚘 Rental & Chauffeur Protocol
                    </button>
                    <button
                      type="button"
                      onClick={() => setLegalSubTab('insurance')}
                      style={{
                        padding: 'var(--space-2) var(--space-4)',
                        borderRadius: 'var(--radius-md)',
                        border: '1px solid ' + (legalSubTab === 'insurance' ? 'var(--color-primary)' : 'var(--color-border)'),
                        background: legalSubTab === 'insurance' ? 'var(--color-primary)' : 'var(--color-bg-alt)',
                        color: legalSubTab === 'insurance' ? '#ffffff' : 'var(--color-text)',
                        fontWeight: 700,
                        fontSize: '0.9rem',
                        cursor: 'pointer',
                        boxShadow: legalSubTab === 'insurance' ? 'var(--shadow-sm)' : 'none',
                        transition: 'all var(--transition-fast)',
                      }}
                    >
                      🛡️ Insurance & Liability
                    </button>
                  </>
                )}
                <button
                  type="button"
                  onClick={() => setLegalSubTab('privacy')}
                  style={{
                    padding: 'var(--space-2) var(--space-4)',
                    borderRadius: 'var(--radius-md)',
                    border: '1px solid ' + (legalSubTab === 'privacy' ? 'var(--color-primary)' : 'var(--color-border)'),
                    background: legalSubTab === 'privacy' ? 'var(--color-primary)' : 'var(--color-bg-alt)',
                    color: legalSubTab === 'privacy' ? '#ffffff' : 'var(--color-text)',
                    fontWeight: 700,
                    fontSize: '0.9rem',
                    cursor: 'pointer',
                    boxShadow: legalSubTab === 'privacy' ? 'var(--shadow-sm)' : 'none',
                    transition: 'all var(--transition-fast)',
                  }}
                >
                  🔒 Privacy Policy
                </button>
              </div>

              {/* Document Textarea */}
              <div className="field">
                <label className="field__label" style={{ fontWeight: 700 }}>
                  {legalCategory === 'rider' ? 'Rider' : legalCategory === 'driver' ? 'Driver' : 'Fleet Partner'} -{' '}
                  {legalSubTab === 'terms'
                    ? 'Terms of Use'
                    : legalSubTab === 'protocol'
                    ? 'Vehicle Rental & Chauffeur Protocol'
                    : legalSubTab === 'insurance'
                    ? 'Insurance & Liability Guidelines'
                    : 'Privacy Policy'}{' '}
                  Content
                </label>
                <p className="muted" style={{ fontSize: '0.8rem', marginBottom: 'var(--space-2)' }}>
                  Leave empty to use default standard app policy terms.
                </p>
                <textarea
                  className="field__input"
                  rows={14}
                  value={
                    legalCategory === 'rider'
                      ? (legalSubTab === 'terms' ? legalConfig.riderTerms : legalConfig.riderPrivacy)
                      : legalCategory === 'driver'
                      ? (legalSubTab === 'terms' ? legalConfig.driverTerms : legalConfig.driverPrivacy)
                      : (legalSubTab === 'terms'
                          ? legalConfig.fleetTerms
                          : legalSubTab === 'protocol'
                          ? legalConfig.fleetRentalProtocol
                          : legalSubTab === 'insurance'
                          ? legalConfig.fleetInsurancePolicy
                          : legalConfig.fleetPrivacy)
                  }
                  onChange={(e) => {
                    const val = e.target.value;
                    setLegalConfig((prev) => {
                      if (legalCategory === 'rider') {
                        return legalSubTab === 'terms'
                          ? { ...prev, riderTerms: val }
                          : { ...prev, riderPrivacy: val };
                      } else if (legalCategory === 'driver') {
                        return legalSubTab === 'terms'
                          ? { ...prev, driverTerms: val }
                          : { ...prev, driverPrivacy: val };
                      } else {
                        if (legalSubTab === 'terms') return { ...prev, fleetTerms: val };
                        if (legalSubTab === 'protocol') return { ...prev, fleetRentalProtocol: val };
                        if (legalSubTab === 'insurance') return { ...prev, fleetInsurancePolicy: val };
                        return { ...prev, fleetPrivacy: val };
                      }
                    });
                  }}
                  placeholder="Enter full terms / privacy policy text here..."
                  style={{ resize: 'vertical', fontFamily: 'inherit', lineHeight: 1.6 }}
                />
              </div>
            </article>
          </div>

          <button type="submit" className="btn btn--primary" disabled={saving}>
            {saving ? 'Saving...' : 'Save Legal Settings'}
          </button>
        </form>
      )}

      {activeTab === 'faqs' && (
        <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-4)' }}>
          {/* Header Controls */}
          <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: 12 }}>
            <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
              <span style={{ fontWeight: 600, fontSize: '0.95rem' }}>Category Filter:</span>
              <select
                className="field__input"
                style={{ width: 'auto', padding: '6px 12px' }}
                value={faqCategoryFilter}
                onChange={(e) => setFaqCategoryFilter(e.target.value as any)}
              >
                <option value="all">All Categories</option>
                <option value="fleet">Fleet Manager</option>
                <option value="customer">Customer / Rider</option>
                <option value="driver">Driver</option>
                <option value="general">General</option>
              </select>
            </div>

            <button className="btn btn--primary" onClick={handleOpenAddFaq}>
              + Create FAQ
            </button>
          </div>

          {/* FAQs List Table */}
          <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
            <table className="table" style={{ width: '100%', borderCollapse: 'collapse' }}>
              <thead>
                <tr style={{ background: 'var(--color-bg-subtle, #f9fafb)', textAlign: 'left', borderBottom: '1px solid var(--color-border)' }}>
                  <th style={{ padding: '12px 16px', width: '70px' }}>Order</th>
                  <th style={{ padding: '12px 16px', width: '120px' }}>Category</th>
                  <th style={{ padding: '12px 16px' }}>Question</th>
                  <th style={{ padding: '12px 16px' }}>Answer Excerpt</th>
                  <th style={{ padding: '12px 16px', width: '160px', textAlign: 'right' }}>Actions</th>
                </tr>
              </thead>
              <tbody>
                {faqs
                  .filter((item) => faqCategoryFilter === 'all' || item.category === faqCategoryFilter)
                  .map((faq) => (
                    <tr key={faq.id} style={{ borderBottom: '1px solid var(--color-border)' }}>
                      <td style={{ padding: '12px 16px', fontWeight: 700 }}>#{faq.order}</td>
                      <td style={{ padding: '12px 16px' }}>
                        <span
                          style={{
                            display: 'inline-block',
                            padding: '4px 10px',
                            borderRadius: '12px',
                            fontSize: '0.75rem',
                            fontWeight: 700,
                            textTransform: 'uppercase',
                            background: faq.category === 'fleet' ? '#dcfce7' : faq.category === 'driver' ? '#e0f2fe' : '#f3e8ff',
                            color: faq.category === 'fleet' ? '#15803d' : faq.category === 'driver' ? '#0369a1' : '#6b21a8',
                          }}
                        >
                          {faq.category}
                        </span>
                      </td>
                      <td style={{ padding: '12px 16px', fontWeight: 600, color: 'var(--color-text)' }}>
                        {faq.question}
                      </td>
                      <td style={{ padding: '12px 16px', color: 'var(--color-text-muted)', fontSize: '0.88rem' }}>
                        {faq.answer.length > 90 ? faq.answer.slice(0, 90) + '...' : faq.answer}
                      </td>
                      <td style={{ padding: '12px 16px', textAlign: 'right' }}>
                        <div style={{ display: 'flex', gap: 8, justifyContent: 'flex-end' }}>
                          <button
                            className="btn btn--secondary"
                            style={{ padding: '4px 10px', fontSize: '0.8rem' }}
                            onClick={() => handleOpenEditFaq(faq)}
                          >
                            ✏️ Edit
                          </button>
                          <button
                            className="btn btn--danger"
                            style={{ padding: '4px 10px', fontSize: '0.8rem', background: '#fee2e2', color: '#dc2626', border: 'none', borderRadius: '6px', cursor: 'pointer' }}
                            onClick={() => handleDeleteFaq(faq.id)}
                          >
                            🗑️ Delete
                          </button>
                        </div>
                      </td>
                    </tr>
                  ))}
                {faqs.filter((item) => faqCategoryFilter === 'all' || item.category === faqCategoryFilter).length === 0 && (
                  <tr>
                    <td colSpan={5} style={{ padding: '32px', textAlign: 'center', color: 'var(--color-text-muted)' }}>
                      No FAQs found for this category. Click "+ Create FAQ" to add one.
                    </td>
                  </tr>
                )}
              </tbody>
            </table>
          </div>

          {/* Modal / Dialog Drawer for Create / Edit FAQ */}
          {faqModalOpen && (
            <div
              style={{
                position: 'fixed',
                top: 0,
                left: 0,
                right: 0,
                bottom: 0,
                backgroundColor: 'rgba(0,0,0,0.5)',
                display: 'flex',
                alignItems: 'center',
                justifyContent: 'center',
                zIndex: 999,
              }}
            >
              <div
                className="card"
                style={{
                  width: '90%',
                  maxWidth: '560px',
                  background: 'var(--color-bg-surface, #ffffff)',
                  borderRadius: '16px',
                  padding: '24px',
                }}
              >
                <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '16px' }}>
                  <h3 style={{ margin: 0, fontWeight: 700 }}>
                    {editingFaq ? '✏️ Edit FAQ' : '➕ Create New FAQ'}
                  </h3>
                  <button
                    onClick={() => setFaqModalOpen(false)}
                    style={{ background: 'none', border: 'none', fontSize: '1.2rem', cursor: 'pointer' }}
                  >
                    ✖
                  </button>
                </div>

                <form onSubmit={handleSaveFaq} style={{ display: 'flex', flexDirection: 'column', gap: '14px' }}>
                  <div className="field">
                    <label className="field__label">Question *</label>
                    <input
                      type="text"
                      className="field__input"
                      value={faqForm.question}
                      onChange={(e) => setFaqForm({ ...faqForm, question: e.target.value })}
                      placeholder="e.g. How do I list and manage my vehicles?"
                      required
                    />
                  </div>

                  <div className="field">
                    <label className="field__label">Answer *</label>
                    <textarea
                      className="field__input"
                      rows={5}
                      value={faqForm.answer}
                      onChange={(e) => setFaqForm({ ...faqForm, answer: e.target.value })}
                      placeholder="Enter detailed answer here..."
                      required
                    />
                  </div>

                  <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '14px' }}>
                    <div className="field">
                      <label className="field__label">Category</label>
                      <select
                        className="field__input"
                        value={faqForm.category}
                        onChange={(e) => setFaqForm({ ...faqForm, category: e.target.value as any })}
                      >
                        <option value="fleet">Fleet Manager</option>
                        <option value="customer">Customer / Rider</option>
                        <option value="driver">Driver</option>
                        <option value="general">General</option>
                      </select>
                    </div>

                    <div className="field">
                      <label className="field__label">Display Order</label>
                      <input
                        type="number"
                        className="field__input"
                        value={faqForm.order}
                        onChange={(e) => setFaqForm({ ...faqForm, order: parseInt(e.target.value) || 1 })}
                        min="1"
                        required
                      />
                    </div>
                  </div>

                  <div style={{ display: 'flex', justifyContent: 'flex-end', gap: '10px', marginTop: '12px' }}>
                    <button
                      type="button"
                      className="btn btn--secondary"
                      onClick={() => setFaqModalOpen(false)}
                    >
                      Cancel
                    </button>
                    <button type="submit" className="btn btn--primary" disabled={saving}>
                      {saving ? 'Saving...' : editingFaq ? 'Update FAQ' : 'Save FAQ'}
                    </button>
                  </div>
                </form>
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}
