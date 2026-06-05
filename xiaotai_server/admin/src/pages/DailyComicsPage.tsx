import {
  ArrowDownOutlined,
  ArrowUpOutlined,
  BookOutlined,
  DeleteOutlined,
  EditOutlined,
  FileImageOutlined,
  PlusOutlined,
  ReloadOutlined,
  SearchOutlined,
  UploadOutlined,
} from '@ant-design/icons';
import {
  Alert,
  Button,
  Card,
  DatePicker,
  Empty,
  Form,
  Input,
  message,
  Modal,
  Popconfirm,
  Select,
  Space,
  Switch,
  Table,
  Tag,
  Tooltip,
  Typography,
  Upload,
} from 'antd';
import type { ColumnsType, TablePaginationConfig } from 'antd/es/table';
import type { UploadProps } from 'antd/es/upload';
import dayjs from 'dayjs';
import { useEffect, useMemo, useRef, useState } from 'react';

import {
  createDailyComic,
  deleteDailyComic,
  getDailyComics,
  type DailyComicImageInput,
  type DailyComicInput,
  updateDailyComic,
  uploadDailyComicImage,
} from '../api/admin';
import { resolveApiAssetUrl } from '../api/client';
import type { AdminDailyComic } from '../api/types';
import PageHeader from '../components/PageHeader';
import { formatDateTime } from '../utils/format';
import { showSuccessToast } from '../utils/operationToast';

const { TextArea } = Input;

interface DailyComicFormValues {
  title: string;
  description?: string;
  publishDate: dayjs.Dayjs;
  enabled: boolean;
}

interface ComicImageDraft {
  key: string;
  imageUrl?: string;
  originalName?: string;
  mimeType?: string;
  size?: number;
  file?: File;
  previewUrl: string;
}

