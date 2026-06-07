import {
  AuditOutlined,
  ApiOutlined,
  BellOutlined,
  BookOutlined,
  CalendarOutlined,
  ControlOutlined,
  CustomerServiceOutlined,
  DashboardOutlined,
  DatabaseOutlined,
  EditOutlined,
  EnvironmentOutlined,
  FileTextOutlined,
  LogoutOutlined,
  PictureOutlined,
  RollbackOutlined,
  SyncOutlined,
  TeamOutlined,
  UploadOutlined,
} from "@ant-design/icons";
import { Button, Layout, Menu, Tooltip } from "antd";
import type { MenuProps } from "antd";
import { Outlet, useLocation, useNavigate } from "react-router-dom";

import { useSession } from "../auth/session";

const { Header, Sider, Content } = Layout;

const navItems = [
  { section: "概览", key: "/", icon: <DashboardOutlined />, label: "仪表盘" },
  { section: "账号", key: "/users", icon: <TeamOutlined />, label: "用户管理" },
  { section: "内容", key: "/entries", icon: <EditOutlined />, label: "记录" },
  { section: "内容", key: "/memos", icon: <FileTextOutlined />, label: "备忘录" },
  { section: "内容", key: "/anniversaries", icon: <CalendarOutlined />, label: "纪念日" },
  {
    section: "内容",
    key: "/places",
    icon: <EnvironmentOutlined />,
    label: "想去的地方",
  },
  { section: "内容", key: "/media", icon: <PictureOutlined />, label: "媒体文件" },
  {
    section: "内容",
    key: "/music",
    icon: <CustomerServiceOutlined />,
    label: "音乐管理",
  },
  { section: "运营", key: "/monitor/push", icon: <ControlOutlined />, label: "强提醒" },
  { section: "运营", key: "/ai-verify", icon: <ApiOutlined />, label: "AI 验证" },
  {
    section: "运营",
    key: "/announcements",
    icon: <BellOutlined />,
    label: "公告管理",
  },
  {
    section: "运营",
    key: "/daily-comics",
    icon: <BookOutlined />,
    label: "小笨漫画",
  },
  {
    section: "系统",
    key: "/sync-health",
    icon: <SyncOutlined />,
    label: "同步健康",
  },
  {
    section: "系统",
    key: "/data",
    icon: <DatabaseOutlined />,
    label: "APP 数据(全部)",
  },
  {
    section: "系统",
    key: "/recovery",
    icon: <RollbackOutlined />,
    label: "数据恢复",
  },
  {
    section: "系统",
    key: "/app-versions",
    icon: <UploadOutlined />,
    label: "版本管理",
  },
  { section: "系统", key: "/audit-logs", icon: <AuditOutlined />, label: "操作日志" },
];

const menuItems: MenuProps["items"] = ["概览", "账号", "内容", "运营", "系统"].map(
  (section) => ({
    key: section,
    type: "group",
    label: section,
    children: navItems
      .filter((item) => item.section === section)
      .map(({ key, icon, label }) => ({ key, icon, label })),
  }),
);

const mobileMenuItems: MenuProps["items"] = navItems.map(
  ({ key, icon, label }) => ({ key, icon, label }),
);

function avatarLetter(value: string | undefined): string {
  if (!value) {
    return "小";
  }
  const trimmed = value.trim();
  return trimmed.length > 0 ? trimmed[0]!.toUpperCase() : "小";
}

export default function AdminLayout(): React.JSX.Element {
  const navigate = useNavigate();
  const location = useLocation();
  const { session, signOut } = useSession();

  const currentItem =
    navItems.find((item) => item.key === location.pathname) ?? navItems[0];
  const displayName = session?.nickname ?? session?.username ?? "管理员";
  const roleLabel = session?.role === "admin" ? "超级管理员" : "管理员";

  return (
    <Layout className="app-shell">
      <a className="skip-link" href="#main-content">
        跳到主内容
      </a>
      <Sider width={232} theme="light" className="app-sider">
        <div className="app-logo">
          <span className="app-logo-mark">小</span>
          <span className="app-logo-text">
            <strong>小泰管理端</strong>
            <span>私有同步控制台</span>
          </span>
        </div>
        <Menu
          mode="inline"
          selectedKeys={[location.pathname]}
          items={menuItems}
          onClick={(item) => navigate(item.key)}
          className="app-sider-menu"
        />
        <div className="app-sider-footer">
          婷婷的小笨笔记 · V2 控制台
          <br />
          仅供私有部署使用
        </div>
      </Sider>
      <Layout>
        <Header className="app-header">
          <div className="app-header-left">
            <span className="app-header-eyebrow">
              婷婷的小笨笔记 · 管理中心
            </span>
            <span className="app-header-title">{currentItem.label}</span>
          </div>
          <div className="app-header-right">
            <div className="app-header-user">
              <div className="app-header-avatar">
                {avatarLetter(displayName)}
              </div>
              <div className="app-header-user-meta">
                <span className="app-header-user-name">{displayName}</span>
                <span className="app-header-user-role">{roleLabel}</span>
              </div>
            </div>
            <Tooltip title="退出登录">
              <Button
                icon={<LogoutOutlined />}
                onClick={() => {
                  signOut();
                  navigate("/login", { replace: true });
                }}
              >
                退出
              </Button>
            </Tooltip>
          </div>
        </Header>
        <div className="app-mobile-nav" aria-label="移动端管理导航">
          <Menu
            mode="horizontal"
            selectedKeys={[location.pathname]}
            items={mobileMenuItems}
            onClick={(item) => navigate(item.key)}
          />
        </div>
        <Content id="main-content" className="page-content">
          <Outlet />
        </Content>
      </Layout>
    </Layout>
  );
}
