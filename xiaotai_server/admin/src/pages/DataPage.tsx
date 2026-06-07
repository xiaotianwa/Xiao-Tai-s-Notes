import {
  DatabaseOutlined,
  DeleteOutlined,
  ReloadOutlined,
  RollbackOutlined,
  SearchOutlined,
} from '@ant-design/icons';
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
} from 'antd';
import type { ColumnsType, TablePaginationConfig } from 'antd/es/table';
import { useEffect, useState } from 'react';
import { useSearchParams } from 'react-router-dom';

import PageHeader from '../components/PageHeader';

import { deleteSyncItem, getItemDetail, getItems, restoreSyncItem } from '../api/admin';
import { ApiError } from '../api/client';
import type { AdminSyncItem } from '../api/types';
import { formatDateTime, typeLabel } from '../utils/format';
import { showSuccessToast } from '../utils/operationToast';

const typeOptions = [
  'entry',
  'memo',
  'reminder',
  'anniversary',
  'place',
  'couple_task',
  'weekly_goal',
  'money_record',
  'ai_message',
  'settings',
].map((value) => ({ value, label: typeLabel(value) }));

const deletedOptions = [
  { value: 'false', label: '正常数据' },
  { value: 'true', label: '已删除数据' },
];

interface BusinessSummary {
  title: string;
  description: string;
  meta: string[];
}

