import {
  DeleteOutlined,
  DownloadOutlined,
  FileImageOutlined,
  PictureOutlined,
  PlayCircleFilled,
  ReloadOutlined,
  SearchOutlined,
  VideoCameraOutlined,
} from "@ant-design/icons";
import {
  Alert,
  Button,
  Card,
  Descriptions,
  Empty,
  Image,
  Input,
  Modal,
  Popconfirm,
  Space,
  Table,
  Tag,
} from "antd";
import type { ColumnsType, TablePaginationConfig } from "antd/es/table";
import type { Key } from "react";
import { useEffect, useRef, useState } from "react";

import PageHeader from "../components/PageHeader";

import {
  createMediaDownloadTicket,
  deleteMediaAsset,
  getMediaAsset,
  getMediaAssets,
} from "../api/admin";
import {
  ApiError,
  requestBlob,
  requestDownloadBlob,
  resolveApiAssetUrl,
} from "../api/client";
import type { AdminMediaAsset } from "../api/types";
import { formatDateTime } from "../utils/format";
import { showSuccessToast } from "../utils/operationToast";

const mediaThumbObjectUrlCache = new Map<string, string>();
const maxMediaThumbCacheSize = 180;
const maxConcurrentThumbRequests = 4;
let activeThumbRequests = 0;
const queuedThumbRequests: Array<() => void> = [];

