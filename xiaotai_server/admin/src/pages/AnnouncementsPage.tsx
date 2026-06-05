import {
  BellOutlined,
  DeleteOutlined,
  EditOutlined,
  EyeOutlined,
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
  Flex,
  Form,
  Input,
  InputNumber,
  message,
  Modal,
  Popconfirm,
  Radio,
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
import type { ReactNode } from 'react';
import { useEffect, useMemo, useState } from 'react';

import PageHeader from '../components/PageHeader';
import {
  type AnnouncementInput,
  createAnnouncement,
  deleteAnnouncement,
  getAnnouncements,
  updateAnnouncement,
  uploadAnnouncementImage,
} from '../api/admin';
import { resolveApiAssetUrl } from '../api/client';
import type { AdminAnnouncement } from '../api/types';
import { formatDateTime } from '../utils/format';
import { showSuccessToast } from '../utils/operationToast';

const { RangePicker } = DatePicker;
const { TextArea } = Input;

interface AnnouncementFormValues {
  title: string;
  content: string;
  type: AdminAnnouncement['type'];
  priority: number;
  targetUsers?: string;
  imageUrl?: string;
  timeMode: 'permanent' | 'scheduled' | 'range';
  startAt?: dayjs.Dayjs;
  timeRange?: [dayjs.Dayjs, dayjs.Dayjs];
  enabled: boolean;
}

const typeOptions: Array<{
  value: AdminAnnouncement['type'];
  label: string;
  color: string;
}> = [
  { value: 'info', label: '信息', color: 'blue' },
  { value: 'warning', label: '警告', color: 'orange' },
  { value: 'success', label: '成功', color: 'green' },
  { value: 'error', label: '错误', color: 'red' },
];

export default function AnnouncementsPage(): React.JSX.Element {
  const [items, setItems] = useState<AdminAnnouncement[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(20);
  const [keyword, setKeyword] = useState('');
  const [type, setType] = useState<string | undefined>();
  const [enabled, setEnabled] = useState<string | undefined>();
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [modalOpen, setModalOpen] = useState(false);
  const [editingId, setEditingId] = useState<string | null>(null);
  const [imageFile, setImageFile] = useState<File | null>(null);
  const [imagePreviewUrl, setImagePreviewUrl] = useState<string | null>(null);
  const [form] = Form.useForm<AnnouncementFormValues>();
  const watchedValues = Form.useWatch([], form) as
    | Partial<AnnouncementFormValues>
    | undefined;

  const previewType =
    typeOptions.find((option) => option.value === watchedValues?.type) ??
    typeOptions[0];
  const previewImageUrl = useMemo(() => {
    if (imagePreviewUrl) {
      return imagePreviewUrl;
    }
    if (watchedValues?.imageUrl) {
      return resolveApiAssetUrl(watchedValues.imageUrl);
    }
    return null;
  }, [imagePreviewUrl, watchedValues?.imageUrl]);

  useEffect(() => {
    void load(1, pageSize);
  }, []);

  useEffect(() => {
    return () => {
      if (imagePreviewUrl?.startsWith('blob:')) {
        URL.revokeObjectURL(imagePreviewUrl);
      }
    };
  }, [imagePreviewUrl]);

  async function load(nextPage = page, nextPageSize = pageSize): Promise<void> {
    setLoading(true);
    setError(null);
    try {
      const result = await getAnnouncements({
        page: nextPage,
        pageSize: nextPageSize,
        keyword,
        type,
        enabled,
      });
      setItems(result.items);
      setTotal(result.total);
      setPage(result.page);
      setPageSize(result.pageSize);
    } catch (requestError: unknown) {
      setError(errorMessage(requestError, '公告列表加载失败'));
    } finally {
      setLoading(false);
    }
  }

  async function handleSubmit(): Promise<void> {
    const values = await form.validateFields();
    setSaving(true);
    setError(null);

    try {
      let imageUrl = values.imageUrl?.trim() || undefined;
      if (imageFile) {
        const formData = new FormData();
        formData.append('image', imageFile);
        const uploaded = await uploadAnnouncementImage(formData);
        imageUrl = uploaded.imageUrl;
      }

      const payload: AnnouncementInput = {
        title: values.title.trim(),
        content: values.content.trim(),
        type: values.type,
        priority: values.priority,
        targetUsers: values.targetUsers?.trim() || undefined,
        imageUrl,
        enabled: values.enabled,
      };

      if (values.timeMode === 'permanent') {
        payload.startAt = null;
        payload.endAt = null;
      } else if (values.timeMode === 'scheduled') {
        if (!values.startAt) {
          form.setFields([
            { name: 'startAt', errors: ['请选择发布时间'] },
          ]);
          setSaving(false);
          return;
        }
        payload.startAt = values.startAt.toISOString();
        payload.endAt = null;
      } else if (values.timeMode === 'range') {
        if (!values.timeRange) {
          form.setFields([
            { name: 'timeRange', errors: ['请选择生效时间范围'] },
          ]);
          setSaving(false);
          return;
        }
        if (!values.timeRange[0].isBefore(values.timeRange[1])) {
          form.setFields([
            { name: 'timeRange', errors: ['结束时间必须晚于开始时间'] },
          ]);
          setSaving(false);
          return;
        }
        payload.startAt = values.timeRange[0].toISOString();
        payload.endAt = values.timeRange[1].toISOString();
      }

      if (editingId) {
        await updateAnnouncement(editingId, payload);
        showSuccessToast('公告更新成功');
      } else {
        await createAnnouncement(payload);
        showSuccessToast('公告创建成功');
      }

      closeEditor();
      await load(1, pageSize);
    } catch (requestError: unknown) {
      setError(errorMessage(requestError, '操作失败，请检查网络连接后重试'));
    } finally {
      setSaving(false);
    }
  }

  async function handleDelete(id: string): Promise<void> {
    setError(null);
    try {
      await deleteAnnouncement(id);
      showSuccessToast('公告已删除');
      await load(page, pageSize);
    } catch (requestError: unknown) {
      setError(errorMessage(requestError, '删除失败，请检查网络连接后重试'));
    }
  }

  async function handleToggleEnabled(record: AdminAnnouncement): Promise<void> {
    setError(null);
    try {
      await updateAnnouncement(record.id, { enabled: !record.enabled });
      showSuccessToast(`公告已${record.enabled ? '停用' : '启用'}`);
      await load(page, pageSize);
    } catch (requestError: unknown) {
      setError(errorMessage(requestError, '状态更新失败'));
    }
  }

  function openCreateModal(): void {
    resetImageState();
    setEditingId(null);
    form.setFieldsValue({
      title: '',
      content: '',
      type: 'info',
      priority: 0,
      targetUsers: '',
      imageUrl: '',
      timeMode: 'permanent',
      startAt: undefined,
      enabled: true,
      timeRange: undefined,
    });
    setModalOpen(true);
  }

  function openEditModal(record: AdminAnnouncement): void {
    resetImageState();
    setEditingId(record.id);
    const timeMode = record.startAt && record.endAt
      ? 'range'
      : record.startAt
        ? 'scheduled'
        : 'permanent';
    form.setFieldsValue({
      title: record.title,
      content: record.content,
      type: record.type,
      priority: record.priority,
      targetUsers: record.targetUsers ?? '',
      imageUrl: record.imageUrl ?? '',
      timeMode,
      startAt:
        timeMode === 'scheduled' && record.startAt
          ? dayjs(record.startAt)
          : undefined,
      timeRange:
        timeMode === 'range' && record.startAt && record.endAt
          ? [dayjs(record.startAt), dayjs(record.endAt)]
          : undefined,
      enabled: record.enabled,
    });
    setModalOpen(true);
  }

  function closeEditor(): void {
    setModalOpen(false);
    setEditingId(null);
    form.resetFields();
    resetImageState();
  }

  function resetImageState(): void {
    setImageFile(null);
    setImagePreviewUrl(null);
  }

  function clearImage(): void {
    setImageFile(null);
    setImagePreviewUrl(null);
    form.setFieldValue('imageUrl', '');
  }

  const uploadProps: UploadProps = {
    accept: 'image/png,image/jpeg,image/webp',
    maxCount: 1,
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
        void message.error('公告图片不能超过 5MB');
        return Upload.LIST_IGNORE;
      }
      setImageFile(file);
      setImagePreviewUrl(URL.createObjectURL(file));
      form.setFieldValue('imageUrl', '');
      return false;
    },
  };

  const columns: ColumnsType<AdminAnnouncement> = [
    {
      title: '标题',
      dataIndex: 'title',
      width: 220,
      render: (value: string, record) => (
        <Space direction="vertical" size={4}>
          <Space size={8}>
            <strong>{value}</strong>
            {record.imageUrl && (
              <Tooltip title="包含图片">
                <FileImageOutlined style={{ color: 'var(--color-primary)' }} />
              </Tooltip>
            )}
          </Space>
          {record.priority > 0 && (
            <Tag color="red" style={{ fontSize: 11 }}>
              优先级 {record.priority}
            </Tag>
          )}
        </Space>
      ),
    },
    {
      title: '内容',
      dataIndex: 'content',
      width: 320,
      ellipsis: true,
      render: (value: string) => (
        <Tooltip title={value}>
          <span style={{ color: 'var(--color-text-muted)' }}>{value}</span>
        </Tooltip>
      ),
    },
    {
      title: '类型',
      dataIndex: 'type',
      width: 100,
      render: (value: string) => {
        const option = typeOptions.find((item) => item.value === value);
        return <Tag color={option?.color}>{option?.label ?? value}</Tag>;
      },
    },
    {
      title: '生效时间',
      width: 200,
      render: (_, record) => {
        if (!record.startAt && !record.endAt) {
          return <Tag color="green">永久生效</Tag>;
        }
        return (
          <Space direction="vertical" size={2} style={{ fontSize: 12 }}>
            {record.startAt && <span>开始：{formatDateTime(record.startAt)}</span>}
            {record.endAt && <span>结束：{formatDateTime(record.endAt)}</span>}
          </Space>
        );
      },
    },
    {
      title: '目标用户',
      dataIndex: 'targetUsers',
      width: 120,
      render: (value: string | null) =>
        value ? (
          <Tooltip title={value}>
            <Tag>指定用户</Tag>
          </Tooltip>
        ) : (
          <Tag color="blue">全部用户</Tag>
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
      title: '创建时间',
      dataIndex: 'createdAt',
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
            title="删除公告"
            description="确认删除这条公告？"
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

  const optimizedColumns: ColumnsType<AdminAnnouncement> = [
    {
      title: '公告内容',
      dataIndex: 'title',
      render: (value: string, record) => (
        <Space direction="vertical" size={6} style={{ maxWidth: 520 }}>
          <Space size={8} wrap>
            <strong>{value}</strong>
            {record.imageUrl && (
              <Tooltip title="包含图片">
                <FileImageOutlined style={{ color: 'var(--color-primary)' }} />
              </Tooltip>
            )}
            {record.priority > 0 && (
              <Tag color="red" style={{ fontSize: 11 }}>
                优先级 {record.priority}
              </Tag>
            )}
          </Space>
          <Typography.Text type="secondary" ellipsis>
            {record.content}
          </Typography.Text>
        </Space>
      ),
    },
    {
      title: '发布设置',
      width: 170,
      render: (_, record) => {
        const option = typeOptions.find((item) => item.value === record.type);
        return (
          <Space direction="vertical" size={6}>
            <Tag color={option?.color}>{option?.label ?? record.type}</Tag>
            {record.targetUsers ? (
              <Tooltip title={record.targetUsers}>
                <Tag>指定用户</Tag>
              </Tooltip>
            ) : (
              <Tag color="blue">全部用户</Tag>
            )}
          </Space>
        );
      },
    },
    {
      title: '生效时间',
      width: 270,
      render: (_, record) => (
        <Space direction="vertical" size={4}>
          {effectiveStatusTag(record)}
          <Typography.Text type="secondary" style={{ fontSize: 12 }}>
            {formatEffectiveTime(record)}
          </Typography.Text>
        </Space>
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
      title: '时间',
      width: 260,
      className: "table-date",
      render: (_, record) => (
        <Space direction="vertical" size={2} style={{ fontSize: 12 }}>
          <span>创建：{formatDateTime(record.createdAt)}</span>
          <span>更新：{formatDateTime(record.updatedAt)}</span>
        </Space>
      ),
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
            title="删除公告"
            description="确认删除这条公告？"
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
            <BellOutlined /> 公告管理
          </>
        }
        title="APP 公告推送"
        subtitle="创建和管理 APP 端弹窗公告，支持定时发布、指定用户和图片内容。"
        extra={
          <Space>
            <Button icon={<ReloadOutlined />} onClick={() => void load(page, pageSize)}>
              刷新
            </Button>
            <Button type="primary" icon={<PlusOutlined />} onClick={openCreateModal}>
              新建公告
            </Button>
          </Space>
        }
      />
      <div className="toolbar-card">
        <div className="toolbar">
          <Input.Search
            allowClear
            prefix={<SearchOutlined />}
            placeholder="搜索标题或内容"
            style={{ width: 320 }}
            value={keyword}
            onChange={(event) => setKeyword(event.target.value)}
            onSearch={() => void load(1, pageSize)}
          />
          <Select
            allowClear
            placeholder="公告类型"
            style={{ width: 140 }}
            value={type}
            options={typeOptions}
            onChange={(value) => setType(value)}
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
          columns={optimizedColumns}
          dataSource={items}
          tableLayout="fixed"
          onChange={handleTableChange}
          pagination={{ current: page, pageSize, total, showSizeChanger: true }}
          locale={{
            emptyText: (
              <Empty description="暂无公告，点击右上角「新建公告」创建第一条公告" />
            ),
          }}
        />
      </Card>

      <Modal
        className="announcement-editor-modal"
        title={
          <Space size={10}>
            <span className="announcement-editor-title-icon">
              <BellOutlined />
            </span>
            <span>{editingId ? '编辑公告' : '新建公告'}</span>
          </Space>
        }
        open={modalOpen}
        okText={editingId ? '保存公告' : '发布公告'}
        cancelText="取消"
        width={980}
        confirmLoading={saving}
        onCancel={closeEditor}
        onOk={() => void handleSubmit()}
        destroyOnClose
      >
        <Form form={form} layout="vertical" className="announcement-editor-form">
          <div className="announcement-editor-grid">
            <div className="announcement-editor-fields">
              <section className="announcement-editor-section">
                <Typography.Text className="announcement-editor-section-title">
                  基础内容
                </Typography.Text>
                <Form.Item
                  label="公告标题"
                  name="title"
                  rules={[{ required: true, message: '请输入公告标题' }]}
                >
                  <Input placeholder="例如：系统维护通知" maxLength={50} />
                </Form.Item>
                <Form.Item
                  label="公告正文"
                  name="content"
                  rules={[{ required: true, message: '请输入公告内容' }]}
                >
                  <TextArea
                    rows={6}
                    placeholder="例如：系统将在今晚 22:00 - 23:00 进行维护，期间可能无法访问。"
                    maxLength={500}
                    showCount
                  />
                </Form.Item>
                <Form.Item name="imageUrl" hidden>
                  <Input />
                </Form.Item>
                <div className="announcement-image-field">
                  <Flex justify="space-between" align="center">
                    <Typography.Text strong>公告图片</Typography.Text>
                    {previewImageUrl && (
                      <Button size="small" danger type="text" onClick={clearImage}>
                        移除图片
                      </Button>
                    )}
                  </Flex>
                  {previewImageUrl ? (
                    <div className="announcement-image-preview">
                      <img src={previewImageUrl} alt="公告图片预览" />
                      <Upload {...uploadProps}>
                        <Button icon={<UploadOutlined />}>更换图片</Button>
                      </Upload>
                    </div>
                  ) : (
                    <Upload.Dragger {...uploadProps} className="announcement-image-uploader">
                      <p className="ant-upload-drag-icon">
                        <FileImageOutlined />
                      </p>
                      <p className="ant-upload-text">上传一张公告图片</p>
                      <p className="ant-upload-hint">JPG / PNG / WebP，最大 5MB</p>
                    </Upload.Dragger>
                  )}
                </div>
              </section>

              <section className="announcement-editor-section">
                <Typography.Text className="announcement-editor-section-title">
                  发布设置
                </Typography.Text>
                <div className="announcement-editor-inline">
                  <Form.Item
                    label="公告类型"
                    name="type"
                    rules={[{ required: true }]}
                  >
                    <Select options={typeOptions} />
                  </Form.Item>
                  <Form.Item
                    label="优先级"
                    name="priority"
                    rules={[{ required: true }]}
                  >
                    <InputNumber min={0} max={100} style={{ width: '100%' }} />
                  </Form.Item>
                  <Form.Item label="启用状态" name="enabled" valuePropName="checked">
                    <Switch checkedChildren="启用" unCheckedChildren="停用" />
                  </Form.Item>
                </div>
                <Form.Item label="生效方式" name="timeMode" rules={[{ required: true }]}>
                  <Radio.Group
                    options={[
                      { value: 'permanent', label: '永久生效' },
                      { value: 'scheduled', label: '定时发布' },
                      { value: 'range', label: '时间区间' },
                    ]}
                    optionType="button"
                    buttonStyle="solid"
                  />
                </Form.Item>
                {watchedValues?.timeMode === 'scheduled' && (
                  <Form.Item label="发布时间" name="startAt">
                    <DatePicker
                      showTime
                      format="YYYY-MM-DD HH:mm"
                      style={{ width: '100%' }}
                    />
                  </Form.Item>
                )}
                {watchedValues?.timeMode === 'range' && (
                  <Form.Item label="生效时间" name="timeRange">
                    <RangePicker
                      showTime
                      format="YYYY-MM-DD HH:mm"
                      style={{ width: '100%' }}
                    />
                  </Form.Item>
                )}
                <Form.Item label="目标用户" name="targetUsers">
                  <Input placeholder="用户 ID 列表，逗号分隔；留空表示全部用户" />
                </Form.Item>
              </section>
            </div>

            <aside className="announcement-editor-preview-panel">
              <div className="announcement-editor-preview-heading">
                <EyeOutlined />
                <span>APP 预览</span>
              </div>
              <div className="announcement-phone-preview">
                <div className="announcement-phone-status" />
                <div className="announcement-phone-dialog">
                  {previewImageUrl && (
                    <div className="announcement-phone-cover">
                      <img src={previewImageUrl} alt="APP 公告图片预览" />
                    </div>
                  )}
                  <div className="announcement-phone-icon">
                    <BellOutlined />
                  </div>
                  <Tag color={previewType.color}>{previewType.label}</Tag>
                  <h3>{watchedValues?.title || '公告标题'}</h3>
                  <p>{watchedValues?.content || '公告正文会显示在这里。'}</p>
                  <button type="button">知道了</button>
                </div>
              </div>
            </aside>
          </div>
        </Form>
      </Modal>
    </>
  );
}

function errorMessage(error: unknown, fallback: string): string {
  return error instanceof Error && error.message ? error.message : fallback;
}

function formatEffectiveTime(record: AdminAnnouncement): string {
  if (!record.startAt && !record.endAt) {
    return '永久生效';
  }
  if (record.startAt && record.endAt) {
    return `${formatDateTime(record.startAt)} 至 ${formatDateTime(record.endAt)}`;
  }
  if (record.startAt) {
    return `自 ${formatDateTime(record.startAt)} 起生效`;
  }
  return `截至 ${formatDateTime(record.endAt)}`;
}

function effectiveStatusTag(record: AdminAnnouncement): ReactNode {
  if (!record.enabled) {
    return <Tag>已停用</Tag>;
  }
  const now = Date.now();
  const startAt = record.startAt ? new Date(record.startAt).getTime() : null;
  const endAt = record.endAt ? new Date(record.endAt).getTime() : null;
  if (startAt && startAt > now) {
    return <Tag color="blue">待发布</Tag>;
  }
  if (endAt && endAt < now) {
    return <Tag color="red">已过期</Tag>;
  }
  return <Tag color="green">生效中</Tag>;
}
