"use client";

import Link from "next/link";
import { cn } from "./cn";

export function StatCard({
  label,
  value,
  hint,
  href,
  tone = "default",
  className,
}: {
  label: string;
  value: string | number;
  hint?: string;
  href?: string;
  tone?: "default" | "danger" | "success" | "warning";
  className?: string;
}) {
  const toneBorder =
    tone === "danger"
      ? "border-l-[var(--diti-danger)]"
      : tone === "success"
        ? "border-l-[var(--diti-success)]"
        : tone === "warning"
          ? "border-l-[var(--diti-warning)]"
          : "border-l-[var(--diti-primary)]";

  const body = (
    <div
      className={cn(
        "rounded-[var(--diti-radius-lg)] border border-[var(--diti-border)] bg-[var(--diti-surface)] p-4 shadow-[var(--diti-shadow)] border-l-4",
        toneBorder,
        href && "transition hover:border-[var(--diti-primary)]",
        className,
      )}
    >
      <div className="text-xs font-medium uppercase tracking-wide text-[var(--diti-muted)]">{label}</div>
      <div className="mt-2 text-2xl font-semibold tabular-nums text-[var(--diti-text)]">{value}</div>
      {hint ? <div className="mt-1 text-xs text-[var(--diti-muted)]">{hint}</div> : null}
    </div>
  );

  return href ? <Link href={href}>{body}</Link> : body;
}
