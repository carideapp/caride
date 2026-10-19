import { useEffect, useState } from 'react';
import {
  collection,
  doc,
  onSnapshot,
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  addDoc,
  updateDoc,
  type Timestamp,
} from 'firebase/firestore';
import { auth, db } from '../config/firebase';
import { logStaffActivity } from '../utils/staffAuditLogger';

interface SupportChatRow {
  id: string;
  driverUid: string;
  driverName: string;
  driverEmail: string;
  subject: string;
  status: string;
  lastMessage: string;
  lastMessageAtMs: number;
  createdAtMs: number;
}

interface SupportMessageRow {
  id: string;
  senderRole: string;
  senderUid: string;
  text: string;
  imageUrl?: string;
  createdAtMs: number;
}

export function DriverSupportPage() {
  const [chats, setChats] = useState<SupportChatRow[]>([]);
  const [selectedChatId, setSelectedChatId] = useState<string | null>(null);
  const [messages, setMessages] = useState<SupportMessageRow[]>([]);
  const [messageText, setMessageText] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [pendingAction, setPendingAction] = useState(false);
  const [activeTab, setActiveTab] = useState<'active' | 'resolved' | 'all'>('active');

  const adminUid = auth.currentUser?.uid ?? '';

  useEffect(() => {
    const q = query(collection(db, 'supportChats'), orderBy('lastMessageAt', 'desc'));
    const unsub = onSnapshot(
      q,
      (snap) => {
        const rows = snap.docs
          .map((docSnap) => {
            const data = docSnap.data();
            const createdAt = data.createdAt as Timestamp | undefined;
            const lastMessageAt = data.lastMessageAt as Timestamp | undefined;
            const rawUserType = (data.userType as string)?.toLowerCase();
            const driverUid = (data.driverUid as string) || (data.userUid as string) || '';
            const isDriver = rawUserType === 'driver' || (rawUserType !== 'customer' && Boolean(data.driverUid));
            return {
              id: docSnap.id,
              driverUid,
              driverName: (data.driverName as string) || (data.userName as string) || 'Driver',
              driverEmail: (data.driverEmail as string) || (data.userEmail as string) || '',
              subject: (data.subject as string) || 'Driver Support',
              status: (data.status as string) || 'active',
              lastMessage: (data.lastMessage as string) || '',
              lastMessageAtMs: lastMessageAt?.toMillis?.() ?? 0,
              createdAtMs: createdAt?.toMillis?.() ?? 0,
              userType: isDriver ? 'driver' : 'customer',
            };
          })
          .filter((row) => row.userType === 'driver');
        setChats(rows);
        setSelectedChatId((prev) => {
          if (!prev && rows.length > 0) return rows[0].id;
          if (prev && !rows.some((row) => row.id === prev) && rows.length > 0) return rows[0].id;
          return prev;
        });
      },
      (e) => setError(e.message),
    );
    return () => unsub();
  }, []);

  useEffect(() => {
    if (!selectedChatId) {
      setMessages([]);
      return undefined;
    }
    const q = query(collection(db, 'supportChats', selectedChatId, 'messages'), orderBy('createdAt', 'asc'));
    const unsub = onSnapshot(
      q,
      (snap) => {
        setMessages(
          snap.docs.map((docSnap) => {
            const data = docSnap.data();
            const createdAt = data.createdAt as Timestamp | undefined;
            return {
              id: docSnap.id,
              senderRole: (data.senderRole as string) || 'driver',
              senderUid: (data.senderUid as string) || '',
              text: (data.text as string) || '',
              imageUrl: (data.imageUrl as string) || undefined,
              createdAtMs: createdAt?.toMillis?.() ?? Date.now(),
            };
          }),
        );
      },
      (e) => setError(e.message),
    );
    return () => unsub();
  }, [selectedChatId]);

  const selectedChat = chats.find((chat) => chat.id === selectedChatId) ?? null;

  const activeCount = chats.filter((c) => c.status !== 'resolved').length;
  const resolvedCount = chats.filter((c) => c.status === 'resolved').length;
  const allCount = chats.length;

  const displayedChats = chats.filter((c) => {
    if (activeTab === 'active') return c.status !== 'resolved';
    if (activeTab === 'resolved') return c.status === 'resolved';
    return true;
  });

  async function sendMessage() {
    if (!selectedChat || !adminUid || !messageText.trim()) return;
    setPendingAction(true);
    setError(null);
    try {
      const chatRef = doc(db, 'supportChats', selectedChat.id);
      await addDoc(collection(db, 'supportChats', selectedChat.id, 'messages'), {
        senderRole: 'admin',
        senderUid: adminUid,
        text: messageText.trim(),
        createdAt: serverTimestamp(),
      });
      await setDoc(
        chatRef,
        {
          status: 'active',
          lastMessage: messageText.trim(),
          lastMessageAt: serverTimestamp(),
          resolvedAt: null,
          resolvedByAdminUid: null,
        },
        { merge: true },
      );
      logStaffActivity({
        page: 'driver_support',
        actionType: 'Sent Support Message',
        description: `Replied to driver support chat (${selectedChat.driverName || selectedChat.driverEmail})`,
        targetId: selectedChat.id,
      });
      setMessageText('');
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Unable to send message.');
    } finally {
      setPendingAction(false);
    }
  }

  async function markResolved() {
    if (!selectedChat || !adminUid) return;
    setPendingAction(true);
    setError(null);
    try {
      await updateDoc(doc(db, 'supportChats', selectedChat.id), {
        status: 'resolved',
        resolvedAt: serverTimestamp(),
        resolvedByAdminUid: adminUid,
        lastMessageAt: serverTimestamp(),
      });
      logStaffActivity({
        page: 'driver_support',
        actionType: 'Resolved Support Ticket',
        description: `Marked driver support ticket as resolved (${selectedChat.driverName || selectedChat.driverEmail})`,
        targetId: selectedChat.id,
      });
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Unable to resolve conversation.');
    } finally {
      setPendingAction(false);
    }
  }

  return (
    <div>
      <div style={{ marginBottom: 'var(--space-4)' }}>
        <p className="muted" style={{ margin: 0 }}>
          Manage incoming support queries and live chats with registered drivers.
        </p>
      </div>

      {error && <p className="field__error" style={{ marginBottom: 'var(--space-3)' }}>{error}</p>}

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
              grid-template-columns: 320px minmax(0, 1fr) !important;
            }
          }
        `}</style>

        {/* Chat List Pane */}
        <div className="table-card" style={{ maxHeight: 'calc(100vh - 200px)', overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 'var(--space-3)', padding: 16 }}>
          <h3 style={{ margin: '4px 0 0 0', fontSize: '1rem', fontWeight: 800 }}>Driver Tickets</h3>
          
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

          {displayedChats.length === 0 ? (
            <div className="empty-state" style={{ padding: 'var(--space-4)' }}>
              <p className="muted">No {activeTab !== 'all' ? activeTab : ''} support chats found.</p>
            </div>
          ) : (
            <div style={{ display: 'flex', flexDirection: 'column', gap: 8 }}>
              {displayedChats.map((chat) => (
                <button
                  key={chat.id}
                  type="button"
                  onClick={() => setSelectedChatId(chat.id)}
                  style={{
                    width: '100%',
                    textAlign: 'left',
                    padding: '12px 14px',
                    borderRadius: '16px',
                    background: selectedChatId === chat.id ? 'var(--color-primary-light)' : 'transparent',
                    border: '1px solid',
                    borderColor: selectedChatId === chat.id ? 'var(--color-primary)' : 'var(--color-border)',
                    cursor: 'pointer',
                    color: 'var(--color-text)',
                    transition: 'all var(--transition-fast)'
                  }}
                >
                  <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', gap: 8 }}>
                    <strong style={{ fontSize: '0.875rem' }}>{chat.driverName}</strong>
                    <span className={`status-pill ${chat.status === 'resolved' ? 'status-pill--success' : 'status-pill--warning'}`} style={{ fontSize: '0.65rem', padding: '2px 8px' }}>
                      {chat.status}
                    </span>
                  </div>
                  <div style={{ fontSize: '0.8rem', fontWeight: 600, marginTop: 4, color: 'var(--color-text-muted)' }}>
                    {chat.subject}
                  </div>
                  <div className="muted" style={{ fontSize: '0.75rem', marginTop: 4, textOverflow: 'ellipsis', overflow: 'hidden', whiteSpace: 'nowrap' }}>
                    {chat.lastMessage || 'No messages'}
                  </div>
                </button>
              ))}
            </div>
          )}
        </div>

        {/* Chat Detail Pane */}
        <div className="table-card" style={{ minHeight: 'calc(100vh - 200px)', display: 'flex', flexDirection: 'column', padding: 'var(--space-5)' }}>
          {!selectedChat ? (
            <div className="empty-state" style={{ margin: 'auto' }}>
              <svg className="empty-state__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
              </svg>
              <h4 style={{ margin: 0 }}>Select a support chat</h4>
              <p className="muted" style={{ margin: 0, fontSize: '0.85rem' }}>Choose an conversation from the left rail to view message history.</p>
            </div>
          ) : (
            <>
              <div
                style={{
                  display: 'flex',
                  justifyContent: 'space-between',
                  gap: 'var(--space-3)',
                  flexWrap: 'wrap',
                  borderBottom: '1px solid var(--color-border)',
                  paddingBottom: 'var(--space-4)',
                  marginBottom: 'var(--space-4)',
                }}
              >
                <div>
                  <h3 style={{ marginTop: 0, marginBottom: 4, fontSize: '1.1rem', fontWeight: 800 }}>{selectedChat.subject}</h3>
                  <div className="muted" style={{ fontSize: '0.85rem' }}>
                    {selectedChat.driverName} · {selectedChat.driverEmail}
                  </div>
                </div>
                <div style={{ display: 'flex', gap: 'var(--space-2)', alignItems: 'center' }}>
                  <span className={`status-pill ${selectedChat.status === 'resolved' ? 'status-pill--success' : 'status-pill--warning'}`}>
                    {selectedChat.status}
                  </span>
                  {selectedChat.status !== 'resolved' && (
                    <button type="button" className="btn btn--ghost" style={{ padding: '6px 16px', fontSize: '0.8rem', borderRadius: 'var(--radius-full)' }} disabled={pendingAction} onClick={markResolved}>
                      Mark Resolved
                    </button>
                  )}
                </div>
              </div>

              {/* Chat messages list */}
              <div style={{ flex: 1, overflowY: 'auto', display: 'flex', flexDirection: 'column', gap: 12, paddingRight: 4 }}>
                {messages.length === 0 ? (
                  <p className="muted">No messages in this chat history.</p>
                ) : (
                  messages.map((message) => {
                    const isAdmin = message.senderRole === 'admin';
                    return (
                      <div
                        key={message.id}
                        style={{
                          maxWidth: '72%',
                          alignSelf: isAdmin ? 'flex-end' : 'flex-start',
                          background: isAdmin ? 'var(--color-primary-light)' : 'var(--color-bg-alt)',
                          border: '1px solid',
                          borderColor: isAdmin ? 'rgba(22, 163, 74, 0.3)' : 'var(--color-border)',
                          color: 'var(--color-text)',
                          padding: '12px 16px',
                          borderRadius: isAdmin ? '18px 18px 4px 18px' : '18px 18px 18px 4px',
                        }}
                      >
                        {message.imageUrl && (
                          <div style={{ marginBottom: message.text ? 8 : 0 }}>
                            <a href={message.imageUrl} target="_blank" rel="noopener noreferrer">
                              <img
                                src={message.imageUrl}
                                alt="Attachment"
                                style={{
                                  maxWidth: '100%',
                                  maxHeight: 260,
                                  borderRadius: 'var(--radius-md)',
                                  display: 'block',
                                  objectFit: 'cover',
                                  cursor: 'pointer',
                                  border: '1px solid var(--color-border)',
                                }}
                              />
                            </a>
                          </div>
                        )}
                        {message.text && (
                          <div style={{ fontSize: '0.875rem', wordBreak: 'break-word', lineHeight: 1.5 }}>{message.text}</div>
                        )}
                        <div style={{ fontSize: '0.7rem', color: 'var(--color-text-light)', marginTop: 4, textAlign: isAdmin ? 'right' : 'left' }}>
                          {message.createdAtMs ? new Date(message.createdAtMs).toLocaleTimeString('en-NG', { hour: '2-digit', minute: '2-digit' }) : 'Sending...'}
                        </div>
                      </div>
                    );
                  })
                )}
              </div>

              {selectedChat.status === 'resolved' ? (
                <div style={{ 
                  marginTop: 'var(--space-4)', 
                  background: 'var(--color-primary-light)', 
                  border: '1px solid var(--color-primary)', 
                  borderRadius: '16px',
                  padding: 'var(--space-3)', 
                  fontSize: '0.85rem',
                  fontWeight: 500,
                  color: 'var(--color-text)'
                }}>
                  <strong>Ticket Resolved</strong>
                  <p className="muted" style={{ margin: '4px 0 0 0', fontSize: '0.8rem' }}>
                    This query is closed. Composer is disabled unless the conversation is reopened.
                  </p>
                </div>
              ) : (
                <div style={{ marginTop: 'var(--space-4)', borderTop: '1px solid var(--color-border)', paddingTop: 'var(--space-4)' }}>
                  <div className="field">
                    <label htmlFor="replyText" style={{ display: 'none' }}>Reply composer</label>
                    <textarea
                      id="replyText"
                      rows={3}
                      placeholder="Write your response here..."
                      value={messageText}
                      onChange={(e) => setMessageText(e.target.value)}
                      style={{ borderRadius: '16px', padding: '12px 16px' }}
                    />
                  </div>
                  <div style={{ display: 'flex', justifyContent: 'flex-end', marginTop: 'var(--space-2)' }}>
                    <button 
                      type="button" 
                      className="btn btn--primary" 
                      style={{ borderRadius: 'var(--radius-full)', padding: '8px 24px' }}
                      disabled={pendingAction || !messageText.trim()} 
                      onClick={sendMessage}
                    >
                      Send Response
                    </button>
                  </div>
                </div>
              )}
            </>
          )}
        </div>
      </div>
    </div>
  );
}
