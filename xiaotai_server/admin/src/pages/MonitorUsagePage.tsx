import {
  AppstoreOutlined,
  BellOutlined,
  CheckCircleOutlined,
  DesktopOutlined,
  FieldTimeOutlined,
  MobileOutlined,
  ReloadOutlined,
  SafetyCertificateOutlined,
} from "@ant-design/icons";
import { Alert, Button, Card, Empty, Input, List, Space, Table, Tag } from "antd";
import type { ColumnsType, TablePaginationConfig } from "antd/es/table";
import { useEffect, useMemo, useState } from "react";

import {
  getMonitorDevices,
  getMonitorLatestUsage,
  getMonitorUsage,
} from "../api/admin";
import { ApiError } from "../api/client";
import type {
  MonitorDeviceSummary,
  MonitorTodayUsageItem,
  MonitorUsageReport,
} from "../api/types";
import PageHeader from "../components/PageHeader";
import { formatDateTime } from "../utils/format";

export default function MonitorUsagePage(): React.JSX.Element {
  const [devices, setDevices] = useState<MonitorDeviceSummary[]>([]);
  const [selected, setSelected] = useState<MonitorDeviceSummary | null>(null);
  const [latest, setLatest] = useState<MonitorUsageReport | null>(null);
  const [reports, setReports] = useState<MonitorUsageReport[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(20);
  const [userId, setUserId] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function loadDevices(): Promise<void> {
    setLoading(true);
    setError(null);
    try {
      const nextDevices = await getMonitorDevices({ userId });
      setDevices(nextDevices);
      const nextSelected =
        nextDevices.find(
          (item) =>
            item.userId === selected?.userId &&
            item.deviceId === selected?.deviceId,
        ) ??
        nextDevices[0] ??
        null;
      setSelected(nextSelected);
      if (nextSelected) {
        await loadDeviceData(nextSelected, 1, pageSize);
      } else {
        setLatest(null);
        setReports([]);
        setTotal(0);
      }
    } catch (requestError) {
      setError(toErrorMessage(requestError, "设备监控数据加载失败"));
    } finally {
      setLoading(false);
    }
  }

  async function loadDeviceData(
    device: MonitorDeviceSummary,
    nextPage = page,
    nextPageSize = pageSize,
  ): Promise<void> {
    setError(null);
    try {
      const [latestReport, reportPage] = await Promise.all([
        getMonitorLatestUsage({
          userId: device.userId,
          deviceId: device.deviceId,
        }),
        getMonitorUsage({
          userId: device.userId,
          deviceId: device.deviceId,
          page: nextPage,
          pageSize: nextPageSize,
        }),
      ]);
      setLatest(latestReport);
      setReports(reportPage.items);
      setTotal(reportPage.total);
      setPage(reportPage.page);
      setPageSize(reportPage.pageSize);
    } catch (requestError) {
      setError(toErrorMessage(requestError, "设备使用明细加载失败"));
    }
  }

  useEffect(() => {
    void loadDevices();
  }, []);

  useEffect(() => {
    if (!selected) {
      return undefined;
    }
    const timer = window.setInterval(() => {
      void loadDeviceData(selected, page, pageSize);
    }, 5000);
    return () => window.clearInterval(timer);
  }, [selected?.userId, selected?.deviceId, page, pageSize]);

  const topUsage = useMemo(
    () =>
      [...(latest?.todayUsage ?? [])]
        .sort((a, b) => b.totalMillis - a.totalMillis)
        .slice(0, 10),
    [latest],
  );

  function handleTableChange(pagination: TablePaginationConfig): void {
    if (!selected) {
      return;
    }
    void loadDeviceData(
      selected,
      pagination.current ?? 1,
      pagination.pageSize ?? 20,
    );
  }

  return (
    <>
      <PageHeader
        eyebrow={
          <>
            <DesktopOutlined /> 设备监控
          </>
        }
        title="设备实时监控"
        subtitle="查看授权设备的前台 App、屏幕状态和使用时长，并确认实时监控与强弹授权状态。"
        extra={
          <Button icon={<ReloadOutlined />} onClick={() => void loadDevices()}>
            刷新
          </Button>
        }
      />

      <div className="toolbar-card">
        <div className="toolbar monitor-toolbar">
          <Input.Search
            allowClear
            placeholder="按用户 ID 筛选"
            value={userId}
            onChange={(event) => setUserId(event.target.value)}
            onSearch={() => void loadDevices()}
          />
          <Button type="primary" ghost onClick={() => void loadDevices()}>
            筛选
          </Button>
        </div>
      </div>

      {error && (
        <Alert
          type="error"
          showIcon
          title="操作失败"
          description={error}
          style={{ marginBottom: 14 }}
          closable
          onClose={() => setError(null)}
        />
      )}

      <div className="monitor-workbench">
        <Card className="soft-card monitor-device-panel" title="授权设备" loading={loading}>
          <List
            dataSource={devices}
            locale={{ emptyText: <Empty description="暂无设备上报" /> }}
            renderItem={(item) => (
              <List.Item
                className={
                  selected?.userId === item.userId &&
                  selected?.deviceId === item.deviceId
                    ? "monitor-device-item active"
                    : "monitor-device-item"
                }
                onClick={() => {
                  setSelected(item);
                  void loadDeviceData(item, 1, pageSize);
                }}
              >
                <List.Item.Meta
                  avatar={<MobileOutlined />}
                  title={`${item.nickname || item.username} / ${item.deviceName ?? item.deviceId}`}
                  description={
                    <Space direction="vertical" size={2}>
                      <span>{item.deviceId}</span>
                      <span>{formatDateTime(item.lastSeenAt)}</span>
                    </Space>
                  }
                />
                <OnlineTag lastSeenAt={item.lastSeenAt} />
              </List.Item>
            )}
          />
        </Card>

        <Space direction="vertical" size={12} className="monitor-main-panel">
          <div className="metric-grid">
            <MonitorStat
              icon={<AppstoreOutlined />}
              label="当前前台 App"
              value={latest?.foregroundAppName ?? latest?.foregroundPackage ?? "-"}
              hint={latest?.foregroundPackage ?? "暂无上报"}
            />
            <MonitorStat
              icon={<DesktopOutlined />}
              label="屏幕状态"
              value={latest?.screenOn ? "亮屏" : latest ? "熄屏" : "-"}
              hint={latest ? formatDateTime(latest.capturedAt) : "暂无上报"}
            />
            <MonitorStat
              icon={<FieldTimeOutlined />}
              label="最近上报"
              value={latest ? relativeMinutes(latest.capturedAt) : "-"}
              hint={latest ? formatDateTime(latest.capturedAt) : "暂无上报"}
            />
          </div>

          <Card className="soft-card monitor-auth-card" title="授权内容">
            <div className="monitor-auth-grid">
              <AuthItem
                icon={<SafetyCertificateOutlined />}
                title="使用情况访问"
                description="手机端登录后授权，用于上报前台 App、屏幕状态和使用时长。"
              />
              <AuthItem
                icon={<BellOutlined />}
                title="实时强弹提醒"
                description="手机端登录后授权悬浮窗，管理端发布强提醒后由手机端轮询并弹出。"
              />
              <AuthItem
                icon={<CheckCircleOutlined />}
                title="默认开启"
                description="两项核心授权完成后，手机端会自动启动实时监控与强弹服务。"
              />
            </div>
          </Card>

          <Card className="soft-card" title="今日使用 Top 10">
            {topUsage.length === 0 ? (
              <Empty description="暂无使用时长数据" />
            ) : (
              <Space direction="vertical" size={10} style={{ width: "100%" }}>
                {topUsage.map((item) => (
                  <UsageBar
                    key={item.packageName}
                    item={item}
                    max={topUsage[0]!.totalMillis}
                  />
                ))}
              </Space>
            )}
          </Card>

          <Card
            className="soft-card"
            title="最近上报记录"
            styles={{ body: { padding: 0 } }}
          >
            <Table
              className="admin-table"
              rowKey="id"
              columns={usageColumns}
              dataSource={reports}
              onChange={handleTableChange}
              pagination={{ current: page, pageSize, total, showSizeChanger: true }}
              tableLayout="fixed"
            />
          </Card>
        </Space>
      </div>
    </>
  );
}

function AuthItem({
  icon,
  title,
  description,
}: {
  icon: React.ReactNode;
  title: string;
  description: string;
}): React.JSX.Element {
  return (
    <div className="monitor-auth-item">
      <span className="monitor-auth-icon">{icon}</span>
      <span>
        <strong>{title}</strong>
        <p>{description}</p>
      </span>
    </div>
  );
}

function MonitorStat({
  icon,
  label,
  value,
  hint,
}: {
  icon: React.ReactNode;
  label: string;
  value: string;
  hint: string;
}): React.JSX.Element {
  return (
    <div className="stat-card">
      <span className="stat-card-icon">{icon}</span>
      <span className="stat-card-body">
        <div className="stat-card-label">{label}</div>
        <div className="stat-card-value monitor-stat-value">{value}</div>
        <div className="stat-card-hint">{hint}</div>
      </span>
    </div>
  );
}

function OnlineTag({ lastSeenAt }: { lastSeenAt: string }): React.JSX.Element {
  const offline = Date.now() - new Date(lastSeenAt).getTime() > 5 * 60 * 1000;
  return <Tag color={offline ? "default" : "green"}>{offline ? "离线" : "在线"}</Tag>;
}

function UsageBar({
  item,
  max,
}: {
  item: MonitorTodayUsageItem;
  max: number;
}): React.JSX.Element {
  const width = max <= 0 ? 0 : Math.max(4, (item.totalMillis / max) * 100);
  return (
    <div className="usage-bar-row">
      <span className="usage-bar-name">{item.appName || item.packageName}</span>
      <span className="usage-bar-track">
        <span style={{ width: `${width}%` }} />
      </span>
      <strong>{formatDuration(item.totalMillis)}</strong>
    </div>
  );
}

const usageColumns: ColumnsType<MonitorUsageReport> = [
  {
    title: "上报时间",
    dataIndex: "capturedAt",
    width: 180,
    className: "table-date",
    render: (value: string) => formatDateTime(value),
  },
  {
    title: "屏幕",
    dataIndex: "screenOn",
    width: 90,
    render: (value: boolean) => (
      <Tag color={value ? "green" : "default"}>{value ? "亮屏" : "熄屏"}</Tag>
    ),
  },
  {
    title: "前台 App",
    width: 220,
    ellipsis: true,
    render: (_, row) => row.foregroundAppName ?? row.foregroundPackage ?? "-",
  },
  {
    title: "包名",
    dataIndex: "foregroundPackage",
    width: 260,
    ellipsis: true,
    render: (value: string | null) => (
      <span className="table-mono-text table-clip">{value ?? "-"}</span>
    ),
  },
];

function relativeMinutes(value: string): string {
  const diff = Math.max(0, Date.now() - new Date(value).getTime());
  if (diff < 60 * 1000) {
    return "刚刚";
  }
  return `${Math.floor(diff / 60000)} 分钟前`;
}

function formatDuration(ms: number): string {
  const minutes = Math.floor(ms / 60000);
  if (minutes < 60) {
    return `${minutes} 分钟`;
  }
  const hours = Math.floor(minutes / 60);
  const rest = minutes % 60;
  return rest > 0 ? `${hours}小时${rest}分钟` : `${hours}小时`;
}

function toErrorMessage(error: unknown, fallback: string): string {
  return error instanceof ApiError ? error.message : fallback;
}
