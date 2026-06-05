import React from 'react';
import ReactDOM from 'react-dom/client';
import { ConfigProvider } from 'antd';
import zhCN from 'antd/locale/zh_CN';

import App from './App';
import './styles.css';

ReactDOM.createRoot(document.getElementById('root') as HTMLElement).render(
  <React.StrictMode>
    <ConfigProvider
      locale={zhCN}
      theme={{
        token: {
          colorPrimary: '#0EA5E9',
          colorInfo: '#0284C7',
          colorSuccess: '#10B981',
          colorError: '#EF4444',
          colorWarning: '#F59E0B',
          colorTextBase: '#0F172A',
          colorBgLayout: '#F7FAFC',
          colorBgContainer: '#FFFFFF',
          colorBorder: '#D8E2EE',
          colorBorderSecondary: '#E7EEF6',
          borderRadius: 8,
          borderRadiusLG: 8,
          borderRadiusSM: 6,
          controlHeight: 38,
          fontSize: 14,
          fontFamily:
            '-apple-system, BlinkMacSystemFont, "Segoe UI", "Microsoft YaHei", "PingFang SC", sans-serif',
          boxShadow:
            '0 1px 2px rgba(15, 23, 42, 0.04), 0 10px 24px -22px rgba(15, 23, 42, 0.28)',
          boxShadowSecondary:
            '0 22px 48px -32px rgba(15, 23, 42, 0.34), 0 8px 18px -16px rgba(15, 23, 42, 0.18)',
        },
        components: {
          Layout: {
            headerBg: '#FFFFFF',
            siderBg: '#FFFFFF',
            bodyBg: '#F7FAFC',
            headerHeight: 64,
            headerPadding: '0 24px',
          },
          Menu: {
            itemBg: 'transparent',
            itemSelectedBg: 'rgba(14, 165, 233, 0.11)',
            itemSelectedColor: '#0369A1',
            itemHoverBg: 'rgba(14, 165, 233, 0.07)',
            itemBorderRadius: 8,
            itemHeight: 38,
            iconSize: 16,
          },
          Card: {
            borderRadiusLG: 8,
            paddingLG: 18,
          },
          Button: {
            borderRadius: 8,
            controlHeight: 38,
          },
          Table: {
            headerBg: '#F8FAFC',
            headerColor: '#475569',
            rowHoverBg: '#F8FAFC',
            borderColor: '#E7EEF6',
            cellPaddingBlock: 11,
            cellPaddingInline: 14,
          },
          Input: {
            borderRadius: 8,
          },
          Tag: {
            borderRadiusSM: 999,
          },
          Modal: {
            borderRadiusLG: 8,
          },
          Drawer: {
            borderRadiusLG: 8,
          },
        },
      }}
    >
      <App />
    </ConfigProvider>
  </React.StrictMode>,
);
