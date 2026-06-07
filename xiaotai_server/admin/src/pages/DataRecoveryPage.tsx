import {
  EyeOutlined,
  ReloadOutlined,
  RollbackOutlined,
  SearchOutlined,
} from "@ant-design/icons";
import {
  Alert,
  Button,
  Card,
  Descriptions,
  Empty,
  Input,
  Modal,
  Popconfirm,
  Select,
  Space,
  Table,
  Tag,
} from "antd";
import type { ColumnsType, TablePaginationConfig } from "antd/es/table";
import { useEffect, useState } from "react";
import { useSearchParams } from "react-router-dom";

import { getItemDetail, getItems, restoreSyncItem } from "../api/admin";
import { ApiError } from "../api/client";
import type { AdminSyncItem } from "../api/types";
import PageHeader from "../components/PageHeader";
import { formatDateTime, typeLabel } from "../utils/format";
import { showSuccessToast } from "../utils/operationToast";
import { buildSyncItemSummary } from "../utils/syncItemSummary";

const typeOptions = [
  "entry",
  "memo",
  "reminder",
  "anniversary",
  "place",
  "couple_task",
  "weekly_goal",
  "money_record",
  "ai_message",
  "settings",
].map((value) => ({ value, label: typeLabel(value) }));

export default function DataRecoveryPage(): React.JSX.Element {
  const [searchParams] = useSearchParams();
  const [items, setItems] = useState<AdminSyncItem[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(20);
  const [keyword, setKeyword] = useState(searchParams.get("keyword") ?? "");
  const [type, setType] = useState<string | undefined>(
    searchParams.get("type") ?? undefined,
  );
  const [userId, setUserId] = useState(searchParams.get("userId") ?? "");
  const [loading, setLoading] = useState(false);
  const [restoringId, setRestoringId] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const [detail, setDetail] = useState<AdminSyncItem | null>(null);

  async function load(nextPage = page, nextPageSize = pageSize): Promise<void> {
    setLoading(true);
    setError(null);
    try {
      const result = await getItems({
        page: nextPage,
        pageSize: nextPageSize,
        keyword,
        type,
        userId,
        deleted: "true",
      });
      setItems(result.items);
      setTotal(result.total);
      setPage(result.page);
      setPageSize(result.pageSize);
    } catch (requestError) {
      setError(
        requestError instanceof ApiError
          ? requestError.message
          : "已删除数据加载失败",
      );
    } finally {
      setLoading(false);
    }
  }

  async function openDetail(id: string): Promise<void> {
    try {
      setDetail(await getItemDetail(id));
    } catch (requestError) {
      setError(
        requestError instanceof ApiError
          ? requestError.message
          : "详情加载失败",
      );
    }
  }

  async function restore(row: AdminSyncItem): Promise<void> {
    setRestoringId(row.id);
    setError(null);
    try {
      const result = await restoreSyncItem(row.id);
      showSuccessToast(`${buildSyncItemSummary(result.item).title} 已恢复`);
      setDetail((current) => (current?.id === row.id ? result.item : current));
      await load(page, pageSize);
    } catch (requestError) {
      setError(
        requestError instanceof ApiError
          ? requestError.message
          : "恢复失败，请稍后重试",
      );
    } finally {
      setRestoringId(null);
    }
  }

  useEffect(() => {
    void load(1, pageSize);
  }, []);

  const columns: ColumnsType<AdminSyncItem> = [
    {
      title: "用户",
      width: 140,
      render: (_, row) => (
        <div className="sync-business-cell">
          <div className="sync-business-title">{row.nickname}</div>
          <div className="sync-business-desc">{row.username}</div>
        </div>
      ),
    },
    {
      title: "类型",
      dataIndex: "type",
      width: 110,
      render: (value: string) => <Tag color="blue">{typeLabel(value)}</Tag>,
    },
    {
      title: "已删除内容",
      render: (_, row) => <BusinessSummaryCell item={row} />,
    },
    {
      title: "删除时间",
      dataIndex: "deletedAt",
      width: 180,
      className: "table-date",
      render: (value: string | null) => formatDateTime(value),
    },
    {
      title: "版本",
      dataIndex: "version",
      width: 80,
    },
    {
      title: "操作",
      width: 150,
      className: "table-actions",
      render: (_, row) => (
        <Space size={4}>
          <Button
            type="link"
            icon={<EyeOutlined />}
            onClick={() => void openDetail(row.id)}
          >
            详情
          </Button>
          <Popconfirm
            title="恢复这条 APP 数据？"
            description="恢复后会同步回 APP，客户端下次同步时会重新获得这条记录。"
            okText="恢复"
            cancelText="取消"
            onConfirm={() => void restore(row)}
          >
            <Button
              type="link"
              icon={<RollbackOutlined />}
              loading={restoringId === row.id}
            >
              恢复
            </Button>
          </Popconfirm>
        </Space>
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
            <RollbackOutlined /> 数据恢复
          </>
        }
        title="已删除同步数据"
        subtitle="集中查看从管理端或同步链路标记删除的 APP 数据，并在误删后恢复到下一轮同步。"
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
      <Alert
        type="info"
        showIcon
        title="恢复会生成新的同步版本"
        description="恢复操作不会修改业务 JSON 内容，只会清空删除时间、刷新服务端更新时间并递增版本，方便 APP 正常拉取。"
        style={{ marginBottom: 16 }}
      />
      <div className="toolbar-card">
        <div className="toolbar">
          <Input.Search
            allowClear
            prefix={<SearchOutlined />}
            placeholder="搜索客户端 ID 或 JSON 内容"
            style={{ width: 320 }}
            value={keyword}
            onChange={(event) => setKeyword(event.target.value)}
            onSearch={() => void load(1, pageSize)}
          />
          <Input
            allowClear
            placeholder="按用户 ID 筛选"
            style={{ width: 240 }}
            value={userId}
            onChange={(event) => setUserId(event.target.value)}
          />
          <Select
            allowClear
            placeholder="数据类型"
            style={{ width: 180 }}
            value={type}
            options={typeOptions}
            onChange={(value) => setType(value)}
          />
          <Button type="primary" ghost onClick={() => void load(1, pageSize)}>
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
            emptyText: <Empty description="暂无可恢复的已删除同步数据" />,
          }}
        />
      </Card>
      <Modal
        title="已删除数据详情"
        open={Boolean(detail)}
        onCancel={() => setDetail(null)}
        footer={null}
        width={920}
        className="detail-modal"
      >
        {detail && (
          <Space orientation="vertical" size={16} style={{ width: "100%" }}>
            <Descriptions column={1} bordered size="middle">
              <Descriptions.Item label="用户">
                {detail.nickname} / {detail.username}
              </Descriptions.Item>
              <Descriptions.Item label="类型">
                {typeLabel(detail.type)}
              </Descriptions.Item>
              <Descriptions.Item label="客户端 ID">
                {detail.clientId}
              </Descriptions.Item>
              <Descriptions.Item label="业务摘要">
                <BusinessSummaryCell item={detail} />
              </Descriptions.Item>
              <Descriptions.Item label="删除时间">
                {formatDateTime(detail.deletedAt)}
              </Descriptions.Item>
              <Descriptions.Item label="服务端更新时间">
                {formatDateTime(detail.serverUpdatedAt)}
              </Descriptions.Item>
            </Descriptions>
            <div>
              <div className="json-preview-title">数据内容（JSON）</div>
              <pre className="json-preview">
                {JSON.stringify(detail.data, null, 2)}
              </pre>
            </div>
          </Space>
        )}
      </Modal>
    </>
  );
}

function BusinessSummaryCell({
  item,
}: {
  item: AdminSyncItem;
}): React.JSX.Element {
  const summary = buildSyncItemSummary(item);
  return (
    <div className="sync-business-cell">
      <div className="sync-business-title">{summary.title}</div>
      <div className="sync-business-desc">{summary.description}</div>
      {summary.meta.length > 0 && (
        <div className="sync-business-meta">
          {summary.meta.map((value) => (
            <Tag key={value}>{value}</Tag>
          ))}
        </div>
      )}
    </div>
  );
}
