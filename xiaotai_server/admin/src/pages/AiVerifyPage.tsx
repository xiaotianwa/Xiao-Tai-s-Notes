import {
  ApiOutlined,
  CheckCircleOutlined,
  ClockCircleOutlined,
  SendOutlined,
} from '@ant-design/icons';
import { Alert, Button, Card, Input, Space, Tag } from 'antd';
import { useState } from 'react';

import { verifyAiModel } from '../api/admin';
import { ApiError } from '../api/client';
import PageHeader, { StatCard } from '../components/PageHeader';

const defaultPrompt =
  '请只用一段中文回答：你正在通过腾讯云 TokenHub 被调用。回答时先写“模型连通正常”，再给出一句 20 字以内的验证说明。';

interface VerifyResult {
  answer: string;
  model: string;
  elapsedMs: number;
  checkedAt: Date;
}

function formatCheckedAt(value: Date): string {
  return new Intl.DateTimeFormat('zh-CN', {
    year: 'numeric',
    month: 'long',
    day: 'numeric',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false,
  }).format(value);
}

export default function AiVerifyPage(): React.JSX.Element {
  const [prompt, setPrompt] = useState(defaultPrompt);
  const [result, setResult] = useState<VerifyResult | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function runVerification(): Promise<void> {
    const message = prompt.trim();
    if (!message) {
      setError('请输入用于验证的提示词');
      return;
    }
    setLoading(true);
    setError(null);
    const startedAt = performance.now();
    try {
      const response = await verifyAiModel(message);
      setResult({
        answer: response.answer,
        model: response.model,
        elapsedMs: Math.round(performance.now() - startedAt),
        checkedAt: new Date(),
      });
    } catch (requestError) {
      setError(
        requestError instanceof ApiError
          ? requestError.message
          : 'AI 验证失败，请检查后端模型配置',
      );
    } finally {
      setLoading(false);
    }
  }

  return (
    <>
      <PageHeader
        eyebrow={
          <>
            <ApiOutlined /> AI 验证
          </>
        }
        title="模型调用验证"
        subtitle="通过项目后端实时调用 AI 接口，确认当前生产环境实际使用的模型与返回内容。"
        extra={
          <Button
            type="primary"
            icon={<SendOutlined />}
            loading={loading}
            onClick={() => void runVerification()}
          >
            发起验证
          </Button>
        }
      />

      {error && (
        <Alert
          type="error"
          showIcon
          title="验证失败"
          description={error}
          action={
            <Button
              size="small"
              type="link"
              onClick={() => void runVerification()}
            >
              重试
            </Button>
          }
          style={{ marginBottom: 16 }}
          closable
          onClose={() => setError(null)}
        />
      )}

      <div className="metric-grid">
        <StatCard
          label="目标模型"
          value={result?.model ?? 'deepseek-v4-pro-202606'}
          hint="来自后端 AI 配置或本次响应"
          icon={<ApiOutlined />}
          tone="info"
        />
        <StatCard
          label="调用状态"
          value={result ? '已连通' : '待验证'}
          hint={result ? formatCheckedAt(result.checkedAt) : '点击发起验证'}
          icon={<CheckCircleOutlined />}
          tone={result ? 'success' : 'warning'}
        />
        <StatCard
          label="响应耗时"
          value={result ? `${result.elapsedMs} ms` : '-'}
          hint="浏览器到后端再到模型服务"
          icon={<ClockCircleOutlined />}
          tone="primary"
        />
      </div>

      <div className="ai-verify-grid">
        <Card title="验证提示词" className="soft-card">
          <Space direction="vertical" size={12} style={{ width: '100%' }}>
            <Input.TextArea
              value={prompt}
              onChange={(event) => setPrompt(event.target.value)}
              autoSize={{ minRows: 7, maxRows: 12 }}
              maxLength={8000}
              showCount
              disabled={loading}
            />
            <Space wrap>
              <Button
                type="primary"
                icon={<SendOutlined />}
                loading={loading}
                onClick={() => void runVerification()}
              >
                发送到后端 AI
              </Button>
              <Button disabled={loading} onClick={() => setPrompt(defaultPrompt)}>
                恢复默认
              </Button>
            </Space>
          </Space>
        </Card>

        <Card
          title="模型返回"
          className="soft-card"
          extra={result ? <Tag color="green">{result.model}</Tag> : null}
        >
          {result ? (
            <div className="ai-verify-answer">{result.answer}</div>
          ) : (
            <div className="ai-verify-empty">
              还没有验证结果。发起验证后，这里会显示模型的原始回复。
            </div>
          )}
        </Card>
      </div>
    </>
  );
}
