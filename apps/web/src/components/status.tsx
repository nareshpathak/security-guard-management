"use client";

import { StatusPill } from "@diti365/ui";

/**
 * One place that decides what colour a status is.
 *
 * Without this each screen picks its own, and "Overdue" ends up amber on the
 * invoice list and red on the client list, which quietly teaches people that
 * the colours mean nothing.
 *
 * Colour is never the only signal - the text is always present too, which is
 * what WCAG 1.4.1 requires and what makes these readable to the roughly 1 in
 * 12 men with a colour vision deficiency.
 */
const TONES: Record<string, "success" | "warning" | "danger" | "info" | "neutral" | "primary"> = {
  // attendance
  "p": "success", "present": "success",
  "a": "danger", "absent": "danger",
  "hd": "warning", "half day": "warning", "halfday": "warning",
  "wo": "neutral", "week off": "neutral", "weekoff": "neutral",
  "hl": "info", "holiday": "info",
  "l": "info", "leave": "info",
  "ds": "success", "double shift": "success",

  // generic lifecycle
  active: "success",
  inactive: "neutral",
  expired: "danger",
  pending: "warning",
  approved: "success",
  rejected: "danger",
  cancelled: "neutral",
  closed: "neutral",
  open: "warning",
  draft: "neutral",
  locked: "info",

  // finance
  paid: "success",
  partpaid: "warning", "part paid": "warning", "partially paid": "warning",
  sent: "info",
  overdue: "danger",
  recovering: "warning",

  // tasks and incidents
  new: "info",
  "in progress": "warning",
  completed: "success",
  done: "success",
  overduetask: "danger",
  critical: "danger",
  high: "danger",
  medium: "warning",
  low: "neutral",
};

export function Status({ value, className }: { value: unknown; className?: string }) {
  const text = value === null || value === undefined || value === "" ? "—" : String(value).trim();
  if (text === "—") return <span className="text-muted">—</span>;

  return (
    <StatusPill tone={TONES[text.toLowerCase()] ?? "neutral"} className={className}>
      {text}
    </StatusPill>
  );
}
