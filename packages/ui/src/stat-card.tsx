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
      ? "border-l-red-600 bg-gradient-to-br from-white via-white to-red-50/20"
      : tone === "success"
        ? "border-l-emerald-600 bg-gradient-to-br from-white via-white to-emerald-50/20"
        : tone === "warning"
          ? "border-l-amber-500 bg-gradient-to-br from-white via-white to-amber-50/20"
          : "border-l-[#581c87] bg-gradient-to-br from-white via-white to-purple-50/25";

  const trendTone =
    tone === "danger"
      ? "bg-red-50 text-red-800 border-red-200"
      : tone === "success"
        ? "bg-emerald-50 text-emerald-800 border-emerald-200"
        : tone === "warning"
          ? "bg-amber-50 text-amber-900 border-amber-200"
          : "bg-purple-50 text-purple-900 border-purple-200/80";

  const body = (
    <div
      className={cn(
        "relative overflow-hidden rounded-2xl border border-slate-200/90 dark:border-slate-800/90 p-5.5 shadow-xs transition-all duration-200 border-l-4 hover:shadow-md hover:border-purple-200/80 hover:-translate-y-0.5 select-none",
        toneBorder,
        href && "cursor-pointer",
        className,
      )}
    >
      <div className="flex items-center justify-between gap-2">
        <div className="text-[11px] font-extrabold uppercase tracking-wider text-slate-500">{label}</div>
        {trend ? (
          <span className={cn("rounded-full px-2.5 py-0.5 text-[10px] font-extrabold border shadow-2xs", trendTone)}>
            {trend}
          </span>
        ) : null}
      </div>
      <div className="mt-3 text-3xl sm:text-3.5xl font-black tabular-nums tracking-tight text-slate-900 dark:text-slate-100 leading-none">
        {value}
      </div>
      {hint ? <div className="mt-2 text-xs text-slate-500 font-semibold leading-relaxed">{hint}</div> : null}
    </div>
  );

  return href ? <Link href={href} className="block group">{body}</Link> : body;
}
