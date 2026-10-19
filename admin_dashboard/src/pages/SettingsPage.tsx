import React, { useEffect, useState } from 'react';
import { doc, getDoc, setDoc, collection, getDocs, deleteDoc } from 'firebase/firestore';
import { db } from '../config/firebase';
import { NIGERIAN_STATES } from '../constants/driverVerification';

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
  tricycle: PricingDetails;
  motorcycle: PricingDetails;
}

const defaultPricing: PricingConfig = {
  regular: { baseFare: 800, perKmRate: 250, perMinuteRate: 50 },
  comfort: { baseFare: 1200, perKmRate: 350, perMinuteRate: 70 },
  luxury: { baseFare: 2500, perKmRate: 600, perMinuteRate: 120 },
  courier: { baseFare: 600, perKmRate: 200, perMinuteRate: 40 },
  tricycle: { baseFare: 400, perKmRate: 150, perMinuteRate: 30 },
  motorcycle: { baseFare: 300, perKmRate: 120, perMinuteRate: 25 },
};

export interface VehicleAvailability {
  enabled: boolean;
  allStates: boolean;
  availableStates: string[];
}

export interface ServiceAvailabilityConfig {
  regular: VehicleAvailability;
  comfort: VehicleAvailability;
  luxury: VehicleAvailability;
  courier: VehicleAvailability;
  tricycle: VehicleAvailability;
  motorcycle: VehicleAvailability;
}

