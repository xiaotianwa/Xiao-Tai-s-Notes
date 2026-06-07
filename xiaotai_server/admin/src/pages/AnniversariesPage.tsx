import {
  CalendarOutlined,
  HeartOutlined,
  PushpinFilled,
  ReloadOutlined,
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
  Space,
  Table,
  Tag,
} from 'antd';
import type { ColumnsType, TablePaginationConfig } from 'antd/es/table';
import { useEffect, useMemo, useState } from 'react';

import { getAnniversaryItems, getItemDetail } from '../api/admin';
import { ApiError } from '../api/client';
import type { AdminSyncItem } from '../api/types';
import PageHeader from '../components/PageHeader';
import { formatDateTime } from '../utils/format';

interface AnniversaryData {
  id?: string;
  title?: string;
  date?: string;
  category?: string;
  colorName?: string;
  mascotVariant?: string;
  imagePath?: string | null;
  note?: string;
  showCountUp: boolean;
  pinnedOnHome: boolean;
}

const categoryLabels: Record<string, string> = {
  love: '爱情',
  birthday: '生日',
  life: '生活',
  travel: '旅行',
  study: '学习',
  other: '其他',
};

const categoryColors: Record<string, string> = {
  love: 'pink',
  birthday: 'gold',
  life: 'blue',
  travel: 'cyan',
  study: 'green',
  other: 'default',
};

const colorLabels: Record<string, string> = {
  pink: '樱花粉',
  purple: '浅紫',
  orange: '暖橙',
  yellow: '奶油黄',
  green: '薄荷绿',
  blue: '晴空蓝',
  lavender: '薰衣草',
};

