"use client";

import { cn } from "./cn";

export function PageHeader({
  title,
  description,
  actions,
  className,
}: {
  title: string;
  description?: string;
  actions?: React.ReactNode;
  className?: string;
}) {
  return (
    <div className={cn("mb-6 flex flex-col gap-3 sm:flex-row sm:items-start sm:justify-between", className)}>
      <div>
        <h1 className="text-2xl font-semibold tracking-tight text-[var(--diti-text)]">{title}</h1>
        {description ? (
          <p className="mt-1 max-w-2xl text-sm text-[var(--diti-muted)]">{description}</p>
        ) : null}
      </div>
      {actions ? <div className="flex flex-wrap items-center gap-2">{actions}</div> : null}
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
    <div className="flex flex-col items-center justify-center rounded-[var(--diti-radius-lg)] border border-dashed border-[var(--diti-border)] bg-[var(--diti-surface)] px-6 py-16 text-center">
      <h3 className="text-base font-semibold text-[var(--diti-text)]">{title}</h3>
      {description ? <p className="mt-2 max-w-md text-sm text-[var(--diti-muted)]">{description}</p> : null}
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
    <div className="rounded-[var(--diti-radius-lg)] border border-red-200 bg-red-50 p-6 dark:border-red-900 dark:bg-red-950/40">
      <h3 className="text-sm font-semibold text-red-700 dark:text-red-300">{title}</h3>
      {message ? <p className="mt-1 text-sm text-red-600 dark:text-red-400">{message}</p> : null}
      {onRetry ? (
        <button
          type="button"
          onClick={onRetry}
          className="mt-3 text-sm font-medium text-red-700 underline dark:text-red-300"
        >
          Try again
        </button>
      ) : null}
    </div>
  );
}

export function Skeleton({ className }: { className?: string }) {
  return (
    <div className={cn("animate-pulse rounded-[var(--diti-radius-md)] bg-zinc-200 dark:bg-zinc-800", className)} />
  );
}
