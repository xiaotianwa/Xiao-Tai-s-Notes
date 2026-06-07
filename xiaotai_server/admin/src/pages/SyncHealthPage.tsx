import {
  CheckCircleOutlined,
  ClockCircleOutlined,
  DatabaseOutlined,
  MobileOutlined,
  ReloadOutlined,
  SearchOutlined,
  SyncOutlined,
  TeamOutlined,
  WarningOutlined,
} from "@ant-design/icons";
import {
  Alert,
  Button,
  Card,
  Empty,
  Input,
  Select,
  Space,
  Table,
  Tag,
} from "antd";
import type { ColumnsType, TablePaginationConfig } from "antd/es/table";
import { useEffect, useState } from "react";
import { useNavigate } from "react-router-dom";

import { getSyncHealth } from "../api/admin";
import { ApiError } from "../api/client";
import type { AdminSyncHealthData, AdminSyncHealthUser } from "../api/types";
import PageHeader, { StatCard } from "../components/PageHeader";
import { formatCount, formatDateTime } from "../utils/format";

const statusOptions = [
  { value: "active", label: "启用账号" },
  { value: "disabled", label: "停用账号" },
];

const healthColor: Record<AdminSyncHealthUser["status"], string> = {
  healthy: "green",
  warning: "orange",
  critical: "red",
  no_data: "default",
  disabled: "volcano",
};

export default function SyncHealthPage(): React.JSX.Element {
  const navigate = useNavigate();
  const [data, setData] = useState<AdminSyncHealthData | null>(null);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(20);
  const [keyword, setKeyword] = useState("");
  const [status, setStatus] = useState<string | undefined>();
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function load(nextPage = page, nextPageSize = pageSize): Promise<void> {
    setLoading(true);
    setError(null);
    try {
      const result = await getSyncHealth({
        page: nextPage,
        pageSize: nextPageSize,
        keyword,
        status,
      });
      setData(result);
      setPage(result.page);
      setPageSize(result.pageSize);
    } catch (requestError) {
      setError(
        requestError instanceof ApiError
          ? requestError.message
          : "同步健康数据加载失败",
      );
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void load(1, pageSize);
  }, []);

  const summary = data?.summary;
  const columns: ColumnsType<AdminSyncHealthUser> = [
    {
      title: "用户",
      width: 180,
      render: (_, row) => (
        <div className="sync-business-cell">
          <div className="sync-business-title">{row.user.nickname}</div>
          <div className="sync-business-desc">{row.user.username}</div>
        </div>
      ),
    },
    {
      title: "健康状态",
      width: 130,
      render: (_, row) => (
        <Space direction="vertical" size={2}>
          <Tag color={healthColor[row.status]}>{row.statusLabel}</Tag>
          <span className="table-muted-text">{row.statusReason}</span>
        </Space>
      ),
    },
    {
      title: "最近活动",
      dataIndex: "latestActivityAt",
      width: 180,
      className: "table-date",
      render: (value: string | null) => formatDateTime(value),
    },
    {
      title: "设备",
      width: 180,
      render: (_, row) =>
        row.latestDevice ? (
          <div className="sync-business-cell">
            <div className="sync-business-title">
              {row.latestDevice.deviceName}
            </div>
            <div className="sync-business-desc">
              {row.latestDevice.platform}
              {row.latestDevice.appVersionName
                ? ` · ${row.latestDevice.appVersionName}`
                : ""}
            </div>
          </div>
        ) : (
          "-"
        ),
    },
    {
      title: "同步数据",
      width: 150,
      render: (_, row) => (
        <Space size={4} wrap>
          <Tag color="blue">{formatCount(row.activeSyncItemCount)} 正常</Tag>
          <Tag color="red">{formatCount(row.deletedSyncItemCount)} 删除</Tag>
        </Space>
      ),
    },
    {
      title: "今日同步",
      dataIndex: "todaySyncCount",
      width: 110,
      render: (value: number) => formatCount(value),
    },
    {
      title: "媒体",
      dataIndex: "mediaAssetCount",
      width: 90,
      render: (value: number) => formatCount(value),
    },
    {
      title: "操作",
      width: 110,
      className: "table-actions",
      render: (_, row) => (
        <Button
          type="link"
          onClick={() => navigate(`/users?detail=${row.user.id}`)}
        >
          用户 360
        </Button>
      ),
    },
  ];

  function handleTableChange(pagination: TablePaginationConfig): void {
    void load(pagination.current ?? 1, pagination.pageSize ?? 20);
  }

  return (
    <>
      <PageHeader
        eyebrow={
          <>
            <SyncOutlined /> 同步健康
          </>
        }
        title="业务数据同步健康中心"
        subtitle="按用户聚合同步记录、设备活动、媒体备份和删除数据，快速发现长期未同步或无数据账号。"
        extra={
          <Button
            icon={<ReloadOutlined />}
            onClick={() => void load(page, pageSize)}
            loading={loading}
          >
            刷新
          </Button>
        }
      />
      <div className="metric-grid">
        <StatCard
          label="启用用户"
          value={formatCount(summary?.activeUsers ?? 0)}
          icon={<TeamOutlined />}
          tone="primary"
        />
        <StatCard
          label="健康同步"
          value={formatCount(summary?.healthyUsers ?? 0)}
          icon={<CheckCircleOutlined />}
          tone="success"
        />
        <StatCard
          label="需关注"
          value={formatCount((summary?.warningUsers ?? 0) + (summary?.criticalUsers ?? 0))}
          icon={<WarningOutlined />}
          tone="warning"
        />
        <StatCard
          label="今日同步"
          value={formatCount(summary?.todaySyncCount ?? 0)}
          icon={<ClockCircleOutlined />}
          tone="info"
        />
        <StatCard
          label="设备数"
          value={formatCount(summary?.totalDevices ?? 0)}
          icon={<MobileOutlined />}
          tone="accent"
        />
        <StatCard
          label="同步数据"
          value={formatCount(summary?.totalSyncItems ?? 0)}
          icon={<DatabaseOutlined />}
          tone="primary"
        />
      </div>
      <div className="toolbar-card">
        <div className="toolbar">
          <Input.Search
            allowClear
            prefix={<SearchOutlined />}
            placeholder="搜索账号或昵称"
            style={{ width: 320 }}
            value={keyword}
            onChange={(event) => setKeyword(event.target.value)}
            onSearch={() => void load(1, pageSize)}
          />
          <Select
            allowClear
            placeholder="账号状态"
            style={{ width: 160 }}
            value={status}
            options={statusOptions}
            onChange={(value) => setStatus(value)}
          />
          <Button type="primary" ghost onClick={() => void load(1, pageSize)}>
            筛选
          </Button>
        </div>
      </div>
      {summary && summary.noDataUsers > 0 && (
        <Alert
          type="warning"
          showIcon
          title="存在无同步数据账号"
          description={`当前筛选范围内有 ${summary.noDataUsers} 个账号没有设备或同步记录，建议在用户 360 中核对账号是否已登录过 APP。`}
          style={{ marginBottom: 16 }}
        />
      )}
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
      <Card className="soft-card" styles={{ body: { padding: 0 } }}>
        <Table
          className="admin-table"
          rowKey={(row) => row.user.id}
          loading={loading}
          columns={columns}
          dataSource={data?.items ?? []}
          tableLayout="fixed"
          onChange={handleTableChange}
          pagination={{
            current: page,
            pageSize,
            total: data?.total ?? 0,
            showSizeChanger: true,
          }}
          locale={{
            emptyText: <Empty description="暂无同步健康数据" />,
          }}
        />
      </Card>
    </>
  );
}
