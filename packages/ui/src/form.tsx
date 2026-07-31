"use client";

import type { InputHTMLAttributes } from "react";
import { cn } from "./cn";

export function Input({ className, ...props }: InputHTMLAttributes<HTMLInputElement>) {
  return (
    <input
      className={cn(
        "h-9.5 w-full rounded-[var(--diti-radius-md)] border border-slate-300 dark:border-slate-700 bg-[var(--diti-surface)] px-3 text-xs font-medium text-[var(--diti-text)] placeholder:text-[var(--diti-muted)]/70 shadow-2xs transition-all duration-150 focus:border-purple-600 focus:outline-none focus:ring-3 focus:ring-purple-500/20 disabled:opacity-50 disabled:bg-slate-100 dark:disabled:bg-slate-800",
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
      className={cn("mb-1.5 block text-xs font-bold text-slate-800 dark:text-slate-200 leading-none select-none", className)}
    >
      {children}
      {required ? <span className="ml-1 text-red-600 font-extrabold">*</span> : null}
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
        "min-h-24 w-full rounded-[var(--diti-radius-md)] border border-slate-300 dark:border-slate-700 bg-[var(--diti-surface)] p-3 text-xs font-medium text-[var(--diti-text)] placeholder:text-[var(--diti-muted)]/70 shadow-2xs transition-all duration-150 focus:border-purple-600 focus:outline-none focus:ring-3 focus:ring-purple-500/20",
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
        "h-9.5 w-full rounded-[var(--diti-radius-md)] border border-slate-300 dark:border-slate-700 bg-[var(--diti-surface)] px-3 pr-8 text-xs font-medium text-[var(--diti-text)] shadow-2xs transition-all duration-150 focus:border-indigo-600 focus:outline-none focus:ring-3 focus:ring-indigo-500/20 cursor-pointer",
        className,
      )}
      {...props}
    >
      {children}
    </select>
  );
}
