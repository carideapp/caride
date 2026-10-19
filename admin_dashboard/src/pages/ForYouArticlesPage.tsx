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
import { db, storage } from '../config/firebase';

interface ForYouArticle {
  id: string;
  title: string;
  shortDescription: string;
  content: string;
  coverImageUrl: string;
  category: string;
  readTime: string;
  isActive: boolean;
  createdAt: any;
  updatedAt?: any;
}

const CATEGORIES = [
  'Safety',
  'Tips',
  'Guide',
  'Rental',
  'Courier',
  'Offers',
  'Community',
];

export function ForYouArticlesPage() {
  const [articles, setArticles] = useState<ForYouArticle[]>([]);
  const [loading, setLoading] = useState(true);

  // Form states
  const [editingId, setEditingId] = useState<string | null>(null);
  const [title, setTitle] = useState('');
  const [category, setCategory] = useState('Safety');
  const [shortDescription, setShortDescription] = useState('');
  const [content, setContent] = useState('');
  const [coverImageUrl, setCoverImageUrl] = useState('');
  const [readTime, setReadTime] = useState('3 min read');
  const [isActive, setIsActive] = useState(true);

  // UI status
  const [uploadingImage, setUploadingImage] = useState(false);
  const [uploadProgress, setUploadProgress] = useState(0);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [success, setSuccess] = useState<string | null>(null);
  const [searchFilter, setSearchFilter] = useState('');

  // 1. Subscribe to Firestore `for_you_articles`
  useEffect(() => {
    const q = query(
      collection(db, 'for_you_articles'),
      orderBy('createdAt', 'desc')
    );

    const unsub = onSnapshot(
      q,
      (snap: QuerySnapshot<DocumentData>) => {
        const rows: ForYouArticle[] = snap.docs.map((docSnap) => {
          const d = docSnap.data();
          return {
            id: docSnap.id,
            title: d.title || '',
            shortDescription: d.shortDescription || '',
            content: d.content || '',
            coverImageUrl: d.coverImageUrl || '',
            category: d.category || 'Tips',
            readTime: d.readTime || '3 min read',
            isActive: d.isActive !== false,
            createdAt: d.createdAt,
            updatedAt: d.updatedAt,
          };
        });
        setArticles(rows);
        setLoading(false);
      },
      (err) => {
        setError(`Failed to load articles: ${err.message}`);
        setLoading(false);
      }
    );

    return () => unsub();
  }, []);

  // Auto-estimate read time when content changes
  useEffect(() => {
    const words = (content + ' ' + shortDescription).trim().split(/\s+/).filter(Boolean).length;
    const mins = Math.max(1, Math.ceil(words / 180));
    setReadTime(`${mins} min read`);
  }, [content, shortDescription]);

  // Image Upload helper
  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    if (!file.type.startsWith('image/')) {
      setError('Please select a valid image file (JPG, PNG, WEBP).');
      return;
    }

    setUploadingImage(true);
    setUploadProgress(0);
    setError(null);

    const storageRef = ref(storage, `for_you/${Date.now()}_${file.name.replace(/\s+/g, '_')}`);
    const uploadTask = uploadBytesResumable(storageRef, file);

    uploadTask.on(
      'state_changed',
      (snapshot) => {
        const progress = Math.round((snapshot.bytesTransferred / snapshot.totalBytes) * 100);
        setUploadProgress(progress);
      },
      (err) => {
        setError(`Image upload failed: ${err.message}`);
        setUploadingImage(false);
      },
      async () => {
        const downloadUrl = await getDownloadURL(uploadTask.snapshot.ref);
        setCoverImageUrl(downloadUrl);
        setUploadingImage(false);
        setSuccess('Cover image uploaded successfully.');
      }
    );
  };

  // Reset form
  const handleResetForm = () => {
    setEditingId(null);
    setTitle('');
    setCategory('Safety');
    setShortDescription('');
    setContent('');
    setCoverImageUrl('');
    setReadTime('3 min read');
    setIsActive(true);
    setError(null);
    setSuccess(null);
  };

  // Populate form for editing
  const handleStartEdit = (article: ForYouArticle) => {
    setEditingId(article.id);
    setTitle(article.title);
    setCategory(article.category);
    setShortDescription(article.shortDescription);
    setContent(article.content);
    setCoverImageUrl(article.coverImageUrl);
    setReadTime(article.readTime);
    setIsActive(article.isActive);
    setError(null);
    setSuccess(null);
    window.scrollTo({ top: 0, behavior: 'smooth' });
  };

  // Save / Update
  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!title.trim()) {
      setError('Article Title is required.');
      return;
    }
    if (!shortDescription.trim()) {
      setError('Short description / summary is required.');
      return;
    }
    if (!content.trim()) {
      setError('Article content is required.');
      return;
    }

    setSaving(true);
    setError(null);
    setSuccess(null);

    try {
      const payload = {
        title: title.trim(),
        category,
        shortDescription: shortDescription.trim(),
        content: content.trim(),
        coverImageUrl: coverImageUrl.trim(),
        readTime: readTime.trim() || '3 min read',
        isActive,
        updatedAt: serverTimestamp(),
      };

      if (editingId) {
        await updateDoc(doc(db, 'for_you_articles', editingId), payload);
        setSuccess('Article updated successfully!');
      } else {
        await addDoc(collection(db, 'for_you_articles'), {
          ...payload,
          createdAt: serverTimestamp(),
        });
        setSuccess('New article published to customer "For you" feed!');
        handleResetForm();
      }
    } catch (err: any) {
      setError(`Failed to save article: ${err.message}`);
    } finally {
      setSaving(false);
    }
  };

  // Toggle active status
  const handleToggleActive = async (article: ForYouArticle) => {
    try {
      await updateDoc(doc(db, 'for_you_articles', article.id), {
        isActive: !article.isActive,
        updatedAt: serverTimestamp(),
      });
      setSuccess(`Article marked as ${!article.isActive ? 'Active' : 'Inactive'}.`);
    } catch (err: any) {
      setError(`Status update failed: ${err.message}`);
    }
  };

  // Delete article
  const handleDelete = async (articleId: string) => {
    if (!window.confirm('Are you sure you want to delete this educational article?')) {
      return;
    }
    try {
      await deleteDoc(doc(db, 'for_you_articles', articleId));
      if (editingId === articleId) {
        handleResetForm();
      }
      setSuccess('Article deleted successfully.');
    } catch (err: any) {
      setError(`Delete failed: ${err.message}`);
    }
  };

  const filteredArticles = articles.filter((a) => {
    if (!searchFilter.trim()) return true;
    const q = searchFilter.toLowerCase();
    return (
      a.title.toLowerCase().includes(q) ||
      a.category.toLowerCase().includes(q) ||
      a.shortDescription.toLowerCase().includes(q)
    );
  });

  return (
    <div className="page-container">
      {/* Header */}
      <div className="page-header" style={{ marginBottom: 'var(--space-4)' }}>
        <div>
          <h1 className="page-title" style={{ fontSize: '1.6rem', fontWeight: 800 }}>
            "For You" Educational & Blog Content
          </h1>
          <p className="page-subtitle" style={{ color: 'var(--color-text-muted)', fontSize: '0.9rem' }}>
            Create and curate educational blog posts, tips, and safety articles displayed on the Customer Home Screen.
          </p>
        </div>
      </div>

      {/* Metrics Row (Solid Dark Brand Cards per AGENTS.md) */}
      <div className="metrics-grid" style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: 'var(--space-4)', marginBottom: 'var(--space-5)' }}>
        <div style={{ background: '#064e3b', borderRadius: '18px', padding: '18px 22px', color: '#ffffff' }}>
          <div style={{ fontSize: '0.8rem', fontWeight: 600, color: 'rgba(255,255,255,0.75)', textTransform: 'uppercase', letterSpacing: 0.5 }}>
            Total Articles
          </div>
          <div style={{ fontSize: '2rem', fontWeight: 800, marginTop: 4 }}>
            {articles.length}
          </div>
          <div style={{ fontSize: '0.75rem', color: '#86efac', marginTop: 4 }}>
            Live in Firestore
          </div>
        </div>

        <div style={{ background: '#0b2b1b', borderRadius: '18px', padding: '18px 22px', color: '#ffffff' }}>
          <div style={{ fontSize: '0.8rem', fontWeight: 600, color: 'rgba(255,255,255,0.75)', textTransform: 'uppercase', letterSpacing: 0.5 }}>
            Active / Published
          </div>
          <div style={{ fontSize: '2rem', fontWeight: 800, marginTop: 4 }}>
            {articles.filter((a) => a.isActive).length}
          </div>
          <div style={{ fontSize: '0.75rem', color: 'rgba(255,255,255,0.75)', marginTop: 4 }}>
            Visible to passengers
          </div>
        </div>

        <div style={{ background: '#08281b', borderRadius: '18px', padding: '18px 22px', color: '#ffffff' }}>
          <div style={{ fontSize: '0.8rem', fontWeight: 600, color: 'rgba(255,255,255,0.75)', textTransform: 'uppercase', letterSpacing: 0.5 }}>
            Categories
          </div>
          <div style={{ fontSize: '2rem', fontWeight: 800, marginTop: 4 }}>
            {new Set(articles.map((a) => a.category)).size || CATEGORIES.length}
          </div>
          <div style={{ fontSize: '0.75rem', color: 'rgba(255,255,255,0.75)', marginTop: 4 }}>
            Topic tags
          </div>
        </div>
      </div>

      {/* Notifications */}
      {error && (
        <div style={{ background: 'rgba(239, 68, 68, 0.1)', color: '#ef4444', padding: '12px 18px', borderRadius: 9999, marginBottom: 18, border: '1px solid rgba(239, 68, 68, 0.25)', fontSize: '0.88rem', fontWeight: 600 }}>
          ⚠ {error}
        </div>
      )}
      {success && (
        <div style={{ background: 'rgba(16, 185, 129, 0.12)', color: '#10b981', padding: '12px 18px', borderRadius: 9999, marginBottom: 18, border: '1px solid rgba(16, 185, 129, 0.3)', fontSize: '0.88rem', fontWeight: 600 }}>
          ✓ {success}
        </div>
      )}

      {/* Main 2-Column Workspace: Form & Live Mobile Customer App Preview */}
      <div style={{ display: 'grid', gridTemplateColumns: 'minmax(0, 1.25fr) minmax(340px, 0.95fr)', gap: 'var(--space-5)', alignItems: 'start' }} className="foryou-layout">
        <style>{`
          @media (max-width: 1100px) {
            .foryou-layout {
              grid-template-columns: 1fr !important;
            }
          }
          .phone-frame {
            width: 325px;
            height: 660px;
            background: #ffffff;
            border-radius: 40px;
            border: 11px solid #1e293b;
            box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
            margin: 0 auto;
            position: relative;
            overflow: hidden;
            display: flex;
            flex-direction: column;
          }
          .phone-notch {
            width: 90px;
            height: 18px;
            background: #1e293b;
            position: absolute;
            top: 0;
            left: 50%;
            transform: translateX(-50%);
            border-bottom-left-radius: 12px;
            border-bottom-right-radius: 12px;
            z-index: 10;
          }
        `}</style>

        {/* ── Column 1: Article Editor & Published List ── */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 'var(--space-5)' }}>
          {/* Article Form Card */}
          <div className="card" style={{ padding: '24px', borderRadius: '22px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 18 }}>
              <h2 style={{ fontSize: '1.15rem', fontWeight: 800, margin: 0 }}>
                {editingId ? 'Edit Educational Article' : 'Create New Article'}
              </h2>
              {editingId && (
                <button
                  type="button"
                  onClick={handleResetForm}
                  style={{
                    padding: '6px 14px',
                    borderRadius: 9999,
                    border: '1px solid var(--color-border)',
                    background: 'transparent',
                    color: 'var(--color-text-muted)',
                    fontSize: '0.8rem',
                    fontWeight: 600,
                    cursor: 'pointer',
                  }}
                >
                  Cancel Edit
                </button>
              )}
            </div>

            <form onSubmit={handleSubmit} style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
              {/* Title input */}
              <div>
                <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 700, marginBottom: 6 }}>
                  Article Title *
                </label>
                <input
                  type="text"
                  placeholder="e.g. Ride Safety: Verifying Vehicle & PIN Code"
                  value={title}
                  onChange={(e) => setTitle(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '12px 18px',
                    borderRadius: 9999,
                    border: '1px solid var(--color-border)',
                    background: 'var(--color-bg-alt)',
                    fontSize: '0.9rem',
                    color: 'var(--color-text)',
                  }}
                  required
                />
              </div>

              {/* Category & Read Time Row */}
              <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 12 }}>
                <div>
                  <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 700, marginBottom: 6 }}>
                    Category
                  </label>
                  <select
                    value={category}
                    onChange={(e) => setCategory(e.target.value)}
                    style={{
                      width: '100%',
                      padding: '12px 16px',
                      borderRadius: 9999,
                      border: '1px solid var(--color-border)',
                      background: 'var(--color-bg-alt)',
                      fontSize: '0.88rem',
                      color: 'var(--color-text)',
                    }}
                  >
                    {CATEGORIES.map((c) => (
                      <option key={c} value={c}>
                        {c}
                      </option>
                    ))}
                  </select>
                </div>

                <div>
                  <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 700, marginBottom: 6 }}>
                    Estimated Read Time
                  </label>
                  <input
                    type="text"
                    value={readTime}
                    onChange={(e) => setReadTime(e.target.value)}
                    style={{
                      width: '100%',
                      padding: '12px 18px',
                      borderRadius: 9999,
                      border: '1px solid var(--color-border)',
                      background: 'var(--color-bg-alt)',
                      fontSize: '0.88rem',
                      color: 'var(--color-text)',
                    }}
                  />
                </div>
              </div>

              {/* Short description */}
              <div>
                <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 700, marginBottom: 6 }}>
                  Short Summary / Subtitle * (Shown on the home card)
                </label>
                <textarea
                  rows={2}
                  placeholder="A punchy 1-2 sentence overview of what riders will learn..."
                  value={shortDescription}
                  onChange={(e) => setShortDescription(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '12px 16px',
                    borderRadius: '16px',
                    border: '1px solid var(--color-border)',
                    background: 'var(--color-bg-alt)',
                    fontSize: '0.88rem',
                    color: 'var(--color-text)',
                    resize: 'vertical',
                  }}
                  required
                />
              </div>

              {/* Cover Image Upload & Direct URL */}
              <div>
                <label style={{ display: 'block', fontSize: '0.85rem', fontWeight: 700, marginBottom: 6 }}>
                  Cover Image (Upload or Paste URL)
                </label>
                <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
                  <input
                    type="file"
                    accept="image/*"
                    onChange={handleFileUpload}
                    id="foryou-file"
                    style={{ display: 'none' }}
                  />
                  <label
                    htmlFor="foryou-file"
                    style={{
                      padding: '10px 18px',
                      borderRadius: 9999,
                      background: '#10b981',
                      color: '#ffffff',
                      fontSize: '0.85rem',
                      fontWeight: 700,
                      cursor: uploadingImage ? 'not-allowed' : 'pointer',
                      whiteSpace: 'nowrap',
                    }}
                  >
                    {uploadingImage ? `Uploading ${uploadProgress}%...` : '📁 Select Cover Image'}
                  </label>
                  <input
                    type="url"
                    placeholder="Or paste direct image URL (https://...)"
                    value={coverImageUrl}
                    onChange={(e) => setCoverImageUrl(e.target.value)}
                    style={{
                      flex: 1,
                      padding: '10px 16px',
                      borderRadius: 9999,
                      border: '1px solid var(--color-border)',
                      background: 'var(--color-bg-alt)',
                      fontSize: '0.85rem',
                      color: 'var(--color-text)',
                    }}
                  />
                </div>
                {coverImageUrl && (
                  <div style={{ marginTop: 8, display: 'flex', alignItems: 'center', gap: 10 }}>
                    <img
                      src={coverImageUrl}
                      alt="Cover Preview"
                      style={{ width: 68, height: 42, objectFit: 'cover', borderRadius: 8, border: '1px solid var(--color-border)' }}
                    />
                    <span style={{ fontSize: '0.8rem', color: 'var(--color-text-muted)' }}>
                      Cover preview loaded
                    </span>
                  </div>
                )}
              </div>

              {/* Full Article Content */}
              <div>
                <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: 6 }}>
                  <label style={{ fontSize: '0.85rem', fontWeight: 700 }}>
                    Article Content / Markdown *
                  </label>
                  <span style={{ fontSize: '0.78rem', color: 'var(--color-text-muted)' }}>
                    Supports headers (`## Section`), bullet lists (`* Item`), and spacy paragraphs
                  </span>
                </div>
                <textarea
                  rows={8}
                  placeholder={`### Main Section Heading\n\nExplain your insights in clean, friendly language...\n\n### Key Takeaways:\n* Verify car details before onboarding\n* Keep the safety PIN private until the driver arrives\n* Contact 24/7 support if anything feels unexpected.`}
                  value={content}
                  onChange={(e) => setContent(e.target.value)}
                  style={{
                    width: '100%',
                    padding: '14px 16px',
                    borderRadius: '16px',
                    border: '1px solid var(--color-border)',
                    background: 'var(--color-bg-alt)',
                    fontSize: '0.88rem',
                    color: 'var(--color-text)',
                    fontFamily: 'inherit',
                    lineHeight: 1.5,
                  }}
                  required
                />
              </div>

              {/* Active Switch & Action Buttons */}
              <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginTop: 6 }}>
                <label style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: '0.88rem', fontWeight: 600, cursor: 'pointer' }}>
                  <input
                    type="checkbox"
                    checked={isActive}
                    onChange={(e) => setIsActive(e.target.checked)}
                    style={{ width: 18, height: 18, accentColor: '#10b981' }}
                  />
                  Publish immediately (Active)
                </label>

                <div style={{ display: 'flex', gap: 10 }}>
                  <button
                    type="button"
                    onClick={handleResetForm}
                    style={{
                      padding: '12px 20px',
                      borderRadius: 9999,
                      border: '1px solid var(--color-border)',
                      background: 'transparent',
                      color: 'var(--color-text)',
                      fontSize: '0.88rem',
                      fontWeight: 700,
                      cursor: 'pointer',
                    }}
                  >
                    Reset
                  </button>
                  <button
                    type="submit"
                    disabled={saving}
                    style={{
                      padding: '12px 28px',
                      borderRadius: 9999,
                      border: 'none',
                      background: '#10b981',
                      color: '#ffffff',
                      fontSize: '0.9rem',
                      fontWeight: 800,
                      cursor: saving ? 'not-allowed' : 'pointer',
                      boxShadow: 'none',
                    }}
                  >
                    {saving ? 'Saving...' : editingId ? 'Update Article' : 'Publish Article'}
                  </button>
                </div>
              </div>
            </form>
          </div>

          {/* Published Articles List Catalog */}
          <div className="card" style={{ padding: '24px', borderRadius: '22px' }}>
            <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: 16 }}>
              <div>
                <h3 style={{ fontSize: '1.1rem', fontWeight: 800, margin: 0 }}>
                  Published Articles ({filteredArticles.length})
                </h3>
                <span style={{ fontSize: '0.8rem', color: 'var(--color-text-muted)' }}>
                  Live articles currently in the Firestore database
                </span>
              </div>

              {/* Filter search */}
              <input
                type="text"
                placeholder="Search articles..."
                value={searchFilter}
                onChange={(e) => setSearchFilter(e.target.value)}
                style={{
                  padding: '8px 16px',
                  borderRadius: 9999,
                  border: '1px solid var(--color-border)',
                  background: 'var(--color-bg-alt)',
                  fontSize: '0.82rem',
                  color: 'var(--color-text)',
                  width: 180,
                }}
              />
            </div>

            {loading ? (
              <div style={{ textAlign: 'center', padding: 30, color: 'var(--color-text-muted)' }}>
                Loading articles from Firestore...
              </div>
            ) : filteredArticles.length === 0 ? (
              <div style={{ textAlign: 'center', padding: 30, color: 'var(--color-text-muted)', fontSize: '0.9rem' }}>
                No articles found matching your criteria.
              </div>
            ) : (
              <div style={{ display: 'flex', flexDirection: 'column', gap: 12 }}>
                {filteredArticles.map((article) => (
                  <div
                    key={article.id}
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      gap: 14,
                      padding: 14,
                      borderRadius: '16px',
                      border: '1px solid var(--color-border)',
                      background: editingId === article.id ? 'rgba(16, 185, 129, 0.08)' : 'var(--color-surface)',
                    }}
                  >
                    {/* Thumbnail */}
                    <div
                      style={{
                        width: 72,
                        height: 52,
                        borderRadius: 10,
                        background: '#f1f5f9',
                        overflow: 'hidden',
                        flexShrink: 0,
                        border: '1px solid var(--color-border)',
                      }}
                    >
                      {article.coverImageUrl ? (
                        <img
                          src={article.coverImageUrl}
                          alt={article.title}
                          style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                        />
                      ) : (
                        <div style={{ width: '100%', height: '100%', display: 'flex', alignItems: 'center', justifyContent: 'center', color: '#10b981', fontSize: 11, fontWeight: 700 }}>
                          No Img
                        </div>
                      )}
                    </div>

                    {/* Meta info */}
                    <div style={{ flex: 1, minWidth: 0 }}>
                      <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                        <span
                          style={{
                            fontSize: '0.72rem',
                            fontWeight: 800,
                            padding: '2px 8px',
                            borderRadius: 9999,
                            background: 'rgba(16, 185, 129, 0.14)',
                            color: '#059669',
                            textTransform: 'uppercase',
                          }}
                        >
                          {article.category}
                        </span>
                        <span
                          style={{
                            fontSize: '0.72rem',
                            fontWeight: 700,
                            padding: '2px 8px',
                            borderRadius: 9999,
                            background: article.isActive ? '#dcfce7' : '#fee2e2',
                            color: article.isActive ? '#15803d' : '#b91c1c',
                          }}
                        >
                          {article.isActive ? 'Active' : 'Draft'}
                        </span>
                        <span style={{ fontSize: '0.75rem', color: 'var(--color-text-muted)' }}>
                          • {article.readTime}
                        </span>
                      </div>
                      <div
                        style={{
                          fontWeight: 700,
                          fontSize: '0.92rem',
                          marginTop: 3,
                          overflow: 'hidden',
                          textOverflow: 'ellipsis',
                          whiteSpace: 'nowrap',
                        }}
                      >
                        {article.title}
                      </div>
                      <div
                        style={{
                          fontSize: '0.78rem',
                          color: 'var(--color-text-muted)',
                          overflow: 'hidden',
                          textOverflow: 'ellipsis',
                          whiteSpace: 'nowrap',
                        }}
                      >
                        {article.shortDescription}
                      </div>
                    </div>

                    {/* Actions */}
                    <div style={{ display: 'flex', gap: 6, flexShrink: 0 }}>
                      <button
                        type="button"
                        onClick={() => handleStartEdit(article)}
                        style={{
                          padding: '6px 14px',
                          borderRadius: 9999,
                          border: '1px solid var(--color-border)',
                          background: 'var(--color-bg-alt)',
                          fontSize: '0.8rem',
                          fontWeight: 700,
                          cursor: 'pointer',
                        }}
                      >
                        Edit
                      </button>
                      <button
                        type="button"
                        onClick={() => handleToggleActive(article)}
                        style={{
                          padding: '6px 12px',
                          borderRadius: 9999,
                          border: '1px solid var(--color-border)',
                          background: 'transparent',
                          fontSize: '0.8rem',
                          fontWeight: 600,
                          cursor: 'pointer',
                          color: article.isActive ? '#d97706' : '#10b981',
                        }}
                      >
                        {article.isActive ? 'Hide' : 'Show'}
                      </button>
                      <button
                        type="button"
                        onClick={() => handleDelete(article.id)}
                        style={{
                          padding: '6px 12px',
                          borderRadius: 9999,
                          border: 'none',
                          background: 'rgba(239, 68, 68, 0.1)',
                          color: '#ef4444',
                          fontSize: '0.8rem',
                          fontWeight: 700,
                          cursor: 'pointer',
                        }}
                      >
                        Delete
                      </button>
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </div>

        {/* ── Column 2: Live Mobile App Details Preview (Requested by User) ── */}
        <div style={{ position: 'sticky', top: 20 }}>
          <div style={{ marginBottom: 12, display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
            <h3 style={{ fontSize: '1.05rem', fontWeight: 800, margin: 0 }}>
              Live Customer App Details Preview
            </h3>
            <span style={{ fontSize: '0.75rem', fontWeight: 700, color: '#10b981', background: 'rgba(16, 185, 129, 0.12)', padding: '3px 10px', borderRadius: 9999 }}>
              ● Live Sync
            </span>
          </div>

          {/* Smartphone Simulator Frame */}
          <div className="phone-frame">
            <div className="phone-notch" />

            {/* Mobile Status Bar */}
            <div style={{ height: 28, display: 'flex', justifyContent: 'space-between', alignItems: 'center', padding: '0 20px', fontSize: 11, fontWeight: 700, color: '#0f172a', paddingTop: 4 }}>
              <span>9:41</span>
              <span>100% ⚡</span>
            </div>

            {/* Mobile App Bar */}
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '8px 16px', borderBottom: '1px solid #f1f5f9' }}>
              <div style={{ width: 34, height: 34, borderRadius: '50%', border: '1px solid #e2e8f0', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 14 }}>
                ‹
              </div>
              <div style={{ fontSize: 13, fontWeight: 700, color: '#0f172a' }}>
                For You
              </div>
              <div style={{ width: 34, height: 34, borderRadius: '50%', border: '1px solid #e2e8f0', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 13, color: '#94a3b8' }}>
                🔖
              </div>
            </div>

            {/* Mobile Article Reader Body */}
            <div style={{ flex: 1, overflowY: 'auto', padding: '16px', display: 'flex', flexDirection: 'column', gap: 12 }}>
              {/* Category badge + read time */}
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <span style={{ fontSize: 9.5, fontWeight: 800, color: '#10b981', background: 'rgba(16, 185, 129, 0.14)', padding: '2px 9px', borderRadius: 20, letterSpacing: 0.5, textTransform: 'uppercase' }}>
                  {category}
                </span>
                <span style={{ fontSize: 11, color: '#64748b', fontWeight: 500 }}>
                  • {readTime}
                </span>
              </div>

              {/* Title */}
              <div style={{ fontSize: 17, fontWeight: 800, color: '#0f172a', lineHeight: 1.25 }}>
                {title || 'Article Title Preview Goes Here'}
              </div>

              {/* Author & Date line */}
              <div style={{ display: 'flex', alignItems: 'center', gap: 6, fontSize: 11, color: '#64748b' }}>
                <div style={{ width: 18, height: 18, background: '#10b981', borderRadius: '50%', color: 'white', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 10, fontWeight: 900 }}>
                  C
                </div>
                <span>CaRide Editorial • Today</span>
              </div>

              {/* Cover Image Hero */}
              <div style={{ width: '100%', height: 140, borderRadius: 16, overflow: 'hidden', background: '#f8fafc', border: '1px solid #e2e8f0', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                {coverImageUrl ? (
                  <img
                    src={coverImageUrl}
                    alt="Cover"
                    style={{ width: '100%', height: '100%', objectFit: 'cover' }}
                  />
                ) : (
                  <div style={{ color: '#94a3b8', fontSize: 11, textAlign: 'center', padding: 10 }}>
                    [Cover Image Displayed Here]
                  </div>
                )}
              </div>

              {/* Short summary lead banner */}
              {shortDescription && (
                <div style={{ background: '#f0fdf4', border: '1px solid rgba(16, 185, 129, 0.3)', borderRadius: 12, padding: '10px 12px', fontSize: 12, color: '#166534', fontWeight: 600, lineHeight: 1.4 }}>
                  💡 {shortDescription}
                </div>
              )}

              {/* Content body formatted */}
              <div style={{ fontSize: 12.5, color: '#334155', lineHeight: 1.6, whiteSpace: 'pre-line' }}>
                {content || 'Your spacy, minimal, and highly readable article content will render here as passengers scroll down in the CaRide mobile app...'}
              </div>

              {/* Mobile Footer */}
              <div style={{ marginTop: 20, textAlign: 'center', padding: '14px 0', borderTop: '1px dashed #e2e8f0' }}>
                <span style={{ fontSize: 10, color: '#94a3b8', background: '#f8fafc', padding: '4px 12px', borderRadius: 999 }}>
                  CaRide Educational Community
                </span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
