import type { AuthUser } from '../api/types';

const accessTokenKey = 'xiaotai_admin_access_token';
const refreshTokenKey = 'xiaotai_admin_refresh_token';
const userKey = 'xiaotai_admin_user';

export const adminSessionExpiredEvent = 'xiaotai-admin-session-expired';

export function getAdminAccessToken(): string | null {
  return sessionStorage.getItem(accessTokenKey);
}

export function getStoredAdminUser(): AuthUser | null {
  const raw = sessionStorage.getItem(userKey);
  if (!raw) {
    return null;
  }
  try {
    return JSON.parse(raw) as AuthUser;
  } catch {
    clearAdminSession();
    return null;
  }
}

export function storeAdminSession({
  accessToken,
  refreshToken,
  user,
}: {
  accessToken: string;
  refreshToken: string;
  user: AuthUser;
}): void {
  sessionStorage.setItem(accessTokenKey, accessToken);
  sessionStorage.setItem(refreshTokenKey, refreshToken);
  sessionStorage.setItem(userKey, JSON.stringify(user));
}

export function clearAdminSession(): void {
  sessionStorage.removeItem(accessTokenKey);
  sessionStorage.removeItem(refreshTokenKey);
  sessionStorage.removeItem(userKey);
}

export function notifyAdminSessionExpired(): void {
  clearAdminSession();
  window.dispatchEvent(new Event(adminSessionExpiredEvent));
}
