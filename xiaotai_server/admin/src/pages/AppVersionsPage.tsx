import {
  CloudUploadOutlined,
  DeleteOutlined,
  DownloadOutlined,
  ReloadOutlined,
  UploadOutlined,
} from '@ant-design/icons';
import {
  Alert,
  Button,
  Card,
  Empty,
  Form,
  Input,
  InputNumber,
  Modal,
  Popconfirm,
  Progress,
  Select,
  Space,
  Switch,
  Table,
  Tag,
} from 'antd';

import PageHeader from '../components/PageHeader';
import type { ColumnsType, TablePaginationConfig } from 'antd/es/table';
import { useEffect, useState } from 'react';

import {
  createAppVersion,
  deleteAppVersion,
  getAppVersions,
  updateAppVersion,
} from '../api/admin';
import { ApiError, resolveApiAssetUrl } from '../api/client';
import type { AppVersion } from '../api/types';
import { formatDateTime } from '../utils/format';
import { showSuccessToast } from '../utils/operationToast';

interface VersionFormState {
  platform: string;
  channel: string;
  versionName: string;
  versionCode: number | null;
  changelog: string;
  forceUpdate: boolean;
  enabled: boolean;
}

const defaultForm: VersionFormState = {
  platform: 'android',
  channel: 'private',
  versionName: '',
  versionCode: null,
  changelog: '',
  forceUpdate: false,
  enabled: true,
};

const maxApkSize = 200 * 1024 * 1024;

