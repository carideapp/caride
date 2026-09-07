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
        <div className="card" style={{ maxHeight: 'calc(100vh - 200px)', overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 'var(--space-3)' }}>
          <h3 style={{ marginTop: 0, fontSize: '1rem', fontWeight: 800 }}>Fleet Support Tickets</h3>

          {/* Search Field */}
          <input
            type="text"
            className="input"
            placeholder="Search by manager name, email, or subject..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            style={{ fontSize: '0.85rem' }}
          />

          {/* Filter Tabs */}
          <div className="page-tabs" style={{ marginBottom: 'var(--space-2)' }}>
            <button
              type="button"
              className={`page-tab-btn ${activeTab === 'active' ? 'active' : ''}`}
              onClick={() => setActiveTab('active')}
            >
              Active <span className="tab-badge tab-badge--warn">{activeCount}</span>
            </button>
            <button
              type="button"
              className={`page-tab-btn ${activeTab === 'resolved' ? 'active' : ''}`}
              onClick={() => setActiveTab('resolved')}
            >
              Resolved <span className="tab-badge tab-badge--ok">{resolvedCount}</span>
            </button>
            <button
              type="button"
              className={`page-tab-btn ${activeTab === 'all' ? 'active' : ''}`}
              onClick={() => setActiveTab('all')}
            >
              All <span className="tab-badge">{allCount}</span>
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
                      borderRadius: 'var(--radius-md)',
                      border: isSelected ? '2px solid #16A34A' : '1fr border-color',
                      backgroundColor: isSelected ? 'rgba(22, 163, 74, 0.08)' : 'var(--bg-surface)',
                      cursor: 'pointer',
                      transition: 'all 0.15s ease',
                      display: 'flex',
                      flexDirection: 'column',
                      gap: 4,
                    }}
                  >
                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
                      <span style={{ fontSize: '0.85rem', fontWeight: 700, color: 'var(--text-color)' }}>
                        {t.userName}
                      </span>
                      <span
                        className={`tab-badge ${isResolved ? 'tab-badge--ok' : 'tab-badge--warn'}`}
                        style={{ fontSize: '0.7rem' }}
                      >
                        {isResolved ? 'Resolved' : 'Active'}
                      </span>
                    </div>

                    <span style={{ fontSize: '0.8rem', fontWeight: 600, color: 'var(--text-color)' }}>
                      {t.subject}
                    </span>

                    <span className="muted" style={{ fontSize: '0.75rem', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                      {t.lastMessage || 'Ticket created.'}
                    </span>

                    <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', fontSize: '0.7rem', color: 'var(--muted-color)', marginTop: 2 }}>
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
        <div className="card" style={{ display: 'flex', flexDirection: 'column', height: 'calc(100vh - 200px)', padding: 0, overflow: 'hidden' }}>
          {selectedTicket ? (
            <>
              {/* Header Bar */}
              <div
                style={{
                  padding: 'var(--space-4)',
                  borderBottom: '1px solid var(--border-color)',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'space-between',
                  backgroundColor: 'var(--bg-subtle, #f9fafb)',
                }}
              >
                <div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                    <h3 style={{ margin: 0, fontSize: '1.05rem', fontWeight: 800 }}>{selectedTicket.subject}</h3>
                    <span className={`tab-badge ${selectedTicket.status === 'closed' || selectedTicket.status === 'resolved' ? 'tab-badge--ok' : 'tab-badge--warn'}`}>
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
                  className={selectedTicket.status === 'closed' || selectedTicket.status === 'resolved' ? 'btn-primary' : 'btn-secondary'}
                  style={{ fontSize: '0.8rem', padding: '6px 14px' }}
                >
                  {selectedTicket.status === 'closed' || selectedTicket.status === 'resolved' ? 'Reopen Ticket' : 'Mark as Resolved'}
                </button>
              </div>

              {/* Conversation Messages Log */}
              <div
                style={{
                  flex: 1,
                  padding: 'var(--space-4)',
                  overflowY: 'auto',
                  display: 'flex',
                  flexDirection: 'column',
                  gap: 'var(--space-3)',
                  backgroundColor: '#ffffff',
                }}
              >
                {messages.length === 0 ? (
                  <div className="empty-state" style={{ padding: 'var(--space-4)' }}>
                    <p className="muted">No messages in this support conversation yet.</p>
                  </div>
                ) : (
                  messages.map((m) => {
                    const isAdminMsg = m.senderRole === 'admin';

                    return (
                      <div
                        key={m.id}
                        style={{
                          display: 'flex',
                          flexDirection: 'column',
                          alignItems: isAdminMsg ? 'flex-end' : 'flex-start',
                        }}
                      >
                        <div style={{ fontSize: '0.7rem', color: 'var(--muted-color)', marginBottom: 4 }}>
                          <strong>{isAdminMsg ? 'CaRide Admin' : selectedTicket.userName}</strong> •{' '}
                          {m.createdAtMs > 0 ? new Date(m.createdAtMs).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }) : ''}
                        </div>

                        <div
                          style={{
                            maxWidth: '75%',
                            padding: '10px 14px',
                            borderRadius: '16px',
                            fontSize: '0.88rem',
                            lineHeight: 1.4,
                            backgroundColor: isAdminMsg ? '#16A34A' : '#F3F4F6',
                            color: isAdminMsg ? '#ffffff' : '#111827',
                            borderBottomRightRadius: isAdminMsg ? '2px' : '16px',
                            borderBottomLeftRadius: isAdminMsg ? '16px' : '2px',
                          }}
                        >
                          {m.imageUrl && (
                            <img
                              src={m.imageUrl}
                              alt="Attachment"
                              onClick={() => setPreviewImage(m.imageUrl!)}
                              style={{
                                maxHeight: 180,
                                width: '100%',
                                objectFit: 'cover',
                                borderRadius: 10,
                                marginBottom: 8,
                                cursor: 'pointer',
                              }}
                            />
                          )}
                          <div style={{ whiteSpace: 'pre-wrap' }}>{m.text}</div>
                        </div>
                      </div>
                    );
                  })
                )}
              </div>

              {/* Reply Form */}
              {selectedTicket.status === 'closed' || selectedTicket.status === 'resolved' ? (
                <div style={{ padding: 'var(--space-3)', textAlign: 'center', backgroundColor: '#F9FAFB', borderTop: '1px solid var(--border-color)', fontSize: '0.8rem', color: 'var(--muted-color)' }}>
                  This support ticket is currently marked as resolved.{' '}
                  <button type="button" onClick={handleToggleStatus} style={{ background: 'none', border: 'none', color: '#16A34A', fontWeight: 700, cursor: 'pointer', textDecoration: 'underline' }}>
                    Reopen Ticket
                  </button>
                </div>
              ) : (
                <form
                  onSubmit={handleSendMessage}
                  style={{
                    padding: 'var(--space-3)',
                    borderTop: '1px solid var(--border-color)',
                    display: 'flex',
                    gap: 10,
                    backgroundColor: '#ffffff',
                  }}
                >
                  <input
                    type="text"
                    className="input"
                    placeholder="Type official admin response..."
                    value={messageText}
                    onChange={(e) => setMessageText(e.target.value)}
                    style={{ flex: 1, fontSize: '0.88rem' }}
                  />
                  <button
                    type="submit"
                    className="btn-primary"
                    disabled={pendingAction || !messageText.trim()}
                    style={{ padding: '8px 20px', fontSize: '0.85rem' }}
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
