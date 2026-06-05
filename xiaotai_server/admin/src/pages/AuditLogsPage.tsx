import {
  AuditOutlined,
  DeleteOutlined,
  DownloadOutlined,
  EyeOutlined,
  ReloadOutlined,
  SearchOutlined,
  UserOutlined,
} from "@ant-design/icons";
import {
  Alert,
  Button,
  Card,
  Descriptions,
  Empty,
  Input,
  Modal,
  Space,
  Table,
  Tag,
  Tooltip,
} from "antd";

import PageHeader from "../components/PageHeader";
import type { ColumnsType, TablePaginationConfig } from "antd/es/table";
import { useEffect, useState } from "react";

import { getAuditLogs } from "../api/admin";
import { ApiError } from "../api/client";
import type { AdminAuditLog } from "../api/types";
import { formatDateTime, formatDateTimeFull } from "../utils/format";

interface ActionInfo {
  label: string;
  color: string;
  icon?: React.ReactNode;
}

function getActionInfo(action: string): ActionInfo {
  const actionMap: Record<string, ActionInfo> = {
    // 用户相关
    "admin.users.view": {
      label: "查看用户",
      color: "blue",
      icon: <EyeOutlined />,
    },
    "admin.users.create": {
      label: "创建用户",
      color: "green",
      icon: <UserOutlined />,
    },
    "admin.users.update": {
      label: "更新用户",
      color: "orange",
      icon: <UserOutlined />,
    },
    "admin.users.delete": {
      label: "删除用户",
      color: "red",
      icon: <DeleteOutlined />,
    },

    // 数据相关
    "admin.items.view": {
      label: "查看数据",
      color: "blue",
      icon: <EyeOutlined />,
    },
    "admin.items.delete": {
      label: "删除数据",
      color: "red",
      icon: <DeleteOutlined />,
    },

    // 媒体相关
    "admin.media.view": {
      label: "查看媒体",
      color: "blue",
      icon: <EyeOutlined />,
    },
    "admin.media.download": {
      label: "下载媒体",
      color: "cyan",
      icon: <DownloadOutlined />,
    },
    "admin.media.delete": {
      label: "删除媒体",
      color: "red",
      icon: <DeleteOutlined />,
    },

    // 版本相关
    "admin.versions.view": {
      label: "查看版本",
      color: "blue",
      icon: <EyeOutlined />,
    },
    "admin.versions.create": { label: "发布版本", color: "green" },
    "admin.versions.update": { label: "更新版本", color: "orange" },
    "admin.versions.delete": {
      label: "删除版本",
      color: "red",
      icon: <DeleteOutlined />,
    },

    // 同步相关
    "admin.sync.view": {
      label: "查看同步",
      color: "blue",
      icon: <EyeOutlined />,
    },
  };

  return actionMap[action] ?? { label: action, color: "default" };
}

