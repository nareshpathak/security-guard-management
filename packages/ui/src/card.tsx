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
        "rounded-[var(--diti-radius-lg)] border border-[var(--diti-border)] bg-[var(--diti-surface)] p-5 shadow-sm",
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
    <div className={cn("border-b border-[var(--diti-border)] px-5 py-4", className)}>
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
    <div className={cn("px-5 py-4", className)}>
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
    <div className={cn("border-t border-[var(--diti-border)] px-5 py-3", className)}>
      {children}
    </div>
  );
}
