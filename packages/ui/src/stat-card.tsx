"use client";

import Link from "next/link";
import { cn } from "./cn";

export function StatCard({
  label,
  value,
  hint,
  href,
  tone = "default",
  trend,
  className,
}: {
  label: string;
  value: string | number;
  hint?: string;
  href?: string;
  tone?: "default" | "danger" | "success" | "warning";
  trend?: string;
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
        "relative overflow-hidden rounded-[var(--diti-radius-lg)] border border-[var(--diti-border)] bg-[var(--diti-surface)] p-5 shadow-xs transition-all duration-200 border-l-4 hover:shadow-md hover:border-r-[var(--diti-border-strong)]",
        toneBorder,
        href && "cursor-pointer hover:-translate-y-0.5",
        className,
      )}
    >
      <div className="flex items-center justify-between gap-2">
        <div className="text-[11px] font-bold uppercase tracking-wider text-[var(--diti-muted)]">{label}</div>
        {trend ? (
          <span className="rounded-full bg-[var(--diti-primary-subtle)] px-2 py-0.5 text-[10px] font-bold text-[var(--diti-primary)]">
            {trend}
          </span>
        ) : null}
      </div>
      <div className="mt-2 text-3xl font-extrabold tabular-nums tracking-tight text-[var(--diti-text)]">{value}</div>
      {hint ? <div className="mt-1.5 text-xs text-[var(--diti-muted)] font-medium leading-snug">{hint}</div> : null}
    </div>
  );

  return href ? <Link href={href} className="block group">{body}</Link> : body;
}
