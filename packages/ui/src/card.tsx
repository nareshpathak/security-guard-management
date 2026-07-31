"use client";

import { cn } from "./cn";

export function Card({
  className,
  children,
  ...props
}: {
  className?: string;
  children?: React.ReactNode;
} & React.HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={cn(
        "rounded-xl border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 shadow-2xs transition-all duration-200",
        className,
      )}
      {...props}
    >
      {children}
    </div>
  );
}

export function CardHeader({
  className,
  children,
}: {
  className?: string;
  children?: React.ReactNode;
}) {
  return (
    <div className={cn("border-b border-slate-100 dark:border-slate-800/80 px-6 py-4 bg-slate-50/40 dark:bg-slate-900/40 rounded-t-xl", className)}>
      {children}
    </div>
  );
}

export function CardContent({
  className,
  children,
}: {
  className?: string;
  children?: React.ReactNode;
}) {
  return (
    <div className={cn("px-6 py-5", className)}>
      {children}
    </div>
  );
}

export function CardFooter({
  className,
  children,
}: {
  className?: string;
  children?: React.ReactNode;
}) {
  return (
    <div className={cn("border-t border-slate-100 dark:border-slate-800/80 px-6 py-3.5 bg-slate-50/50 dark:bg-slate-900/50 rounded-b-xl", className)}>
      {children}
    </div>
  );
}
