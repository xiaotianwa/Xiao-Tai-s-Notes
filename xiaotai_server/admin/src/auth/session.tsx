import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
} from 'react';

import type { AuthTokens, AuthUser } from '../api/types';
import {
  adminSessionExpiredEvent,
  clearAdminSession,
  getStoredAdminUser,
  storeAdminSession,
} from './storage';

interface SessionState {
  session: AuthUser | null;
  signIn(tokens: AuthTokens): void;
  signOut(): void;
}

const SessionContext = createContext<SessionState | null>(null);

export function SessionProvider({
  children,
}: {
  children: React.ReactNode;
}): React.JSX.Element {
  const [session, setSession] = useState<AuthUser | null>(() => {
    return getStoredAdminUser();
  });

  const signIn = useCallback((tokens: AuthTokens): void => {
    storeAdminSession(tokens);
    setSession(tokens.user);
  }, []);

  const signOut = useCallback((): void => {
    clearAdminSession();
    setSession(null);
  }, []);

  useEffect(() => {
    const handleSessionExpired = (): void => {
      setSession(null);
    };
    window.addEventListener(adminSessionExpiredEvent, handleSessionExpired);
    return () => {
      window.removeEventListener(
        adminSessionExpiredEvent,
        handleSessionExpired,
      );
    };
  }, []);

  const value = useMemo(
    () => ({ session, signIn, signOut }),
    [session, signIn, signOut],
  );

  return (
    <SessionContext.Provider value={value}>{children}</SessionContext.Provider>
  );
}

export function useSession(): SessionState {
  const context = useContext(SessionContext);
  if (!context) {
    throw new Error('useSession must be used within SessionProvider');
  }
  return context;
}
