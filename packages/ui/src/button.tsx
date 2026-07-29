"use client";

import type { ButtonHTMLAttributes, ReactNode } from "react";
import { cn } from "./cn";

type Variant = "primary" | "secondary" | "ghost" | "danger" | "outline";
type Size = "sm" | "md" | "lg";

const variants: Record<Variant, string> = {
  primary: "bg-[var(--diti-primary)] text-white hover:bg-[var(--diti-primary-hover)]",
  secondary: "bg-[var(--diti-primary-subtle)] text-[var(--diti-primary)] hover:opacity-90",
  ghost: "bg-transparent text-[var(--diti-text)] hover:bg-zinc-100 dark:hover:bg-zinc-800",
  danger: "bg-[var(--diti-danger)] text-white hover:opacity-90",
  outline:
    "border border-[var(--diti-border)] bg-[var(--diti-surface)] text-[var(--diti-text)] hover:bg-zinc-50 dark:hover:bg-zinc-800",
};

const sizes: Record<Size, string> = {
  sm: "h-8 px-3 text-xs",
  md: "h-9 px-4 text-sm",
  lg: "h-11 px-5 text-sm",
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
        "inline-flex items-center justify-center gap-2 rounded-[var(--diti-radius-md)] font-medium transition focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--diti-primary)] disabled:pointer-events-none disabled:opacity-50",
        variants[variant],
        sizes[size],
        className,
      )}
      disabled={disabled || loading}
      {...props}
    >
      {loading ? "Please wait…" : children}
    </button>
  );
}
