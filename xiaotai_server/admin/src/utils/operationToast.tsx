import {
  CheckCircleOutlined,
  CloseCircleOutlined,
  InfoCircleOutlined,
  WarningOutlined,
} from '@ant-design/icons';
import { Modal } from 'antd';
import type { ReactNode } from 'react';

type ToastType = 'success' | 'error' | 'info' | 'warning';

interface ToastOptions {
  type?: ToastType;
  title?: string;
  content: ReactNode;
  duration?: number;
}

export function showOperationToast({
  type = 'success',
  title,
  content,
  duration = 1600,
}: ToastOptions): void {
  const config = {
    title: title ?? defaultTitle(type),
    content,
    centered: true,
    closable: false,
    mask: false,
    footer: null,
    width: 360,
    icon: iconFor(type),
    className: 'operation-toast-modal',
  };
  const toast =
    type === 'error'
      ? Modal.error(config)
      : type === 'warning'
        ? Modal.warning(config)
        : type === 'info'
          ? Modal.info(config)
          : Modal.success(config);

  window.setTimeout(() => toast.destroy(), duration);
}

export function showSuccessToast(content: ReactNode): void {
  showOperationToast({ type: 'success', content });
}

function defaultTitle(type: ToastType): string {
  if (type === 'error') {
    return '操作失败';
  }
  if (type === 'warning') {
    return '请注意';
  }
  if (type === 'info') {
    return '提示';
  }
  return '操作成功';
}

function iconFor(type: ToastType): ReactNode {
  if (type === 'error') {
    return <CloseCircleOutlined />;
  }
  if (type === 'warning') {
    return <WarningOutlined />;
  }
  if (type === 'info') {
    return <InfoCircleOutlined />;
  }
  return <CheckCircleOutlined />;
}
