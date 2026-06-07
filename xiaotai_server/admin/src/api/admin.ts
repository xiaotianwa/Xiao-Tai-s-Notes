import { requestApi, requestUpload } from "./client";
import type { UploadProgress } from "./client";
import type {
  AdminAuditLog,
  AdminAnnouncement,
  AdminDevice,
  AdminDailyComic,
  AdminMediaAsset,
  AdminMediaDownloadTicket,
  AdminMusicTrack,
  AdminSyncHealthData,
  AdminSyncItem,
  AdminUser,
  AdminUserDetail,
  AppVersion,
  AuthTokens,
  DashboardData,
  ForcePush,
  PageResult,
} from "./types";

export interface PageQuery {
  page?: number;
  pageSize?: number;
  keyword?: string;
}

export interface UserQuery extends PageQuery {
  status?: string;
}

export interface ItemQuery extends PageQuery {
  userId?: string;
  type?: string;
  deleted?: string;
}

export interface AppVersionQuery extends PageQuery {
  platform?: string;
  channel?: string;
}

export interface MediaQuery extends PageQuery {
  userId?: string;
  deleted?: string;
}

export interface MusicQuery extends PageQuery {
  enabled?: string;
}

export interface AnnouncementQuery extends PageQuery {
  type?: string;
  enabled?: string;
}

export interface DailyComicQuery extends PageQuery {
  enabled?: string;
}

export interface MonitorPushQuery extends PageQuery {
  userId?: string;
  level?: string;
  enabled?: string;
  since?: string;
  until?: string;
}

export interface AnnouncementInput {
  title: string;
  content: string;
  type: AdminAnnouncement["type"];
  priority: number;
  targetUsers?: string;
  imageUrl?: string;
  startAt?: string | null;
  endAt?: string | null;
  enabled: boolean;
}

export interface DailyComicImageInput {
  imageUrl: string;
  originalName?: string;
  mimeType?: string;
  size?: number;
}

export interface DailyComicInput {
  title: string;
  description?: string;
  publishDate: string;
  enabled: boolean;
  images: DailyComicImageInput[];
}

export interface CreateForcePushInput {
  userId: string;
  deviceId?: string | null;
  title: string;
  content: string;
  level?: ForcePush["level"];
  expiresAt?: string | null;
}

export interface UpdateForcePushInput {
  title?: string;
  content?: string;
  level?: ForcePush["level"];
  enabled?: boolean;
  expiresAt?: string | null;
}

export interface UpdateAppVersionInput {
  changelog?: string;
  forceUpdate?: boolean;
  enabled?: boolean;
}

export interface CreateAdminUserInput {
  username: string;
  nickname: string;
  password: string;
  role?: "user" | "admin";
  status?: "active" | "disabled";
}

export interface ResetAdminUserPasswordInput {
  password: string;
}

export interface UpdateAdminUserStatusInput {
  status: "active" | "disabled";
}

export interface AiChatResult {
  answer: string;
  model: string;
}

export function login(username: string, password: string): Promise<AuthTokens> {
  return requestApi<AuthTokens>("/auth/login", {
    method: "POST",
    body: JSON.stringify({ username, password }),
  });
}

export function getMe(): Promise<AuthTokens["user"]> {
  return requestApi<AuthTokens["user"]>("/auth/me");
}

export function getDashboard(): Promise<DashboardData> {
  return requestApi<DashboardData>("/admin/dashboard");
}

export function getSyncHealth(
  query: UserQuery,
): Promise<AdminSyncHealthData> {
  return requestApi<AdminSyncHealthData>(
    `/admin/sync-health?${toQuery(query)}`,
  );
}

export function verifyAiModel(message: string): Promise<AiChatResult> {
  return requestApi<AiChatResult>("/ai/chat", {
    method: "POST",
    body: JSON.stringify({ message }),
  });
}

export function getUsers(query: UserQuery): Promise<PageResult<AdminUser>> {
  return requestApi<PageResult<AdminUser>>(`/admin/users?${toQuery(query)}`);
}

export function getUserDetail(
  id: string,
): Promise<AdminUserDetail> {
  return requestApi(`/admin/users/${encodeURIComponent(id)}`);
}

export function getUserItems(
  id: string,
  query: Omit<ItemQuery, "userId">,
): Promise<PageResult<AdminSyncItem>> {
  return requestApi<PageResult<AdminSyncItem>>(
    `/admin/users/${encodeURIComponent(id)}/items?${toQuery(query)}`,
  );
}

export function createAdminUser(
  input: CreateAdminUserInput,
): Promise<AdminUser> {
  return requestApi<AdminUser>("/admin/users", {
    method: "POST",
    body: JSON.stringify(input),
  });
}

