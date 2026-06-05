import {
  EnvironmentOutlined,
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
  Select,
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

interface PlaceData {
  id?: string;
  title?: string;
  description?: string;
  category?: string;
  colorName?: string;
  imagePath?: string;
  imageMediaId?: string;
}

const categoryLabels: Record<string, string> = {
  travel: '旅行',
  date: '约会',
};

const categoryColors: Record<string, string> = {
  travel: 'gold',
  date: 'pink',
};

const categoryOptions = [
  { value: 'travel', label: '旅行' },
  { value: 'date', label: '约会' },
];

function asPlace(item: AdminSyncItem): PlaceData {
  return (item.data ?? {}) as PlaceData;
}

export default function PlacesPage(): React.JSX.Element {
  const [items, setItems] = useState<AdminSyncItem[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(12);
  const [userId, setUserId] = useState('');
  const [keyword, setKeyword] = useState('');
  const [category, setCategory] = useState<string | undefined>();
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
        type: 'place',
        userId,
        keyword,
        deleted: 'false',
      });
      const filtered = category
        ? result.items.filter((item) => asPlace(item).category === category)
        : result.items;
      setItems(filtered);
      setTotal(result.total);
      setPage(result.page);
      setPageSize(result.pageSize);
    } catch (requestError) {
      setError(
        requestError instanceof ApiError
          ? requestError.message
          : '想去的地方加载失败',
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

  const detailPlace = detail ? asPlace(detail) : null;
  const detailMediaId = (detailPlace?.imageMediaId ?? '').trim();

  return (
    <>
      <PageHeader
        eyebrow={
          <>
            <EnvironmentOutlined /> 想去的地方
          </>
        }
        title="用户的想去地点"
        subtitle="查看用户在 APP 中收藏的想去的地方与心愿清单。"
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
            placeholder="搜索地点或描述"
            style={{ width: 300 }}
            value={keyword}
            onChange={(event) => setKeyword(event.target.value)}
            onSearch={() => void load(1, pageSize)}
          />
          <Input.Search
            allowClear
            placeholder="按用户 ID 筛选"
            style={{ width: 220 }}
            value={userId}
            onChange={(event) => setUserId(event.target.value)}
            onSearch={() => void load(1, pageSize)}
          />
          <Select
            allowClear
            placeholder="分类"
            style={{ width: 160 }}
            value={category}
            options={categoryOptions}
            onChange={(value) => setCategory(value)}
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
          title={error}
          style={{ marginBottom: 16 }}
        />
      )}
      <Card className="soft-card">
        <Spin spinning={loading}>
          {items.length === 0 ? (
            <Empty description="暂无想去的地方" />
          ) : (
            <Row gutter={[16, 16]}>
              {items.map((item) => {
                const data = asPlace(item);
                const categoryKey = data.category ?? 'travel';
                const mediaId = (data.imageMediaId ?? '').trim();
                const hasLocalOnly = !!data.imagePath && !mediaId;
                return (
                  <Col key={item.id} xs={24} sm={12} md={12} lg={8} xl={8} xxl={6}>
                <Card
                  hoverable
                  size="small"
                  style={{ height: '100%' }}
                  onClick={() => void openDetail(item.id)}
                  title={<span>{data.title || '(无标题)'}</span>}
                  extra={
                    <Tag color={categoryColors[categoryKey] ?? 'blue'}>
                      {categoryLabels[categoryKey] ?? categoryKey}
                    </Tag>
                  }
                >
                  {mediaId && (
                    <div
                      style={{ marginBottom: 10 }}
                      onClick={(event) => event.stopPropagation()}
                    >
                      <MediaThumb
                        mediaId={mediaId}
                        size={200}
                        rounded={8}
                        preview
                      />
                    </div>
                  )}
                  <div
                    style={{
                      minHeight: 56,
                      color: 'var(--color-text-muted)',
                      whiteSpace: 'pre-wrap',
                      display: '-webkit-box',
                      WebkitLineClamp: 3,
                      WebkitBoxOrient: 'vertical',
                      overflow: 'hidden',
                    }}
                  >
                    {data.description || '(无描述)'}
                  </div>
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
                      {hasLocalOnly && (
                        <Tag icon={<PictureOutlined />} color="default">
                          本地图
                        </Tag>
                      )}
                      <span>{item.nickname}</span>
                    </Space>
                    <span>{formatDateTime(item.clientUpdatedAt)}</span>
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
        title="地点详情"
        open={Boolean(detail)}
        onCancel={() => setDetail(null)}
        footer={null}
        width={860}
        className="detail-modal"
      >
        {detail && detailPlace && (
          <Space orientation="vertical" size={16} style={{ width: '100%' }}>
            <Descriptions column={1} bordered size="middle">
              <Descriptions.Item label="用户">
                {detail.nickname} / {detail.username}
              </Descriptions.Item>
              <Descriptions.Item label="标题">
                {detailPlace.title ?? '-'}
              </Descriptions.Item>
              <Descriptions.Item label="分类">
                {categoryLabels[detailPlace.category ?? ''] ??
                  detailPlace.category ??
                  '-'}
              </Descriptions.Item>
              <Descriptions.Item label="图片">
                {detailMediaId
                  ? '已上传到服务端'
                  : detailPlace.imagePath
                    ? '有（仅保存在用户手机本地，未上传服务端）'
                    : '无'}
              </Descriptions.Item>
              <Descriptions.Item label="同步时间">
                {formatDateTime(detail.serverUpdatedAt)}
              </Descriptions.Item>
            </Descriptions>
            {detailMediaId && (
              <Card size="small" title="图片" className="soft-card">
                <MediaThumb
                  mediaId={detailMediaId}
                  size={180}
                  rounded={10}
                  preview
                />
              </Card>
            )}
            <Card size="small" title="描述" className="soft-card">
              <div style={{ whiteSpace: 'pre-wrap' }}>
                {detailPlace.description || '(无描述)'}
              </div>
            </Card>
          </Space>
        )}
      </Modal>
    </>
  );
}
