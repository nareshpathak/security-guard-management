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
  Skeleton,
  StatusPill,
  TextArea,
} from "@diti365/ui";
import { ApiError, type Row, type SpResult } from "@diti365/shared";
import { getApi } from "@/lib/api";
import { cell } from "@/lib/list-query";

export default function RecruitsPage() {
  const qc = useQueryClient();
  const [status, setStatus] = useState("");
  const [form, setForm] = useState({ name: "", mobile: "", aadhaar: "", remark: "" });
  const [message, setMessage] = useState<string | null>(null);

  const list = useQuery({
    queryKey: ["recruits", status],
    queryFn: async () =>
      (await getApi().get<Row[][]>("/api/v2/recruits", { status: status || undefined, page: 1, pageSize: 50 }))
        .data,
  });

  const save = useMutation({
    mutationFn: async () =>
      (await getApi().post<SpResult>("/api/v2/recruits", {
        name: form.name,
        mobile: form.mobile || undefined,
        aadhaar: form.aadhaar || undefined,
        remark: form.remark || undefined,
      })).data,
    onSuccess: async (res) => {
      setMessage(res.message || "Recruit saved");
      setForm({ name: "", mobile: "", aadhaar: "", remark: "" });
      await qc.invalidateQueries({ queryKey: ["recruits"] });
    },
    onError: (err) => setMessage(err instanceof ApiError ? err.message : "Save failed"),
  });

  type RecruitAction = "approve" | "waitlist" | "convert" | "reject";

  const action = useMutation({
    mutationFn: async ({ id, path }: { id: number; path: RecruitAction }) => {
      if (path === "convert") {
        return (await getApi().post<SpResult>(`/api/v2/recruits/${id}/convert`, {})).data;
      }

      const status = path === "approve"
        ? "Approved"
        : path === "waitlist"
          ? "Waitlist"
          : "Rejected";

      return (await getApi().post<SpResult>(`/api/v2/recruits/${id}/status`, { status, remark: null })).data;
    },
    onSuccess: async (res) => {
      setMessage(res.message);
      await qc.invalidateQueries({ queryKey: ["recruits"] });
    },
    onError: (err) => setMessage(err instanceof ApiError ? err.message : "Action failed"),
  });

  const rows = list.data?.[0] ?? [];

  return (
    <div>
      <PageHeader title="Recruit pipeline" description="Intake, approve, waitlist or convert recruits to employees." />
      {message ? (
        <div className="mb-4 rounded-[var(--diti-radius-md)] border border-[var(--diti-border)] bg-[var(--diti-surface)] px-3 py-2 text-sm">
          {message}
        </div>
      ) : null}

      <div className="mb-6 grid gap-4 rounded-[var(--diti-radius-lg)] border border-[var(--diti-border)] bg-[var(--diti-surface)] p-4 md:grid-cols-4">
        <div>
          <Label required>Name</Label>
          <Input value={form.name} onChange={(e) => setForm((f) => ({ ...f, name: e.target.value }))} />
        </div>
        <div>
          <Label>Mobile</Label>
          <Input value={form.mobile} onChange={(e) => setForm((f) => ({ ...f, mobile: e.target.value }))} />
        </div>
        <div>
          <Label>Aadhaar</Label>
          <Input value={form.aadhaar} onChange={(e) => setForm((f) => ({ ...f, aadhaar: e.target.value }))} />
        </div>
        <div className="md:col-span-4">
          <Label>Remark</Label>
          <TextArea value={form.remark} onChange={(e) => setForm((f) => ({ ...f, remark: e.target.value }))} />
        </div>
        <div>
          <Button loading={save.isPending} onClick={() => save.mutate()} disabled={!form.name}>
            Add recruit
          </Button>
        </div>
      </div>

      <div className="mb-4">
        <select
          className="h-9 rounded-[var(--diti-radius-md)] border border-[var(--diti-border)] bg-[var(--diti-surface)] px-3 text-sm"
          value={status}
          onChange={(e) => setStatus(e.target.value)}
        >
          <option value="">All</option>
          <option value="New">New</option>
          <option value="Approved">Approved</option>
          <option value="Waitlist">Waitlist</option>
          <option value="Rejected">Rejected</option>
        </select>
      </div>

      {list.isLoading ? <Skeleton className="h-64" /> : null}
      {list.isError ? (
        <ErrorState message={list.error instanceof Error ? list.error.message : "Failed"} onRetry={() => list.refetch()} />
      ) : null}
      {list.data ? (
        <DataTable
          columns={[
            { id: "name", header: "Name", cell: (r) => cell(r, "Name", "EmpFullName") },
            { id: "mobile", header: "Mobile", cell: (r) => cell(r, "Mobile", "Mobile1") },
            {
              id: "status",
              header: "Status",
              cell: (r) => <StatusPill>{cell(r, "Status", "RecruitStatus")}</StatusPill>,
            },
            {
              id: "actions",
              header: "Actions",
              cell: (r) => {
                const id = Number(r.RecruitID ?? r.RecruitId);
                return (
                  <div className="flex flex-wrap gap-1">
                    <Button size="sm" variant="secondary" onClick={() => action.mutate({ id, path: "approve" })}>
                      Approve
                    </Button>
                    <Button size="sm" variant="outline" onClick={() => action.mutate({ id, path: "waitlist" })}>
                      Waitlist
                    </Button>
                    <Button size="sm" variant="outline" onClick={() => action.mutate({ id, path: "convert" })}>
                      Convert
                    </Button>
                    <Button size="sm" variant="danger" onClick={() => action.mutate({ id, path: "reject" })}>
                      Reject
                    </Button>
                  </div>
                );
              },
            },
          ]}
          rows={rows}
          rowKey={(r) => String(r.RecruitID ?? r.RecruitId)}
          empty={<EmptyState title="No recruits" description="Add a recruit to start the pipeline." />}
        />
      ) : null}
    </div>
  );
}
