"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useSearchParams } from "next/navigation";
import { useState } from "react";
import {
  Button,
  DataTable,
  EmptyState,
  ErrorState,
  PageHeader,
  Pagination,
  Skeleton,
  StatusPill,
} from "@diti365/ui";
import { ApiError, type Row, type SpResult } from "@diti365/shared";
import { getApi } from "@/lib/api";
import { cell, useListQueryState } from "@/lib/list-query";

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
  const qc = useQueryClient();
  const searchParams = useSearchParams();
  const tab = searchParams.get("tab") === "approvals" ? "approvals" : "register";
  const q = useListQueryState();
  const [message, setMessage] = useState<string | null>(null);

  const register = useQuery({
    queryKey: ["attendance", q.page, q.unitId, q.from, q.to],
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
    queryKey: ["attendance-approvals", q.page],
    enabled: tab === "approvals",
    queryFn: async () =>
      getApi().get<ApprovalRow[]>("/api/v2/attendance/pending-approval", {
        page: q.page,
        pageSize: q.pageSize,
      }),
  });

  const approve = useMutation({
    mutationFn: async ({ ids, ok }: { ids: number[]; ok: boolean }) =>
      (await getApi().post<SpResult>("/api/v2/attendance/approve", {
        attendanceIds: ids,
        approve: ok,
        rejectReason: ok ? undefined : "Rejected from web console",
      })).data,
    onSuccess: async (res) => {
      setMessage(res.message);
      await qc.invalidateQueries({ queryKey: ["attendance-approvals"] });
      await qc.invalidateQueries({ queryKey: ["attendance-counts"] });
    },
    onError: (err) => setMessage(err instanceof ApiError ? err.message : "Failed"),
  });

  return (
    <div>
      <PageHeader title="Attendance" description="Daily register and supervisor approval queue." />
      <div className="mb-4 flex gap-2">
        <Button
          variant={tab === "register" ? "primary" : "outline"}
          size="sm"
          onClick={() => q.setParams({ tab: undefined })}
        >
          Register
        </Button>
        <Button
          variant={tab === "approvals" ? "primary" : "outline"}
          size="sm"
          onClick={() => q.setParams({ tab: "approvals", page: 1 })}
        >
          Approvals
        </Button>
      </div>
      {message ? <p className="mb-4 text-sm">{message}</p> : null}

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
                  { id: "date", header: "Date", cell: (r) => cell(r as Row, "attendanceDate", "AttendanceDate") },
                  { id: "emp", header: "Employee", cell: (r) => cell(r as Row, "empFullName", "EmpFullName", "empCode") },
                  { id: "unit", header: "Unit", cell: (r) => cell(r as Row, "unitName", "UnitName") },
                  {
                    id: "status",
                    header: "Status",
                    cell: (r) => <StatusPill>{cell(r as Row, "status", "Status", "AttendanceStatus")}</StatusPill>,
                  },
                ]}
                rows={register.data.data}
                rowKey={(r, i) => String(r.attendanceId ?? r.AttendanceId ?? i)}
                empty={<EmptyState title="No attendance rows" />}
              />
              <Pagination
                page={q.page}
                pageSize={q.pageSize}
                total={register.data.meta?.total ?? register.data.data.length}
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
            <DataTable
              columns={[
                { id: "emp", header: "Employee", cell: (r) => cell(r as Row, "empFullName", "EmpFullName") },
                { id: "unit", header: "Unit", cell: (r) => cell(r as Row, "unitName", "UnitName") },
                { id: "date", header: "Date", cell: (r) => cell(r as Row, "attendanceDate", "AttendanceDate") },
                {
                  id: "actions",
                  header: "Actions",
                  cell: (r) => {
                    const id = Number(r.attendanceId ?? r.AttendanceId);
                    return (
                      <div className="flex gap-2">
                        <Button size="sm" onClick={() => approve.mutate({ ids: [id], ok: true })}>
                          Approve
                        </Button>
                        <Button size="sm" variant="danger" onClick={() => approve.mutate({ ids: [id], ok: false })}>
                          Reject
                        </Button>
                      </div>
                    );
                  },
                },
              ]}
              rows={approvals.data.data}
              rowKey={(r, i) => String(r.attendanceId ?? r.AttendanceId ?? i)}
              empty={<EmptyState title="No pending approvals" />}
            />
          ) : null}
        </>
      )}
    </div>
  );
}
