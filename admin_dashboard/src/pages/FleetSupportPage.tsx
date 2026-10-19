import React, { useEffect, useState } from 'react';
import {
  collection,
  doc,
  onSnapshot,
  addDoc,
  updateDoc,
  type Timestamp,
} from 'firebase/firestore';
import { auth, db } from '../config/firebase';
import { logStaffActivity } from '../utils/staffAuditLogger';

interface SupportTicketRow {
  id: string;
  userId: string;
  userName: string;
  userEmail: string;
  userType: string;
  subject: string;
  status: string;
  lastMessage: string;
  lastMessageAtMs: number;
  createdAtMs: number;
}

interface SupportMessageRow {
  id: string;
  senderRole: string;
  senderName: string;
  senderUid: string;
  text: string;
  imageUrl?: string;
  createdAtMs: number;
}

export function FleetSupportPage() {
  const [tickets, setTickets] = useState<SupportTicketRow[]>([]);
  const [selectedTicketId, setSelectedTicketId] = useState<string | null>(null);
  const [messages, setMessages] = useState<SupportMessageRow[]>([]);
  const [messageText, setMessageText] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [pendingAction, setPendingAction] = useState(false);
  const [activeTab, setActiveTab] = useState<'active' | 'resolved' | 'all'>('active');
  const [searchQuery, setSearchQuery] = useState('');
  const [previewImage, setPreviewImage] = useState<string | null>(null);

  const adminUid = auth.currentUser?.uid ?? '';
  const adminName = auth.currentUser?.displayName || 'CaRide Admin';

  // 1. Fetch Fleet Support Tickets in Realtime
  useEffect(() => {
    const unsub = onSnapshot(
      collection(db, 'support_tickets'),
      (snap) => {
        const rows: SupportTicketRow[] = snap.docs.map((docSnap) => {
          const data = docSnap.data();
          const createdAt = data.createdAt as Timestamp | undefined;
          const lastMessageAt = data.lastMessageAt as Timestamp | undefined;
          const timeMs =
            (data.lastMessageAtMs as number) ||
            (data.updatedAtMs as number) ||
            (data.createdAtMs as number) ||
            lastMessageAt?.toMillis?.() ||
            createdAt?.toMillis?.() ||
            0;

          return {
            id: docSnap.id,
            userId: (data.userId as string) || (data.userUid as string) || '',
            userName: (data.userName as string) || (data.fleetName as string) || 'Fleet Manager',
            userEmail: (data.userEmail as string) || '',
            userType: (data.userType as string) || 'fleet',
            subject: (data.subject as string) || (data.heading as string) || 'Fleet Support Inquiry',
            status: (data.status as string) || 'open',
            lastMessage: (data.lastMessage as string) || '',
            lastMessageAtMs: timeMs,
            createdAtMs: (data.createdAtMs as number) || createdAt?.toMillis?.() || timeMs,
          };
        });

        // Filter for Fleet support tickets & sort descending by last message time
        const fleetRows = rows.filter((row) => row.userType === 'fleet' || !row.userType);
        fleetRows.sort((a, b) => b.lastMessageAtMs - a.lastMessageAtMs);

        setTickets(fleetRows);

        setSelectedTicketId((prev) => {
          if (!prev && fleetRows.length > 0) return fleetRows[0].id;
          if (prev && !fleetRows.some((r) => r.id === prev) && fleetRows.length > 0) return fleetRows[0].id;
          return prev;
        });
      },
      (e) => {
        console.warn('Fleet support_tickets listener warning:', e);
        setError('Unable to load support tickets. Check Firestore connection.');
      }
    );
    return () => unsub();
  }, []);

  // 2. Fetch Messages for Selected Support Ticket
  useEffect(() => {
    if (!selectedTicketId) {
      setMessages([]);
      return undefined;
    }
    const unsub = onSnapshot(
      collection(db, 'support_tickets', selectedTicketId, 'messages'),
      (snap) => {
        const rows: SupportMessageRow[] = snap.docs.map((docSnap) => {
          const data = docSnap.data();
          const createdAt = data.createdAt as Timestamp | undefined;
          return {
            id: docSnap.id,
            senderRole: (data.senderRole as string) || 'fleet',
            senderName: (data.senderName as string) || 'User',
            senderUid: (data.senderUid as string) || '',
            text: (data.text as string) || '',
            imageUrl: (data.imageUrl as string) || undefined,
            createdAtMs: (data.createdAtMs as number) || createdAt?.toMillis?.() || Date.now(),
          };
        });
        rows.sort((a, b) => a.createdAtMs - b.createdAtMs);
        setMessages(rows);
      },
      (e) => setError(e.message)
    );
    return () => unsub();
  }, [selectedTicketId]);

  const selectedTicket = tickets.find((t) => t.id === selectedTicketId) ?? null;

  const activeCount = tickets.filter((t) => t.status !== 'closed' && t.status !== 'resolved').length;
  const resolvedCount = tickets.filter((t) => t.status === 'closed' || t.status === 'resolved').length;
  const allCount = tickets.length;

  const displayedTickets = tickets.filter((t) => {
    const isClosed = t.status === 'closed' || t.status === 'resolved';
    const matchesTab =
      activeTab === 'all' ? true : activeTab === 'resolved' ? isClosed : !isClosed;

    const matchesSearch =
      searchQuery === '' ||
      t.subject.toLowerCase().includes(searchQuery.toLowerCase()) ||
      t.userName.toLowerCase().includes(searchQuery.toLowerCase()) ||
      t.userEmail.toLowerCase().includes(searchQuery.toLowerCase());

    return matchesTab && matchesSearch;
  });

  // 3. Admin Send Reply Handler
  const handleSendMessage = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!selectedTicketId || !selectedTicket || !messageText.trim()) return;

    setPendingAction(true);
    setError(null);
    const textToSend = messageText.trim();
    const nowMs = Date.now();

    try {
      await addDoc(collection(db, 'support_tickets', selectedTicketId, 'messages'), {
        senderRole: 'admin',
        senderName: adminName,
        senderUid: adminUid,
        text: textToSend,
        createdAtMs: nowMs,
        createdAt: new Date(),
      });

      await updateDoc(doc(db, 'support_tickets', selectedTicketId), {
        lastMessage: textToSend,
        lastMessageAtMs: nowMs,
        updatedAtMs: nowMs,
        status: 'open',
      });

      logStaffActivity({
        page: 'customer_support',
        actionType: 'Sent Support Message',
        description: `Replied to fleet support ticket (${selectedTicket.userName || selectedTicket.userEmail})`,
        targetId: selectedTicket.id,
      });

      setMessageText('');
    } catch (err: any) {
      setError(err.message || 'Failed to send admin reply.');
    } finally {
      setPendingAction(false);
    }
  };

  // 4. Toggle Status (Resolve / Reopen Ticket)
  const handleToggleStatus = async () => {
    if (!selectedTicketId || !selectedTicket) return;
    setPendingAction(true);
    setError(null);
    const isClosed = selectedTicket.status === 'closed' || selectedTicket.status === 'resolved';
    const newStatus = isClosed ? 'open' : 'resolved';
    try {
      await updateDoc(doc(db, 'support_tickets', selectedTicketId), {
        status: newStatus,
        updatedAtMs: Date.now(),
      });

      logStaffActivity({
        page: 'customer_support',
        actionType: isClosed ? 'Reopened Support Ticket' : 'Resolved Support Ticket',
        description: `Updated fleet support ticket status to ${newStatus} (${selectedTicket.userName || selectedTicket.userEmail})`,
        targetId: selectedTicket.id,
      });
    } catch (err: any) {
      setError(err.message || 'Failed to update ticket status.');
    } finally {
      setPendingAction(false);
    }
  };

  return (
    <div>
      {/* Header Info */}
      <div style={{ marginBottom: 'var(--space-4)' }}>
        <p className="muted" style={{ margin: 0 }}>
          Manage incoming support queries, technical issues, and live chats with Fleet Partners and vehicle managers.
        </p>
      </div>

      {error && <p className="field__error" style={{ marginBottom: 'var(--space-3)' }}>{error}</p>}

      {/* Grid Layout matching Admin Dashboard design tokens */}
      <div
        style={{
          display: 'grid',
          gridTemplateColumns: '1fr',
          gap: 'var(--space-5)',
          alignItems: 'stretch',
        }}
        className="support-layout"
      >
        <style>{`
          .support-layout {
            grid-template-columns: 1fr;
          }
          @media (min-width: 900px) {
            .support-layout {
              grid-template-columns: 340px minmax(0, 1fr) !important;
            }
          }
        `}</style>

        {/* Left Pane: Ticket List & Search */}
        <div className="table-card" style={{ maxHeight: 'calc(100vh - 200px)', overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 'var(--space-3)', padding: 16 }}>
          <h3 style={{ margin: '4px 0 0 0', fontSize: '1rem', fontWeight: 800 }}>Fleet Support Tickets</h3>

          {/* Search Field */}
          <div className="search-pill-wrap" style={{ width: '100%' }}>
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
              <circle cx="11" cy="11" r="8" /><line x1="21" y1="21" x2="16.65" y2="16.65" />
            </svg>
            <input
              type="text"
              placeholder="Search manager, email, subject..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              style={{ width: '100%' }}
            />
          </div>

          {/* Filter Tabs */}
          <div className="tab-bar-underline" style={{ marginBottom: 8, gap: 4 }}>
            <button
              type="button"
              className={`tab-btn-underline ${activeTab === 'active' ? 'active' : ''}`}
              style={{ padding: '8px 12px', fontSize: '0.85rem' }}
              onClick={() => setActiveTab('active')}
            >
              Active <span className="tab-count-badge">{activeCount}</span>
            </button>
            <button
              type="button"
              className={`tab-btn-underline ${activeTab === 'resolved' ? 'active' : ''}`}
              style={{ padding: '8px 12px', fontSize: '0.85rem' }}
              onClick={() => setActiveTab('resolved')}
            >
              Resolved <span className="tab-count-badge">{resolvedCount}</span>
            </button>
            <button
              type="button"
              className={`tab-btn-underline ${activeTab === 'all' ? 'active' : ''}`}
              style={{ padding: '8px 12px', fontSize: '0.85rem' }}
              onClick={() => setActiveTab('all')}
            >
              All <span className="tab-count-badge">{allCount}</span>
            </button>
          </div>

          {/* Tickets List */}
          {displayedTickets.length === 0 ? (
            <div className="empty-state" style={{ padding: 'var(--space-4)' }}>
              <p className="muted">No {activeTab !== 'all' ? activeTab : ''} fleet support tickets found.</p>
            </div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              {displayedTickets.map((t) => {
                const isSelected = t.id === selectedTicketId;
                const isResolved = t.status === 'closed' || t.status === 'resolved';

                return (
                  <button
                    key={t.id}
                    type="button"
                    onClick={() => setSelectedTicketId(t.id)}
                    style={{
                      width: '100%',
                      textAlign: 'left',
                      padding: '12px 14px',
                      borderRadius: '16px',
                      border: '1px solid',
                      borderColor: isSelected ? 'var(--color-primary)' : 'var(--color-border)',
                      backgroundColor: isSelected ? 'var(--color-primary-light)' : 'transparent',
                      cursor: 'pointer',
                      transition: 'all 0.15s ease',
                      display: 'flex',
                      flexDirection: 'column',
                      gap: 4,
                    }}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                      <span style={{ fontSize: '0.85rem', fontWeight: 700, color: 'var(--color-text)' }}>
                        {t.userName}
                      </span>
                      <span
                        className={`status-pill ${isResolved ? 'status-pill--success' : 'status-pill--warning'}`}
                        style={{ fontSize: '0.65rem', padding: '2px 8px' }}
                      >
                        {isResolved ? 'Resolved' : 'Active'}
                      </span>
                    </div>

                    <span style={{ fontSize: '0.8rem', fontWeight: 600, color: 'var(--color-text-muted)' }}>
                      {t.subject}
                    </span>

                    <span className="muted" style={{ fontSize: '0.75rem', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                      {t.lastMessage || 'Ticket created.'}
                    </span>

                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', fontSize: '0.7rem', color: 'var(--color-text-light)', marginTop: 2 }}>
                      <span style={{ overflow: 'hidden', textOverflow: 'ellipsis', maxWidth: '180px' }}>{t.userEmail}</span>
                      <span>
                        {t.lastMessageAtMs > 0
                          ? new Date(t.lastMessageAtMs).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
                          : ''}
                      </span>
                    </div>
                  </button>
                );
              })}
            </div>
          )}
        </div>

        {/* Right Pane: Active Ticket Conversation Console */}
        <div className="table-card" style={{ display: 'flex', flexDirection: 'column', height: 'calc(100vh - 200px)', padding: 0, overflow: 'hidden' }}>
          {selectedTicket ? (
            <>
              {/* Header Bar */}
              <div
                style={{
                  padding: '16px 20px',
                  borderBottom: '1px solid var(--color-border)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  backgroundColor: 'var(--color-bg-alt)',
                }}
              >
                <div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <h3 style={{ margin: 0, fontSize: '1.05rem', fontWeight: 800 }}>{selectedTicket.subject}</h3>
                    <span className={`status-pill ${selectedTicket.status === 'closed' || selectedTicket.status === 'resolved' ? 'status-pill--success' : 'status-pill--warning'}`}>
                      {selectedTicket.status === 'closed' || selectedTicket.status === 'resolved' ? 'Resolved' : 'Active'}
                    </span>
                  </div>
                  <p className="muted" style={{ margin: '4px 0 0 0', fontSize: '0.8rem' }}>
                    Manager: <strong>{selectedTicket.userName}</strong> ({selectedTicket.userEmail || 'No email registered'})
                  </p>
                </div>

                <button
                  type="button"
                  onClick={handleToggleStatus}
                  disabled={pendingAction}
                  className={selectedTicket.status === 'closed' || selectedTicket.status === 'resolved' ? 'btn btn--primary' : 'btn btn--ghost'}
                  style={{ fontSize: '0.8rem', padding: '6px 16px', borderRadius: 'var(--radius-full)' }}
                >
                  {selectedTicket.status === 'closed' || selectedTicket.status === 'resolved' ? 'Reopen Ticket' : 'Mark as Resolved'}
                </button>
              </div>

              {/* Chat Message List */}
              <div
                style={{
                  flex: 1,
                  padding: '20px',
                  overflowY: 'auto',
                  display: 'flex',
                  flexDirection: 'column',
                  gap: 12,
                }}
              >
                {messages.length === 0 ? (
                  <div className="empty-state" style={{ margin: 'auto' }}>
                    <p className="muted" style={{ fontSize: '0.85rem' }}>No messages yet. Send an opening response below.</p>
                  </div>
                ) : (
                  messages.map((m) => {
                    const isAdmin = m.senderRole === 'admin';
                    return (
                      <div
                        key={m.id}
                        style={{
                          display: 'flex',
                          flexDirection: 'column',
                          alignItems: isAdmin ? 'flex-end' : 'flex-start',
                          maxWidth: '72%',
                          alignSelf: isAdmin ? 'flex-end' : 'flex-start',
                        }}
                      >
                        <span style={{ fontSize: '0.7rem', color: 'var(--color-text-light)', marginBottom: 2 }}>
                          {isAdmin ? '🛡️ Admin Support' : `👔 ${m.senderName || selectedTicket.userName}`}
                        </span>

                        <div
                          style={{
                            padding: '12px 16px',
                            borderRadius: isAdmin ? '18px 18px 4px 18px' : '18px 18px 18px 4px',
                            backgroundColor: isAdmin ? 'var(--color-primary-light)' : 'var(--color-bg-alt)',
                            border: '1px solid',
                            borderColor: isAdmin ? 'rgba(22, 163, 74, 0.3)' : 'var(--color-border)',
                            color: 'var(--color-text)',
                            fontSize: '0.875rem',
                            lineHeight: 1.5,
                            wordBreak: 'break-word',
                          }}
                        >
                          {m.text}
                          {m.imageUrl && (
                            <div style={{ marginTop: 8 }}>
                              <img
                                src={m.imageUrl}
                                alt="Attachment"
                                style={{ maxWidth: '100%', maxHeight: 220, borderRadius: 8, cursor: 'pointer', display: 'block', border: '1px solid var(--color-border)' }}
                                onClick={() => setPreviewImage(m.imageUrl || null)}
                              />
                            </div>
                          )}
                        </div>

                        <span style={{ fontSize: '0.65rem', color: 'var(--color-text-light)', marginTop: 2 }}>
                          {m.createdAtMs > 0 ? new Date(m.createdAtMs).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : ''}
                        </span>
                      </div>
                    );
                  })
                )}
              </div>

              {/* Composer / Resolved Notice */}
              {selectedTicket.status === 'closed' || selectedTicket.status === 'resolved' ? (
                <div
                  style={{
                    padding: '16px',
                    borderTop: '1px solid var(--color-border)',
                    backgroundColor: 'var(--color-bg-alt)',
                    textAlign: 'center',
                    fontSize: '0.85rem',
                    color: 'var(--color-text-muted)',
                  }}
                >
                  ✓ Ticket marked as resolved. Click "Reopen Ticket" to resume conversation.
                </div>
              ) : (
                <form
                  onSubmit={handleSendMessage}
                  style={{
                    padding: '16px 20px',
                    borderTop: '1px solid var(--color-border)',
                    display: 'flex',
                    gap: 12,
                    alignItems: 'center',
                  }}
                >
                  <input
                    type="text"
                    placeholder="Type official admin response..."
                    value={messageText}
                    onChange={(e) => setMessageText(e.target.value)}
                    style={{ 
                      flex: 1, 
                      fontSize: '0.88rem', 
                      borderRadius: 'var(--radius-full)', 
                      padding: '12px 20px',
                      border: '1px solid var(--color-border)',
                      background: 'var(--color-bg-alt)',
                      color: 'var(--color-text)',
                      outline: 'none',
                    }}
                  />
                  <button
                    type="submit"
                    className="btn btn--primary"
                    disabled={pendingAction || !messageText.trim()}
                    style={{ padding: '10px 24px', fontSize: '0.85rem', borderRadius: 'var(--radius-full)' }}
                  >
                    Send Reply
                  </button>
                </form>
              )}
            </>
          ) : (
            <div className="empty-state" style={{ height: '100%', display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center' }}>
              <p className="muted" style={{ fontSize: '0.9rem', fontWeight: 600 }}>No Support Ticket Selected</p>
              <p className="muted" style={{ fontSize: '0.8rem' }}>Select a ticket from the left panel to read and reply.</p>
            </div>
          )}
        </div>
      </div>

      {/* Image Lightbox Modal */}
      {previewImage && (
        <div
          style={{
            position: 'fixed',
            inset: 0,
            zIndex: 999,
            backgroundColor: 'rgba(0,0,0,0.8)',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'center',
            padding: 20,
          }}
          onClick={() => setPreviewImage(null)}
        >
          <div style={{ position: 'relative', maxWidth: '80%', maxHeight: '80vh' }}>
            <img src={previewImage} alt="Attachment Preview" style={{ maxWidth: '100%', maxHeight: '80vh', borderRadius: 12, objectFit: 'contain' }} />
            <button
              type="button"
              onClick={() => setPreviewImage(null)}
              style={{
                position: 'absolute',
                top: 10,
                right: 10,
                backgroundColor: 'rgba(0,0,0,0.6)',
                color: '#fff',
                border: 'none',
                borderRadius: '50%',
                width: 32,
                height: 32,
                cursor: 'pointer',
              }}
            >
              ✕
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
