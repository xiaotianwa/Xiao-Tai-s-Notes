import {
  DeleteOutlined,
  PlusOutlined,
  ReloadOutlined,
  SearchOutlined,
  TeamOutlined,
} from "@ant-design/icons";
import {
  Alert,
  Button,
  Card,
  Descriptions,
  Empty,
  Form,
  Input,
  Modal,
  Popconfirm,
  Select,
  Space,
  Table,
  Tag,
} from "antd";
import type { ColumnsType, TablePaginationConfig } from "antd/es/table";
import { useEffect, useState } from "react";

import PageHeader from "../components/PageHeader";

import {
  createAdminUser,
  deleteAdminUser,
  getUserDetail,
  getUsers,
  resetAdminUserPassword,
  updateAdminUserStatus,
} from "../api/admin";
import { ApiError } from "../api/client";
import type { AdminDevice, AdminUser } from "../api/types";
import { formatDateTime } from "../utils/format";
import { showSuccessToast } from "../utils/operationToast";

interface CreateUserValues {
  username: string;
  nickname: string;
  password: string;
  role: "user" | "admin";
  status: "active" | "disabled";
}

interface ResetPasswordValues {
  password: string;
}

const roleOptions = [
  { value: "user", label: "普通用户" },
  { value: "admin", label: "管理员" },
];

const statusOptions = [
  { value: "active", label: "启用" },
  { value: "disabled", label: "停用" },
];

function roleLabel(value: string): string {
  return value === "admin" ? "管理员" : "普通用户";
}

function statusLabel(value: string): string {
  return value === "active" ? "启用" : "停用";
}

