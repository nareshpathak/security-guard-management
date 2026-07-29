"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
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
  Skeleton,
  StatusPill,
} from "@diti365/ui";
import { ApiError, type Row, type SpResult } from "@diti365/shared";
import { getApi } from "@/lib/api";
import { cell, useListQueryState } from "@/lib/list-query";

export default function DeploymentPage() {
  const qc = useQueryClient();
  const q = useListQueryState();
  const [form, setForm] = useState({ empId: "", unitId: "", remark: "" });
  const [message, setMessage] = useState<string | null>(null);

  const list = useQuery({
    queryKey: ["deployments", q.page, q.unitId, q.search],
    queryFn: async () =>
      getApi().get<Row[]>("/api/v2/deployments", {
        page: q.page,
        pageSize: q.pageSize,
        unitId: q.unitId,
        search: q.search || undefined,
      }),
  });

  const deploy = useMutation({
    mutationFn: async () =>
      (await getApi().post<SpResult>("/api/v2/deployments", {
        empId: Number(form.empId),
        unitId: Number(form.unitId),
        remark: form.remark || undefined,
      })).data,
    onSuccess: async (res) => {
      setMessage(res.message);
      setForm({ empId: "", unitId: "", remark: "" });
      await qc.invalidateQueries({ queryKey: ["deployments"] });
    },
    onError: (err) => setMessage(err instanceof ApiError ? err.message : "Failed"),
  });

  return (
    <div>
      <PageHeader title="Deployments" description="Assign guards to units, posts and shifts." />
      {message ? <p className="mb-4 text-sm">{message}</p> : null}

      <div className="mb-6 grid gap-3 rounded-[var(--diti-radius-lg)] border border-[var(--diti-border)] bg-[var(--diti-surface)] p-4 md:grid-cols-4">
        <div>
          <Label required>Emp id</Label>
          <Input value={form.empId} onChange={(e) => setForm((f) => ({ ...f, empId: e.target.value }))} />
        </div>
        <div>
          <Label required>Unit id</Label>
          <Input value={form.unitId} onChange={(e) => setForm((f) => ({ ...f, unitId: e.target.value }))} />
        </div>
        <div className="md:col-span-2">
          <Label>Remark</Label>
          <Input value={form.remark} onChange={(e) => setForm((f) => ({ ...f, remark: e.target.value }))} />
        </div>
        <div>
          <Button
            loading={deploy.isPending}
            disabled={!form.empId || !form.unitId}
            onClick={() => deploy.mutate()}
          >
            Deploy guard
          </Button>
        </div>
      </div>

      {list.isLoading ? <Skeleton className="h-64" /> : null}
      {list.isError ? (
        <ErrorState message={list.error instanceof Error ? list.error.message : "Failed"} onRetry={() => list.refetch()} />
      ) : null}
      {list.data ? (
        <>
          <DataTable
            columns={[
              { id: "emp", header: "Employee", cell: (r) => cell(r, "EmpFullName", "EmpCode", "EmpID") },
              { id: "unit", header: "Unit", cell: (r) => cell(r, "UnitName", "UnitID") },
              { id: "shift", header: "Shift", cell: (r) => cell(r, "ShiftName", "ShiftID") },
              { id: "from", header: "From", cell: (r) => cell(r, "FromDate") },
              {
                id: "status",
                header: "Status",
                cell: (r) => (
                  <StatusPill tone={cell(r, "IsActive", "Status") === "1" || cell(r, "IsActive") === "true" ? "success" : "neutral"}>
                    {cell(r, "Status", "IsActive")}
                  </StatusPill>
                ),
              },
            ]}
            rows={list.data.data}
            rowKey={(r, i) => String(r.DeploymentID ?? r.DeploymentId ?? i)}
            empty={<EmptyState title="No deployments" description="Deploy a guard to a unit." />}
          />
          <Pagination
            page={q.page}
            pageSize={q.pageSize}
            total={list.data.meta?.total ?? list.data.data.length}
            onPageChange={(page) => q.setParams({ page })}
          />
        </>
      ) : null}
    </div>
  );
}
