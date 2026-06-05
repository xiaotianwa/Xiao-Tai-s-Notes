import {
  CustomerServiceOutlined,
  DeleteOutlined,
  EditOutlined,
  PlusOutlined,
  ReloadOutlined,
  SearchOutlined,
  UploadOutlined,
} from "@ant-design/icons";
import {
  Alert,
  Button,
  Card,
  Empty,
  Form,
  Input,
  InputNumber,
  message,
  Modal,
  Popconfirm,
  Progress,
  Select,
  Space,
  Switch,
  Table,
  Tag,
  Tooltip,
  Typography,
  Upload,
} from "antd";
import type { ColumnsType, TablePaginationConfig } from "antd/es/table";
import type { RcFile, UploadProps } from "antd/es/upload";
import { useEffect, useState } from "react";

import {
  createMusicTrack,
  deleteMusicTrack,
  getMusicTracks,
  updateMusicTrack,
} from "../api/admin";
import { resolveApiAssetUrl } from "../api/client";
import type { AdminMusicTrack } from "../api/types";
import PageHeader from "../components/PageHeader";
import { formatDateTime, formatFileSize } from "../utils/format";
import { showSuccessToast } from "../utils/operationToast";

const { TextArea } = Input;

interface MusicFormValues {
  title: string;
  artist?: string;
  album?: string;
  lyrics?: string;
  enabled: boolean;
  sortOrder: number;
}

