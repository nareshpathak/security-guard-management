"use client";

import { useQuery } from "@tanstack/react-query";
import { useState } from "react";
import { Button, EmptyState, ErrorState, Input, Label, PageHeader, Skeleton } from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { getApi } from "@/lib/api";
import { cell } from "@/lib/list-query";
import { currentMonth, moneyExact } from "@/lib/format";

/**
 * A single guard's slip for a month.
 *
 * Every figure comes from usp_Payroll_GetSlip. Nothing is recomputed here: a
 * slip that disagrees with the payroll run is worse than no slip at all.
 */
import { PayslipPrintTemplate, PrintModal } from "@/components/print-template";

export default function SalarySlipsPage() {
  const [empId, setEmpId] = useState("");
  const [monthYear, setMonthYear] = useState(currentMonth(-1));
  const [asked, setAsked] = useState<{ empId: string; monthYear: string } | null>(null);
  const [showPrintModal, setShowPrintModal] = useState(false);

  const slip = useQuery({
    queryKey: ["salary-slip", asked?.empId, asked?.monthYear],
    enabled: Boolean(asked?.empId),
    queryFn: () => getApi().get<Row | null>(`/api/v2/payroll/slips/${asked!.empId}/${asked!.monthYear}`),
  });

  const s = slip.data?.data ?? null;

  const earnings: [string, unknown][] = s
    ? [
        ["Basic", s.BasicSalary ?? s.Basic],
        ["HRA", s.Hra],
        ["Conveyance", s.Conveyance],
        ["Washing allowance", s.WashingAllowance],
        ["Overtime", s.OtAmount],
        ["Other allowances", s.OtherAllowance],
      ]
    : [];

  const deductions: [string, unknown][] = s
    ? [
        ["Provident fund", s.Pf],
        ["ESIC", s.Esic],
        ["Professional tax", s.Pt],
        ["Labour welfare fund", s.Lwf],
        ["Advance recovered", s.AdvanceDeduction],
        ["Uniform recovered", s.UniformDeduction],
      ]
    : [];

  return (
    <div className="max-w-3xl">
      <PageHeader
        title="Salary slip"
        description="One guard, one month, exactly as payroll computed it."
        actions={
          s ? (
            <Button variant="primary" size="sm" onClick={() => setShowPrintModal(true)}>
              <svg className="size-4 mr-1.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <polyline points="6 9 6 2 18 2 18 9" />
                <path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2" />
                <rect x="6" y="14" width="12" height="8" />
              </svg>
              Print / Save PDF Payslip
            </Button>
          ) : null
        }
      />

      <form
        className="mb-6 flex flex-wrap items-end gap-3"
        onSubmit={(e) => {
          e.preventDefault();
          setAsked({ empId, monthYear });
        }}
      >
        <div>
          <Label htmlFor="empId" required>
            Employee id
          </Label>
          <Input
            id="empId"
            inputMode="numeric"
            className="w-32 tabular"
            value={empId}
            onChange={(e) => setEmpId(e.target.value.replace(/\D/g, ""))}
            required
          />
        </div>
        <div>
          <Label htmlFor="month" required>
            Month
          </Label>
          <Input
            id="month"
            type="month"
            value={monthYear}
            onChange={(e) => setMonthYear(e.target.value)}
            required
          />
        </div>
        <Button type="submit" disabled={!empId}>
          Show slip
        </Button>
      </form>

      {slip.isLoading ? <Skeleton className="h-64" /> : null}
      {slip.isError ? (
        <ErrorState
          message={slip.error instanceof Error ? slip.error.message : "Could not load the slip."}
          onRetry={() => slip.refetch()}
        />
      ) : null}

      {asked && slip.data && !s ? (
        <EmptyState
          title="No slip for that month"
          description="Payroll may not have been run, or this employee had no approved attendance."
        />
      ) : null}

      {s ? (
        <article className="rounded-xl border border-border bg-surface p-6 shadow-sm">
          <header className="mb-6 flex flex-wrap items-start justify-between gap-4 border-b border-border pb-4">
            <div>
              <h2 className="text-lg font-semibold text-text">{cell(s, "EmpName", "EmpFullName")}</h2>
              <p className="tabular text-sm text-muted">
                {cell(s, "EmpCode")} · {cell(s, "DesignationName")} · {cell(s, "UnitName")}
              </p>
            </div>
            <div className="text-right">
              <div className="text-xs uppercase tracking-wide text-muted">{asked?.monthYear}</div>
              <div className="tabular text-sm">
                {cell(s, "PresentDays", "PayableDays")} days payable
              </div>
            </div>
          </header>

          <div className="grid gap-8 sm:grid-cols-2">
            <section>
              <h3 className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted">Earnings</h3>
              <dl className="space-y-1.5 text-sm">
                {earnings.map(([label, value]) => (
                  <div key={label} className="flex justify-between gap-4">
                    <dt className="text-muted">{label}</dt>
                    <dd className="tabular">{moneyExact(value)}</dd>
                  </div>
                ))}
                <div className="flex justify-between gap-4 border-t border-border pt-1.5 font-medium">
                  <dt>Gross</dt>
                  <dd className="tabular">{moneyExact(s.GrossSalary ?? s.Gross)}</dd>
                </div>
              </dl>
            </section>

            <section>
              <h3 className="mb-2 text-xs font-semibold uppercase tracking-wide text-muted">Deductions</h3>
              <dl className="space-y-1.5 text-sm">
                {deductions.map(([label, value]) => (
                  <div key={label} className="flex justify-between gap-4">
                    <dt className="text-muted">{label}</dt>
                    <dd className="tabular">{moneyExact(value)}</dd>
                  </div>
                ))}
                <div className="flex justify-between gap-4 border-t border-border pt-1.5 font-medium">
                  <dt>Total deductions</dt>
                  <dd className="tabular">{moneyExact(s.TotalDeduction ?? s.Deductions)}</dd>
                </div>
              </dl>
            </section>
          </div>

          <footer className="mt-6 flex items-baseline justify-between border-t border-border pt-4">
            <span className="text-sm font-medium">Net payable</span>
            <span className="tabular text-2xl font-semibold text-text">
              {moneyExact(s.NetPayble ?? s.NetPayable)}
            </span>
          </footer>
        </article>
      ) : null}

      {/* Printable Payslip Modal */}
      {s ? (
        <PrintModal
          open={showPrintModal}
          onClose={() => setShowPrintModal(false)}
          title={`PAYSLIP - ${s.EmpName ?? "STAFF"} (${asked?.monthYear})`}
        >
          <PayslipPrintTemplate
            payslip={{
              ...s,
              Month: asked?.monthYear,
              GuardName: cell(s, "EmpName", "EmpFullName"),
              GuardCode: cell(s, "EmpCode"),
              Designation: cell(s, "DesignationName"),
              BranchName: cell(s, "UnitName"),
            }}
          />
        </PrintModal>
      ) : null}
    </div>
  );
}