export default function UsersPage(): React.JSX.Element {
  const [items, setItems] = useState<AdminUser[]>([]);
  const [total, setTotal] = useState(0);
  const [page, setPage] = useState(1);
  const [pageSize, setPageSize] = useState(20);
  const [keyword, setKeyword] = useState("");
  const [status, setStatus] = useState<string | undefined>();
  const [loading, setLoading] = useState(false);
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [createOpen, setCreateOpen] = useState(false);
  const [resetUser, setResetUser] = useState<AdminUser | null>(null);
  const [detail, setDetail] = useState<
    (AdminUser & { devices: AdminDevice[]; syncItemCount: number }) | null
  >(null);
  const [createForm] = Form.useForm<CreateUserValues>();
  const [resetForm] = Form.useForm<ResetPasswordValues>();

  async function load(nextPage = page, nextPageSize = pageSize): Promise<void> {
    setLoading(true);
    setError(null);
    try {
      const result = await getUsers({
        page: nextPage,
        pageSize: nextPageSize,
        keyword,
        status,
      });
      setItems(result.items);
      setTotal(result.total);
      setPage(result.page);
      setPageSize(result.pageSize);
    } catch (requestError) {
      setError(
        requestError instanceof ApiError
          ? requestError.message
          : "用户加载失败",
      );
    } finally {
      setLoading(false);
    }
  }

  async function openDetail(id: string): Promise<void> {
    try {
      setDetail(await getUserDetail(id));
    } catch (requestError) {
      setError(
        requestError instanceof ApiError
          ? requestError.message
          : "详情加载失败",
      );
    }
  }

  async function handleCreate(): Promise<void> {
    const values = await createForm.validateFields();
    setSaving(true);
    setError(null);
    try {
      await createAdminUser(values);
      setCreateOpen(false);
      createForm.resetFields();
      showSuccessToast(`用户 ${values.nickname} 创建成功`);
      await load(1, pageSize);
    } catch (requestError) {
      setError(
        requestError instanceof ApiError
          ? requestError.message
          : "创建用户失败，请检查网络连接后重试",
      );
    } finally {
      setSaving(false);
    }
  }

  async function handleResetPassword(): Promise<void> {
    if (!resetUser) {
      return;
    }
    const values = await resetForm.validateFields();
    setSaving(true);
    setError(null);
    try {
      await resetAdminUserPassword(resetUser.id, values);
      setResetUser(null);
      resetForm.resetFields();
      showSuccessToast(`${resetUser.nickname} 的密码已重置，旧登录态已失效`);
      await load(page, pageSize);
    } catch (requestError) {
      setError(
        requestError instanceof ApiError
          ? requestError.message
          : "重置密码失败，请检查网络连接后重试",
      );
    } finally {
      setSaving(false);
    }
  }

  async function handleStatusChange(user: AdminUser): Promise<void> {
    const nextStatus = user.status === "active" ? "disabled" : "active";
    const actionText = nextStatus === "active" ? "启用" : "停用";
    setLoading(true);
    setError(null);
    try {
      await updateAdminUserStatus(user.id, { status: nextStatus });
      showSuccessToast(`已${actionText}用户 ${user.nickname}`);
      await load(page, pageSize);
    } catch (requestError) {
      setError(
        requestError instanceof ApiError
          ? requestError.message
          : `${actionText}用户失败，请检查网络连接后重试`,
      );
    } finally {
      setLoading(false);
    }
  }

  async function handleDelete(user: AdminUser): Promise<void> {
    setLoading(true);
    setError(null);
    try {
      const result = await deleteAdminUser(user.id);
      setDetail((current) => (current?.id === user.id ? null : current));
      showSuccessToast(
        `已删除用户 ${result.user.nickname}，同步数据 ${result.related.syncItems} 条、媒体 ${result.related.mediaAssets} 条、设备 ${result.related.devices} 个已同步清理`,
      );
      await load(page, pageSize);
    } catch (requestError) {
      setError(
        requestError instanceof ApiError
          ? requestError.message
          : "删除用户失败，请检查网络连接后重试",
      );
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void load(1, pageSize);
  }, []);

  const columns: ColumnsType<AdminUser> = [
    { title: "昵称", dataIndex: "nickname", width: 150, ellipsis: true },
    { title: "账号", dataIndex: "username", width: 150, ellipsis: true },
    {
      title: "角色",
      dataIndex: "role",
      width: 100,
      render: (value: string) => (
        <Tag color={value === "admin" ? "gold" : "blue"}>
          {roleLabel(value)}
        </Tag>
      ),
    },
    {
      title: "状态",
      dataIndex: "status",
      width: 100,
      render: (value: string) => (
        <Tag color={value === "active" ? "green" : "red"}>
          {statusLabel(value)}
        </Tag>
      ),
    },
    { title: "数据量", dataIndex: "syncItemCount", width: 100 },
    {
      title: "创建时间",
      dataIndex: "createdAt",
      width: 180,
      className: "table-date",
      render: (value: string) => formatDateTime(value),
    },
    {
      title: "操作",
      width: 260,
      className: "table-actions",
      render: (_, row) => {
        const nextText = row.status === "active" ? "停用" : "启用";
        return (
          <Space size={4}>
            <Button type="link" onClick={() => void openDetail(row.id)}>
              查看
            </Button>
            <Button
              type="link"
              onClick={() => {
                setResetUser(row);
                resetForm.resetFields();
              }}
            >
              重置密码
            </Button>
            <Popconfirm
              title={`${nextText}账号`}
              description={`确认${nextText} ${row.nickname} 吗？`}
              okText="确认"
              cancelText="取消"
              onConfirm={() => void handleStatusChange(row)}
            >
              <Button type="link" danger={row.status === "active"}>
                {nextText}
              </Button>
            </Popconfirm>
            <Popconfirm
              title="删除用户及关联内容"
              description={`确认删除 ${row.nickname} 吗？该用户的登录态、设备、同步数据和媒体记录会一并删除。`}
              okText="确认删除"
              cancelText="取消"
              okButtonProps={{ danger: true }}
              onConfirm={() => void handleDelete(row)}
            >
              <Button type="link" danger icon={<DeleteOutlined />}>
                删除
              </Button>
            </Popconfirm>
          </Space>
        );
      },
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
            <TeamOutlined /> 用户管理
          </>
        }
        title="账号与同步用户"
        subtitle="创建 APP 登录账号，管理账号状态，并在需要时重置密码。"
        extra={
          <Button
            type="primary"
            icon={<PlusOutlined />}
            onClick={() => {
              createForm.setFieldsValue({
                role: "user",
                status: "active",
              });
              setCreateOpen(true);
            }}
          >
            新建用户
          </Button>
        }
      />
      <div className="toolbar-card">
        <div className="toolbar">
          <Input.Search
            allowClear
            prefix={<SearchOutlined />}
            placeholder="搜索账号或昵称"
            style={{ width: 320 }}
            value={keyword}
            onChange={(event) => setKeyword(event.target.value)}
            onSearch={() => void load(1, pageSize)}
          />
          <Select
            allowClear
            placeholder="账号状态"
            style={{ width: 160 }}
            value={status}
            options={statusOptions}
            onChange={(value) => setStatus(value)}
          />
          <Button type="primary" ghost onClick={() => void load(1, pageSize)}>
            筛选
          </Button>
          <div className="toolbar-spacer" />
          <Button
            icon={<ReloadOutlined />}
            onClick={() => void load(page, pageSize)}
          >
            刷新
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
          columns={columns}
          dataSource={items}
          tableLayout="fixed"
          onChange={handleTableChange}
          pagination={{ current: page, pageSize, total, showSizeChanger: true }}
          locale={{
            emptyText: (
              <Empty description="暂无用户数据，点击右上角「新建用户」创建第一个账号" />
            ),
          }}
        />
      </Card>
      <Modal
        title="用户详情"
        open={Boolean(detail)}
        onCancel={() => setDetail(null)}
        footer={null}
        width={820}
        className="detail-modal"
      >
        {detail && (
          <Descriptions column={1} bordered size="middle">
            <Descriptions.Item label="昵称">
              {detail.nickname}
            </Descriptions.Item>
            <Descriptions.Item label="账号">
              {detail.username}
            </Descriptions.Item>
            <Descriptions.Item label="角色">
              {roleLabel(detail.role)}
            </Descriptions.Item>
            <Descriptions.Item label="状态">
              {statusLabel(detail.status)}
            </Descriptions.Item>
            <Descriptions.Item label="同步数据">
              {detail.syncItemCount}
            </Descriptions.Item>
            <Descriptions.Item label="设备数量">
              {detail.devices.length}
            </Descriptions.Item>
            <Descriptions.Item label="创建时间">
              {formatDateTime(detail.createdAt)}
            </Descriptions.Item>
          </Descriptions>
        )}
      </Modal>
      <Modal
        title="新建用户"
        open={createOpen}
        okText="创建用户"
        cancelText="取消"
        confirmLoading={saving}
        onCancel={() => {
          setCreateOpen(false);
          createForm.resetFields();
        }}
        onOk={() => void handleCreate()}
        destroyOnClose
      >
        <Form<CreateUserValues>
          form={createForm}
          layout="vertical"
          initialValues={{
            role: "user",
            status: "active",
          }}
        >
          <Form.Item
            label="账号"
            name="username"
            rules={[
              { required: true, message: "请输入账号" },
              { min: 3, max: 32, message: "账号长度为 3-32 个字符" },
              {
                pattern: /^[a-zA-Z0-9_.-]+$/,
                message: "账号只能包含字母、数字、下划线、点和短横线",
              },
            ]}
          >
            <Input placeholder="例如 xiaotai" />
          </Form.Item>
          <Form.Item
            label="昵称"
            name="nickname"
            rules={[{ required: true, message: "请输入昵称" }]}
          >
            <Input placeholder="显示在管理端和 APP 同步记录中" />
          </Form.Item>
          <Form.Item
            label="初始密码"
            name="password"
            rules={[
              { required: true, message: "请输入初始密码" },
              { min: 8, message: "密码至少 8 位" },
            ]}
            extra="建议使用包含字母、数字和符号的强密码"
          >
            <Input.Password placeholder="至少 8 位，建议使用强密码" />
          </Form.Item>
          <Form.Item label="角色" name="role">
            <Select options={roleOptions} />
          </Form.Item>
          <Form.Item label="状态" name="status">
            <Select options={statusOptions} />
          </Form.Item>
        </Form>
      </Modal>
      <Modal
        title={`重置密码：${resetUser?.nickname ?? ""}`}
        open={Boolean(resetUser)}
        okText="确认重置"
        okButtonProps={{ danger: true }}
        cancelText="取消"
        confirmLoading={saving}
        onCancel={() => {
          setResetUser(null);
          resetForm.resetFields();
        }}
        onOk={() => void handleResetPassword()}
        destroyOnClose
      >
        <Alert
          type="warning"
          showIcon
          title="重置密码后，该用户的所有登录态将立即失效"
          description="用户需要使用新密码重新登录 APP 和管理端"
          style={{ marginBottom: 16 }}
        />
        <Form<ResetPasswordValues> form={resetForm} layout="vertical">
          <Form.Item
            label="新密码"
            name="password"
            rules={[
              { required: true, message: "请输入新密码" },
              { min: 8, message: "密码至少 8 位" },
            ]}
            extra="建议使用包含字母、数字和符号的强密码"
          >
            <Input.Password placeholder="至少 8 位，建议使用强密码" />
          </Form.Item>
        </Form>
      </Modal>
    </>
  );
}
