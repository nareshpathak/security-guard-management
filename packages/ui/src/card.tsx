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
        "rounded-2xl border border-slate-200/90 dark:border-slate-800/90 bg-gradient-to-br from-white via-white to-purple-50/20 dark:from-slate-900 dark:to-slate-900 shadow-xs hover:shadow-md hover:border-purple-200/80 transition-all duration-200 overflow-hidden",
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
    <div className={cn("border-b border-slate-100 dark:border-slate-800/80 px-6 py-4 bg-gradient-to-r from-slate-50/80 via-white to-purple-50/20 dark:from-slate-900/60 dark:to-slate-900/60 rounded-t-2xl", className)}>
      {children}
    </div>
  );
}

export function CardTitle({
  className,
  children,
}: {
  className?: string;
  children?: React.ReactNode;
}) {
  return (
    <h3 className={cn("text-base font-extrabold tracking-tight text-slate-900 dark:text-slate-100 leading-snug", className)}>
      {children}
    </h3>
  );
}

export function CardDescription({
  className,
  children,
}: {
  className?: string;
  children?: React.ReactNode;
}) {
  return (
    <p className={cn("mt-1 text-xs font-semibold text-slate-500 dark:text-slate-400 leading-relaxed", className)}>
      {children}
    </p>
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
    <div className={cn("border-t border-slate-100 dark:border-slate-800/80 px-6 py-3.5 bg-slate-50/50 dark:bg-slate-900/50 rounded-b-2xl", className)}>
      {children}
    </div>
  );
}