export default function MediaPage(): React.JSX.Element {
  const [items, setItems] = useState<AdminMediaAsset[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(30);
  const [userId, setUserId] = useState("");
  const [loading, setLoading] = useState(false);
  const [batching, setBatching] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [detail, setDetail] = useState<AdminMediaAsset | null>(null);
  const [selectedRowKeys, setSelectedRowKeys] = useState<Key[]>([]);

  async function load(nextPage = page, nextPageSize = pageSize): Promise<void> {
    setLoading(true);
    setError(null);
    try {
      const result = await getMediaAssets({
        page: nextPage,
        pageSize: nextPageSize,
        userId,
        deleted: "false",
      });
      setItems(result.items);
      setTotal(result.total);
      setPage(result.page);
      setPageSize(result.pageSize);
    } catch (requestError) {
      setError(
        requestError instanceof ApiError
          ? requestError.message
          : "媒体数据加载失败",
      );
    } finally {
      setLoading(false);
    }
  }

  async function openDetail(id: string): Promise<void> {
    setError(null);
    try {
      setDetail(await getMediaAsset(id));
    } catch (requestError) {
      setError(
        requestError instanceof ApiError
          ? requestError.message
          : "详情加载失败",
      );
    }
  }

  async function remove(id: string): Promise<void> {
    setError(null);
    try {
      await deleteMediaAsset(id);
      clearMediaThumbCache(id);
      showSuccessToast("云端媒体文件已删除，本地文件已清理");
      if (detail?.id === id) {
        setDetail(null);
      }
      setSelectedRowKeys((current) => current.filter((key) => key !== id));
      await load(page, pageSize);
    } catch (requestError) {
      setError(
        requestError instanceof ApiError
          ? requestError.message
          : "删除失败，请检查网络连接后重试",
      );
    }
  }

  async function download(row: AdminMediaAsset): Promise<void> {
    setError(null);
    try {
      const result = await downloadMediaFile(row);
      showSuccessToast(
        result.saved
          ? `${row.originalName} 已保存到本地`
          : `${row.originalName} 已获取文件并交给浏览器下载，请查看浏览器下载栏`,
      );
    } catch (requestError) {
      setError(
        requestError instanceof ApiError
          ? requestError.message
          : "下载失败，请检查网络连接后重试",
      );
    }
  }

  async function downloadSelected(): Promise<void> {
    const selected = selectedRows();
    if (selected.length === 0 || batching) {
      return;
    }
    setBatching(true);
    setError(null);
    try {
      for (const row of selected) {
        await downloadMediaFile(row);
        await delay(120);
      }
      showSuccessToast(
        `已处理 ${selected.length} 个媒体文件下载；若浏览器拦截，请允许本站下载多个文件`,
      );
    } catch (requestError) {
      setError(
        requestError instanceof ApiError
          ? requestError.message
          : "批量下载失败，请稍后重试",
      );
    } finally {
      setBatching(false);
    }
  }

  async function removeSelected(): Promise<void> {
    const ids = selectedRowKeys.map(String);
    if (ids.length === 0 || batching) {
      return;
    }
    setBatching(true);
    setError(null);
    try {
      for (const id of ids) {
        await deleteMediaAsset(id);
        clearMediaThumbCache(id);
      }
      setSelectedRowKeys([]);
      if (detail && ids.includes(detail.id)) {
        setDetail(null);
      }
      showSuccessToast(`已删除 ${ids.length} 个云端媒体文件`);
      await load(page, pageSize);
    } catch (requestError) {
      setError(
        requestError instanceof ApiError
          ? requestError.message
          : "批量删除失败，请稍后重试",
      );
    } finally {
      setBatching(false);
    }
  }

  function selectedRows(): AdminMediaAsset[] {
    const selected = new Set(selectedRowKeys.map(String));
    return items.filter((item) => selected.has(item.id));
  }

  useEffect(() => {
    void load(1, pageSize);
  }, []);

  function handleTableChange(pagination: TablePaginationConfig): void {
    void load(pagination.current ?? 1, pagination.pageSize ?? 30);
  }

  const columns: ColumnsType<AdminMediaAsset> = [
    {
      title: "媒体",
      width: 96,
      render: (_, row) => <MediaThumb asset={row} />,
    },
    {
      title: "文件",
      width: 360,
      ellipsis: true,
      render: (_, row) => (
        <Space orientation="vertical" size={2}>
          <strong className="table-primary-text table-clip">
            {row.originalName}
          </strong>
          <span className="table-secondary-text table-mono-text">
            {row.sha256.slice(0, 16)}
          </span>
        </Space>
      ),
    },
    {
      title: "用户",
      width: 150,
      ellipsis: true,
      render: (_, row) => (
        <span className="table-clip">
          {row.nickname} / {row.username}
        </span>
      ),
    },
    {
      title: "类型",
      dataIndex: "mimeType",
      width: 150,
      render: (value: string) => (
        <Tag
          className="table-tag"
          color={value.startsWith("video/") ? "cyan" : "blue"}
        >
          {value.startsWith("video/") ? (
            <VideoCameraOutlined />
          ) : (
            <FileImageOutlined />
          )}{" "}
          {value}
        </Tag>
      ),
    },
    {
      title: "大小",
      dataIndex: "size",
      width: 100,
      render: (value: number) => formatFileSize(value),
    },
    {
      title: "上传时间",
      dataIndex: "uploadedAt",
      width: 180,
      className: "table-date",
      render: (value: string) => formatDateTime(value),
    },
    {
      title: "操作",
      width: 172,
      className: "table-actions",
      render: (_, row) => (
        <Space size={0} wrap>
          <Button type="link" onClick={() => void openDetail(row.id)}>
            详情
          </Button>
          <Button type="link" onClick={() => void download(row)}>
            下载
          </Button>
          <Popconfirm
            title="删除云端媒体"
            description="确认删除这个云端媒体？本地文件也会被删除，用户 APP 不受影响"
            okText="确认删除"
            okButtonProps={{ danger: true }}
            cancelText="取消"
            onConfirm={() => void remove(row.id)}
          >
            <Button type="link" danger>
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
        eyebrow={
          <>
            <PictureOutlined /> 媒体文件
          </>
        }
        title="云端媒体文件"
        subtitle="查看已上传到私有服务器的图片和视频备份。"
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
            placeholder="按用户 ID 筛选"
            style={{ width: 340 }}
            value={userId}
            onChange={(event) => setUserId(event.target.value)}
            onSearch={() => void load(1, pageSize)}
          />
          <Button type="primary" ghost onClick={() => void load(1, pageSize)}>
            筛选
          </Button>
          <div className="toolbar-spacer" />
          <Space size={8}>
            <Tag color={selectedRowKeys.length > 0 ? "blue" : "default"}>
              已选 {selectedRowKeys.length} 项
            </Tag>
            <Button
              icon={<DownloadOutlined />}
              disabled={selectedRowKeys.length === 0}
              loading={batching}
              onClick={() => void downloadSelected()}
            >
              批量下载
            </Button>
            <Popconfirm
              title="批量删除云端媒体"
              description={`确认删除选中的 ${selectedRowKeys.length} 个云端媒体文件吗？本地文件也会清理。`}
              okText="确认删除"
              okButtonProps={{ danger: true }}
              cancelText="取消"
              disabled={selectedRowKeys.length === 0}
              onConfirm={() => void removeSelected()}
            >
              <Button
                danger
                icon={<DeleteOutlined />}
                disabled={selectedRowKeys.length === 0}
                loading={batching}
              >
                批量删除
              </Button>
            </Popconfirm>
          </Space>
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
          rowSelection={{
            selectedRowKeys,
            onChange: (keys) => setSelectedRowKeys(keys),
          }}
          onChange={handleTableChange}
          pagination={{ current: page, pageSize, total, showSizeChanger: true }}
          locale={{
            emptyText: (
              <Empty description="暂无媒体文件，用户在 APP 中上传照片或视频后会显示在这里" />
            ),
          }}
        />
      </Card>
      <Modal
        title={
          <div className="detail-modal-title">
            <span>媒体详情</span>
            {detail && (
              <Space>
                <Button onClick={() => void download(detail)}>
                  下载原文件
                </Button>
                <Popconfirm
                  title="删除云端媒体"
                  description="确认删除这个云端媒体？"
                  okText="确认删除"
                  okButtonProps={{ danger: true }}
                  cancelText="取消"
                  onConfirm={() => void remove(detail.id)}
                >
                  <Button danger>删除</Button>
                </Popconfirm>
              </Space>
            )}
          </div>
        }
        open={Boolean(detail)}
        onCancel={() => setDetail(null)}
        footer={null}
        width={920}
        className="detail-modal"
      >
        {detail && (
          <Space orientation="vertical" size={16} style={{ width: "100%" }}>
            <MediaPreview asset={detail} />
            <Descriptions column={1} bordered size="middle">
              <Descriptions.Item label="文件名">
                {detail.originalName}
              </Descriptions.Item>
              <Descriptions.Item label="用户">
                {detail.nickname} / {detail.username}
              </Descriptions.Item>
              <Descriptions.Item label="设备">
                {detail.deviceId ?? "-"}
              </Descriptions.Item>
              <Descriptions.Item label="MIME">
                {detail.mimeType}
              </Descriptions.Item>
              <Descriptions.Item label="大小">
                {formatFileSize(detail.size)}
              </Descriptions.Item>
              <Descriptions.Item label="拍摄时间">
                {formatDateTime(detail.takenAt)}
              </Descriptions.Item>
              <Descriptions.Item label="上传时间">
                {formatDateTime(detail.uploadedAt)}
              </Descriptions.Item>
              <Descriptions.Item label="SHA-256">
                {detail.sha256}
              </Descriptions.Item>
            </Descriptions>
          </Space>
        )}
      </Modal>
    </>
  );
}

function MediaThumb({ asset }: { asset: AdminMediaAsset }): React.JSX.Element {
  const rootRef = useRef<HTMLDivElement>(null);
  const [src, setSrc] = useState<string>();
  const [visible, setVisible] = useState(false);

  useEffect(() => {
    const node = rootRef.current;
    if (!node) {
      return;
    }
    const observer = new IntersectionObserver(
      ([entry]) => {
        if (entry?.isIntersecting) {
          setVisible(true);
          observer.disconnect();
        }
      },
      { rootMargin: "160px" },
    );
    observer.observe(node);
    return () => observer.disconnect();
  }, []);

  useEffect(() => {
    if (isVideoAsset(asset)) {
      setSrc(undefined);
      return;
    }
    if (!visible) {
      return;
    }

    const cached = mediaThumbObjectUrlCache.get(asset.id);
    if (cached) {
      setSrc(cached);
      return;
    }

    let active = true;
    setSrc(undefined);
    queueMediaThumbRequest(() =>
      requestBlob(`/admin/media/${encodeURIComponent(asset.id)}/thumb`, {
        cache: "force-cache",
      }),
    )
      .then((blob) => {
        if (!active) {
          return;
        }
        const objectUrl = URL.createObjectURL(blob);
        cacheMediaThumb(asset.id, objectUrl);
        setSrc(objectUrl);
      })
      .catch(() => undefined);
    return () => {
      active = false;
    };
  }, [asset.id, asset.mimeType, visible]);

  const content = (() => {
    if (isVideoAsset(asset)) {
      return (
        <div className="media-video-thumb">
          <VideoCameraOutlined />
          <span className="media-video-play">
            <PlayCircleFilled />
          </span>
        </div>
      );
    }

    if (!src) {
      return (
        <div className="media-thumb-placeholder">
          <FileImageOutlined />
          <span>图片</span>
        </div>
      );
    }

    return (
      <Image
        src={src}
        alt={asset.originalName}
        width={64}
        height={64}
        style={{ objectFit: "cover", borderRadius: 8 }}
        preview={false}
      />
    );
  })();

  return <div ref={rootRef}>{content}</div>;
}

function MediaPreview({
  asset,
}: {
  asset: AdminMediaAsset;
}): React.JSX.Element {
  const [src, setSrc] = useState<string>();
  const [videoError, setVideoError] = useState(false);

  useEffect(() => {
    let active = true;
    let objectUrl: string | undefined;
    setSrc(undefined);
    setVideoError(false);
    requestBlob(`/admin/media/${encodeURIComponent(asset.id)}/file`)
      .then((blob) => {
        if (!active) {
          return;
        }
        objectUrl = URL.createObjectURL(blob);
        setSrc(objectUrl);
      })
      .catch(() => undefined);
    return () => {
      active = false;
      if (objectUrl) {
        URL.revokeObjectURL(objectUrl);
      }
    };
  }, [asset.id]);

  if (!src) {
    return <Empty description="媒体加载中" />;
  }

  if (isVideoAsset(asset)) {
    return (
      <div className="media-video-preview-shell">
        <div className="media-video-preview">
          <video
            key={asset.id}
            src={src}
            controls
            preload="auto"
            playsInline
            onLoadedMetadata={(event) => {
              event.currentTarget.currentTime = 0;
            }}
            onError={() => setVideoError(true)}
          />
        </div>
        {videoError && (
          <div className="media-video-error">
            当前浏览器无法直接解码这个 MP4，可能是手机录制的 HEVC/H.265
            编码。请下载原文件查看，或在手机端改为 H.264/高兼容性录制。
          </div>
        )}
      </div>
    );
  }

  if (isImageAsset(asset)) {
    return (
      <Image src={src} alt={asset.originalName} style={{ maxHeight: 420 }} />
    );
  }

  return (
    <div className="media-file-preview">
      <PictureOutlined />
      <strong>{asset.originalName}</strong>
      <span>{asset.mimeType}</span>
    </div>
  );
}

function formatFileSize(value: number): string {
  if (value < 1024 * 1024) {
    return `${(value / 1024).toFixed(1)} KB`;
  }
  return `${(value / 1024 / 1024).toFixed(1)} MB`;
}

function isImageAsset(asset: AdminMediaAsset): boolean {
  return asset.mimeType.startsWith("image/");
}

function isVideoAsset(asset: AdminMediaAsset): boolean {
  return asset.mimeType.startsWith("video/");
}

function cacheMediaThumb(id: string, objectUrl: string): void {
  if (mediaThumbObjectUrlCache.has(id)) {
    URL.revokeObjectURL(objectUrl);
    return;
  }
  mediaThumbObjectUrlCache.set(id, objectUrl);
  while (mediaThumbObjectUrlCache.size > maxMediaThumbCacheSize) {
    const oldest = mediaThumbObjectUrlCache.keys().next().value;
    if (!oldest) {
      return;
    }
    clearMediaThumbCache(oldest);
  }
}

function clearMediaThumbCache(id: string): void {
  const cached = mediaThumbObjectUrlCache.get(id);
  if (!cached) {
    return;
  }
  URL.revokeObjectURL(cached);
  mediaThumbObjectUrlCache.delete(id);
}

function queueMediaThumbRequest(task: () => Promise<Blob>): Promise<Blob> {
  return new Promise((resolve, reject) => {
    const run = () => {
      activeThumbRequests += 1;
      task()
        .then(resolve, reject)
        .finally(() => {
          activeThumbRequests -= 1;
          queuedThumbRequests.shift()?.();
        });
    };

    if (activeThumbRequests < maxConcurrentThumbRequests) {
      run();
      return;
    }
    queuedThumbRequests.push(run);
  });
}

async function downloadMediaFile(
  row: AdminMediaAsset,
): Promise<{ saved: boolean }> {
  const ticket = await createMediaDownloadTicket(row.id);
  const url = resolveApiAssetUrl(ticket.url);
  const blob = await requestDownloadBlob(url, { cache: "no-store" });
  if (blob.size === 0) {
    throw new ApiError("下载文件为空，已阻止错误的成功提示", 0);
  }

  if (window.showSaveFilePicker) {
    const handle = await window.showSaveFilePicker({
      suggestedName: safeDownloadName(row.originalName),
      types: [
        {
          description: row.mimeType.startsWith("video/")
            ? "Video file"
            : row.mimeType.startsWith("image/")
              ? "Image file"
              : "Media file",
          accept: { [row.mimeType]: [extensionForFile(row.originalName)] },
        },
      ],
    });
    const writable = await handle.createWritable();
    await writable.write(blob);
    await writable.close();
    return { saved: true };
  }

  const objectUrl = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = objectUrl;
  anchor.download = row.originalName;
  anchor.rel = "noopener";
  document.body.append(anchor);
  anchor.click();
  anchor.remove();
  window.setTimeout(() => URL.revokeObjectURL(objectUrl), 60_000);
  return { saved: false };
}

function delay(ms: number): Promise<void> {
  return new Promise((resolve) => window.setTimeout(resolve, ms));
}

function safeDownloadName(name: string): string {
  const trimmed = name.trim();
  const safeName = trimmed.replace(/[\\/:*?"<>|]+/g, "_");
  return safeName.length > 0 ? safeName : "media-file";
}

function extensionForFile(name: string): string {
  const dotIndex = name.lastIndexOf(".");
  if (dotIndex < 0 || dotIndex === name.length - 1) {
    return "";
  }
  return name.slice(dotIndex);
}

declare global {
  interface Window {
    showSaveFilePicker?: (options?: {
      suggestedName?: string;
      types?: Array<{
        description?: string;
        accept: Record<string, string[]>;
      }>;
    }) => Promise<FileSystemFileHandle>;
  }
}