export default function MusicPage(): React.JSX.Element {
  const [items, setItems] = useState<AdminMusicTrack[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(20);
  const [keyword, setKeyword] = useState("");
  const [enabled, setEnabled] = useState<string | undefined>();
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [modalOpen, setModalOpen] = useState(false);
  const [editing, setEditing] = useState<AdminMusicTrack | null>(null);
  const [audioFile, setAudioFile] = useState<RcFile | null>(null);
  const [coverFile, setCoverFile] = useState<RcFile | null>(null);
  const [lyricsFile, setLyricsFile] = useState<RcFile | null>(null);
  const [uploadPercent, setUploadPercent] = useState(0);
  const [form] = Form.useForm<MusicFormValues>();

  useEffect(() => {
    void load(1, pageSize);
  }, []);

  async function load(nextPage = page, nextPageSize = pageSize): Promise<void> {
    setLoading(true);
    setError(null);
    try {
      const result = await getMusicTracks({
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
      setError(errorMessage(requestError, "音乐列表加载失败"));
    } finally {
      setLoading(false);
    }
  }

  function openCreate(): void {
    setEditing(null);
    setAudioFile(null);
    setCoverFile(null);
    setLyricsFile(null);
    setUploadPercent(0);
    form.setFieldsValue({
      title: "",
      artist: "",
      album: "",
      lyrics: "",
      enabled: true,
      sortOrder: 0,
    });
    setModalOpen(true);
  }

  function openEdit(track: AdminMusicTrack): void {
    setEditing(track);
    setAudioFile(null);
    setCoverFile(null);
    setLyricsFile(null);
    setUploadPercent(0);
    form.setFieldsValue({
      title: track.title,
      artist: track.artist ?? "",
      album: track.album ?? "",
      lyrics: track.lyrics ?? "",
      enabled: track.enabled,
      sortOrder: track.sortOrder,
    });
    setModalOpen(true);
  }

  async function handleSubmit(): Promise<void> {
    const values = await form.validateFields();
    if (!editing && !audioFile) {
      void message.error("请上传音乐文件");
      return;
    }
    const formData = new FormData();
    formData.append("title", values.title.trim());
    formData.append("artist", values.artist?.trim() ?? "");
    formData.append("album", values.album?.trim() ?? "");
    formData.append("lyrics", values.lyrics?.trim() ?? "");
    formData.append("enabled", String(values.enabled));
    formData.append("sortOrder", String(values.sortOrder ?? 0));
    if (audioFile) {
      formData.append("audio", audioFile);
    }
    if (coverFile) {
      formData.append("cover", coverFile);
    }
    if (lyricsFile) {
      formData.append("lyricsFile", lyricsFile);
    }

    setSaving(true);
    setError(null);
    try {
      if (editing) {
        await updateMusicTrack(editing.id, formData, (progress) =>
          setUploadPercent(progress.percent),
        );
        showSuccessToast("音乐已更新");
      } else {
        await createMusicTrack(formData, (progress) =>
          setUploadPercent(progress.percent),
        );
        showSuccessToast("音乐已上传");
      }
      setModalOpen(false);
      await load(1, pageSize);
    } catch (requestError: unknown) {
      setError(errorMessage(requestError, "保存音乐失败"));
    } finally {
      setSaving(false);
    }
  }

  async function handleToggle(track: AdminMusicTrack): Promise<void> {
    const formData = new FormData();
    formData.append("enabled", String(!track.enabled));
    try {
      await updateMusicTrack(track.id, formData);
      showSuccessToast(track.enabled ? "音乐已停用" : "音乐已启用");
      await load(page, pageSize);
    } catch (requestError: unknown) {
      setError(errorMessage(requestError, "状态更新失败"));
    }
  }

  async function handleDelete(id: string): Promise<void> {
    try {
      await deleteMusicTrack(id);
      showSuccessToast("音乐已删除");
      await load(page, pageSize);
    } catch (requestError: unknown) {
      setError(errorMessage(requestError, "删除音乐失败"));
    }
  }

  const columns: ColumnsType<AdminMusicTrack> = [
    {
      title: "歌曲",
      dataIndex: "title",
      width: "26%",
      render: (_, record) => (
        <div className="music-track-cell">
          <MusicCoverThumb track={record} />
          <div className="table-meta-stack">
            <strong className="table-primary-text table-clip">
              {record.title}
            </strong>
            <Typography.Text
              type="secondary"
              ellipsis
              style={{ maxWidth: "100%" }}
            >
              {record.artist || "未填写歌手"}
              {record.album ? ` · ${record.album}` : ""}
            </Typography.Text>
          </div>
        </div>
      ),
    },
    {
      title: "试听",
      dataIndex: "audioUrl",
      width: "17%",
      render: (value: string) => (
        <audio controls preload="none" src={resolveApiAssetUrl(value)} />
      ),
    },
    {
      title: "文件信息",
      dataIndex: "originalName",
      width: "27%",
      render: (value: string, record) => (
        <div className="table-meta-stack">
          <Tooltip title={`${value} · ${formatFileSize(record.size)}`}>
            <span className="table-clip">
              {value} · {formatFileSize(record.size)}
            </span>
          </Tooltip>
          <Typography.Text type="secondary" ellipsis>
            更新：{formatDateTime(record.updatedAt)}
          </Typography.Text>
        </div>
      ),
    },
    {
      title: "配置",
      width: "18%",
      render: (_, record) => (
        <Space wrap size={[8, 8]} className="table-control-pack">
          <Switch
            checked={record.enabled}
            checkedChildren="启用"
            unCheckedChildren="停用"
            onChange={() => void handleToggle(record)}
          />
          <Tag>排序 {record.sortOrder}</Tag>
          <Tag color={record.lyrics ? "blue" : "default"}>
            {record.lyrics ? "已加歌词" : "无歌词"}
          </Tag>
        </Space>
      ),
    },
    {
      title: "操作",
      width: "12%",
      className: "table-actions",
      render: (_, record) => (
        <Space>
          <Button
            type="link"
            icon={<EditOutlined />}
            onClick={() => openEdit(record)}
          >
            编辑
          </Button>
          <Popconfirm
            title="删除音乐"
            description="确认删除这首音乐吗？"
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

  const audioUploadProps = buildSingleUploadProps({
    accept:
      "audio/mpeg,audio/mp4,audio/aac,audio/wav,audio/flac,audio/ogg,audio/webm",
    maxBytes: 80 * 1024 * 1024,
    onSelect: setAudioFile,
  });
  const coverUploadProps = buildSingleUploadProps({
    accept: "image/png,image/jpeg,image/webp",
    maxBytes: 5 * 1024 * 1024,
    onSelect: setCoverFile,
  });
  const lyricsUploadProps = buildSingleUploadProps({
    accept: ".lrc,.txt,text/plain",
    maxBytes: 512 * 1024,
    onSelect: setLyricsFile,
  });

  return (
    <>
      <PageHeader
        eyebrow={
          <>
            <CustomerServiceOutlined /> 音乐播放器
          </>
        }
        title="音乐管理"
        subtitle="上传歌曲、封面与歌词，APP 端只展示已启用的音乐。"
        extra={
          <Space wrap>
            <Button icon={<ReloadOutlined />} onClick={() => void load()}>
              刷新
            </Button>
            <Button type="primary" icon={<PlusOutlined />} onClick={openCreate}>
              上传音乐
            </Button>
          </Space>
        }
      />

      <div className="toolbar">
        <Input.Search
          allowClear
          prefix={<SearchOutlined />}
          placeholder="搜索歌曲、歌手或专辑"
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
            { value: "true", label: "启用" },
            { value: "false", label: "停用" },
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
          onChange={(pagination: TablePaginationConfig) =>
            void load(pagination.current ?? 1, pagination.pageSize ?? 20)
          }
          pagination={{ current: page, pageSize, total, showSizeChanger: true }}
          locale={{
            emptyText: (
              <Empty description="暂无音乐，点击右上角上传第一首歌曲。" />
            ),
          }}
        />
      </Card>

      <Modal
        title={
          <Space>
            <CustomerServiceOutlined />
            <span>{editing ? "编辑音乐" : "上传音乐"}</span>
          </Space>
        }
        open={modalOpen}
        width={860}
        okText={editing ? "保存音乐" : "上传音乐"}
        cancelText="取消"
        confirmLoading={saving}
        onCancel={() => setModalOpen(false)}
        onOk={() => void handleSubmit()}
        destroyOnClose
      >
        <Form form={form} layout="vertical">
          <Space size={16} align="start" className="music-editor-layout">
            <div className="music-editor-fields">
              <Form.Item
                label="歌曲名称"
                name="title"
                rules={[{ required: true, message: "请输入歌曲名称" }]}
              >
                <Input maxLength={120} placeholder="例如：晴天" />
              </Form.Item>
              <Space.Compact block>
                <Form.Item label="歌手" name="artist" style={{ width: "50%" }}>
                  <Input maxLength={80} placeholder="可选" />
                </Form.Item>
                <Form.Item label="专辑" name="album" style={{ width: "50%" }}>
                  <Input maxLength={80} placeholder="可选" />
                </Form.Item>
              </Space.Compact>
              <Space.Compact block>
                <Form.Item
                  label="排序"
                  name="sortOrder"
                  style={{ width: "50%" }}
                >
                  <InputNumber min={0} max={999999} style={{ width: "100%" }} />
                </Form.Item>
                <Form.Item
                  label="启用状态"
                  name="enabled"
                  valuePropName="checked"
                  style={{ width: "50%" }}
                >
                  <Switch checkedChildren="启用" unCheckedChildren="停用" />
                </Form.Item>
              </Space.Compact>
              <Form.Item label="歌词" name="lyrics">
                <TextArea
                  rows={7}
                  maxLength={10000}
                  showCount
                  placeholder="可直接粘贴 LRC 歌词，也可以上传 .lrc / .txt 文件。"
                />
              </Form.Item>
            </div>
            <div className="music-upload-panel">
              <Upload.Dragger {...audioUploadProps}>
                <p className="ant-upload-drag-icon">
                  <UploadOutlined />
                </p>
                <p className="ant-upload-text">
                  {audioFile?.name ??
                    (editing ? "替换音乐文件" : "上传音乐文件")}
                </p>
                <p className="ant-upload-hint">
                  MP3 / AAC / WAV / FLAC，最大 80MB
                </p>
              </Upload.Dragger>
              <Upload {...coverUploadProps}>
                <Button icon={<UploadOutlined />}>
                  {coverFile?.name ?? "上传封面"}
                </Button>
              </Upload>
              <Upload {...lyricsUploadProps}>
                <Button icon={<UploadOutlined />}>
                  {lyricsFile?.name ?? "上传歌词文件"}
                </Button>
              </Upload>
              {saving && <Progress percent={uploadPercent} size="small" />}
            </div>
          </Space>
        </Form>
      </Modal>
    </>
  );
}

function MusicCoverThumb({
  track,
}: {
  track: AdminMusicTrack;
}): React.JSX.Element {
  const [loadFailed, setLoadFailed] = useState(false);
  const coverUrl = track.coverUrl ? resolveApiAssetUrl(track.coverUrl) : null;

  return (
    <div className="music-cover-thumb">
      {coverUrl && !loadFailed ? (
        <img
          src={coverUrl}
          alt={track.title}
          onError={() => setLoadFailed(true)}
        />
      ) : (
        <CustomerServiceOutlined />
      )}
    </div>
  );
}

function buildSingleUploadProps(input: {
  accept: string;
  maxBytes: number;
  onSelect: (file: RcFile) => void;
}): UploadProps {
  return {
    accept: input.accept,
    maxCount: 1,
    showUploadList: false,
    beforeUpload: (file) => {
      if (file.size > input.maxBytes) {
        void message.error("文件大小超过限制");
        return Upload.LIST_IGNORE;
      }
      input.onSelect(file);
      return false;
    },
  };
}

function errorMessage(error: unknown, fallback: string): string {
  return error instanceof Error && error.message ? error.message : fallback;
}
