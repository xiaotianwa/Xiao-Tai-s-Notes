import {
  BellOutlined,
  DeleteOutlined,
  PlusOutlined,
  ReloadOutlined,
} from "@ant-design/icons";
import {
  Alert,
  Button,
  Card,
  Drawer,
  Form,
  Input,
  Popconfirm,
  Radio,
  Select,
  Space,
  Switch,
  Table,
  Tag,
} from "antd";
import type { ColumnsType, TablePaginationConfig } from "antd/es/table";
import { useEffect, useState } from "react";

import {
  createForcePush,
  deleteForcePush,
  getForcePushes,
  getUsers,
  updateForcePush,
} from "../api/admin";
import { ApiError } from "../api/client";
import type { AdminUser, ForcePush } from "../api/types";
import PageHeader from "../components/PageHeader";
import { formatDateTime } from "../utils/format";
import { showSuccessToast } from "../utils/operationToast";

interface ForcePushFormValues {
  userId: string;
  title: string;
  content: string;
  level: ForcePush["level"];
  expiresAt?: string;
}

export default function ForcePushPage(): React.JSX.Element {
  const [items, setItems] = useState<ForcePush[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(20);
  const [level, setLevel] = useState<string>();
  const [enabled, setEnabled] = useState<string>();
  const [users, setUsers] = useState<AdminUser[]>([]);
  const [drawerOpen, setDrawerOpen] = useState(false);
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [form] = Form.useForm<ForcePushFormValues>();

  async function load(nextPage = page, nextPageSize = pageSize): Promise<void> {
    setLoading(true);
    setError(null);
    try {
      const [pushPage, userPage] = await Promise.all([
        getForcePushes({
          page: nextPage,
          pageSize: nextPageSize,
          level,
          enabled,
        }),
        getUsers({ page: 1, pageSize: 100 }),
      ]);
      setItems(pushPage.items);
      setTotal(pushPage.total);
      setPage(pushPage.page);
      setPageSize(pushPage.pageSize);
      setUsers(userPage.items);
    } catch (requestError) {
      setError(
        requestError instanceof ApiError
          ? requestError.message
          : "强提醒数据加载失败",
      );
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void load(1, pageSize);
  }, []);

  async function handleCreate(values: ForcePushFormValues): Promise<void> {
    setSaving(true);
    setError(null);
    try {
      await createForcePush({
        userId: values.userId,
        title: values.title,
        content: values.content,
        level: values.level,
        expiresAt: values.expiresAt || null,
      });
      showSuccessToast("强提醒已发布");
      setDrawerOpen(false);
      form.resetFields();
      await load(1, pageSize);
    } catch (requestError) {
      setError(
        requestError instanceof ApiError
          ? requestError.message
          : "强提醒发布失败",
      );
    } finally {
      setSaving(false);
    }
  }

  async function toggleEnabled(
    row: ForcePush,
    checked: boolean,
  ): Promise<void> {
    setError(null);
    try {
      await updateForcePush(row.id, { enabled: checked });
      showSuccessToast(checked ? "强提醒已启用" : "强提醒已禁用");
      await load(page, pageSize);
    } catch (requestError) {
      setError(
        requestError instanceof ApiError
          ? requestError.message
          : "状态更新失败",
      );
    }
  }

  async function remove(row: ForcePush): Promise<void> {
    setError(null);
    try {
      await deleteForcePush(row.id);
      showSuccessToast("强提醒已删除");
      await load(page, pageSize);
    } catch (requestError) {
      setError(
        requestError instanceof ApiError ? requestError.message : "删除失败",
      );
    }
  }

  function handleTableChange(pagination: TablePaginationConfig): void {
    void load(pagination.current ?? 1, pagination.pageSize ?? 20);
  }

  const columns: ColumnsType<ForcePush> = [
    {
      title: "标题",
      width: 360,
      ellipsis: true,
      render: (_, row) => (
        <Space direction="vertical" size={2}>
          <strong className="table-primary-text table-clip">{row.title}</strong>
          <span className="table-subtle-text table-clip">{row.content}</span>
        </Space>
      ),
    },
    {
      title: "级别",
      dataIndex: "level",
      width: 100,
      render: (value: ForcePush["level"]) => <LevelTag level={value} />,
    },
    {
      title: "目标",
      width: 220,
      render: (_, row) => (
        <Space direction="vertical" size={2}>
          <span>{row.nickname || row.username || row.userId}</span>
          <span className="table-subtle-text">用户登录设备</span>
        </Space>
      ),
    },
    {
      title: "送达状态",
      width: 130,
      render: (_, row) =>
        row.deliveredAt ? (
          <Tag color="green">已送达</Tag>
        ) : (
          <Tag color="gold">未送达</Tag>
        ),
    },
    {
      title: "启用",
      width: 100,
      render: (_, row) => (
        <Switch
          checked={row.enabled}
          onChange={(checked) => void toggleEnabled(row, checked)}
        />
      ),
    },
    {
      title: "创建时间",
      dataIndex: "createdAt",
      width: 180,
      className: "table-date",
      render: (value: string) => formatDateTime(value),
    },
    {
      title: "操作",
      width: 110,
      className: "table-actions",
      render: (_, row) => (
        <Popconfirm
          title="删除强提醒"
          description="确认删除这条强提醒？"
          okText="删除"
          okButtonProps={{ danger: true }}
          cancelText="取消"
          onConfirm={() => void remove(row)}
        >
          <Button type="link" danger icon={<DeleteOutlined />}>
            删除
          </Button>
        </Popconfirm>
      ),
    },
  ];

  return (
    <>
      <PageHeader
        eyebrow={
          <>
            <BellOutlined /> 强提醒
          </>
        }
        title="实时强提醒发布"
        subtitle="向已授权强提醒的登录用户发布系统级悬浮提醒，手机端轮询命中后会弹窗并回写送达状态。"
        extra={
          <Space>
            <Button icon={<ReloadOutlined />} onClick={() => void load()}>
              刷新
            </Button>
            <Button
              type="primary"
              icon={<PlusOutlined />}
              onClick={() => setDrawerOpen(true)}
            >
              新建强提醒
            </Button>
          </Space>
        }
      />
      <div className="toolbar-card">
        <div className="toolbar">
          <Select
            allowClear
            placeholder="级别"
            style={{ width: 160 }}
            value={level}
            onChange={setLevel}
            options={[
              { value: "info", label: "普通" },
              { value: "warn", label: "警告" },
              { value: "critical", label: "紧急" },
            ]}
          />
          <Select
            allowClear
            placeholder="状态"
            style={{ width: 160 }}
            value={enabled}
            onChange={setEnabled}
            options={[
              { value: "true", label: "启用" },
              { value: "false", label: "禁用" },
            ]}
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
          style={{ marginBottom: 14 }}
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
          pagination={{ current: page, pageSize, total, showSizeChanger: true }}
          onChange={handleTableChange}
        />
      </Card>
      <Drawer
        title="新建强提醒"
        open={drawerOpen}
        width={520}
        destroyOnClose
        onClose={() => setDrawerOpen(false)}
        extra={
          <Space>
            <Button onClick={() => setDrawerOpen(false)}>取消</Button>
            <Button
              type="primary"
              loading={saving}
              onClick={() => form.submit()}
            >
              发布
            </Button>
          </Space>
        }
      >
        <Alert
          type="info"
          showIcon
          style={{ marginBottom: 18 }}
          title="仅向已登录并授权悬浮窗的用户发布强提醒，不再采集或展示设备使用内容。"
        />
        <Form<ForcePushFormValues>
          form={form}
          layout="vertical"
          initialValues={{ level: "warn" }}
          onFinish={handleCreate}
        >
          <Form.Item
            label="目标用户"
            name="userId"
            rules={[{ required: true, message: "请选择目标用户" }]}
          >
            <Select
              showSearch
              placeholder="选择用户"
              optionFilterProp="label"
              options={users.map((user) => ({
                value: user.id,
                label: `${user.nickname} / ${user.username}`,
              }))}
            />
          </Form.Item>
          <Form.Item
            label="标题"
            name="title"
            rules={[{ required: true, message: "请输入标题" }]}
          >
            <Input maxLength={80} />
          </Form.Item>
          <Form.Item
            label="内容"
            name="content"
            rules={[{ required: true, message: "请输入内容" }]}
          >
            <Input.TextArea rows={5} maxLength={2000} showCount />
          </Form.Item>
          <Form.Item label="级别" name="level">
            <Radio.Group
              options={[
                { value: "info", label: "普通" },
                { value: "warn", label: "警告" },
                { value: "critical", label: "紧急" },
              ]}
            />
          </Form.Item>
          <Form.Item label="过期时间" name="expiresAt">
            <Input placeholder="可选，ISO 时间，例如 2026-05-29T12:00:00+08:00" />
          </Form.Item>
        </Form>
      </Drawer>
    </>
  );
}

function LevelTag({ level }: { level: ForcePush["level"] }): React.JSX.Element {
  if (level === "critical") {
    return <Tag color="red">紧急</Tag>;
  }
  if (level === "warn") {
    return <Tag color="gold">警告</Tag>;
  }
  return <Tag color="blue">普通</Tag>;
}