export default function DataPage(): React.JSX.Element {
  const [searchParams] = useSearchParams();
  const [items, setItems] = useState<AdminSyncItem[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(20);
  const [keyword, setKeyword] = useState(searchParams.get('keyword') ?? '');
  const [type, setType] = useState<string | undefined>(
    searchParams.get('type') ?? undefined,
  );
  const [deleted, setDeleted] = useState<string | undefined>(
    searchParams.get('deleted') ?? 'false',
  );
  const [userId, setUserId] = useState(searchParams.get('userId') ?? '');
  const [loading, setLoading] = useState(false);
  const [deletingId, setDeletingId] = useState<string | null>(null);
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
        deleted,
      });
      setItems(result.items);
      setTotal(result.total);
      setPage(result.page);
      setPageSize(result.pageSize);
    } catch (requestError) {
      setError(
        requestError instanceof ApiError ? requestError.message : '数据加载失败',
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
        requestError instanceof ApiError ? requestError.message : '详情加载失败',
      );
    }
  }

  async function removeItem(row: AdminSyncItem): Promise<void> {
    setDeletingId(row.id);
    setError(null);
    try {
      const result = await deleteSyncItem(row.id);
      setItems((current) =>
        current.map((item) => (item.id === row.id ? result.item : item)),
      );
      setDetail((current) => (current?.id === row.id ? result.item : current));
      await load(page, pageSize);
    } catch (requestError) {
      setError(
        requestError instanceof ApiError ? requestError.message : '删除失败',
      );
    } finally {
      setDeletingId(null);
    }
  }

  async function restoreItem(row: AdminSyncItem): Promise<void> {
    setRestoringId(row.id);
    setError(null);
    try {
      const result = await restoreSyncItem(row.id);
      showSuccessToast(`${buildBusinessSummary(result.item).title} 已恢复`);
      setItems((current) =>
        current.map((item) => (item.id === row.id ? result.item : item)),
      );
      setDetail((current) => (current?.id === row.id ? result.item : current));
      await load(page, pageSize);
    } catch (requestError) {
      setError(
        requestError instanceof ApiError ? requestError.message : '恢复失败',
      );
    } finally {
      setRestoringId(null);
    }
  }

  useEffect(() => {
    void load(1, pageSize);
  }, []);

  const columns: ColumnsType<AdminSyncItem> = [
    { title: '用户', dataIndex: 'nickname', width: 120 },
    {
      title: '类型',
      dataIndex: 'type',
      width: 120,
      render: (value: string) => <Tag color="blue">{typeLabel(value)}</Tag>,
    },
    {
      title: '业务内容',
      dataIndex: 'data',
      render: (_, row) => {
        const summary = buildBusinessSummary(row);
        return (
          <div className="sync-business-cell">
            <div className="sync-business-title">{summary.title}</div>
            <div className="sync-business-desc">{summary.description}</div>
            {summary.meta.length > 0 && (
              <div className="sync-business-meta">
                {summary.meta.map((item) => (
                  <Tag key={item}>{item}</Tag>
                ))}
              </div>
            )}
          </div>
        );
      },
    },
    {
      title: '客户端 ID',
      dataIndex: 'clientId',
      width: 210,
      ellipsis: true,
      render: (value: string) => (
        <span className="table-mono-text table-clip">{value}</span>
      ),
    },
    { title: '版本', dataIndex: 'version', width: 70 },
    {
      title: '删除',
      dataIndex: 'deletedAt',
      width: 90,
      render: (value: string | null) =>
        value ? <Tag color="red">已删除</Tag> : <Tag color="green">正常</Tag>,
    },
    {
      title: '服务端更新时间',
      dataIndex: 'serverUpdatedAt',
      width: 170,
      className: "table-date",
      render: (value: string) => formatDateTime(value),
    },
    {
      title: '操作',
      width: 150,
      className: "table-actions",
      render: (_, row) => (
        <Space size={4}>
          <Button type="link" onClick={() => void openDetail(row.id)}>
            详情
          </Button>
          {row.deletedAt && (
            <Popconfirm
              title="恢复这条 APP 数据？"
              description="恢复后会同步回 APP，客户端下次同步时会重新获得这条记录。"
              okText="恢复"
              cancelText="取消"
              onConfirm={() => void restoreItem(row)}
            >
              <Button
                type="link"
                icon={<RollbackOutlined />}
                loading={restoringId === row.id}
              >
                恢复
              </Button>
            </Popconfirm>
          )}
          <Popconfirm
            title="确认删除这条 APP 数据？"
            description="删除后会同步到 APP，本地对应内容将在下次同步时移除。"
            okText="删除"
            cancelText="取消"
            okButtonProps={{ danger: true }}
            disabled={Boolean(row.deletedAt)}
            onConfirm={() => void removeItem(row)}
          >
            <Button
              danger
              type="link"
              icon={<DeleteOutlined />}
              disabled={Boolean(row.deletedAt)}
              loading={deletingId === row.id}
            >
              删除
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
        eyebrow={<><DatabaseOutlined /> APP 数据</>}
        title="同步数据浏览"
        subtitle="按用户、类型和关键词查看同步到私有服务端的数据记录。"
        extra={
          <Button icon={<ReloadOutlined />} onClick={() => void load(page, pageSize)}>
            刷新
          </Button>
        }
      />
      <div className="toolbar-card">
        <div className="toolbar">
          <Input.Search
            allowClear
            prefix={<SearchOutlined />}
            placeholder="搜索客户端 ID 或 JSON 内容"
            style={{ width: 340 }}
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
            style={{ width: 200 }}
            value={type}
            options={typeOptions}
            onChange={(value) => setType(value)}
          />
          <Select
            allowClear
            placeholder="删除状态"
            style={{ width: 160 }}
            value={deleted}
            options={deletedOptions}
            onChange={(value) => setDeleted(value)}
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
          title="加载失败"
          description={error}
          action={<Button size="small" type="link" onClick={() => void load()}>重试</Button>}
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
        locale={{ emptyText: <Empty description="暂无同步数据，用户在 APP 中创建记录后会同步到这里" /> }}
      />
      </Card>
      <Modal
        title="数据详情"
        open={Boolean(detail)}
        onCancel={() => setDetail(null)}
        footer={null}
        width={920}
        className="detail-modal"
      >
        {detail && (
          <Space orientation="vertical" size={16} style={{ width: '100%' }}>
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
                <BusinessSummaryView item={detail} />
              </Descriptions.Item>
              <Descriptions.Item label="版本">{detail.version}</Descriptions.Item>
              <Descriptions.Item label="删除状态">
                {detail.deletedAt ? (
                  <Tag color="red">已删除于 {formatDateTime(detail.deletedAt)}</Tag>
                ) : (
                  <Tag color="green">正常</Tag>
                )}
              </Descriptions.Item>
              <Descriptions.Item label="客户端更新时间">
                {formatDateTime(detail.clientUpdatedAt)}
              </Descriptions.Item>
              <Descriptions.Item label="服务端更新时间">
                {formatDateTime(detail.serverUpdatedAt)}
              </Descriptions.Item>
            </Descriptions>
            <div>
              <div style={{ marginBottom: 8, fontWeight: 600, color: 'var(--color-text)' }}>
                数据内容（JSON）
              </div>
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

function BusinessSummaryView({
  item,
}: {
  item: AdminSyncItem;
}): React.JSX.Element {
  const summary = buildBusinessSummary(item);
  return (
    <div className="sync-business-cell sync-business-cell-detail">
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

function buildBusinessSummary(item: AdminSyncItem): BusinessSummary {
  const data = readRecord(item.data);
  const deletedPrefix = item.deletedAt ? '已删除 · ' : '';
  const fallbackTitle = `${deletedPrefix}${typeLabel(item.type)} / ${item.clientId}`;
  switch (item.type) {
    case 'entry':
      return {
        title: deletedPrefix + firstText(data, ['title'], fallbackTitle),
        description: clipText(firstText(data, ['content'], '暂无正文')),
        meta: compact([
          firstText(data, ['kindLabel', 'kind']),
          firstText(data, ['mood']),
          readStringList(data, 'tags').join('、'),
        ]),
      };
    case 'memo':
      return {
        title: deletedPrefix + firstText(data, ['title'], fallbackTitle),
        description: clipText(firstText(data, ['content'], '暂无内容')),
        meta: compact([
          readBoolean(data, 'pinned') ? '置顶' : '',
          firstText(data, ['mood']),
          readStringList(data, 'tags').join('、'),
        ]),
      };
    case 'reminder':
      return {
        title: deletedPrefix + firstText(data, ['title'], fallbackTitle),
        description: compact([
          formatDateTime(readString(data, 'scheduledAt')),
          firstText(data, ['repeatRule']),
        ]).join(' · '),
        meta: compact([
          readBoolean(data, 'completed') ? '已完成' : '待提醒',
          firstText(data, ['priority']),
        ]),
      };
    case 'anniversary':
      return {
        title: deletedPrefix + firstText(data, ['title'], fallbackTitle),
        description: compact([
          formatDateTime(readString(data, 'date')),
          firstText(data, ['note'], '暂无备注'),
        ]).join(' · '),
        meta: compact([
          firstText(data, ['category']),
          readBoolean(data, 'showCountUp') ? '正数日' : '倒数日',
          readBoolean(data, 'pinnedOnHome') ? '首页显示' : '',
        ]),
      };
    case 'place':
      return {
        title: deletedPrefix + firstText(data, ['title'], fallbackTitle),
        description: clipText(firstText(data, ['description'], '暂无描述')),
        meta: compact([
          firstText(data, ['category']),
          firstText(data, ['colorName']),
        ]),
      };
    case 'couple_task':
      return {
        title: deletedPrefix + firstText(data, ['title'], fallbackTitle),
        description: compact([
          readBoolean(data, 'completed') ? '已完成' : '未完成',
          formatDateTime(readString(data, 'completedAt')),
        ]).join(' · '),
        meta: compact([`序号 ${readNumber(data, 'index') ?? '-'}`]),
      };
    case 'weekly_goal':
      return {
        title: deletedPrefix + firstText(data, ['title'], fallbackTitle),
        description: formatGoalProgress(data),
        meta: compact([
          firstText(data, ['period']),
          firstText(data, ['unit']),
          firstText(data, ['colorName']),
        ]),
      };
    case 'money_record':
      return {
        title: deletedPrefix + firstText(data, ['title'], fallbackTitle),
        description: compact([
          readString(data, 'type') === 'income' ? '收入' : '支出',
          formatAmount(readNumber(data, 'amountCents')),
          firstText(data, ['category']),
          formatDateTime(readString(data, 'happenedAt')),
        ]).join(' · '),
        meta: compact([
          firstText(data, ['owner']),
          firstText(data, ['paymentMethod']),
        ]),
      };
    case 'ai_message':
      return {
        title:
          deletedPrefix +
          `${roleLabel(readString(data, 'role'))} / ${item.clientId}`,
        description: clipText(firstText(data, ['content'], '暂无对话内容')),
        meta: compact([formatDateTime(readString(data, 'createdAt'))]),
      };
    case 'settings':
      return {
        title: `${deletedPrefix}个人资料与偏好设置`,
        description: compact([
          firstText(data, ['profileName']),
          firstText(data, ['profileMotto']),
          `主题 ${firstText(data, ['themeId'], '-')}`,
        ]).join(' · '),
        meta: compact([
          readBoolean(data, 'notificationsEnabled') ? '通知开启' : '通知关闭',
          readBoolean(data, 'lockPreviewEnabled') ? '锁屏预览' : '',
        ]),
      };
    default:
      return {
        title: deletedPrefix + firstText(data, ['title', 'name', 'id'], fallbackTitle),
        description: clipText(JSON.stringify(data)),
        meta: [],
      };
  }
}

function readRecord(value: unknown): Record<string, unknown> {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    return {};
  }
  return value as Record<string, unknown>;
}

function firstText(
  data: Record<string, unknown>,
  keys: string[],
  fallback = '',
): string {
  for (const key of keys) {
    const value = readString(data, key);
    if (value) {
      return value;
    }
  }
  return fallback;
}

function readString(data: Record<string, unknown>, key: string): string {
  const value = data[key];
  if (typeof value === 'string') {
    return value.trim();
  }
  if (typeof value === 'number' || typeof value === 'boolean') {
    return String(value);
  }
  return '';
}

function readNumber(
  data: Record<string, unknown>,
  key: string,
): number | undefined {
  const value = data[key];
  return typeof value === 'number' && Number.isFinite(value) ? value : undefined;
}

function readBoolean(data: Record<string, unknown>, key: string): boolean {
  return data[key] === true;
}

function readStringList(
  data: Record<string, unknown>,
  key: string,
): string[] {
  const value = data[key];
  if (!Array.isArray(value)) {
    return [];
  }
  return value.filter((item): item is string => typeof item === 'string');
}

function compact(values: Array<string | undefined>): string[] {
  return values
    .map((value) => value?.trim() ?? '')
    .filter((value, index, array) => value.length > 0 && array.indexOf(value) === index);
}

function clipText(value: string): string {
  const normalized = value.replace(/\s+/g, ' ').trim();
  if (!normalized) {
    return '-';
  }
  return normalized.length > 86 ? `${normalized.slice(0, 86)}...` : normalized;
}

function formatGoalProgress(data: Record<string, unknown>): string {
  const current = readNumber(data, 'currentValue');
  const target = readNumber(data, 'targetValue');
  const unit = readString(data, 'unit');
  if (current === undefined && target === undefined) {
    return '暂无进度';
  }
  return `${current ?? 0}/${target ?? '-'}${unit}`;
}

function formatAmount(cents?: number): string {
  if (cents === undefined) {
    return '金额未知';
  }
  return `${(cents / 100).toFixed(2)} 元`;
}

function roleLabel(role: string): string {
  if (role === 'user') {
    return '用户';
  }
  if (role === 'assistant') {
    return '助手';
  }
  return role || 'AI 对话';
}
