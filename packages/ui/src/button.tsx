"use client";

import type { ButtonHTMLAttributes, ReactNode } from "react";
import { cn } from "./cn";

type Variant = "primary" | "secondary" | "ghost" | "danger" | "outline" | "subtle";
type Size = "sm" | "md" | "lg";

const variants: Record<Variant, string> = {
  primary: "bg-[var(--diti-primary)] text-white hover:bg-[var(--diti-primary-hover)] shadow-xs active:scale-[0.98]",
  secondary: "bg-[var(--diti-primary-subtle)] text-[var(--diti-primary)] hover:opacity-90 active:scale-[0.98]",
  subtle: "bg-[var(--diti-surface-sunken)] text-[var(--diti-text)] hover:bg-[var(--diti-border)] active:scale-[0.98]",
  ghost: "bg-transparent text-[var(--diti-text)] hover:bg-zinc-100 dark:hover:bg-zinc-800 active:scale-[0.98]",
  danger: "bg-[var(--diti-danger)] text-white hover:opacity-90 shadow-xs active:scale-[0.98]",
  outline:
    "border border-[var(--diti-border)] bg-[var(--diti-surface)] text-[var(--diti-text)] hover:bg-zinc-50 dark:hover:bg-zinc-800 shadow-xs active:scale-[0.98]",
};

const sizes: Record<Size, string> = {
  sm: "h-8 px-3 text-xs gap-1.5 font-medium",
  md: "h-9.5 px-4 text-xs font-semibold gap-2",
  lg: "h-11 px-5 text-sm font-semibold gap-2.5",
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
        "inline-flex items-center justify-center rounded-[var(--diti-radius-md)] transition-all duration-150 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--diti-primary)] disabled:pointer-events-none disabled:opacity-50",
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
