import { Spin } from "antd";
import { lazy, Suspense, type ReactNode } from "react";
import { BrowserRouter, Navigate, Route, Routes } from "react-router-dom";

import { SessionProvider, useSession } from "./auth/session";
import AdminLayout from "./layout/AdminLayout";
import LoginPage from "./pages/LoginPage";

const AnnouncementsPage = lazy(() => import("./pages/AnnouncementsPage"));
const AuditLogsPage = lazy(() => import("./pages/AuditLogsPage"));
const AppVersionsPage = lazy(() => import("./pages/AppVersionsPage"));
const AiVerifyPage = lazy(() => import("./pages/AiVerifyPage"));
const DashboardPage = lazy(() => import("./pages/DashboardPage"));
const DataPage = lazy(() => import("./pages/DataPage"));
const DailyComicsPage = lazy(() => import("./pages/DailyComicsPage"));
const EntriesPage = lazy(() => import("./pages/EntriesPage"));
const ForcePushPage = lazy(() => import("./pages/ForcePushPage"));
const MediaPage = lazy(() => import("./pages/MediaPage"));
const MemosPage = lazy(() => import("./pages/MemosPage"));
const MusicPage = lazy(() => import("./pages/MusicPage"));
const PlacesPage = lazy(() => import("./pages/PlacesPage"));
const UsersPage = lazy(() => import("./pages/UsersPage"));

function RequireAuth(): React.JSX.Element {
  const { session } = useSession();
  if (!session) {
    return <Navigate to="/login" replace />;
  }
  return <AdminLayout />;
}

function PageFallback(): React.JSX.Element {
  return (
    <div className="route-fallback" role="status" aria-live="polite">
      <Spin size="small" />
      <span>正在加载页面</span>
    </div>
  );
}

function withSuspense(element: ReactNode): React.JSX.Element {
  return <Suspense fallback={<PageFallback />}>{element}</Suspense>;
}

export default function App(): React.JSX.Element {
  return (
    <SessionProvider>
      <BrowserRouter>
        <Routes>
          <Route path="/login" element={<LoginPage />} />
          <Route element={<RequireAuth />}>
            <Route path="/" element={withSuspense(<DashboardPage />)} />
            <Route path="/users" element={withSuspense(<UsersPage />)} />
            <Route path="/data" element={withSuspense(<DataPage />)} />
            <Route path="/entries" element={withSuspense(<EntriesPage />)} />
            <Route path="/memos" element={withSuspense(<MemosPage />)} />
            <Route path="/places" element={withSuspense(<PlacesPage />)} />
            <Route path="/media" element={withSuspense(<MediaPage />)} />
            <Route path="/music" element={withSuspense(<MusicPage />)} />
            <Route
              path="/monitor/push"
              element={withSuspense(<ForcePushPage />)}
            />
            <Route path="/ai-verify" element={withSuspense(<AiVerifyPage />)} />
            <Route
              path="/announcements"
              element={withSuspense(<AnnouncementsPage />)}
            />
            <Route
              path="/daily-comics"
              element={withSuspense(<DailyComicsPage />)}
            />
            <Route
              path="/app-versions"
              element={withSuspense(<AppVersionsPage />)}
            />
            <Route
              path="/audit-logs"
              element={withSuspense(<AuditLogsPage />)}
            />
          </Route>
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </BrowserRouter>
    </SessionProvider>
  );
}