export default function DailyComicsPage(): React.JSX.Element {
  const [items, setItems] = useState<AdminDailyComic[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(20);
  const [keyword, setKeyword] = useState('');
  const [enabled, setEnabled] = useState<string | undefined>();
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [modalOpen, setModalOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [imageDrafts, setImageDrafts] = useState<ComicImageDraft[]>([]);
  const imageDraftsRef = useRef<ComicImageDraft[]>([]);
  const [form] = Form.useForm<DailyComicFormValues>();
  const watchedValues = Form.useWatch([], form) as
    | Partial<DailyComicFormValues>
    | undefined;

  const firstPreviewUrl = useMemo(
    () => imageDrafts[0]?.previewUrl ?? null,
    [imageDrafts],
  );

  useEffect(() => {
    void load(1, pageSize);
  }, []);

  useEffect(() => {
    imageDraftsRef.current = imageDrafts;
  }, [imageDrafts]);

  useEffect(() => {
    return () => revokeDraftPreviews(imageDraftsRef.current);
  }, []);

  async function load(nextPage = page, nextPageSize = pageSize): Promise<void> {
    setLoading(true);
    setError(null);
    try {
      const result = await getDailyComics({
        page: nextPage,
        pageSize: nextPageSize,
        keyword,
        enabled,
      });
      setItems(result.items);
      setTotal(result.total);
      setPage(result.page);
      setPageSize(result.pageSize);
    } catch (requestError: unknown) {
      setError(errorMessage(requestError, '每日漫画列表加载失败'));
    } finally {
      setLoading(false);
    }
  }

  async function handleSubmit(): Promise<void> {
    const values = await form.validateFields();
    if (imageDrafts.length === 0) {
      void message.error('每日漫画至少需要 1 张图片');
      return;
    }
    if (imageDrafts.length > 10) {
      void message.error('每日漫画最多只能上传 10 张图片');
      return;
    }

    setSaving(true);
    setError(null);
    try {
      const images = await uploadPendingImages(imageDrafts);
      const payload: DailyComicInput = {
        title: values.title.trim(),
        description: values.description?.trim() || undefined,
        publishDate: values.publishDate.format('YYYY-MM-DD'),
        enabled: values.enabled,
        images,
      };

      if (editingId) {
        await updateDailyComic(editingId, payload);
        showSuccessToast('每日漫画已更新');
      } else {
        await createDailyComic(payload);
        showSuccessToast('每日漫画已发布');
      }

      closeEditor();
      await load(1, pageSize);
    } catch (requestError: unknown) {
      setError(errorMessage(requestError, '保存每日漫画失败'));
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete(id: string): Promise<void> {
    setError(null);
    try {
      await deleteDailyComic(id);
      showSuccessToast('每日漫画已删除');
      await load(page, pageSize);
    } catch (requestError: unknown) {
      setError(errorMessage(requestError, '删除每日漫画失败'));
    }
  }

  async function handleToggleEnabled(record: AdminDailyComic): Promise<void> {
    setError(null);
    try {
      await updateDailyComic(record.id, { enabled: !record.enabled });
      showSuccessToast(`每日漫画已${record.enabled ? '停用' : '启用'}`);
      await load(page, pageSize);
    } catch (requestError: unknown) {
      setError(errorMessage(requestError, '状态更新失败'));
    }
  }

  function openCreateModal(): void {
    resetDrafts();
    setEditingId(null);
    form.setFieldsValue({
      title: '',
      description: '',
      publishDate: dayjs(),
      enabled: true,
    });
    setModalOpen(true);
  }

  function openEditModal(record: AdminDailyComic): void {
    resetDrafts();
    setEditingId(record.id);
    form.setFieldsValue({
      title: record.title,
      description: record.description ?? '',
      publishDate: dayjs(record.publishDate),
      enabled: record.enabled,
    });
    setImageDrafts(
      record.images.map((image) => ({
        key: image.id,
        imageUrl: image.imageUrl,
        originalName: image.originalName ?? undefined,
        mimeType: image.mimeType ?? undefined,
        size: image.size ?? undefined,
        previewUrl: resolveApiAssetUrl(image.imageUrl),
      })),
    );
    setModalOpen(true);
  }

  function closeEditor(): void {
    setModalOpen(false);
    setEditingId(null);
    form.resetFields();
    resetDrafts();
  }

  function resetDrafts(): void {
    setImageDrafts((current) => {
      revokeDraftPreviews(current);
      return [];
    });
  }

  function removeDraft(key: string): void {
    setImageDrafts((current) => {
      const target = current.find((item) => item.key === key);
      if (target) {
        revokeDraftPreviews([target]);
      }
      return current.filter((item) => item.key !== key);
    });
  }

  function moveDraft(key: string, direction: -1 | 1): void {
    setImageDrafts((current) => {
      const index = current.findIndex((item) => item.key === key);
      const targetIndex = index + direction;
      if (index < 0 || targetIndex < 0 || targetIndex >= current.length) {
        return current;
      }
      const next = [...current];
      const [draft] = next.splice(index, 1);
      if (!draft) {
        return current;
      }
      next.splice(targetIndex, 0, draft);
      return next;
    });
  }

  const uploadProps: UploadProps = {
    accept: 'image/png,image/jpeg,image/webp',
    multiple: true,
    showUploadList: false,
    beforeUpload: (file) => {
      const isImage = ['image/jpeg', 'image/png', 'image/webp'].includes(
        file.type,
      );
      if (!isImage) {
        void message.error('仅支持 JPG、PNG、WebP 图片');
        return Upload.LIST_IGNORE;
      }
      if (file.size > 5 * 1024 * 1024) {
        void message.error('漫画图片不能超过 5MB');
        return Upload.LIST_IGNORE;
      }
      setImageDrafts((current) => {
        if (current.length >= 10) {
          void message.error('每日漫画最多只能上传 10 张图片');
          return current;
        }
        return [
          ...current,
          {
            key: `${file.uid}-${Date.now()}`,
            file,
            originalName: file.name,
            mimeType: file.type,
            size: file.size,
            previewUrl: URL.createObjectURL(file),
          },
        ];
      });
      return false;
    },
  };

  const columns: ColumnsType<AdminDailyComic> = [
    {
      title: '发布日期',
      dataIndex: 'publishDate',
      width: 130,
      render: (value: string) => dayjs(value).format('YYYY年M月D日'),
    },
    {
      title: '标题',
      dataIndex: 'title',
      width: 360,
      ellipsis: true,
      render: (value: string, record) => (
        <Space direction="vertical" size={4}>
          <strong className="table-primary-text table-clip">{value}</strong>
          {record.description && (
            <Typography.Text type="secondary" ellipsis style={{ maxWidth: 360 }}>
              {record.description}
            </Typography.Text>
          )}
        </Space>
      ),
    },
    {
      title: '图片',
      dataIndex: 'images',
      width: 110,
      render: (_, record) => (
        <Tag color={record.images.length > 0 ? 'blue' : 'default'}>
          {record.images.length}/10 张
        </Tag>
      ),
    },
    {
      title: '状态',
      dataIndex: 'enabled',
      width: 110,
      render: (value: boolean, record) => (
        <Switch
          checked={value}
          checkedChildren="启用"
          unCheckedChildren="停用"
          onChange={() => void handleToggleEnabled(record)}
        />
      ),
    },
    {
      title: '更新时间',
      dataIndex: 'updatedAt',
      width: 180,
      className: "table-date",
      render: (value: string) => formatDateTime(value),
    },
    {
      title: '操作',
      width: 150,
      className: "table-actions",
      render: (_, record) => (
        <Space>
          <Button
            type="link"
            icon={<EditOutlined />}
            onClick={() => openEditModal(record)}
          >
            编辑
          </Button>
          <Popconfirm
            title="删除每日漫画"
            description="确认删除这条每日漫画？"
            okText="确认删除"
            okButtonProps={{ danger: true }}
            cancelText="取消"
            onConfirm={() => void handleDelete(record.id)}
          >
            <Button type="link" danger icon={<DeleteOutlined />}>
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
        eyebrow={
          <>
            <BookOutlined /> 小笨漫画
          </>
        }
        title="每日漫画"
        subtitle="通过管理端上传每日漫画图片，APP 首页的小笨漫画入口会展示最新启用内容。"
        extra={
          <Space wrap>
            <Button icon={<ReloadOutlined />} onClick={() => void load()}>
              刷新
            </Button>
            <Button
              type="primary"
              icon={<PlusOutlined />}
              onClick={openCreateModal}
            >
              新建漫画
            </Button>
          </Space>
        }
      />

      <div className="toolbar">
        <Input.Search
          allowClear
          prefix={<SearchOutlined />}
          placeholder="搜索标题或说明"
          style={{ width: 320 }}
          value={keyword}
          onChange={(event) => setKeyword(event.target.value)}
          onSearch={() => void load(1, pageSize)}
        />
        <Select
          allowClear
          placeholder="状态"
          style={{ width: 120 }}
          value={enabled}
          options={[
            { value: 'true', label: '启用' },
            { value: 'false', label: '停用' },
          ]}
          onChange={(value) => setEnabled(value)}
        />
        <Button type="primary" ghost onClick={() => void load(1, pageSize)}>
          筛选
        </Button>
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
            emptyText: (
              <Empty description="暂无每日漫画，点击右上角新建第一条漫画。" />
            ),
          }}
        />
      </Card>

      <Modal
        title={
          <Space size={10}>
            <BookOutlined />
            <span>{editingId ? '编辑每日漫画' : '新建每日漫画'}</span>
          </Space>
        }
        open={modalOpen}
        width={1040}
        okText={editingId ? '保存漫画' : '发布漫画'}
        cancelText="取消"
        confirmLoading={saving}
        onCancel={closeEditor}
        onOk={() => void handleSubmit()}
        destroyOnClose
      >
        <Form form={form} layout="vertical" className="comic-editor-form">
          <div className="comic-editor-grid">
            <div className="comic-editor-fields">
              <Form.Item
                label="漫画标题"
                name="title"
                rules={[{ required: true, message: '请输入漫画标题' }]}
              >
                <Input placeholder="例如：今天的小笨漫画" maxLength={80} />
              </Form.Item>
              <Form.Item
                label="发布日期"
                name="publishDate"
                rules={[{ required: true, message: '请选择发布日期' }]}
              >
                <DatePicker format="YYYY年M月D日" style={{ width: '100%' }} />
              </Form.Item>
              <Form.Item label="漫画说明" name="description">
                <TextArea
                  rows={4}
                  placeholder="可选，写一点今天漫画的说明"
                  maxLength={500}
                  showCount
                />
              </Form.Item>
              <Form.Item label="启用状态" name="enabled" valuePropName="checked">
                <Switch checkedChildren="启用" unCheckedChildren="停用" />
              </Form.Item>

              <div className="comic-image-section">
                <Space align="center" style={{ marginBottom: 10 }}>
                  <Typography.Text strong>漫画图片</Typography.Text>
                  <Tag color={imageDrafts.length > 10 ? 'red' : 'blue'}>
                    {imageDrafts.length}/10 张
                  </Tag>
                </Space>
                <Upload.Dragger {...uploadProps} className="comic-image-uploader">
                  <p className="ant-upload-drag-icon">
                    <FileImageOutlined />
                  </p>
                  <p className="ant-upload-text">上传漫画图片</p>
                  <p className="ant-upload-hint">
                    支持多选，JPG / PNG / WebP，单张最大 5MB，一期最多 10 张。
                  </p>
                </Upload.Dragger>

                <div className="comic-image-grid">
                  {imageDrafts.map((draft, index) => (
                    <div className="comic-image-card" key={draft.key}>
                      <div className="comic-image-thumb">
                        <img src={draft.previewUrl} alt={`漫画第 ${index + 1} 张`} />
                        <span>{index + 1}</span>
                      </div>
                      <Tooltip title={draft.originalName ?? draft.imageUrl ?? '漫画图片'}>
                        <Typography.Text ellipsis>
                          {draft.originalName ?? draft.imageUrl ?? '漫画图片'}
                        </Typography.Text>
                      </Tooltip>
                      <Space size={4}>
                        <Button
                          size="small"
                          icon={<ArrowUpOutlined />}
                          disabled={index === 0}
                          onClick={() => moveDraft(draft.key, -1)}
                        />
                        <Button
                          size="small"
                          icon={<ArrowDownOutlined />}
                          disabled={index === imageDrafts.length - 1}
                          onClick={() => moveDraft(draft.key, 1)}
                        />
                        <Button
                          size="small"
                          danger
                          icon={<DeleteOutlined />}
                          onClick={() => removeDraft(draft.key)}
                        />
                      </Space>
                    </div>
                  ))}
                </div>
              </div>
            </div>

            <aside className="comic-preview-panel">
              <div className="comic-preview-phone">
                <div className="comic-preview-title">
                  {watchedValues?.title || '每日漫画'}
                </div>
                <div className="comic-preview-date">
                  {watchedValues?.publishDate?.format('YYYY年M月D日') ??
                    dayjs().format('YYYY年M月D日')}
                </div>
                <div className="comic-preview-image">
                  {firstPreviewUrl ? (
                    <img src={firstPreviewUrl} alt="APP 漫画首图预览" />
                  ) : (
                    <div>
                      <UploadOutlined />
                      <span>上传后预览首图</span>
                    </div>
                  )}
                </div>
                <div className="comic-preview-count">
                  共 {imageDrafts.length} 张，APP 端按当前顺序查看
                </div>
              </div>
            </aside>
          </div>
        </Form>
      </Modal>
    </>
  );
}

async function uploadPendingImages(
  drafts: ComicImageDraft[],
): Promise<DailyComicImageInput[]> {
  const images: DailyComicImageInput[] = [];
  for (const draft of drafts) {
    if (draft.file) {
      const formData = new FormData();
      formData.append('image', draft.file);
      images.push(await uploadDailyComicImage(formData));
    } else if (draft.imageUrl) {
      images.push({
        imageUrl: draft.imageUrl,
        originalName: draft.originalName,
        mimeType: draft.mimeType,
        size: draft.size,
      });
    }
  }
  return images;
}

function revokeDraftPreviews(drafts: ComicImageDraft[]): void {
  for (const draft of drafts) {
    if (draft.previewUrl.startsWith('blob:')) {
      URL.revokeObjectURL(draft.previewUrl);
    }
  }
}

function errorMessage(error: unknown, fallback: string): string {
  return error instanceof Error && error.message ? error.message : fallback;
}