export default function AnniversariesPage(): React.JSX.Element {
  const [items, setItems] = useState<AdminSyncItem[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(20);
  const [userId, setUserId] = useState('');
  const [keyword, setKeyword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [detail, setDetail] = useState<AdminSyncItem | null>(null);

  async function load(nextPage = page, nextPageSize = pageSize): Promise<void> {
    setLoading(true);
    setError(null);
    try {
      const result = await getAnniversaryItems({
        page: nextPage,
        pageSize: nextPageSize,
        userId,
        keyword,
        deleted: 'false',
      });
      setItems(result.items);
      setTotal(result.total);
      setPage(result.page);
      setPageSize(result.pageSize);
    } catch (requestError) {
      setError(
        requestError instanceof ApiError
          ? requestError.message
          : '纪念日记录加载失败',
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
          : '纪念日详情加载失败',
      );
    }
  }

  useEffect(() => {
    void load(1, pageSize);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const columns = useMemo<ColumnsType<AdminSyncItem>>(
    () => [
      {
        title: '用户',
        dataIndex: 'nickname',
        width: 140,
        render: (_, row) => (
          <div className="sync-business-cell">
            <div className="sync-business-title">{row.nickname}</div>
            <div className="sync-business-desc">{row.username}</div>
          </div>
        ),
      },
      {
        title: '纪念日',
        dataIndex: 'data',
        render: (_, row) => {
          const data = asAnniversary(row);
          return (
            <div className="sync-business-cell">
              <div className="sync-business-title">
                {data.pinnedOnHome && (
                  <PushpinFilled style={{ color: 'var(--color-warn)' }} />
                )}
                <span style={{ marginLeft: data.pinnedOnHome ? 6 : 0 }}>
                  {data.title || '(无标题)'}
                </span>
              </div>
              <div className="sync-business-desc">
                {data.note?.trim() || '暂无备注'}
              </div>
              <div className="sync-business-meta">
                <Tag color={categoryColors[data.category ?? ''] ?? 'default'}>
                  {categoryLabel(data.category)}
                </Tag>
                <Tag>{data.showCountUp ? '正数日' : '倒数日'}</Tag>
                {data.pinnedOnHome && <Tag color="orange">首页固定</Tag>}
              </div>
            </div>
          );
        },
      },
      {
        title: '日期',
        dataIndex: 'data',
        width: 160,
        render: (_, row) => formatDateOnly(asAnniversary(row).date),
      },
      {
        title: '计时',
        dataIndex: 'data',
        width: 120,
        render: (_, row) => {
          const data = asAnniversary(row);
          const metric = anniversaryMetric(data);
          return (
            <Tag color={data.showCountUp ? 'blue' : 'green'}>
              {metric.label} {metric.days} 天
            </Tag>
          );
        },
      },
      {
        title: '同步时间',
        dataIndex: 'serverUpdatedAt',
        width: 180,
        className: 'table-date',
        render: (value: string) => formatDateTime(value),
      },
      {
        title: '操作',
        width: 96,
        className: 'table-actions',
        render: (_, row) => (
          <Button type="link" onClick={() => void openDetail(row.id)}>
            详情
          </Button>
        ),
      },
    ],
    [],
  );

  const detailData = detail ? asAnniversary(detail) : null;

  function handleTableChange(pagination: TablePaginationConfig): void {
    void load(pagination.current ?? 1, pagination.pageSize ?? 20);
  }

  return (
    <>
      <PageHeader
        eyebrow={
          <>
            <HeartOutlined /> 纪念日
          </>
        }
        title="用户纪念日记录"
        subtitle="查看 App 同步到服务器的纪念日、倒数日和首页固定记录。"
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
            placeholder="搜索标题、备注或分类"
            style={{ width: 340 }}
            value={keyword}
            onChange={(event) => setKeyword(event.target.value)}
            onSearch={() => void load(1, pageSize)}
          />
          <Input.Search
            allowClear
            placeholder="按用户 ID 筛选"
            style={{ width: 260 }}
            value={userId}
            onChange={(event) => setUserId(event.target.value)}
            onSearch={() => void load(1, pageSize)}
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
          pagination={{
            current: page,
            pageSize,
            total,
            showSizeChanger: true,
            pageSizeOptions: ['20', '50', '100'],
          }}
          locale={{
            emptyText: (
              <Empty description="暂无纪念日记录，App 同步后会显示在这里" />
            ),
          }}
        />
      </Card>
      <Modal
        title="纪念日详情"
        open={Boolean(detail)}
        onCancel={() => setDetail(null)}
        footer={null}
        width={860}
        className="detail-modal"
      >
        {detail && detailData && (
          <Space orientation="vertical" size={16} style={{ width: '100%' }}>
            <Descriptions column={1} bordered size="middle">
              <Descriptions.Item label="用户">
                {detail.nickname} / {detail.username}
              </Descriptions.Item>
              <Descriptions.Item label="标题">
                {detailData.title ?? '-'}
              </Descriptions.Item>
              <Descriptions.Item label="日期">
                {formatDateOnly(detailData.date)}
              </Descriptions.Item>
              <Descriptions.Item label="计时方式">
                {detailData.showCountUp ? '正数日' : '倒数日'}，
                {anniversaryMetric(detailData).label}{' '}
                {anniversaryMetric(detailData).days} 天
              </Descriptions.Item>
              <Descriptions.Item label="分类">
                <Tag color={categoryColors[detailData.category ?? ''] ?? 'default'}>
                  {categoryLabel(detailData.category)}
                </Tag>
              </Descriptions.Item>
              <Descriptions.Item label="颜色">
                {colorLabel(detailData.colorName)}
              </Descriptions.Item>
              <Descriptions.Item label="吉祥物">
                {detailData.mascotVariant ?? '-'}
              </Descriptions.Item>
              <Descriptions.Item label="首页固定">
                {detailData.pinnedOnHome ? '是' : '否'}
              </Descriptions.Item>
              <Descriptions.Item label="备注">
                {detailData.note?.trim() || '-'}
              </Descriptions.Item>
              <Descriptions.Item label="客户端 ID">
                <span className="table-mono-text">{detail.clientId}</span>
              </Descriptions.Item>
              <Descriptions.Item label="客户端更新时间">
                {formatDateTime(detail.clientUpdatedAt)}
              </Descriptions.Item>
              <Descriptions.Item label="服务端同步时间">
                {formatDateTime(detail.serverUpdatedAt)}
              </Descriptions.Item>
            </Descriptions>
            <div>
              <div className="json-preview-title">原始同步内容</div>
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

function asAnniversary(item: AdminSyncItem): AnniversaryData {
  const data = isRecord(item.data) ? item.data : {};
  return {
    id: readString(data.id),
    title: readString(data.title),
    date: readString(data.date),
    category: readString(data.category),
    colorName: readString(data.colorName),
    mascotVariant: readString(data.mascotVariant),
    imagePath: readString(data.imagePath),
    note: readString(data.note),
    showCountUp: data.showCountUp === true,
    pinnedOnHome: data.pinnedOnHome === true,
  };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function readString(value: unknown): string | undefined {
  return typeof value === 'string' && value.trim() !== ''
    ? value.trim()
    : undefined;
}

function categoryLabel(value?: string): string {
  return value ? categoryLabels[value] ?? value : '-';
}

function colorLabel(value?: string): string {
  return value ? colorLabels[value] ?? value : '-';
}

function anniversaryMetric(data: AnniversaryData): {
  label: string;
  days: number;
} {
  const date = parseDate(data.date);
  if (!date) {
    return { label: data.showCountUp ? '已记录' : '还有', days: 0 };
  }
  const today = startOfDay(new Date());
  if (data.showCountUp) {
    const start = startOfDay(date);
    const days = today < start ? 0 : daysBetween(start, today) + 1;
    return { label: '已记录', days };
  }
  const target = new Date(today.getFullYear(), date.getMonth(), date.getDate());
  const next = target < today
    ? new Date(today.getFullYear() + 1, date.getMonth(), date.getDate())
    : target;
  return { label: '还有', days: daysBetween(today, next) };
}

function parseDate(value?: string): Date | null {
  if (!value) {
    return null;
  }
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}

function startOfDay(date: Date): Date {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

function daysBetween(start: Date, end: Date): number {
  return Math.floor((end.getTime() - start.getTime()) / 86_400_000);
}

function formatDateOnly(value?: string): string {
  const date = parseDate(value);
  if (!date) {
    return '-';
  }
  return `${date.getFullYear()}年${pad2(date.getMonth() + 1)}月${pad2(
    date.getDate(),
  )}日`;
}

function pad2(value: number): string {
  return String(value).padStart(2, '0');
}
