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
    <div className="overflow-hidden rounded-[var(--diti-radius-lg)] border border-slate-200 dark:border-slate-800 bg-white dark:bg-slate-900 shadow-2xs transition-all">
      <div className="overflow-x-auto max-h-[calc(100vh-220px)]">
        <table className="min-w-full text-left text-xs font-normal border-collapse">
          <thead className="sticky top-0 z-10 border-b-2 border-slate-200 dark:border-slate-700 bg-slate-100/95 dark:bg-slate-800/95 backdrop-blur-md shadow-2xs">
            <tr>
              {columns.map((col) => (
                <th
                  key={col.id}
                  className={cn(
                    "px-4 py-3 text-[11px] font-bold uppercase tracking-wider text-slate-700 dark:text-slate-200 select-none",
                    col.hideOnMobile && "hidden md:table-cell",
                    col.className,
                  )}
                >
                  {col.header}
                </th>
              ))}
            </tr>
          </thead>
          <tbody className="divide-y divide-slate-200/80 dark:divide-slate-800/80">
            {rows.map((row, index) => (
              <tr
                key={rowKey(row, index)}
                onClick={onRowClick ? () => onRowClick(row) : undefined}
                className={cn(
                  "transition-colors duration-150 odd:bg-white even:bg-slate-50/60 dark:odd:bg-slate-900 dark:even:bg-slate-900/60",
                  onRowClick
                    ? "cursor-pointer hover:bg-indigo-50/70 dark:hover:bg-indigo-950/50 active:bg-indigo-100/60"
                    : "hover:bg-indigo-50/40 dark:hover:bg-indigo-950/30",
                )}
              >
                {columns.map((col) => (
                  <td
                    key={col.id}
                    className={cn(
                      "px-4 py-3.5 align-middle text-slate-900 dark:text-slate-100 leading-snug font-medium",
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
            <span className="text-[11px] font-semibold text-slate-600">Rows per page:</span>
            <select
              value={pageSize}
              onChange={(e) => onPageSizeChange(Number(e.target.value))}
              className="h-7 rounded-md border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-900 px-2 text-xs font-bold text-[var(--diti-text)] shadow-2xs outline-none focus:border-indigo-600 focus:ring-2 focus:ring-indigo-500/20"
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
          className="inline-flex h-8 items-center justify-center rounded-[var(--diti-radius-md)] border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-900 px-3 text-xs font-bold text-[var(--diti-text)] shadow-2xs transition hover:bg-slate-100 dark:hover:bg-slate-800 disabled:opacity-40 disabled:pointer-events-none active:scale-[0.97]"
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
          className="inline-flex h-8 items-center justify-center rounded-[var(--diti-radius-md)] border border-slate-300 dark:border-slate-700 bg-white dark:bg-slate-900 px-3 text-xs font-bold text-[var(--diti-text)] shadow-2xs transition hover:bg-slate-100 dark:hover:bg-slate-800 disabled:opacity-40 disabled:pointer-events-none active:scale-[0.97]"
        >
          Next
        </button>
      </div>
    </div>
  );
}
