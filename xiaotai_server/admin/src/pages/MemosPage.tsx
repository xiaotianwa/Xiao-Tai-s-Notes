import {
  FileTextOutlined,
  PushpinFilled,
  ReloadOutlined,
  SearchOutlined,
} from '@ant-design/icons';
import {
  Alert,
  Button,
  Card,
  Col,
  Descriptions,
  Empty,
  Input,
  Modal,
  Pagination,
  Row,
  Space,
  Spin,
  Tag,
} from 'antd';
import { useEffect, useState } from 'react';

import PageHeader from '../components/PageHeader';

import { getItemDetail, getItems } from '../api/admin';
import { ApiError } from '../api/client';
import type { AdminSyncItem } from '../api/types';
import { formatDateTime } from '../utils/format';

interface MemoData {
  id?: string;
  title?: string;
  content?: string;
  createdAt?: string;
  updatedAt?: string;
  mood?: string | null;
  tags: string[];
  remindAt?: string | null;
  imagePaths: string[];
  imageMediaIds: string[];
  draft: boolean;
  pinned?: boolean;
}

function asMemo(item: AdminSyncItem): MemoData {
  const data = isRecord(item.data) ? item.data : {};
  return {
    id: readString(data.id),
    title: readString(data.title),
    content: readString(data.content),
    createdAt: readString(data.createdAt),
    updatedAt: readString(data.updatedAt),
    mood: readString(data.mood),
    tags: readStringList(data.tags),
    remindAt: readString(data.remindAt),
    imagePaths: readStringList(data.imagePaths),
    imageMediaIds: readStringList(data.imageMediaIds),
    draft: data.draft === true,
    pinned: data.pinned === true,
  };
}

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null;
}

function readString(value: unknown): string | undefined {
  return typeof value === 'string' && value.trim() !== ''
    ? value.trim()
    : undefined;
}

function readStringList(value: unknown): string[] {
  return Array.isArray(value)
    ? value.filter((item): item is string => typeof item === 'string')
    : [];
}

