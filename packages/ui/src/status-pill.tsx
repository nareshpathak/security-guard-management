"use client";

import { cn } from "./cn";

const tones: Record<string, { bg: string; dot: string }> = {
  success: {
    bg: "bg-emerald-50 text-emerald-700 ring-emerald-600/30 dark:bg-emerald-950/80 dark:text-emerald-300 dark:ring-emerald-500/30",
    dot: "bg-emerald-500",
  },
  warning: {
    bg: "bg-amber-50 text-amber-800 ring-amber-600/30 dark:bg-amber-950/80 dark:text-amber-300 dark:ring-amber-500/30",
    dot: "bg-amber-500",
  },
  danger: {
    bg: "bg-red-50 text-red-700 ring-red-600/30 dark:bg-red-950/80 dark:text-red-300 dark:ring-red-500/30",
    dot: "bg-red-500",
  },
  info: {
    bg: "bg-sky-50 text-sky-700 ring-sky-600/30 dark:bg-sky-950/80 dark:text-sky-300 dark:ring-sky-500/30",
    dot: "bg-sky-500",
  },
  neutral: {
    bg: "bg-slate-100 text-slate-700 ring-slate-400/30 dark:bg-slate-800/80 dark:text-slate-300 dark:ring-slate-600/30",
    dot: "bg-slate-400",
  },
  primary: {
    bg: "bg-indigo-50 text-indigo-700 ring-indigo-600/30 dark:bg-indigo-950/80 dark:text-indigo-300 dark:ring-indigo-500/30",
    dot: "bg-indigo-600",
  },
};

export function StatusPill({
  children,
  tone = "neutral",
  className,
}: {
  children: React.ReactNode;
  tone?: keyof typeof tones;
  className?: string;
}) {
  const current = tones[tone] ?? tones.neutral;

  return (
    <span
      className={cn(
        "inline-flex items-center gap-1.5 rounded-full px-2.5 py-0.5 text-[11px] font-bold tracking-tight ring-1 ring-inset shadow-2xs select-none",
        current.bg,
        className,
      )}
    >
      <span className={cn("size-1.5 rounded-full shrink-0", current.dot)} />
      {children}
    </span>
  );
}
