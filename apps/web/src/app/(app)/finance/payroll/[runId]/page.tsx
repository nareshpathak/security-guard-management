"use client";

import { useQuery } from "@tanstack/react-query";
import { useParams, useRouter } from "next/navigation";
import { useState } from "react";
import { Button, Card, DataTable, EmptyState, ErrorState, PageHeader, Select, Skeleton, StatCard } from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { Modal } from "@/components/modal";
import { getApi, apiBaseUrl } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { useCommand } from "@/lib/use-command";
import { Perm } from "@/lib/perm";
import { cell } from "@/lib/list-query";
import { count, moneyExact } from "@/lib/format";

const RETURNS = ["PF", "ESIC", "PT", "LWF"] as const;

/**
 * One payroll run: the register, the bank advice, the statutory returns, and
 * the lock.
 *
 * Locking is the point of no return - it recovers advances and uniform amounts
 * exactly once and closes the month for attendance edits - so it sits behind a
 * typed confirmation rather than a button that could be clicked by accident.
 */
export default function PayrollRunPage() {
  const { runId } = useParams<{ runId: string }>();
  const router = useRouter();
  const { has } = useAuth();
  const [locking, setLocking] = useState(false);
  const [typed, setTyped] = useState("");
  const [returnType, setReturnType] = useState<string>("PF");

  const register = useQuery({
    queryKey: ["payroll-run", runId],
    queryFn: () => getApi().get<Row[][]>(`/api/v2/payroll/runs/${runId}`, { page: 1, pageSize: 200 }),
  });

  const statutory = useQuery({
    queryKey: ["payroll-statutory", runId, returnType],
    queryFn: () => getApi().get<Row[]>(`/api/v2/payroll/runs/${runId}/statutory/${returnType}`),
  });

  const lock = useCommand({
    path: `/api/v2/payroll/runs/${runId}/lock`,
    invalidate: ["payroll-run", "payroll-runs"],
    successMessage: "Month locked. Attendance for it can no longer be edited.",
    onDone: () => setLocking(false),
  });

  if (register.isLoading) return <Skeleton className="h-96" />;
  if (register.isError)
    return (
      <ErrorState
        message={register.error instanceof Error ? register.error.message : "Could not load this run."}
        onRetry={() => register.refetch()}
      />
    );

  const [rows = [], summaryRows = []] = register.data?.data ?? [];
  const summary = summaryRows[0] ?? {};
  const isLocked = Boolean(summary.IsLocked ?? summary.Locked);

  return (
    <div>
      <PageHeader
        title={`Payroll ${String(summary.MonthYear ?? runId)}`}
        description={isLocked ? "Locked. This month is closed." : "Draft. Nothing has been recovered yet."}
        actions={
          <div className="flex gap-2">
            <Button variant="outline" onClick={() => router.push("/finance/payroll")}>
              Back
            </Button>
            <Button
              variant="outline"
              onClick={() =>
                window.open(`${apiBaseUrl}/api/v2/payroll/runs/${runId}/bank-advice`, "_blank", "noopener")
              }
            >
              Bank advice
            </Button>
            {!isLocked && has(Perm.payrollApprove) ? (
              <Button onClick={() => setLocking(true)}>Lock this month</Button>
            ) : null}
          </div>
        }
      />

      <div className="mb-8 grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard label="Employees" value={count(rows.length)} />
        <StatCard label="Gross" value={moneyExact(sum(rows, "GrossSalary", "Gross"))} />
        <StatCard label="Deductions" value={moneyExact(sum(rows, "TotalDeduction", "Deductions"))} tone="warning" />
        <StatCard label="Net payable" value={moneyExact(sum(rows, "NetPayble", "NetPayable"))} tone="success" />
      </div>

      <section className="mb-8">
        <h2 className="mb-3 text-sm font-semibold text-muted">Register</h2>
        <DataTable
          columns={[
            {
              id: "emp",
              header: "Employee",
              cell: (r) => (
                <div>
                  <div className="font-medium text-text">{cell(r, "EmpFullName", "EmpName")}</div>
                  <div className="tabular text-xs text-muted">{cell(r, "EmpCode")}</div>
                </div>
              ),
            },
            { id: "unit", header: "Site", hideOnMobile: true, cell: (r) => cell(r, "UnitName") },
            {
              id: "days",
              header: "Days",
              className: "text-right",
              cell: (r) => <span className="tabular">{cell(r, "PayableDays", "PresentDays")}</span>,
            },
            {
              id: "gross",
              header: "Gross",
              className: "text-right",
              cell: (r) => <span className="tabular">{moneyExact(r.GrossSalary ?? r.Gross)}</span>,
            },
            {
              id: "ded",
              header: "Deductions",
              className: "text-right",
              hideOnMobile: true,
              cell: (r) => <span className="tabular text-warning">{moneyExact(r.TotalDeduction ?? r.Deductions)}</span>,
            },
            {
              id: "net",
              header: "Net",
              className: "text-right",
              cell: (r) => (
                <span className="tabular font-medium">{moneyExact(r.NetPayble ?? r.NetPayable)}</span>
              ),
            },
          ]}
          rows={rows}
          rowKey={(r, i) => String(r.EmpID ?? i)}
          empty={<EmptyState title="Nobody in this run" description="Generate payroll for a month that has approved attendance." />}
        />
      </section>

      <section>
        <div className="mb-3 flex items-end gap-3">
          <h2 className="text-sm font-semibold text-muted">Statutory return</h2>
          <Select
            className="w-32"
            value={returnType}
            onChange={(e) => setReturnType(e.target.value)}
            aria-label="Statutory return type"
          >
            {RETURNS.map((r) => (
              <option key={r} value={r}>
                {r}
              </option>
            ))}
          </Select>
        </div>

        {statutory.isLoading ? (
          <Skeleton className="h-48" />
        ) : (
          <DataTable
            columns={
              (statutory.data?.data?.[0]
                ? Object.keys(statutory.data.data[0]).slice(0, 6)
                : []
              ).map((k) => ({
                id: k,
                header: k.replace(/([a-z])([A-Z])/g, "$1 $2"),
                className: /amount|wage|total/i.test(k) ? "text-right" : undefined,
                cell: (r: Row) =>
                  r[k] === null || r[k] === undefined ? (
                    <span className="text-muted">—</span>
                  ) : /amount|wage|total/i.test(k) ? (
                    <span className="tabular">{moneyExact(r[k])}</span>
                  ) : (
                    String(r[k])
                  ),
              }))
            }
            rows={statutory.data?.data ?? []}
            rowKey={(_, i) => i}
            empty={<EmptyState title={`No ${returnType} liability`} description="Nobody in this run is enrolled." />}
          />
        )}
      </section>

      <Modal
        open={locking}
        onOpenChange={setLocking}
        title="Lock this month"
        description="Advances and uniform amounts are recovered, and attendance for the month can no longer be edited. This cannot be undone."
        footer={
          <Button variant="danger" loading={lock.isPending} disabled={typed !== "LOCK"} onClick={() => lock.mutate()}>
            Lock
          </Button>
        }
      >
        <p className="rounded-md bg-warning-subtle px-3 py-2 text-sm text-warning">
          Type <strong>LOCK</strong> to confirm.
        </p>
        <input
          value={typed}
          onChange={(e) => setTyped(e.target.value.toUpperCase())}
          aria-label="Type LOCK to confirm"
          className="h-9 w-full rounded-md border border-border bg-surface px-3 text-sm text-text"
        />
      </Modal>
    </div>
  );
}

function sum(rows: Row[], ...keys: string[]): number {
  return rows.reduce((total, r) => {
    for (const k of keys) {
      const v = r[k];
      if (v !== null && v !== undefined) return total + Number(v);
    }
    return total;
  }, 0);
}