export default function MemosPage(): React.JSX.Element {
  const [items, setItems] = useState<AdminSyncItem[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(12);
  const [userId, setUserId] = useState('');
  const [keyword, setKeyword] = useState('');
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [detail, setDetail] = useState<AdminSyncItem | null>(null);

  async function load(nextPage = page, nextPageSize = pageSize): Promise<void> {
    setLoading(true);
    setError(null);
    try {
      const result = await getItems({
        page: nextPage,
        pageSize: nextPageSize,
        type: 'memo',
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
          : '备忘录加载失败',
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

  useEffect(() => {
    void load(1, pageSize);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  const detailMemo = detail ? asMemo(detail) : null;

  return (
    <>
      <PageHeader
        eyebrow={
          <>
            <FileTextOutlined /> 备忘录
          </>
        }
        title="用户备忘录"
        subtitle="查看用户在 APP 中创建的备忘录卡片。"
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
            placeholder="搜索标题或内容"
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
          style={{ marginBottom: 16 }}
          closable
          onClose={() => setError(null)}
        />
      )}
      <Card className="soft-card">
        <Spin spinning={loading}>
          {items.length === 0 ? (
            <Empty description="暂无备忘录，用户在 APP 中创建备忘录后会显示在这里" />
          ) : (
            <Row gutter={[16, 16]}>
              {items.map((item) => {
                const data = asMemo(item);
                return (
                  <Col
                    key={item.id}
                    xs={24}
                    sm={12}
                    md={12}
                    lg={8}
                    xl={8}
                    xxl={6}
                  >
                    <Card
                      hoverable
                      size="small"
                      style={{ height: '100%' }}
                      onClick={() => void openDetail(item.id)}
                      title={
                        <Space size={6}>
                          {data.pinned && (
                            <PushpinFilled
                              style={{ color: 'var(--color-warn)' }}
                            />
                          )}
                          <span>{data.title || '(无标题)'}</span>
                        </Space>
                      }
                      extra={
                        <Space size={4} wrap>
                          {data.draft && <Tag>草稿</Tag>}
                          {data.pinned && <Tag color="orange">置顶</Tag>}
                        </Space>
                      }
                    >
                      <Space size={[4, 4]} wrap style={{ marginBottom: 10 }}>
                        {data.mood && <Tag color="magenta">{data.mood}</Tag>}
                        {data.tags.map((tag) => (
                          <Tag key={tag}>{tag}</Tag>
                        ))}
                        {data.remindAt && <Tag color="blue">有提醒</Tag>}
                        {data.imagePaths.length > 0 && (
                          <Tag color="cyan">{data.imagePaths.length} 张图片</Tag>
                        )}
                      </Space>
                      <div
                        style={{
                          minHeight: 80,
                          color: 'var(--color-text-muted)',
                          whiteSpace: 'pre-wrap',
                          display: '-webkit-box',
                          WebkitLineClamp: 4,
                          WebkitBoxOrient: 'vertical',
                          overflow: 'hidden',
                        }}
                      >
                        {data.content || '(无内容)'}
                      </div>
                      <div
                        style={{
                          marginTop: 12,
                          display: 'flex',
                          justifyContent: 'space-between',
                          fontSize: 12,
                          color: 'var(--color-text-muted)',
                        }}
                      >
                        <span>{item.nickname}</span>
                        <span>
                          {formatDateTime(data.updatedAt ?? item.clientUpdatedAt)}
                        </span>
                      </div>
                    </Card>
                  </Col>
                );
              })}
            </Row>
          )}
        </Spin>
        <div
          style={{
            marginTop: 16,
            display: 'flex',
            justifyContent: 'flex-end',
          }}
        >
          <Pagination
            current={page}
            pageSize={pageSize}
            total={total}
            showSizeChanger
            pageSizeOptions={['12', '24', '48']}
            onChange={(nextPage, nextPageSize) =>
              void load(nextPage, nextPageSize)
            }
          />
        </div>
      </Card>
      <Modal
        title="备忘录详情"
        open={Boolean(detail)}
        onCancel={() => setDetail(null)}
        footer={null}
        width={860}
        className="detail-modal"
      >
        {detail && detailMemo && (
          <Space orientation="vertical" size={16} style={{ width: '100%' }}>
            <Descriptions column={1} bordered size="middle">
              <Descriptions.Item label="用户">
                {detail.nickname} / {detail.username}
              </Descriptions.Item>
              <Descriptions.Item label="标题">
                {detailMemo.title ?? '-'}
              </Descriptions.Item>
              <Descriptions.Item label="置顶">
                {detailMemo.pinned ? '是' : '否'}
              </Descriptions.Item>
              <Descriptions.Item label="草稿">
                {detailMemo.draft ? '是' : '否'}
              </Descriptions.Item>
              <Descriptions.Item label="心情">
                {detailMemo.mood ?? '-'}
              </Descriptions.Item>
              <Descriptions.Item label="标签">
                {detailMemo.tags.length > 0 ? (
                  <Space size={[4, 4]} wrap>
                    {detailMemo.tags.map((tag) => (
                      <Tag key={tag}>{tag}</Tag>
                    ))}
                  </Space>
                ) : (
                  '-'
                )}
              </Descriptions.Item>
              <Descriptions.Item label="提醒时间">
                {formatDateTime(detailMemo.remindAt)}
              </Descriptions.Item>
              <Descriptions.Item label="本地图片">
                {detailMemo.imagePaths.length > 0
                  ? `${detailMemo.imagePaths.length} 张`
                  : '-'}
              </Descriptions.Item>
              <Descriptions.Item label="媒体 ID">
                {detailMemo.imageMediaIds.length > 0
                  ? detailMemo.imageMediaIds.filter(Boolean).join('、') || '-'
                  : '-'}
              </Descriptions.Item>
              <Descriptions.Item label="创建时间">
                {formatDateTime(detailMemo.createdAt)}
              </Descriptions.Item>
              <Descriptions.Item label="更新时间">
                {formatDateTime(detailMemo.updatedAt)}
              </Descriptions.Item>
              <Descriptions.Item label="同步时间">
                {formatDateTime(detail.serverUpdatedAt)}
              </Descriptions.Item>
            </Descriptions>
            <Card size="small" title="正文" className="soft-card">
              <div style={{ whiteSpace: 'pre-wrap' }}>
                {detailMemo.content || '(无内容)'}
              </div>
            </Card>
          </Space>
        )}
      </Modal>
    </>
  );
}
