"use client";

import { useQuery } from "@tanstack/react-query";
import { DataTable, EmptyState, ErrorState, PageHeader, Skeleton, StatCard } from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { getApi } from "@/lib/api";
import { count, date } from "@/lib/format";

/**
 * The platform operator's view across every tenant.
 *
 * The API returns several result sets; they are labelled here rather than
 * guessed from their shape, because the order is the contract.
 */
const SET_TITLES = ["Tenants", "Usage", "Signups", "Expiring soon"];

export default function PlatformAnalyticsPage() {
  const dash = useQuery({
    queryKey: ["platform-dashboard"],
    queryFn: () => getApi().get<Row[][]>("/api/v2/dashboard/platform"),
  });

  if (dash.isLoading) return <Skeleton className="h-64" />;
  if (dash.isError)
    return (
      <ErrorState
        message={dash.error instanceof Error ? dash.error.message : "Could not load platform analytics."}
        onRetry={() => dash.refetch()}
      />
    );

  const sets = dash.data?.data ?? [];
  const summary = sets[0]?.[0] ?? {};

  return (
    <div>
      <PageHeader title="Platform" description="Every agency on this installation." />

      <div className="mb-8 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard label="Tenants" value={count(summary.TenantCount ?? summary.TotalCompanies)} />
        <StatCard label="Active" value={count(summary.ActiveCount ?? summary.ActiveCompanies)} tone="success" />
        <StatCard
          label="Expiring in 30 days"
          value={count(summary.ExpiringCount ?? summary.ExpiringSoon)}
          tone="warning"
        />
        <StatCard label="Users" value={count(summary.UserCount ?? summary.TotalUsers)} />
      </div>

      {sets.slice(1).map((rows, i) =>
        rows.length === 0 ? null : (
          <section key={i} className="mb-8">
            <h2 className="mb-3 text-sm font-semibold text-muted">{SET_TITLES[i + 1] ?? `Set ${i + 2}`}</h2>
            <DataTable
              columns={Object.keys(rows[0])
                .slice(0, 5)
                .map((k) => ({
                  id: k,
                  header: k.replace(/([a-z])([A-Z])/g, "$1 $2"),
                  className: /count|nos|total|amount/i.test(k) ? "text-right" : undefined,
                  cell: (r: Row) =>
                    r[k] === null || r[k] === undefined ? (
                      <span className="text-muted">—</span>
                    ) : /date|on$/i.test(k) ? (
                      <span className="tabular">{date(r[k])}</span>
                    ) : (
                      String(r[k])
                    ),
                }))}
              rows={rows}
              rowKey={(_, j) => j}
              empty={<EmptyState title="Nothing here" />}
            />
          </section>
        ),
      )}

      {sets.length === 0 ? <EmptyState title="No platform data" /> : null}
    </div>
  );
}