export function resetAdminUserPassword(
  id: string,
  input: ResetAdminUserPasswordInput,
): Promise<AdminUser> {
  return requestApi<AdminUser>(
    `/admin/users/${encodeURIComponent(id)}/password`,
    {
      method: "PATCH",
      body: JSON.stringify(input),
    },
  );
}

export function updateAdminUserStatus(
  id: string,
  input: UpdateAdminUserStatusInput,
): Promise<AdminUser> {
  return requestApi<AdminUser>(
    `/admin/users/${encodeURIComponent(id)}/status`,
    {
      method: "PATCH",
      body: JSON.stringify(input),
    },
  );
}

export function deleteAdminUser(id: string): Promise<{
  deleted: true;
  user: AdminUser;
  related: {
    refreshTokens: number;
    devices: number;
    syncItems: number;
    mediaAssets: number;
    auditLogs: number;
    spaceMemberships: number;
    orphanSpaces: number;
  };
}> {
  return requestApi(`/admin/users/${encodeURIComponent(id)}`, {
    method: "DELETE",
  });
}

export function getItems(query: ItemQuery): Promise<PageResult<AdminSyncItem>> {
  return requestApi<PageResult<AdminSyncItem>>(
    `/admin/items?${toQuery(query)}`,
  );
}

export function getAnniversaryItems(
  query: Omit<ItemQuery, "type">,
): Promise<PageResult<AdminSyncItem>> {
  return getItems({ ...query, type: "anniversary" });
}

export function getItemDetail(id: string): Promise<AdminSyncItem> {
  return requestApi<AdminSyncItem>(`/admin/items/${encodeURIComponent(id)}`);
}

export function deleteSyncItem(
  id: string,
): Promise<{ deleted: true; item: AdminSyncItem }> {
  return requestApi<{ deleted: true; item: AdminSyncItem }>(
    `/admin/items/${encodeURIComponent(id)}`,
    { method: "DELETE" },
  );
}

export function restoreSyncItem(
  id: string,
): Promise<{ restored: true; item: AdminSyncItem }> {
  return requestApi<{ restored: true; item: AdminSyncItem }>(
    `/admin/items/${encodeURIComponent(id)}/restore`,
    { method: "PATCH" },
  );
}

export function getAuditLogs(
  query: PageQuery & { action?: string },
): Promise<PageResult<AdminAuditLog>> {
  return requestApi<PageResult<AdminAuditLog>>(
    `/admin/audit-logs?${toQuery(query)}`,
  );
}

export function getAppVersions(
  query: AppVersionQuery,
): Promise<PageResult<AppVersion>> {
  return requestApi<PageResult<AppVersion>>(
    `/admin/app-versions?${toQuery(query)}`,
  );
}

export function createAppVersion(
  form: FormData,
  onProgress?: (progress: UploadProgress) => void,
): Promise<AppVersion> {
  return requestUpload<AppVersion>("/admin/app-versions", form, {
    method: "POST",
    onProgress,
  });
}

export function updateAppVersion(
  id: string,
  input: UpdateAppVersionInput,
): Promise<AppVersion> {
  return requestApi<AppVersion>(
    `/admin/app-versions/${encodeURIComponent(id)}`,
    {
      method: "PATCH",
      body: JSON.stringify(input),
    },
  );
}

export function deleteAppVersion(id: string): Promise<{ deleted: true }> {
  return requestApi<{ deleted: true }>(
    `/admin/app-versions/${encodeURIComponent(id)}`,
    { method: "DELETE" },
  );
}

export function getAnnouncements(
  query: AnnouncementQuery,
): Promise<PageResult<AdminAnnouncement>> {
  return requestApi<PageResult<AdminAnnouncement>>(
    `/announcements?${toQuery(query)}`,
  );
}

export function createAnnouncement(
  input: AnnouncementInput,
): Promise<AdminAnnouncement> {
  return requestApi<AdminAnnouncement>("/announcements", {
    method: "POST",
    body: JSON.stringify(input),
  });
}

export function uploadAnnouncementImage(
  form: FormData,
): Promise<{ imageUrl: string }> {
  return requestApi<{ imageUrl: string }>("/announcements/image", {
    method: "POST",
    body: form,
  });
}

export function updateAnnouncement(
  id: string,
  input: Partial<AnnouncementInput>,
): Promise<AdminAnnouncement> {
  return requestApi<AdminAnnouncement>(
    `/announcements/${encodeURIComponent(id)}`,
    {
      method: "PATCH",
      body: JSON.stringify(input),
    },
  );
}

