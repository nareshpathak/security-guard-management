"use client";

import { cn } from "./cn";

export type Column<T> = {
  id: string;
  header: string;
  cell: (row: T) => React.ReactNode;
  className?: string;
  hideOnMobile?: boolean;
};

export function DataTable<T>({
  columns,
  rows,
  rowKey,
  onRowClick,
  empty,
}: {
  columns: Column<T>[];
  rows: T[];
  rowKey: (row: T, index: number) => string | number;
  onRowClick?: (row: T) => void;
  empty?: React.ReactNode;
}) {
  if (rows.length === 0) return <>{empty}</>;

  return (
    <div className="overflow-hidden rounded-[var(--diti-radius-lg)] border border-[var(--diti-border)] bg-[var(--diti-surface)] shadow-xs transition-all">
      <div className="overflow-x-auto max-h-[calc(100vh-220px)]">
        <table className="min-w-full text-left text-xs font-normal border-collapse">
          <thead className="sticky top-0 z-10 border-b-2 border-[var(--diti-border-strong)] bg-slate-100/90 dark:bg-zinc-800/90 backdrop-blur-md shadow-xs">
            <tr>
              {columns.map((col) => (
                <th
                  key={col.id}
                  className={cn(
                    "px-4 py-3 text-[11px] font-bold uppercase tracking-wider text-[var(--diti-text)] select-none",
                    col.hideOnMobile && "hidden md:table-cell",
                    col.className,
                  )}
                >
                  {col.header}
                </th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y divide-[var(--diti-border)]">
            {rows.map((row, index) => (
              <tr
                key={rowKey(row, index)}
                onClick={onRowClick ? () => onRowClick(row) : undefined}
                className={cn(
                  "transition-colors duration-150 odd:bg-[var(--diti-surface)] even:bg-[var(--diti-surface-stripe)]",
                  onRowClick
                    ? "cursor-pointer hover:bg-[var(--diti-primary-subtle)]/80 active:bg-[var(--diti-primary-subtle)]"
                    : "hover:bg-[var(--diti-primary-subtle)]/40",
                )}
              >
                {columns.map((col) => (
                  <td
                    key={col.id}
                    className={cn(
                      "px-4 py-3.5 align-middle text-[var(--diti-text)] leading-snug font-normal",
                      col.hideOnMobile && "hidden md:table-cell",
                      col.className,
                    )}
                  >
                    {col.cell(row)}
                  </td>
                ))}
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

export function Pagination({
  page,
  pageSize,
  total,
  onPageChange,
  onPageSizeChange,
}: {
  page: number;
  pageSize: number;
  total: number;
  onPageChange: (page: number) => void;
  onPageSizeChange?: (size: number) => void;
}) {
  const totalPages = Math.max(1, Math.ceil(total / pageSize));
  const startItem = total === 0 ? 0 : (page - 1) * pageSize + 1;
  const endItem = Math.min(total, page * pageSize);

  return (
    <div className="mt-4 flex flex-col sm:flex-row items-center justify-between gap-3 text-xs text-[var(--diti-muted)] px-1">
      <div className="flex items-center gap-3">
        <span>
          Showing <strong className="font-bold text-[var(--diti-text)]">{startItem}-{endItem}</strong> of <strong className="font-bold text-[var(--diti-text)]">{total}</strong> records
        </span>
        {onPageSizeChange ? (
          <div className="flex items-center gap-1.5 ml-2">
            <span className="text-[11px] font-medium">Rows:</span>
            <select
              value={pageSize}
              onChange={(e) => onPageSizeChange(Number(e.target.value))}
              className="h-7 rounded-md border border-[var(--diti-border)] bg-[var(--diti-surface)] px-2 text-xs font-semibold text-[var(--diti-text)] shadow-xs outline-none focus:border-[var(--diti-primary)]"
            >
              {[10, 25, 50, 100].map((size) => (
                <option key={size} value={size}>
                  {size}
                </option>
              ))}
            </select>
          </div>
        ) : null}
      </div>
      <div className="flex items-center gap-1.5">
        <button
          type="button"
          disabled={page <= 1}
          onClick={() => onPageChange(page - 1)}
          className="inline-flex h-8 items-center justify-center rounded-[var(--diti-radius-md)] border border-[var(--diti-border)] bg-[var(--diti-surface)] px-3 text-xs font-semibold text-[var(--diti-text)] shadow-xs transition hover:bg-[var(--diti-surface-sunken)] disabled:opacity-40 disabled:pointer-events-none active:scale-[0.97]"
        >
          Previous
        </button>
        <div className="flex items-center px-2 text-xs font-bold text-[var(--diti-text)]">
          Page {page} of {totalPages}
        </div>
        <button
          type="button"
          disabled={page >= totalPages}
          onClick={() => onPageChange(page + 1)}
          className="inline-flex h-8 items-center justify-center rounded-[var(--diti-radius-md)] border border-[var(--diti-border)] bg-[var(--diti-surface)] px-3 text-xs font-semibold text-[var(--diti-text)] shadow-xs transition hover:bg-[var(--diti-surface-sunken)] disabled:opacity-40 disabled:pointer-events-none active:scale-[0.97]"
        >
          Next
        </button>
      </div>
    </div>
  );
}
