"use client";

import { cn } from "./cn";

const tones: Record<string, { bg: string; dot: string }> = {
  success: {
    bg: "bg-emerald-50 text-emerald-700 ring-emerald-600/20 dark:bg-emerald-950/80 dark:text-emerald-300",
    dot: "bg-emerald-500",
  },
  warning: {
    bg: "bg-amber-50 text-amber-800 ring-amber-600/20 dark:bg-amber-950/80 dark:text-amber-300",
    dot: "bg-amber-500",
  },
  danger: {
    bg: "bg-red-50 text-red-700 ring-red-600/20 dark:bg-red-950/80 dark:text-red-300",
    dot: "bg-red-500",
  },
  info: {
    bg: "bg-sky-50 text-sky-700 ring-sky-600/20 dark:bg-sky-950/80 dark:text-sky-300",
    dot: "bg-sky-500",
  },
  neutral: {
    bg: "bg-zinc-100 text-zinc-700 ring-zinc-500/20 dark:bg-zinc-800/80 dark:text-zinc-300",
    dot: "bg-zinc-400",
  },
  primary: {
    bg: "bg-[var(--diti-primary-subtle)] text-[var(--diti-primary)] ring-[var(--diti-primary)]/20",
    dot: "bg-[var(--diti-primary)]",
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
        "inline-flex items-center gap-1.5 rounded-full px-2.5 py-0.5 text-[11px] font-semibold tracking-tight ring-1 ring-inset shadow-2xs",
        current.bg,
        className,
      )}
    >
      <span className={cn("size-1.5 rounded-full shrink-0", current.dot)} />
      {children}
    </span>
  );
}
