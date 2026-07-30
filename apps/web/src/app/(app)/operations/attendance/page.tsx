"use client";
export const dynamic = "force-dynamic";

import { useQuery } from "@tanstack/react-query";
import { useSearchParams } from "next/navigation";
import { useState } from "react";
import {
  Button,
  DataTable,
  EmptyState,
  ErrorState,
  Input,
  Label,
  PageHeader,
  Pagination,
  Select,
  Skeleton,
  StatusPill,
} from "@diti365/ui";
import type { Row } from "@diti365/shared";
import { Modal } from "@/components/modal";
import { GenericReportPrintTemplate, PrintModal } from "@/components/print-template";
import { getApi } from "@/lib/api";
import { useAuth } from "@/lib/auth";
import { useCommand } from "@/lib/use-command";
import { Perm } from "@/lib/perm";
import { cell, useListQueryState } from "@/lib/list-query";
import { date, isoDate } from "@/lib/format";

type AttendanceRow = {
  attendanceId?: number;
  empId?: number;
  empCode?: string;
  empFullName?: string;
  unitName?: string;
  attendanceDate?: string;
  status?: string;
  [key: string]: unknown;
};

type ApprovalRow = {
  attendanceId?: number;
  empFullName?: string;
  unitName?: string;
  [key: string]: unknown;
};

