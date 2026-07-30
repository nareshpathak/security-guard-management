"use client";

import { useQuery } from "@tanstack/react-query";
import { useState } from "react";
import {
  Button,
  DataTable,
  EmptyState,
  ErrorState,
  Input,
  Label,
  PageHeader,
  Skeleton,
  StatCard,
} from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { Modal } from "@/components/modal";
import { Status } from "@/components/status";
import { GenericReportPrintTemplate, PrintModal } from "@/components/print-template";
import { getApi } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { useCommand } from "@/lib/use-command";
import { Perm } from "@/lib/perm";
import { cell } from "@/lib/list-query";
import { count, money } from "@/lib/format";

export default function PayrollPage() {
  const { has } = useAuth();
  const [monthYear, setMonthYear] = useState(() => {
    const d = new Date();
    const mm = String(d.getMonth() + 1).padStart(2, "0");
    return `${mm}-${d.getFullYear()}`;
  });

  const [activeRunId, setActiveRunId] = useState<number | null>(null);
  const [showValidationModal, setShowValidationModal] = useState(false);
  const [showBankAdviceModal, setShowBankAdviceModal] = useState(false);
  const [showStatutoryModal, setShowStatutoryModal] = useState(false);
  const [statutoryType, setStatutoryType] = useState<"pf" | "esic">("pf");

  // Payroll Validation Query
  const validateQuery = useQuery({
    queryKey: ["payroll-validate", monthYear],
    queryFn: () =>
      getApi().get<Row[][]>("/api/v2/payroll/validate", { monthYear }),
    enabled: showValidationModal,
  });

  // Payroll Run Details Query
  const runDetailQuery = useQuery({
    queryKey: ["payroll-run-detail", activeRunId],
    queryFn: () =>
      getApi().get<Row[][]>(`/api/v2/payroll/runs/${activeRunId}`),
    enabled: !!activeRunId,
  });

  // Bank Advice Query
  const bankAdviceQuery = useQuery({
    queryKey: ["payroll-bank-advice", activeRunId],
    queryFn: () =>
      getApi().get<Row[]>(`/api/v2/payroll/runs/${activeRunId}/bank-advice`),
    enabled: !!activeRunId && showBankAdviceModal,
  });

  // Statutory Return Query
  const statutoryQuery = useQuery({
    queryKey: ["payroll-statutory", activeRunId, statutoryType],
    queryFn: () =>
      getApi().get<Row[]>(`/api/v2/payroll/runs/${activeRunId}/statutory/${statutoryType}`),
    enabled: !!activeRunId && showStatutoryModal,
  });

  // Generate Payroll Command
  const generateCmd = useCommand<Record<string, unknown>>({
    path: "/api/v2/payroll/runs",
    invalidate: ["payroll-validate", "payroll-run-detail"],
    successMessage: "Payroll run generated successfully",
    onDone: (res) => {
      const runId = Number((res as { id?: number })?.id ?? 0);
      if (runId > 0) setActiveRunId(runId);
    },
  });

  // Lock Payroll Command
  const lockCmd = useCommand<Record<string, unknown>>({
    path: activeRunId ? `/api/v2/payroll/runs/${activeRunId}/lock` : "",
    invalidate: ["payroll-run-detail", "payroll-validate"],
    successMessage: "Payroll run locked and advance recoveries processed",
  });

  const validationSets = validateQuery.data?.data ?? [];
  const runRegisterRows = runDetailQuery.data?.data?.[0] ?? [];
  const runSummaryRow = runDetailQuery.data?.data?.[1]?.[0] ?? {};

  const totalEmployeesPaid = runRegisterRows.length;
  const totalNetPay = runRegisterRows.reduce(
    (acc, r) => acc + Number(r.NetPayable ?? r.NetSalary ?? r.NetPay ?? 0),
    0
  );

  return (
    <div>
      <PageHeader
        title="Payroll & Salary Processing"
        description="Automated monthly attendance salary calculation, statutory PF/ESIC deductions, and bank payout processing."
        actions={
          <div className="flex items-center gap-2">
            <Button variant="outline" onClick={() => setShowValidationModal(true)}>
              Validate Month
            </Button>
            {has(Perm.payrollEdit) ? (
              <Button
                variant="primary"
                loading={generateCmd.isPending}
                onClick={() => generateCmd.mutate({ monthYear })}
              >
                + Generate Payroll Run
              </Button>
            ) : null}
          </div>
        }
      />

      {/* KPI Overview */}
      <div className="mb-6 grid gap-4 sm:grid-cols-3">
        <StatCard label="Active Payroll Month" value={monthYear} tone="default" />
        <StatCard label="Employees Paid" value={count(totalEmployeesPaid)} tone="default" />
        <StatCard label="Total Net Payout" value={money(totalNetPay)} tone="success" />
      </div>

      {/* Selection Control Bar */}
      <div className="mb-6 flex flex-wrap items-center justify-between gap-4 rounded-xl border border-[var(--diti-border)] bg-[var(--diti-surface)] p-4 shadow-xs">
        <div className="flex items-center gap-3">
          <div>
            <Label required className="!mb-0 text-xs">Payroll Month (MM-YYYY)</Label>
            <Input
              value={monthYear}
              onChange={(e) => setMonthYear(e.target.value)}
              placeholder="07-2026"
              className="w-36 mt-1"
            />
          </div>
        </div>

        {activeRunId ? (
          <div className="flex items-center gap-2">
            {has(Perm.payrollApprove) ? (
              <Button
                variant="danger"
                loading={lockCmd.isPending}
                onClick={() => lockCmd.mutate({})}
              >
                Lock & Finalize Run #{activeRunId}
              </Button>
            ) : null}
            <Button variant="outline" onClick={() => setShowBankAdviceModal(true)}>
              Bank Advice Payout
            </Button>
            <Button
              variant="outline"
              onClick={() => {
                setStatutoryType("pf");
                setShowStatutoryModal(true);
              }}
            >
              Statutory Returns (PF/ESIC)
            </Button>
          </div>
        ) : null}
      </div>

      {/* Active Run Register View */}
      {activeRunId ? (
        <div className="space-y-4">
          <div className="flex items-center justify-between">
            <h2 className="text-base font-semibold text-text">
              Payroll Register (Run #{activeRunId})
            </h2>
            <span className="text-xs text-muted">
              {String(runSummaryRow.Status ?? "Generated")}
            </span>
          </div>

          {runDetailQuery.isLoading ? <Skeleton className="h-64" /> : null}
          {runDetailQuery.isError ? (
            <ErrorState
              message={
                runDetailQuery.error instanceof Error
                  ? runDetailQuery.error.message
                  : "Could not load payroll register."
              }
              onRetry={() => runDetailQuery.refetch()}
            />
          ) : null}

          {runDetailQuery.data ? (
            <DataTable
              columns={[
                {
                  id: "emp",
                  header: "Employee",
                  cell: (r) => (
                    <div>
                      <div className="font-semibold text-text">{cell(r, "EmpFullName")}</div>
                      <div className="tabular text-xs text-muted">ID: {cell(r, "EmpCode", "EmpId")}</div>
                    </div>
                  ),
                },
                {
                  id: "days",
                  header: "Present Days",
                  className: "text-right",
                  cell: (r) => <span className="tabular font-medium">{count(r.PresentDays)}</span>,
                },
                {
                  id: "basic",
                  header: "Basic Pay",
                  className: "text-right",
                  hideOnMobile: true,
                  cell: (r) => <span className="tabular">{money(r.BasicPay)}</span>,
                },
                {
                  id: "gross",
                  header: "Gross Salary",
                  className: "text-right",
                  cell: (r) => <span className="tabular font-medium">{money(r.GrossSalary)}</span>,
                },
                {
                  id: "deductions",
                  header: "Deductions",
                  className: "text-right",
                  hideOnMobile: true,
                  cell: (r) => <span className="tabular text-danger">{money(r.TotalDeduction)}</span>,
                },
                {
                  id: "net",
                  header: "Net Payable",
                  className: "text-right",
                  cell: (r) => (
                    <span className="tabular font-bold text-success">
                      {money(r.NetPayable ?? r.NetSalary)}
                    </span>
                  ),
                },
              ]}
              rows={runRegisterRows}
              rowKey={(r, i) => String(r.EmpID ?? r.RegisterID ?? i)}
              empty={
                <EmptyState
                  title="No payroll entries found"
                  description="Click Generate Payroll Run to process salary for this month."
                />
              }
            />
          ) : null}
        </div>
      ) : (
        <EmptyState
          title="No payroll run active"
          description="Click Validate Month to verify attendance, or Generate Payroll Run to execute salary calculation."
        />
      )}

      {/* Validation Modal */}
      <Modal
        open={showValidationModal}
        onOpenChange={setShowValidationModal}
        title={`Payroll Pre-Run Validation (${monthYear})`}
        description="Blocking items: unapproved attendance, missing salary structure, or missing bank details."
      >
        {validateQuery.isLoading ? <Skeleton className="h-48" /> : null}
        {validateQuery.isError ? (
          <ErrorState
            message={
              validateQuery.error instanceof Error
                ? validateQuery.error.message
                : "Validation failed."
            }
          />
        ) : null}

        {validationSets.length > 0 ? (
          <div className="space-y-4 max-h-[60vh] overflow-y-auto">
            {validationSets.map((rows, idx) => (
              <div key={idx} className="rounded-lg border border-[var(--diti-border)] p-3">
                <div className="text-xs font-semibold text-muted mb-2">
                  Validation Issue Group #{idx + 1} ({rows.length} records)
                </div>
                <DataTable
                  columns={
                    rows[0]
                      ? Object.keys(rows[0]).slice(0, 6).map((k) => ({
                          id: k,
                          header: k,
                          cell: (r: Row) => String(r[k] ?? "—"),
                        }))
                      : []
                  }
                  rows={rows}
                  rowKey={(_, i) => `${idx}-${i}`}
                  empty={<EmptyState title="No blocking issues in group" />}
                />
              </div>
            ))}
          </div>
        ) : validateQuery.isSuccess ? (
          <div className="p-4 text-center text-sm font-medium text-success bg-emerald-500/10 rounded-lg">
            ✓ All validation checks passed cleanly! Month is ready for payroll generation.
          </div>
        ) : null}
      </Modal>

      {/* Bank Advice Modal */}
      <PrintModal
        open={showBankAdviceModal}
        onClose={() => setShowBankAdviceModal(false)}
        title={`BANK PAYOUT ADVICE - RUN #${activeRunId}`}
      >
        <GenericReportPrintTemplate
          title={`BANK TRANSFER PAYOUT ADVICE (${monthYear})`}
          columns={[
            { key: "EmpFullName", label: "Employee Name" },
            { key: "BankName", label: "Bank Name" },
            { key: "AccountNo", label: "Account No" },
            { key: "IfscCode", label: "IFSC Code" },
            { key: "NetPayable", label: "Net Payout (₹)", align: "right" },
          ]}
          rows={bankAdviceQuery.data?.data ?? []}
        />
      </PrintModal>

      {/* Statutory Returns Modal */}
      <Modal
        open={showStatutoryModal}
        onOpenChange={setShowStatutoryModal}
        title={`Statutory Compliance Returns (${statutoryType.toUpperCase()})`}
        description="Monthly regulatory file dataset for PF ECR / ESIC return submission."
        footer={
          <div className="flex gap-2">
            <Button
              variant={statutoryType === "pf" ? "primary" : "outline"}
              onClick={() => setStatutoryType("pf")}
            >
              PF Return Data
            </Button>
            <Button
              variant={statutoryType === "esic" ? "primary" : "outline"}
              onClick={() => setStatutoryType("esic")}
            >
              ESIC Return Data
            </Button>
          </div>
        }
      >
        {statutoryQuery.isLoading ? <Skeleton className="h-48" /> : null}
        {statutoryQuery.data ? (
          <DataTable
            columns={
              (statutoryQuery.data.data[0]
                ? Object.keys(statutoryQuery.data.data[0]).slice(0, 6).map((k) => ({
                    id: k,
                    header: k,
                    cell: (r: Row) => String(r[k] ?? "—"),
                  }))
                : [])
            }
            rows={statutoryQuery.data.data}
            rowKey={(_, i) => String(i)}
            empty={<EmptyState title="No statutory return data available" />}
          />
        ) : null}
      </Modal>
    </div>
  );
}
