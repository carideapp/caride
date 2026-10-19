import React, { useEffect, useState } from 'react';
import {
  collection,
  onSnapshot,
  orderBy,
  query,
  addDoc,
  deleteDoc,
  doc,
  updateDoc,
  serverTimestamp,
  type QuerySnapshot,
  type DocumentData,
} from 'firebase/firestore';
import { ref, uploadBytesResumable, getDownloadURL } from 'firebase/storage';
import { httpsCallable } from 'firebase/functions';
import { db, storage, functions } from '../config/firebase';

type Tab = 'customers' | 'drivers' | 'staff';
type SubTab = 'push' | 'email' | 'popup' | 'banner';
type Audience = 'all' | 'specific';

interface UserRow {
  uid: string;
  fullName: string;
  email: string;
}

interface ActivePopup {
  id: string;
  title: string;
  imageUrl: string;
  target: 'customers' | 'drivers';
  isActive: boolean;
  createdAt: any;
}

interface BannerAd {
  id: string;
  heading: string;
  imageUrl: string;
  startDate: string;
  expiryDate: string;
  target: 'customers' | 'drivers';
  isActive: boolean;
  createdAt: any;
}

export function AnnouncementsPage() {
  const [tab, setTab] = useState<Tab>('customers');
  const [subTab, setSubTab] = useState<SubTab>('push');
  
  // Users lists for search
  const [customers, setCustomers] = useState<UserRow[]>([]);
  const [drivers, setDrivers] = useState<UserRow[]>([]);
  const [staffList, setStaffList] = useState<UserRow[]>([]);

  // Manual / Custom email addresses input (for Staff or any direct recipients)
  const [customEmailsInput, setCustomEmailsInput] = useState('');
  
  // Active popups list
  const [popups, setPopups] = useState<ActivePopup[]>([]);
  
  // Banners list
  const [banners, setBanners] = useState<BannerAd[]>([]);

  // Search/Specific Audience selection
  const [audience, setAudience] = useState<Audience>('all');
  const [searchTerm, setSearchTerm] = useState('');
  const [selectedUids, setSelectedUids] = useState<string[]>([]);
  
  // Push Notification Form State
  const [pushTitle, setPushTitle] = useState('');
  const [pushBody, setPushBody] = useState('');
  const [pushImageUrl, setPushImageUrl] = useState('');
  const [uploadingPushImage, setUploadingPushImage] = useState(false);
  const [sendingPush, setSendingPush] = useState(false);

  // Email Notification Form State
  const [emailSubject, setEmailSubject] = useState('');
  const [emailBody, setEmailBody] = useState('');
  const [emailImageUrl, setEmailImageUrl] = useState('');
  const [uploadingEmailImage, setUploadingEmailImage] = useState(false);
  const [sendingEmail, setSendingEmail] = useState(false);

  // Popup Notification Form State
  const [popupTitle, setPopupTitle] = useState('');
  const [popupImageUrl, setPopupImageUrl] = useState('');
  const [uploadingPopupImage, setUploadingPopupImage] = useState(false);
  const [savingPopup, setSavingPopup] = useState(false);

  // Banner Ads Form State
  const [bannerHeading, setBannerHeading] = useState('');
  const [bannerImageUrl, setBannerImageUrl] = useState('');
  const [bannerStartDate, setBannerStartDate] = useState('');
  const [bannerExpiryDate, setBannerExpiryDate] = useState('');
  const [uploadingBannerImage, setUploadingBannerImage] = useState(false);
  const [savingBanner, setSavingBanner] = useState(false);
  const [editingBannerId, setEditingBannerId] = useState<string | null>(null);

  // Status & Error Messages
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);

  // Load Customers, Drivers, Popups, and Banners from Firestore
  useEffect(() => {
    const unsubCustomers = onSnapshot(
      collection(db, 'customers'),
      (snap: QuerySnapshot<DocumentData>) => {
        const rows: UserRow[] = snap.docs.map((docSnap) => {
          const d = docSnap.data();
          return {
            uid: docSnap.id,
            fullName: d.fullName || '',
            email: d.email || '',
          };
        });
        setCustomers(rows);
      },
      (err) => setError(err.message)
    );

        const unsubDrivers = onSnapshot(
      collection(db, 'drivers'),
      (snap: QuerySnapshot<DocumentData>) => {
        const rows: UserRow[] = snap.docs.map((docSnap) => {
          const d = docSnap.data();
          return {
            uid: docSnap.id,
            fullName: d.fullName || '',
            email: d.email || '',
          };
        });
        setDrivers(rows);
      },
      (err) => setError(err.message)
    );

    const unsubStaff = onSnapshot(
      collection(db, 'staff'),
      (snap: QuerySnapshot<DocumentData>) => {
        const rows: UserRow[] = snap.docs.map((docSnap) => {
          const d = docSnap.data();
          const fullName = [d.firstName, d.lastName].filter(Boolean).join(' ').trim() || d.fullName || '';
          return {
            uid: docSnap.id,
            fullName,
            email: d.email || '',
          };
        });
        setStaffList(rows);
      },
      (err) => setError(err.message)
    );

    const qPopups = query(collection(db, 'popups'), orderBy('createdAt', 'desc'));
    const unsubPopups = onSnapshot(
      qPopups,
      (snap: QuerySnapshot<DocumentData>) => {
        const rows: ActivePopup[] = snap.docs.map((docSnap) => {
          const d = docSnap.data();
          return {
            id: docSnap.id,
            title: d.title || '',
            imageUrl: d.imageUrl || '',
            target: d.target || 'customers',
            isActive: !!d.isActive,
            createdAt: d.createdAt,
          };
        });
        setPopups(rows);
      },
      (err) => setError(err.message)
    );

    const qBanners = query(collection(db, 'banners'), orderBy('createdAt', 'desc'));
    const unsubBanners = onSnapshot(
      qBanners,
      (snap: QuerySnapshot<DocumentData>) => {
        const rows: BannerAd[] = snap.docs.map((docSnap) => {
          const d = docSnap.data();
          return {
            id: docSnap.id,
            heading: d.heading || '',
            imageUrl: d.imageUrl || '',
            startDate: d.startDate || '',
            expiryDate: d.expiryDate || '',
            target: d.target || 'customers',
            isActive: !!d.isActive,
            createdAt: d.createdAt,
          };
        });
        setBanners(rows);
      },
      (err) => setError(err.message)
    );

    return () => {
      unsubCustomers();
      unsubDrivers();
      unsubStaff();
      unsubPopups();
      unsubBanners();
    };
  }, []);

  // Handle Tab changes (Reset selected users)
  const handleTabChange = (newTab: Tab) => {
    setTab(newTab);
    if (newTab === 'staff') {
      setSubTab('email');
    }
    setSelectedUids([]);
    setSearchTerm('');
    setCustomEmailsInput('');
    setError(null);
    setSuccess(null);
  };

  // Image Upload helper
  const handleFileUpload = (
    e: React.ChangeEvent<HTMLInputElement>,
    setImageUrl: (url: string) => void,
    setUploading: (val: boolean) => void
  ) => {
    const file = e.target.files?.[0];
    if (!file) return;

    setUploading(true);
    setError(null);
    const storageRef = ref(storage, `announcements/${Date.now()}_${file.name}`);
    const uploadTask = uploadBytesResumable(storageRef, file);

    uploadTask.on(
      'state_changed',
      null,
      (err) => {
        setError(`Upload failed: ${err.message}`);
        setUploading(false);
      },
      async () => {
        const downloadUrl = await getDownloadURL(uploadTask.snapshot.ref);
        setImageUrl(downloadUrl);
        setUploading(false);
      }
    );
  };

  // Push Dispatch
  const handleSendPush = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!pushTitle.trim() || !pushBody.trim()) {
      setError('Title and Body are required.');
      return;
    }
    // Parse any manually entered custom emails
    const directEmails = customEmailsInput
      .split(/[,\n;]+/)
      .map((em) => em.trim())
      .filter((em) => em.length > 0 && em.includes('@'));

    if (audience === 'specific' && selectedUids.length === 0 && directEmails.length === 0) {
      setError('Please select at least one recipient or enter valid direct email address(es).');
      return;
    }

    setSendingPush(true);
    setError(null);
    setSuccess(null);

    try {
      const sendPushFn = httpsCallable<{
        target: Tab;
        audience: Audience;
        uids: string[];
        title: string;
        body: string;
        imageUrl?: string;
      }>(functions, 'sendAnnouncementPush');

      await sendPushFn({
        target: tab,
        audience,
        uids: selectedUids,
        title: pushTitle,
        body: pushBody,
        imageUrl: pushImageUrl || undefined,
      });

      // Save announcement log history
      await addDoc(collection(db, 'announcements'), {
        type: 'push',
        target: tab,
        audience,
        specificUids: selectedUids,
        title: pushTitle,
        body: pushBody,
        imageUrl: pushImageUrl || null,
        createdAt: serverTimestamp(),
      });

      setSuccess('Push notification sent successfully!');
      setPushTitle('');
      setPushBody('');
      setPushImageUrl('');
      setSelectedUids([]);
    } catch (err: any) {
      setError(err.message || 'Failed to send push notification.');
    } finally {
      setSendingPush(false);
    }
  };

  // Email Dispatch
  const handleSendEmail = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!emailSubject.trim() || !emailBody.trim()) {
      setError('Subject and Body are required.');
      return;
    }
    // Parse any manually entered custom emails
    const directEmails = customEmailsInput
      .split(/[,;\n]+/)
      .map((em) => em.trim())
      .filter((em) => em.length > 0 && em.includes('@'));

    if (audience === 'specific' && selectedUids.length === 0 && directEmails.length === 0) {
      setError('Please select at least one recipient or enter valid direct email address(es).');
      return;
    }

    setSendingEmail(true);
    setError(null);
    setSuccess(null);

    try {
      const sendEmailFn = httpsCallable<{
        target: Tab;
        audience: Audience;
        uids: string[];
        customEmails?: string[];
        subject: string;
        htmlBody: string;
      }>(functions, 'sendAnnouncementEmail');

      // Add simple styling layout surrounding the email body html
      const fullEmailHtml = `
        <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e2e8f0; border-radius: 8px;">
          <div style="text-align: center; border-bottom: 2px solid #16a34a; padding-bottom: 10px; margin-bottom: 20px;">
            <h2 style="color: #16a34a; margin: 0;">CaRide Announcements</h2>
          </div>
          <div style="font-size: 16px; line-height: 1.6; color: #334155;">
            ${emailBody.replace(/\n/g, '<br/>')}
          </div>
          <div style="text-align: center; border-top: 1px solid #e2e8f0; padding-top: 15px; margin-top: 30px; font-size: 12px; color: #94a3b8;">
            &copy; 2026 CaRide. All rights reserved.
          </div>
        </div>
      `;

      await sendEmailFn({
        target: tab,
        audience,
        uids: selectedUids,
        customEmails: directEmails,
        subject: emailSubject,
        htmlBody: fullEmailHtml,
      });

      await addDoc(collection(db, 'announcements'), {
        type: 'email',
        target: tab,
        audience,
        specificUids: selectedUids,
        customEmails: directEmails,
        subject: emailSubject,
        body: emailBody,
        createdAt: serverTimestamp(),
      });

      setSuccess(`Email announcement sent successfully!${directEmails.length > 0 ? ` (Including ${directEmails.length} direct email${directEmails.length > 1 ? 's' : ''})` : ''}`);
      setEmailSubject('');
      setEmailBody('');
      setSelectedUids([]);
      setCustomEmailsInput('');
    } catch (err: any) {
      setError(err.message || 'Failed to send email campaign.');
    } finally {
      setSendingEmail(false);
    }
  };

  // Popup Dispatch
  const handleSavePopup = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!popupTitle.trim() || !popupImageUrl.trim()) {
      setError('Title and 4:3 Image Upload are required.');
      return;
    }
    if (audience === 'specific' && selectedUids.length === 0) {
      setError('Please select at least one recipient.');
      return;
    }

    setSavingPopup(true);
    setError(null);
    setSuccess(null);

    try {
      await addDoc(collection(db, 'popups'), {
        title: popupTitle,
        imageUrl: popupImageUrl,
        target: tab,
        audience,
        specificUids: selectedUids,
        isActive: true,
        createdAt: serverTimestamp(),
      });

      setSuccess('Popup announcement created and published successfully!');
      setPopupTitle('');
      setPopupImageUrl('');
      setSelectedUids([]);
    } catch (err: any) {
      setError(err.message || 'Failed to save popup.');
    } finally {
      setSavingPopup(false);
    }
  };

  const handleDeactivatePopup = async (id: string, currentStatus: boolean) => {
    try {
      await updateDoc(doc(db, 'popups', id), { isActive: !currentStatus });
    } catch (err: any) {
      setError(err.message);
    }
  };

  const handleDeletePopup = async (id: string) => {
    if (!window.confirm('Delete this popup announcement?')) return;
    try {
      await deleteDoc(doc(db, 'popups', id));
    } catch (err: any) {
      setError(err.message);
    }
  };

  // Banner Ads Dispatch
  const handleSaveBanner = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!bannerHeading.trim() || !bannerImageUrl.trim() || !bannerStartDate || !bannerExpiryDate) {
      setError('Heading, Image Upload, Start Date and Expiry Date are all required.');
      return;
    }

    setSavingBanner(true);
    setError(null);
    setSuccess(null);

    try {
      if (editingBannerId) {
        await updateDoc(doc(db, 'banners', editingBannerId), {
          heading: bannerHeading,
          imageUrl: bannerImageUrl,
          startDate: bannerStartDate,
          expiryDate: bannerExpiryDate,
        });
        setSuccess('Banner ad updated successfully!');
      } else {
        await addDoc(collection(db, 'banners'), {
          heading: bannerHeading,
          imageUrl: bannerImageUrl,
          startDate: bannerStartDate,
          expiryDate: bannerExpiryDate,
          target: tab,
          isActive: true,
          createdAt: serverTimestamp(),
        });
        setSuccess('Banner ad created and published successfully!');
      }

      setBannerHeading('');
      setBannerImageUrl('');
      setBannerStartDate('');
      setBannerExpiryDate('');
      setEditingBannerId(null);
    } catch (err: any) {
      setError(err.message || 'Failed to save banner.');
    } finally {
      setSavingBanner(false);
    }
  };

  const handleDeactivateBanner = async (id: string, currentStatus: boolean) => {
    try {
      await updateDoc(doc(db, 'banners', id), { isActive: !currentStatus });
    } catch (err: any) {
      setError(err.message);
    }
  };

  const handleDeleteBanner = async (id: string) => {
    if (!window.confirm('Delete this banner ad?')) return;
    try {
      await deleteDoc(doc(db, 'banners', id));
    } catch (err: any) {
      setError(err.message);
    }
  };

  // User search filtering
  const userList = tab === 'customers' ? customers : tab === 'drivers' ? drivers : staffList;
  const filteredUsers = userList.filter(
    (u) =>
      u.fullName.toLowerCase().includes(searchTerm.toLowerCase()) ||
      u.email.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const toggleSelectUser = (uid: string) => {
    setSelectedUids((prev) =>
      prev.includes(uid) ? prev.filter((id) => id !== uid) : [...prev, uid]
    );
  };

  // Template email format for Live Mail Preview
  const mailPreviewHtml = `
    <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #e2e8f0; border-radius: 8px; background: white; text-align: left;">
      <div style="text-align: center; border-bottom: 2px solid #16a34a; padding-bottom: 10px; margin-bottom: 20px;">
        <h2 style="color: #16a34a; margin: 0;">CaRide Announcements</h2>
      </div>
      <div style="font-size: 14px; line-height: 1.6; color: #334155; min-height: 100px;">
        ${emailBody ? emailBody.replace(/\n/g, '<br/>') : '<span style="color: #94a3b8; font-style: italic;">Start typing below to see live email preview...</span>'}
      </div>
      <div style="text-align: center; border-top: 1px solid #e2e8f0; padding-top: 15px; margin-top: 30px; font-size: 11px; color: #94a3b8;">
        &copy; 2026 CaRide. All rights reserved.
      </div>
    </div>
  `;

  return (
    <div>
      {/* Top Banner tabs: Underline Navigation */}
      <div className="tab-bar-underline" style={{ marginBottom: 20 }}>
        <button
          type="button"
          onClick={() => handleTabChange('customers')}
          className={`tab-btn-underline ${tab === 'customers' ? 'active' : ''}`}
        >
          Customers Announcements <span className="tab-count-badge">{customers.length}</span>
        </button>
        <button
          type="button"
          onClick={() => handleTabChange('drivers')}
          className={`tab-btn-underline ${tab === 'drivers' ? 'active' : ''}`}
        >
          Drivers Announcements <span className="tab-count-badge">{drivers.length}</span>
        </button>
        <button
          type="button"
          onClick={() => handleTabChange('staff')}
          className={`tab-btn-underline ${tab === 'staff' ? 'active' : ''}`}
        >
          Staff Announcements <span className="tab-count-badge">{staffList.length}</span>
        </button>
      </div>

      {/* Success / Error notification */}
      {error && (
        <div className="alert-banner-danger" style={{ marginBottom: 20 }}>
          <div style={{ flex: 1 }}>{error}</div>
        </div>
      )}
      {success && (
        <div style={{ background: 'rgba(16, 185, 129, 0.1)', color: '#10B981', padding: '12px 16px', borderRadius: 16, marginBottom: 20, fontSize: '0.85rem', fontWeight: 600, border: '1px solid rgba(16, 185, 129, 0.2)' }}>
          ✓ {success}
        </div>
      )}

      <div style={{ display: 'grid', gridTemplateColumns: '1.2fr 1fr', gap: 'var(--space-5)' }} className="announcements-layout">
        <style>{`
          @media (max-width: 1024px) {
            .announcements-layout {
              grid-template-columns: 1fr !important;
            }
          }
          .subtabs-bar {
            display: flex;
            flex-wrap: wrap;
            gap: 8px;
            margin-bottom: var(--space-4);
          }
          .subtab-btn {
            padding: 8px 18px;
            border-radius: var(--radius-full);
            font-weight: 600;
            font-size: 0.85rem;
            cursor: pointer;
            border: 1px solid var(--color-border);
            background: var(--color-bg-alt);
            color: var(--color-text-muted);
            transition: all 0.2s ease;
          }
          .subtab-btn.active {
            background: var(--color-primary);
            color: white;
            border-color: var(--color-primary);
          }
          .user-select-list {
            max-height: 200px;
            overflow-y: auto;
            border: 1px solid var(--color-border);
            border-radius: var(--radius-md);
            padding: 8px;
            margin-top: 8px;
          }
          .user-item {
            display: flex;
            align-items: center;
            gap: 8px;
            padding: 6px 8px;
            border-radius: var(--radius-sm);
            cursor: pointer;
          }
          .user-item:hover {
            background: rgba(0,0,0,0.04);
          }
          .selected-badge-container {
            display: flex;
            flex-wrap: wrap;
            gap: 6px;
            margin-top: 8px;
          }
          .selected-user-badge {
            background: var(--color-primary-light, #f0fdf4);
            color: var(--color-primary);
            border: 1px solid rgba(22, 163, 74, 0.3);
            border-radius: 12px;
            padding: 2px 10px;
            font-size: 0.8rem;
            font-weight: 600;
            display: flex;
            align-items: center;
            gap: 6px;
            cursor: pointer;
          }
          .selected-user-badge:hover {
            background: #dcfce7;
          }
          .preview-container {
            border: 1px dashed var(--color-border);
            border-radius: var(--radius-md);
            padding: var(--space-4);
            background: rgba(0,0,0,0.02);
            text-align: center;
          }
          .popup-image-preview {
            width: 100%;
            aspect-ratio: 4/3;
            object-fit: cover;
            border-radius: var(--radius-md);
            border: 1px solid var(--color-border);
          }
        `}</style>

        {/* Main interactive form card */}
        <div className="card" style={{ padding: 'var(--space-5)' }}>
          {/* Sub-tabs: Push, Email, Popup */}
          <div className="subtabs-bar">
            {tab !== 'staff' && (
              <button
                type="button"
                className={`subtab-btn ${subTab === 'push' ? 'active' : ''}`}
                onClick={() => setSubTab('push')}
              >
                Push Notification
              </button>
            )}
            <button
              type="button"
              className={`subtab-btn ${subTab === 'email' ? 'active' : ''}`}
              onClick={() => setSubTab('email')}
            >
              Email Notification
            </button>
            {tab !== 'staff' && (
              <>
                <button
                  type="button"
                  className={`subtab-btn ${subTab === 'popup' ? 'active' : ''}`}
                  onClick={() => setSubTab('popup')}
                >
                  Popup Announcement (Image Only)
                </button>
                <button
                  type="button"
                  className={`subtab-btn ${subTab === 'banner' ? 'active' : ''}`}
                  onClick={() => setSubTab('banner')}
                >
                  Banner Ads
                </button>
              </>
            )}
          </div>

          <h3 style={{ fontSize: '1.2rem', fontWeight: 800, marginBottom: 'var(--space-4)', textTransform: 'capitalize' }}>
            {subTab === 'banner' && editingBannerId ? 'Edit Banner Ad' : `New ${subTab === 'banner' ? 'Banner Ad' : subTab} announcement`} for {tab}
          </h3>

          {/* Form component */}
          <form onSubmit={
            subTab === 'push' ? handleSendPush :
            subTab === 'email' ? handleSendEmail :
            subTab === 'popup' ? handleSavePopup :
            handleSaveBanner
          }>
            {/* Target Select section */}
            {subTab !== 'banner' && (
              <>
                <div className="field" style={{ marginBottom: 'var(--space-4)' }}>
                  <label className="field__label">Audience Target</label>
                  <div style={{ display: 'flex', gap: 16, marginTop: 6 }}>
                    <label style={{ display: 'flex', alignItems: 'center', gap: 6, cursor: 'pointer' }}>
                      <input
                        type="radio"
                        name="audience"
                        value="all"
                        checked={audience === 'all'}
                        onChange={() => setAudience('all')}
                      />
                      Send to All {tab}
                    </label>
                    <label style={{ display: 'flex', alignItems: 'center', gap: 6, cursor: 'pointer' }}>
                      <input
                        type="radio"
                        name="audience"
                        value="specific"
                        checked={audience === 'specific'}
                        onChange={() => setAudience('specific')}
                      />
                      Send to Specific {tab}
                    </label>
                  </div>
                </div>

                {/* Specific Users Selector widget */}
                {audience === 'specific' && (
                  <div className="field" style={{ marginBottom: 'var(--space-4)', borderLeft: '3px solid var(--color-primary)', paddingLeft: 12 }}>
                    <label className="field__label">Search & Select recipients</label>
                    <input
                      type="text"
                      className="field__input"
                      placeholder={`Search ${tab} by name or email...`}
                      value={searchTerm}
                      onChange={(e) => setSearchTerm(e.target.value)}
                    />
                    
                    {/* Available search results */}
                    {searchTerm && (
                      <div className="user-select-list">
                        {filteredUsers.length === 0 ? (
                          <p className="muted" style={{ padding: 6, margin: 0, fontSize: '0.85rem' }}>No matching users found.</p>
                        ) : (
                          filteredUsers.map((user) => {
                            const selected = selectedUids.includes(user.uid);
                            return (
                              <div
                                key={user.uid}
                                className="user-item"
                                onClick={() => toggleSelectUser(user.uid)}
                              >
                                <input
                                  type="checkbox"
                                  checked={selected}
                                  readOnly
                                  style={{ pointerEvents: 'none' }}
                                />
                                <div>
                                  <div style={{ fontWeight: 600, fontSize: '0.85rem' }}>{user.fullName || 'No Name'}</div>
                                  <div className="muted" style={{ fontSize: '0.75rem' }}>{user.email}</div>
                                </div>
                              </div>
                            );
                          })
                        )}
                      </div>
                    )}

                    {/* Direct Custom Emails input */}
                    <div style={{ marginTop: 14, paddingTop: 12, borderTop: '1px dashed var(--color-border)' }}>
                      <label className="field__label" style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                        <span>Send to Specific / Custom Email(s)</span>
                        <span className="muted" style={{ fontSize: '0.75rem', fontWeight: 400 }}>Separate multiple emails by comma or new line</span>
                      </label>
                      <textarea
                        className="field__input"
                        rows={2}
                        placeholder="e.g. staff.member@gmail.com, manager@caride.com"
                        value={customEmailsInput}
                        onChange={(e) => setCustomEmailsInput(e.target.value)}
                        style={{ fontSize: '0.85rem', resize: 'vertical' }}
                      />
                    </div>

                    {/* Selected Badge counter */}
                    <div style={{ marginTop: 10 }}>
                      <span style={{ fontSize: '0.8rem', fontWeight: 600 }}>Selected UIDs ({selectedUids.length}):</span>
                      <div className="selected-badge-container">
                        {selectedUids.length === 0 ? (
                          <span className="muted" style={{ fontSize: '0.8rem' }}>None selected. Use the search field above.</span>
                        ) : (
                          selectedUids.map((uid) => {
                            const info = userList.find((u) => u.uid === uid);
                            return (
                              <div
                                key={uid}
                                className="selected-user-badge"
                                title="Click to remove"
                                onClick={() => toggleSelectUser(uid)}
                              >
                                {info?.fullName || info?.email || uid.substring(0, 6)} &times;
                              </div>
                            );
                          })
                        )}
                      </div>
                    </div>
                  </div>
                )}
              </>
            )}

            {/* Tab Form: PUSH */}
            {subTab === 'push' && (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-4)' }}>
                <div className="field">
                  <label className="field__label">Push Notification Title</label>
                  <input
                    type="text"
                    className="field__input"
                    placeholder="Enter heading..."
                    value={pushTitle}
                    onChange={(e) => setPushTitle(e.target.value)}
                    required
                  />
                </div>
                <div className="field">
                  <label className="field__label">Push Notification Message</label>
                  <textarea
                    className="field__input"
                    rows={4}
                    placeholder="Enter description..."
                    value={pushBody}
                    onChange={(e) => setPushBody(e.target.value)}
                    required
                    style={{ resize: 'vertical' }}
                  />
                </div>
                <div className="field">
                  <label className="field__label">Image Upload (Optional)</label>
                  <div style={{ display: 'flex', gap: 12 }}>
                    <input
                      type="file"
                      accept="image/*"
                      onChange={(e) => handleFileUpload(e, setPushImageUrl, setUploadingPushImage)}
                      style={{ display: 'none' }}
                      id="push-file-input"
                    />
                    <label htmlFor="push-file-input" className="btn btn--ghost" style={{ cursor: 'pointer' }}>
                      {uploadingPushImage ? 'Uploading image...' : 'Choose File'}
                    </label>
                    <input
                      type="text"
                      className="field__input"
                      placeholder="Or enter image URL..."
                      value={pushImageUrl}
                      onChange={(e) => setPushImageUrl(e.target.value)}
                    />
                  </div>
                  {pushImageUrl && (
                    <div style={{ marginTop: 8 }}>
                      <img src={pushImageUrl} alt="Push Preview" style={{ maxHeight: 100, borderRadius: 6 }} />
                    </div>
                  )}
                </div>

                <button
                  type="submit"
                  className="btn btn--primary"
                  style={{ marginTop: 12 }}
                  disabled={sendingPush || uploadingPushImage}
                >
                  {sendingPush ? 'Sending Push Notification...' : 'Send Push Notification'}
                </button>
              </div>
            )}

            {/* Tab Form: EMAIL */}
            {subTab === 'email' && (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-4)' }}>
                <div className="field">
                  <label className="field__label">Email Campaign Subject</label>
                  <input
                    type="text"
                    className="field__input"
                    placeholder="Enter heading..."
                    value={emailSubject}
                    onChange={(e) => setEmailSubject(e.target.value)}
                    required
                  />
                </div>
                <div className="field">
                  <label className="field__label">Email Body (HTML/Text)</label>
                  <textarea
                    className="field__input"
                    rows={8}
                    placeholder="Type email body content here..."
                    value={emailBody}
                    onChange={(e) => setEmailBody(e.target.value)}
                    required
                    style={{ resize: 'vertical' }}
                  />
                </div>
                
                {/* Embed Image Upload Helper widget */}
                <div className="field" style={{ background: 'rgba(0,0,0,0.02)', padding: 12, borderRadius: 6, border: '1px dashed var(--color-border)' }}>
                  <label className="field__label" style={{ fontSize: '0.8rem' }}>Embed Image Helper</label>
                  <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
                    <input
                      type="file"
                      accept="image/*"
                      onChange={(e) => handleFileUpload(e, setEmailImageUrl, setUploadingEmailImage)}
                      style={{ display: 'none' }}
                      id="email-file-input"
                    />
                    <label htmlFor="email-file-input" className="btn btn--ghost btn--sm" style={{ cursor: 'pointer' }}>
                      {uploadingEmailImage ? 'Uploading...' : 'Upload Image to embed'}
                    </label>
                    <input
                      type="text"
                      className="field__input field__input--sm"
                      readOnly
                      placeholder="Uploaded image URL will appear here..."
                      value={emailImageUrl}
                    />
                    {emailImageUrl && (
                      <button
                        type="button"
                        className="btn btn--sm btn--primary"
                        onClick={() => {
                          navigator.clipboard.writeText(`<img src="${emailImageUrl}" alt="Announcement Image" style="max-width: 100%; border-radius: 8px; margin: 12px 0;" />`);
                          alert('Copied <img> tag containing the URL to clipboard! You can paste it into the body text.');
                        }}
                      >
                        Copy &lt;img&gt; tag
                      </button>
                    )}
                  </div>
                </div>

                <button
                  type="submit"
                  className="btn btn--primary"
                  style={{ marginTop: 12 }}
                  disabled={sendingEmail || uploadingEmailImage}
                >
                  {sendingEmail ? 'Sending Email Campaign...' : 'Send Email Campaign'}
                </button>
              </div>
            )}

            {/* Tab Form: POPUP */}
            {subTab === 'popup' && (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-4)' }}>
                <div className="field">
                  <label className="field__label">Popup Administrative Heading</label>
                  <input
                    type="text"
                    className="field__input"
                    placeholder="Enter catalog title (e.g. Easter Promo PopUp)..."
                    value={popupTitle}
                    onChange={(e) => setPopupTitle(e.target.value)}
                    required
                  />
                </div>
                <div className="field">
                  <label className="field__label">Upload 4:3 Image (Required)</label>
                  <div style={{ display: 'flex', gap: 12 }}>
                    <input
                      type="file"
                      accept="image/*"
                      onChange={(e) => handleFileUpload(e, setPopupImageUrl, setUploadingPopupImage)}
                      style={{ display: 'none' }}
                      id="popup-file-input"
                    />
                    <label htmlFor="popup-file-input" className="btn btn--ghost" style={{ cursor: 'pointer' }}>
                      {uploadingPopupImage ? 'Uploading image...' : 'Choose File'}
                    </label>
                    <input
                      type="text"
                      className="field__input"
                      placeholder="Or enter image URL..."
                      value={popupImageUrl}
                      onChange={(e) => setPopupImageUrl(e.target.value)}
                      required
                    />
                  </div>
                </div>

                <button
                  type="submit"
                  className="btn btn--primary"
                  style={{ marginTop: 12 }}
                  disabled={savingPopup || uploadingPopupImage}
                >
                  {savingPopup ? 'Publishing Popup Announcement...' : 'Publish Popup Announcement'}
                </button>
              </div>
            )}
            {/* Tab Form: BANNER */}
            {subTab === 'banner' && (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-4)' }}>
                <div className="field">
                  <label className="field__label">Banner Heading</label>
                  <input
                    type="text"
                    className="field__input"
                    placeholder="Enter banner heading (e.g. 50% Off First Ride!)..."
                    value={bannerHeading}
                    onChange={(e) => setBannerHeading(e.target.value)}
                    required
                  />
                </div>
                <div className="field">
                  <label className="field__label">Upload Banner Image (16:9 or 4:3) (Required)</label>
                  <div style={{ display: 'flex', gap: 12 }}>
                    <input
                      type="file"
                      accept="image/*"
                      onChange={(e) => handleFileUpload(e, setBannerImageUrl, setUploadingBannerImage)}
                      style={{ display: 'none' }}
                      id="banner-file-input"
                    />
                    <label htmlFor="banner-file-input" className="btn btn--ghost" style={{ cursor: 'pointer' }}>
                      {uploadingBannerImage ? 'Uploading image...' : 'Choose File'}
                    </label>
                    <input
                      type="text"
                      className="field__input"
                      placeholder="Or enter image URL..."
                      value={bannerImageUrl}
                      onChange={(e) => setBannerImageUrl(e.target.value)}
                      required
                    />
                  </div>
                </div>
                <div className="field">
                  <label className="field__label">Start Date & Time</label>
                  <input
                    type="datetime-local"
                    className="field__input"
                    value={bannerStartDate}
                    onChange={(e) => setBannerStartDate(e.target.value)}
                    required
                  />
                </div>
                <div className="field">
                  <label className="field__label">Expiry Date & Time</label>
                  <input
                    type="datetime-local"
                    className="field__input"
                    value={bannerExpiryDate}
                    onChange={(e) => setBannerExpiryDate(e.target.value)}
                    required
                  />
                </div>

                <div style={{ display: 'flex', gap: 12, marginTop: 12 }}>
                  <button
                    type="submit"
                    className="btn btn--primary"
                    disabled={savingBanner || uploadingBannerImage}
                  >
                    {savingBanner ? 'Saving...' : (editingBannerId ? 'Save Changes' : 'Publish Banner Ad')}
                  </button>
                  {editingBannerId && (
                    <button
                      type="button"
                      className="btn btn--ghost"
                      onClick={() => {
                        setEditingBannerId(null);
                        setBannerHeading('');
                        setBannerImageUrl('');
                        setBannerStartDate('');
                        setBannerExpiryDate('');
                      }}
                    >
                      Cancel Edit
                    </button>
                  )}
                </div>
              </div>
            )}
          </form>
        </div>

        {/* Visual Live Preview panels or history lists */}
        <div>
          {/* Subtab Preview: EMAIL */}
          {subTab === 'email' && (
            <div>
              <h3 style={{ fontSize: '1.05rem', fontWeight: 700, marginBottom: 'var(--space-3)' }}>
                Live HTML Email Preview
              </h3>
              <div
                style={{
                  border: '1px solid var(--color-border)',
                  borderRadius: 'var(--radius-lg)',
                  background: '#f8fafc',
                  padding: 'var(--space-4)',
                  maxHeight: 500,
                  overflowY: 'auto',
                }}
                dangerouslySetInnerHTML={{ __html: mailPreviewHtml }}
              />
            </div>
          )}

          {/* Subtab Preview: POPUP (Simulate Mobile Popup) */}
          {subTab === 'popup' && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-5)' }}>
              <div>
                <h3 style={{ fontSize: '1.05rem', fontWeight: 700, marginBottom: 'var(--space-3)' }}>
                  App Popup Preview (Image Only, 4:3 aspect ratio)
                </h3>
                
                {/* Mobile Phone Mock frame */}
                <div style={{
                  border: '12px solid #334155',
                  borderRadius: 36,
                  background: '#0f172a',
                  width: 320,
                  height: 520,
                  margin: '0 auto',
                  position: 'relative',
                  overflow: 'hidden',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                }}>
                  {/* Speaker slot */}
                  <div style={{ width: 60, height: 4, background: '#1e293b', borderRadius: 2, position: 'absolute', top: 12, left: '50%', transform: 'translateX(-50%)' }} />
                  
                  {/* Backdrop Overlay representation */}
                  <div style={{ position: 'absolute', inset: 0, background: 'rgba(0,0,0,0.6)', backdropFilter: 'blur(3px)', display: 'flex', alignItems: 'center', justifyContent: 'center', padding: 20 }}>
                    
                    {/* Simulated PopUp container */}
                    <div style={{ background: '#1e293b', borderRadius: 16, width: '100%', overflow: 'hidden', border: '1px solid rgba(255,255,255,0.08)', position: 'relative' }}>
                      {/* Close button */}
                      <div style={{ position: 'absolute', top: 8, right: 8, background: 'rgba(0,0,0,0.5)', width: 24, height: 24, borderRadius: '50%', color: 'white', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 12, fontWeight: 'bold', cursor: 'pointer' }}>&times;</div>
                      
                      {/* Image preview */}
                      {popupImageUrl ? (
                        <img src={popupImageUrl} className="popup-image-preview" alt="Popup Announcement" />
                      ) : (
                        <div style={{ width: '100%', aspectRatio: '4/3', display: 'flex', alignItems: 'center', justifyContent: 'center', background: '#334155', color: '#64748b', fontSize: '0.8rem', padding: 20, textAlign: 'center' }}>
                          Upload an image to see simulated 4:3 popup display.
                        </div>
                      )}
                    </div>

                  </div>
                </div>
              </div>

              {/* Published popups listing catalog */}
              <div>
                <h3 style={{ fontSize: '1.05rem', fontWeight: 700, marginBottom: 'var(--space-3)' }}>
                  Active Popups Catalog ({popups.length})
                </h3>
                {popups.length === 0 ? (
                  <div className="card" style={{ padding: 'var(--space-4)', textAlign: 'center' }}>
                    <p className="muted" style={{ margin: 0 }}>No active popup announcements.</p>
                  </div>
                ) : (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-3)' }}>
                    {popups.map((item) => (
                      <article key={item.id} className="card" style={{ padding: 'var(--space-3)' }}>
                        <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
                          <img src={item.imageUrl} alt={item.title} style={{ width: 60, height: 45, objectFit: 'cover', borderRadius: 4, border: '1px solid var(--color-border)' }} />
                          <div style={{ flex: 1, minWidth: 0 }}>
                            <div style={{ fontWeight: 700, fontSize: '0.9rem', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{item.title}</div>
                            <div className="muted" style={{ fontSize: '0.75rem', textTransform: 'capitalize' }}>
                              Target: {item.target}
                            </div>
                          </div>
                          <div style={{ display: 'flex', gap: 6 }}>
                            <button
                              type="button"
                              className={`btn btn--sm btn--${item.isActive ? 'ghost' : 'primary'}`}
                              onClick={() => handleDeactivatePopup(item.id, item.isActive)}
                            >
                              {item.isActive ? 'Deactivate' : 'Activate'}
                            </button>
                            <button
                              type="button"
                              className="btn btn--sm btn--ghost"
                              onClick={() => handleDeletePopup(item.id)}
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
            </div>
          )}

          {/* Subtab Preview: PUSH (Simulate Push Notification) */}
          {subTab === 'push' && (
            <div>
              <h3 style={{ fontSize: '1.05rem', fontWeight: 700, marginBottom: 'var(--space-3)' }}>
                Simulated Push Notification Preview
              </h3>
              <div style={{
                background: '#1e293b',
                color: 'white',
                padding: 'var(--space-3)',
                borderRadius: 'var(--radius-lg)',
                border: '1px solid rgba(255,255,255,0.08)',
              }}>
                <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 8 }}>
                  <div style={{ width: 18, height: 18, background: '#16a34a', borderRadius: 4, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 10, fontWeight: 'bold' }}>C</div>
                  <span style={{ fontSize: '0.75rem', fontWeight: 600, color: '#94a3b8' }}>CARIDE &bull; JUST NOW</span>
                </div>
                <div>
                  <div style={{ fontWeight: 800, fontSize: '0.9rem', marginBottom: 2 }}>
                    {pushTitle || 'Sample Title'}
                  </div>
                  <div style={{ fontSize: '0.8rem', color: '#cbd5e1', lineHeight: 1.4 }}>
                    {pushBody || 'This is how your description text will look on target devices...'}
                  </div>
                  {pushImageUrl && (
                    <div style={{ marginTop: 8 }}>
                      <img src={pushImageUrl} alt="Push Notification Content" style={{ width: '100%', maxHeight: 120, objectFit: 'cover', borderRadius: 6 }} />
                    </div>
                  )}
                </div>
              </div>
            </div>
          )}

          {/* Subtab Preview: BANNER */}
          {subTab === 'banner' && (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-5)' }}>
              <div>
                <h3 style={{ fontSize: '1.05rem', fontWeight: 700, marginBottom: 'var(--space-3)' }}>
                  Banner Ad Preview (16:9 aspect ratio)
                </h3>
                <div style={{
                  width: '100%',
                  aspectRatio: '16/9',
                  borderRadius: 'var(--radius-lg)',
                  border: '1px solid var(--color-border)',
                  background: '#f1f5f9',
                  overflow: 'hidden',
                  position: 'relative',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                }}>
                  {bannerImageUrl ? (
                    <img src={bannerImageUrl} alt="Banner Preview" style={{ width: '100%', height: '100%', objectFit: 'cover' }} />
                  ) : (
                    <div style={{ color: '#64748b', fontSize: '0.85rem', padding: 20, textAlign: 'center' }}>
                      Upload an image to see simulated 16:9 banner display.
                    </div>
                  )}
                </div>
              </div>

              {/* Published banners listing catalog */}
              <div>
                <h3 style={{ fontSize: '1.05rem', fontWeight: 700, marginBottom: 'var(--space-3)' }}>
                  Banner ads History ({banners.filter((b) => b.target === tab).length})
                </h3>
                {banners.filter((b) => b.target === tab).length === 0 ? (
                  <div className="card" style={{ padding: 'var(--space-4)', textAlign: 'center' }}>
                    <p className="muted" style={{ margin: 0 }}>No banner ads posted yet.</p>
                  </div>
                ) : (
                  <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-3)' }}>
                    {banners
                      .filter((b) => b.target === tab)
                      .map((item) => (
                        <article key={item.id} className="card" style={{ padding: 'var(--space-3)' }}>
                          <div style={{ display: 'flex', gap: 12, alignItems: 'center' }}>
                            <img src={item.imageUrl} alt={item.heading} style={{ width: 80, height: 45, objectFit: 'cover', borderRadius: 4, border: '1px solid var(--color-border)' }} />
                            <div style={{ flex: 1, minWidth: 0 }}>
                              <div style={{ fontWeight: 700, fontSize: '0.9rem', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>{item.heading}</div>
                              <div className="muted" style={{ fontSize: '0.72rem', display: 'flex', flexDirection: 'column', gap: 2 }}>
                                <span>Start: {new Date(item.startDate).toLocaleString()}</span>
                                <span>Expiry: {new Date(item.expiryDate).toLocaleString()}</span>
                              </div>
                            </div>
                            <div style={{ display: 'flex', gap: 6 }}>
                              <button
                                type="button"
                                className="btn btn--sm btn--primary"
                                onClick={() => {
                                  setEditingBannerId(item.id);
                                  setBannerHeading(item.heading);
                                  setBannerImageUrl(item.imageUrl);
                                  setBannerStartDate(item.startDate);
                                  setBannerExpiryDate(item.expiryDate);
                                  // Scroll form to view
                                  window.scrollTo({ top: 0, behavior: 'smooth' });
                                }}
                              >
                                Edit
                              </button>
                              <button
                                type="button"
                                className={`btn btn--sm btn--${item.isActive ? 'ghost' : 'primary'}`}
                                onClick={() => handleDeactivateBanner(item.id, item.isActive)}
                              >
                                {item.isActive ? 'Deactivate' : 'Activate'}
                              </button>
                              <button
                                type="button"
                                className="btn btn--sm btn--ghost"
                                onClick={() => handleDeleteBanner(item.id)}
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
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
