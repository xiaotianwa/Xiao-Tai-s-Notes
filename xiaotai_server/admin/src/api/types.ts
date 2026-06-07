export interface ApiErrorDetail {
  field?: string;
  reason: string;
}

export interface ApiEnvelope<T> {
  code: number;
  data: T;
  message: string;
  details?: ApiErrorDetail[];
  requestId?: string;
}

export interface AuthUser {
  id: string;
  username: string;
  nickname: string;
  role: string;
  status: string;
}

export interface AuthTokens {
  accessToken: string;
  refreshToken: string;
  user: AuthUser;
}

export interface PageResult<T> {
  items: T[];
  total: number;
  page: number;
  pageSize: number;
}

export interface AdminUser extends AuthUser {
  createdAt: string;
  updatedAt: string;
  syncItemCount?: number;
}

export interface AdminDevice {
  id: string;
  deviceName: string;
  platform: string;
  appVersionName?: string | null;
  appVersionCode?: number | null;
  lastSeenAt: string | null;
  createdAt?: string;
  user?: AdminUser;
}

export interface AdminAuditLog {
  id: string;
  action: string;
  targetType: string | null;
  targetId: string | null;
  ip?: string | null;
  userAgent?: string | null;
  metadata?: unknown;
  createdAt: string;
  actor: AdminUser;
}

export interface AdminSyncTypeStat {
  type: string;
  activeCount: number;
  deletedCount: number;
  latestServerUpdatedAt: string | null;
}

export interface AdminUserDetail extends AdminUser {
  devices: AdminDevice[];
  syncItemCount: number;
  deletedSyncItemCount: number;
  mediaAssetCount: number;
  latestSyncAt: string | null;
  latestMediaUploadedAt: string | null;
  syncTypeStats: AdminSyncTypeStat[];
  latestItems: AdminSyncItem[];
  recentDeletedItems: AdminSyncItem[];
  recentAuditLogs: AdminAuditLog[];
}

export type SyncHealthStatus =
  | "healthy"
  | "warning"
  | "critical"
  | "no_data"
  | "disabled";

export interface AdminSyncHealthUser {
  user: AdminUser;
  status: SyncHealthStatus;
  statusLabel: string;
  statusReason: string;
  deviceCount: number;
  syncItemCount: number;
  activeSyncItemCount: number;
  deletedSyncItemCount: number;
  todaySyncCount: number;
  mediaAssetCount: number;
  latestSyncAt: string | null;
  latestDeviceSeenAt: string | null;
  latestActivityAt: string | null;
  latestMediaUploadedAt: string | null;
  latestDevice: AdminDevice | null;
}

export interface AdminSyncHealthSummary {
  totalUsers: number;
  activeUsers: number;
  healthyUsers: number;
  warningUsers: number;
  criticalUsers: number;
  noDataUsers: number;
  disabledUsers: number;
  totalDevices: number;
  totalSyncItems: number;
  deletedSyncItems: number;
  todaySyncCount: number;
  latestActivityAt: string | null;
}

export interface AdminSyncHealthData
  extends PageResult<AdminSyncHealthUser> {
  summary: AdminSyncHealthSummary;
}

export interface DashboardData {
  userCount: number;
  syncItemCount: number;
  memoCount: number;
  reminderCount: number;
  mediaCount: number;
  todaySyncCount: number;
  latestDevices: Array<AdminDevice & { user: AdminUser }>;
  recentAuditLogs: AdminAuditLog[];
}

export interface AdminSyncItem {
  id: string;
  userId: string;
  username: string;
  nickname: string;
  deviceId: string | null;
  type: string;
  clientId: string;
  data: unknown;
  version: number;
  clientUpdatedAt: string;
  serverUpdatedAt: string;
  deletedAt: string | null;
}

export interface AppVersion {
  id: string;
  platform: string;
  channel: string;
  versionName: string;
  versionCode: number;
  forceUpdate: boolean;
  enabled: boolean;
  apkUrl: string;
  apkSize: number | null;
  sha256: string | null;
  changelog: string | null;
  createdBy: string;
  createdAt: string;
  updatedAt: string;
}

export interface AdminAnnouncement {
  id: string;
  title: string;
  content: string;
  type: "info" | "warning" | "success" | "error";
  priority: number;
  targetUsers: string | null;
  imageUrl: string | null;
  startAt: string | null;
  endAt: string | null;
  enabled: boolean;
  createdBy: string;
  createdAt: string;
  updatedAt: string;
}

export interface AdminDailyComicImage {
  id: string;
  comicId: string;
  imageUrl: string;
  originalName: string | null;
  mimeType: string | null;
  size: number | null;
  sortOrder: number;
  createdAt: string;
  updatedAt: string;
}

export interface AdminDailyComic {
  id: string;
  title: string;
  description: string | null;
  publishDate: string;
  enabled: boolean;
  createdBy: string;
  createdAt: string;
  updatedAt: string;
  images: AdminDailyComicImage[];
}

export interface AdminMediaAsset {
  id: string;
  userId: string;
  username: string;
  nickname: string;
  deviceId: string | null;
  originalName: string;
  mimeType: string;
  size: number;
  sha256: string;
  fileUrl: string;
  thumbUrl: string;
  takenAt: string | null;
  uploadedAt: string;
  deletedAt: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface AdminMediaDownloadTicket {
  url: string;
  expiresAt: string;
}

export interface AdminMusicTrack {
  id: string;
  title: string;
  artist: string | null;
  album: string | null;
  audioUrl: string;
  coverUrl: string | null;
  lyrics: string | null;
  originalName: string;
  mimeType: string;
  size: number;
  durationSeconds: number | null;
  enabled: boolean;
  sortOrder: number;
  createdBy: string;
  createdAt: string;
  updatedAt: string;
}

export interface ForcePush {
  id: string;
  userId: string;
  username: string;
  nickname: string;
  deviceId: string | null;
  title: string;
  content: string;
  level: "info" | "warn" | "critical";
  enabled: boolean;
  deliveredAt: string | null;
  createdBy: string;
  createdAt: string;
  updatedAt: string;
  expiresAt: string | null;
}
