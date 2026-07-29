"use client";

import { useQuery } from "@tanstack/react-query";
import { useState } from "react";
import {
  DataTable,
  EmptyState,
  ErrorState,
  PageHeader,
  Skeleton,
  StatCard,
} from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { Status } from "@/components/status";
import { getApi } from "@/lib/api";
import { cell } from "@/lib/list-query";
import { ago, count, dateTime } from "@/lib/format";

export default function TrackingPage() {
  const [selected, setSelected] = useState<number | null>(null);

  const live = useQuery({
    queryKey: ["tracking-live"],
    queryFn: () => getApi().get<Row[]>("/api/v2/tracking/live", { staleMinutes: 30 }),
    // A tracking board that is a minute stale is worse than useless: it shows
    // a guard at a post he left. Thirty seconds is the compromise with battery
    // and server load.
    refetchInterval: 30_000,
  });

  const trail = useQuery({
    queryKey: ["tracking-trail", selected],
    enabled: selected !== null,
    queryFn: () => getApi().get<Row[][]>(`/api/v2/tracking/users/${selected}/trail`),
  });

  const rows = live.data?.data ?? [];
  const stale = rows.filter((r) => r.IsStale === true || r.IsStale === 1).length;
  const spoofing = rows.filter((r) => Number(r.MockPingsToday ?? 0) > 0).length;

  return (
    <div>
      <PageHeader
        title="Live tracking"
        description="Where field staff last reported from. Refreshes every 30 seconds."
      />

      <div className="mb-6 grid gap-4 sm:grid-cols-3">
        <StatCard label="Reporting" value={count(rows.length - stale)} />
        <StatCard label="Stale (30 min+)" value={count(stale)} />
        <StatCard
          label="Spoofed pings today"
          value={count(spoofing)}
          // Zero is the expected value here, so any other number is the point
          // of the card.
          tone={spoofing > 0 ? "danger" : undefined}
        />
      </div>

      {live.isLoading ? <Skeleton className="h-64" /> : null}
      {live.isError ? (
        <ErrorState
          message={live.error instanceof Error ? live.error.message : "Could not load positions."}
          onRetry={() => live.refetch()}
        />
      ) : null}

      {live.data ? (
        <DataTable
          columns={[
            {
              id: "person",
              header: "Person",
              cell: (r) => (
                <div>
                  <div className="font-medium text-text">{cell(r, "EmpFullName", "UserName")}</div>
                  <div className="text-xs text-muted">{cell(r, "DesignationName", "RoleCode")}</div>
                </div>
              ),
            },
            { id: "unit", header: "Site", cell: (r) => cell(r, "CurrentUnit") },
            {
              id: "seen",
              header: "Last reported",
              cell: (r) =>
                r.LoggedAt ? (
                  <div>
                    <div className={r.IsStale ? "text-warning" : ""}>{ago(r.LoggedAt)}</div>
                    <div className="tabular text-xs text-muted">{dateTime(r.LoggedAt)}</div>
                  </div>
                ) : (
                  <span className="text-muted">no genuine position</span>
                ),
            },
            {
              id: "battery",
              header: "Battery",
              className: "text-right",
              hideOnMobile: true,
              cell: (r) => {
                const pct = Number(r.BatteryLevel ?? -1);
                if (pct < 0) return <span className="text-muted">—</span>;
                // A dying phone is why a guard stops reporting, so it belongs
                // next to the timestamp rather than buried in a detail view.
                return (
                  <span className={pct <= 15 ? "tabular text-danger" : "tabular"}>{pct}%</span>
                );
              },
            },
            {
              id: "mock",
              header: "Integrity",
              cell: (r) => {
                const mocked = Number(r.MockPingsToday ?? 0);
                return mocked > 0 ? (
                  <Status value={`${mocked} spoofed`} />
                ) : (
                  <span className="text-xs text-muted">clean</span>
                );
              },
            },
            {
              id: "coords",
              header: "Position",
              hideOnMobile: true,
              cell: (r) =>
                r.Latitude ? (
                  <a
                    className="tabular text-primary underline"
                    href={`https://www.google.com/maps?q=${r.Latitude},${r.Longitude}`}
                    target="_blank"
                    rel="noopener noreferrer"
                  >
                    {Number(r.Latitude).toFixed(4)}, {Number(r.Longitude).toFixed(4)}
                  </a>
                ) : (
                  <span className="text-muted">—</span>
                ),
            },
          ]}
          rows={rows}
          rowKey={(r, i) => String(r.UserID ?? i)}
          onRowClick={(r) => setSelected(Number(r.UserID))}
          empty={
            <EmptyState
              title="Nobody has reported today"
              description="Field staff report from the mobile app while on duty."
            />
          }
        />
      ) : null}

      {selected !== null ? (
        <div className="mt-8">
          <h2 className="mb-3 text-sm font-semibold text-muted">Today&rsquo;s trail</h2>
          {trail.isLoading ? <Skeleton className="h-48" /> : null}
          {trail.data ? (
            <DataTable
              columns={[
                { id: "at", header: "At", cell: (r) => <span className="tabular">{dateTime(r.LoggedAt)}</span> },
                {
                  id: "pos",
                  header: "Position",
                  cell: (r) => (
                    <span className="tabular">
                      {Number(r.Latitude).toFixed(5)}, {Number(r.Longitude).toFixed(5)}
                    </span>
                  ),
                },
                {
                  id: "seg",
                  header: "Moved",
                  className: "text-right",
                  cell: (r) =>
                    r.SegmentMeters === null || r.SegmentMeters === undefined ? (
                      <span className="text-muted">—</span>
                    ) : (
                      <span className="tabular">{Math.round(Number(r.SegmentMeters))} m</span>
                    ),
                },
                { id: "src", header: "Source", hideOnMobile: true, cell: (r) => cell(r, "Source") },
                {
                  id: "flag",
                  header: "",
                  cell: (r) => (r.IsMockLocation ? <Status value="Spoofed" /> : null),
                },
              ]}
              rows={trail.data.data?.[0] ?? []}
              rowKey={(r, i) => String(r.LogID ?? i)}
              empty={<EmptyState title="No pings today for this person" />}
            />
          ) : null}
        </div>
      ) : null}
    </div>
  );
}
