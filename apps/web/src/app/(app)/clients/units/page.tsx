"use client";

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { useRouter } from "next/navigation";
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
} from "@diti365/ui";
import { ApiError, type Row, type SpResult } from "@diti365/shared";
import { getApi } from "@/lib/api";
import { cell, useListQueryState } from "@/lib/list-query";

export default function UnitsPage() {
  const router = useRouter();
  const qc = useQueryClient();
  const q = useListQueryState();
  const [form, setForm] = useState({
    clientId: "",
    unitName: "",
    address: "",
    geofenceRadiusMeters: "150",
  });
  const [message, setMessage] = useState<string | null>(null);

  const list = useQuery({
    queryKey: ["units", q.page, q.search],
    queryFn: async () =>
      getApi().get<Row[]>("/api/v2/units", {
        page: q.page,
        pageSize: q.pageSize,
        search: q.search || undefined,
      }),
  });

  const save = useMutation({
    mutationFn: async () =>
      (await getApi().post<SpResult>("/api/v2/units", {
        clientId: Number(form.clientId),
        unitName: form.unitName,
        address: form.address || undefined,
        geofenceRadiusMeters: Number(form.geofenceRadiusMeters) || 150,
      })).data,
    onSuccess: async (res) => {
      setMessage(res.message);
      await qc.invalidateQueries({ queryKey: ["units"] });
    },
    onError: (err) => setMessage(err instanceof ApiError ? err.message : "Failed"),
  });

  return (
    <div>
      <PageHeader title="Sites / Units" description="Client sites with geofence and contracted strength." />
      {message ? <p className="mb-4 text-sm">{message}</p> : null}

      <div className="mb-6 grid gap-3 rounded-[var(--diti-radius-lg)] border border-[var(--diti-border)] bg-[var(--diti-surface)] p-4 md:grid-cols-4">
        <div>
          <Label required>Client id</Label>
          <Input value={form.clientId} onChange={(e) => setForm((f) => ({ ...f, clientId: e.target.value }))} />
        </div>
        <div>
          <Label required>Unit name</Label>
          <Input value={form.unitName} onChange={(e) => setForm((f) => ({ ...f, unitName: e.target.value }))} />
        </div>
        <div>
          <Label>Geofence (m)</Label>
          <Input
            value={form.geofenceRadiusMeters}
            onChange={(e) => setForm((f) => ({ ...f, geofenceRadiusMeters: e.target.value }))}
          />
        </div>
        <div className="md:col-span-4">
          <Label>Address</Label>
          <Input value={form.address} onChange={(e) => setForm((f) => ({ ...f, address: e.target.value }))} />
        </div>
        <div>
          <Button
            loading={save.isPending}
            disabled={!form.clientId || !form.unitName}
            onClick={() => save.mutate()}
          >
            Save unit
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
              { id: "name", header: "Unit", cell: (r) => cell(r, "UnitName") },
              { id: "client", header: "Client", cell: (r) => cell(r, "ClientName") },
              { id: "code", header: "Code", cell: (r) => cell(r, "UnitCode") },
              { id: "geo", header: "Geofence", cell: (r) => cell(r, "GeofenceRadiusMeters") },
            ]}
            rows={list.data.data}
            rowKey={(r) => String(r.UnitID ?? r.UnitId)}
            onRowClick={(r) => router.push(`/clients/units/${r.UnitID ?? r.UnitId}`)}
            empty={<EmptyState title="No sites" description="Create a unit for a client." />}
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
