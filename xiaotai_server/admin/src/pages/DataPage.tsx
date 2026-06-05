import {
  DatabaseOutlined,
  DeleteOutlined,
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
  Popconfirm,
  Select,
  Space,
  Table,
  Tag,
} from 'antd';
import type { ColumnsType, TablePaginationConfig } from 'antd/es/table';
import { useEffect, useState } from 'react';

import PageHeader from '../components/PageHeader';

import { deleteSyncItem, getItemDetail, getItems } from '../api/admin';
import { ApiError } from '../api/client';
import type { AdminSyncItem } from '../api/types';
import { formatDateTime, typeLabel } from '../utils/format';

const typeOptions = [
  'entry',
  'memo',
  'reminder',
  'weekly_goal',
  'anniversary',
  'place',
  'ai_message',
  'ai_memory',
  'settings',
].map((value) => ({ value, label: typeLabel(value) }));

export default function DataPage(): React.JSX.Element {
  const [items, setItems] = useState<AdminSyncItem[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(20);
  const [keyword, setKeyword] = useState('');
  const [type, setType] = useState<string | undefined>();
  const [loading, setLoading] = useState(false);
  const [deletingId, setDeletingId] = useState<string | null>(null);
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

  useEffect(() => {
    void load(1, pageSize);
  }, []);

  const columns: ColumnsType<AdminSyncItem> = [
    { title: '用户', dataIndex: 'nickname', width: 140 },
    {
      title: '类型',
      dataIndex: 'type',
      width: 130,
      render: (value: string) => <Tag color="blue">{typeLabel(value)}</Tag>,
    },
    {
      title: '客户端 ID',
      dataIndex: 'clientId',
      width: 280,
      ellipsis: true,
      render: (value: string) => (
        <span className="table-mono-text table-clip">{value}</span>
      ),
    },
    { title: '版本', dataIndex: 'version', width: 80 },
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
      width: 180,
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
          <Select
            allowClear
            placeholder="数据类型"
            style={{ width: 200 }}
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
