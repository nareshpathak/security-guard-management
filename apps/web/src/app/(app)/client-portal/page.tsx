"use client";

import { useQuery } from "@tanstack/react-query";
import { DataTable, EmptyState, ErrorState, PageHeader, Skeleton, StatCard } from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { Status } from "@/components/status";
import { getApi } from "@/lib/api";
import { cell } from "@/lib/list-query";
import { count, money, percent } from "@/lib/format";

/**
 * What a client sees about their own service.
 *
 * `usp_Dashboard_Client` is scoped to the signed-in client, so nothing here
 * needs a filter - and a client cannot widen it to somebody else's sites.
 */
export default function ClientPortalPage() {
  const dash = useQuery({
    queryKey: ["client-dashboard"],
    queryFn: () => getApi().get<Row[][]>("/api/v2/dashboard/client"),
  });

  if (dash.isLoading) return <Skeleton className="h-96" />;
  if (dash.isError)
    return (
      <ErrorState
        message={dash.error instanceof Error ? dash.error.message : "Could not load your dashboard."}
        onRetry={() => dash.refetch()}
      />
    );

  const sets = dash.data?.data ?? [];
  const summary = sets[0]?.[0] ?? {};
  const guards = sets[1] ?? [];
  const complaints = sets[2] ?? [];

  return (
    <div>
      <PageHeader title="Your service" description="Guards on duty, patrol compliance and what is outstanding." />

      <div className="mb-8 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard
          label="On duty now"
          value={`${count(summary.PresentNos ?? summary.OnDuty)} / ${count(summary.RequiredNos ?? summary.Contracted)}`}
          tone={
            Number(summary.PresentNos ?? 0) < Number(summary.RequiredNos ?? 0) ? "warning" : "success"
          }
        />
        <StatCard label="Attendance this month" value={percent(summary.AttendancePct ?? 0)} />
        <StatCard
          label="Patrol compliance"
          value={percent(summary.PatrolCompliancePct ?? summary.PatrolPct ?? 0)}
        />
        <StatCard
          label="Outstanding"
          value={money(summary.OutstandingAmount ?? summary.Outstanding)}
          tone={Number(summary.OutstandingAmount ?? 0) > 0 ? "warning" : "success"}
        />
      </div>

      <section className="mb-8">
        <h2 className="mb-3 text-sm font-semibold text-muted">Guards on duty</h2>
        <DataTable
          columns={[
            { id: "name", header: "Guard", cell: (r) => cell(r, "EmpFullName") },
            { id: "desig", header: "Designation", hideOnMobile: true, cell: (r) => cell(r, "DesignationName") },
            { id: "unit", header: "Site", cell: (r) => cell(r, "UnitName") },
            { id: "shift", header: "Shift", hideOnMobile: true, cell: (r) => cell(r, "ShiftName") },
            { id: "status", header: "Today", cell: (r) => <Status value={r.Status ?? "Present"} /> },
          ]}
          rows={guards}
          rowKey={(r, i) => String(r.EmpID ?? i)}
          empty={
            <EmptyState
              title="Nobody on duty"
              description="If this looks wrong, raise a complaint — the agency is notified immediately."
            />
          }
        />
      </section>

      <section>
        <h2 className="mb-3 text-sm font-semibold text-muted">Your complaints</h2>
        <DataTable
          columns={[
            { id: "subject", header: "Subject", cell: (r) => cell(r, "Subject", "Description") },
            { id: "unit", header: "Site", hideOnMobile: true, cell: (r) => cell(r, "UnitName") },
            { id: "status", header: "Status", cell: (r) => <Status value={r.IsClosed ? "Closed" : (r.Status ?? "Open")} /> },
          ]}
          rows={complaints}
          rowKey={(r, i) => String(r.ComplaintID ?? i)}
          empty={<EmptyState title="Nothing raised" description="Good news, as far as it goes." />}
        />
      </section>
    </div>
  );
}
