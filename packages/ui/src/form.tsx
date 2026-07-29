"use client";

import type { InputHTMLAttributes } from "react";
import { cn } from "./cn";

export function Input({ className, ...props }: InputHTMLAttributes<HTMLInputElement>) {
  return (
    <input
      className={cn(
        "h-9 w-full rounded-[var(--diti-radius-md)] border border-[var(--diti-border)] bg-[var(--diti-surface)] px-3 text-sm text-[var(--diti-text)] placeholder:text-[var(--diti-muted)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--diti-primary)] disabled:opacity-50",
        className,
      )}
      {...props}
    />
  );
}

export function Label({
  className,
  children,
  htmlFor,
  required,
}: {
  className?: string;
  children: React.ReactNode;
  htmlFor?: string;
  required?: boolean;
}) {
  return (
    <label
      htmlFor={htmlFor}
      className={cn("mb-1.5 block text-sm font-medium text-[var(--diti-text)]", className)}
    >
      {children}
      {required ? <span className="ml-0.5 text-[var(--diti-danger)]">*</span> : null}
    </label>
  );
}

export function TextArea({
  className,
  ...props
}: React.TextareaHTMLAttributes<HTMLTextAreaElement>) {
  return (
    <textarea
      className={cn(
        "min-h-24 w-full rounded-[var(--diti-radius-md)] border border-[var(--diti-border)] bg-[var(--diti-surface)] px-3 py-2 text-sm text-[var(--diti-text)] placeholder:text-[var(--diti-muted)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--diti-primary)]",
        className,
      )}
      {...props}
    />
  );
}

export function Select({
  className,
  children,
  ...props
}: React.SelectHTMLAttributes<HTMLSelectElement>) {
  return (
    <select
      className={cn(
        "h-9 w-full rounded-[var(--diti-radius-md)] border border-[var(--diti-border)] bg-[var(--diti-surface)] px-3 text-sm text-[var(--diti-text)] focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-[var(--diti-primary)]",
        className,
      )}
      {...props}
    >
      {children}
    </select>
  );
}
