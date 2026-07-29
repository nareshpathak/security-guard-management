"use client";

import { useQuery } from "@tanstack/react-query";
import { DataTable, ErrorState, PageHeader, Skeleton, StatCard, StatusPill } from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { getApi } from "@/lib/api";
import { cell } from "@/lib/list-query";

export default function TurnoutPage() {
  const live = useQuery({
    queryKey: ["turnout-live-page"],
    queryFn: async () => (await getApi().get<Row[]>("/api/v2/turnout/live")).data,
    refetchInterval: 60_000,
  });
  const vacant = useQuery({
    queryKey: ["vacant-page"],
    queryFn: async () =>
      (await getApi().get<Row[]>("/api/v2/turnout/vacant-posts", { minutesAhead: 60 })).data,
    refetchInterval: 60_000,
  });

  const required = (live.data ?? []).reduce((n, r) => n + Number(r.RequiredNos ?? r.Required ?? 0), 0);
  const present = (live.data ?? []).reduce((n, r) => n + Number(r.PresentNos ?? r.Present ?? 0), 0);
  const absent = (live.data ?? []).reduce((n, r) => n + Number(r.AbsentNos ?? r.Absent ?? 0), 0);

  return (
    <div>
      <PageHeader
        title="Live turnout"
        description="Required vs present by unit. Auto-refreshes every 60 seconds."
      />
      <div className="mb-6 grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
        <StatCard label="Required" value={required} />
        <StatCard label="Present" value={present} tone="success" />
        <StatCard label="Absent" value={absent || Math.max(required - present, 0)} tone="danger" />
        <StatCard label="Vacant posts" value={vacant.data?.length ?? 0} tone="warning" />
      </div>

      {live.isLoading ? <Skeleton className="h-64" /> : null}
      {live.isError ? (
        <ErrorState message={live.error instanceof Error ? live.error.message : "Failed"} onRetry={() => live.refetch()} />
      ) : null}
      {live.data ? (
        <DataTable
          columns={[
            { id: "unit", header: "Unit", cell: (r) => cell(r, "UnitName") },
            { id: "client", header: "Client", hideOnMobile: true, cell: (r) => cell(r, "ClientName") },
            { id: "req", header: "Required", cell: (r) => cell(r, "RequiredNos", "Required") },
            { id: "pres", header: "Present", cell: (r) => cell(r, "PresentNos", "Present") },
            {
              id: "gap",
              header: "Gap",
              cell: (r) => {
                const gap =
                  Number(r.RequiredNos ?? r.Required ?? 0) - Number(r.PresentNos ?? r.Present ?? 0);
                return gap > 0 ? (
                  <StatusPill tone="danger">{gap}</StatusPill>
                ) : (
                  <StatusPill tone="success">OK</StatusPill>
                );
              },
            },
          ]}
          rows={live.data}
          rowKey={(r, i) => String(r.UnitID ?? r.UnitId ?? i)}
          empty={<p className="text-sm text-[var(--diti-muted)]">No turnout data.</p>}
        />
      ) : null}
    </div>
  );
}
