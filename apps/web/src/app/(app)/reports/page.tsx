"use client";

import { useQuery } from "@tanstack/react-query";
import { useSearchParams } from "next/navigation";
import { useMemo } from "react";
import {
  Button,
  DataTable,
  EmptyState,
  ErrorState,
  Input,
  Label,
  PageHeader,
  Pagination,
  Skeleton,
  type Column,
} from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { Status } from "@/components/status";
import { getApi } from "@/lib/api";
import { useListQueryState } from "@/lib/list-query";
import { date, dateTime, isoDate, money } from "@/lib/format";

type ReportKey = { key?: string; Key?: string; name?: string; Name?: string; title?: string };

/**
 * One shell for all 21 reports.
 *
 * Each report is a different stored procedure returning a different shape, so
 * the columns are derived from the first row rather than declared per report.
 * Writing 21 near-identical screens would have been 21 places to forget a
 * loading state.
 */
export default function ReportsPage() {
  const q = useListQueryState();
  // useSearchParams, not window.location: reading location during render makes
  // the server and client markup disagree and React throws a hydration error.
  const active = useSearchParams().get("key") ?? "";

  const thirtyDaysAgo = new Date();
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
  const from = q.from ?? isoDate(thirtyDaysAgo);
  const to = q.to ?? isoDate(new Date());

  const keys = useQuery({
    queryKey: ["report-keys"],
    queryFn: () => getApi().get<ReportKey[]>("/api/v2/reports"),
    // The allow-list is a constant for the life of a deployment.
    staleTime: Infinity,
  });

  const report = useQuery({
    queryKey: ["report", active, q.page, q.pageSize, from, to],
    enabled: active.length > 0,
    queryFn: () =>
      getApi().get<Row[]>(`/api/v2/reports/${active}`, {
        page: q.page,
        pageSize: q.pageSize,
        from,
        to,
      }),
  });

  const rows = report.data?.data ?? [];

  /**
   * Column types are inferred from the column NAME, not the value, because a
   * value can be null on the first row and guessing from it would flip the
   * formatting between pages.
   */
  const columns = useMemo<Column<Row>[]>(() => {
    const rows = report.data?.data ?? [];
    if (rows.length === 0) return [];
    return Object.keys(rows[0])
      .filter((name) => !/^(CompanyID|IsCancel|InsertUserID|UpdateUserID|TotalRows)$/i.test(name))
      .map((name) => {
        const lower = name.toLowerCase();
        const isMoney = /amount|total|salary|wage|rate|value|payable|balance|outstanding/.test(lower);
        const isWhen = /date|on$|at$|time/.test(lower);
        const isStatus = /status|state|stage|priority/.test(lower);
        const isNumber = /count|nos|qty|days|hours|strength|meters|pct|percent/.test(lower);

        return {
          id: name,
          // GuardsOnDuty -> Guards on duty
          header: name.replace(/([a-z])([A-Z])/g, "$1 $2").replace(/^./, (c) => c.toUpperCase()),
          className: isMoney || isNumber ? "text-right" : undefined,
          cell: (r: Row) => {
            const value = r[name];
            if (value === null || value === undefined || value === "")
              return <span className="text-muted">—</span>;
            if (isStatus) return <Status value={value} />;
            if (isMoney) return <span className="tabular">{money(value)}</span>;
            if (isWhen)
              return <span className="tabular">{/time/.test(lower) ? dateTime(value) : date(value)}</span>;
            if (isNumber) return <span className="tabular">{String(value)}</span>;
            if (typeof value === "boolean") return <Status value={value ? "Yes" : "No"} />;
            return String(value);
          },
        };
      });
  }, [report.data?.data]);

  const list = keys.data?.data ?? [];

  return (
    <div>
      <PageHeader
        title="Reports"
        description="Every report the API exposes. Pick one, set a date range, export."
        actions={
          active ? (
            <Button
              variant="outline"
              onClick={() => {
                // Export is a plain download, so it goes through the browser
                // rather than the fetch client.
                const url = `${process.env.NEXT_PUBLIC_API_BASE_URL ?? ""}/api/v2/reports/${active}/export?from=${from}&to=${to}`;
                window.open(url, "_blank", "noopener");
              }}
            >
              Export
            </Button>
          ) : null
        }
      />

      {keys.isLoading ? <Skeleton className="mb-6 h-20" /> : null}
      {keys.isError ? (
        <ErrorState message="Could not load the report list." onRetry={() => keys.refetch()} />
      ) : null}

      {list.length > 0 ? (
        <div className="mb-6 flex flex-wrap gap-2">
          {list.map((k, i) => {
            const key = String(k.key ?? k.Key ?? k ?? "");
            const label = String(k.name ?? k.Name ?? k.title ?? key).replace(/([a-z])([A-Z])/g, "$1 $2");
            return (
              <Button
                key={key || i}
                size="sm"
                variant={active === key ? "primary" : "outline"}
                onClick={() => q.setParams({ key, page: 1 })}
              >
                {label}
              </Button>
            );
          })}
        </div>
      ) : null}

      {active ? (
        <>
          <div className="mb-4 flex flex-wrap items-end gap-3">
            <div>
              <Label>From</Label>
              <Input
                type="date"
                value={from}
                onChange={(e) => q.setParams({ from: e.target.value, page: 1 })}
              />
            </div>
            <div>
              <Label>To</Label>
              <Input
                type="date"
                value={to}
                onChange={(e) => q.setParams({ to: e.target.value, page: 1 })}
              />
            </div>
          </div>

          {report.isLoading ? <Skeleton className="h-64" /> : null}
          {report.isError ? (
            <ErrorState
              message={report.error instanceof Error ? report.error.message : "Could not run this report."}
              onRetry={() => report.refetch()}
            />
          ) : null}

          {report.data ? (
            <>
              <DataTable
                columns={columns}
                rows={rows}
                rowKey={(_, i) => i}
                empty={
                  <EmptyState
                    title="Nothing in this period"
                    description="Widen the date range, or check that the underlying activity has been recorded."
                  />
                }
              />
              {rows.length > 0 ? (
                <Pagination
                  page={q.page}
                  pageSize={q.pageSize}
                  total={report.data.meta?.total ?? rows.length}
                  onPageChange={(page) => q.setParams({ page })}
                />
              ) : null}
            </>
          ) : null}
        </>
      ) : (
        <EmptyState
          title="Pick a report"
          description="Each one runs against live data for the date range you choose."
        />
      )}
    </div>
  );
}