const defaultServiceAvailability: ServiceAvailabilityConfig = {
  regular: { enabled: true, allStates: true, availableStates: [] },
  comfort: { enabled: true, allStates: true, availableStates: [] },
  luxury: { enabled: true, allStates: true, availableStates: [] },
  courier: { enabled: true, allStates: true, availableStates: [] },
  tricycle: {
    enabled: true,
    allStates: false,
    availableStates: ['Edo', 'Delta', 'Oyo', 'Kano', 'Rivers', 'Anambra', 'Enugu'],
  },
  motorcycle: {
    enabled: true,
    allStates: false,
    availableStates: ['Edo', 'Delta', 'Oyo', 'Rivers', 'Akwa Ibom'],
  },
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
  iosUrl: 'https://apps.apple.com/ng/app/caride-ride-delivery/id6802303889',
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

type Tab = 'ride-fare' | 'driver-settings' | 'fleet-rental' | 'referral' | 'support' | 'app-update' | 'legal-settings' | 'faqs';
type LegalCategory = 'rider' | 'driver' | 'fleet';
type LegalSubTab = 'terms' | 'privacy' | 'protocol' | 'insurance';

export function SettingsPage() {
  const [activeTab, setActiveTab] = useState<Tab>('ride-fare');
  const [legalCategory, setLegalCategory] = useState<LegalCategory>('rider');
  const [legalSubTab, setLegalSubTab] = useState<LegalSubTab>('terms');
  const [pricing, setPricing] = useState<PricingConfig>(defaultPricing);
  const [serviceAvailability, setServiceAvailability] = useState<ServiceAvailabilityConfig>(defaultServiceAvailability);
  const [maxDriverNegativeBalance, setMaxDriverNegativeBalance] = useState<number>(3000);
  const [fleetCommissionPercent, setFleetCommissionPercent] = useState<number>(15);
  const [customerReferralPercent, setCustomerReferralPercent] = useState<number>(2);
  const [driverReferralPercent, setDriverReferralPercent] = useState<number>(2);
  const [firstRideCashbackAmount, setFirstRideCashbackAmount] = useState<number>(500);
  const [isFirstRideCashbackActive, setIsFirstRideCashbackActive] = useState<boolean>(true);
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
        try { await fetchFaqs(); } catch (e) { console.warn('FAQs fetch error:', e); }

        try {
          const docRef = doc(db, 'config', 'ridePricing');
          const snap = await getDoc(docRef);
          if (snap.exists()) {
            const data = snap.data() as Partial<PricingConfig>;
            setPricing({
              regular: { ...defaultPricing.regular, ...data.regular },
              comfort: { ...defaultPricing.comfort, ...data.comfort },
              luxury: { ...defaultPricing.luxury, ...data.luxury },
              courier: { ...defaultPricing.courier, ...data.courier },
              tricycle: { ...defaultPricing.tricycle, ...data.tricycle },
              motorcycle: { ...defaultPricing.motorcycle, ...data.motorcycle },
            });
          }
        } catch (e) { console.warn('Pricing fetch error:', e); }

        try {
          const availRef = doc(db, 'config', 'serviceAvailability');
          const availSnap = await getDoc(availRef);
          if (availSnap.exists()) {
            const aData = availSnap.data() as Partial<ServiceAvailabilityConfig>;
            setServiceAvailability({
              regular: { ...defaultServiceAvailability.regular, ...aData.regular },
              comfort: { ...defaultServiceAvailability.comfort, ...aData.comfort },
              luxury: { ...defaultServiceAvailability.luxury, ...aData.luxury },
              courier: { ...defaultServiceAvailability.courier, ...aData.courier },
              tricycle: { ...defaultServiceAvailability.tricycle, ...aData.tricycle },
              motorcycle: { ...defaultServiceAvailability.motorcycle, ...aData.motorcycle },
            });
          }
        } catch (e) { console.warn('Service availability fetch error:', e); }

        try {
          const driverSetRef = doc(db, 'config', 'driverSettings');
          const driverSetSnap = await getDoc(driverSetRef);
          if (driverSetSnap.exists()) {
            const dData = driverSetSnap.data();
            if (dData.maxNegativeBalanceNaira !== undefined) {
              setMaxDriverNegativeBalance(Number(dData.maxNegativeBalanceNaira));
            }
          }
        } catch (e) { console.warn('Driver settings fetch error:', e); }

        try {
          const refRef = doc(db, 'config', 'referralSettings');
          const refSnap = await getDoc(refRef);
          if (refSnap.exists()) {
            const refData = refSnap.data();
            if (refData.customerReferralPercent !== undefined) setCustomerReferralPercent(refData.customerReferralPercent);
            if (refData.driverReferralPercent !== undefined) setDriverReferralPercent(refData.driverReferralPercent);
            if (refData.firstRideCashbackAmount !== undefined) setFirstRideCashbackAmount(Number(refData.firstRideCashbackAmount));
            if (refData.isFirstRideCashbackActive !== undefined) setIsFirstRideCashbackActive(refData.isFirstRideCashbackActive !== false);
          }
        } catch (e) { console.warn('Referral fetch error:', e); }

        try {
          const supportRef = doc(db, 'config', 'appSupport');
          const supportSnap = await getDoc(supportRef);
          if (supportSnap.exists()) {
            const sData = supportSnap.data();
            if (sData.website) setWebsite(sData.website);
            if (sData.supportEmail) setSupportEmail(sData.supportEmail);
            if (sData.supportPhone) setSupportPhone(sData.supportPhone);
          }
        } catch (e) { console.warn('Support fetch error:', e); }

        try {
          const updateRef = doc(db, 'config', 'appUpdate');
          const updateSnap = await getDoc(updateRef);
          if (updateSnap.exists()) {
            setAppUpdate({ ...defaultAppUpdate, ...updateSnap.data() });
          }
        } catch (e) { console.warn('App update fetch error:', e); }

        try {
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
        } catch (e) { console.warn('Legal fetch error:', e); }

        try {
          const fleetRef = doc(db, 'config', 'fleetSettings');
          const fleetSnap = await getDoc(fleetRef);
          if (fleetSnap.exists()) {
            const fData = fleetSnap.data();
            if (fData.commissionPercent !== undefined) {
              setFleetCommissionPercent(fData.commissionPercent);
            }
          } else {
            const sysRef = doc(db, 'system_settings', 'fleet');
            const sysSnap = await getDoc(sysRef);
            if (sysSnap.exists()) {
              const fData = sysSnap.data();
              if (fData.commissionPercent !== undefined) {
                setFleetCommissionPercent(fData.commissionPercent);
              }
            }
          }
        } catch (e) { console.warn('Fleet rental config fetch error:', e); }

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
          tricycle: pricing.tricycle,
          motorcycle: pricing.motorcycle,
        }, { merge: true });

        const availRef = doc(db, 'config', 'serviceAvailability');
        await setDoc(availRef, serviceAvailability, { merge: true });

        setSuccess('Ride fare pricing & vehicle availability settings saved successfully!');
      } else if (activeTab === 'driver-settings') {
        const docRef = doc(db, 'config', 'driverSettings');
        await setDoc(docRef, {
          maxNegativeBalanceNaira: maxDriverNegativeBalance,
          updatedAt: new Date(),
        }, { merge: true });
        setSuccess('Driver settings saved successfully!');
      } else if (activeTab === 'fleet-rental') {
        const docRef = doc(db, 'system_settings', 'fleet');
        await setDoc(docRef, {
          commissionPercent: fleetCommissionPercent,
          updatedAt: new Date(),
        }, { merge: true });
        await setDoc(doc(db, 'config', 'fleetSettings'), {
          commissionPercent: fleetCommissionPercent,
          updatedAt: new Date(),
        }, { merge: true });
        setSuccess('Fleet & Rental settings saved successfully!');
      } else if (activeTab === 'referral') {
        const docRef = doc(db, 'config', 'referralSettings');
        await setDoc(docRef, {
          customerReferralPercent,
          driverReferralPercent,
          firstRideCashbackAmount,
          isFirstRideCashbackActive,
        }, { merge: true });
        setSuccess('Referral & Cashback settings saved successfully!');
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

      {/* Modern Underline Tabs (Matching orders (1).png & account.png) */}
      <div className="tab-bar-underline">
        <button
          type="button"
          className={`tab-btn-underline ${activeTab === 'ride-fare' ? 'active' : ''}`}
          onClick={() => setActiveTab('ride-fare')}
        >
          <span>Ride Fare & Pricing</span>
        </button>
        <button
          type="button"
          className={`tab-btn-underline ${activeTab === 'driver-settings' ? 'active' : ''}`}
          onClick={() => setActiveTab('driver-settings')}
        >
          <span>🚗 Driver Settings</span>
        </button>
        <button
          type="button"
          className={`tab-btn-underline ${activeTab === 'fleet-rental' ? 'active' : ''}`}
          onClick={() => setActiveTab('fleet-rental')}
        >
          <span>🚙 Fleet & Rental</span>
        </button>
        <button
          type="button"
          className={`tab-btn-underline ${activeTab === 'referral' ? 'active' : ''}`}
          onClick={() => setActiveTab('referral')}
        >
          <span>Referral Settings</span>
        </button>
        <button
          type="button"
          className={`tab-btn-underline ${activeTab === 'support' ? 'active' : ''}`}
          onClick={() => setActiveTab('support')}
        >
          <span>Support & Contact</span>
        </button>
        <button
          type="button"
          className={`tab-btn-underline ${activeTab === 'app-update' ? 'active' : ''}`}
          onClick={() => setActiveTab('app-update')}
        >
          <span>🚀 App Update</span>
        </button>
        <button
          type="button"
          className={`tab-btn-underline ${activeTab === 'legal-settings' ? 'active' : ''}`}
          onClick={() => setActiveTab('legal-settings')}
        >
          <span>⚖️ Legal Settings</span>
        </button>
        <button
          type="button"
          className={`tab-btn-underline ${activeTab === 'faqs' ? 'active' : ''}`}
          onClick={() => setActiveTab('faqs')}
        >
          <span>❓ FAQs Management</span>
          <span className="tab-count-badge">{faqs.length}</span>
        </button>
      </div>

      {error && <p className="field__error" style={{ marginBottom: 'var(--space-4)' }}>{error}</p>}
      {success && <p className="success-message" style={{ color: 'var(--success-color, #2e7d32)', marginBottom: 'var(--space-4)', fontWeight: 600 }}>{success}</p>}
      {activeTab === 'driver-settings' && (
        <form onSubmit={handleSave}>
          <div style={{ maxWidth: 640, marginBottom: 'var(--space-5)' }}>
            <article className="card" style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-4)' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-3)' }}>
                <span style={{ fontSize: '1.8rem' }}>🚗</span>
                <div>
                  <h3 style={{ margin: 0, fontWeight: 700, fontSize: '1.2rem' }}>Driver Account & Debt Threshold</h3>
                  <p className="muted" style={{ fontSize: '0.85rem', margin: 0 }}>
                    Control maximum negative balance allowed before driver is restricted from receiving cash or wallet rides.
                  </p>
                </div>
              </div>

              <div className="field">
                <label className="field__label" htmlFor="maxNegativeBalance" style={{ fontWeight: 600 }}>
                  Maximum Allowed Negative Balance / Debt Limit (₦)
                </label>
                <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                  <span style={{ fontWeight: 700, fontSize: '1.1rem', color: '#ef4444' }}>-₦</span>
                  <input
                    id="maxNegativeBalance"
                    className="field__input search-pill"
                    type="number"
                    min="0"
                    step="100"
                    value={maxDriverNegativeBalance}
                    onChange={(e) => setMaxDriverNegativeBalance(parseFloat(e.target.value) || 0)}
                    style={{ width: '100%', borderRadius: 9999, height: 46 }}
                  />
                </div>
                <p className="muted" style={{ fontSize: '0.8rem', marginTop: 8, lineHeight: 1.5 }}>
                  When drivers complete cash rides, platform commission is debited from their CaRide driver wallet balance. If their balance falls below <strong>-₦{maxDriverNegativeBalance.toLocaleString()}</strong>, they will be prevented from toggling online or accepting rides until they top up their wallet to clear their debt.
                </p>
              </div>

              <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: 'var(--space-2)' }}>
                <button
                  type="submit"
                  className="btn btn--primary"
                  disabled={saving}
                  style={{ borderRadius: 9999, padding: '12px 28px' }}
                >
                  {saving ? 'Saving...' : 'Save Driver Settings'}
                </button>
              </div>
            </article>
          </div>
        </form>
      )}

      {activeTab === 'fleet-rental' && (
        <form onSubmit={handleSave}>
          <div style={{ maxWidth: 640, marginBottom: 'var(--space-5)' }}>
            <article className="card" style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-4)' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-3)' }}>
                <span style={{ fontSize: '1.8rem' }}>🚙</span>
                <div>
                  <h3 style={{ margin: 0, fontWeight: 700, fontSize: '1.2rem' }}>Fleet & Rental Commission</h3>
                  <p className="muted" style={{ fontSize: '0.85rem', margin: 0 }}>Configure the platform commission percentage for car rental bookings.</p>
                </div>
              </div>

              <div className="field">
                <label className="field__label" htmlFor="fleetCommissionPercent" style={{ fontWeight: 600 }}>
                  Rental Commission Percentage (%)
                </label>
                <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                  <input
                    id="fleetCommissionPercent"
                    className="field__input search-pill"
                    type="number"
                    min="0"
                    max="100"
                    step="0.5"
                    value={fleetCommissionPercent}
                    onChange={(e) => setFleetCommissionPercent(parseFloat(e.target.value) || 0)}
                    style={{ width: '100%', borderRadius: 9999, height: 46 }}
                  />
                  <span style={{ fontWeight: 700, fontSize: '1.1rem' }}>%</span>
                </div>
                <p className="muted" style={{ fontSize: '0.8rem', marginTop: 6 }}>
                  This percentage is automatically deducted as company commission from rental payments before crediting the fleet manager's wallet.
                </p>
              </div>

              <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: 'var(--space-2)' }}>
                <button
                  type="submit"
                  className="btn btn--primary"
                  disabled={saving}
                  style={{ borderRadius: 9999, padding: '12px 28px' }}
                >
                  {saving ? 'Saving...' : 'Save Commission Settings'}
                </button>
              </div>
            </article>
          </div>
        </form>
      )}

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

            {/* Category: Tricycle (Keke) */}
            <article className="card" style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-3)' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-2)' }}>
                <span style={{ fontSize: '1.5rem' }}>🛺</span>
                <div>
                  <h3 style={{ margin: 0, fontWeight: 700 }}>Tricycle (Keke)</h3>
                  <span style={{ fontSize: '0.75rem', color: 'var(--color-primary)', fontWeight: 600 }}>Commercial 3-Wheeler</span>
                </div>
              </div>
              <p className="muted" style={{ fontSize: '0.85rem', margin: 0 }}>Affordable point-to-point commercial tricycle transport.</p>
              
              <div className="field">
                <label className="field__label">Base Fare (₦)</label>
                <input
                  type="number"
                  className="field__input"
                  value={pricing.tricycle.baseFare}
                  onChange={(e) => handleRateChange('tricycle', 'baseFare', e.target.value)}
                  min="0"
                  required
                />
              </div>

              <div className="field">
                <label className="field__label">Per Kilometer Rate (₦)</label>
                <input
                  type="number"
                  className="field__input"
                  value={pricing.tricycle.perKmRate}
                  onChange={(e) => handleRateChange('tricycle', 'perKmRate', e.target.value)}
                  min="0"
                  required
                />
              </div>

              <div className="field">
                <label className="field__label">Per Minute Rate (₦)</label>
                <input
                  type="number"
                  className="field__input"
                  value={pricing.tricycle.perMinuteRate}
                  onChange={(e) => handleRateChange('tricycle', 'perMinuteRate', e.target.value)}
                  min="0"
                  required
                />
              </div>
            </article>

            {/* Category: Motorcycle */}
            <article className="card" style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-3)' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-2)' }}>
                <span style={{ fontSize: '1.5rem' }}>🏍️</span>
                <div>
                  <h3 style={{ margin: 0, fontWeight: 700 }}>Motorcycle (Bike)</h3>
                  <span style={{ fontSize: '0.75rem', color: 'var(--color-primary)', fontWeight: 600 }}>Fast 2-Wheeler Dispatch</span>
                </div>
              </div>
              <p className="muted" style={{ fontSize: '0.85rem', margin: 0 }}>Fast, economical two-wheeler rides for navigating traffic.</p>
              
              <div className="field">
                <label className="field__label">Base Fare (₦)</label>
                <input
                  type="number"
                  className="field__input"
                  value={pricing.motorcycle.baseFare}
                  onChange={(e) => handleRateChange('motorcycle', 'baseFare', e.target.value)}
                  min="0"
                  required
                />
              </div>

              <div className="field">
                <label className="field__label">Per Kilometer Rate (₦)</label>
                <input
                  type="number"
                  className="field__input"
                  value={pricing.motorcycle.perKmRate}
                  onChange={(e) => handleRateChange('motorcycle', 'perKmRate', e.target.value)}
                  min="0"
                  required
                />
              </div>

              <div className="field">
                <label className="field__label">Per Minute Rate (₦)</label>
                <input
                  type="number"
                  className="field__input"
                  value={pricing.motorcycle.perMinuteRate}
                  onChange={(e) => handleRateChange('motorcycle', 'perMinuteRate', e.target.value)}
                  min="0"
                  required
                />
              </div>
            </article>

          </div>

          {/* Vehicle Type & State Availability Section */}
          <article className="card" style={{ marginBottom: 'var(--space-5)', padding: 'var(--space-5)' }}>
            <div style={{ marginBottom: 'var(--space-4)' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-2)' }}>
                <span style={{ fontSize: '1.5rem' }}>🇳🇬</span>
                <h3 style={{ margin: 0, fontWeight: 800 }}>Vehicle Types & State Availability</h3>
              </div>
              <p className="muted" style={{ fontSize: '0.87rem', margin: '4px 0 0 0' }}>
                Control which ride vehicle types are active and specify Nigerian states where each service is operational. State availability is strictly enforced for customer booking and driver verification.
              </p>
            </div>

            <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-4)' }}>
              {(
                [
                  { key: 'regular', name: 'Regular Ride', icon: '🚗' },
                  { key: 'comfort', name: 'Comfort Ride', icon: '🛋️' },
                  { key: 'luxury', name: 'Luxury Ride', icon: '✨' },
                  { key: 'courier', name: 'Courier Delivery', icon: '📦' },
                  { key: 'tricycle', name: 'Tricycle (Keke)', icon: '🛺' },
                  { key: 'motorcycle', name: 'Motorcycle (Bike)', icon: '🏍️' },
                ] as const
              ).map(({ key, name, icon }) => {
                const config = serviceAvailability[key];
                return (
                  <div
                    key={key}
                    style={{
                      border: '1px solid var(--color-border)',
                      borderRadius: 12,
                      padding: 16,
                      background: config.enabled ? 'transparent' : 'var(--color-bg-alt)',
                      opacity: config.enabled ? 1 : 0.75,
                    }}
                  >
                    <div
                      style={{
                        display: 'flex',
                        alignItems: 'center',
                        justifyContent: 'space-between',
                        flexWrap: 'wrap',
                        gap: 12,
                        marginBottom: config.enabled && !config.allStates ? 14 : 0,
                      }}
                    >
                      <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
                        <span style={{ fontSize: '1.3rem' }}>{icon}</span>
                        <div>
                          <div style={{ fontWeight: 700, fontSize: '0.98rem' }}>{name}</div>
                          <span
                            style={{
                              fontSize: '0.78rem',
                              color: config.enabled
                                ? config.allStates
                                  ? 'var(--color-success)'
                                  : 'var(--color-primary)'
                                : 'var(--color-danger)',
                              fontWeight: 600,
                            }}
                          >
                            {config.enabled
                              ? config.allStates
                                ? 'Active Nationwide (All 36 States + FCT)'
                                : `Active in ${config.availableStates.length} Nigerian state(s)`
                              : 'Disabled Platform-Wide'}
                          </span>
                        </div>
                      </div>

                      <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
                        {/* Enable/Disable Toggle */}
                        <label style={{ display: 'flex', alignItems: 'center', gap: 6, cursor: 'pointer', fontSize: '0.85rem' }}>
                          <input
                            type="checkbox"
                            checked={config.enabled}
                            onChange={(e) => {
                              const checked = e.target.checked;
                              setServiceAvailability((prev) => ({
                                ...prev,
                                [key]: { ...prev[key], enabled: checked },
                              }));
                            }}
                          />
                          <span style={{ fontWeight: 600 }}>Enabled</span>
                        </label>

                        {/* Nationwide Toggle */}
                        {config.enabled && (
                          <label style={{ display: 'flex', alignItems: 'center', gap: 6, cursor: 'pointer', fontSize: '0.85rem' }}>
                            <input
                              type="checkbox"
                              checked={config.allStates}
                              onChange={(e) => {
                                const checked = e.target.checked;
                                setServiceAvailability((prev) => ({
                                  ...prev,
                                  [key]: { ...prev[key], allStates: checked },
                                }));
                              }}
                            />
                            <span style={{ fontWeight: 600 }}>Nationwide</span>
                          </label>
                        )}
                      </div>
                    </div>

                    {/* Specific State Selector if not Nationwide */}
                    {config.enabled && !config.allStates && (
                      <div style={{ marginTop: 12, paddingTop: 12, borderTop: '1px solid var(--color-border)' }}>
                        <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 8 }}>
                          <span style={{ fontSize: '0.82rem', fontWeight: 600, color: 'var(--color-text-muted)' }}>
                            Select Operating States for {name}:
                          </span>
                          <div style={{ display: 'flex', gap: 8 }}>
                            <button
                              type="button"
                              className="btn btn--subtle"
                              style={{ fontSize: '0.72rem', padding: '2px 8px' }}
                              onClick={() => {
                                setServiceAvailability((prev) => ({
                                  ...prev,
                                  [key]: { ...prev[key], availableStates: [...NIGERIAN_STATES] },
                                }));
                              }}
                            >
                              Select All
                            </button>
                            <button
                              type="button"
                              className="btn btn--subtle"
                              style={{ fontSize: '0.72rem', padding: '2px 8px' }}
                              onClick={() => {
                                setServiceAvailability((prev) => ({
                                  ...prev,
                                  [key]: { ...prev[key], availableStates: [] },
                                }));
                              }}
                            >
                              Clear All
                            </button>
                          </div>
                        </div>

                        <div style={{ display: 'flex', flexWrap: 'wrap', gap: 6 }}>
                          {NIGERIAN_STATES.map((state) => {
                            const isSelected = config.availableStates.includes(state);
                            return (
                              <button
                                key={state}
                                type="button"
                                onClick={() => {
                                  const current = config.availableStates || [];
                                  const next = isSelected
                                    ? current.filter((s) => s !== state)
                                    : [...current, state];
                                  setServiceAvailability((prev) => ({
                                    ...prev,
                                    [key]: { ...prev[key], availableStates: next },
                                  }));
                                }}
                                style={{
                                  padding: '4px 10px',
                                  fontSize: '0.75rem',
                                  borderRadius: 9999,
                                  border: isSelected ? '1.5px solid var(--color-primary)' : '1px solid var(--color-border)',
                                  background: isSelected ? 'rgba(34, 197, 94, 0.15)' : 'transparent',
                                  color: isSelected ? 'var(--color-primary)' : 'inherit',
                                  fontWeight: isSelected ? 700 : 500,
                                  cursor: 'pointer',
                                  transition: 'all 0.15s ease',
                                }}
                              >
                                {isSelected ? `✓ ${state}` : state}
                              </button>
                            );
                          })}
                        </div>
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          </article>

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

            {/* First Ride Cashback Settings */}
            <article className="card" style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-3)' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 'var(--space-2)' }}>
                <span style={{ fontSize: '1.5rem' }}>🎁</span>
                <h3 style={{ margin: 0, fontWeight: 700 }}>First Ride Customer Cashback</h3>
              </div>
              <p className="muted" style={{ fontSize: '0.85rem', margin: 0 }}>
                Fixed monetary amount credited to customer's wallet after completing their 1st ride booking.
              </p>
              
              <div className="field">
                <label className="field__label">Cashback Reward Amount (₦)</label>
                <input
                  type="number"
                  className="field__input"
                  value={firstRideCashbackAmount}
                  onChange={(e) => setFirstRideCashbackAmount(parseFloat(e.target.value) || 0)}
                  min="0"
                  step="50"
                  required
                />
              </div>

              <div style={{ display: 'flex', alignItems: 'center', gap: 10, marginTop: 'var(--space-2)' }}>
                <input
                  type="checkbox"
                  id="settingsIsFirstRideCashbackActive"
                  checked={isFirstRideCashbackActive}
                  onChange={(e) => setIsFirstRideCashbackActive(e.target.checked)}
                  style={{ width: 18, height: 18, cursor: 'pointer', accentColor: 'var(--color-primary)' }}
                />
                <label htmlFor="settingsIsFirstRideCashbackActive" style={{ fontWeight: 600, fontSize: '0.9rem', cursor: 'pointer' }}>
                  Enable First Ride Cashback
                </label>
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
                  placeholder="https://apps.apple.com/ng/app/caride-ride-delivery/id6802303889"
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
                    borderRadius: 'var(--radius-full)',
                    border: '1px solid ' + (legalSubTab === 'terms' ? 'var(--color-primary)' : 'var(--color-border)'),
                    background: legalSubTab === 'terms' ? 'var(--color-primary)' : 'var(--color-bg-alt)',
                    color: legalSubTab === 'terms' ? '#ffffff' : 'var(--color-text)',
                    fontWeight: 700,
                    fontSize: '0.9rem',
                    cursor: 'pointer',
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
                        borderRadius: 'var(--radius-full)',
                        border: '1px solid ' + (legalSubTab === 'protocol' ? 'var(--color-primary)' : 'var(--color-border)'),
                        background: legalSubTab === 'protocol' ? 'var(--color-primary)' : 'var(--color-bg-alt)',
                        color: legalSubTab === 'protocol' ? '#ffffff' : 'var(--color-text)',
                        fontWeight: 700,
                        fontSize: '0.9rem',
                        cursor: 'pointer',
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
                        borderRadius: 'var(--radius-full)',
                        border: '1px solid ' + (legalSubTab === 'insurance' ? 'var(--color-primary)' : 'var(--color-border)'),
                        background: legalSubTab === 'insurance' ? 'var(--color-primary)' : 'var(--color-bg-alt)',
                        color: legalSubTab === 'insurance' ? '#ffffff' : 'var(--color-text)',
                        fontWeight: 700,
                        fontSize: '0.9rem',
                        cursor: 'pointer',
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
                    borderRadius: 'var(--radius-full)',
                    border: '1px solid ' + (legalSubTab === 'privacy' ? 'var(--color-primary)' : 'var(--color-border)'),
                    background: legalSubTab === 'privacy' ? 'var(--color-primary)' : 'var(--color-bg-alt)',
                    color: legalSubTab === 'privacy' ? '#ffffff' : 'var(--color-text)',
                    fontWeight: 700,
                    fontSize: '0.9rem',
                    cursor: 'pointer',
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
