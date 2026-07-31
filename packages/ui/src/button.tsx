"use client";

import type { ButtonHTMLAttributes, ReactNode } from "react";
import { cn } from "./cn";

type Variant = "primary" | "secondary" | "ghost" | "danger" | "outline" | "subtle";
type Size = "sm" | "md" | "lg";

const variants: Record<Variant, string> = {
  primary: "bg-gradient-to-r from-[#4c1d95] via-[#581c87] to-[#6366f1] text-white hover:from-[#3b0764] hover:to-[#4f46e5] shadow-sm shadow-purple-900/20 active:scale-[0.98] font-semibold border border-purple-500/20",
  secondary: "bg-purple-50 text-purple-900 hover:bg-purple-100 dark:bg-purple-950/80 dark:text-purple-200 active:scale-[0.98] font-semibold border border-purple-200/60 dark:border-purple-800/60",
  subtle: "bg-slate-100 text-slate-800 hover:bg-slate-200 dark:bg-slate-800 dark:text-slate-200 active:scale-[0.98] font-medium border border-slate-200/60 dark:border-slate-700/60",
  ghost: "bg-transparent text-[var(--diti-text)] hover:bg-purple-50/70 hover:text-purple-900 dark:hover:bg-slate-800 active:scale-[0.98]",
  danger: "bg-red-600 text-white hover:bg-red-700 shadow-sm shadow-red-600/25 active:scale-[0.98] font-semibold border border-red-500/20",
  outline:
    "border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 text-slate-800 dark:text-slate-200 hover:bg-purple-50/60 hover:text-purple-900 dark:hover:bg-slate-800 shadow-2xs active:scale-[0.98] font-medium",
};

const sizes: Record<Size, string> = {
  sm: "h-8 px-3 text-xs gap-1.5 rounded-md",
  md: "h-9.5 px-4 text-xs font-semibold gap-2 rounded-lg",
  lg: "h-11 px-5 text-sm font-semibold gap-2.5 rounded-xl",
};

export function Button({
  className,
  variant = "primary",
  size = "md",
  loading,
  children,
  disabled,
  ...props
}: ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: Variant;
  size?: Size;
  loading?: boolean;
  children?: ReactNode;
}) {
  return (
    <button
      className={cn(
        "inline-flex items-center justify-center transition-all duration-150 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-purple-500/30 focus-visible:border-purple-600 disabled:pointer-events-none disabled:opacity-50 select-none",
        variants[variant],
        sizes[size],
        className,
      )}
      disabled={disabled || loading}
      {...props}
    >
      {loading ? (
        <>
          <svg className="size-4 animate-spin shrink-0 text-current" viewBox="0 0 24 24" fill="none">
            <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" />
            <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4z" />
          </svg>
          <span>Loading…</span>
        </>
      ) : (
        children
      )}
    </button>
  );
}
