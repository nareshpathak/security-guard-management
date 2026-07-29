"use client";

import { useQuery } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { DataTable, EmptyState, ErrorState, PageHeader, Skeleton, StatCard } from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { Status } from "@/components/status";
import { getApi } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { cell } from "@/lib/list-query";
import { count, date, money, percent } from "@/lib/format";

export default function DashboardPage() {
  const router = useRouter();
  const { user } = useAuth();

  const turnout = useQuery({
    queryKey: ["turnout-live"],
    queryFn: async () => (await getApi().get<Row[]>("/api/v2/turnout/live")).data,
    refetchInterval: 60_000,
  });

  const vacant = useQuery({
    queryKey: ["vacant-posts"],
    queryFn: async () =>
      (await getApi().get<Row[]>("/api/v2/turnout/vacant-posts", { minutesAhead: 60 })).data,
  });

  const pending = useQuery({
    queryKey: ["pending-approvals-count"],
    queryFn: async () => {
      const r = await getApi().get<Row[]>("/api/v2/attendance/pending-approval", { page: 1, pageSize: 1 });
      return r.meta?.total ?? r.data.length;
    },
  });

  const expiring = useQuery({
    queryKey: ["docs-expiring"],
    queryFn: async () =>
      (await getApi().get<Row[]>("/api/v2/documents/expiring", { withinDays: 30, page: 1, pageSize: 8 })).data,
  });

  const outstanding = useQuery({
    queryKey: ["invoices-outstanding"],
    queryFn: async () =>
      (await getApi().get<Row[]>("/api/v2/invoices", { onlyOutstanding: true, page: 1, pageSize: 200 })).data,
  });

  const units = turnout.data ?? [];
  const required = units.reduce((n, r) => n + Number(r.RequiredNos ?? r.Required ?? 0), 0);
  const present = units.reduce((n, r) => n + Number(r.PresentNos ?? r.Present ?? 0), 0);
  const owed = (outstanding.data ?? []).reduce(
    (n, r) => n + (Number(r.GrandTotal ?? 0) - Number(r.ReceivedAmount ?? 0)),
    0,
  );

  // Only the short sites are worth charting: a bar per site where present
  // equals required is a row of identical bars that says nothing.
  const shortfall = units
    .map((r) => ({
      unit: String(r.UnitName ?? r.Unit ?? ""),
      required: Number(r.RequiredNos ?? r.Required ?? 0),
      present: Number(r.PresentNos ?? r.Present ?? 0),
      gap: Number(r.RequiredNos ?? r.Required ?? 0) - Number(r.PresentNos ?? r.Present ?? 0),
    }))
    .filter((d) => d.gap > 0)
    .sort((a, b) => b.gap - a.gap)
    .slice(0, 10);

  if (turnout.isError) {
    return (
      <ErrorState
        title="Dashboard could not load"
        message={turnout.error instanceof Error ? turnout.error.message : "Unknown error"}
        onRetry={() => turnout.refetch()}
      />
    );
  }

  return (
    <div>
      <PageHeader
        title={`Good ${greeting()}, ${user?.name?.split(" ")[0] ?? "there"}`}
        description="Everything that needs a decision today."
      />

      {turnout.isLoading ? (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {[0, 1, 2, 3].map((i) => (
            <Skeleton key={i} className="h-24" />
          ))}
        </div>
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          <StatCard
            label="On duty now"
            value={`${count(present)} / ${count(required)}`}
            hint={required > 0 ? `${percent((present / required) * 100)} of contracted strength` : undefined}
            tone={required > 0 && present / required < 0.9 ? "warning" : "success"}
            href="/operations/turnout"
          />
          <StatCard
            label="Posts vacant"
            value={count(vacant.data?.length ?? 0)}
            hint="within the next hour"
            tone={(vacant.data?.length ?? 0) > 0 ? "danger" : "success"}
            href="/operations/turnout"
          />
          <StatCard
            label="Awaiting approval"
            value={count(pending.data ?? 0)}
            hint="attendance rows"
            tone={(pending.data ?? 0) > 0 ? "warning" : "default"}
            href="/operations/attendance?tab=approvals"
          />
          <StatCard
            label="Outstanding"
            value={money(owed)}
            hint={`${count(outstanding.data?.length ?? 0)} unpaid invoices`}
            tone={owed > 0 ? "warning" : "success"}
            href="/finance/ageing"
          />
        </div>
      )}

      <section className="mt-8 grid gap-6 lg:grid-cols-2">
        <div className="rounded-xl border border-border bg-surface p-5 shadow-sm">
          <h2 className="mb-1 text-sm font-semibold text-text">Sites below strength</h2>
          <p className="mb-4 text-xs text-muted">
            Required against present, worst first. Sites at full strength are not shown.
          </p>
          {shortfall.length === 0 ? (
            <EmptyState title="Every site is at strength" description="Nothing to chase right now." />
          ) : (
            <ResponsiveContainer width="100%" height={Math.max(200, shortfall.length * 34)}>
              <BarChart data={shortfall} layout="vertical" margin={{ left: 8, right: 16 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="var(--diti-border)" horizontal={false} />
                <XAxis type="number" allowDecimals={false} stroke="var(--diti-muted)" fontSize={12} />
                <YAxis
                  type="category"
                  dataKey="unit"
                  width={120}
                  stroke="var(--diti-muted)"
                  fontSize={12}
                />
                <Tooltip
                  cursor={{ fill: "var(--diti-surface-sunken)" }}
                  contentStyle={{
                    background: "var(--diti-surface)",
                    border: "1px solid var(--diti-border)",
                    borderRadius: 8,
                    fontSize: 12,
                  }}
                  // Recharts types the formatter loosely across versions, so the
                  // signature is left to inference rather than pinned here.
                  formatter={(value) => [value, "Short by"]}
                />
                <Bar dataKey="gap" radius={[0, 4, 4, 0]}>
                  {shortfall.map((d, i) => (
                    <Cell key={i} fill={d.gap >= 3 ? "var(--diti-danger)" : "var(--diti-warning)"} />
                  ))}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          )}
        </div>

        <div className="rounded-xl border border-border bg-surface p-5 shadow-sm">
          <h2 className="mb-1 text-sm font-semibold text-text">Documents expiring</h2>
          <p className="mb-4 text-xs text-muted">
            Within 30 days. A guard on site with a lapsed police verification is a liability.
          </p>
          {expiring.isLoading ? (
            <Skeleton className="h-40" />
          ) : (
            <DataTable
              columns={[
                { id: "emp", header: "Employee", cell: (r) => cell(r, "EmpFullName", "OwnerName") },
                { id: "doc", header: "Document", cell: (r) => cell(r, "DocTypeName", "DocumentFilename") },
                {
                  id: "exp",
                  header: "Expires",
                  className: "text-right",
                  cell: (r) => {
                    const days = Math.ceil(
                      (new Date(String(r.ExpiryDate)).getTime() - Date.now()) / 86_400_000,
                    );
                    return (
                      <span className={days <= 7 ? "tabular font-medium text-danger" : "tabular"}>
                        {date(r.ExpiryDate)}
                      </span>
                    );
                  },
                },
              ]}
              rows={expiring.data ?? []}
              rowKey={(r, i) => String(r.DocumentID ?? i)}
              onRowClick={() => router.push("/people/documents")}
              empty={<EmptyState title="Nothing expiring" description="No documents lapse in the next 30 days." />}
            />
          )}
        </div>
      </section>

      <section className="mt-8">
        <h2 className="mb-3 text-sm font-semibold text-muted">Turnout by site</h2>
        {turnout.isLoading ? (
          <Skeleton className="h-48" />
        ) : (
          <DataTable
            columns={[
              { id: "unit", header: "Site", cell: (r) => cell(r, "UnitName", "Unit") },
              { id: "client", header: "Client", hideOnMobile: true, cell: (r) => cell(r, "ClientName") },
              {
                id: "req",
                header: "Required",
                className: "text-right",
                cell: (r) => <span className="tabular">{count(r.RequiredNos ?? r.Required)}</span>,
              },
              {
                id: "present",
                header: "Present",
                className: "text-right",
                cell: (r) => <span className="tabular">{count(r.PresentNos ?? r.Present)}</span>,
              },
              {
                id: "gap",
                header: "Short by",
                className: "text-right",
                cell: (r) => {
                  const gap = Number(r.VacantNos ?? 0);
                  return gap > 0 ? (
                    <span className="tabular font-medium text-danger">{gap}</span>
                  ) : (
                    <span className="text-muted">—</span>
                  );
                },
              },
              {
                id: "status",
                header: "",
                cell: (r) => (Number(r.VacantNos ?? 0) > 0 ? <Status value="Short" /> : <Status value="Full" />),
              },
            ]}
            rows={units}
            rowKey={(r, i) => String(r.UnitID ?? i)}
            onRowClick={() => router.push("/operations/turnout")}
            empty={<EmptyState title="No turnout recorded today" />}
          />
        )}
      </section>
    </div>
  );
}

function greeting(): string {
  const h = new Date().getHours();
  if (h < 12) return "morning";
  if (h < 17) return "afternoon";
  return "evening";
}
