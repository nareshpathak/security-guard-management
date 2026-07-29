/**
 * Display formatting. All of it is Indian-locale by default because that is
 * where every tenant operates: rupees, lakhs/crores grouping, dd MMM yyyy.
 */

const inr = new Intl.NumberFormat("en-IN", {
  style: "currency",
  currency: "INR",
  maximumFractionDigits: 0,
});

const inrExact = new Intl.NumberFormat("en-IN", {
  style: "currency",
  currency: "INR",
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

const num = new Intl.NumberFormat("en-IN");

function toNumber(value: unknown): number | null {
  if (value === null || value === undefined || value === "") return null;
  const n = typeof value === "number" ? value : Number(value);
  return Number.isFinite(n) ? n : null;
}

/** Rounded rupees for dashboards and list columns. */
export function money(value: unknown): string {
  const n = toNumber(value);
  return n === null ? "—" : inr.format(n);
}

/**
 * Rupees and paise. Use this anywhere the number is a statement of what someone
 * is owed or has been paid - a salary slip, an invoice, a receipt. Rounding
 * there is not a display choice, it is a wrong number.
 */
export function moneyExact(value: unknown): string {
  const n = toNumber(value);
  return n === null ? "—" : inrExact.format(n);
}

export function count(value: unknown): string {
  const n = toNumber(value);
  return n === null ? "—" : num.format(n);
}

export function percent(value: unknown, digits = 0): string {
  const n = toNumber(value);
  return n === null ? "—" : `${n.toFixed(digits)}%`;
}

function toDate(value: unknown): Date | null {
  if (!value) return null;
  const d = value instanceof Date ? value : new Date(String(value));
  return Number.isNaN(d.getTime()) ? null : d;
}

/** 04 Jul 2026 */
export function date(value: unknown): string {
  const d = toDate(value);
  return d
    ? d.toLocaleDateString("en-IN", { day: "2-digit", month: "short", year: "numeric" })
    : "—";
}

/** 04 Jul 2026, 09:15 */
export function dateTime(value: unknown): string {
  const d = toDate(value);
  return d
    ? d.toLocaleString("en-IN", {
        day: "2-digit",
        month: "short",
        year: "numeric",
        hour: "2-digit",
        minute: "2-digit",
        hour12: false,
      })
    : "—";
}

/** 09:15 - for punch times, where the date is already the row's context. */
export function time(value: unknown): string {
  const d = toDate(value);
  return d
    ? d.toLocaleTimeString("en-IN", { hour: "2-digit", minute: "2-digit", hour12: false })
    : "—";
}

/**
 * "3 min ago", "2 h ago". Used on the live boards, where the age of a reading
 * matters more than its timestamp.
 */
export function ago(value: unknown): string {
  const d = toDate(value);
  if (!d) return "—";
  const seconds = Math.round((Date.now() - d.getTime()) / 1000);
  if (seconds < 60) return "just now";
  const minutes = Math.round(seconds / 60);
  if (minutes < 60) return `${minutes} min ago`;
  const hours = Math.round(minutes / 60);
  if (hours < 24) return `${hours} h ago`;
  return `${Math.round(hours / 24)} d ago`;
}

/** The current month as the API wants it: yyyy-MM. */
export function currentMonth(offset = 0): string {
  const d = new Date();
  d.setMonth(d.getMonth() + offset);
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}`;
}

export function isoDate(d: Date): string {
  return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`;
}
