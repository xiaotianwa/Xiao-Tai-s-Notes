import {
  ClockCircleOutlined,
  DashboardOutlined,
  DatabaseOutlined,
  FileTextOutlined,
  PictureOutlined,
  ReloadOutlined,
  TeamOutlined,
} from "@ant-design/icons";
import { Alert, Button, Card, Empty, Skeleton, Space, Table, Tag } from "antd";
import type { ColumnsType } from "antd/es/table";
import { useEffect, useState } from "react";

import PageHeader, { StatCard } from "../components/PageHeader";
import { getDashboard } from "../api/admin";
import { ApiError } from "../api/client";
import type { AdminDevice, AdminUser, DashboardData } from "../api/types";
import { formatCount, formatDateTime } from "../utils/format";

export default function DashboardPage(): React.JSX.Element {
  const [data, setData] = useState<DashboardData | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  async function load(): Promise<void> {
    setLoading(true);
    setError(null);
    try {
      setData(await getDashboard());
    } catch (requestError) {
      setError(
        requestError instanceof ApiError
          ? requestError.message
          : "仪表盘加载失败",
      );
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void load();
  }, []);

  const deviceColumns: ColumnsType<AdminDevice & { user: AdminUser }> = [
    { title: "设备", dataIndex: "deviceName", width: 180, ellipsis: true },
    { title: "平台", dataIndex: "platform", width: 120 },
    { title: "用户", width: 120, render: (_, row) => row.user.nickname },
    {
      title: "最近同步",
      dataIndex: "lastSeenAt",
      width: 180,
      className: "table-date",
      render: (value: string | null) => formatDateTime(value),
    },
  ];

  return (
    <>
      <PageHeader
        eyebrow={
          <>
            <DashboardOutlined /> 仪表盘
          </>
        }
        title="控制台总览"
        subtitle="实时掌握私有同步状态、数据规模与最近管理动作。"
        extra={
          <Button
            icon={<ReloadOutlined />}
            onClick={() => void load()}
            loading={loading}
          >
            刷新
          </Button>
        }
      />
      {error && (
        <Alert
          type="error"
          showIcon
          title="加载失败"
          description={error}
          action={
            <Button size="small" type="link" onClick={() => void load()}>
              重试
            </Button>
          }
          style={{ marginBottom: 16 }}
          closable
          onClose={() => setError(null)}
        />
      )}
      {loading ? (
        <Skeleton active paragraph={{ rows: 8 }} />
      ) : data ? (
        <>
          <div className="metric-grid">
            <StatCard
              label="用户数量"
              value={formatCount(data.userCount)}
              icon={<TeamOutlined />}
              tone="primary"
            />
            <StatCard
              label="同步数据"
              value={formatCount(data.syncItemCount)}
              icon={<DatabaseOutlined />}
              tone="info"
            />
            <StatCard
              label="备忘录"
              value={formatCount(data.memoCount)}
              icon={<FileTextOutlined />}
              tone="accent"
            />
            <StatCard
              label="今日同步"
              value={formatCount(data.todaySyncCount)}
              icon={<ClockCircleOutlined />}
              tone="success"
            />
            <StatCard
              label="媒体文件"
              value={formatCount(data.mediaCount)}
              icon={<PictureOutlined />}
              tone="warning"
            />
          </div>
          <div className="content-grid">
            <Card title="最近同步设备" className="soft-card">
              <Table
                className="admin-table"
                rowKey="id"
                size="middle"
                columns={deviceColumns}
                dataSource={data.latestDevices}
                tableLayout="fixed"
                pagination={false}
                locale={{ emptyText: <Empty description="暂无设备同步" /> }}
              />
            </Card>
            <Card title="最近操作日志" className="soft-card">
              {data.recentAuditLogs.length === 0 ? (
                <Empty description="暂无操作日志" />
              ) : (
                <Space
                  orientation="vertical"
                  size={10}
                  style={{ width: "100%" }}
                >
                  {data.recentAuditLogs.map((item) => (
                    <div key={item.id} className="audit-entry">
                      <Space>
                        <Tag color="orange">{item.action}</Tag>
                        <span>{item.actor.nickname}</span>
                      </Space>
                      <div className="audit-entry-meta">
                        {formatDateTime(item.createdAt)}
                      </div>
                    </div>
                  ))}
                </Space>
              )}
            </Card>
          </div>
        </>
      ) : (
        <Empty description="暂无仪表盘数据" />
      )}
    </>
  );
}
