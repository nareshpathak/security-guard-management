"use client";

import { useQuery } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
import { useState } from "react";
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
import {
  Button,
  DataTable,
  EmptyState,
  ErrorState,
  Input,
  Label,
  PageHeader,
  Select,
  Skeleton,
  StatCard,
} from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { Status } from "@/components/status";
import { getApi } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { cell } from "@/lib/list-query";
import { count, date, isoDate, money, percent } from "@/lib/format";

export default function DashboardPage() {
  const router = useRouter();
  const { user } = useAuth();

  const [filterClient, setFilterClient] = useState("");
  const [filterDate, setFilterDate] = useState(isoDate(new Date()));

  // Dropdown options queries
  const clientsQuery = useQuery({
    queryKey: ["clients-dropdown"],
    queryFn: () => getApi().get<Row[]>("/api/v2/clients"),
    staleTime: 5 * 60 * 1000,
  });

  const turnout = useQuery({
    queryKey: ["turnout-live", filterClient, filterDate],
    queryFn: async () =>
      (await getApi().get<Row[]>("/api/v2/turnout/live", { clientId: filterClient ? Number(filterClient) : undefined })).data,
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

  const expiringDocs = useQuery({
    queryKey: ["docs-expiring"],
    queryFn: async () =>
      (await getApi().get<Row[]>("/api/v2/documents/expiring", { withinDays: 30, page: 1, pageSize: 6 })).data,
  });

  const expiringContracts = useQuery({
    queryKey: ["contracts-expiring-dash"],
    queryFn: async () =>
      (await getApi().get<Row[]>("/api/v2/reports/contract", { page: 1, pageSize: 6 })).data,
  });

  const outstanding = useQuery({
    queryKey: ["invoices-outstanding-dash"],
    queryFn: async () =>
      (await getApi().get<Row[]>("/api/v2/invoices", { onlyOutstanding: true, page: 1, pageSize: 200 })).data,
  });

  const clients = clientsQuery.data?.data ?? [];
  const units = turnout.data ?? [];
  const required = units.reduce((n, r) => n + Number(r.RequiredNos ?? r.Required ?? 0), 0);
  const present = units.reduce((n, r) => n + Number(r.PresentNos ?? r.Present ?? 0), 0);
  const owed = (outstanding.data ?? []).reduce(
    (n, r) => n + (Number(r.GrandTotal ?? 0) - Number(r.ReceivedAmount ?? 0)),
    0,
  );

  const shortfall = units
    .map((r) => ({
      unit: String(r.UnitName ?? r.Unit ?? ""),
      required: Number(r.RequiredNos ?? r.Required ?? 0),
      present: Number(r.PresentNos ?? r.Present ?? 0),
      gap: Number(r.RequiredNos ?? r.Required ?? 0) - Number(r.PresentNos ?? r.Present ?? 0),
    }))
    .filter((d) => d.gap > 0)
    .sort((a, b) => b.gap - a.gap)
    .slice(0, 8);

  if (turnout.isError) {
    return (
      <ErrorState
        title="Dashboard Command Center could not load"
        message={turnout.error instanceof Error ? turnout.error.message : "Unknown error"}
        onRetry={() => turnout.refetch()}
      />
    );
  }

  const actions = (
    <div className="flex flex-wrap items-center gap-2">
      <Button size="sm" variant="outline" onClick={() => router.push("/operations/deployment")}>
        + Deploy Guard
      </Button>
      <Button size="sm" variant="outline" onClick={() => router.push("/operations/turnout")}>
        + Record Turnout
      </Button>
      <Button size="sm" variant="outline" onClick={() => router.push("/finance/invoices")}>
        + Issue Invoice
      </Button>
      <Button size="sm" variant="primary" onClick={() => router.push("/reports")}>
        📊 Reports Hub
      </Button>
    </div>
  );

  return (
    <div>
      <PageHeader
        title={`Executive Command Center — Good ${greeting()}, ${user?.name?.split(" ")[0] ?? "Commander"}`}
        description="Real-time 360° operational & financial intelligence for Security Guard Operations."
        actions={actions}
      />

      {/* Global Filter Bar */}
      <div className="mb-6 flex flex-wrap items-end gap-3 rounded-xl border border-[var(--diti-border)] bg-[var(--diti-surface)] p-3.5 shadow-xs">
        <div className="w-48">
          <Label>Filter Client Account</Label>
          <Select
            value={filterClient}
            onChange={(e) => setFilterClient(e.target.value)}
          >
            <option value="">All Clients Account</option>
            {clients.map((c, i) => (
              <option key={String(c.ClientID ?? c.Id ?? i)} value={String(c.ClientID ?? c.Id ?? "")}>
                {String(c.ClientName ?? c.Name ?? "")}
              </option>
            ))}
          </Select>
        </div>
        <div>
          <Label>Operational Date</Label>
          <Input
            type="date"
            value={filterDate}
            onChange={(e) => setFilterDate(e.target.value)}
          />
        </div>
        <div className="ml-auto flex items-center gap-2">
          <Button
            size="sm"
            variant="outline"
            onClick={() => {
              turnout.refetch();
              vacant.refetch();
              outstanding.refetch();
            }}
          >
            🔄 Refresh Live Metrics
          </Button>
        </div>
      </div>

      {/* Primary KPI StatCards */}
      {turnout.isLoading ? (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
          {[0, 1, 2, 3, 4, 5].map((i) => (
            <Skeleton key={i} className="h-24" />
          ))}
        </div>
      ) : (
        <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6">
          <StatCard
            label="On Duty Now"
            value={`${count(present)} / ${count(required)}`}
            hint={required > 0 ? `${percent((present / required) * 100)} contracted strength` : "No active shifts"}
            tone={required > 0 && present / required < 0.9 ? "warning" : "success"}
            href="/operations/turnout"
          />
          <StatCard
            label="Vacant Posts"
            value={count(vacant.data?.length ?? 0)}
            hint="Immediate replacement required"
            tone={(vacant.data?.length ?? 0) > 0 ? "danger" : "success"}
            href="/operations/turnout"
          />
          <StatCard
            label="Pending Approvals"
            value={count(pending.data ?? 0)}
            hint="Attendance signoffs pending"
            tone={(pending.data ?? 0) > 0 ? "warning" : "default"}
            href="/operations/attendance?tab=approvals"
          />
          <StatCard
            label="Accounts Receivable"
            value={money(owed)}
            hint={`${count(outstanding.data?.length ?? 0)} unpaid client bills`}
            tone={owed > 0 ? "warning" : "success"}
            href="/finance/ageing"
          />
          <StatCard
            label="Contract Renewals"
            value={count(expiringContracts.data?.length ?? 0)}
            hint="Expiring within 30 days"
            tone={(expiringContracts.data?.length ?? 0) > 0 ? "warning" : "success"}
            href="/clients/contracts"
          />
          <StatCard
            label="Compliance Risk"
            value={count(expiringDocs.data?.length ?? 0)}
            hint="Expiring guard documents"
            tone={(expiringDocs.data?.length ?? 0) > 0 ? "danger" : "success"}
            href="/people/documents"
          />
        </div>
      )}

      {/* Operational Charts & Exception Tables */}
      <section className="mt-8 grid gap-6 lg:grid-cols-2">
        {/* Shortfall Bar Chart */}
        <div className="rounded-xl border border-[var(--diti-border)] bg-[var(--diti-surface)] p-5 shadow-xs">
          <div className="flex items-center justify-between mb-2">
            <div>
              <h2 className="text-sm font-bold text-[var(--diti-text)]">Site Shortfall Command Chart</h2>
              <p className="text-xs text-[var(--diti-muted)]">
                Deployment gaps (Required vs Present). Fully deployed sites hidden.
              </p>
            </div>
            <Button size="sm" variant="outline" onClick={() => router.push("/operations/deployment")}>
              Deploy Relievers
            </Button>
          </div>
          {shortfall.length === 0 ? (
            <EmptyState title="100% Strength Achieved" description="All client site units are fully deployed with zero vacant posts." />
          ) : (
            <ResponsiveContainer width="100%" height={Math.max(220, shortfall.length * 36)}>
              <BarChart data={shortfall} layout="vertical" margin={{ left: 8, right: 16 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="var(--diti-border)" horizontal={false} />
                <XAxis type="number" allowDecimals={false} stroke="var(--diti-muted)" fontSize={12} />
                <YAxis
                  type="category"
                  dataKey="unit"
                  width={130}
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
                  formatter={(value) => [value, "Guards Short"]}
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

        {/* Expiring Compliance Documents */}
        <div className="rounded-xl border border-[var(--diti-border)] bg-[var(--diti-surface)] p-5 shadow-xs">
          <div className="flex items-center justify-between mb-2">
            <div>
              <h2 className="text-sm font-bold text-[var(--diti-text)]">Guard Document Verification Audit</h2>
              <p className="text-xs text-[var(--diti-muted)]">
                Police verification, Aadhaar, and License expiring within 30 days.
              </p>
            </div>
            <Button size="sm" variant="outline" onClick={() => router.push("/people/documents")}>
              View All Docs
            </Button>
          </div>
          {expiringDocs.isLoading ? (
            <Skeleton className="h-44" />
          ) : (
            <DataTable
              columns={[
                { id: "emp", header: "Guard Name", cell: (r) => <span className="font-semibold">{cell(r, "EmpFullName", "OwnerName")}</span> },
                { id: "doc", header: "Document Type", cell: (r) => cell(r, "DocTypeName", "DocumentFilename") },
                {
                  id: "exp",
                  header: "Expiry Date",
                  className: "text-right",
                  cell: (r) => {
                    const days = Math.ceil(
                      (new Date(String(r.ExpiryDate)).getTime() - Date.now()) / 86_400_000,
                    );
                    return (
                      <span className={days <= 7 ? "tabular font-bold text-danger" : "tabular font-medium"}>
                        {date(r.ExpiryDate)}
                      </span>
                    );
                  },
                },
              ]}
              rows={expiringDocs.data ?? []}
              rowKey={(r, i) => String(r.DocumentID ?? i)}
              onRowClick={() => router.push("/people/documents")}
              empty={<EmptyState title="Zero Compliance Risk" description="No guard documents expire within 30 days." />}
            />
          )}
        </div>
      </section>

      {/* Live Turnout Roster Table */}
      <section className="mt-8">
        <div className="flex items-center justify-between mb-3">
          <div>
            <h2 className="text-sm font-bold text-[var(--diti-text)]">Live Client Site Turnout Register</h2>
            <p className="text-xs text-[var(--diti-muted)]">Real-time attendance vs contracted post requirements across all sites.</p>
          </div>
          <Button size="sm" variant="outline" onClick={() => router.push("/operations/turnout")}>
            Full Turnout Board →
          </Button>
        </div>
        {turnout.isLoading ? (
          <Skeleton className="h-48" />
        ) : (
          <DataTable
            columns={[
              { id: "unit", header: "Site Unit", cell: (r) => <span className="font-semibold text-text">{cell(r, "UnitName", "Unit")}</span> },
              { id: "client", header: "Client Account", hideOnMobile: true, cell: (r) => cell(r, "ClientName") },
              {
                id: "req",
                header: "Contracted Strength",
                className: "text-right",
                cell: (r) => <span className="tabular font-medium">{count(r.RequiredNos ?? r.Required)}</span>,
              },
              {
                id: "present",
                header: "Present On Duty",
                className: "text-right",
                cell: (r) => <span className="tabular font-medium">{count(r.PresentNos ?? r.Present)}</span>,
              },
              {
                id: "gap",
                header: "Shortfall",
                className: "text-right",
                cell: (r) => {
                  const gap = Number(r.VacantNos ?? 0);
                  return gap > 0 ? (
                    <span className="tabular font-bold text-danger">{gap}</span>
                  ) : (
                    <span className="text-muted">—</span>
                  );
                },
              },
              {
                id: "status",
                header: "Status",
                cell: (r) => (Number(r.VacantNos ?? 0) > 0 ? <Status value="Shortfall" /> : <Status value="100% Full" />),
              },
            ]}
            rows={units}
            rowKey={(r, i) => String(r.UnitID ?? i)}
            onRowClick={() => router.push("/operations/turnout")}
            empty={<EmptyState title="No site turnout recorded for selected date" />}
          />
        )}
      </section>
    </div>
  );
}

function greeting(): string {
  const h = new Date().getHours();
  if (h < 12) return "Morning";
  if (h < 17) return "Afternoon";
  return "Evening";
}