export function deleteAnnouncement(id: string): Promise<{ success: true }> {
  return requestApi<{ success: true }>(
    `/announcements/${encodeURIComponent(id)}`,
    { method: "DELETE" },
  );
}

export function getDailyComics(
  query: DailyComicQuery,
): Promise<PageResult<AdminDailyComic>> {
  return requestApi<PageResult<AdminDailyComic>>(
    `/daily-comics?${toQuery(query)}`,
  );
}

export function createDailyComic(
  input: DailyComicInput,
): Promise<AdminDailyComic> {
  return requestApi<AdminDailyComic>("/daily-comics", {
    method: "POST",
    body: JSON.stringify(input),
  });
}

export function uploadDailyComicImage(
  form: FormData,
): Promise<DailyComicImageInput> {
  return requestApi<DailyComicImageInput>("/daily-comics/image", {
    method: "POST",
    body: form,
  });
}

export function updateDailyComic(
  id: string,
  input: Partial<DailyComicInput>,
): Promise<AdminDailyComic> {
  return requestApi<AdminDailyComic>(
    `/daily-comics/${encodeURIComponent(id)}`,
    {
      method: "PATCH",
      body: JSON.stringify(input),
    },
  );
}

export function deleteDailyComic(id: string): Promise<{ success: true }> {
  return requestApi<{ success: true }>(
    `/daily-comics/${encodeURIComponent(id)}`,
    { method: "DELETE" },
  );
}

export function getMediaAssets(
  query: MediaQuery,
): Promise<PageResult<AdminMediaAsset>> {
  return requestApi<PageResult<AdminMediaAsset>>(
    `/admin/media?${toQuery(query)}`,
  );
}

export function getMediaAsset(id: string): Promise<AdminMediaAsset> {
  return requestApi<AdminMediaAsset>(`/admin/media/${encodeURIComponent(id)}`);
}

export function createMediaDownloadTicket(
  id: string,
): Promise<AdminMediaDownloadTicket> {
  return requestApi<AdminMediaDownloadTicket>(
    `/admin/media/${encodeURIComponent(id)}/download-ticket`,
    { method: "POST" },
  );
}

export function deleteMediaAsset(id: string): Promise<{ deleted: true }> {
  return requestApi<{ deleted: true }>(
    `/admin/media/${encodeURIComponent(id)}`,
    {
      method: "DELETE",
    },
  );
}

export function getMusicTracks(
  query: MusicQuery,
): Promise<PageResult<AdminMusicTrack>> {
  return requestApi<PageResult<AdminMusicTrack>>(
    `/admin/music/tracks?${toQuery(query)}`,
  );
}

export function createMusicTrack(
  form: FormData,
  onProgress?: (progress: UploadProgress) => void,
): Promise<AdminMusicTrack> {
  return requestUpload<AdminMusicTrack>("/admin/music/tracks", form, {
    method: "POST",
    onProgress,
  });
}

export function updateMusicTrack(
  id: string,
  form: FormData,
  onProgress?: (progress: UploadProgress) => void,
): Promise<AdminMusicTrack> {
  return requestUpload<AdminMusicTrack>(
    `/admin/music/tracks/${encodeURIComponent(id)}`,
    form,
    { method: "PATCH", onProgress },
  );
}

export function deleteMusicTrack(id: string): Promise<{ success: true }> {
  return requestApi<{ success: true }>(
    `/admin/music/tracks/${encodeURIComponent(id)}`,
    { method: "DELETE" },
  );
}

export function getForcePushes(
  query: MonitorPushQuery,
): Promise<PageResult<ForcePush>> {
  return requestApi<PageResult<ForcePush>>(`/monitor/push?${toQuery(query)}`);
}

export function createForcePush(
  input: CreateForcePushInput,
): Promise<ForcePush> {
  return requestApi<ForcePush>("/monitor/push", {
    method: "POST",
    body: JSON.stringify(input),
  });
}

export function updateForcePush(
  id: string,
  input: UpdateForcePushInput,
): Promise<ForcePush> {
  return requestApi<ForcePush>(`/monitor/push/${encodeURIComponent(id)}`, {
    method: "PATCH",
    body: JSON.stringify(input),
  });
}

export function deleteForcePush(id: string): Promise<{ success: true }> {
  return requestApi<{ success: true }>(
    `/monitor/push/${encodeURIComponent(id)}`,
    { method: "DELETE" },
  );
}

function toQuery(query: object): string {
  const params = new URLSearchParams();
  for (const [key, value] of Object.entries(query) as Array<
    [string, unknown]
  >) {
    if (
      (typeof value === "string" || typeof value === "number") &&
      value !== ""
    ) {
      params.set(key, String(value));
    }
  }
  return params.toString();
}
