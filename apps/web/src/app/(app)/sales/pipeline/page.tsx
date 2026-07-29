"use client";

import { useQuery } from "@tanstack/react-query";
import { EmptyState, ErrorState, PageHeader, Skeleton } from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { getApi } from "@/lib/api";
import { count, money } from "@/lib/format";

/**
 * The funnel, as a set of proportional bars rather than a chart library.
 *
 * A pipeline has five or six stages; a bar chart adds a dependency, an axis and
 * a legend to show what a row of bars shows directly.
 */
export default function PipelinePage() {
  const pipeline = useQuery({
    queryKey: ["sales-pipeline"],
    queryFn: () => getApi().get<Row[]>("/api/v2/sales/pipeline"),
  });

  const rows = pipeline.data?.data ?? [];
  const peak = Math.max(1, ...rows.map((r) => Number(r.Count ?? r.Cnt ?? 0)));

  return (
    <div>
      <PageHeader title="Pipeline" description="Prospects by stage, widest first." />

      {pipeline.isLoading ? <Skeleton className="h-64" /> : null}
      {pipeline.isError ? (
        <ErrorState
          message={pipeline.error instanceof Error ? pipeline.error.message : "Could not load the pipeline."}
          onRetry={() => pipeline.refetch()}
        />
      ) : null}

      {pipeline.data ? (
        rows.length === 0 ? (
          <EmptyState
            title="Nothing in the pipeline"
            description="Log a sales visit and it will appear here at its stage."
          />
        ) : (
          <div className="space-y-3 rounded-xl border border-border bg-surface p-5 shadow-sm">
            {rows.map((r, i) => {
              const n = Number(r.Count ?? r.Cnt ?? 0);
              const label = String(r.Stage ?? r.Status ?? "Unknown");
              return (
                <div key={i}>
                  <div className="mb-1 flex items-baseline justify-between text-sm">
                    <span className="font-medium text-text">{label}</span>
                    <span className="tabular text-muted">
                      {count(n)}
                      {r.Value ? ` · ${money(r.Value)}` : ""}
                    </span>
                  </div>
                  <div
                    className="h-2.5 rounded-full bg-surface-sunken"
                    role="img"
                    aria-label={`${label}: ${n}`}
                  >
                    <div
                      className="h-full rounded-full bg-primary transition-all"
                      style={{ width: `${Math.max(2, (n / peak) * 100)}%` }}
                    />
                  </div>
                </div>
              );
            })}
          </div>
        )
      ) : null}
    </div>
  );
}
