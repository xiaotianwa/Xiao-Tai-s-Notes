import {
  AppstoreOutlined,
  AuditOutlined,
  BarChartOutlined,
  CloudServerOutlined,
  CloudSyncOutlined,
  DatabaseOutlined,
  FieldTimeOutlined,
  LockOutlined,
  MobileOutlined,
  RocketOutlined,
  SafetyCertificateOutlined,
  ThunderboltOutlined,
  UserOutlined,
} from '@ant-design/icons';
import { Alert, Button, Form, Input } from 'antd';
import { useState } from 'react';
import { Navigate, useNavigate } from 'react-router-dom';

import { login } from '../api/admin';
import { ApiError } from '../api/client';
import { useSession } from '../auth/session';
import loginHero from '../assets/login-hero.jpeg';

interface LoginFormValues {
  username: string;
  password: string;
}

export default function LoginPage(): React.JSX.Element {
  const navigate = useNavigate();
  const { session, signIn } = useSession();
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  if (session) {
    return <Navigate to="/" replace />;
  }

  async function handleFinish(values: LoginFormValues): Promise<void> {
    setError(null);
    setLoading(true);
    try {
      const tokens = await login(values.username, values.password);
      if (tokens.user.role !== 'admin') {
        setError('当前账号不是管理员，无法进入管理端');
        return;
      }
      signIn(tokens);
      navigate('/', { replace: true });
    } catch (requestError) {
      setError(
        requestError instanceof ApiError
          ? requestError.message
          : '登录失败，请稍后重试',
      );
    } finally {
      setLoading(false);
    }
  }

  return (
    <main className="login-page">
      <div className="login-shell">
        <section className="login-brand">
          <div className="login-brand-copy">
            <span className="login-brand-eyebrow">
              <SafetyCertificateOutlined /> 婷婷的小笨笔记 · 私有管理端
            </span>
            <h1 className="login-brand-title">
              两个人的小世界，也要有稳稳的后台
            </h1>
            <p className="login-brand-subtitle">
              管理同步、媒体、版本和公告，把 App 的每一次记录都安放在可检查、可恢复、可追踪的私有控制台里。
            </p>
          </div>

          <div className="login-hero-board" aria-hidden="true">
            <div className="login-hero-image">
              <img src={loginHero} alt="" />
              <span className="login-hero-tag">
                <CloudSyncOutlined /> 私有同步在线
              </span>
            </div>
            <div className="login-hero-content">
              <div>
                <span className="login-hero-label">今日守护</span>
                <strong>同步、媒体、版本</strong>
              </div>
              <div className="login-hero-mini-grid">
                <span>
                  <DatabaseOutlined />
                  数据
                </span>
                <span>
                  <MobileOutlined />
                  设备
                </span>
                <span>
                  <AuditOutlined />
                  审计
                </span>
              </div>
            </div>
          </div>

          <div className="login-insight-grid">
            <div className="login-insight-card">
              <BarChartOutlined />
              <span>
                <strong>同步可视化</strong>
                <small>查看用户数据规模与设备同步状态</small>
              </span>
            </div>
            <div className="login-insight-card">
              <AppstoreOutlined />
              <span>
                <strong>内容可治理</strong>
                <small>维护公告、媒体、记录与备忘数据</small>
              </span>
            </div>
            <div className="login-insight-card">
              <RocketOutlined />
              <span>
                <strong>版本可灰度</strong>
                <small>发布私有 APK 并控制强制更新</small>
              </span>
            </div>
          </div>
        </section>
        <section className="login-panel">
          <div className="login-panel-header">
            <span className="login-panel-icon">
              <CloudServerOutlined />
            </span>
            <div>
              <h2 className="login-title">登录管理控制台</h2>
              <p className="login-subtitle">使用管理员账号进入私有后台</p>
            </div>
          </div>
          <div className="login-panel-badges">
            <span>
              <SafetyCertificateOutlined /> 管理员权限
            </span>
            <span>
              <FieldTimeOutlined /> 登录态托管
            </span>
          </div>
          {error && (
            <Alert
              type="error"
              showIcon
              title="登录失败"
              description={error}
              style={{ marginBottom: 16 }}
              closable
              onClose={() => setError(null)}
            />
          )}
          <Form<LoginFormValues>
            layout="vertical"
            size="large"
            onFinish={handleFinish}
          >
            <Form.Item
              label="管理员账号"
              name="username"
              rules={[{ required: true, message: '请输入管理员账号' }]}
            >
              <Input
                prefix={<UserOutlined />}
                autoComplete="username"
                placeholder="请输入账号"
              />
            </Form.Item>
            <Form.Item
              label="密码"
              name="password"
              rules={[{ required: true, message: '请输入密码' }]}
            >
              <Input.Password
                prefix={<LockOutlined />}
                autoComplete="current-password"
                placeholder="请输入登录密码"
              />
            </Form.Item>
            <Button
              type="primary"
              htmlType="submit"
              loading={loading}
              block
              size="large"
              icon={<ThunderboltOutlined />}
            >
              登录控制台
            </Button>
          </Form>
          <div className="login-panel-note">
            <SafetyCertificateOutlined />
            <span>仅允许管理员账号访问，登录后会使用本地安全存储保存会话。</span>
          </div>
        </section>
      </div>
    </main>
  );
}