export default function AuditLogsPage(): React.JSX.Element {
  const [items, setItems] = useState<AdminAuditLog[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(20);
  const [action, setAction] = useState("");
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [detail, setDetail] = useState<AdminAuditLog | null>(null);

  async function load(nextPage = page, nextPageSize = pageSize): Promise<void> {
    setLoading(true);
    setError(null);
    try {
      const result = await getAuditLogs({
        page: nextPage,
        pageSize: nextPageSize,
        action,
      });
      setItems(result.items);
      setTotal(result.total);
      setPage(result.page);
      setPageSize(result.pageSize);
    } catch (requestError) {
      setError(
        requestError instanceof ApiError
          ? requestError.message
          : "操作日志加载失败",
      );
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void load(1, pageSize);
  }, []);

  const columns: ColumnsType<AdminAuditLog> = [
    {
      title: "动作",
      dataIndex: "action",
      width: 180,
      render: (value: string) => {
        const info = getActionInfo(value);
        return (
          <Tooltip title={value}>
            <Tag color={info.color} icon={info.icon}>
              {info.label}
            </Tag>
          </Tooltip>
        );
      },
    },
    {
      title: "操作者",
      width: 140,
      render: (_, row) => (
        <Space size={4}>
          <UserOutlined style={{ color: "var(--color-text-muted)" }} />
          <span>{row.actor.nickname}</span>
        </Space>
      ),
    },
    {
      title: "目标类型",
      dataIndex: "targetType",
      width: 120,
      render: (value: string) => {
        const typeMap: Record<string, string> = {
          user: "用户",
          sync_item: "同步数据",
          media_asset: "媒体",
          app_version: "版本",
        };
        return typeMap[value] ?? value;
      },
    },
    {
      title: "目标 ID",
      dataIndex: "targetId",
      width: 180,
      ellipsis: true,
      render: (value: string) => (
        <code
          style={{
            fontSize: 12,
            color: "var(--color-text-muted)",
            background: "var(--color-bg-soft)",
            padding: "2px 6px",
            borderRadius: 4,
          }}
        >
          {value.slice(0, 8)}...
        </code>
      ),
    },
    {
      title: "IP",
      dataIndex: "ip",
      width: 140,
    },
    {
      title: "时间",
      dataIndex: "createdAt",
      width: 180,
      className: "table-date",
      render: (value: string) => formatDateTime(value),
    },
    {
      title: "操作",
      width: 100,
      className: "table-actions",
      render: (_, row) => (
        <Button type="link" onClick={() => setDetail(row)}>
          详情
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
            <AuditOutlined /> 操作日志
          </>
        }
        title="管理端审计"
        subtitle="查看管理端访问用户与数据详情的审计记录。"
        extra={
          <Button
            icon={<ReloadOutlined />}
            onClick={() => void load(page, pageSize)}
          >
            刷新
          </Button>
        }
      />
      <div className="toolbar-card">
        <div className="toolbar">
          <Input.Search
            allowClear
            prefix={<SearchOutlined />}
            placeholder="搜索动作，例如「查看用户」或「admin.users.view」"
            style={{ width: 420 }}
            value={action}
            onChange={(event) => setAction(event.target.value)}
            onSearch={() => void load(1, pageSize)}
          />
          <Button type="primary" ghost onClick={() => void load(1, pageSize)}>
            筛选
          </Button>
          <div className="toolbar-spacer" />
          <Space size={8} wrap>
            <Tag
              color={action === "" ? "orange" : "default"}
              style={{ cursor: "pointer" }}
              onClick={() => {
                setAction("");
                void load(1, pageSize);
              }}
            >
              全部
            </Tag>
            <Tag
              color={action.includes(".view") ? "blue" : "default"}
              style={{ cursor: "pointer" }}
              onClick={() => {
                setAction(".view");
                void load(1, pageSize);
              }}
            >
              <EyeOutlined /> 查看
            </Tag>
            <Tag
              color={action.includes(".download") ? "cyan" : "default"}
              style={{ cursor: "pointer" }}
              onClick={() => {
                setAction(".download");
                void load(1, pageSize);
              }}
            >
              <DownloadOutlined /> 下载
            </Tag>
            <Tag
              color={action.includes(".delete") ? "red" : "default"}
              style={{ cursor: "pointer" }}
              onClick={() => {
                setAction(".delete");
                void load(1, pageSize);
              }}
            >
              <DeleteOutlined /> 删除
            </Tag>
            <Tag
              color={
                action.includes(".create") || action.includes(".update")
                  ? "green"
                  : "default"
              }
              style={{ cursor: "pointer" }}
              onClick={() => {
                setAction(".create");
                void load(1, pageSize);
              }}
            >
              创建/更新
            </Tag>
          </Space>
        </div>
      </div>
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
          rowKey="id"
          loading={loading}
          columns={columns}
          dataSource={items}
          tableLayout="fixed"
          onChange={handleTableChange}
          pagination={{ current: page, pageSize, total, showSizeChanger: true }}
          locale={{
            emptyText: (
              <Empty description="暂无操作日志，管理员查看用户或数据详情时会记录审计日志" />
            ),
          }}
        />
      </Card>
      <Modal
        title="操作日志详情"
        open={Boolean(detail)}
        onCancel={() => setDetail(null)}
        footer={null}
        width={820}
        className="detail-modal"
      >
        {detail && (
          <Space orientation="vertical" size={16} style={{ width: "100%" }}>
            <Descriptions column={1} bordered size="middle">
              <Descriptions.Item label="动作">
                {(() => {
                  const info = getActionInfo(detail.action);
                  return (
                    <Space>
                      <Tag color={info.color} icon={info.icon}>
                        {info.label}
                      </Tag>
                      <code
                        style={{
                          fontSize: 12,
                          color: "var(--color-text-muted)",
                        }}
                      >
                        {detail.action}
                      </code>
                    </Space>
                  );
                })()}
              </Descriptions.Item>
              <Descriptions.Item label="操作者">
                <Space>
                  <UserOutlined />
                  <span>{detail.actor.nickname}</span>
                  <span style={{ color: "var(--color-text-muted)" }}>
                    ({detail.actor.username})
                  </span>
                </Space>
              </Descriptions.Item>
              <Descriptions.Item label="目标类型">
                {(() => {
                  const typeMap: Record<string, string> = {
                    user: "用户",
                    sync_item: "同步数据",
                    media_asset: "媒体",
                    app_version: "版本",
                  };
                  const targetType = detail.targetType ?? "";
                  return typeMap[targetType] ?? targetType;
                })()}
              </Descriptions.Item>
              <Descriptions.Item label="目标 ID">
                <code
                  style={{
                    fontSize: 12,
                    color: "var(--color-text-muted)",
                    background: "var(--color-bg-soft)",
                    padding: "4px 8px",
                    borderRadius: 4,
                    wordBreak: "break-all",
                  }}
                >
                  {detail.targetId}
                </code>
              </Descriptions.Item>
              <Descriptions.Item label="IP 地址">{detail.ip}</Descriptions.Item>
              <Descriptions.Item label="操作时间">
                <Space orientation="vertical" size={2}>
                  <span>{formatDateTime(detail.createdAt)}</span>
                  <span
                    style={{ fontSize: 12, color: "var(--color-text-muted)" }}
                  >
                    {formatDateTimeFull(detail.createdAt)}
                  </span>
                </Space>
              </Descriptions.Item>
            </Descriptions>
          </Space>
        )}
      </Modal>
    </>
  );
}
