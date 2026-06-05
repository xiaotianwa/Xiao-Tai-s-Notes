import {
  EditOutlined,
  EnvironmentOutlined,
  HeartFilled,
  PictureOutlined,
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

import MediaThumb from '../components/MediaThumb';
import PageHeader from '../components/PageHeader';

import { getItemDetail, getItems } from '../api/admin';
import { ApiError } from '../api/client';
import type { AdminSyncItem } from '../api/types';
import { formatDateTime } from '../utils/format';

interface EntryData {
  id?: string;
  kind?: string;
  kindLabel?: string;
  title?: string;
  content?: string;
  mood?: string;
  moodEmoji?: string;
  location?: string | null;
  tags: string[];
  draft: boolean;
  imagePaths: string[];
  imageMediaIds: string[];
  createdAt?: string;
  favorite?: boolean;
  mascotVariant?: string;
}

const kindLabels: Record<string, string> = {
  diary: '日记',
  list: '清单',
  mood: '心情',
};

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function readString(value: unknown): string | undefined {
  return typeof value === 'string' ? value : undefined;
}

function readStringList(value: unknown): string[] {
  return Array.isArray(value)
    ? value.filter((item): item is string => typeof item === 'string')
    : [];
}

function readBoolean(value: unknown): boolean {
  return typeof value === 'boolean' ? value : false;
}

function asEntry(item: AdminSyncItem): EntryData {
  const data = isRecord(item.data) ? item.data : {};
  return {
    id: readString(data.id),
    kind: readString(data.kind),
    kindLabel: readString(data.kindLabel),
    title: readString(data.title),
    content: readString(data.content),
    mood: readString(data.mood),
    moodEmoji: readString(data.moodEmoji),
    location: readString(data.location) ?? null,
    tags: readStringList(data.tags),
    draft: readBoolean(data.draft),
    imagePaths: readStringList(data.imagePaths),
    imageMediaIds: readStringList(data.imageMediaIds),
    createdAt: readString(data.createdAt),
    favorite: readBoolean(data.favorite),
    mascotVariant: readString(data.mascotVariant),
  };
}

function entryKindText(data: EntryData): string {
  return data.kindLabel ?? kindLabels[data.kind ?? ''] ?? data.kind ?? '记录';
}

function uploadedMediaIds(data: EntryData): string[] {
  return data.imageMediaIds.filter((id) => id.trim().length > 0);
}

function localOnlyImageCount(data: EntryData): number {
  return Math.max(0, data.imagePaths.length - uploadedMediaIds(data).length);
}

export default function EntriesPage(): React.JSX.Element {
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
        type: 'entry',
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
        requestError instanceof ApiError ? requestError.message : '记录加载失败',
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

  const detailEntry = detail ? asEntry(detail) : null;

  return (
    <>
      <PageHeader
        eyebrow={
          <>
            <EditOutlined /> 记录
          </>
        }
        title="用户日常记录"
        subtitle="按用户、关键词查看用户在 APP 中记录的日记、清单和心情。"
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
            <Empty description="暂无记录，用户在 APP 中创建日记、清单或心情记录后会显示在这里。" />
          ) : (
            <Row gutter={[16, 16]}>
              {items.map((item) => {
                const data = asEntry(item);
                const mediaIds = uploadedMediaIds(data);
                const localOnlyCount = localOnlyImageCount(data);
                return (
                  <Col key={item.id} xs={24} sm={12} md={12} lg={8} xl={8} xxl={6}>
                    <Card
                      hoverable
                      size="small"
                      style={{ height: '100%' }}
                      onClick={() => void openDetail(item.id)}
                      title={
                        <Space size={6}>
                          {data.favorite && (
                            <HeartFilled style={{ color: 'var(--color-danger)' }} />
                          )}
                          <span>{data.title || '(无标题)'}</span>
                        </Space>
                      }
                      extra={<Tag color="blue">{entryKindText(data)}</Tag>}
                    >
                      <div
                        style={{
                          minHeight: 64,
                          color: 'var(--color-text-muted)',
                          whiteSpace: 'pre-wrap',
                          display: '-webkit-box',
                          WebkitLineClamp: 3,
                          WebkitBoxOrient: 'vertical',
                          overflow: 'hidden',
                        }}
                      >
                        {data.content || '(无内容)'}
                      </div>
                      <Space size={[6, 6]} wrap style={{ marginTop: 10 }}>
                        {data.draft && <Tag color="gold">草稿</Tag>}
                        {data.location && (
                          <Tag icon={<EnvironmentOutlined />} color="purple">
                            {data.location}
                          </Tag>
                        )}
                        {data.tags.slice(0, 3).map((tag) => (
                          <Tag key={tag}>{tag}</Tag>
                        ))}
                      </Space>
                      {mediaIds.length > 0 && (
                        <div
                          style={{
                            marginTop: 10,
                            display: 'flex',
                            gap: 6,
                            flexWrap: 'wrap',
                          }}
                          onClick={(event) => event.stopPropagation()}
                        >
                          {mediaIds.slice(0, 3).map((id) => (
                            <MediaThumb
                              key={id}
                              mediaId={id}
                              size={56}
                              rounded={6}
                              preview
                            />
                          ))}
                        </div>
                      )}
                      <div
                        style={{
                          marginTop: 12,
                          display: 'flex',
                          justifyContent: 'space-between',
                          alignItems: 'center',
                          fontSize: 12,
                          color: 'var(--color-text-muted)',
                        }}
                      >
                        <Space size={6}>
                          <span>{data.moodEmoji ?? '😊'}</span>
                          <span>{data.mood ?? '-'}</span>
                          {localOnlyCount > 0 && (
                            <Tag icon={<PictureOutlined />} color="default">
                              本地 {localOnlyCount}
                            </Tag>
                          )}
                        </Space>
                        <span>{item.nickname}</span>
                      </div>
                      <div
                        style={{
                          marginTop: 6,
                          fontSize: 12,
                          color: 'var(--color-text-muted)',
                        }}
                      >
                        {formatDateTime(data.createdAt ?? item.clientUpdatedAt)}
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
        title="记录详情"
        open={Boolean(detail)}
        onCancel={() => setDetail(null)}
        footer={null}
        width={920}
        className="detail-modal"
      >
        {detail && detailEntry && (
          <Space direction="vertical" size={16} style={{ width: '100%' }}>
            <Descriptions column={1} bordered size="middle">
              <Descriptions.Item label="用户">
                {detail.nickname} / {detail.username}
              </Descriptions.Item>
              <Descriptions.Item label="类型">
                {entryKindText(detailEntry)}
              </Descriptions.Item>
              <Descriptions.Item label="标题">
                {detailEntry.title ?? '-'}
              </Descriptions.Item>
              <Descriptions.Item label="草稿">
                {detailEntry.draft ? '是' : '否'}
              </Descriptions.Item>
              <Descriptions.Item label="心情">
                {detailEntry.moodEmoji ?? ''} {detailEntry.mood ?? '-'}
              </Descriptions.Item>
              <Descriptions.Item label="位置">
                {detailEntry.location ?? '-'}
              </Descriptions.Item>
              <Descriptions.Item label="标签">
                {detailEntry.tags.length > 0
                  ? detailEntry.tags.map((tag) => <Tag key={tag}>{tag}</Tag>)
                  : '-'}
              </Descriptions.Item>
              <Descriptions.Item label="是否收藏">
                {detailEntry.favorite ? '是' : '否'}
              </Descriptions.Item>
              <Descriptions.Item label="图片">
                {(() => {
                  const ids = uploadedMediaIds(detailEntry);
                  const totalImages = detailEntry.imagePaths.length;
                  const localOnly = localOnlyImageCount(detailEntry);
                  if (ids.length === 0 && localOnly === 0) {
                    return '无';
                  }
                  return (
                    <span>
                      已上传 {ids.length} 张
                      {localOnly > 0 && `，本地未上传 ${localOnly} 张`}
                      {totalImages > 0 && `，共 ${totalImages} 张`}
                    </span>
                  );
                })()}
              </Descriptions.Item>
              <Descriptions.Item label="创建时间">
                {formatDateTime(detailEntry.createdAt)}
              </Descriptions.Item>
              <Descriptions.Item label="同步时间">
                {formatDateTime(detail.serverUpdatedAt)}
              </Descriptions.Item>
            </Descriptions>
            {uploadedMediaIds(detailEntry).length > 0 && (
              <Card size="small" title="图片" className="soft-card">
                <div style={{ display: 'flex', gap: 12, flexWrap: 'wrap' }}>
                  {uploadedMediaIds(detailEntry).map((id) => (
                    <MediaThumb
                      key={id}
                      mediaId={id}
                      size={160}
                      rounded={10}
                      preview
                    />
                  ))}
                </div>
              </Card>
            )}
            <Card size="small" title="正文" className="soft-card">
              <div style={{ whiteSpace: 'pre-wrap' }}>
                {detailEntry.content || '(无内容)'}
              </div>
            </Card>
          </Space>
        )}
      </Modal>
    </>
  );
}
