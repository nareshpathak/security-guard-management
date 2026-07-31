"use client";

import { cn } from "./cn";

export function PageHeader({
  title,
  description,
  actions,
  breadcrumbs,
  className,
}: {
  title: string;
  description?: string;
  actions?: React.ReactNode;
  breadcrumbs?: { label: string; href?: string }[];
  className?: string;
}) {
  return (
    <div className={cn("mb-6 flex flex-col gap-3.5 sm:flex-row sm:items-start sm:justify-between border-b border-slate-200/80 dark:border-slate-800/80 pb-5", className)}>
      <div>
        {breadcrumbs && breadcrumbs.length > 0 ? (
          <nav className="mb-2 flex items-center gap-1.5 text-xs text-slate-500 font-medium select-none">
            {breadcrumbs.map((b, i) => (
              <span key={i} className="flex items-center gap-1.5">
                {i > 0 ? <span className="text-slate-300 dark:text-slate-700">/</span> : null}
                {b.href ? (
                  <a href={b.href} className="hover:text-indigo-600 dark:hover:text-indigo-400 transition-colors">
                    {b.label}
                  </a>
                ) : (
                  <span className="text-slate-900 dark:text-slate-100 font-semibold">{b.label}</span>
                )}
              </span>
            ))}
          </nav>
        ) : null}
        <h1 className="text-2xl sm:text-3xl font-extrabold tracking-tight text-slate-900 dark:text-slate-100">{title}</h1>
        {description ? (
          <p className="mt-1 max-w-3xl text-xs sm:text-sm font-medium text-slate-500 dark:text-slate-400 leading-relaxed">{description}</p>
        ) : null}
      </div>
      {actions ? <div className="flex flex-wrap items-center gap-2.5 shrink-0">{actions}</div> : null}
    </div>
  );
}

export function EmptyState({
  title,
  description,
  action,
}: {
  title: string;
  description?: string;
  action?: React.ReactNode;
}) {
  return (
    <div className="flex flex-col items-center justify-center rounded-2xl border border-dashed border-slate-300 dark:border-slate-800 bg-white dark:bg-slate-900 px-6 py-12 text-center shadow-2xs">
      <div className="flex size-12 items-center justify-center rounded-full bg-slate-100 dark:bg-slate-800 text-slate-500 mb-3 shadow-2xs">
        <svg className="size-6 text-slate-400 opacity-80" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
          <rect width="18" height="18" x="3" y="3" rx="2" ry="2"/>
          <path d="M3 9h18"/>
          <path d="M9 21V9"/>
        </svg>
      </div>
      <h3 className="text-sm font-bold text-slate-900 dark:text-slate-100">{title}</h3>
      {description ? <p className="mt-1.5 max-w-sm text-xs font-medium text-slate-500 dark:text-slate-400 leading-relaxed">{description}</p> : null}
      {action ? <div className="mt-4">{action}</div> : null}
    </div>
  );
}

export function ErrorState({
  title = "Something went wrong",
  message,
  onRetry,
}: {
  title?: string;
  message?: string;
  onRetry?: () => void;
}) {
  return (
    <div className="rounded-xl border border-red-200 bg-red-50/90 p-5 dark:border-red-900/60 dark:bg-red-950/40 shadow-2xs">
      <div className="flex items-start gap-3">
        <div className="rounded-full bg-red-100 p-1 text-red-600 dark:bg-red-900/60 dark:text-red-400 shrink-0">
          <svg className="size-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <path d="M12 9v37M12 17h.01" />
          </svg>
        </div>
        <div className="flex-1">
          <h3 className="text-xs font-extrabold text-red-800 dark:text-red-300">{title}</h3>
          {message ? <p className="mt-1 text-xs font-medium text-red-700 dark:text-red-400 leading-relaxed">{message}</p> : null}
          {onRetry ? (
            <button
              type="button"
              onClick={onRetry}
              className="mt-2.5 text-xs font-bold text-red-700 underline underline-offset-2 hover:text-red-900 dark:text-red-300"
            >
              Try again
            </button>
          ) : null}
        </div>
      </div>
    </div>
  );
}

export function Skeleton({ className }: { className?: string }) {
  return (
    <div className={cn("animate-pulse rounded-lg bg-slate-200/80 dark:bg-slate-800/80", className)} />
  );
}
