import { useCallback, useMemo, useState, useEffect, type ReactNode } from 'react';
import { signInWithEmailAndPassword, onAuthStateChanged, signOut as firebaseSignOut } from 'firebase/auth';
import { auth } from '../config/firebase';
import { AuthContext } from './context';

export function AuthProvider({ children }: { children: ReactNode }) {
  const [isAuthenticated, setAuthenticated] = useState(false);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const unsubscribe = onAuthStateChanged(auth, (currentUser) => {
      setAuthenticated(!!currentUser);
      setLoading(false);
    });
    return () => unsubscribe();
  }, []);

  const signIn = useCallback(async (email: string, password: string) => {
    if (!email.trim()) throw new Error('Email required');
    if (!password.trim()) throw new Error('Password required');
    await signInWithEmailAndPassword(auth, email, password);
  }, []);

  const signOut = useCallback(async () => {
    await firebaseSignOut(auth);
  }, []);

  const value = useMemo(
    () => ({ isAuthenticated, signIn, signOut }),
    [isAuthenticated, signIn, signOut],
  );

  if (loading) {
    return <div style={{ display: 'flex', height: '100vh', alignItems: 'center', justifyContent: 'center' }}>Loading...</div>;
  }

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}