export default function AppVersionsPage(): React.JSX.Element {
  const [items, setItems] = useState<AppVersion[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(20);
  const [platform, setPlatform] = useState<string | undefined>();
  const [channel, setChannel] = useState<string | undefined>();
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [uploadOpen, setUploadOpen] = useState(false);
  const [form, setForm] = useState<VersionFormState>(defaultForm);
  const [apkFile, setApkFile] = useState<File | null>(null);
  const [uploadProgress, setUploadProgress] = useState(0);
  const [error, setError] = useState<string | null>(null);

  async function load(nextPage = page, nextPageSize = pageSize): Promise<void> {
    setLoading(true);
    setError(null);
    try {
      const result = await getAppVersions({
        page: nextPage,
        pageSize: nextPageSize,
        platform,
        channel,
      });
      setItems(result.items);
      setTotal(result.total);
      setPage(result.page);
      setPageSize(result.pageSize);
    } catch (requestError) {
      setError(
        requestError instanceof ApiError
          ? requestError.message
          : '版本列表加载失败',
      );
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void load(1, pageSize);
  }, []);

  async function submitVersion(): Promise<void> {
    if (!form.versionName.trim()) {
      setError('请填写版本号，例如 1.0.1');
      return;
    }
    if (!form.versionCode || form.versionCode <= 0) {
      setError('请填写正确的版本代码（正整数）');
      return;
    }
    if (!apkFile) {
      setError('请选择要上传的 APK 文件');
      return;
    }

    if (!apkFile.name.toLowerCase().endsWith('.apk')) {
      setError('只能上传 APK 安装包文件');
      return;
    }
    if (apkFile.size > maxApkSize) {
      setError('APK 文件不能超过 200MB');
      return;
    }

    const payload = new FormData();
    payload.set('platform', form.platform);
    payload.set('channel', form.channel);
    payload.set('versionName', form.versionName.trim());
    payload.set('versionCode', String(form.versionCode));
    payload.set('changelog', form.changelog.trim());
    payload.set('forceUpdate', String(form.forceUpdate));
    payload.set('enabled', String(form.enabled));
    payload.set('apk', apkFile);

    setSaving(true);
    setError(null);
    setUploadProgress(0);
    try {
      await createAppVersion(payload, (progress) => {
        setUploadProgress(progress.percent);
      });
      setUploadOpen(false);
      setForm(defaultForm);
      setApkFile(null);
      setUploadProgress(0);
      showSuccessToast(`版本 ${form.versionName} 发布成功，APP 可检查更新`);
      await load(1, pageSize);
    } catch (requestError) {
      setUploadProgress(0);
      setError(
        requestError instanceof ApiError ? requestError.message : '版本发布失败，请检查网络连接和文件大小后重试',
      );
    } finally {
      setSaving(false);
    }
  }

  async function toggleVersion(
    row: AppVersion,
    patch: { enabled?: boolean; forceUpdate?: boolean },
  ): Promise<void> {
    setError(null);
    try {
      await updateAppVersion(row.id, patch);
      const action = patch.enabled !== undefined 
        ? (patch.enabled ? '已启用' : '已停用')
        : (patch.forceUpdate ? '已设为强制更新' : '已取消强制更新');
      showSuccessToast(`版本 ${row.versionName} ${action}`);
      await load(page, pageSize);
    } catch (requestError) {
      setError(
        requestError instanceof ApiError ? requestError.message : '状态更新失败，请检查网络连接后重试',
      );
    }
  }

  async function removeVersion(id: string): Promise<void> {
    setError(null);
    try {
      await deleteAppVersion(id);
      showSuccessToast('版本记录已删除，本地 APK 文件已清理');
      await load(page, pageSize);
    } catch (requestError) {
      setError(
        requestError instanceof ApiError ? requestError.message : '删除失败，请检查网络连接后重试',
      );
    }
  }

  function handleTableChange(pagination: TablePaginationConfig): void {
    void load(pagination.current ?? 1, pagination.pageSize ?? 20);
  }

  const columns: ColumnsType<AppVersion> = [
    {
      title: '版本',
      width: 220,
      ellipsis: true,
      render: (_, row) => (
        <Space orientation="vertical" size={2}>
          <strong className="table-primary-text table-clip">{row.versionName}</strong>
          <span className="table-secondary-text">
            Code {row.versionCode}
          </span>
        </Space>
      ),
    },
    {
      title: '平台',
      dataIndex: 'platform',
      width: 110,
      render: (value: string) => <Tag color="blue">{value}</Tag>,
    },
    { title: '渠道', dataIndex: 'channel', width: 120 },
    {
      title: '安装包',
      dataIndex: 'apkSize',
      width: 130,
      render: (value: number | null) => formatFileSize(value),
    },
    {
      title: '强制更新',
      dataIndex: 'forceUpdate',
      width: 120,
      render: (value: boolean, row) => (
        <Switch
          checked={value}
          checkedChildren="是"
          unCheckedChildren="否"
          onChange={(checked) =>
            void toggleVersion(row, { forceUpdate: checked })
          }
        />
      ),
    },
    {
      title: '启用',
      dataIndex: 'enabled',
      width: 110,
      render: (value: boolean, row) => (
        <Switch
          checked={value}
          checkedChildren="启用"
          unCheckedChildren="停用"
          onChange={(checked) => void toggleVersion(row, { enabled: checked })}
        />
      ),
    },
    {
      title: '发布时间',
      dataIndex: 'createdAt',
      width: 180,
      className: "table-date",
      render: (value: string) => formatDateTime(value),
    },
    {
      title: '操作',
      width: 170,
      className: "table-actions",
      render: (_, row) => (
        <Space>
          <Button
            type="link"
            icon={<DownloadOutlined />}
            href={resolveApiAssetUrl(row.apkUrl)}
            target="_blank"
            rel="noreferrer"
          >
            下载
          </Button>
          <Popconfirm
            title="删除版本记录"
            description="确认删除这条版本记录？本地 APK 文件也会被删除"
            okText="确认删除"
            okButtonProps={{ danger: true }}
            cancelText="取消"
            onConfirm={() => void removeVersion(row.id)}
          >
            <Button type="link" danger icon={<DeleteOutlined />}>
              删除
            </Button>
          </Popconfirm>
        </Space>
      ),
    },
  ];

  return (
    <>
      <PageHeader
        eyebrow={<><UploadOutlined /> 版本管理</>}
        title="私有 APK 发布"
        subtitle="发布私有 APK，供 APP 检查更新和下载安装。"
        extra={
          <Space>
            <Button icon={<ReloadOutlined />} onClick={() => void load(page, pageSize)}>
              刷新
            </Button>
            <Button
              type="primary"
              icon={<CloudUploadOutlined />}
              onClick={() => setUploadOpen(true)}
            >
              发布新版本
            </Button>
          </Space>
        }
      />
      <div className="toolbar-card">
        <div className="toolbar">
          <Select
            allowClear
            placeholder="平台"
            style={{ width: 180 }}
            value={platform}
            options={[{ value: 'android', label: 'Android' }]}
            onChange={(value) => setPlatform(value)}
          />
          <Input
            allowClear
            placeholder="渠道，例如 private"
            style={{ width: 240 }}
            value={channel}
            onChange={(event) => setChannel(event.target.value)}
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
        locale={{ emptyText: <Empty description="暂无版本记录，点击右上角「发布新版本」上传第一个 APK" /> }}
      />
      </Card>
      <Modal
        title="发布新版本"
        open={uploadOpen}
        okText="确认发布"
        cancelText="取消"
        width={560}
        confirmLoading={saving}
        onOk={() => void submitVersion()}
        onCancel={() => {
          if (saving) {
            return;
          }
          setUploadOpen(false);
          setForm(defaultForm);
          setApkFile(null);
          setUploadProgress(0);
        }}
        closable={!saving}
        maskClosable={!saving}
        destroyOnClose
      >
        <Alert
          type="info"
          showIcon
          title="发布后 APP 可立即检查到新版本"
          description="启用状态的版本会被 APP 检测到，强制更新会阻止用户跳过更新"
          style={{ marginBottom: 16 }}
        />
        <Form layout="vertical">
          <Form.Item label="平台" required>
            <Select
              value={form.platform}
              options={[{ value: 'android', label: 'Android' }]}
              onChange={(value) => setForm({ ...form, platform: value })}
            />
          </Form.Item>
          <Form.Item label="渠道" required>
            <Input
              placeholder="例如 private、beta"
              value={form.channel}
              onChange={(event) =>
                setForm({ ...form, channel: event.target.value })
              }
            />
          </Form.Item>
          <Form.Item label="版本号" required extra="用户可见的版本号，例如 1.0.1">
            <Input
              placeholder="例如 1.0.1"
              value={form.versionName}
              onChange={(event) =>
                setForm({ ...form, versionName: event.target.value })
              }
            />
          </Form.Item>
          <Form.Item label="版本代码" required extra="用于版本比较的整数，必须递增">
            <InputNumber
              min={1}
              precision={0}
              style={{ width: '100%' }}
              placeholder="例如 2"
              value={form.versionCode}
              onChange={(value) =>
                setForm({
                  ...form,
                  versionCode: typeof value === 'number' ? value : null,
                })
              }
            />
          </Form.Item>
          <Form.Item label="更新说明" extra="向用户展示的更新内容">
            <Input.TextArea
              rows={4}
              placeholder="例如：修复了若干已知问题，优化了使用体验"
              value={form.changelog}
              onChange={(event) =>
                setForm({ ...form, changelog: event.target.value })
              }
            />
          </Form.Item>
          <Form.Item label="安装包" required extra={apkFile ? `已选择：${apkFile.name}` : '请选择 APK 文件'}>
            <input
              type="file"
              accept=".apk,application/vnd.android.package-archive"
              disabled={saving}
              onChange={(event) => {
                setError(null);
                setUploadProgress(0);
                setApkFile(event.target.files?.item(0) ?? null);
              }}
            />
          </Form.Item>
          {(saving || uploadProgress > 0) && (
            <Progress
              percent={uploadProgress}
              status={uploadProgress >= 100 ? 'success' : 'active'}
              format={(percent) =>
                saving && (percent ?? 0) >= 99 ? '处理中' : `${percent ?? 0}%`
              }
            />
          )}
          <Space size={16}>
            <Space size={8}>
              <span>启用</span>
              <Switch
                checked={form.enabled}
                onChange={(checked) => setForm({ ...form, enabled: checked })}
              />
            </Space>
            <Space size={8}>
              <span>强制更新</span>
              <Switch
                checked={form.forceUpdate}
                onChange={(checked) =>
                  setForm({ ...form, forceUpdate: checked })
                }
              />
            </Space>
          </Space>
        </Form>
      </Modal>
    </>
  );
}

function formatFileSize(value: number | null): string {
  if (!value) {
    return '-';
  }
  if (value < 1024 * 1024) {
    return `${(value / 1024).toFixed(1)} KB`;
  }
  return `${(value / 1024 / 1024).toFixed(1)} MB`;
}
