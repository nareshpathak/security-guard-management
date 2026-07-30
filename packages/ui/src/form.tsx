"use client";

import type { InputHTMLAttributes } from "react";
import { cn } from "./cn";

export function Input({ className, ...props }: InputHTMLAttributes<HTMLInputElement>) {
  return (
    <input
      className={cn(
        "h-9.5 w-full rounded-[var(--diti-radius-md)] border border-[var(--diti-border)] bg-[var(--diti-surface)] px-3 text-xs font-normal text-[var(--diti-text)] placeholder:text-[var(--diti-muted)]/70 shadow-xs transition-all duration-150 focus:border-[var(--diti-primary)] focus:outline-none focus:ring-3 focus:ring-[var(--diti-primary)]/15 disabled:opacity-50 disabled:bg-[var(--diti-surface-sunken)]",
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
      className={cn("mb-1.5 block text-xs font-semibold text-[var(--diti-text)] leading-none", className)}
    >
      {children}
      {required ? <span className="ml-1 text-[var(--diti-danger)] font-bold">*</span> : null}
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
        "min-h-24 w-full rounded-[var(--diti-radius-md)] border border-[var(--diti-border)] bg-[var(--diti-surface)] p-3 text-xs font-normal text-[var(--diti-text)] placeholder:text-[var(--diti-muted)]/70 shadow-xs transition-all duration-150 focus:border-[var(--diti-primary)] focus:outline-none focus:ring-3 focus:ring-[var(--diti-primary)]/15",
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
        "h-9.5 w-full rounded-[var(--diti-radius-md)] border border-[var(--diti-border)] bg-[var(--diti-surface)] px-3 pr-8 text-xs font-normal text-[var(--diti-text)] shadow-xs transition-all duration-150 focus:border-[var(--diti-primary)] focus:outline-none focus:ring-3 focus:ring-[var(--diti-primary)]/15 cursor-pointer",
        className,
      )}
      {...props}
    >
      {children}
    </select>
  );
}