export default function AttendancePage() {
  const { has } = useAuth();
  const searchParams = useSearchParams();
  const tab = searchParams.get("tab") === "approvals" ? "approvals" : "register";
  const q = useListQueryState();
  const [bulkModal, setBulkModal] = useState(false);
  const [showPrintModal, setShowPrintModal] = useState(false);

  const [bulkForm, setBulkForm] = useState({
    unitId: "",
    date: isoDate(new Date()),
    shiftId: "1",
    empIds: "",
    status: "P",
    remark: "",
  });

  const register = useQuery({
    queryKey: ["attendance", q.page, q.pageSize, q.unitId, q.from, q.to],
    enabled: tab === "register",
    queryFn: async () =>
      getApi().get<AttendanceRow[]>("/api/v2/attendance", {
        page: q.page,
        pageSize: q.pageSize,
        unitId: q.unitId,
        from: q.from,
        to: q.to,
      }),
  });

  const approvals = useQuery({
    queryKey: ["attendance-approvals", q.page, q.pageSize],
    enabled: tab === "approvals",
    queryFn: async () =>
      getApi().get<ApprovalRow[]>("/api/v2/attendance/pending-approval", {
        page: q.page,
        pageSize: q.pageSize,
      }),
  });

  const unitsQuery = useQuery({
    queryKey: ["units-dropdown"],
    queryFn: () => getApi().get<Row[]>("/api/v2/units"),
    staleTime: 5 * 60 * 1000,
  });

  const approveCmd = useCommand<Record<string, unknown>>({
    path: "/api/v2/attendance/approve",
    invalidate: ["attendance-approvals", "attendance"],
    successMessage: "Attendance approval status updated",
  });

  const bulkCmd = useCommand<Record<string, unknown>>({
    path: "/api/v2/attendance/bulk",
    invalidate: ["attendance", "attendance-approvals"],
    successMessage: "Bulk shift attendance marked successfully",
    onDone: () => {
      setBulkModal(false);
      setBulkForm({
        unitId: "",
        date: isoDate(new Date()),
        shiftId: "1",
        empIds: "",
        status: "P",
        remark: "",
      });
    },
  });

  const rows = register.data?.data ?? [];
  const approvalRows = approvals.data?.data ?? [];
  const units = unitsQuery.data?.data ?? [];

  return (
    <div>
      <PageHeader
        title="Daily Attendance & Punch Register"
        description="Shift attendance logs, supervisor punch approvals, and bulk shift marking."
        actions={
          <div className="flex items-center gap-2">
            <Button variant="outline" onClick={() => setShowPrintModal(true)}>
              <svg className="size-4 mr-1.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
                <polyline points="6 9 6 2 18 2 18 9" />
                <path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2" />
                <rect x="6" y="14" width="12" height="8" />
              </svg>
              Print Attendance Register
            </Button>
            {has(Perm.attendanceEdit) ? (
              <Button variant="primary" onClick={() => setBulkModal(true)}>
                + Bulk Mark Roster
              </Button>
            ) : null}
          </div>
        }
      />

      {/* Tabs */}
      <div className="mb-4 flex gap-2">
        <Button
          variant={tab === "register" ? "primary" : "outline"}
          size="sm"
          onClick={() => q.setParams({ tab: undefined })}
        >
          Attendance Register
        </Button>
        <Button
          variant={tab === "approvals" ? "primary" : "outline"}
          size="sm"
          onClick={() => q.setParams({ tab: "approvals", page: 1 })}
        >
          Pending Approvals Queue
        </Button>
      </div>

      {tab === "register" ? (
        <>
          {register.isLoading ? <Skeleton className="h-64" /> : null}
          {register.isError ? (
            <ErrorState
              message={register.error instanceof Error ? register.error.message : "Failed"}
              onRetry={() => register.refetch()}
            />
          ) : null}

          {register.data ? (
            <>
              <DataTable
                columns={[
                  {
                    id: "date",
                    header: "Date",
                    cell: (r) => (
                      <span className="tabular font-medium">
                        {date(cell(r as Row, "attendanceDate", "AttendanceDate"))}
                      </span>
                    ),
                  },
                  {
                    id: "emp",
                    header: "Employee Guard",
                    cell: (r) => (
                      <div>
                        <div className="font-semibold text-text">
                          {cell(r as Row, "empFullName", "EmpFullName")}
                        </div>
                        <div className="tabular text-xs text-muted">
                          ID: {cell(r as Row, "empCode", "EmpCode", "empId")}
                        </div>
                      </div>
                    ),
                  },
                  {
                    id: "unit",
                    header: "Unit Site",
                    cell: (r) => cell(r as Row, "unitName", "UnitName"),
                  },
                  {
                    id: "status",
                    header: "Status",
                    cell: (r) => {
                      const st = cell(r as Row, "status", "Status", "AttendanceStatus");
                      return (
                        <StatusPill
                          tone={st === "P" || st === "Present" ? "success" : st === "A" || st === "Absent" ? "danger" : "neutral"}
                        >
                          {st}
                        </StatusPill>
                      );
                    },
                  },
                ]}
                rows={rows}
                rowKey={(r, i) => String(r.attendanceId ?? r.AttendanceId ?? i)}
                empty={
                  <EmptyState
                    title="No attendance records"
                    description="Click Bulk Mark Roster to enter attendance for a shift."
                  />
                }
              />
              <Pagination
                page={q.page}
                pageSize={q.pageSize}
                total={register.data.meta?.total ?? rows.length}
                onPageChange={(page) => q.setParams({ page })}
              />
            </>
          ) : null}
        </>
      ) : (
        <>
          {approvals.isLoading ? <Skeleton className="h-64" /> : null}
          {approvals.isError ? (
            <ErrorState
              message={approvals.error instanceof Error ? approvals.error.message : "Failed"}
              onRetry={() => approvals.refetch()}
            />
          ) : null}

          {approvals.data ? (
            <>
              <DataTable
                columns={[
                  {
                    id: "emp",
                    header: "Employee Guard",
                    cell: (r) => (
                      <span className="font-semibold text-text">
                        {cell(r as Row, "empFullName", "EmpFullName")}
                      </span>
                    ),
                  },
                  {
                    id: "unit",
                    header: "Unit Site",
                    cell: (r) => cell(r as Row, "unitName", "UnitName"),
                  },
                  {
                    id: "date",
                    header: "Punch Date",
                    cell: (r) => (
                      <span className="tabular">
                        {date(cell(r as Row, "attendanceDate", "AttendanceDate"))}
                      </span>
                    ),
                  },
                  {
                    id: "actions",
                    header: "Actions",
                    className: "text-right",
                    cell: (r) => {
                      const id = Number(r.attendanceId ?? r.AttendanceId);
                      return (
                        <div className="flex items-center justify-end gap-2">
                          <Button
                            size="sm"
                            variant="secondary"
                            onClick={() => approveCmd.mutate({ attendanceIds: [id], approve: true })}
                          >
                            Approve
                          </Button>
                          <Button
                            size="sm"
                            variant="danger"
                            onClick={() =>
                              approveCmd.mutate({
                                attendanceIds: [id],
                                approve: false,
                                rejectReason: "Rejected by operational executive",
                              })
                            }
                          >
                            Reject
                          </Button>
                        </div>
                      );
                    },
                  },
                ]}
                rows={approvalRows}
                rowKey={(r, i) => String(r.attendanceId ?? r.AttendanceId ?? i)}
                empty={
                  <EmptyState
                    title="No pending approvals"
                    description="All supervisor punches have been processed."
                  />
                }
              />
              <Pagination
                page={q.page}
                pageSize={q.pageSize}
                total={approvals.data.meta?.total ?? approvalRows.length}
                onPageChange={(page) => q.setParams({ page })}
              />
            </>
          ) : null}
        </>
      )}

      {/* Bulk Attendance Modal */}
      <Modal
        open={bulkModal}
        onOpenChange={setBulkModal}
        title="Bulk Mark Shift Roster"
        description="Mark attendance for multiple employee guards at once."
        footer={
          <Button
            loading={bulkCmd.isPending}
            disabled={!bulkForm.unitId || !bulkForm.empIds}
            onClick={() => {
              const ids = bulkForm.empIds
                .split(",")
                .map((s) => Number(s.trim()))
                .filter((n) => !isNaN(n) && n > 0);
              bulkCmd.mutate({
                unitId: Number(bulkForm.unitId),
                date: bulkForm.date,
                shiftId: Number(bulkForm.shiftId),
                empIds: ids,
                status: bulkForm.status,
                remark: bulkForm.remark || undefined,
              });
            }}
          >
            Mark Bulk Attendance
          </Button>
        }
      >
        <div>
          <Label required>Unit Site</Label>
          <Select
            value={bulkForm.unitId}
            onChange={(e) => setBulkForm((f) => ({ ...f, unitId: e.target.value }))}
          >
            <option value="">Select Unit Site...</option>
            {units.map((u, i) => (
              <option key={String(u.UnitID ?? u.Id ?? i)} value={String(u.UnitID ?? u.Id ?? "")}>
                {String(u.UnitName ?? u.Name ?? "")}
              </option>
            ))}
          </Select>
        </div>
        <div className="grid grid-cols-2 gap-3">
          <div>
            <Label required>Attendance Date</Label>
            <Input
              type="date"
              value={bulkForm.date}
              onChange={(e) => setBulkForm((f) => ({ ...f, date: e.target.value }))}
            />
          </div>
          <div>
            <Label required>Attendance Status</Label>
            <Select
              value={bulkForm.status}
              onChange={(e) => setBulkForm((f) => ({ ...f, status: e.target.value }))}
            >
              <option value="P">Present (P)</option>
              <option value="A">Absent (A)</option>
              <option value="WO">Weekly Off (WO)</option>
            </Select>
          </div>
        </div>
        <div>
          <Label required>Employee IDs (Comma-separated)</Label>
          <Input
            placeholder="e.g. 1001, 1002, 1003"
            value={bulkForm.empIds}
            onChange={(e) => setBulkForm((f) => ({ ...f, empIds: e.target.value }))}
          />
        </div>
        <div>
          <Label>Remarks</Label>
          <Input
            placeholder="Shift remarks"
            value={bulkForm.remark}
            onChange={(e) => setBulkForm((f) => ({ ...f, remark: e.target.value }))}
          />
        </div>
      </Modal>

      {/* Printable Attendance Modal */}
      <PrintModal
        open={showPrintModal}
        onClose={() => setShowPrintModal(false)}
        title="DAILY ATTENDANCE REGISTER REPORT"
      >
        <GenericReportPrintTemplate
          title="DAILY ATTENDANCE REGISTER REPORT"
          columns={[
            { key: "AttendanceDate", label: "Date" },
            { key: "EmpFullName", label: "Guard Name" },
            { key: "UnitName", label: "Unit Site" },
            { key: "Status", label: "Status" },
          ]}
          rows={rows}
        />
      </PrintModal>
    </div>
  );
}
