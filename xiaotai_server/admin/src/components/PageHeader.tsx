import type { ReactNode } from 'react';

interface PageHeaderProps {
  eyebrow?: ReactNode;
  title: ReactNode;
  subtitle?: ReactNode;
  extra?: ReactNode;
}

export default function PageHeader({
  eyebrow,
  title,
  subtitle,
  extra,
}: PageHeaderProps): React.JSX.Element {
  return (
    <header className="page-header">
      <div className="page-header-text">
        {eyebrow && <span className="page-header-eyebrow">{eyebrow}</span>}
        <h1 className="page-header-title">{title}</h1>
        {subtitle && <p className="page-header-subtitle">{subtitle}</p>}
      </div>
      {extra && <div className="page-header-extra">{extra}</div>}
    </header>
  );
}

type StatTone = 'primary' | 'info' | 'success' | 'warning' | 'accent';

interface StatCardProps {
  label: ReactNode;
  value: ReactNode;
  hint?: ReactNode;
  icon: ReactNode;
  tone?: StatTone;
}

export function StatCard({
  label,
  value,
  hint,
  icon,
  tone = 'primary',
}: StatCardProps): React.JSX.Element {
  const toneClass = tone === 'primary' ? '' : ` tone-${tone}`;
  return (
    <div className="stat-card">
      <div className={`stat-card-icon${toneClass}`}>{icon}</div>
      <div className="stat-card-body">
        <div className="stat-card-label">{label}</div>
        <div className="stat-card-value">{value}</div>
        {hint && <div className="stat-card-hint">{hint}</div>}
      </div>
    </div>
  );
}
